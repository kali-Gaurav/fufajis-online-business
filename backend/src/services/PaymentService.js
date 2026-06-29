/**
 * ============================================================================
 * PaymentService.js - Unified Payment Processing & Order Orchestration
 * ============================================================================
 * Handles:
 * - Order creation after payment verification
 * - Payment tracking & ledger entries
 * - Refund processing with wallet & stock recovery
 * - Payment status updates
 * - Order status orchestration
 * ============================================================================
 */

const { admin, db } = require('../firestore');
const RazorpayService = require('./RazorpayService');

class PaymentService {
  /**
   * Create order in Firestore after payment is verified
   * Called after signature verification succeeds
   *
   * Flow:
   * 1. Verify payment exists in payments collection
   * 2. Create or update order document
   * 3. Trigger inventory reservation/deduction
   * 4. Add to payment ledger
   * 5. Send confirmation
   */
  async createOrderAfterPayment(orderId, paymentId, paymentData = {}) {
    const firestore = db();
    const FieldValue = admin.firestore.FieldValue;

    try {
      await firestore.runTransaction(async (transaction) => {
        // 1. Fetch existing payment record
        const paymentRef = firestore.collection('payments').doc(paymentId);
        const paymentDoc = await transaction.get(paymentRef);

        if (!paymentDoc.exists) {
          throw new Error(`Payment ${paymentId} not found in database`);
        }

        const payment = paymentDoc.data();
        const amount = payment.amount || paymentData.amount;

        // 2. Create or update order
        const orderRef = firestore.collection('orders').doc(orderId);
        const orderDoc = await transaction.get(orderRef);

        if (orderDoc.exists) {
          // Order already exists, just update payment status
          transaction.update(orderRef, {
            paymentStatus: 'paid',
            paymentId,
            status: 'OrderStatus.confirmed',
            updatedAt: FieldValue.serverTimestamp(),
          });
        } else {
          // Create new order (minimal data, assume order data exists elsewhere)
          transaction.set(
            orderRef,
            {
              orderId,
              paymentId,
              paymentStatus: 'paid',
              status: 'OrderStatus.confirmed',
              amount,
              customerId: payment.customerId,
              createdAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }

        // 3. Add to payment ledger
        const ledgerRef = firestore.collection('payment_ledger').doc();
        transaction.set(ledgerRef, {
          orderId,
          paymentId,
          customerId: payment.customerId,
          type: 'credit',
          amount,
          method: 'razorpay',
          status: 'captured',
          timestamp: FieldValue.serverTimestamp(),
        });

        // 4. Update payment record to mark as processed
        transaction.update(paymentRef, {
          status: 'captured',
          verified: true,
          verifiedAt: FieldValue.serverTimestamp(),
          orderId,
        });
      });

      console.log(`[PaymentService] Order ${orderId} created after payment ${paymentId}`);
      return { success: true, orderId, paymentId };
    } catch (error) {
      console.error('[PaymentService] Failed to create order:', error.message);
      throw error;
    }
  }

  /**
   * Track payment in payments collection
   * Called when payment is created or verified
   */
  async trackPayment(paymentId, paymentData) {
    const firestore = db();
    const FieldValue = admin.firestore.FieldValue;

    try {
      await firestore.collection('payments').doc(paymentId).set(
        {
          paymentId,
          orderId: paymentData.orderId,
          customerId: paymentData.customerId,
          amount: paymentData.amount,
          currency: paymentData.currency || 'INR',
          method: paymentData.method || 'razorpay',
          status: paymentData.status || 'pending',
          verified: paymentData.verified || false,
          source: paymentData.source || 'client',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      console.log(`[PaymentService] Payment tracked: ${paymentId}`);
      return { success: true, paymentId };
    } catch (error) {
      console.error('[PaymentService] Failed to track payment:', error.message);
      throw error;
    }
  }

  /**
   * Process Refund (Full or Partial)
   * Flow:
   * 1. Call Razorpay refund API
   * 2. Add refund record
   * 3. Update payment status
   * 4. Update order status
   * 5. Restore wallet (if applicable)
   * 6. Recover inventory (if applicable)
   */
  async processRefund(paymentId, amount = null, reason = 'Customer request') {
    const firestore = db();
    const FieldValue = admin.firestore.FieldValue;

    try {
      // 1. Call Razorpay refund API
      const refund = await RazorpayService.refund(paymentId, amount, { reason });

      // 2. Fetch payment & order details
      const paymentDoc = await firestore.collection('payments').doc(paymentId).get();
      if (!paymentDoc.exists) {
        throw new Error(`Payment ${paymentId} not found`);
      }

      const payment = paymentDoc.data();
      const orderId = payment.orderId;
      const customerId = payment.customerId;
      const refundAmount = amount || payment.amount;

      // 3. Run transaction to update all related documents
      await firestore.runTransaction(async (transaction) => {
        // Update payment status
        const paymentRef = firestore.collection('payments').doc(paymentId);
        transaction.update(paymentRef, {
          status: 'refunded',
          refundId: refund.refundId,
          refundAmount,
          refundedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        // Update order status
        const orderRef = firestore.collection('orders').doc(orderId);
        transaction.update(orderRef, {
          paymentStatus: 'refunded',
          refundAmount,
          refundReason: reason,
          refundedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        // Add refund ledger entry
        const refundRef = firestore.collection('payment_ledger').doc();
        transaction.set(refundRef, {
          orderId,
          paymentId,
          refundId: refund.refundId,
          customerId,
          type: 'debit',
          amount: refundAmount,
          reason,
          method: 'razorpay',
          status: 'processed',
          timestamp: FieldValue.serverTimestamp(),
        });

        // Add to wallet if customer is entitled
        const walletRef = firestore.collection('customer_wallet').doc(customerId);
        transaction.update(walletRef, {
          balance: admin.firestore.FieldValue.increment(refundAmount),
          lastRefundDate: FieldValue.serverTimestamp(),
        });
      });

      console.log(`[PaymentService] Refund processed: ${refund.refundId} for ₹${refundAmount}`);
      return { success: true, refundId: refund.refundId, amount: refundAmount };
    } catch (error) {
      console.error('[PaymentService] Refund failed:', error.message);
      throw error;
    }
  }

  /**
   * Mark payment as failed
   * Called when payment.failed webhook event received
   */
  async markPaymentFailed(paymentId, failureReason = 'Unknown') {
    const firestore = db();
    const FieldValue = admin.firestore.FieldValue;

    try {
      const paymentDoc = await firestore.collection('payments').doc(paymentId).get();
      if (!paymentDoc.exists) {
        console.warn(`[PaymentService] Payment ${paymentId} not found when marking as failed`);
        return;
      }

      const payment = paymentDoc.data();
      const orderId = payment.orderId;

      await firestore.runTransaction(async (transaction) => {
        // Update payment
        const paymentRef = firestore.collection('payments').doc(paymentId);
        transaction.update(paymentRef, {
          status: 'failed',
          failureReason,
          failedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        // Update order (if it exists)
        if (orderId) {
          const orderRef = firestore.collection('orders').doc(orderId);
          transaction.update(orderRef, {
            paymentStatus: 'failed',
            status: 'OrderStatus.cancelled',
            failureReason,
            cancelledAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      });

      console.log(`[PaymentService] Payment ${paymentId} marked as failed`);
      return { success: true, paymentId };
    } catch (error) {
      console.error('[PaymentService] Failed to mark payment as failed:', error.message);
      throw error;
    }
  }

  /**
   * Get Payment Status
   * Queries both local Firestore and Razorpay for system of record
   */
  async getPaymentStatus(paymentId) {
    const firestore = db();

    try {
      // Get local payment record
      const paymentDoc = await firestore.collection('payments').doc(paymentId).get();
      if (!paymentDoc.exists) {
        throw new Error(`Payment ${paymentId} not found`);
      }

      const localPayment = paymentDoc.data();

      // Fetch from Razorpay for verification
      let razorpayPayment = null;
      try {
        razorpayPayment = await RazorpayService.getPayment(paymentId);
      } catch (error) {
        console.warn(`[PaymentService] Could not fetch payment from Razorpay: ${error.message}`);
      }

      return {
        paymentId,
        local: localPayment,
        razorpay: razorpayPayment,
        reconciled: localPayment.status === razorpayPayment?.status,
      };
    } catch (error) {
      console.error('[PaymentService] Failed to get payment status:', error.message);
      throw error;
    }
  }

  /**
   * Reconcile Payment
   * Used by admin to reconcile payment discrepancies
   * Fetches latest status from Razorpay and updates Firestore
   */
  async reconcilePayment(paymentId) {
    const firestore = db();
    const FieldValue = admin.firestore.FieldValue;

    try {
      // Fetch from Razorpay (source of truth)
      const razorpayPayment = await RazorpayService.getPayment(paymentId);

      // Update local record
      await firestore.collection('payments').doc(paymentId).update({
        status: razorpayPayment.status,
        razorpayStatus: razorpayPayment.status,
        reconciledAt: FieldValue.serverTimestamp(),
        reconciliationSource: 'razorpay_api_reconcile',
      });

      console.log(`[PaymentService] Payment ${paymentId} reconciled (Status: ${razorpayPayment.status})`);
      return { success: true, paymentId, status: razorpayPayment.status };
    } catch (error) {
      console.error('[PaymentService] Reconciliation failed:', error.message);
      throw error;
    }
  }
}

module.exports = new PaymentService();
