import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../constants/order_status.dart';
import 'inventory_ledger_service.dart';
import 'wallet_order_service.dart';

/// UnifiedOrderService consolidates 4 order engines:
/// - OrderService (live, basic order creation)
/// - OrderWorkflowEngine (state machine)
/// - OrderStatusEngine (planning engine)
/// - WalletOrderService (wallet balance usage)
///
/// Single source of truth for all order operations.
class UnifiedOrderService {
  static final UnifiedOrderService _instance = UnifiedOrderService._internal();
  factory UnifiedOrderService() => _instance;
  UnifiedOrderService._internal();

  FirebaseFirestore? _customDb;
  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;

  set db(FirebaseFirestore database) => _customDb = database;

  final InventoryLedgerService _ledger = InventoryLedgerService();
  final WalletOrderService _walletOrderService = WalletOrderService();

  // Guard against duplicate rapid checkouts
  final Set<String> _activeCheckouts = {};

  // ──────────────────────────────────────────────────────────────
  // ORDER STATUS STATE MACHINE
  // ──────────────────────────────────────────────────────────────

  /// Unified status machine - delegates to OrderStatus enum
  /// All transitions now defined in OrderStatus.canTransitionTo()
  @deprecated
  static const Map<String, Set<String>> validTransitions = {
    'pending': {'confirmed', 'cancelled'},
    'confirmed': {'processing', 'cancelled'},
    'processing': {'packed', 'cancelled'},
    'packed': {'shipped', 'cancelled'},
    'shipped': {'delivered', 'cancelled'},
    'delivered': {'refunded', 'cancelled'},
    'cancelled': {'refunded'},
    'refunded': <String>{},
  };

  @deprecated
  static const Set<String> terminalStatuses = {'cancelled', 'refunded'};

  /// Check if status is terminal (use OrderStatus.isTerminal instead)
  bool isTerminal(String status) {
    return OrderStatus.fromString(status).isTerminal;
  }

  /// Check if transition is valid (use OrderStatus.canTransitionTo instead)
  bool canTransition(String from, String to) {
    final fromStatus = OrderStatus.fromString(from);
    final toStatus = OrderStatus.fromString(to);
    return fromStatus.canTransitionTo(toStatus);
  }

  // ──────────────────────────────────────────────────────────────
  // ORDER CREATION (consolidated from 4 engines)
  // ──────────────────────────────────────────────────────────────

  /// Create order - handles all 4 order types
  /// Types:
  /// 1. normal - cart → payment → delivery
  /// 2. wallet - use wallet balance (ATOMIC: stock + wallet deduction)
  /// 3. group_buy - join existing group
  /// 4. reorder - quick repeat order
  ///
  /// CRITICAL: Wallet orders are routed to WalletOrderService which handles
  /// atomic stock reservation + wallet deduction. Regular orders proceed through
  /// the normal payment flow.
  Future<OrderModel> createOrder({
    required String customerId,
    required String shopId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String orderType, // 'normal', 'wallet', 'group_buy', 'reorder'
    String? paymentMethod,
    String? groupBuyId,
    String? reorderFromOrderId,
    String? deliveryType,
    DateTime? scheduledDeliveryDate,
    String? timeSlot,
    Map<String, dynamic>? metadata,
  }) async {
    final lockKey = '${customerId}_${totalAmount}_${items.length}';

    // Guard: prevent duplicate orders from rapid taps
    if (_activeCheckouts.contains(lockKey)) {
      debugPrint('[UnifiedOrderService] Duplicate checkout blocked: $lockKey');
      throw Exception('Your order is already being placed. Please wait.');
    }
    _activeCheckouts.add(lockKey);

    try {
      // CRITICAL: Route wallet orders through WalletOrderService
      // This ensures atomic stock + wallet deduction (P0 bug fix)
      if (orderType == 'wallet') {
        debugPrint(
          '[UnifiedOrderService] Routing wallet order to WalletOrderService '
          '(customer: $customerId, amount: ₹$totalAmount)'
        );

        return await _walletOrderService.createWalletOrder(
          customerId: customerId,
          shopId: shopId,
          items: items,
          totalAmount: totalAmount,
          deliveryAddressId: metadata?['deliveryAddressId'] as String?,
          deliveryType: deliveryType,
          scheduledDeliveryDate: scheduledDeliveryDate,
          timeSlot: timeSlot,
        );
      }

      // Check for recent duplicates
      final fiveMinAgo = DateTime.now().subtract(const Duration(minutes: 5));
      final recentDuplicates = await _db
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .where('totalAmount', isEqualTo: totalAmount)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(fiveMinAgo))
          .limit(1)
          .get();

      if (recentDuplicates.docs.isNotEmpty) {
        throw Exception('Duplicate order detected. Please check your orders.');
      }

      // Validate order type
      const validTypes = ['normal', 'group_buy', 'reorder'];
      if (!validTypes.contains(orderType)) {
        throw Exception('Invalid order type: $orderType');
      }

      final now = DateTime.now();
      final orderNumber = 'ORD-${now.millisecondsSinceEpoch}-${customerId.hashCode}';
      final orderId = _db.collection('orders').doc().id;

      // Build order data
      final orderData = {
        'orderId': orderId,
        'orderNumber': orderNumber,
        'customerId': customerId,
        'shopId': shopId,
        'orderType': orderType,
        'status': OrderStatus.pending.firestoreValue,
        'items': items,
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        'deliveryType': deliveryType,
        'scheduledDeliveryDate':
            scheduledDeliveryDate != null ? Timestamp.fromDate(scheduledDeliveryDate) : null,
        'timeSlot': timeSlot,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': [
          {
            'status': OrderStatus.pending.firestoreValue,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': customerId,
          }
        ],
        if (groupBuyId != null) 'groupBuyId': groupBuyId,
        if (reorderFromOrderId != null) 'reorderFromOrderId': reorderFromOrderId,
        if (metadata != null) 'metadata': metadata,
      };

