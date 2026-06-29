import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import * as crypto from 'crypto';

const db = admin.firestore();

/**
 * RAZORPAY WEBHOOK RECONCILIATION HANDLER
 *
 * Endpoint: POST /webhooks/razorpay
 *
 * Responsibilities:
 * 1. Validate HMAC-SHA256 signature for security
 * 2. Parse Razorpay webhook events (payment.authorized, payment.captured, payment.failed)
 * 3. Update order status atomically in Firestore
 * 4. Log all webhook events for audit trail
 * 5. Handle idempotency (prevent duplicate processing)
 *
 * Event Flow:
 * - payment.authorized → Order status = "confirmed"
 * - payment.captured → Order status = "confirmed"
 * - payment.failed → Order status = "payment_failed", add to retry queue
 *
 * Security:
 * - HMAC-SHA256 signature validation against webhook secret
 * - Idempotency key: payment_id (prevents double-processing same payment)
 * - Firestore write permissions restricted to verified webhooks only
 */

interface RazorpayWebhookEvent {
  id: string;
  event: string;
  created_at: number;
  payload: {
    payment: {
      entity: string;
      id: string;
      entity_id: string;
      amount: number;
      currency: string;
      status: string;
      method: string;
      description?: string;
      amount_refunded?: number;
      refund_status?: string;
      captured: boolean;
      order_id?: string;
      invoice_id?: string;
      international?: boolean;
      failed_at?: number;
      error_code?: string;
      error_description?: string;
      error_source?: string;
      error_reason?: string;
      error_step?: string;
      notes?: Record<string, any>;
      fee?: number;
      tax?: number;
      vpa?: string;
      email: string;
      contact: string;
      fee_details?: {
        gst?: number;
      };
      acquirer_data?: Record<string, any>;
    };
  };
}

interface WebhookLog {
  id: string;
  eventId: string;
  eventType: string;
  paymentId: string;
  orderId: string;
  amount: number;
  status: string;
  signature: string;
  signatureValid: boolean;
  processed: boolean;
  processedAt?: admin.firestore.Timestamp;
  processedResult?: string;
  error?: string;
  errorCode?: string;
  receivedAt: admin.firestore.Timestamp;
  retryCount: number;
  lastRetryAt?: admin.firestore.Timestamp;
  idempotencyKey: string;
}

interface PaymentRetryEntry {
  id: string;
  paymentId: string;
  orderId: string;
  amount: number;
  status: string;
  error: string;
  retryCount: number;
  maxRetries: number;
  nextRetryAt: admin.firestore.Timestamp;
  createdAt: admin.firestore.Timestamp;
  lastRetryAt?: admin.firestore.Timestamp;
  fallbackToWallet: boolean;
  notes?: string;
}

// Get webhook secret from Firebase configuration
function getWebhookSecret(): string {
  const secret = process.env.RAZORPAY_WEBHOOK_SECRET || '';
  if (!secret) {
    functions.logger.warn('[razorpay_webhook] RAZORPAY_WEBHOOK_SECRET not configured');
  }
  return secret;
}

/**
 * Validate HMAC-SHA256 signature for webhook
 * Uses the X-Razorpay-Signature header and shared webhook secret
 */
function validateWebhookSignature(
  body: string,
  signature: string,
  secret: string
): boolean {
  if (!secret) {
    functions.logger.warn('[razorpay_webhook] No webhook secret configured - skipping signature validation');
    return false;
  }

  try {
    const hash = crypto
      .createHmac('sha256', secret)
      .update(body)
      .digest('hex');

    const isValid = hash === signature;

    functions.logger.info(
      `[razorpay_webhook] Signature validation: ${isValid ? 'PASS' : 'FAIL'}`
    );

    return isValid;
  } catch (error) {
    functions.logger.error('[razorpay_webhook] Signature validation error:', error);
    return false;
  }
}

/**
 * Check idempotency to prevent duplicate processing
 * Returns true if webhook has NOT been processed yet
 */
async function checkIdempotency(paymentId: string, eventId: string): Promise<boolean> {
  const idempotencyKey = `${paymentId}_${eventId}`;

  try {
    const logsRef = db.collection('webhook_logs');
    const existingLog = await logsRef
      .where('paymentId', '==', paymentId)
      .where('eventId', '==', eventId)
      .limit(1)
      .get();

    if (!existingLog.empty) {
      const log = existingLog.docs[0].data();
      if (log.processed) {
        functions.logger.info(
          `[razorpay_webhook] Webhook already processed: ${idempotencyKey}`
        );
        return false; // Already processed, skip
      }
    }

    return true; // Safe to process
  } catch (error) {
    functions.logger.error('[razorpay_webhook] Idempotency check error:', error);
    return true; // On error, allow processing to be safe
  }
}

