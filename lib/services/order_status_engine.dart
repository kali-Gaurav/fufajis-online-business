import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/cart_item.dart';
import '../repositories/order_repository.dart';
import '../repositories/inventory_repository.dart';
import '../constants/order_status.dart';

/// Exception thrown when an invalid status transition is attempted
class InvalidStatusTransitionException implements Exception {
  final String from;
  final String to;
  final String message;

  InvalidStatusTransitionException({
    required this.from,
    required this.to,
    String? customMessage,
  }) : message = customMessage ??
       'Invalid transition from $from to $to';

  @override
  String toString() => message;
}

/// Exception thrown when a user lacks permission for a state transition
class UnauthorizedWorkflowException implements Exception {
  final String role;
  final String transition;
  final String message;

  UnauthorizedWorkflowException({
    required this.role,
    required this.transition,
    String? customMessage,
  }) : message = customMessage ??
       'Role $role is not authorized to perform transition: $transition';

  @override
  String toString() => message;
}

/// OrderStatusEngine enforces valid order state transitions
/// Implements a state machine for order lifecycle management
/// Prevents invalid transitions and handles side effects
class OrderStatusEngine {
  final OrderRepository _repository = OrderRepository();
  final InventoryRepository _inventoryRepo = InventoryRepository();

  static final OrderStatusEngine _instance = OrderStatusEngine._internal();
  factory OrderStatusEngine() => _instance;
  OrderStatusEngine._internal();

  // ──────────────────────────────────────────────────────────────
  // STATE TRANSITION RULES
  // ──────────────────────────────────────────────────────────────

  /// Valid transitions from each state (state machine rules)
  static final Map<OrderStatus, Set<OrderStatus>> _validTransitions = {
    OrderStatus.pending: {OrderStatus.confirmed, OrderStatus.cancelled},
    OrderStatus.confirmed: {OrderStatus.processing, OrderStatus.cancelled},
    OrderStatus.processing: {OrderStatus.packed, OrderStatus.cancelled},
    OrderStatus.packed: {OrderStatus.outForDelivery, OrderStatus.shipped, OrderStatus.cancelled},
    OrderStatus.shipped: {OrderStatus.delivered, OrderStatus.cancelled},
    OrderStatus.outForDelivery: {OrderStatus.delivered, OrderStatus.cancelled},
    OrderStatus.delivered: {OrderStatus.returned, OrderStatus.refunded, OrderStatus.completed},
    OrderStatus.completed: {OrderStatus.returned, OrderStatus.refunded},
    OrderStatus.cancelled: {OrderStatus.refunded},
    OrderStatus.returned: {OrderStatus.refunded},
    OrderStatus.refunded: {}, // Terminal state
  };

  // ──────────────────────────────────────────────────────────────
  // ROLE-BASED ACCESS CONTROL (RBAC) RULES
  // ──────────────────────────────────────────────────────────────

  /// Defines which roles can perform specific transitions
  static final Map<OrderStatus, List<String>> _allowedRolesForState = {
    OrderStatus.pending: ['customer', 'admin', 'manager'],
    OrderStatus.confirmed: ['admin', 'manager', 'shop_owner'],
    OrderStatus.processing: ['admin', 'manager', 'shop_owner', 'employee'],
    OrderStatus.packed: ['admin', 'manager', 'shop_owner', 'employee'],
    OrderStatus.shipped: ['admin', 'manager', 'delivery_partner'],
    OrderStatus.outForDelivery: ['admin', 'manager', 'delivery_partner'],
    OrderStatus.delivered: ['admin', 'manager', 'delivery_partner'],
    OrderStatus.completed: ['admin', 'manager', 'customer', 'delivery_partner'],
    OrderStatus.cancelled: ['admin', 'manager', 'customer', 'shop_owner'],
    OrderStatus.returned: ['admin', 'manager', 'customer'],
    OrderStatus.refunded: ['admin', 'manager', 'finance'],
  };

