/**
 * OrderStatus.js - Single Source of Truth for Order Status Values (Backend)
 *
 * This file defines all valid order statuses for backend API.
 * Must be kept in sync with Dart enum in lib/models/order_status.dart
 * and Postgres enum in database migrations.
 *
 * Usage in routes:
 * const { PENDING, CONFIRMED, PACKED } = require('../constants/OrderStatus');
 *
 * Then use in queries:
 * db.collection('orders').where('status', '==', OrderStatus.PACKED)
 */

const OrderStatus = Object.freeze({
  // Order created but not yet confirmed by shop
  PENDING: 'pending',

  // Shop owner confirmed order; items assigned to kitchen
  CONFIRMED: 'confirmed',

  // Kitchen is processing/preparing items
  PROCESSING: 'processing',

  // Items are packed and ready for pickup
  PACKED: 'packed',

  // With delivery rider, en route to customer
  OUT_FOR_DELIVERY: 'out_for_delivery',

  // Successfully delivered to customer
  DELIVERED: 'delivered',

  // Customer confirmed receipt and order complete
  COMPLETED: 'completed',

  // Customer requested order cancellation
  CANCEL_REQUESTED: 'cancel_requested',

  // Order was cancelled (refund in progress or completed)
  CANCELLED: 'cancelled',

  // Customer initiated refund request
  REFUND_REQUESTED: 'refund_requested',

  // Refund was approved by shop owner
  REFUND_APPROVED: 'refund_approved',

  // Refund amount credited to customer wallet
  REFUND_COMPLETED: 'refund_completed',
});

/**
 * Get display name for status (customer-facing UI)
 */
function getDisplayName(status) {
  const displayNames = {
    [OrderStatus.PENDING]: 'Order Placed',
    [OrderStatus.CONFIRMED]: 'Confirmed',
    [OrderStatus.PROCESSING]: 'Preparing',
    [OrderStatus.PACKED]: 'Packed',
    [OrderStatus.OUT_FOR_DELIVERY]: 'Out for Delivery',
    [OrderStatus.DELIVERED]: 'Delivered',
    [OrderStatus.COMPLETED]: 'Completed',
    [OrderStatus.CANCEL_REQUESTED]: 'Cancellation Requested',
    [OrderStatus.CANCELLED]: 'Cancelled',
    [OrderStatus.REFUND_REQUESTED]: 'Refund Requested',
    [OrderStatus.REFUND_APPROVED]: 'Refund Approved',
    [OrderStatus.REFUND_COMPLETED]: 'Refund Completed',
  };
  return displayNames[status] || 'Unknown Status';
}

/**
 * Get emoji emoji for status
 */
function getEmoji(status) {
  const emojis = {
    [OrderStatus.PENDING]: '⏳',
    [OrderStatus.CONFIRMED]: '✅',
    [OrderStatus.PROCESSING]: '👨‍🍳',
    [OrderStatus.PACKED]: '📦',
    [OrderStatus.OUT_FOR_DELIVERY]: '🚴',
    [OrderStatus.DELIVERED]: '🎉',
    [OrderStatus.COMPLETED]: '⭐',
    [OrderStatus.CANCEL_REQUESTED]: '❌',
    [OrderStatus.CANCELLED]: '🚫',
    [OrderStatus.REFUND_REQUESTED]: '💰',
    [OrderStatus.REFUND_APPROVED]: '✅',
    [OrderStatus.REFUND_COMPLETED]: '🎁',
  };
  return emojis[status] || '❓';
}

/**
 * Check if order can be cancelled at current status
 */
function canBeCancelled(status) {
  const cancellableStates = [
    OrderStatus.PENDING,
    OrderStatus.CONFIRMED,
    OrderStatus.PROCESSING,
    OrderStatus.PACKED,
  ];
  return cancellableStates.includes(status);
}

/**
 * Check if refund is in progress or completed
 */
function isRefundInProgress(status) {
  const refundStates = [
    OrderStatus.REFUND_REQUESTED,
    OrderStatus.REFUND_APPROVED,
    OrderStatus.REFUND_COMPLETED,
  ];
  return refundStates.includes(status);
}

