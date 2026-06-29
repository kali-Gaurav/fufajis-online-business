import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants/order_status.dart';
import 'inventory_ledger_service.dart';
import 'notification_service.dart';
import 'audit_service.dart';
import 'wallet_service.dart';

/// Complete order lifecycle management
/// Handles all state transitions, side effects, and guarantees
///
/// Workflow:
/// pending → confirmed → processing → packed → shipped → delivered → completed
///   ↓
/// cancelled (from any state) → refunded
///
/// Side effects:
/// - confirmed: reserve inventory, create fulfillment task, notify shop
/// - packed: deduct stock, create delivery task, notify customer
/// - shipped: update delivery task, notify customer with rider details
/// - delivered: award loyalty points, prompt for review
/// - cancelled: release inventory, process refund, restore wallet
enum OrderWorkflowStatus {
  pending,      // Just created, awaiting payment
  confirmed,    // Payment verified, inventory reserved
  processing,   // Preparing at shop
  packed,       // Ready for delivery
  shipped,      // With rider
  delivered,    // Completed
  cancelled,    // Cancelled by customer/shop
  refunded,     // Refund processed (terminal)
  completed,    // Completed (terminal)
}

class OrderWorkflowService {
  static final OrderWorkflowService _instance = OrderWorkflowService._internal();
  factory OrderWorkflowService() => _instance;
  OrderWorkflowService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final InventoryLedgerService _ledger = InventoryLedgerService();
  final NotificationService _notifications = NotificationService();
  final AuditService _audit = AuditService();
  final WalletService _wallet = WalletService();

  // State machine definition
  static const Map<String, Set<String>> validTransitions = {
    'pending': {'confirmed', 'cancelled'},
    'confirmed': {'processing', 'cancelled'},
    'processing': {'packed', 'cancelled'},
    'packed': {'shipped', 'cancelled'},
    'shipped': {'delivered', 'cancelled'},
    'delivered': {'completed', 'cancelled'},
    'completed': <String>{}, // Terminal
    'cancelled': {'refunded'}, // Must refund if paid
    'refunded': <String>{}, // Terminal
  };

  static const Set<String> terminalStatuses = {'completed', 'refunded'};

  bool isTerminal(String status) => terminalStatuses.contains(status);

  bool canTransition(String from, String to) {
    if (from == to) return false;
    return validTransitions[from]?.contains(to) ?? false;
  }

