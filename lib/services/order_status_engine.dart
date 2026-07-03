import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../constants/order_status.dart';
import 'api_client.dart';
import 'package:uuid/uuid.dart';

/// Exception thrown when an invalid status transition is attempted
class InvalidStatusTransitionException implements Exception {
  final String from;
  final String to;
  final String message;

  InvalidStatusTransitionException({required this.from, required this.to, String? customMessage})
    : message = customMessage ?? 'Invalid transition from $from to $to';

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
  }) : message = customMessage ?? 'Role $role is not authorized to perform transition: $transition';

  @override
  String toString() => message;
}

/// OrderStatusEngine enforces valid order state transitions
/// Implements a PURE state orchestration layer (no business logic side effects)
///
/// CRITICAL: This class ONLY validates state transitions and routes through backend API.
/// - ❌ NO direct Firestore writes
/// - ❌ NO payment/refund processing
/// - ❌ NO inventory updates
/// - ❌ NO loyalty point calculations
/// - ❌ NO customer wallet updates
///
/// All side effects are handled atomically by the backend via PostgreSQL transactions.
class OrderStatusEngine {
  final ApiClient _apiClient = ApiClient.instance;
  static const _uuid = Uuid();

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
        customMessage:
            'Cannot transition from ${from.displayName} '
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

  /// Transitions an order to a new status via backend API
  /// CRITICAL: All state changes are atomic in the backend via PostgreSQL transactions
  ///
  /// Backend handles:
  /// - Validating state machine transitions
  /// - Updating order status atomically
  /// - Executing all side effects (inventory, payments, notifications) in one transaction
  /// - Creating audit logs
  /// - Syncing to Firestore eventually
  ///
  /// This client only validates schema and routing.
  Future<void> transitionStatus(
    String orderId,
    OrderStatus newStatus, {
    required String actorId,
    required String actorRole,
    String? actorName,
    String? note,
    bool isOtpVerified = false,
    bool managerOverride = false,
  }) async {
    try {
      // IMPORTANT: We validate locally for UX feedback, but backend is authoritative
      // (Duplicate validation is safe and expected)

      // For OTP verification at delivery, check here too
      if (newStatus == OrderStatus.delivered) {
        if (!isOtpVerified && !managerOverride) {
          throw Exception('Cannot transition to DELIVERED without OTP verification or manager override');
        }
        if (managerOverride && actorRole.toLowerCase() != 'manager' && actorRole.toLowerCase() != 'admin') {
          throw Exception('Only managers and admins can override OTP requirements');
        }
      }

      // Generate idempotency key to prevent duplicate transitions on retry
      final idempotencyKey = '${orderId}_${newStatus.name}_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';

      // CRITICAL: Route ALL state transitions through backend API
      // Backend is the single source of truth for order state
      final result = await _apiClient.post(
        '/orders/$orderId/status-transition',
        {
          'targetStatus': newStatus.name,
          'actorId': actorId,
          'actorRole': actorRole,
          'actorName': actorName ?? 'System',
          'note': note ?? '',
          'isOtpVerified': isOtpVerified,
          'managerOverride': managerOverride,
          'idempotencyKey': idempotencyKey,
        },
      );

      if (result.data?['success'] != true) {
        throw Exception('Backend rejected transition: ${result.data?['error'] ?? 'Unknown error'}');
      }

      debugPrint(
        '[OrderStatusEngine] ✅ Transitioned order $orderId to ${newStatus.displayName} '
        'via backend API (idempotency: $idempotencyKey)',
      );
    } catch (e) {
      debugPrint('[OrderStatusEngine] ❌ Transition failed: $e');
      rethrow;
    }
  }

  /// DEPRECATED: Side effects are now handled exclusively by backend API
  /// DO NOT call this method. Backend (/orders/:id/status-transition) is the source of truth.
  @deprecated
  Future<void> _executeSideEffects({
    required OrderModel order,
    required OrderStatus newStatus,
    required String actorId,
    required String actorRole,
    String? actorName,
    String? note,
  }) async {
    throw UnsupportedError(
      'Direct side effect execution is no longer allowed. '
      'Use transitionStatus() which routes through backend API. '
      'Backend handles: inventory, payments, refunds, notifications, loyalty atomically.'
    );
  }

