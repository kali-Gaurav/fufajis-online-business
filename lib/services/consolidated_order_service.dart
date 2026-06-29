import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';

/// Consolidated Order Service
/// Single unified order engine consolidating multiple competitors (Task #13 FIX)
///
/// CRITICAL FIX: Audit found 4 separate order services:
/// 1. OrderService (LIVE) - main service
/// 2. OrderService2 (DUPLICATE) - unused variant
/// 3. QuickOrderService (UNUSED) - was for quick checkout
/// 4. LegacyOrderEngine (DEPRECATED) - old implementation
///
/// This service unifies all into single implementation with feature flags.
/// DELETE: OrderService2, QuickOrderService, LegacyOrderEngine files
/// CONSOLIDATE: All logic into OrderService with optional parameters
class ConsolidatedOrderService {
  static final ConsolidatedOrderService _instance = ConsolidatedOrderService._internal();
  factory ConsolidatedOrderService() => _instance;
  ConsolidatedOrderService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Create order with optional quick checkout
  /// Replaces: OrderService.createOrder(), QuickOrderService, OrderService2.createOrder()
  ///
  /// Parameters:
  /// - order: OrderModel with all required data
  /// - isQuickCheckout: Skip address selection (use saved address)
  /// - paymentMethod: 'card', 'wallet', 'cod', 'upi'
  /// - skipInventoryReservation: For urgent orders (not recommended)
  Future<Map<String, dynamic>> createOrder({
    required OrderModel order,
    required String paymentMethod,
    bool isQuickCheckout = false,
    bool skipInventoryReservation = false,
  }) async {
    try {
      // Validate order
      if (order.items.isEmpty) {
        throw Exception('Order must contain at least one item');
      }

      if (order.totalAmount.toDouble() <= 0) {
        throw Exception('Order total must be greater than 0');
      }

      // Quick checkout validation
      if (isQuickCheckout && order.deliveryAddress.latitude == 0) {
        throw Exception('Quick checkout requires saved delivery address');
      }

      debugPrint(
        '[ConsolidatedOrderService] Creating order '
        '(quickCheckout: $isQuickCheckout, paymentMethod: $paymentMethod)'
      );

      // Create order in Firestore
      await _db.runTransaction((transaction) async {
        final orderRef = _db.collection('orders').doc(order.id);

        // Validate no duplicate
        final existing = await transaction.get(orderRef);
        if (existing.exists) {
          throw Exception('Order ${order.id} already exists');
        }

        // Add metadata for consolidation tracking
        final orderData = order.toMap();
        orderData.addAll({
          'consolidatedEngine': true,
          'isQuickCheckout': isQuickCheckout,
          'paymentMethod': paymentMethod,
          'createdAt': FieldValue.serverTimestamp(),
          'version': 2, // Consolidated version
        });

        transaction.set(orderRef, orderData);

        // Inventory deduction (if not skipped)
        if (!skipInventoryReservation) {
          for (var item in order.items) {
            final productRef = _db.collection('products').doc(item.productId);
            final productSnap = await transaction.get(productRef);

            if (productSnap.exists) {
              final data = productSnap.data()!;
              final currentStock = (data['stockQuantity'] as num? ?? 0).toInt();

              if (currentStock >= item.quantity) {
                transaction.update(productRef, {
                  'stockQuantity': currentStock - item.quantity,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              } else {
                throw Exception(
                  'Insufficient stock for ${item.productName} '
                  '(available: $currentStock, ordered: ${item.quantity})'
                );
              }
            }
          }
        }
      });

      return {
        'success': true,
        'orderId': order.id,
        'orderNumber': order.orderNumber,
        'message': isQuickCheckout ? 'Quick order placed successfully' : 'Order placed successfully',
      };
    } catch (e) {
      debugPrint('[ConsolidatedOrderService] Create order failed: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get order details
  Future<OrderModel?> getOrder(String orderId) async {
    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (!doc.exists) return null;
      return OrderModel.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('[ConsolidatedOrderService] Get order failed: $e');
      return null;
    }
  }

  /// Get customer orders
  Stream<List<OrderModel>> getCustomerOrders(String customerId) {
    return _db
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.data()))
            .toList());
  }

  /// Update order status
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[ConsolidatedOrderService] Update status failed: $e');
      return false;
    }
  }

  /// Cancel order
  Future<bool> cancelOrder({
    required String orderId,
    required String customerId,
    String? reason,
  }) async {
    try {
      await _db.runTransaction((transaction) async {
        final orderRef = _db.collection('orders').doc(orderId);
        final orderSnap = await transaction.get(orderRef);

        if (!orderSnap.exists) {
          throw Exception('Order not found');
        }

        final orderData = orderSnap.data()!;
        final currentStatus = orderData['status'] as String?;

        // Validate can cancel
        final terminalStatuses = ['delivered', 'cancelled', 'refunded'];
        if (terminalStatuses.contains(currentStatus)) {
          throw Exception('Cannot cancel order in $currentStatus status');
        }

        // Restore inventory
        final items = orderData['items'] as List? ?? [];
        for (var item in items) {
          final productId = item['productId'] as String;
          final qty = (item['quantity'] as num).toInt();
          final productRef = _db.collection('products').doc(productId);
          final productSnap = await transaction.get(productRef);

          if (productSnap.exists) {
            final currentStock = (productSnap.data()?['stockQuantity'] as num? ?? 0).toInt();
            transaction.update(productRef, {
              'stockQuantity': currentStock + qty,
            });
          }
        }

        // Mark cancelled
        transaction.update(orderRef, {
          'status': 'cancelled',
          'cancelledReason': reason,
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': customerId,
        });
      });

      debugPrint('[ConsolidatedOrderService] Order $orderId cancelled');
      return true;
    } catch (e) {
      debugPrint('[ConsolidatedOrderService] Cancel order failed: $e');
      return false;
    }
  }

  /// List all orders (admin only)
  Future<List<OrderModel>> getAllOrders({
    int limit = 100,
    String? status,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db.collection('orders');

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[ConsolidatedOrderService] Get all orders failed: $e');
      return [];
    }
  }

  /// DEPRECATED: Old separate methods (kept for reference)
  @deprecated
  Future<Map<String, dynamic>> createQuickOrder() async {
    // OLD QuickOrderService - CONSOLIDATED
    throw UnimplementedError('Use createOrder() with isQuickCheckout: true');
  }

  @deprecated
  Future<Map<String, dynamic>> createOrderService2Style() async {
    // OLD OrderService2 - CONSOLIDATED
    throw UnimplementedError('Use createOrder() directly');
  }

  @deprecated
  Future<Map<String, dynamic>> createLegacyOrder() async {
    // OLD LegacyOrderEngine - CONSOLIDATED
    throw UnimplementedError('Use createOrder() with appropriate flags');
  }
}
