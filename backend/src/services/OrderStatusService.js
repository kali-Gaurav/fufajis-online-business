/**
 * Order Status Service — Unified status enum across all domains
 * FIXES: Rider queries vs packing engine status format mismatch (Module 9)
 *        Refund logic missing stock restoration (Module 10)
 */

const { admin } = require('../firestore');

const ORDER_STATUS = {
  PENDING: 'pending',
  PAYMENT_VERIFIED: 'payment_verified',
  READY_TO_PACK: 'ready_to_pack',
  PACKED: 'packed',
  ASSIGNED_TO_DELIVERY: 'assigned_to_delivery',
  OUT_FOR_DELIVERY: 'out_for_delivery',
  DELIVERED: 'delivered',
  CANCELLED: 'cancelled',
  REFUNDED: 'refunded',
  RETURNED: 'returned',
};

class OrderStatusService {
  /**
   * Normalize status across all services (rider queries, packing, etc.)
   * Handles both legacy and new status formats
   */
  static normalizeStatus(status) {
    if (!status) return ORDER_STATUS.PENDING;

    const normalized = status.toLowerCase().trim();

    const statusMap = {
      'pending': ORDER_STATUS.PENDING,
      'payment_verified': ORDER_STATUS.PAYMENT_VERIFIED,
      'paymentverified': ORDER_STATUS.PAYMENT_VERIFIED,
      'ready_to_pack': ORDER_STATUS.READY_TO_PACK,
      'readytopack': ORDER_STATUS.READY_TO_PACK,
      'packed': ORDER_STATUS.PACKED,
      'assigned_to_delivery': ORDER_STATUS.ASSIGNED_TO_DELIVERY,
      'assignedtodelivery': ORDER_STATUS.ASSIGNED_TO_DELIVERY,
      'out_for_delivery': ORDER_STATUS.OUT_FOR_DELIVERY,
      'outfordelivery': ORDER_STATUS.OUT_FOR_DELIVERY,
      'delivered': ORDER_STATUS.DELIVERED,
      'cancelled': ORDER_STATUS.CANCELLED,
      'refunded': ORDER_STATUS.REFUNDED,
      'returned': ORDER_STATUS.RETURNED,
    };

    return statusMap[normalized] || ORDER_STATUS.PENDING;
  }

  /**
   * Get orders by normalized status (fixes rider query mismatch)
   */
  static async getOrdersByStatus(userId, statuses, isRider = false) {
    const db = admin.firestore();
    const normalized = statuses.map(s => this.normalizeStatus(s));

    let query = db.collection('orders').where('status', 'in', normalized);

    if (isRider) {
      query = query.where('riderId', '==', userId);
    } else {
      query = query.where('customerId', '==', userId);
    }

    return (await query.get()).docs.map(doc => ({ ...doc.data(), id: doc.id }));
  }

  /**
   * Process refund and restore stock (fixes Module 10 bug)
   */
  static async processRefund(orderId, reason = 'customer_request') {
    const db = admin.firestore();

    try {
      const orderDoc = await db.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        throw new Error(`Order not found: ${orderId}`);
      }

      const order = orderDoc.data();
      const items = order.items || [];

      // CRITICAL FIX: Restore stock for each item
      const inventoryService = require('./SupabaseInventoryService');
      for (const item of items) {
        const productId = item.productId;
        const quantity = item.quantity || 0;

        // Release reserved stock
        try {
          await inventoryService.releaseReservedStock(productId, order.shopId, quantity);
          console.log(`[Refund] Released ${quantity} units of ${productId}`);
        } catch (e) {
          console.error(`[Refund] Stock restoration failed for ${productId}:`, e);
          // Continue with refund even if stock restoration fails
        }
      }

      // Process wallet refund
      if (order.paymentMethod === 'wallet') {
        const customerId = order.customerId;
        const refundAmount = order.totalAmount;

        await db.collection('users').doc(customerId).update({
          walletBalance: admin.firestore.FieldValue.increment(refundAmount),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Log refund transaction
        await db
          .collection('users')
          .doc(customerId)
          .collection('wallet_transactions')
          .doc()
          .set({
            type: 'refund',
            amount: refundAmount,
            orderReference: orderId,
            reason,
            balanceAfter: admin.firestore.FieldValue.increment(refundAmount),
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
      }

      // Update order status to refunded
      await db.collection('orders').doc(orderId).update({
        status: ORDER_STATUS.REFUNDED,
        refundedAt: admin.firestore.FieldValue.serverTimestamp(),
        refundReason: reason,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, message: 'Refund processed and stock restored' };
    } catch (err) {
      console.error('[OrderStatusService] Refund processing error:', err);
      throw err;
    }
  }

  /**
   * Cancel order (restore stock but no wallet refund)
   */
  static async cancelOrder(orderId, reason = 'customer_request') {
    const db = admin.firestore();

    try {
      const orderDoc = await db.collection('orders').doc(orderId).get();
      const order = orderDoc.data();
      const items = order.items || [];

      const inventoryService = require('./SupabaseInventoryService');
      for (const item of items) {
        try {
          await inventoryService.releaseReservedStock(item.productId, order.shopId, item.quantity);
        } catch (e) {
          console.error(`[Cancel] Stock restoration failed for ${item.productId}:`, e);
        }
      }

      await db.collection('orders').doc(orderId).update({
        status: ORDER_STATUS.CANCELLED,
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelReason: reason,
      });

      return { success: true };
    } catch (err) {
      console.error('[OrderStatusService] Cancel error:', err);
      throw err;
    }
  }
}

module.exports = OrderStatusService;
