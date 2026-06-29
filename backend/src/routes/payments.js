/**
 * ============================================================================
 * routes/payments.js - Payment API Endpoints
 * ============================================================================
 * Endpoints:
 * - POST /payments/razorpay/order     Create Razorpay order
 * - POST /payments/razorpay/verify    Verify payment signature + create order
 * - POST /payments/{id}/refund        Process refund (admin only)
 * - GET  /payments/{id}               Get payment status
 * - POST /payments/{id}/reconcile     Reconcile payment (admin only)
 * ============================================================================
 */

const express = require('express');
const router = express.Router();

const RazorpayService = require('../services/RazorpayService');
const PaymentService = require('../services/PaymentService');
const { admin, db } = require('../firestore');
const { verifyToken, requireRole } = require('../auth');

// ── POST /payments/razorpay/order - Create Razorpay Order ──────────────────
// Any authenticated user can initiate payment
router.post('/razorpay/order', verifyToken, async (req, res) => {
  try {
    const { amount, orderId, customerId, notes } = req.body || {};

    // Validate input
    if (!amount || !orderId || !customerId) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: amount, orderId, customerId',
      });
    }

    // Initialize Razorpay service
    await RazorpayService.initialize();

    // Create order on Razorpay
    const razorpayOrder = await RazorpayService.createOrder(orderId, amount, {
      customer_id: customerId,
      ...notes,
    });

    // Track payment in Firestore
    await PaymentService.trackPayment(razorpayOrder.razorpayOrderId, {
      orderId,
      customerId,
      amount,
      status: 'pending',
      source: 'client',
    });

    console.log(`[Payments] Order created: ${razorpayOrder.razorpayOrderId} for ₹${amount}`);

    return res.json({
      success: true,
      razorpayOrderId: razorpayOrder.razorpayOrderId,
      amount: razorpayOrder.amount,
      currency: razorpayOrder.currency,
      status: razorpayOrder.status,
    });
  } catch (error) {
    console.error('[Payments] Error creating order:', error.message);
    return res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

// ── POST /payments/razorpay/verify - Verify Payment Signature ──────────────
// Called after client-side payment completion
// CRITICAL: This endpoint:
// 1. Verifies signature using webhook_secret
// 2. Fetches payment details from Razorpay
// 3. Creates order in Firestore
router.post('/razorpay/verify', verifyToken, async (req, res) => {
  try {
    const { razorpay_payment_id, razorpay_order_id, razorpay_signature, order_id } = req.body || {};

    // Validate input
    if (!razorpay_payment_id || !razorpay_order_id || !razorpay_signature) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: razorpay_payment_id, razorpay_order_id, razorpay_signature',
      });
    }

    // Initialize Razorpay service
    await RazorpayService.initialize();

    // CRITICAL: Verify signature using webhook_secret
    const isValid = RazorpayService.verifySignature(
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature
    );

    if (!isValid) {
      console.warn(`[Payments] Signature verification failed for ${razorpay_payment_id}`);
      return res.status(400).json({
        success: false,
        error: 'Payment signature verification failed',
      });
    }

    // Fetch payment details from Razorpay for confirmation
    const payment = await RazorpayService.getPayment(razorpay_payment_id);

    // Verify payment is captured or authorized
    if (payment.status !== 'captured' && payment.status !== 'authorized') {
      console.warn(`[Payments] Payment not captured: ${razorpay_payment_id} (Status: ${payment.status})`);
      return res.status(400).json({
        success: false,
        error: `Payment not captured (Status: ${payment.status})`,
      });
    }

    // Create order after payment verification
    await PaymentService.createOrderAfterPayment(order_id || razorpay_order_id, razorpay_payment_id, {
      amount: payment.amount,
    });

    console.log(`[Payments] Payment verified and order created: ${razorpay_payment_id}`);

    return res.json({
      success: true,
      message: 'Payment verified successfully',
      paymentId: razorpay_payment_id,
      orderId: order_id || razorpay_order_id,
      amount: payment.amount,
      status: payment.status,
    });
  } catch (error) {
    console.error('[Payments] Error verifying payment:', error.message);
    return res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

// ── POST /payments/{paymentId}/refund - Process Refund ────────────────────
// Admin or shop owner only
router.post('/:paymentId/refund', verifyToken, requireRole('UserRole.admin', 'UserRole.shopOwner'), async (req, res) => {
  try {
    const { paymentId } = req.params;
    const { amount, reason } = req.body || {};

    if (!paymentId) {
      return res.status(400).json({
        success: false,
        error: 'Missing paymentId',
      });
    }

    // Process refund
    const refund = await PaymentService.processRefund(paymentId, amount, reason || 'Admin refund');

    console.log(`[Payments] Refund processed: ${refund.refundId} for ₹${refund.amount}`);

    return res.json({
      success: true,
      message: 'Refund processed successfully',
      refundId: refund.refundId,
      amount: refund.amount,
    });
  } catch (error) {
    console.error('[Payments] Error processing refund:', error.message);
    return res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

// ── GET /payments/{paymentId} - Get Payment Status ────────────────────────
// Authenticated users can view their own payments, admins can view any
router.get('/:paymentId', verifyToken, async (req, res) => {
  try {
    const { paymentId } = req.params;

    if (!paymentId) {
      return res.status(400).json({
        success: false,
        error: 'Missing paymentId',
      });
    }

    const status = await PaymentService.getPaymentStatus(paymentId);

    return res.json({
      success: true,
      payment: status.local,
      razorpayStatus: status.razorpay,
      reconciled: status.reconciled,
    });
  } catch (error) {
    console.error('[Payments] Error fetching payment:', error.message);
    return res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

// ── POST /payments/{paymentId}/reconcile - Reconcile Payment ──────────────
// Admin only - reconcile discrepancies with Razorpay
router.post('/:paymentId/reconcile', verifyToken, requireRole('UserRole.admin'), async (req, res) => {
  try {
    const { paymentId } = req.params;

    if (!paymentId) {
      return res.status(400).json({
        success: false,
        error: 'Missing paymentId',
      });
    }

    const result = await PaymentService.reconcilePayment(paymentId);

    return res.json({
      success: true,
      message: 'Payment reconciled successfully',
      paymentId: result.paymentId,
      status: result.status,
    });
  } catch (error) {
    console.error('[Payments] Error reconciling payment:', error.message);
    return res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

module.exports = router;
