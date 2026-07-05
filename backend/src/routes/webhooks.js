/**
 * ============================================================================
 * routes/webhooks.js - Webhook Handlers (Consolidated Backend)
 * ============================================================================
 * Handlers for:
 * - POST /webhooks/razorpay      Razorpay payment webhooks (PostgreSQL + outbox pattern)
 * - GET/POST /webhooks/whatsapp  WhatsApp Business API webhooks
 *
 * CRITICAL: Razorpay webhook signature must be verified over raw body bytes
 *
 * ARCHITECTURE:
 * - PostgreSQL is source of truth
 * - Outbox pattern: orders → outbox_events → sync worker → Firestore
 * - Signature verification via HMAC-SHA256
 * - Idempotency via payment_id + webhook_logs table
 * ============================================================================
 */

const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const { createClient } = require('@supabase/supabase-js');
const { admin, db } = require('../firestore');

// Initialize Supabase client (service role for webhook processing)
const supabase = createClient(
  process.env.SUPABASE_URL || '',
  process.env.SUPABASE_SERVICE_ROLE_KEY || ''
);

// Fallback services for backward compat
const RazorpayService = require('../services/RazorpayService');
const PaymentService = require('../services/PaymentService');
const SupabasePaymentService = require('../services/SupabasePaymentService');

// ── Helper: Validate HMAC-SHA256 signature ─────────────────────────────────
function validateWebhookSignature(rawBody, signature, secret) {
  if (!secret) {
    console.warn('[razorpay_webhook] No webhook secret configured - skipping signature validation');
    return false;
  }
  try {
    const hash = crypto
      .createHmac('sha256', secret)
      .update(rawBody)
      .digest('hex');
    const isValid = hash === signature;
    console.log(`[razorpay_webhook] Signature validation: ${isValid ? 'PASS' : 'FAIL'}`);
    return isValid;
  } catch (error) {
    console.error('[razorpay_webhook] Signature validation error:', error.message);
    return false;
  }
}

// ── Helper: Check idempotency (via webhook_logs table) ────────────────────
async function checkIdempotency(paymentId) {
  try {
    const { data, error } = await supabase
      .from('webhook_logs')
      .select('id, processed')
      .eq('payment_id', paymentId)
      .eq('processed', true)
      .limit(1)
      .single();

    if (error && error.code !== 'PGRST116') {
      console.error('[razorpay_webhook] Idempotency check error:', error.message);
      return true; // On error, allow processing to be safe
    }

    if (data) {
      console.info(`[razorpay_webhook] Webhook already processed for payment ${paymentId}`);
      return false; // Already processed, skip
    }

    return true; // Safe to process
  } catch (error) {
    console.error('[razorpay_webhook] Idempotency check exception:', error.message);
    return true; // On error, allow processing to be safe
  }
}

// ── Helper: Log webhook event for audit trail ──────────────────────────────
async function logWebhookEvent(eventId, eventType, paymentId, orderId, amount, signatureValid, processed, error = null) {
  try {
    await supabase.from('webhook_logs').insert({
      event_id: eventId,
      event_type: eventType,
      payment_id: paymentId,
      order_id: orderId,
      amount,
      signature_valid: signatureValid,
      processed,
      processed_at: processed ? new Date().toISOString() : null,
      error,
      received_at: new Date().toISOString(),
      retry_count: 0,
    });
    return true;
  } catch (err) {
    console.error('[razorpay_webhook] Failed to log webhook event:', err.message);
    return false;
  }
}

// ── Helper: Find order by razorpay_order_id ────────────────────────────────
async function findOrderByRazorpayOrderId(razorpayOrderId) {
  try {
    const { data, error } = await supabase
      .from('orders')
      .select('id, status')
      .eq('razorpay_order_id', razorpayOrderId)
      .limit(1)
      .single();

    if (error && error.code === 'PGRST116') {
      return null; // No rows found
    }

    if (error) {
      console.error('[razorpay_webhook] Order lookup error:', error.message);
      return null;
    }

    return data;
  } catch (error) {
    console.error('[razorpay_webhook] Order lookup exception:', error.message);
    return null;
  }
}

