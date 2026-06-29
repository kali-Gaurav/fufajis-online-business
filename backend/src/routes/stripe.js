/**
 * Stripe Payment Integration Route
 * Fallback when Razorpay unavailable
 * Server-side payment verification (no client-side secrets)
 */

const express = require('express');
const router = express.Router();
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const { verifyToken } = require('../auth');
const { admin } = require('../firestore');

/**
 * POST /stripe/create-payment-intent
 * Create Stripe PaymentIntent for card payments
 * Only called if Razorpay fails/unavailable
 */
router.post('/create-payment-intent', verifyToken, async (req, res) => {
  const { orderId, amount, currency = 'INR', customerId } = req.body;

  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100), // Convert to paise
      currency: currency.toLowerCase(),
      description: `Order ${orderId}`,
      metadata: {
        orderId,
        customerId: customerId || req.user.uid,
      },
    });

    // Store pending payment in Firestore
    const db = admin.firestore();
    await db.collection('payments').doc(paymentIntent.id).set({
      paymentId: paymentIntent.id,
      orderId,
      customerId: customerId || req.user.uid,
      provider: 'stripe',
      amount,
      currency,
      status: 'pending',
      clientSecret: paymentIntent.client_secret,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({
      success: true,
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    });
  } catch (err) {
    console.error('[Stripe] Payment intent creation failed:', err);
    res.status(500).json({ success: false, message: 'Payment setup failed' });
  }
});

/**
 * POST /stripe/webhook
 * Handle Stripe webhook events (payment confirmation, failure)
 * CRITICAL: Verify webhook signature for security
 */
router.post('/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  try {
    // Verify webhook signature (CRITICAL for security)
    const event = stripe.webhooks.constructEvent(req.body, sig, webhookSecret);

    const db = admin.firestore();

    switch (event.type) {
      case 'payment_intent.succeeded':
        const paymentIntent = event.data.object;
        const orderId = paymentIntent.metadata.orderId;
        const customerId = paymentIntent.metadata.customerId;

        // Mark payment as successful
        await db.collection('payments').doc(paymentIntent.id).update({
          status: 'succeeded',
          stripePaymentIntentId: paymentIntent.id,
          succeededAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Update order status
        await db.collection('orders').doc(orderId).update({
          paymentStatus: 'confirmed',
          paymentMethod: 'stripe',
          status: 'payment_verified',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`[Stripe] Payment succeeded: ${paymentIntent.id} for order ${orderId}`);
        break;

      case 'payment_intent.payment_failed':
        const failedIntent = event.data.object;
        const failedOrderId = failedIntent.metadata.orderId;

        // Mark payment as failed
        await db.collection('payments').doc(failedIntent.id).update({
          status: 'failed',
          failureReason: failedIntent.last_payment_error?.message || 'Unknown error',
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Enqueue for retry (or fallback to other payment method)
        await db.collection('payment_retry_queue').doc().set({
          paymentId: failedIntent.id,
          orderId: failedOrderId,
          provider: 'stripe',
          failureReason: failedIntent.last_payment_error?.message,
          retryCount: 0,
          status: 'pending',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`[Stripe] Payment failed: ${failedIntent.id} for order ${failedOrderId}`);
        break;

      default:
        console.log(`[Stripe] Unhandled event type: ${event.type}`);
    }

    res.json({ received: true });
  } catch (err) {
    console.error('[Stripe] Webhook error:', err);
    res.status(400).json({ error: 'Webhook validation failed' });
  }
});

/**
 * POST /stripe/confirm-payment
 * Confirm payment after client-side confirmation
 */
router.post('/confirm-payment', verifyToken, async (req, res) => {
  const { paymentIntentId } = req.body;

  try {
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

    if (paymentIntent.status === 'succeeded') {
      return res.json({ success: true, status: 'succeeded' });
    }

    if (paymentIntent.status === 'requires_action') {
      return res.json({ success: false, status: 'requires_action', message: '3D Secure required' });
    }

    if (paymentIntent.status === 'requires_payment_method') {
      return res.status(400).json({ success: false, message: 'Payment method required' });
    }

    res.json({ success: true, status: paymentIntent.status });
  } catch (err) {
    console.error('[Stripe] Confirm payment error:', err);
    res.status(500).json({ success: false, message: 'Confirmation failed' });
  }
});

module.exports = router;