      // Type-specific logic (non-wallet orders)
      switch (orderType) {

        case 'group_buy':
          if (groupBuyId == null) {
            throw Exception('groupBuyId required for group_buy orders');
          }
          // Validate group buy exists and is active
          final groupBuy = await _db.collection('group_buys').doc(groupBuyId).get();
          if (!groupBuy.exists) {
            throw Exception('Group buy not found');
          }
          break;

        case 'reorder':
          if (reorderFromOrderId == null) {
            throw Exception('reorderFromOrderId required for reorder orders');
          }
          // Validate original order exists
          final originalOrder = await _db.collection('orders').doc(reorderFromOrderId).get();
          if (!originalOrder.exists) {
            throw Exception('Original order not found');
          }
          break;

        default:
          break;
      }

      // Write order to Firestore
      await _db.collection('orders').doc(orderId).set(orderData);

      // Create ledger entry
      await _ledger.logOrderCreation(
        orderId: orderId,
        customerId: customerId,
        amount: totalAmount,
        orderType: orderType,
      );

      return OrderModel.fromMap({...orderData, 'id': orderId});
    } finally {
      _activeCheckouts.remove(lockKey);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // STATUS TRANSITIONS
  // ──────────────────────────────────────────────────────────────

  /// Transition order through state machine
  /// Validates transition and handles side effects
  Future<void> transitionOrder({
    required String orderId,
    required String toStatus,
    String? changedByUserId,
    String? reason,
  }) async {
    try {
      // Get current order
      final orderSnap = await _db.collection('orders').doc(orderId).get();
      if (!orderSnap.exists) {
        throw Exception('Order not found: $orderId');
      }

      final orderData = orderSnap.data() as Map<String, dynamic>;
      final currentStatus = orderData['status'] as String;

      // Validate transition using unified enum
      final currentStatusEnum = OrderStatus.fromString(currentStatus);
      final nextStatusEnum = OrderStatus.fromString(toStatus);
      if (!currentStatusEnum.canTransitionTo(nextStatusEnum)) {
        throw Exception(
            'Invalid transition: $currentStatus → $toStatus for order $orderId');
      }

      final now = DateTime.now();
      final updatedData = {
        'status': nextStatusEnum.firestoreValue,
        'updatedAt': Timestamp.fromDate(now),
      };

      // Handle side effects for specific transitions
      switch (toStatus) {
        case 'confirmed':
          // Confirm payment has been captured
          updatedData['confirmedAt'] = Timestamp.fromDate(now);
          break;

        case 'processing':
          // Reserve inventory
          await _reserveInventoryForOrder(orderId, orderData);
          updatedData['processingStartedAt'] = Timestamp.fromDate(now);
          break;

        case 'packed':
          // Deduct from inventory
          await _deductInventoryForOrder(orderId, orderData);
          updatedData['packedAt'] = Timestamp.fromDate(now);
          break;

        case 'shipped':
          updatedData['shippedAt'] = Timestamp.fromDate(now);
          break;

        case 'delivered':
          updatedData['deliveredAt'] = Timestamp.fromDate(now);
          break;

        case 'cancelled':
          // Restore inventory and handle refund
          await _handleOrderCancellation(orderId, orderData);
          updatedData['cancelledAt'] = Timestamp.fromDate(now);
          break;

        case 'refunded':
          // Process refund to wallet
          await _processRefund(orderId, orderData);
          updatedData['refundedAt'] = Timestamp.fromDate(now);
          break;

        default:
          break;
      }

      // Add to status history
      final statusHistory = List<Map<String, dynamic>>.from(
          (orderData['statusHistory'] as List?) ?? []);
      statusHistory.add({
        'status': nextStatusEnum.firestoreValue,
        'timestamp': Timestamp.fromDate(now),
        'changedBy': changedByUserId,
        if (reason != null) 'reason': reason,
      });
      updatedData['statusHistory'] = statusHistory;

      // Update order
      await _db.collection('orders').doc(orderId).update(updatedData);

      // Log transition
      await _ledger.logOrderStatusChange(
        orderId: orderId,
        oldStatus: currentStatus,
        newStatus: toStatus,
      );

      debugPrint(
          '[UnifiedOrderService] Order $orderId transitioned: $currentStatus → ${nextStatusEnum.firestoreValue}');
    } catch (e) {
      debugPrint('[UnifiedOrderService] Transition failed for $orderId: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // CANCEL ORDER
  // ──────────────────────────────────────────────────────────────

  Future<void> cancelOrder({
    required String orderId,
    String? reason,
    String? cancelledBy,
  }) async {
    try {
      final orderSnap = await _db.collection('orders').doc(orderId).get();
      if (!orderSnap.exists) {
        throw Exception('Order not found: $orderId');
      }

      final orderData = orderSnap.data() as Map<String, dynamic>;
      final status = orderData['status'] as String;

      // Can only cancel from non-terminal states
      if (isTerminal(status)) {
        throw Exception('Cannot cancel order in $status state');
      }

      // Restore inventory if processing/packed
      if (status == 'processing' || status == 'packed') {
        await _restoreInventoryForOrder(orderId, orderData);
      }

      // Transition to cancelled
      await transitionOrder(
        orderId: orderId,
        toStatus: 'cancelled',
        changedByUserId: cancelledBy,
        reason: reason,
      );

      // If paid, mark for refund
      final paymentMethod = orderData['paymentMethod'] as String?;
      if (paymentMethod == 'wallet' || paymentMethod == 'card') {
        await transitionOrder(
          orderId: orderId,
          toStatus: 'refunded',
          changedByUserId: cancelledBy,
          reason: 'Cancelled by $cancelledBy',
        );
      }
    } catch (e) {
      debugPrint('[UnifiedOrderService] Cancel failed for $orderId: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // QUERIES
  // ──────────────────────────────────────────────────────────────

  /// Get current order status
  Future<String?> getOrderStatus(String orderId) async {
    try {
      final snap = await _db.collection('orders').doc(orderId).get();
      return snap.data()?['status'] as String?;
    } catch (e) {
      debugPrint('[UnifiedOrderService] Failed to get status for $orderId: $e');
      return null;
    }
  }

  /// Get full order details
  Future<OrderModel?> getOrder(String orderId) async {
    try {
      final snap = await _db.collection('orders').doc(orderId).get();
      if (!snap.exists) return null;
      return OrderModel.fromMap({...snap.data() as Map<String, dynamic>, 'id': orderId});
    } catch (e) {
      debugPrint('[UnifiedOrderService] Failed to get order $orderId: $e');
      return null;
    }
  }

  /// Get order history (status transitions)
  Future<List<Map<String, dynamic>>> getOrderHistory(String orderId) async {
    try {
      final snap = await _db.collection('orders').doc(orderId).get();
      if (!snap.exists) return [];
      final history = snap.data()?['statusHistory'] as List? ?? [];
      return history.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[UnifiedOrderService] Failed to get history for $orderId: $e');
      return [];
    }
  }

  /// Get customer's orders
  Future<List<OrderModel>> getCustomerOrders(String customerId) async {
    try {
      final snap = await _db
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs
          .map((doc) => OrderModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('[UnifiedOrderService] Failed to get orders for $customerId: $e');
      return [];
    }
  }

  /// Get orders by status
  Future<List<OrderModel>> getOrdersByStatus(String status) async {
    try {
      final snap = await _db
          .collection('orders')
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs
          .map((doc) => OrderModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('[UnifiedOrderService] Failed to get orders by status $status: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────
  // DISCOUNT APPLICATION
  // ──────────────────────────────────────────────────────────────

  /// Apply coupon/loyalty discount to order
  Future<double> applyDiscount({
    required String orderId,
    required String discountId,
    required String discountType, // 'coupon', 'loyalty'
    required double discountAmount,
  }) async {
    try {
      final orderSnap = await _db.collection('orders').doc(orderId).get();
      if (!orderSnap.exists) {
        throw Exception('Order not found: $orderId');
      }

      final orderData = orderSnap.data() as Map<String, dynamic>;
      final currentTotal = orderData['totalAmount'] as double;

      // Validate discount
      if (discountAmount > currentTotal) {
        throw Exception('Discount exceeds order total');
      }

      // Apply discount
      final newTotal = currentTotal - discountAmount;
      await _db.collection('orders').doc(orderId).update({
        'totalAmount': newTotal,
        'discount': {
          'type': discountType,
          'id': discountId,
          'amount': discountAmount,
          'appliedAt': Timestamp.fromDate(DateTime.now()),
        },
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint(
          '[UnifiedOrderService] Applied $discountType discount ₹$discountAmount to order $orderId');

      return newTotal;
    } catch (e) {
      debugPrint('[UnifiedOrderService] Failed to apply discount for $orderId: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // INTERNAL HELPERS
  // ──────────────────────────────────────────────────────────────

  /// Reserve inventory when order moves to processing
  Future<void> _reserveInventoryForOrder(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    final items = orderData['items'] as List? ?? [];
    for (var item in items) {
      final productId = item['productId'] as String?;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      if (productId != null && quantity > 0) {
        await _ledger.logInventoryReservation(
          productId: productId,
          orderId: orderId,
          quantity: quantity,
        );
      }
    }
  }

  /// Deduct from inventory when order moves to packed
  Future<void> _deductInventoryForOrder(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    final items = orderData['items'] as List? ?? [];
    for (var item in items) {
      final productId = item['productId'] as String?;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      if (productId != null && quantity > 0) {
        await _ledger.logInventoryDeduction(
          productId: productId,
          orderId: orderId,
          quantity: quantity,
        );
      }
    }
  }

  /// Restore inventory when order is cancelled
  Future<void> _restoreInventoryForOrder(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    final items = orderData['items'] as List? ?? [];
    for (var item in items) {
      final productId = item['productId'] as String?;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      if (productId != null && quantity > 0) {
        await _ledger.logInventoryRestoration(
          productId: productId,
          orderId: orderId,
          quantity: quantity,
        );
      }
    }
  }

  /// Handle order cancellation side effects
  Future<void> _handleOrderCancellation(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    final status = orderData['status'] as String;

    // Restore inventory if already reserved/deducted
    if (status == 'processing' || status == 'packed') {
      await _restoreInventoryForOrder(orderId, orderData);
    }

    // Reset delivery assignments if any
    final deliveryTaskId = orderData['deliveryTaskId'] as String?;
    if (deliveryTaskId != null) {
      await _db.collection('delivery_tasks').doc(deliveryTaskId).update({
        'status': 'cancelled',
        'cancelledAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  /// Process refund to wallet
  Future<void> _processRefund(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    final customerId = orderData['customerId'] as String;
    final totalAmount = orderData['totalAmount'] as double;
    final paymentMethod = orderData['paymentMethod'] as String?;

    // Only refund if paid
    if (paymentMethod == null || paymentMethod == 'cod') {
      return;
    }

    // Add refund to wallet
    final walletRef = _db.collection('wallets').doc(customerId);
    await walletRef.update({
      'balance': FieldValue.increment(totalAmount),
      'lastRefund': Timestamp.fromDate(DateTime.now()),
    });

    // Log refund
    await _ledger.logRefund(
      orderId: orderId,
      amount: totalAmount,
      reason: 'Refunded via payment method: $paymentMethod',
    );

    debugPrint('[UnifiedOrderService] Refunded ₹$totalAmount to wallet for order $orderId');
  }

  // Idempotency guard
}