/**
 * Create or update webhook log for audit trail
 */
async function logWebhookEvent(
  eventId: string,
  eventType: string,
  payment: RazorpayWebhookEvent['payload']['payment'],
  signature: string,
  signatureValid: boolean,
  processedResult?: string,
  error?: string
): Promise<string> {
  const idempotencyKey = `${payment.id}_${eventId}`;
  const logRef = db.collection('webhook_logs').doc();

  const logData: WebhookLog = {
    id: logRef.id,
    eventId,
    eventType,
    paymentId: payment.id,
    orderId: payment.order_id || 'unknown',
    amount: payment.amount,
    status: payment.status,
    signature: signature.substring(0, 20) + '...', // Log only partial signature
    signatureValid,
    processed: !!processedResult,
    processedAt: processedResult ? admin.firestore.Timestamp.now() : undefined,
    processedResult,
    error,
    errorCode: payment.error_code || undefined,
    receivedAt: admin.firestore.Timestamp.now(),
    retryCount: 0,
    idempotencyKey,
  };

  await logRef.set(logData);
  return logRef.id;
}

/**
 * Update order status based on payment event
 */
async function updateOrderStatus(
  razorpayOrderId: string,
  paymentId: string,
  paymentStatus: string,
  amount: number,
  firestoreOrderId?: string  // from payment.notes.firestore_order_id
): Promise<void> {
  // Resolve the Firestore document ID:
  // Priority 1: notes.firestore_order_id (set by createRazorpayOrder CF)
  // Priority 2: stamp on the order document (razorpayOrderId field)
  // Priority 3: direct doc ID lookup (only if razorpayOrderId happens to match)
  let resolvedOrderId = firestoreOrderId || null;

  if (!resolvedOrderId) {
    // Try to find order by razorpayOrderId field
    const orderQuery = await db.collection('orders')
      .where('razorpayOrderId', '==', razorpayOrderId)
      .limit(1)
      .get();
    if (!orderQuery.empty) {
      resolvedOrderId = orderQuery.docs[0].id;
      functions.logger.info(`[razorpay_webhook] Resolved Firestore order via razorpayOrderId field: ${resolvedOrderId}`);
    }
  }

  if (!resolvedOrderId) {
    functions.logger.error(
      `[razorpay_webhook] ❌ Cannot resolve Firestore order for Razorpay order ${razorpayOrderId}. Payment ${paymentId} orphaned.`
    );
    // Write to orphan queue for manual reconciliation
    await db.collection('payment_orphans').add({
      razorpayOrderId,
      paymentId,
      paymentStatus,
      amount,
      orphanedAt: admin.firestore.Timestamp.now(),
      reason: 'no_firestore_order_found',
    }).catch(() => null);
    // P3-2: Alert owner immediately so orphaned payments don't go unnoticed
    await db.collection('owner_notifications').add({
      type: 'payment_orphan',
      paymentId,
      razorpayOrderId,
      amount: (amount || 0) / 100,
      message: `⚠️ Orphaned payment ₹${(amount || 0) / 100} (ID: ${paymentId}) — no matching Fufaji order found. Manual reconciliation needed.`,
      isRead: false,
      priority: 'high',
      createdAt: admin.firestore.Timestamp.now(),
    }).catch(() => null);
    return;
  }

  const orderRef = db.collection('orders').doc(resolvedOrderId);

  await db.runTransaction(async (transaction) => {
    const orderSnapshot = await transaction.get(orderRef);

    if (!orderSnapshot.exists) {
      functions.logger.warn(
        `[razorpay_webhook] Order ${resolvedOrderId} not found for payment ${paymentId}`
      );
      return;
    }

    const orderData = orderSnapshot.data()!;

    // Determine new status based on payment status
    let newStatus = orderData.status;
    let paymentConfirmed = false;

    if (paymentStatus === 'captured' || paymentStatus === 'authorized') {
      newStatus = 'confirmed';
      paymentConfirmed = true;
    } else if (paymentStatus === 'failed') {
      newStatus = 'payment_failed';
      paymentConfirmed = false;
    }

    // Update order with payment details
    transaction.update(orderRef, {
      status: newStatus,
      paymentStatus,
      razorpayPaymentId: paymentId,
      paymentAmount: amount,
      paymentConfirmed,
      paymentConfirmedAt: paymentConfirmed
        ? admin.firestore.FieldValue.serverTimestamp()
        : undefined,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info(
      `[razorpay_webhook] Updated order ${orderId} status to ${newStatus} for payment ${paymentId}`
    );
  });
}

/**
 * Create retry entry for failed payments
 */
async function createRetryEntry(
  paymentId: string,
  orderId: string,
  amount: number,
  error: string
): Promise<void> {
  const retryRef = db.collection('payment_retry_queue').doc();
  const nextRetryDelay = 300000; // 5 minutes initial delay

  const retryEntry: PaymentRetryEntry = {
    id: retryRef.id,
    paymentId,
    orderId,
    amount,
    status: 'pending',
    error,
    retryCount: 0,
    maxRetries: 3,
    nextRetryAt: admin.firestore.Timestamp.fromMillis(
      Date.now() + nextRetryDelay
    ),
    createdAt: admin.firestore.Timestamp.now(),
    fallbackToWallet: false,
    notes: `Initial retry entry created from webhook for payment ${paymentId}`,
  };

  await retryRef.set(retryEntry);

  functions.logger.info(
    `[razorpay_webhook] Created retry entry for failed payment ${paymentId}`
  );
}

/**
 * Handle payment.authorized event
 */
async function handlePaymentAuthorized(
  event: RazorpayWebhookEvent,
  signature: string,
  signatureValid: boolean
): Promise<{ success: boolean; message: string }> {
  const payment = event.payload.payment;
  const paymentId = payment.id;
  const orderId = payment.order_id;

  if (!orderId) {
    const errorMsg = `Payment authorized but no order_id found for payment ${paymentId}`;
    functions.logger.warn(`[razorpay_webhook] ${errorMsg}`);
    await logWebhookEvent(event.id, 'payment.authorized', payment, signature, signatureValid, null, errorMsg);
    return { success: false, message: errorMsg };
  }

  try {
    // Update order status to confirmed
    const firestoreOrderId = payment.notes?.firestore_order_id as string | undefined;
    await updateOrderStatus(orderId, paymentId, 'authorized', payment.amount, firestoreOrderId);

    // Log successful processing
    await logWebhookEvent(
      event.id,
      'payment.authorized',
      payment,
      signature,
      signatureValid,
      'Order status updated to confirmed'
    );

    return {
      success: true,
      message: `Payment ${paymentId} authorized for order ${orderId}`,
    };
  } catch (error: any) {
    const errorMsg = `Failed to handle payment.authorized: ${error.message}`;
    functions.logger.error(`[razorpay_webhook] ${errorMsg}`, error);
    await logWebhookEvent(event.id, 'payment.authorized', payment, signature, signatureValid, null, errorMsg);
    throw error;
  }
}

/**
 * Handle payment.captured event
 */
async function handlePaymentCaptured(
  event: RazorpayWebhookEvent,
  signature: string,
  signatureValid: boolean
): Promise<{ success: boolean; message: string }> {
  const payment = event.payload.payment;
  const paymentId = payment.id;
  const orderId = payment.order_id;

  if (!orderId) {
    const errorMsg = `Payment captured but no order_id found for payment ${paymentId}`;
    functions.logger.warn(`[razorpay_webhook] ${errorMsg}`);
    await logWebhookEvent(event.id, 'payment.captured', payment, signature, signatureValid, null, errorMsg);
    return { success: false, message: errorMsg };
  }

  try {
    // Update order status to confirmed
    const firestoreOrderId2 = payment.notes?.firestore_order_id as string | undefined;
    await updateOrderStatus(orderId, paymentId, 'captured', payment.amount, firestoreOrderId2);

    // Log successful processing
    await logWebhookEvent(
      event.id,
      'payment.captured',
      payment,
      signature,
      signatureValid,
      'Order status updated to confirmed'
    );

    return {
      success: true,
      message: `Payment ${paymentId} captured for order ${orderId}`,
    };
  } catch (error: any) {
    const errorMsg = `Failed to handle payment.captured: ${error.message}`;
    functions.logger.error(`[razorpay_webhook] ${errorMsg}`, error);
    await logWebhookEvent(event.id, 'payment.captured', payment, signature, signatureValid, null, errorMsg);
    throw error;
  }
}

/**
 * Handle payment.failed event
 */
async function handlePaymentFailed(
  event: RazorpayWebhookEvent,
  signature: string,
  signatureValid: boolean
): Promise<{ success: boolean; message: string }> {
  const payment = event.payload.payment;
  const paymentId = payment.id;
  const orderId = payment.order_id;
  const errorCode = payment.error_code || 'UNKNOWN';
  const errorDescription = payment.error_description || 'Payment failed';

  if (!orderId) {
    const errorMsg = `Payment failed but no order_id found for payment ${paymentId}`;
    functions.logger.warn(`[razorpay_webhook] ${errorMsg}`);
    await logWebhookEvent(event.id, 'payment.failed', payment, signature, signatureValid, null, errorMsg);
    return { success: false, message: errorMsg };
  }

  try {
    // Update order status to payment_failed
    const firestoreOrderId3 = payment.notes?.firestore_order_id as string | undefined;
    await updateOrderStatus(orderId, paymentId, 'failed', payment.amount, firestoreOrderId3);

    // Create retry entry for later retry
    const retryError = `${errorCode}: ${errorDescription}`;
    await createRetryEntry(paymentId, orderId, payment.amount, retryError);

    // Log the failure
    await logWebhookEvent(
      event.id,
      'payment.failed',
      payment,
      signature,
      signatureValid,
      'Payment failed, retry entry created'
    );

    functions.logger.info(
      `[razorpay_webhook] Payment failed for order ${orderId}: ${errorCode}`
    );

    return {
      success: true,
      message: `Payment ${paymentId} failed for order ${orderId}. Retry queued.`,
    };
  } catch (error: any) {
    const errorMsg = `Failed to handle payment.failed: ${error.message}`;
    functions.logger.error(`[razorpay_webhook] ${errorMsg}`, error);
    await logWebhookEvent(event.id, 'payment.failed', payment, signature, signatureValid, null, errorMsg);
    throw error;
  }
}


/**
 * Handle refund.created event
 */
async function handleRefundCreated(
  event: RazorpayWebhookEvent,
  signature: string,
  signatureValid: boolean
): Promise<{ success: boolean; message: string }> {
  const payment = event.payload.payment;
  const paymentId = payment.id;
  const orderId = payment.order_id;
  const firestoreOrderId = (payment.notes?.firestore_order_id as string) || undefined;
  const amountRefunded = payment.amount_refunded || 0;

  try {
    // Update order refund status
    const resolvedOrderId = firestoreOrderId || orderId;
    if (resolvedOrderId) {
      await db.collection('orders').doc(resolvedOrderId).update({
        refundStatus: 'refund_pending',
        refundAmount: amountRefunded / 100, // paise to rupees
        refundInitiatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }).catch(() => null);
    }

    // Update payment ledger
    await db.collection('payments').doc(paymentId).set({
      refundStatus: 'refund_pending',
      refundAmount: amountRefunded / 100,
      refundCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true }).catch(() => null);

    await logWebhookEvent(event.id, 'refund.created', payment, signature, signatureValid, 'Refund initiated');
    return { success: true, message: `Refund initiated for payment ${paymentId}` };
  } catch (error: any) {
    await logWebhookEvent(event.id, 'refund.created', payment, signature, signatureValid, null, error.message);
    throw error;
  }
}

/**
 * Handle refund.processed event — refund has hit the customer's account
 */
async function handleRefundProcessed(
  event: RazorpayWebhookEvent,
  signature: string,
  signatureValid: boolean
): Promise<{ success: boolean; message: string }> {
  const payment = event.payload.payment;
  const paymentId = payment.id;
  const orderId = payment.order_id;
  const firestoreOrderId = (payment.notes?.firestore_order_id as string) || undefined;
  const amountRefunded = payment.amount_refunded || 0;
  const isFullRefund = amountRefunded >= payment.amount;

  try {
    const resolvedOrderId = firestoreOrderId || orderId;
    if (resolvedOrderId) {
      await db.collection('orders').doc(resolvedOrderId).update({
        refundStatus: isFullRefund ? 'refunded' : 'partial_refunded',
        paymentStatus: isFullRefund ? 'refunded' : 'partial_refunded',
        refundAmount: amountRefunded / 100,
        refundProcessedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }).catch(() => null);
    }

    await db.collection('payments').doc(paymentId).set({
      refundStatus: isFullRefund ? 'refunded' : 'partial_refunded',
      refundAmount: amountRefunded / 100,
      refundProcessedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true }).catch(() => null);

    // P2-3: Write a new ledger entry for the refund transaction
    // (separate from the original payment document, for proper accounting)
    await db.collection('payments').add({
      type: isFullRefund ? 'full_refund' : 'partial_refund',
      originalPaymentId: paymentId,
      orderId: resolvedOrderId || orderId,
      amount: -(amountRefunded / 100), // negative = money out
      currency: 'INR',
      refundId: paymentId, // Razorpay refund ID if available
      status: isFullRefund ? 'refunded' : 'partial_refunded',
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }).catch((e: Error) => functions.logger.warn('[razorpay_webhook] Failed to write refund ledger entry', e));

    functions.logger.info(`[razorpay_webhook] Refund processed for ${paymentId}: ₹${amountRefunded / 100}`);
    await logWebhookEvent(event.id, 'refund.processed', payment, signature, signatureValid, `Refund processed: ₹${amountRefunded / 100}`);
    return { success: true, message: `Refund processed for payment ${paymentId}` };
  } catch (error: any) {
    await logWebhookEvent(event.id, 'refund.processed', payment, signature, signatureValid, null, error.message);
    throw error;
  }
}

/**
 * Main webhook handler
 *
 * POST /webhooks/razorpay
 * Content-Type: application/json
 * X-Razorpay-Signature: <HMAC-SHA256 signature>
 *
 * Body: Razorpay webhook event JSON
 */
export const razorpayWebhook = functions.https.onRequest(async (req, res) => {
  // Enable CORS for local testing (restrict in production)
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, X-Razorpay-Signature');

  // Handle OPTIONS preflight
  if (req.method === 'OPTIONS') {
    res.status(200).send();
    return;
  }

  // Only accept POST requests
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    // Extract signature from header
    const signature = (req.headers['x-razorpay-signature'] as string) || '';
    if (!signature) {
      functions.logger.warn('[razorpay_webhook] Missing X-Razorpay-Signature header');
      res.status(401).json({ error: 'Missing signature' });
      return;
    }

    // Get raw body for signature validation
    let rawBody: string;
    if (typeof req.body === 'string') {
      rawBody = req.body;
    } else {
      rawBody = JSON.stringify(req.body);
    }

    // Validate signature
    const secret = getWebhookSecret();
    const signatureValid = validateWebhookSignature(rawBody, signature, secret);

    // Parse webhook event
    const event: RazorpayWebhookEvent = typeof req.body === 'string'
      ? JSON.parse(req.body)
      : req.body;

    const eventId = event.id;
    const eventType = event.event;
    const payment = event.payload.payment;

    functions.logger.info(
      `[razorpay_webhook] Received event: ${eventType} (Event ID: ${eventId}, Payment ID: ${payment.id})`
    );

    // SECURITY: Reject events with invalid signatures — prevents order fraud
    if (!signatureValid) {
      functions.logger.error(
        `[razorpay_webhook] ❌ REJECTED: Invalid signature for event ${eventId}. Possible tampering.`
      );
      // Log the rejected event for security audit
      await db.collection('security_events').add({
        type: 'webhook_signature_rejected',
        eventId,
        eventType,
        paymentId: payment.id,
        receivedAt: admin.firestore.Timestamp.now(),
      }).catch(() => null);
      res.status(401).json({ error: 'Invalid signature' });
      return;
    }

    // Check idempotency
    const shouldProcess = await checkIdempotency(payment.id, eventId);
    if (!shouldProcess) {
      res.status(200).json({
        success: true,
        message: 'Webhook already processed',
        duplicate: true,
      });
      return;
    }

    // Route to event handler
    let result: { success: boolean; message: string };

    switch (eventType) {
      case 'payment.authorized':
        result = await handlePaymentAuthorized(event, signature, signatureValid);
        break;

      case 'payment.captured':
        result = await handlePaymentCaptured(event, signature, signatureValid);
        break;

      case 'payment.failed':
        result = await handlePaymentFailed(event, signature, signatureValid);
        break;

      case 'refund.created':
        result = await handleRefundCreated(event, signature, signatureValid);
        break;

      case 'refund.processed':
        result = await handleRefundProcessed(event, signature, signatureValid);
        break;

      case 'refund.failed':
        // Log and flag for manual review
        functions.logger.error(`[razorpay_webhook] ❌ Refund FAILED for payment ${payment.id}`);
        await db.collection('owner_notifications').add({
          type: 'refund_failed',
          paymentId: payment.id,
          orderId: payment.order_id || 'unknown',
          message: `Razorpay refund failed for payment ${payment.id}. Manual action required.`,
          isRead: false,
          createdAt: admin.firestore.Timestamp.now(),
        }).catch(() => null);
        await logWebhookEvent(event.id, 'refund.failed', payment, signature, signatureValid, null, 'Refund failed');
        result = { success: true, message: `Refund failure logged for payment ${payment.id}` };
        break;

      case 'payment.dispute.created':
      case 'dispute.created': {
        // Chargeback / dispute opened by customer's bank
        const dispute = payload.dispute?.entity || payload.payment?.entity;
        const disputeOrderId = dispute?.order_id || payment.order_id || 'unknown';
        const disputeFirestoreId = dispute?.notes?.firestore_order_id as string || disputeOrderId;
        const disputeAmount = (dispute?.amount || payment?.amount || 0) / 100;
        functions.logger.error(`[razorpay_webhook] ⚠️ DISPUTE OPENED for order ${disputeFirestoreId}`);
        // Write to payment_disputes collection
        await db.collection('payment_disputes').add({
          type: 'chargeback',
          paymentId: payment.id,
          orderId: disputeFirestoreId,
          razorpayDisputeId: dispute?.id || null,
          amount: disputeAmount,
          currency: dispute?.currency || 'INR',
          status: 'open',
          reason: dispute?.reason_code || 'unknown',
          openedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }).catch(() => null);
        // Notify owner immediately
        await db.collection('owner_notifications').add({
          type: 'dispute_opened',
          paymentId: payment.id,
          orderId: disputeFirestoreId,
          amount: disputeAmount,
          message: `⚠️ Chargeback dispute opened for order ${disputeFirestoreId} (₹${disputeAmount}). Respond within 7 days in Razorpay dashboard.`,
          isRead: false,
          priority: 'high',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }).catch(() => null);
        await logWebhookEvent(event.id, eventType, payment, signature, signatureValid, `Dispute opened for order ${disputeFirestoreId}`);
        result = { success: true, message: `Dispute logged for order ${disputeFirestoreId}` };
        break;
      }

      case 'payment.dispute.won':
      case 'dispute.won':
      case 'payment.dispute.closed':
      case 'dispute.closed': {
        // Dispute resolved in merchant's favour
        const closedDispute = payload.dispute?.entity || payload.payment?.entity;
        const closedOrderId = closedDispute?.notes?.firestore_order_id as string || closedDispute?.order_id || payment.order_id || 'unknown';
        functions.logger.info(`[razorpay_webhook] ✅ Dispute CLOSED for order ${closedOrderId}`);
        // Update dispute record
        const disputeQuery = await db.collection('payment_disputes')
          .where('paymentId', '==', payment.id)
          .limit(1)
          .get();
        if (!disputeQuery.empty) {
          await disputeQuery.docs[0].ref.update({
            status: 'closed',
            closedAt: admin.firestore.FieldValue.serverTimestamp(),
          }).catch(() => null);
        }
        await db.collection('owner_notifications').add({
          type: 'dispute_closed',
          paymentId: payment.id,
          orderId: closedOrderId,
          message: `✅ Dispute resolved for order ${closedOrderId}. No further action needed.`,
          isRead: false,
          priority: 'normal',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }).catch(() => null);
        await logWebhookEvent(event.id, eventType, payment, signature, signatureValid, `Dispute closed for order ${closedOrderId}`);
        result = { success: true, message: `Dispute closed for order ${closedOrderId}` };
        break;
      }

      default:
        functions.logger.warn(`[razorpay_webhook] Unhandled event type: ${eventType}`);
        await logWebhookEvent(event.id, eventType, payment, signature, signatureValid, null, `Unhandled event type`);
        result = {
          success: false,
          message: `Unhandled event type: ${eventType}`,
        };
    }

    // Return success response
    res.status(200).json({
      success: result.success,
      message: result.message,
      eventId,
      paymentId: payment.id,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    functions.logger.error('[razorpay_webhook] Unhandled error:', error);

    res.status(500).json({
      success: false,
      error: error.message || 'Internal server error',
      timestamp: new Date().toISOString(),
    });
  }
});