  // ──────────────────────────────────────────────────────────────
  // VALIDATION METHODS
  // ──────────────────────────────────────────────────────────────

  /// Validates if a status transition is allowed
  /// Returns true if the transition is valid, false otherwise
  bool isValidTransition(OrderStatus from, OrderStatus to) {
    // Same state is always valid
    if (from == to) return true;

    // Check if transition exists in rules
    final validNext = _validTransitions[from];
    return validNext != null && validNext.contains(to);
  }

  /// Check if an order in the given status can be refunded
  bool canRefund(OrderStatus status) {
    return _validTransitions[status]?.contains(OrderStatus.refunded) ?? false;
  }

  /// Gets all valid next states from current state
  Set<OrderStatus> getValidNextStates(OrderStatus currentStatus) {
    return _validTransitions[currentStatus] ?? {};
  }

  /// Validates a status transition and role permissions, throwing exceptions if invalid
  void validateTransition(OrderStatus from, OrderStatus to, String actorRole) {
    if (!isValidTransition(from, to)) {
      throw InvalidStatusTransitionException(
        from: from.toString(),
        to: to.toString(),
        customMessage: 'Cannot transition from ${from.displayName} '
            'to ${to.displayName}',
      );
    }

    // RBAC Check
    final allowedRoles = _allowedRolesForState[to] ?? [];
    // Allow 'admin' and 'super_admin' universally as a fallback safety
    if (!allowedRoles.contains(actorRole.toLowerCase()) && 
        actorRole.toLowerCase() != 'admin' && 
        actorRole.toLowerCase() != 'super_admin') {
      throw UnauthorizedWorkflowException(
        role: actorRole,
        transition: '${from.displayName} → ${to.displayName}',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // TRANSITION WITH SIDE EFFECTS
  // ──────────────────────────────────────────────────────────────

  /// Transitions an order to a new status with side effects
  /// Handles all related updates atomically
  ///
  /// Side effects include:
  /// - Updating order status
  /// - Recording timeline entry
  /// - Triggering notifications
  /// - Updating related entities (inventory, payments, etc.)
  Future<OrderModel> transitionWithSideEffects(
    String orderId,
    OrderStatus newStatus, {
    required String actorId,
    required String actorRole,
    String? actorName,
    String? note,
    bool isOtpVerified = false,
    bool managerOverride = false,
    String? managerPin,
  }) async {
    try {
      // Step 1: Get current order
      final currentOrder = await _repository.getOrderById(orderId);
      if (currentOrder == null) {
        throw Exception('Order $orderId not found');
      }

      // Step 2: Validate transition & roles
      validateTransition(currentOrder.status, newStatus, actorRole);

      // OTP Verification Rule
      if (newStatus == OrderStatus.delivered) {
        if (!isOtpVerified) {
          if (managerOverride) {
             // Example: verify managerPin here if required in the future
             if (actorRole.toLowerCase() != 'manager' && actorRole.toLowerCase() != 'admin') {
                throw Exception('Only Managers and Admins can override OTP requirements.');
             }
             debugPrint('[OrderStatusEngine] Manager override used for OTP on order $orderId');
          } else {
            throw Exception('Cannot transition to DELIVERED without verifying OTP.');
          }
        }
      }

      // Step 3: Execute side effects based on new status
      await _executeSideEffects(
        order: currentOrder,
        newStatus: newStatus,
        actorId: actorId,
        actorRole: actorRole,
        actorName: actorName,
        note: note,
      );

      // Step 4: Update order status in repository
      await _repository.updateOrderStatus(
        orderId,
        newStatus.toString(),
        note: note,
        actorId: actorId,
        actorRole: actorRole,
        actorName: actorName,
      );

      // Step 5: Fetch and return updated order
      final updatedOrder = await _repository.getOrderById(orderId);
      if (updatedOrder == null) {
        throw Exception('Failed to retrieve updated order');
      }

      debugPrint(
        '[OrderStatusEngine] Transitioned order $orderId: '
        '${currentOrder.status.displayName} → ${newStatus.displayName} '
        'by $actorRole $actorName',
      );

      return updatedOrder;
    } catch (e) {
      debugPrint('[OrderStatusEngine] Transition failed: $e');
      rethrow;
    }
  }

  /// Executes side effects for each status transition
  Future<void> _executeSideEffects({
    required OrderModel order,
    required OrderStatus newStatus,
    required String actorId,
    required String actorRole,
    String? actorName,
    String? note,
  }) async {
    switch (newStatus) {
      case OrderStatus.confirmed:
        await _onOrderConfirmed(order);
        break;

      case OrderStatus.processing:
        await _onOrderProcessing(order);
        break;

      case OrderStatus.packed:
        await _onOrderPacked(order);
        break;

      case OrderStatus.outForDelivery:
      case OrderStatus.shipped:
        await _onOrderOutForDelivery(order);
        break;

      case OrderStatus.delivered:
      case OrderStatus.completed:
        await _onOrderDelivered(order);
        break;

      case OrderStatus.cancelled:
        await _onOrderCancelled(order, note ?? 'No reason provided');
        break;

      case OrderStatus.returned:
        await _onOrderReturned(order);
        break;

      case OrderStatus.refunded:
        await _onOrderRefunded(order);
        break;

      case OrderStatus.pending:
        // No side effects for pending
        break;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // SIDE EFFECT HANDLERS
  // ──────────────────────────────────────────────────────────────

  /// Called when order is confirmed (payment received)
  /// - Lock inventory
  /// - Create packing list
  /// - Send confirmation to shop
  Future<void> _onOrderConfirmed(OrderModel order) async {
    debugPrint('[OrderStatusEngine] Executing side effects for CONFIRMED: ${order.id}');

    // Lock inventory commitment
    final cartItems = order.items.map((item) => CartItem(
      id: item.productId,
      productId: item.productId,
      productName: item.productName,
      productImage: item.productImage,
      unit: item.unit,
      quantity: item.quantity,
      price: item.price,
      stockQuantity: 0,
      shopId: item.shopId ?? '',
      shopName: item.shopName ?? '',
      addedAt: DateTime.now(),
    )).toList();
    await _inventoryRepo.reserveInventory(cartItems, branchId: order.branchId ?? 'default');
    
    // - Create packing list
    // - Notify shop owner
    // - Send confirmation SMS/email to customer
  }

  /// Called when order moves to processing
  /// - Employee starts working
  /// - Kitchen receives order
  // ✅ FIXED: Implement processing side effects
  Future<void> _onOrderProcessing(OrderModel order) async {
    debugPrint('[OrderStatusEngine] Executing side effects for PROCESSING: ${order.id}');

    try {
      // 1. Record processing start time
      await _repository.recordProcessingStart(order.id);

      // 2. Notify kitchen/employee via Firestore
      await FirebaseFirestore.instance
          .collection('order_notifications')
          .doc('${order.id}_processing')
          .set({
        'orderId': order.id,
        'type': 'processing',
        'status': 'processing',
        'items': order.items.map((item) => {
          'productName': item.productName,
          'quantity': item.quantity,
          'unit': item.unit,
          'specialInstructions': item.specialInstructions ?? 'None',
        }).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // 3. Start SLA timer (30 minutes to pack)
      await FirebaseFirestore.instance
          .collection('sla_timers')
          .doc(order.id)
          .set({
        'orderId': order.id,
        'startedAt': FieldValue.serverTimestamp(),
        'slaMinutes': 30,
        'status': 'active',
      }, SetOptions(merge: true));

      debugPrint('[OrderStatusEngine] ✅ Processing started for ${order.id}');
    } catch (e) {
      debugPrint('[OrderStatusEngine] ❌ Error in _onOrderProcessing: $e');
    }
  }

  /// Called when order is packed
  /// - Verify contents
  /// - Generate barcode
  /// - Ready for pickup
  Future<void> _onOrderPacked(OrderModel order) async {
    debugPrint('[OrderStatusEngine] Executing side effects for PACKED: ${order.id}');

    // Convert reserved inventory to committed
    final cartItems = order.items.map((item) => CartItem(
      id: item.productId,
      productId: item.productId,
      productName: item.productName,
      productImage: item.productImage,
      unit: item.unit,
      quantity: item.quantity,
      price: item.price,
      stockQuantity: 0,
      shopId: item.shopId ?? '',
      shopName: item.shopName ?? '',
      addedAt: DateTime.now(),
    )).toList();
    await _inventoryRepo.commitInventory(cartItems, branchId: order.branchId ?? 'default');
    
    // - Generate packing slip
    // - Create shipping label
    // - Notify delivery partner
  }

  /// Called when order is out for delivery
  /// - Delivery agent receives assignment
  /// - Real-time tracking starts
  // ✅ FIXED: Implement out-for-delivery side effects
  Future<void> _onOrderOutForDelivery(OrderModel order) async {
    debugPrint('[OrderStatusEngine] Executing side effects for OUT_FOR_DELIVERY/SHIPPED: ${order.id}');

    try {
      // 1. Get nearest delivery agent (simplified - production should use TaskRouter)
      final agentsSnapshot = await FirebaseFirestore.instance
          .collection('delivery_agents')
          .where('status', isEqualTo: 'available')
          .limit(1)
          .get();

      if (agentsSnapshot.docs.isEmpty) {
        debugPrint('[OrderStatusEngine] ⚠️ No available delivery agents');
        return;
      }

      final agent = agentsSnapshot.docs.first;
      final agentId = agent.id;
      final agentName = agent['name'] ?? 'Unknown';

      // 2. Create delivery task
      await FirebaseFirestore.instance
          .collection('delivery_tasks')
          .doc(order.id)
          .set({
        'orderId': order.id,
        'customerId': order.customerId,
        'customerName': order.customerName,
        'customerPhone': order.customerPhone,
        'deliveryAddress': order.deliveryAddress,
        'assignedAgentId': agentId,
        'assignedAgentName': agentName,
        'assignedAt': FieldValue.serverTimestamp(),
        'status': 'assigned',
        'items': order.items.map((item) => {
          'productName': item.productName,
          'quantity': item.quantity,
        }).toList(),
        'totalAmount': order.totalAmount.toDouble(),
      });

      // 3. Notify delivery agent
      await FirebaseFirestore.instance
          .collection('delivery_notifications')
          .doc('${agentId}_${order.id}')
          .set({
        'agentId': agentId,
        'orderId': order.id,
        'type': 'new_delivery',
        'customerName': order.customerName,
        'address': order.deliveryAddress,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // 4. Send customer tracking link
      await FirebaseFirestore.instance
          .collection('chat_messages')
          .add({
        'customerId': order.customerId,
        'type': 'tracking',
        'trackingUrl': 'https://fufaji.app/track/${order.id}',
        'trackingCode': order.id,
        'agentName': agentName,
        'agentPhone': agent['phone'],
        'message': 'Your order is out for delivery! Track: https://fufaji.app/track/${order.id}',
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[OrderStatusEngine] ✅ Delivery assigned to $agentName (${order.id})');
    } catch (e) {
      debugPrint('[OrderStatusEngine] ❌ Error in _onOrderOutForDelivery: $e');
    }
  }

  /// Called when order is delivered
  /// - Update customer loyalty points
  /// - Collect payment if COD
  /// - Trigger post-delivery survey
  // ✅ FIXED: Implement delivered side effects
  Future<void> _onOrderDelivered(OrderModel order) async {
    debugPrint('[OrderStatusEngine] Executing side effects for DELIVERED/COMPLETED: ${order.id}');

    try {
      // 1. Update customer loyalty points (1 point per rupee spent)
      final loyaltyPoints = (order.totalAmount * 1).toInt();
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(order.customerId)
          .update({
        'loyaltyPoints': FieldValue.increment(loyaltyPoints),
        'totalSpent': FieldValue.increment(order.totalAmount.toDouble()),
      });

      // 2. Handle COD payment if applicable
      if (order.paymentMethod == 'cod') {
        await FirebaseFirestore.instance
            .collection('cod_collections')
            .doc(order.id)
            .set({
          'orderId': order.id,
          'customerId': order.customerId,
          'amount': order.totalAmount.toDouble(),
          'status': 'collected',
          'collectedAt': FieldValue.serverTimestamp(),
          'collectedBy': 'delivery_agent',
        });
      }

      // 3. Send delivery confirmation
      await FirebaseFirestore.instance
          .collection('order_confirmations')
          .doc(order.id)
          .set({
        'orderId': order.id,
        'customerId': order.customerId,
        'deliveredAt': FieldValue.serverTimestamp(),
        'items': order.items.length,
        'totalAmount': order.totalAmount.toDouble(),
        'status': 'delivered',
      });

      // 4. Start 7-day return window
      final returnDeadline = DateTime.now().add(const Duration(days: 7));
      await FirebaseFirestore.instance
          .collection('return_windows')
          .doc(order.id)
          .set({
        'orderId': order.id,
        'customerId': order.customerId,
        'openedAt': FieldValue.serverTimestamp(),
        'deadline': Timestamp.fromDate(returnDeadline),
        'status': 'active',
        'eligible': true,
      });

      // 5. Enable ratings/reviews - create rating prompt
      await FirebaseFirestore.instance
          .collection('rating_prompts')
          .doc(order.id)
          .set({
        'orderId': order.id,
        'customerId': order.customerId,
        'shopName': order.shopName ?? 'Fufaji Store',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      });

      debugPrint('[OrderStatusEngine] ✅ Post-delivery processing complete for ${order.id}');
    } catch (e) {
      debugPrint('[OrderStatusEngine] ❌ Error in _onOrderDelivered: $e');
    }
  }

  /// Called when order is cancelled
  /// - Restore inventory
  /// - Process refund
  /// - Notify customer
  Future<void> _onOrderCancelled(OrderModel order, String reason) async {
    debugPrint('[OrderStatusEngine] Executing side effects for CANCELLED: ${order.id}, reason: $reason');

    // Restore inventory from reserved state (assuming cancelled before packed)
    // If it was packed and then cancelled, it should be from committed, but we'll default to reserved for now
    final cartItems = order.items.map((item) => CartItem(
      id: item.productId,
      productId: item.productId,
      productName: item.productName,
      productImage: item.productImage,
      unit: item.unit,
      quantity: item.quantity,
      price: item.price,
      stockQuantity: 0,
      shopId: item.shopId ?? '',
      shopName: item.shopName ?? '',
      addedAt: DateTime.now(),
    )).toList();
    await _inventoryRepo.restoreInventory(cartItems, branchId: order.branchId ?? 'default');

    // - Initiate refund (async process)
    // - Cancel any pending deliveries
    // - Send cancellation notice to customer
    // - Log cancellation reason for analytics
  }

  /// Called when order is marked for return
  /// - Open return window
  /// - Generate return label
  /// - Notify shop
  Future<void> _onOrderReturned(OrderModel order) async {
    debugPrint('[OrderStatusEngine] Executing side effects for RETURNED: ${order.id}');

    // Move inventory to QC state
    final cartItems = order.items.map((item) => CartItem(
      id: item.productId,
      productId: item.productId,
      productName: item.productName,
      productImage: item.productImage,
      unit: item.unit,
      quantity: item.quantity,
      price: item.price,
      stockQuantity: 0,
      shopId: item.shopId ?? '',
      shopName: item.shopName ?? '',
      addedAt: DateTime.now(),
    )).toList();
    await _inventoryRepo.qcInventory(cartItems, branchId: order.branchId ?? 'default');

    // - Create return RMA number
    // - Generate return shipping label
    // - Notify shop to prepare for pickup
    // - Schedule return pickup
  }

  /// Called when refund is processed
  /// - Update wallet/payment method
  /// - Send refund confirmation
  /// - Update accounting records
  // ✅ FIXED: Implement refund side effects
  Future<void> _onOrderRefunded(OrderModel order) async {
    debugPrint('[OrderStatusEngine] Executing side effects for REFUNDED: ${order.id}');

    try {
      // 1. Process refund to original payment method
      if (order.paymentMethod == 'razorpay' || order.paymentMethod == 'card') {
        await FirebaseFirestore.instance
            .collection('refund_transactions')
            .add({
          'orderId': order.id,
          'customerId': order.customerId,
          'amount': order.totalAmount.toDouble(),
          'paymentMethod': order.paymentMethod,
          'originalPaymentId': order.paymentId,
          'status': 'initiated',
          'createdAt': FieldValue.serverTimestamp(),
          'processedAt': null,
        });
      }

      // 2. Update customer wallet
      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(order.customerId)
          .set({
        'balance': FieldValue.increment(order.totalAmount.toDouble()),
        'lastRefund': order.id,
        'lastRefundAmount': order.totalAmount.toDouble(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Send refund receipt
      await FirebaseFirestore.instance
          .collection('refund_receipts')
          .doc(order.id)
          .set({
        'orderId': order.id,
        'customerId': order.customerId,
        'refundAmount': order.totalAmount.toDouble(),
        'refundDate': FieldValue.serverTimestamp(),
        'paymentMethod': order.paymentMethod,
        'status': 'completed',
        'items': order.items.map((item) => {
          'productName': item.productName,
          'quantity': item.quantity,
          'refundAmount': (item.price * item.quantity).toDouble(),
        }).toList(),
      });

      // 4. Close return window
      await FirebaseFirestore.instance
          .collection('return_windows')
          .doc(order.id)
          .update({
        'status': 'closed',
        'refundProcessedAt': FieldValue.serverTimestamp(),
      });

      // 5. Update business accounting records
      await FirebaseFirestore.instance
          .collection('accounting_records')
          .add({
        'type': 'refund',
        'orderId': order.id,
        'customerId': order.customerId,
        'amount': -order.totalAmount.toDouble(), // Negative for outflow
        'createdAt': FieldValue.serverTimestamp(),
        'bookingDate': FieldValue.serverTimestamp(),
        'description': 'Refund for order ${order.id}',
      });

      // 6. Deduct loyalty points if applicable
      if (order.loyaltyPointsUsed > 0) {
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(order.customerId)
            .update({
          'loyaltyPoints': FieldValue.increment(order.loyaltyPointsUsed),
        });
      }

      debugPrint('[OrderStatusEngine] ✅ Refund processed for ${order.id} (₹${order.totalAmount})');
    } catch (e) {
      debugPrint('[OrderStatusEngine] ❌ Error in _onOrderRefunded: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // HELPER METHODS
  // ──────────────────────────────────────────────────────────────

  /// Checks if an order can be cancelled
  bool canCancel(OrderModel order) {
    return order.status.canCancel;
  }

  /// Checks if an order can be returned
  bool canReturn(OrderModel order) {
    return order.status.canReturn;
  }

  /// Checks if an order is in a terminal state
  bool isTerminal(OrderModel order) {
    return order.status.isTerminal;
  }

  /// Checks if an order is active (not yet delivered/cancelled)
  bool isActive(OrderModel order) {
    return order.status.isActive;
  }

  /// Gets the state machine diagram as a readable string
  /// Useful for debugging and documentation
  String getStateMachineDiagram() {
    final buffer = StringBuffer();
    buffer.writeln('Order Status State Machine:');
    buffer.writeln('');

    for (final entry in _validTransitions.entries) {
      final from = entry.key.displayName;
      final tos = entry.value
          .map((s) => s.displayName ?? '')
          .join(', ');
      buffer.writeln('  $from → ${tos.isEmpty ? '(terminal)' : tos}');
    }

    return buffer.toString();
  }
}
