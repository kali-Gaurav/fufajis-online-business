/**
 * ============================================================================
 * routes/webhooks.js - Webhook Handlers
 * ============================================================================
 * Handlers for:
 * - POST /webhooks/razorpay      Razorpay payment webhooks
 * - GET/POST /webhooks/whatsapp  WhatsApp Business API webhooks
 *
 * CRITICAL: Razorpay webhook signature must be verified over raw body bytes
 * ============================================================================
 */

const express = require('express');
const router = express.Router();

const RazorpayService = require('../services/RazorpayService');
const PaymentService = require('../services/PaymentService');
const SupabasePaymentService = require('../services/SupabasePaymentService');
const SupabaseOrderService = require('../services/SupabaseOrderService');
const { admin, db } = require('../firestore');

// ── POST /webhooks/razorpay - Razorpay Webhook Handler ────────────────────
// Raw body parser is set in app.js for /webhooks routes
// This handler:
// 1. Verifies webhook signature using webhook_secret
// 2. Prevents duplicate processing (idempotency)
// 3. Validates amount matches order
// 4. Updates order & payment atomically
router.post('/razorpay', async (req, res) => {
  const firestore = db();
  const FieldValue = admin.firestore.FieldValue;
  const pool = require('../db/pool');  // ✅ FIX: Add webhook_events table storage
  const signature = req.headers['x-razorpay-signature'];
  const rawBody = Buffer.isBuffer(req.body) ? req.body : Buffer.from(JSON.stringify(req.body || {}));

  // Extract webhook ID for idempotency
  let parsed;
  try {
    parsed = JSON.parse(rawBody.toString('utf8'));
  } catch (e) {
    console.error('[RazorpayWebhook] Invalid JSON:', e.message);
    return res.status(400).send('Bad JSON');
  }

  const event = parsed.event;
  const payload = parsed.payload;
  const webhookEventId = parsed.id || `unknown_${Date.now()}`;

  // ✅ FIX: Store webhook event in DB for retry tracking
  const webhookStorageId = require('uuid').v4();
  try {
    await pool.query(
      `INSERT INTO webhook_events (id, event_type, razorpay_event_id, payload, status, created_at)
       VALUES ($1, $2, $3, $4, 'processing', CURRENT_TIMESTAMP)
       ON CONFLICT (razorpay_event_id) DO UPDATE SET status = 'processing'
       RETURNING id`,
      [webhookStorageId, event, webhookEventId, JSON.stringify(parsed)]
    );
  } catch (storageErr) {
    console.error('[RazorpayWebhook] Failed to store webhook event:', storageErr.message);
    // Continue anyway - we'll attempt processing
  }

  try {
    // Initialize Razorpay service
    await RazorpayService.initialize();

    // CRITICAL: Verify webhook signature using webhook_secret
    const isValid = RazorpayService.verifyWebhookSignature(rawBody, signature);

    if (!isValid) {
      console.error('[RazorpayWebhook] SECURITY: Invalid signature rejected');
      await firestore.collection('payment_reconciliation_log').add({
        action: 'webhook_signature_rejected',
        eventId: webhookEventId,
        signature: signature ? signature.substring(0, 12) + '...' : 'missing',
        timestamp: FieldValue.serverTimestamp(),
      });
      return res.status(400).send('Invalid signature');
    }

    console.log(`[RazorpayWebhook] Received event: ${event} (ID: ${webhookEventId})`);

    // Idempotency guard - prevent duplicate processing
    const eventRef = firestore.collection('webhook_events').doc(`razorpay_${webhookEventId}`);
    const eventDoc = await eventRef.get();
    if (eventDoc.exists) {
      console.log(`[RazorpayWebhook] Event ${webhookEventId} already processed. Skipping.`);
      return res.status(200).send('Already processed');
    }

    // ── PAYMENT CAPTURED ──
    if (event === 'payment.captured') {
      const payment = payload.payment.entity;
      const orderId = (payment.notes && payment.notes.order_id) || payment.order_id;
      const amountRupees = payment.amount / 100;

      if (!orderId) {
        console.error('[RazorpayWebhook] No order_id found in payment notes');
        await eventRef.set({
          processedAt: FieldValue.serverTimestamp(),
          eventId: webhookEventId,
          type: event,
          error: 'missing_order_id',
        });
        return res.status(400).send('Missing order_id');
      }

      const orderRef = firestore.collection('orders').doc(orderId);
      const orderDoc = await orderRef.get();
      if (!orderDoc.exists) {
        console.error(`[RazorpayWebhook] Order ${orderId} not found`);
        await eventRef.set({
          processedAt: FieldValue.serverTimestamp(),
          eventId: webhookEventId,
          type: event,
          error: 'order_not_found',
          orderId,
        });
        return res.status(404).send('Order not found');
      }

      // Amount validation (₹1 tolerance for rounding)
      const orderData = orderDoc.data();
      const orderAmount = orderData.totalAmount || orderData.amount || 0;
      const tolerance = 1.0;
      if (Math.abs(amountRupees - orderAmount) > tolerance) {
        console.error(
          `[RazorpayWebhook] AMOUNT MISMATCH: Webhook ₹${amountRupees} vs Order ₹${orderAmount}`
        );
        await firestore.collection('payment_reconciliation_log').add({
          paymentId: payment.id,
          orderId,
          action: 'amount_mismatch',
          webhookAmount: amountRupees,
          orderAmount,
          timestamp: FieldValue.serverTimestamp(),
        });
        await eventRef.set({
          processedAt: FieldValue.serverTimestamp(),
          eventId: webhookEventId,
          type: event,
          error: 'amount_mismatch',
          orderId,
        });
        return res.status(400).send('Amount mismatch');
      }

      // ✅ FIX: Use PostgreSQL-based PaymentService for atomic payment processing
      // This ensures idempotency and state machine handling
      // ✅ FIX: Add timeout protection
      const WEBHOOK_TIMEOUT = 30000; // 30 seconds
      const paymentTimeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('WEBHOOK_TIMEOUT: Payment processing exceeded 30s')), WEBHOOK_TIMEOUT)
      );

      try {
        const paymentResult = await Promise.race([
          PaymentService.processPaymentWebhook(
            payment.id,        // razorpayPaymentId
            payment.order_id,  // razorpayOrderId
            signature           // razorpaySignature (for verification)
          ),
          paymentTimeoutPromise
        ]);

        console.log(
          `[RazorpayWebhook] ✅ Payment processed via PaymentService: ${JSON.stringify(paymentResult)}`
        );

        // Also update Firebase for backward compatibility (non-critical)
        try {
          await eventRef.set({
            processedAt: FieldValue.serverTimestamp(),
            eventId: webhookEventId,
            orderId,
            paymentId: payment.id,
            amount: amountRupees,
            type: event,
            source: 'postgres_primary',
          });
        } catch (fbErr) {
          console.warn('[RazorpayWebhook] Firebase event log failed (non-critical):', fbErr.message);
        }
      } catch (pgErr) {
        console.error('[RazorpayWebhook] ❌ CRITICAL: PaymentService failed:', pgErr.message);
        // ✅ FIX: Don't fall back to Firebase dual-write. Instead, alert ops to retry
        // This prevents state inconsistency where Firebase succeeds but Postgres fails
        await firestore.collection('payment_reconciliation_log').add({
          paymentId: payment.id,
          orderId,
          action: 'payment_processing_failed',
          error: pgErr.message,
          requiresManualRetry: true,
          timestamp: FieldValue.serverTimestamp(),
        });

        console.error(`[RazorpayWebhook] 🚨 Payment ${payment.id} failed. Requires manual intervention. Check payment_reconciliation_log.`);
        // Return 500 to signal to Razorpay to retry webhook
        return res.status(500).send('Payment processing failed, retry webhook');
      }

      // Record event for idempotency (Firebase-side tracking)
      await firestore.collection('payment_reconciliation_log').add({
        paymentId: payment.id,
        orderId,
        amount: amountRupees,
        action: 'webhook_reconcile',
        event,
        timestamp: FieldValue.serverTimestamp(),
      });

    // ── PAYMENT FAILED ──
    } else if (event === 'payment.failed') {
      const payment = payload.payment.entity;
      const orderId = (payment.notes && payment.notes.order_id) || payment.order_id;

      if (orderId) {
        await PaymentService.markPaymentFailed(
          payment.id,
          payment.error_description || 'Payment failed'
        );
      }

      await eventRef.set({
        processedAt: FieldValue.serverTimestamp(),
        eventId: webhookEventId,
        orderId,
        paymentId: payment.id,
        type: event,
      });

      console.log(`[RazorpayWebhook] Payment ${payment.id} failed`);

    // ── PAYMENT REFUNDED ──
    } else if (event === 'refund.created' || event === 'payment.refunded') {
      const refundEntity =
        event === 'refund.created' ? payload.refund && payload.refund.entity : null;

      if (refundEntity) {
        const paymentId = refundEntity.payment_id;
        const refundAmount = (refundEntity.amount || 0) / 100;

        // Update payment & order records
        const paymentDoc = await firestore.collection('payments').doc(paymentId).get();
        if (paymentDoc.exists) {
          const payment = paymentDoc.data();
          const orderId = payment.orderId;

          await firestore.runTransaction(async (transaction) => {
            // Update payment
            transaction.update(firestore.collection('payments').doc(paymentId), {
              status: 'refunded',
              refundAmount,
              refundedAt: FieldValue.serverTimestamp(),
            });

            // Update order
            transaction.update(firestore.collection('orders').doc(orderId), {
              paymentStatus: 'refunded',
              refundAmount,
              refundedAt: FieldValue.serverTimestamp(),
            });

            // Add to ledger
            transaction.set(firestore.collection('payment_ledger').doc(), {
              orderId,
              paymentId,
              refundId: refundEntity.id,
              customerId: payment.customerId,
              type: 'debit',
              amount: refundAmount,
              action: 'refund',
              timestamp: FieldValue.serverTimestamp(),
            });
          });

          console.log(
            `[RazorpayWebhook] Order ${orderId} refunded ₹${refundAmount}`
          );

          // ── SUPABASE DUAL-WRITE ──
          try {
            await SupabasePaymentService.processRefund({
              refundId: refundEntity.id,
              orderId: orderId,
              customerId: payment.customerId,
              amount: refundAmount,
              reason: refundEntity.notes ? refundEntity.notes.reason : null,
              gatewayRefundId: refundEntity.id
            });
            console.log(`[Supabase] Refund dual-write successful for ${orderId}`);
          } catch (sbErr) {
            console.error(`[Supabase] Refund dual-write failed for ${orderId}:`, sbErr.message);
          }
        }
      }

      await eventRef.set({
        processedAt: FieldValue.serverTimestamp(),
        eventId: webhookEventId,
        type: event,
      });

    // ── ORDER PAID ──
    } else if (event === 'order.paid') {
      const order = payload.order && payload.order.entity;
      if (order) {
        await eventRef.set({
          processedAt: FieldValue.serverTimestamp(),
          eventId: webhookEventId,
          razorpayOrderId: order.id,
          type: event,
        });
      }
    }

    // ✅ FIX: Mark webhook as succeeded
    try {
      await pool.query(
        `UPDATE webhook_events SET status = 'succeeded', processed_at = CURRENT_TIMESTAMP
         WHERE id = $1`,
        [webhookStorageId]
      );
    } catch (err) {
      console.warn('[RazorpayWebhook] Failed to mark webhook succeeded:', err.message);
    }

    return res.status(200).send('Webhook processed');
  } catch (error) {
    console.error('[RazorpayWebhook] Error processing webhook:', error.message);

    // ✅ FIX: Mark webhook as failed (will be retried by cron)
    try {
      await pool.query(
        `UPDATE webhook_events
         SET status = 'failed', last_error = $1, next_retry_at = CURRENT_TIMESTAMP + INTERVAL '1 minute'
         WHERE id = $2`,
        [error.message, webhookStorageId]
      );
    } catch (storageErr) {
      console.error('[RazorpayWebhook] Failed to mark webhook failed:', storageErr.message);
    }

    await firestore
      .collection('payment_reconciliation_log')
      .add({
        action: 'webhook_processing_error',
        eventId: webhookEventId,
        event,
        error: error.message,
        timestamp: FieldValue.serverTimestamp(),
      })
      .catch(() => {});

    // Return 500 to signal Razorpay to retry
    return res.status(500).send('Internal Server Error');
  }
});

