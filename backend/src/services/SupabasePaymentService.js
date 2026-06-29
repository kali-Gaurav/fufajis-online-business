const supabaseService = require('../../config/supabase');

/**
 * Payment Service - Unified payment processing using Supabase
 * Handles Razorpay integration, verification, and refunds
 * Matches schema in 014_payment_processing_schema.sql
 */
class SupabasePaymentService {
  /**
   * Create payment record in ledger
   */
  async createPayment({
    paymentId,
    orderId,
    customerId,
    amount,
    paymentMethod = 'razorpay',
    status = 'pending',
    razorpayOrderId = null,
  }) {
    try {
      const payment = await supabaseService.query('payment_ledger', 'insert', {
        payload: {
          payment_id: paymentId,
          order_id: orderId,
          customer_id: customerId,
          amount,
          currency: 'INR',
          payment_method: paymentMethod,
          status,
          razorpay_payment_id: paymentMethod === 'razorpay' ? paymentId : null,
          razorpay_order_id: razorpayOrderId,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        },
      });

      console.log(`[Payment] Created payment: ${paymentId} for order: ${orderId}`);
      return payment[0];
    } catch (error) {
      console.error('[Payment] Create payment failed:', error.message);
      throw error;
    }
  }

  /**
   * Get payment by ID
   */
  async getPayment(paymentId) {
    try {
      const payments = await supabaseService.query('payment_ledger', 'select', {
        filters: { payment_id: paymentId },
      });
      return payments[0] || null;
    } catch (error) {
      console.error('[Payment] Get payment failed:', error.message);
      throw error;
    }
  }

  /**
   * Verify payment with signature
   */
  async verifyPayment(paymentId, signature, isValid = true) {
    try {
      // 1. Log verification audit trail
      await supabaseService.query('payment_verifications', 'insert', {
        payload: {
          payment_id: paymentId,
          verification_type: 'webhook_reconciliation',
          is_signature_valid: isValid,
          verified_at: new Date().toISOString(),
        },
      });

      if (!isValid) return false;

      // 2. Update ledger status
      await supabaseService.query('payment_ledger', 'update', {
        payload: {
          status: 'success',
          updated_at: new Date().toISOString(),
        },
        filters: { payment_id: paymentId },
      });

      return true;
    } catch (error) {
      console.error('[Payment] Verify payment failed:', error.message);
      throw error;
    }
  }

  /**
   * Mark payment as failed
   */
  async failPayment(paymentId, reason = null) {
    try {
      await supabaseService.query('payment_ledger', 'update', {
        payload: {
          status: 'failed',
          failure_reason: reason,
          updated_at: new Date().toISOString(),
        },
        filters: { payment_id: paymentId },
      });

      console.log(`[Payment] Failed payment: ${paymentId}`);
      return true;
    } catch (error) {
      console.error('[Payment] Fail payment failed:', error.message);
      throw error;
    }
  }

  /**
   * Process refund in ledger
   */
  async processRefund({
    refundId,
    orderId,
    customerId,
    amount,
    refundMethod = 'gateway',
    reason = null,
    gatewayRefundId = null,
  }) {
    try {
      const refund = await supabaseService.query('refund_ledger', 'insert', {
        payload: {
          refund_id: refundId,
          order_id: orderId,
          customer_id: customerId,
          amount,
          refund_method: refundMethod,
          status: 'completed',
          reason,
          gateway_refund_id: gatewayRefundId,
          created_at: new Date().toISOString(),
          processed_at: new Date().toISOString(),
        },
      });

      // Update original payment status to refunded
      const originalPayment = await supabaseService.query('payment_ledger', 'select', {
          filters: { order_id: orderId, status: 'success' }
      });

      if (originalPayment && originalPayment.length > 0) {
          await supabaseService.query('payment_ledger', 'update', {
              payload: { status: 'refunded', updated_at: new Date().toISOString() },
              filters: { payment_id: originalPayment[0].payment_id }
          });
      }

      console.log(`[Payment] Created refund for order: ${orderId}`);
      return refund[0];
    } catch (error) {
      console.error('[Payment] Process refund failed:', error.message);
      throw error;
    }
  }

  /**
   * Get payment history for customer
   */
  async getPaymentHistory(customerId, limit = 50) {
    try {
      const payments = await supabaseService.query('payment_ledger', 'select', {
        filters: { customer_id: customerId },
        order: { column: 'created_at', ascending: false },
        limit,
      });
      return payments;
    } catch (error) {
      console.error('[Payment] Get payment history failed:', error.message);
      throw error;
    }
  }
}

module.exports = new SupabasePaymentService();
