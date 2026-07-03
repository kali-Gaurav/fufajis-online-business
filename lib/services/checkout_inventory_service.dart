import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'package:uuid/uuid.dart';

/// Checkout Inventory Service (Refactored to Backend API)
///
/// CRITICAL REDESIGN (Sprint 2B-P0):
/// Previous implementation used client-side Firestore transactions which cannot guarantee
/// atomicity across multiple domains (products, reservations, orders, payments, audit logs).
///
/// NEW ARCHITECTURE:
/// - All inventory operations route through backend API
/// - Backend uses PostgreSQL transactions with row-level locks (SELECT...FOR UPDATE)
/// - Reservation states: active → confirmed/released/expired
/// - TTL cleanup job (cron) expires stale reservations every 5 minutes
///
/// This class is now a pure API router, not a transaction executor.
class CheckoutInventoryService {
  static final CheckoutInventoryService _instance = CheckoutInventoryService._internal();
  factory CheckoutInventoryService() => _instance;
  CheckoutInventoryService._internal();

  final ApiClient _apiClient = ApiClient.instance;
  static const _uuid = Uuid();

  // ──────────────────────────────────────────────────────────────
  // CHECKOUT FLOW (Primary Entry Point)
  // ──────────────────────────────────────────────────────────────

  /// Create order with inventory reservation in one atomic backend transaction
  ///
  /// CRITICAL: This is the ONLY entry point for checkout.
  /// Backend guarantees:
  /// 1. Cart items validated
  /// 2. Inventory locked (SELECT...FOR UPDATE)
  /// 3. Stock verified for ALL items
  /// 4. Reservation created
  /// 5. Order created
  /// 6. Audit log created
  /// 7. Sync event triggered
  /// All in one PostgreSQL transaction or none.
  ///
  /// Returns: { orderId, paymentOrderId, reservationId, expiresAt }
  /// Throws: Exception if any step fails
  Future<Map<String, dynamic>> createOrderWithReservation({
    required String customerId,
    required List<Map<String, dynamic>> items, // [{ productId, quantity }, ...]
    required String paymentMethod,
    String? paymentMethodId,
    String? couponCode,
    double? discountAmount,
  }) async {
    try {
      final idempotencyKey = '${customerId}_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';

      // CRITICAL: All operations happen on backend in one transaction
      final result = await _apiClient.post(
        '/checkout/create-order',
        {
          'customerId': customerId,
          'items': items,
          'paymentMethod': paymentMethod,
          'paymentMethodId': paymentMethodId,
          'couponCode': couponCode,
          'discountAmount': discountAmount,
          'idempotencyKey': idempotencyKey,
        },
      );

      if (result.data?['success'] != true) {
        throw Exception('Checkout failed: ${result.data?['error'] ?? 'Unknown error'}');
      }

      final data = result.data as Map<String, dynamic>;

      debugPrint(
        '[CheckoutInventoryService] ✅ Order created atomically: '
        'orderId=${data['orderId']}, reservationId=${data['reservationId']}, '
        'expiresAt=${data['expiresAt']}',
      );

      return {
        'orderId': data['orderId'],
        'paymentOrderId': data['paymentOrderId'],
        'reservationId': data['reservationId'],
        'expiresAt': data['expiresAt'],
      };
    } catch (e) {
      debugPrint('[CheckoutInventoryService] ❌ Checkout failed: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // RESERVATION LIFECYCLE (After Payment)
  // ──────────────────────────────────────────────────────────────

  /// Confirm reservation after successful payment
  /// Called by: RazorpayService after webhook verification
  ///
  /// Backend updates reservation status: active → confirmed
  /// Stock remains locked in inventory (won't auto-expire)
  Future<void> confirmReservation({
    required String reservationId,
    required String orderId,
    required String paymentId,
  }) async {
    try {
      final result = await _apiClient.post(
        '/inventory/confirm',
        {
          'reservationId': reservationId,
          'orderId': orderId,
          'paymentId': paymentId,
          'confirmedAt': DateTime.now().toIso8601String(),
        },
      );

      if (result.data?['success'] != true) {
        throw Exception('Confirmation failed: ${result.data?['error'] ?? 'Unknown error'}');
      }

      debugPrint('[CheckoutInventoryService] ✅ Reservation confirmed: $reservationId');
    } catch (e) {
      debugPrint('[CheckoutInventoryService] ❌ Confirmation failed: $e');
      rethrow;
    }
  }

  /// Release reservation (customer cancelled checkout)
  /// Called by: Checkout screen cancel button
  ///
  /// Backend updates reservation status: active → released
  /// Stock is immediately returned to available pool
  Future<void> releaseReservation({
    required String reservationId,
    required String orderId,
  }) async {
    try {
      final result = await _apiClient.post(
        '/inventory/release',
        {
          'reservationId': reservationId,
          'orderId': orderId,
          'releasedAt': DateTime.now().toIso8601String(),
        },
      );

      if (result.data?['success'] != true) {
        throw Exception('Release failed: ${result.data?['error'] ?? 'Unknown error'}');
      }

      debugPrint('[CheckoutInventoryService] ✅ Reservation released: $reservationId');
    } catch (e) {
      debugPrint('[CheckoutInventoryService] ❌ Release failed: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // DEPRECATED METHODS (Do Not Use)
  // ──────────────────────────────────────────────────────────────

  /// DEPRECATED: Client-side Firestore transactions are no longer used.
  /// Use createOrderWithReservation() instead, which routes through backend API.
  @deprecated
  Future<String> reserveInventory({
    required String productId,
    required String customerId,
    required int quantity,
    required String orderId,
  }) async {
    throw UnsupportedError(
      'Client-side inventory reservation is no longer allowed. '
      'Use createOrderWithReservation() which atomically: '
      'validates cart, locks inventory, creates order, processes payment in PostgreSQL transaction.'
    );
  }

  /// DEPRECATED: Use releaseReservation() instead.
  @deprecated
  Future<void> releaseReservation_old({
    required String productId,
    required String reservationId,
    required int quantity,
  }) async {
    throw UnsupportedError(
      'Old release method removed. Use releaseReservation() which routes through /inventory/release API.'
    );
  }

  /// DEPRECATED: Use confirmReservation() instead.
  @deprecated
  Future<void> confirmReservation_old({
    required String productId,
    required String reservationId,
    required String orderId,
  }) async {
    throw UnsupportedError(
      'Old confirm method removed. Use confirmReservation() which routes through /inventory/confirm API.'
    );
  }

  /// DEPRECATED: Availability checks now happen on backend.
  @deprecated
  Future<bool> isInventoryAvailable({required String productId, required int quantity}) async {
    throw UnsupportedError(
      'Client-side availability checks are unreliable. '
      'Backend validates during checkout atomically via /checkout/create-order.'
    );
  }

  /// DEPRECATED: Reservations are managed by backend TTL job.
  @deprecated
  Future<Map<String, dynamic>?> getReservation(String reservationId) async {
    throw UnsupportedError(
      'Reservation queries removed from client. '
      'Use order status instead: /orders/:orderId returns reservation state.'
    );
  }
}