// ── GET/POST /webhooks/whatsapp - WhatsApp Webhook Handler ────────────────
router.all('/whatsapp', async (req, res) => {
  // 1. Handle Webhook Verification (GET)
  if (req.method === 'GET') {
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];

    // ✅ FIX: Use environment variable instead of hardcoded token
    const VERIFY_TOKEN = process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN || 'fufaji_whatsapp_verify';

    if (!VERIFY_TOKEN || VERIFY_TOKEN === 'fufaji_whatsapp_verify') {
      console.warn('[WhatsAppWebhook] ⚠️ WARNING: Using default verify token. Set WHATSAPP_WEBHOOK_VERIFY_TOKEN env var for security.');
    }

    if (mode && token) {
      if (mode === 'subscribe' && token === VERIFY_TOKEN) {
        console.log('[WhatsAppWebhook] Webhook verified');
        return res.status(200).send(challenge);
      } else {
        console.warn('[WhatsAppWebhook] Invalid token attempt');
        return res.status(403).send('Forbidden');
      }
    }
  }

  // 2. Handle Incoming Messages (POST)
  if (req.method === 'POST') {
    try {
      const rawBody = Buffer.isBuffer(req.body)
        ? req.body.toString('utf8')
        : JSON.stringify(req.body || {});
      const body = JSON.parse(rawBody);

      if (body.object === 'whatsapp_business_account') {
        if (
          body.entry &&
          body.entry[0].changes &&
          body.entry[0].changes[0].value.messages
        ) {
          const message = body.entry[0].changes[0].value.messages[0];
          const from = message.from;
          const messageId = message.id;

          const firestore = db();
          await firestore
            .collection('whatsapp_incoming')
            .doc(messageId)
            .set({
              from,
              body: message,
              receivedAt: admin.firestore.FieldValue.serverTimestamp(),
              status: 'pending',
            });

          console.log(
            `[WhatsAppWebhook] Message from ${from}: ${messageId}`
          );
        }
        return res.status(200).send('EVENT_RECEIVED');
      } else {
        return res.status(404).send('Not Found');
      }
    } catch (error) {
      console.error('[WhatsAppWebhook] Error processing webhook:', error.message);
      return res.status(500).send('Internal Server Error');
    }
  }

  return res.status(405).send('Method Not Allowed');
});

module.exports = router;