/**
 * Check if refund has been completed
 */
function isRefunded(status) {
  return status === OrderStatus.REFUND_COMPLETED;
}

/**
 * Check if order has been delivered
 */
function isDelivered(status) {
  const deliveredStates = [
    OrderStatus.DELIVERED,
    OrderStatus.COMPLETED,
  ];
  return deliveredStates.includes(status);
}

/**
 * Check if order is still in fulfillment (not delivered/cancelled)
 */
function isFulfilling(status) {
  const fulfillingStates = [
    OrderStatus.PENDING,
    OrderStatus.CONFIRMED,
    OrderStatus.PROCESSING,
    OrderStatus.PACKED,
    OrderStatus.OUT_FOR_DELIVERY,
  ];
  return fulfillingStates.includes(status);
}

/**
 * Get all valid status values
 */
function getAllStatuses() {
  return Object.values(OrderStatus);
}

/**
 * Validate status value
 * Returns true if valid, false otherwise
 */
function isValidStatus(status) {
  return Object.values(OrderStatus).includes(status);
}

/**
 * Get valid next statuses for state machine
 * Returns array of valid transitions from current status
 */
function getValidNextStatuses(currentStatus) {
  const transitions = {
    [OrderStatus.PENDING]: [
      OrderStatus.CONFIRMED,
      OrderStatus.CANCELLED,
    ],
    [OrderStatus.CONFIRMED]: [
      OrderStatus.PROCESSING,
      OrderStatus.CANCELLED,
    ],
    [OrderStatus.PROCESSING]: [
      OrderStatus.PACKED,
      OrderStatus.CANCELLED,
    ],
    [OrderStatus.PACKED]: [
      OrderStatus.OUT_FOR_DELIVERY,
      OrderStatus.CANCELLED,
    ],
    [OrderStatus.OUT_FOR_DELIVERY]: [
      OrderStatus.DELIVERED,
    ],
    [OrderStatus.DELIVERED]: [
      OrderStatus.COMPLETED,
      OrderStatus.REFUND_REQUESTED,
    ],
    [OrderStatus.COMPLETED]: [
      OrderStatus.REFUND_REQUESTED,
    ],
    [OrderStatus.CANCEL_REQUESTED]: [
      OrderStatus.CANCELLED,
    ],
    [OrderStatus.CANCELLED]: [
      OrderStatus.REFUND_REQUESTED,
    ],
    [OrderStatus.REFUND_REQUESTED]: [
      OrderStatus.REFUND_APPROVED,
    ],
    [OrderStatus.REFUND_APPROVED]: [
      OrderStatus.REFUND_COMPLETED,
    ],
    [OrderStatus.REFUND_COMPLETED]: [],
  };

  return transitions[currentStatus] || [];
}

/**
 * Validate status transition
 * Returns true if transition is allowed, false otherwise
 */
function isValidTransition(currentStatus, nextStatus) {
  const validNext = getValidNextStatuses(currentStatus);
  return validNext.includes(nextStatus);
}

module.exports = {
  // Enum values
  ...OrderStatus,

  // Helper functions
  getDisplayName,
  getEmoji,
  canBeCancelled,
  isRefundInProgress,
  isRefunded,
  isDelivered,
  isFulfilling,
  getAllStatuses,
  isValidStatus,
  getValidNextStatuses,
  isValidTransition,

  // Export the full enum for reference
  OrderStatus,
};

/**
 * Example usage in routes:
 *
 * const OrderStatus = require('../constants/OrderStatus');
 *
 * // Using enum values
 * db.collection('orders').where('status', '==', OrderStatus.PACKED)
 *
 * // Using helper functions
 * if (OrderStatus.canBeCancelled(order.status)) {
 *   // Allow cancellation
 * }
 *
 * // Validating transitions
 * if (OrderStatus.isValidTransition(currentStatus, newStatus)) {
 *   await updateOrderStatus(orderId, newStatus);
 * } else {
 *   throw new Error(`Invalid transition from ${currentStatus} to ${newStatus}`);
 * }
 */
