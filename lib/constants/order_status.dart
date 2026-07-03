import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Unified Order Status Enum
/// Single source of truth for all order state transitions across:
/// - UnifiedOrderService
/// - OrderService
/// - OrderWorkflowService
/// - OrderWorkflowEngine
/// - PackingWorkflowService
/// - DeliveryWorkflowService
/// - UnifiedDeliveryService
///
/// This enum MUST be used everywhere instead of string literals
/// to prevent status mismatches between services.

enum OrderStatus {
  // Initial states
  pending('pending'), // Just created, awaiting payment
  confirmed('confirmed'), // Payment verified

  // Processing states
  processing('processing'), // Being prepared at shop
  packed('packed'), // Ready for pickup/delivery

  // Delivery states
  shipped('shipped'), // With rider, in transit
  outForDelivery('out_for_delivery'), // Legacy/Common name
  delivered('delivered'), // Delivered to customer

  // Terminal states
  completed('completed'), // Successfully completed
  cancelled('cancelled'), // Cancelled by customer/shop
  returned('returned'), // Returned by customer
  refunded('refunded'); // Refund processed

  final String value;
  const OrderStatus(this.value);

  /// Get string value for Firestore storage
  String get firestoreValue => value;

  /// Parse string from Firestore to enum
  static OrderStatus fromString(String? status) {
    if (status == null || status.isEmpty) return OrderStatus.pending;

    // Handle legacy 'OrderStatus.' prefix
    final normalized = status.replaceAll('OrderStatus.', '').toLowerCase();

    try {
      return OrderStatus.values.firstWhere(
        (e) => e.value == normalized || e.name == normalized,
        orElse: () => OrderStatus.pending,
      );
    } catch (e) {
      return OrderStatus.pending;
    }
  }

  /// Check if this is a terminal state (no further transitions)
  bool get isTerminal {
    return this == OrderStatus.delivered ||
        this == OrderStatus.cancelled ||
        this == OrderStatus.returned ||
        this == OrderStatus.refunded ||
        this == OrderStatus.completed;
  }

  bool get isActive {
    return this == OrderStatus.pending ||
        this == OrderStatus.confirmed ||
        this == OrderStatus.processing ||
        this == OrderStatus.packed ||
        this == OrderStatus.shipped ||
        this == OrderStatus.outForDelivery;
  }

  bool get canCancel {
    return isActive && this != OrderStatus.shipped && this != OrderStatus.outForDelivery;
  }

  bool get canReturn {
    return this == OrderStatus.delivered || this == OrderStatus.completed;
  }

  /// Get valid next statuses from current status
  Set<String> getNextStatuses() {
    const validTransitions = {
      'pending': {'confirmed', 'cancelled'},
      'confirmed': {'processing', 'cancelled'},
      'processing': {'packed', 'cancelled'},
      'packed': {'shipped', 'cancelled', 'out_for_delivery'},
      'shipped': {'delivered', 'cancelled'},
      'out_for_delivery': {'delivered', 'cancelled'},
      'delivered': {'refunded', 'cancelled', 'returned', 'completed'},
      'completed': {'refunded', 'cancelled', 'returned'},
      'cancelled': {'refunded'},
      'returned': {'refunded'},
      'refunded': <String>{},
    };

    return validTransitions[value] ?? <String>{};
  }

  /// Check if transition is valid
  bool canTransitionTo(OrderStatus nextStatus) {
    if (this == nextStatus) return false;
    return getNextStatuses().contains(nextStatus.value);
  }

  /// Get human-readable label
  String getLabel() => displayName;

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending Payment';
      case OrderStatus.confirmed:
        return 'Payment Confirmed';
      case OrderStatus.processing:
        return 'Being Prepared';
      case OrderStatus.packed:
        return 'Ready for Delivery';
      case OrderStatus.shipped:
        return 'In Transit';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.returned:
        return 'Returned';
      case OrderStatus.refunded:
        return 'Refunded';
    }
  }

  String get description {
    switch (this) {
      case OrderStatus.pending:
        return 'Order is awaiting confirmation';
      case OrderStatus.confirmed:
        return 'Order has been confirmed by the shop';
      case OrderStatus.processing:
        return 'Order is being prepared';
      case OrderStatus.packed:
        return 'Order has been packed and is ready for pickup';
      case OrderStatus.shipped:
      case OrderStatus.outForDelivery:
        return 'Order is out for delivery';
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return 'Order has been delivered';
      case OrderStatus.cancelled:
        return 'Order has been cancelled';
      case OrderStatus.returned:
        return 'Order has been returned';
      case OrderStatus.refunded:
        return 'Refund has been processed';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.pending:
        return AppTheme.warning;
      case OrderStatus.confirmed:
        return AppTheme.info;
      case OrderStatus.processing:
        return AppTheme.info;
      case OrderStatus.packed:
        return Colors.purple;
      case OrderStatus.shipped:
      case OrderStatus.outForDelivery:
        return Colors.cyan;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return AppTheme.success;
      case OrderStatus.cancelled:
        return AppTheme.error;
      case OrderStatus.returned:
        return Colors.deepOrange;
      case OrderStatus.refunded:
        return Colors.teal;
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatus.pending:
        return Icons.pending;
      case OrderStatus.confirmed:
        return Icons.check_circle;
      case OrderStatus.processing:
        return Icons.sync;
      case OrderStatus.packed:
        return Icons.inventory_2;
      case OrderStatus.shipped:
      case OrderStatus.outForDelivery:
        return Icons.local_shipping;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return Icons.home;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.returned:
        return Icons.undo;
      case OrderStatus.refunded:
        return Icons.replay;
    }
  }

  double get progressPercentage {
    switch (this) {
      case OrderStatus.pending:
        return 10;
      case OrderStatus.confirmed:
        return 25;
      case OrderStatus.processing:
        return 45;
      case OrderStatus.packed:
        return 65;
      case OrderStatus.shipped:
      case OrderStatus.outForDelivery:
        return 85;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return 100;
      case OrderStatus.cancelled:
      case OrderStatus.returned:
      case OrderStatus.refunded:
        return 0;
    }
  }
}