  /// Create order in pending state
  /// Does NOT deduct inventory or charge wallet yet
  Future<Map<String, dynamic>> createOrder({
    required String customerId,
    required String shopId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String? deliveryAddress,
    String? customerPhone,
    String? paymentMethod,
    String? deliveryType,
    DateTime? scheduledDeliveryDate,
    String? timeSlot,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final now = DateTime.now();
      final orderRef = _db.collection('orders').doc();
      final orderId = orderRef.id;
      final orderNumber = 'ORD-${now.millisecondsSinceEpoch}-${customerId.hashCode % 10000}';

      final orderData = {
        'id': orderId,
        'orderNumber': orderNumber,
        'customerId': customerId,
        'shopId': shopId,
        'status': OrderStatus.pending.firestoreValue,
        'items': items,
        'totalAmount': totalAmount,
        'deliveryAddress': deliveryAddress,
        'customerPhone': customerPhone,
        'paymentMethod': paymentMethod,
        'deliveryType': deliveryType ?? 'standard',
        'scheduledDeliveryDate': scheduledDeliveryDate != null ? Timestamp.fromDate(scheduledDeliveryDate) : null,
        'timeSlot': timeSlot,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': [
          {
            'status': OrderStatus.pending.firestoreValue,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': 'system',
            'reason': 'order_created',
          }
        ],
        'paymentStatus': 'pending', // pending, verified, failed
        'paymentId': null,
        'fulfillmentTaskId': null,
        'deliveryTaskId': null,
        'riderId': null,
        'metadata': metadata,
      };

      await orderRef.set(orderData);

      await _audit.log('order_created', {
        'orderId': orderId,
        'customerId': customerId,
        'shopId': shopId,
        'totalAmount': totalAmount,
        'itemCount': items.length,
      });

      debugPrint('[OrderWorkflowService] Created order $orderId for customer $customerId');
      return orderData;
    } catch (e) {
      debugPrint('[OrderWorkflowService] Failed to create order: $e');
      rethrow;
    }
  }

  /// Confirm order after payment is verified
  /// Reserves inventory, creates fulfillment task, notifies shop
  Future<void> confirmOrder({
    required String orderId,
    required String paymentId,
    String? transactionId,
  }) async {
    try {
      final orderSnap = await _db.collection('orders').doc(orderId).get();
      final orderData = orderSnap.data();

      if (orderData == null) {
        throw Exception('Order not found: $orderId');
      }

      // Validate state machine
      final currentStatus = orderData['status'] as String;
      if (!canTransition(currentStatus, 'confirmed')) {
        throw Exception('Cannot confirm order in status: $currentStatus');
      }

      final items = (orderData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final customerId = orderData['customerId'] as String;
      final shopId = orderData['shopId'] as String;
      final now = DateTime.now();

      // Reserve inventory for each item
      for (final item in items) {
        final productId = item['productId'] as String?;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;

        if (productId != null && quantity > 0) {
          await _ledger.reserve(productId, quantity, orderId);
        }
      }

      // Update order status
      await _db.collection('orders').doc(orderId).update({
        'status': OrderStatus.confirmed.firestoreValue,
        'paymentStatus': 'verified',
        'paymentId': paymentId,
        'transactionId': transactionId,
        'confirmedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': OrderStatus.confirmed.firestoreValue,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': 'payment_system',
            'reason': 'payment_verified',
          }
        ])
      });

      // Create fulfillment task (packing)
      await _db.collection('fulfillment_tasks').add({
        'orderId': orderId,
        'shopId': shopId,
        'status': 'new',
        'items': items,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Notify shop about new order
      await _notifications.notifyShop(
        shopId,
        'New order received: ${orderData['orderNumber']}',
        {
          'orderId': orderId,
          'totalAmount': orderData['totalAmount'],
          'itemCount': items.length,
        },
      );

      await _audit.log('order_confirmed', {
        'orderId': orderId,
        'customerId': customerId,
        'paymentId': paymentId,
        'reservedItemCount': items.length,
      });

      debugPrint('[OrderWorkflowService] Confirmed order $orderId');
    } catch (e) {
      debugPrint('[OrderWorkflowService] Failed to confirm order: $e');
      rethrow;
    }
  }

  /// Mark order as being processed (employee started picking)
  Future<void> markProcessing(String orderId) async {
    await _transitionOrder(
      orderId,
      OrderWorkflowStatus.processing.name,
      'employee_started_processing',
    );
  }

  /// Mark order as packed (ready for delivery)
  /// Deducts stock from inventory
  Future<void> markPacked({
    required String orderId,
    String? packingTaskId,
  }) async {
    try {
      final orderSnap = await _db.collection('orders').doc(orderId).get();
      final orderData = orderSnap.data();

      if (orderData == null) throw Exception('Order not found');

      final currentStatus = orderData['status'] as String;
      if (!canTransition(currentStatus, 'packed')) {
        throw Exception('Cannot pack order in status: $currentStatus');
      }

      final items = (orderData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final customerId = orderData['customerId'] as String;
      final now = DateTime.now();

      // Deduct stock (reserved → actual deduction)
      for (final item in items) {
        final productId = item['productId'] as String?;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;

        if (productId != null && quantity > 0) {
          await _ledger.deduct(productId, quantity, orderId);
        }
      }

      // Update order
      await _db.collection('orders').doc(orderId).update({
        'status': OrderStatus.packed.firestoreValue,
        'packedAt': Timestamp.fromDate(now),
        'packingTaskId': packingTaskId,
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': OrderStatus.packed.firestoreValue,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': 'fulfillment',
            'reason': 'packing_completed',
          }
        ])
      });

      // Notify customer
      await _notifications.notifyCustomer(
        customerId,
        'Your order is packed and ready for delivery!',
        {'orderId': orderId},
      );

      await _audit.log('order_packed', {
        'orderId': orderId,
        'itemCount': items.length,
      });

      debugPrint('[OrderWorkflowService] Marked order $orderId as packed');
    } catch (e) {
      debugPrint('[OrderWorkflowService] Failed to mark packed: $e');
      rethrow;
    }
  }

  /// Mark order as shipped (rider picked up)
  Future<void> markShipped({
    required String orderId,
    required String riderId,
    String? riderName,
    String? riderPhone,
  }) async {
    try {
      final orderSnap = await _db.collection('orders').doc(orderId).get();
      final orderData = orderSnap.data();

      if (orderData == null) throw Exception('Order not found');

      final currentStatus = orderData['status'] as String;
      if (!canTransition(currentStatus, 'shipped')) {
        throw Exception('Cannot ship order in status: $currentStatus');
      }

      final customerId = orderData['customerId'] as String;
      final now = DateTime.now();

      // Update order
      await _db.collection('orders').doc(orderId).update({
        'status': OrderStatus.shipped.firestoreValue,
        'riderId': riderId,
        'riderName': riderName,
        'riderPhone': riderPhone,
        'shippedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': OrderStatus.shipped.firestoreValue,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': 'delivery',
            'reason': 'rider_assigned',
          }
        ])
      });

      // Notify customer with rider details
      await _notifications.notifyCustomer(
        customerId,
        'Rider ${riderName ?? riderId} is on the way with your order',
        {
          'orderId': orderId,
          'riderId': riderId,
          'riderName': riderName,
          'riderPhone': riderPhone,
        },
      );

      await _audit.log('order_shipped', {
        'orderId': orderId,
        'riderId': riderId,
      });

      debugPrint('[OrderWorkflowService] Marked order $orderId as shipped');
    } catch (e) {
      debugPrint('[OrderWorkflowService] Failed to mark shipped: $e');
      rethrow;
    }
  }

  /// Mark order as delivered
  /// Awards loyalty points, prompts for review
  Future<void> markDelivered(String orderId) async {
    try {
      final orderSnap = await _db.collection('orders').doc(orderId).get();
      final orderData = orderSnap.data();

      if (orderData == null) throw Exception('Order not found');

      final currentStatus = orderData['status'] as String;
      if (!canTransition(currentStatus, 'delivered')) {
        throw Exception('Cannot deliver order in status: $currentStatus');
      }

      final customerId = orderData['customerId'] as String;
      final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0;
      final now = DateTime.now();

      // Award loyalty points
      final points = (totalAmount / 10).toInt(); // 1 point per ₹10
      if (points > 0) {
        await _db.collection('loyalty_transactions').add({
          'userId': customerId,
          'type': 'purchase',
          'points': points,
          'orderId': orderId,
          'timestamp': Timestamp.fromDate(now),
        });
      }

      // Update order
      await _db.collection('orders').doc(orderId).update({
        'status': OrderStatus.delivered.firestoreValue,
        'deliveredAt': Timestamp.fromDate(now),
        'loyaltyPointsAwarded': points,
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': OrderStatus.delivered.firestoreValue,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': 'delivery',
            'reason': 'delivered_to_customer',
          }
        ])
      });

      // Notify customer with rating prompt
      await _notifications.notifyCustomer(
        customerId,
        'Order delivered! Please rate your experience.',
        {
          'orderId': orderId,
          'pointsAwarded': points,
          'action': 'rate_order',
        },
      );

      await _audit.log('order_delivered', {
        'orderId': orderId,
        'pointsAwarded': points,
      });

      debugPrint('[OrderWorkflowService] Marked order $orderId as delivered');
    } catch (e) {
      debugPrint('[OrderWorkflowService] Failed to mark delivered: $e');
      rethrow;
    }
  }

  /// Cancel order at any stage
  /// - If confirmed: release reserved inventory
  /// - If packed/shipped: release and refund
  /// - If delivered: refund via return flow
  Future<void> cancelOrder({
    required String orderId,
    required String reason,
    String? cancelledBy, // 'customer', 'shop', 'system'
  }) async {
    try {
      final orderSnap = await _db.collection('orders').doc(orderId).get();
      final orderData = orderSnap.data();

      if (orderData == null) throw Exception('Order not found');

      final currentStatus = orderData['status'] as String;
      if (isTerminal(currentStatus)) {
        throw Exception('Cannot cancel order in terminal status: $currentStatus');
      }

      final customerId = orderData['customerId'] as String;
      final shopId = orderData['shopId'] as String;
      final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0;
      final paymentStatus = orderData['paymentStatus'] as String?;
      final items = (orderData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final now = DateTime.now();

      // Release reserved inventory
      for (final item in items) {
        final productId = item['productId'] as String?;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;

        if (productId != null && quantity > 0) {
          await _ledger.release(productId, quantity, orderId);
        }
      }

      // Process refund if payment was verified
      if (paymentStatus == 'verified' || paymentStatus == 'paid') {
        await _wallet.creditBalance(
          customerId,
          totalAmount,
          'order_cancellation',
          {'orderId': orderId, 'reason': reason},
        );
      }

      // Update order
      await _db.collection('orders').doc(orderId).update({
        'status': OrderStatus.cancelled.firestoreValue,
        'cancelReason': reason,
        'cancelledBy': cancelledBy ?? 'customer',
        'cancelledAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': OrderStatus.cancelled.firestoreValue,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': cancelledBy ?? 'customer',
            'reason': reason,
          }
        ])
      });

      // Notify customer
      await _notifications.notifyCustomer(
        customerId,
        'Order cancelled. ₹$totalAmount refunded to wallet.',
        {
          'orderId': orderId,
          'refundAmount': totalAmount,
        },
      );

      // Notify shop
      await _notifications.notifyShop(
        shopId,
        'Order ${orderData['orderNumber']} cancelled: $reason',
        {
          'orderId': orderId,
          'reason': reason,
        },
      );

      await _audit.log('order_cancelled', {
        'orderId': orderId,
        'customerId': customerId,
        'reason': reason,
        'cancelledBy': cancelledBy,
        'refundAmount': paymentStatus == 'verified' ? totalAmount : 0,
      });

      debugPrint('[OrderWorkflowService] Cancelled order $orderId: $reason');
    } catch (e) {
      debugPrint('[OrderWorkflowService] Failed to cancel order: $e');
      rethrow;
    }
  }

  /// Mark order as completed (final state after delivery)
  Future<void> markCompleted(String orderId) async {
    await _transitionOrder(
      orderId,
      OrderWorkflowStatus.completed.name,
      'order_completion',
    );
  }

  /// Internal: generic state transition with audit logging
  Future<void> _transitionOrder(
    String orderId,
    String toStatus,
    String reason,
  ) async {
    try {
      final orderSnap = await _db.collection('orders').doc(orderId).get();
      final orderData = orderSnap.data();

      if (orderData == null) throw Exception('Order not found');

      final currentStatus = orderData['status'] as String;
      if (!canTransition(currentStatus, toStatus)) {
        throw Exception('Invalid transition: $currentStatus → $toStatus');
      }

      final now = DateTime.now();

      await _db.collection('orders').doc(orderId).update({
        'status': toStatus,
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': toStatus,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': 'system',
            'reason': reason,
          }
        ])
      });

      await _audit.log('order_status_changed', {
        'orderId': orderId,
        'fromStatus': currentStatus,
        'toStatus': toStatus,
        'reason': reason,
      });

      debugPrint('[OrderWorkflowService] Transitioned order $orderId: $currentStatus → $toStatus');
    } catch (e) {
      debugPrint('[OrderWorkflowService] Failed to transition order: $e');
      rethrow;
    }
  }

  /// Get order with full workflow context
  Future<Map<String, dynamic>?> getOrder(String orderId) async {
    final snap = await _db.collection('orders').doc(orderId).get();
    return snap.data();
  }

  /// Get all orders for customer
  Future<List<Map<String, dynamic>>> getCustomerOrders(
    String customerId, {
    String? statusFilter,
    DateTime? fromDate,
    int limit = 20,
  }) async {
    var query = _db
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    if (fromDate != null) {
      query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(fromDate));
    }

    final snap = await query.limit(limit).get();
    return snap.docs.map((doc) => doc.data()).toList();
  }

  /// Get all orders for shop
  Future<List<Map<String, dynamic>>> getShopOrders(
    String shopId, {
    String? statusFilter,
    int limit = 50,
  }) async {
    var query = _db
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    final snap = await query.limit(limit).get();
    return snap.docs.map((doc) => doc.data()).toList();
  }
}
