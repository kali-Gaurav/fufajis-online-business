// Payment Webhook Routes
// POST /webhooks/razorpay — Receive and process Razorpay payment webhooks

const express = require('express');
const router = express.Router();
const PaymentService = require('../services/payment-service');
const pool = require('../db/pool');

/**
 * POST /webhooks/razorpay
 * Receive Razorpay webhook notifications
 * CRITICAL: Signature verification must happen before any processing
 */
router.post('/razorpay', express.raw({ type: '*/*' }), async (req, res) => {
  try {
    // Parse webhook payload
    const payload = req.body.toString('utf-8');
    const webhookEvent = JSON.parse(payload);

    console.log(`[payment-webhook-routes] Received webhook: ${webhookEvent.event}`);

    // Only process payment.authorized events
    if (webhookEvent.event !== 'payment.authorized') {
      console.log(
        `[payment-webhook-routes] ℹ️ Ignoring webhook event type: ${webhookEvent.event}`
      );
      return res.status(200).json({ received: true });
    }

    const { razorpay_payment_id, razorpay_order_id, razorpay_signature } = webhookEvent.payload.payment.entity;

    // Process payment webhook (includes signature verification + recovery logic)
    const result = await PaymentService.processPaymentWebhook(
      razorpay_payment_id,
      razorpay_order_id,
      razorpay_signature
    );

    console.log(
      `[payment-webhook-routes] ✅ Webhook processed: ${result.status} for order ${result.orderId}`
    );

    // Return 200 immediately so Razorpay doesn't retry
    // (Actual side effects handled async)
    res.status(200).json({
      received: true,
      status: result.status,
    });
  } catch (err) {
    console.error('[payment-webhook-routes] ❌ Webhook processing failed:', err.message);

    // Still return 200 to Razorpay to prevent retry loop
    // Log error for manual investigation
    res.status(200).json({
      received: true,
      error: err.message,
    });
  }
});

module.exports = router;