// ── Helper: Update order status (atomic) ───────────────────────────────────
async function updateOrderStatus(orderId, paymentId, newStatus, amount) {
  try {
    const { error } = await supabase
      .from('orders')
      .update({
        status: newStatus,
        payment_status: newStatus === 'confirmed' ? 'captured' : 'failed',
        razorpay_payment_id: paymentId,
        payment_amount: amount / 100, // paise to rupees
        payment_confirmed: newStatus === 'confirmed',
        payment_confirmed_at: newStatus === 'confirmed' ? new Date().toISOString() : null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', orderId);

    if (error) {
      console.error('[razorpay_webhook] Order status update error:', error.message);
      return false;
    }

    console.info(`[razorpay_webhook] Updated order ${orderId} status to ${newStatus}`);
    return true;
  } catch (error) {
    console.error('[razorpay_webhook] Order status update exception:', error.message);
    return false;
  }
}

// ── Helper: Write outbox event (for Firestore sync) ────────────────────────
async function writeOutboxEvent(eventType, orderId, payload) {
  try {
    const { error } = await supabase.from('outbox_events').insert({
      event_type: eventType,
      aggregate_id: orderId,
      payload,
      processed: false,
      retry_count: 0,
      created_at: new Date().toISOString(),
    });

    if (error) {
      console.error('[razorpay_webhook] Outbox event write error:', error.message);
      return false;
    }

    console.info(`[razorpay_webhook] Wrote outbox event for order ${orderId}: ${eventType}`);
    return true;
  } catch (error) {
    console.error('[razorpay_webhook] Outbox event write exception:', error.message);
    return false;
  }
}

// ── POST /webhooks/razorpay - Razorpay Webhook Handler ────────────────────
// Raw body parser is set in app.js for /webhooks routes
// Architecture: PostgreSQL (source of truth) → outbox_events (sync queue) → Firestore (cache)
router.post('/razorpay', async (req, res) => {
  const signature = req.headers['x-razorpay-signature'] || '';
  const rawBody = Buffer.isBuffer(req.body) ? req.body : Buffer.from(JSON.stringify(req.body || {}));

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Parse webhook event
  let event;
  try {
    event = typeof req.body === 'string'
      ? JSON.parse(req.body)
      : req.body;
  } catch (e) {
    console.error('[razorpay_webhook] Invalid JSON:', e.message);
    return res.status(400).json({ error: 'Bad JSON' });
  }

  const eventId = event.id || `unknown_${Date.now()}`;
  const eventType = event.event;
  const payment = event.payload?.payment;

  if (!signature) {
    console.warn('[razorpay_webhook] Missing X-Razorpay-Signature header');
    return res.status(401).json({ error: 'Missing signature' });
  }

  if (!eventType || !payment) {
    console.error('[razorpay_webhook] Invalid event structure');
    return res.status(400).json({ error: 'Invalid event' });
  }

  try {
    console.info(`[razorpay_webhook] Received event: ${eventType} (Event ID: ${eventId}, Payment ID: ${payment.id})`);

    // Validate signature (SECURITY: Must verify before processing)
    const secret = process.env.RAZORPAY_WEBHOOK_SECRET || '';
    const signatureValid = validateWebhookSignature(rawBody.toString('utf8'), signature, secret);

    if (!signatureValid) {
      console.error(`[razorpay_webhook] ❌ REJECTED: Invalid signature for event ${eventId}. Possible tampering.`);
      await logWebhookEvent(eventId, eventType, payment.id, null, payment.amount, false, false, 'Invalid signature');
      return res.status(401).json({ error: 'Invalid signature' });
    }

    // Check idempotency (prevent duplicate processing)
    const shouldProcess = await checkIdempotency(payment.id);
    if (!shouldProcess) {
      console.info(`[razorpay_webhook] Event already processed: ${eventId}`);
      return res.status(200).json({
        success: true,
        message: 'Webhook already processed',
        duplicate: true,
        eventId,
        paymentId: payment.id,
      });
    }

    // Route to event handler
    let result = { success: false, message: 'Unhandled event type' };

    if (eventType === 'payment.authorized' || eventType === 'payment.captured') {
      const razorpayOrderId = payment.order_id;

      if (!razorpayOrderId) {
        const errorMsg = `Payment ${eventType} but no order_id found for payment ${payment.id}`;
        console.warn(`[razorpay_webhook] ${errorMsg}`);
        await logWebhookEvent(eventId, eventType, payment.id, null, payment.amount, true, false, errorMsg);
        return res.status(400).json({ error: errorMsg });
      }

      // Find order
      const order = await findOrderByRazorpayOrderId(razorpayOrderId);
      if (!order) {
        const errorMsg = `Order not found for Razorpay order ${razorpayOrderId}`;
        console.error(`[razorpay_webhook] ${errorMsg}`);
        await logWebhookEvent(eventId, eventType, payment.id, null, payment.amount, true, false, errorMsg);
        return res.status(404).json({ error: errorMsg });
      }

      // Update order status to confirmed (atomic)
      const statusUpdated = await updateOrderStatus(
        order.id,
        payment.id,
        'confirmed',
        payment.amount
      );

      if (!statusUpdated) {
        throw new Error('Failed to update order status');
      }

      // Write outbox event for Firestore sync
      await writeOutboxEvent('order_status_changed', order.id, {
        orderId: order.id,
        razorpayOrderId,
        paymentId: payment.id,
        newStatus: 'confirmed',
        amount: payment.amount / 100,
        timestamp: new Date().toISOString(),
      });

      // Log success
      await logWebhookEvent(eventId, eventType, payment.id, order.id, payment.amount, true, true);

      result = {
        success: true,
        eventId,
        paymentId: payment.id,
        orderId: order.id,
        message: `Payment ${payment.id} processed for order ${order.id}`,
      };

    } else if (eventType === 'payment.failed') {
      const razorpayOrderId = payment.order_id;

      if (!razorpayOrderId) {
        const errorMsg = `Payment failed but no order_id found for payment ${payment.id}`;
        console.warn(`[razorpay_webhook] ${errorMsg}`);
        await logWebhookEvent(eventId, eventType, payment.id, null, payment.amount, true, false, errorMsg);
        return res.status(400).json({ error: errorMsg });
      }

      // Find order
      const order = await findOrderByRazorpayOrderId(razorpayOrderId);
      if (!order) {
        const errorMsg = `Order not found for Razorpay order ${razorpayOrderId}`;
        console.error(`[razorpay_webhook] ${errorMsg}`);
        await logWebhookEvent(eventId, eventType, payment.id, null, payment.amount, true, false, errorMsg);
        return res.status(404).json({ error: errorMsg });
      }

      // Update order status to cancelled
      const statusUpdated = await updateOrderStatus(
        order.id,
        payment.id,
        'cancelled',
        payment.amount
      );

      if (!statusUpdated) {
        throw new Error('Failed to update order status');
      }

      // Write outbox event
      const errorCode = payment.error_code || 'UNKNOWN';
      const errorDescription = payment.error_description || 'Payment failed';
      await writeOutboxEvent('order_status_changed', order.id, {
        orderId: order.id,
        razorpayOrderId,
        paymentId: payment.id,
        newStatus: 'cancelled',
        paymentError: `${errorCode}: ${errorDescription}`,
        amount: payment.amount / 100,
        timestamp: new Date().toISOString(),
      });

      // Log success
      await logWebhookEvent(eventId, eventType, payment.id, order.id, payment.amount, true, true);

      result = {
        success: true,
        eventId,
        paymentId: payment.id,
        orderId: order.id,
        message: `Payment failed for order ${order.id}. Order cancelled.`,
      };

    } else {
      // Unhandled event type
      console.warn(`[razorpay_webhook] Unhandled event type: ${eventType}`);
      await logWebhookEvent(eventId, eventType, payment.id, null, payment.amount, true, false, 'Unhandled event type');
    }

    // Return 200 OK immediately (async processing)
    return res.status(200).json({
      success: result.success,
      message: result.message,
      eventId: result.eventId,
      paymentId: result.paymentId,
      orderId: result.orderId,
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    console.error('[razorpay_webhook] Unhandled error:', error.message);
    await logWebhookEvent(eventId, eventType, payment?.id, null, payment?.amount, false, false, error.message);

    // Return 200 OK (Razorpay expects no errors in response body, retry on 5xx)
    return res.status(200).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString(),
    });
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