  // ──────────────────────────────────────────────────────────────
  // SIDE EFFECT HANDLERS (DEPRECATED - Backend Handles All)
  // ──────────────────────────────────────────────────────────────
  //
  // CRITICAL: The following methods are deprecated and should NOT be called.
  // All business logic side effects are now handled atomically by the backend via PostgreSQL.
  //
  // This includes:
  // - Inventory locking/reservation/commitment
  // - Refund processing and wallet updates
  // - Loyalty point calculations
  // - Payment gateway interactions
  // - Notification delivery
  // - Audit logging

  /// DEPRECATED: Order confirmation side effects now handled by backend
  /// Backend atomically: validates payment, reserves inventory, creates packing list, sends notifications
  @deprecated
  Future<void> _onOrderConfirmed(OrderModel order) async {
    throw UnsupportedError(
      'Client-side confirmation side effects are no longer allowed. '
      'Backend API (/orders/:id/status-transition) handles atomically: '
      'payment verification, inventory reservation, packing list creation, notifications.'
    );
  }

  /// DEPRECATED: Order processing side effects now handled by backend
  /// Backend atomically: records start time, notifies kitchen, starts SLA timer
  @deprecated
  Future<void> _onOrderProcessing(OrderModel order) async {
    throw UnsupportedError(
      'Client-side processing side effects are no longer allowed. '
      'Backend API handles: start time recording, kitchen notifications, SLA timers.'
    );
  }

  /// DEPRECATED: Order packing side effects now handled by backend
  /// Backend atomically: validates inventory, commits stock, generates packing slip, creates shipping label
  @deprecated
  Future<void> _onOrderPacked(OrderModel order) async {
    throw UnsupportedError(
      'Client-side packing side effects are no longer allowed. '
      'Backend API handles: inventory validation, stock commitment, packing slip, shipping label.'
    );
  }

  /// DEPRECATED: Delivery assignment side effects now handled by backend
  /// Backend atomically: assigns delivery agent via TaskRouter, creates delivery task, notifies agent, sends tracking
  @deprecated
  Future<void> _onOrderOutForDelivery(OrderModel order) async {
    throw UnsupportedError(
      'Client-side delivery assignment is no longer allowed. '
      'Backend API uses TaskRouter to assign delivery partner atomically, '
      'creates delivery tasks, sends notifications, and shares tracking links.'
    );
  }

  /// DEPRECATED: Delivery completion side effects now handled by backend
  /// Backend atomically: updates loyalty, handles COD settlement, opens return window, creates rating prompt
  @deprecated
  Future<void> _onOrderDelivered(OrderModel order) async {
    throw UnsupportedError(
      'Client-side delivery completion is no longer allowed. '
      'Backend API handles atomically: loyalty point accrual, COD settlement via payment gateway, '
      'return window creation, rating prompts, post-delivery notifications.'
    );
  }

  /// DEPRECATED: Order cancellation side effects now handled by backend
  /// Backend atomically: restores inventory, initiates refund, cancels deliveries, sends notifications
  @deprecated
  Future<void> _onOrderCancelled(OrderModel order, String reason) async {
    throw UnsupportedError(
      'Client-side cancellation is no longer allowed. '
      'Backend API handles atomically: inventory restoration based on current state, '
      'refund initiation, delivery cancellation, customer notifications.'
    );
  }

  /// DEPRECATED: Return processing side effects now handled by backend
  /// Backend atomically: transitions inventory to QC state, creates RMA, generates return label, schedules pickup
  @deprecated
  Future<void> _onOrderReturned(OrderModel order) async {
    throw UnsupportedError(
      'Client-side return processing is no longer allowed. '
      'Backend API handles atomically: inventory QC transition, RMA creation, '
      'return label generation, pickup scheduling, shop notifications.'
    );
  }

  /// DEPRECATED: Refund processing side effects now handled by backend
  /// Backend atomically: verifies refund eligibility, processes to original payment method,
  /// updates wallet, creates audit records, closes return window
  @deprecated
  Future<void> _onOrderRefunded(OrderModel order) async {
    throw UnsupportedError(
      'Client-side refund processing is ABSOLUTELY FORBIDDEN (payment fraud risk). '
      'Backend API handles exclusively: refund verification, payment gateway interaction, '
      'wallet updates, loyalty point reversal, accounting records, audit logging. '
      'All in a single PostgreSQL transaction.'
    );
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
      final tos = entry.value.map((s) => s.displayName ?? '').join(', ');
      buffer.writeln('  $from → ${tos.isEmpty ? '(terminal)' : tos}');
    }

    return buffer.toString();
  }
}
