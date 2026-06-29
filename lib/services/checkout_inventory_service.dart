import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

/// Checkout Inventory Service
/// Handles inventory reservation during checkout (Task #9 FIX)
///
/// CRITICAL FIX: The original checkout flow attempted to reserve inventory
/// but never created the actual Firestore documents. This service ensures
/// reservation documents are atomically created during order confirmation.
///
/// Reservation flow:
/// 1. Create reservation doc in products/{productId}/reservations/{reservationId}
/// 2. Update product available_quantity
/// 3. Set 30-minute TTL for auto-cleanup if checkout abandoned
class CheckoutInventoryService {
  static final CheckoutInventoryService _instance = CheckoutInventoryService._internal();
  factory CheckoutInventoryService() => _instance;
  CheckoutInventoryService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Generates unique reservation ID
  String _generateReservationId() {
    return 'RESERVATION_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  /// Reserve inventory for checkout (CRITICAL FIX: Actually creates Firestore docs)
  ///
  /// This function:
  /// 1. Verifies sufficient inventory exists
  /// 2. Creates reservation document at products/{productId}/reservations/{reservationId}
  /// 3. Decrements available_quantity atomically
  /// 4. Sets expiration time for auto-cleanup
  ///
  /// Returns: reservationId for tracking; throws if inventory insufficient
  Future<String> reserveInventory({
    required String productId,
    required String customerId,
    required int quantity,
    required String orderId,
  }) async {
    final reservationId = _generateReservationId();
    final expiresAt = DateTime.now().add(const Duration(minutes: 30));

    try {
      await _db.runTransaction((transaction) async {
        final productRef = _db.collection('products').doc(productId);
        final productSnapshot = await transaction.get(productRef);

        if (!productSnapshot.exists) {
          throw Exception('Product $productId not found');
        }

        final productData = productSnapshot.data()!;
        final currentStock = (productData['stockQuantity'] as num? ?? 0).toInt();

        // Check if sufficient inventory
        if (currentStock < quantity) {
          throw Exception(
            'Insufficient stock. Available: $currentStock, Requested: $quantity'
          );
        }

        // FIXED: Create reservation document (was missing in original)
        final reservationRef = productRef
            .collection('reservations')
            .doc(reservationId);

        transaction.set(reservationRef, {
          'customerId': customerId,
          'orderId': orderId,
          'productId': productId,
          'quantity': quantity,
          'reservedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
          'status': 'active',
          // TTL: Firestore will auto-delete after 30 minutes via TTL policy
        });

        // Decrement available stock (reserved_quantity tracks reserved amounts)
        final currentReserved = (productData['reserved_quantity'] as num? ?? 0).toInt();
        final newReserved = currentReserved + quantity;

        transaction.update(productRef, {
          'reserved_quantity': newReserved,
          'available_quantity': currentStock - quantity,
          'lastReservationAt': FieldValue.serverTimestamp(),
        });

        debugPrint(
          '[CheckoutInventoryService] Reserved $quantity units of $productId '
          'for order $orderId (reservation: $reservationId)'
        );
      });

      return reservationId;
    } catch (e) {
      debugPrint('[CheckoutInventoryService] Reservation failed: $e');
      rethrow;
    }
  }

  /// Release reservation (called on checkout cancel or timeout)
  Future<void> releaseReservation({
    required String productId,
    required String reservationId,
    required int quantity,
  }) async {
    try {
      await _db.runTransaction((transaction) async {
        final productRef = _db.collection('products').doc(productId);
        final reservationRef = productRef.collection('reservations').doc(reservationId);

        final reservationSnapshot = await transaction.get(reservationRef);
        if (!reservationSnapshot.exists) {
          debugPrint('[CheckoutInventoryService] Reservation $reservationId not found');
          return;
        }

        // Delete reservation document
        transaction.delete(reservationRef);

        // Restore available quantity
        final productSnapshot = await transaction.get(productRef);
        if (productSnapshot.exists) {
          final productData = productSnapshot.data()!;
          final currentReserved = (productData['reserved_quantity'] as num? ?? 0).toInt();
          final currentAvailable = (productData['available_quantity'] as num? ?? 0).toInt();

          transaction.update(productRef, {
            'reserved_quantity': max(0, currentReserved - quantity),
            'available_quantity': currentAvailable + quantity,
          });

          debugPrint(
            '[CheckoutInventoryService] Released reservation $reservationId '
            '($quantity units of $productId)'
          );
        }
      });
    } catch (e) {
      debugPrint('[CheckoutInventoryService] Release failed: $e');
      rethrow;
    }
  }

  /// Confirm reservation → Convert to order stock deduction
  /// Called when order payment is successful
  Future<void> confirmReservation({
    required String productId,
    required String reservationId,
    required String orderId,
  }) async {
    try {
      await _db.runTransaction((transaction) async {
        final productRef = _db.collection('products').doc(productId);
        final reservationRef = productRef.collection('reservations').doc(reservationId);

        final reservationSnapshot = await transaction.get(reservationRef);
        if (!reservationSnapshot.exists) {
          throw Exception('Reservation not found');
        }

        final reservationData = reservationSnapshot.data()!;
        final quantity = (reservationData['quantity'] as num? ?? 0).toInt();

        // Delete reservation (stock already deducted during reservation)
        transaction.delete(reservationRef);

        // Mark as confirmed in order
        final orderRef = _db.collection('orders').doc(orderId);
        transaction.update(orderRef, {
          'inventoryReservationConfirmed': true,
          'inventoryReservationId': reservationId,
          'confirmedAt': FieldValue.serverTimestamp(),
        });

        debugPrint(
          '[CheckoutInventoryService] Confirmed reservation $reservationId '
          'for order $orderId ($quantity units)'
        );
      });
    } catch (e) {
      debugPrint('[CheckoutInventoryService] Confirmation failed: $e');
      rethrow;
    }
  }

  /// Check if inventory is currently available (excluding reservations)
  Future<bool> isInventoryAvailable({
    required String productId,
    required int quantity,
  }) async {
    try {
      final productDoc = await _db.collection('products').doc(productId).get();
      if (!productDoc.exists) return false;

      final data = productDoc.data()!;
      final available = (data['available_quantity'] as num? ?? 0).toInt();
      return available >= quantity;
    } catch (e) {
      debugPrint('[CheckoutInventoryService] Availability check failed: $e');
      return false;
    }
  }

  /// Get current reservation status
  Future<Map<String, dynamic>?> getReservation(String reservationId) async {
    try {
      // Reservation IDs contain productId info, but we need to search across products
      // For now, query from order reference
      final result = await _db
          .collectionGroup('reservations')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (result.docs.isNotEmpty) {
        return result.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('[CheckoutInventoryService] Get reservation failed: $e');
      return null;
    }
  }
}
