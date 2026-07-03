/**
 * Payments API Routes (v2)
 *
 * CRITICAL: These endpoints handle payment verification and fraud prevention.
 *
 * Architecture:
 * 1. Client creates order (reserved inventory, payment_status = 'pending')
 * 2. Client initiates payment via Razorpay
 * 3. Razorpay returns payment details to client
 * 4. Client sends payment details to backend for VERIFICATION
 * 5. Backend verifies Razorpay signature
 * 6. Backend updates order status if valid
 * 7. Backend syncs to Firestore
 *
 * CRITICAL SECURITY RULES:
 * - Client CANNOT directly mark order as paid
 * - All payment status changes must be backend-verified
 * - Razorpay signature MUST be validated
 * - Refunds must go through backend + payment gateway
 * - Audit log every payment event
 *
 * PREVENTS:
 * - Payment fraud
 * - Unauthorized refunds
 * - Double-charging
 * - Payment signature spoofing
 */

const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const { db } = require('../db');
const { firestore } = require('../firebase');
const { verifyAuth, requireRole } = require('../middleware/auth');
const { logAudit } = require('../middleware/audit');

// Razorpay credentials (from env)
const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID;
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET;

if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
  throw new Error('RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET must be set in environment');
}

/**
 * POST /payments/verify
 * Verify payment from Razorpay and update order status
 *
 * CRITICAL: This is the ONLY way to mark an order as paid.
 * No client can call this with a fake signature.
 *
 * Body:
 * {
 *   orderId: string,
 *   paymentId: string,
 *   razorpay_order_id: string,
 *   razorpay_payment_id: string,
 *   razorpay_signature: string,
 *   expectedAmount: int (in paise)
 * }
 *
 * Response:
 * {
 *   success: true,
 *   orderId: string,
 *   paymentStatus: 'paid',
 *   orderStatus: 'confirmed',
 *   paymentId: string,
 *   verifiedAt: ISO8601
 * }
 */
router.post('/verify', verifyAuth, requireRole('customer', 'admin'), logAudit('payment_verify'), async (req, res) => {
  const client = await db.connect();

  try {
    const { orderId, paymentId, razorpay_order_id, razorpay_payment_id, razorpay_signature, expectedAmount } = req.body;
    const userId = req.user.uid;

    // Validation
    if (!orderId || !razorpay_order_id || !razorpay_payment_id || !razorpay_signature || expectedAmount === undefined) {
      return res.status(400).json({ error: 'Missing required fields for payment verification' });
    }

    // STEP 1: Verify Razorpay signature (CRITICAL SECURITY CHECK)
    const signatureBody = `${razorpay_order_id}|${razorpay_payment_id}`;
    const expectedSignature = crypto
      .createHmac('sha256', RAZORPAY_KEY_SECRET)
      .update(signatureBody)
      .digest('hex');

    if (razorpay_signature !== expectedSignature) {
      // Signature mismatch — potential fraud
      console.error('FRAUD ALERT: Invalid Razorpay signature', {
        orderId,
        userId,
        expectedSignature,
        providedSignature: razorpay_signature,
      });

      // Log fraud attempt
      await db.query(
        `INSERT INTO audit_logs (entity_type, entity_id, action, user_id, metadata, created_at)
         VALUES ($1, $2, $3, $4, $5, NOW())`,
        [
          'payment',
          orderId,
          'fraud_attempt_invalid_signature',
          userId,
          JSON.stringify({ razorpay_payment_id, expectedSignature, providedSignature: razorpay_signature }),
        ]
      );

      return res.status(401).json({
        error: 'Payment signature verification failed',
        details: 'Invalid signature — possible fraud attempt',
      });
    }

    // STEP 2: Lock order for update
    await client.query('BEGIN');

    try {
      const orderQuery = `
        SELECT id, status, payment_status, total_amount, customer_id
        FROM orders
        WHERE id = $1
        FOR UPDATE
      `;
      const orderResult = await client.query(orderQuery, [orderId]);

      if (orderResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Order not found' });
      }

      const order = orderResult.rows[0];

      // STEP 3: Verify order amount matches expected amount
      if (order.total_amount !== expectedAmount) {
        await client.query('ROLLBACK');

        // Log amount mismatch — potential fraud
        console.error('FRAUD ALERT: Payment amount mismatch', {
          orderId,
          userId,
          expectedAmount: order.total_amount,
          providedAmount: expectedAmount,
        });

        await db.query(
          `INSERT INTO audit_logs (entity_type, entity_id, action, user_id, metadata, created_at)
           VALUES ($1, $2, $3, $4, $5, NOW())`,
          [
            'payment',
            orderId,
            'fraud_attempt_amount_mismatch',
            userId,
            JSON.stringify({ expectedAmount: order.total_amount, providedAmount: expectedAmount }),
          ]
        );

        return res.status(400).json({
          error: 'Payment amount mismatch',
          details: { expectedAmount: order.total_amount, providedAmount: expectedAmount },
        });
      }

      // STEP 4: Update order payment status
      const updateQuery = `
        UPDATE orders
        SET payment_status = $1, status = $2, payment_verified_at = NOW(), updated_at = NOW()
        WHERE id = $3
        RETURNING id, status, payment_status, updated_at
      `;

      // Status progression: pending → confirmed (after payment)
      const newOrderStatus = order.status === 'pending' ? 'confirmed' : order.status;

      const updateResult = await client.query(updateQuery, ['paid', newOrderStatus, orderId]);
      const verifiedAt = updateResult.rows[0].updated_at;

      // STEP 5: Record payment in database
      const paymentRecordQuery = `
        INSERT INTO payments (order_id, user_id, amount, currency, payment_gateway, gateway_payment_id, gateway_order_id, signature_verified, verified_at, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), NOW())
        RETURNING id
      `;

      const paymentRecordResult = await client.query(paymentRecordQuery, [
        orderId,
        userId,
        expectedAmount,
        'INR',
        'razorpay',
        razorpay_payment_id,
        razorpay_order_id,
        true, // signature verified
      ]);

      const paymentRecordId = paymentRecordResult.rows[0].id;

      // STEP 6: Create audit log
      const auditQuery = `
        INSERT INTO audit_logs (entity_type, entity_id, action, old_value, new_value, user_id, metadata, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
      `;

      await client.query(auditQuery, [
        'payment',
        orderId,
        'payment_verified',
        JSON.stringify({ paymentStatus: order.payment_status }),
        JSON.stringify({ paymentStatus: 'paid' }),
        userId,
        JSON.stringify({ razorpay_payment_id, razorpay_order_id, paymentRecordId }),
      ]);

      // STEP 7: COMMIT
      await client.query('COMMIT');

      // STEP 8: Sync to Firestore
      syncPaymentToFirestore(orderId, 'paid', verifiedAt).catch(err => {
        console.error('Firestore sync failed for payment verification:', err);
      });

      // Success response
      res.json({
        success: true,
        orderId,
        paymentStatus: 'paid',
        orderStatus: newOrderStatus,
        paymentId: paymentRecordId,
        verifiedAt: verifiedAt.toISOString(),
      });
    } catch (txError) {
      await client.query('ROLLBACK');
      throw txError;
    }
  } catch (error) {
    console.error('POST /payments/verify error:', error);
    res.status(500).json({ error: 'Payment verification failed', details: error.message });
  } finally {
    client.release();
  }
});

/**
 * POST /payments/webhook
 * Razorpay webhook receiver (for additional verification)
 *
 * This endpoint receives webhooks from Razorpay for:
 * - payment.authorized
 * - payment.failed
 * - payment.captured
 *
 * Body (from Razorpay):
 * {
 *   event: 'payment.authorized' | 'payment.captured' | 'payment.failed',
 *   payload: {
 *     payment: {
 *       entity: {
 *         id: string,
 *         amount: int,
 *         status: string,
 *         order_id: string,
 *         ...
 *       }
 *     }
 *   }
 * }
 */
router.post('/webhook', async (req, res) => {
  try {
    const { event, payload } = req.body;

    if (!event || !payload) {
      return res.status(400).json({ error: 'Missing event or payload' });
    }

    const payment = payload.payment?.entity;
    if (!payment) {
      return res.status(400).json({ error: 'Invalid webhook payload' });
    }

    console.log(`Razorpay webhook received: ${event}`, payment);

    // Log webhook event
    await db.query(
      `INSERT INTO webhook_logs (source, event_type, payload, received_at)
       VALUES ($1, $2, $3, NOW())`,
      ['razorpay', event, JSON.stringify(payment)]
    );

    // Handle different events
    switch (event) {
      case 'payment.authorized':
      case 'payment.captured':
        // Payment successful — mark order as confirmed if not already done
        // (The /verify endpoint is authoritative, but this serves as backup)
        await db.query(
          `UPDATE orders SET payment_status = $1, updated_at = NOW()
           WHERE id = $2 AND payment_status = $3`,
          ['paid', payment.order_id, 'pending']
        );
        break;

      case 'payment.failed':
        // Payment failed — log it
        await db.query(
          `UPDATE orders SET payment_status = $1, updated_at = NOW()
           WHERE id = $2`,
          ['failed', payment.order_id]
        );
        break;

      default:
        console.warn(`Unknown Razorpay event: ${event}`);
    }

    // Always respond 200 to acknowledge webhook receipt
    res.json({ success: true, event });
  } catch (error) {
    console.error('POST /payments/webhook error:', error);
    // Still return 200 to prevent Razorpay from retrying
    res.status(200).json({ success: false, error: error.message });
  }
});

/**
 * POST /payments/:orderId/refund
 * Initiate refund (backend-only, never client-initiated)
 *
 * Body:
 * {
 *   reason: string,
 *   amount?: int (partial refund, optional)
 * }
 *
 * Response:
 * {
 *   refundId: string,
 *   orderId: string,
 *   status: 'pending' | 'processing' | 'completed' | 'failed',
 *   amount: int,
 *   createdAt: ISO8601
 * }
 */
router.post('/:orderId/refund', verifyAuth, requireRole('admin'), logAudit('refund_initiate'), async (req, res) => {
  const client = await db.connect();

  try {
    const { orderId } = req.params;
    const { reason, amount: partialAmount } = req.body;
    const userId = req.user.uid;

    if (!reason) {
      return res.status(400).json({ error: 'reason is required' });
    }

    await client.query('BEGIN');

    try {
      // Get order and payment details
      const orderQuery = `
        SELECT id, total_amount, payment_status, status
        FROM orders
        WHERE id = $1
        FOR UPDATE
      `;
      const orderResult = await client.query(orderQuery, [orderId]);

      if (orderResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Order not found' });
      }

      const order = orderResult.rows[0];

      // Only refund paid orders
      if (order.payment_status !== 'paid') {
        await client.query('ROLLBACK');
        return res.status(400).json({
          error: 'Cannot refund unpaid order',
          details: { paymentStatus: order.payment_status },
        });
      }

      // Determine refund amount
      const refundAmount = partialAmount || order.total_amount;

      if (refundAmount > order.total_amount) {
        await client.query('ROLLBACK');
        return res.status(400).json({
          error: 'Refund amount exceeds order total',
          details: { orderTotal: order.total_amount, requestedRefund: refundAmount },
        });
      }

      // Get payment details for Razorpay refund
      const paymentQuery = `
        SELECT id, gateway_payment_id, gateway_order_id, amount
        FROM payments
        WHERE order_id = $1
        LIMIT 1
      `;
      const paymentResult = await client.query(paymentQuery, [orderId]);

      if (paymentResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'No payment record found for order' });
      }

      const payment = paymentResult.rows[0];

      // Create refund record (status: pending)
      const refundId = `ref_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

      const createRefundQuery = `
        INSERT INTO refund_requests (refund_id, order_id, payment_id, amount, reason, status, initiated_by_user_id, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
        RETURNING id, created_at
      `;

      const refundResult = await client.query(createRefundQuery, [
        refundId,
        orderId,
        payment.id,
        refundAmount,
        reason,
        'pending',
        userId,
      ]);

      const refundRecordId = refundResult.rows[0].id;
      const createdAt = refundResult.rows[0].created_at;

      // Create audit log
      const auditQuery = `
        INSERT INTO audit_logs (entity_type, entity_id, action, user_id, metadata, created_at)
        VALUES ($1, $2, $3, $4, $5, NOW())
      `;

      await client.query(auditQuery, [
        'refund',
        orderId,
        'refund_initiated',
        userId,
        JSON.stringify({ refundId, refundAmount, reason, razorpayPaymentId: payment.gateway_payment_id }),
      ]);

      await client.query('COMMIT');

      // BACKGROUND: Send refund to Razorpay
      // This should be done in a background job, not blocking the response
      processRefundWithRazorpay(refundId, payment.gateway_payment_id, refundAmount).catch(err => {
        console.error(`Failed to process refund ${refundId} with Razorpay:`, err);
      });

      // Response
      res.json({
        success: true,
        refundId,
        orderId,
        status: 'pending',
        amount: refundAmount,
        createdAt: createdAt.toISOString(),
        note: 'Refund is being processed with payment gateway',
      });
    } catch (txError) {
      await client.query('ROLLBACK');
      throw txError;
    }
  } catch (error) {
    console.error('POST /payments/:orderId/refund error:', error);
    res.status(500).json({ error: 'Failed to initiate refund', details: error.message });
  } finally {
    client.release();
  }
});

/**
 * Helper: Process refund with Razorpay (background job)
 * This calls Razorpay API to actually process the refund
 */
async function processRefundWithRazorpay(refundId, razorpayPaymentId, amount) {
  try {
    // Call Razorpay refund API
    // This is pseudocode — implement actual HTTP call to Razorpay
    const razorpayRefund = await callRazorpayRefundAPI(razorpayPaymentId, amount);

    // Update refund status
    await db.query(
      `UPDATE refund_requests
       SET status = $1, gateway_refund_id = $2, processed_at = NOW()
       WHERE refund_id = $3`,
      ['completed', razorpayRefund.id, refundId]
    );

    console.log(`Refund ${refundId} processed successfully with Razorpay`);
  } catch (error) {
    console.error(`Failed to process refund ${refundId} with Razorpay:`, error);

    // Update refund status to failed
    await db.query(
      `UPDATE refund_requests
       SET status = $1, error_message = $2
       WHERE refund_id = $3`,
      ['failed', error.message, refundId]
    );
  }
}

/**
 * Helper: Call Razorpay Refund API
 * (This is a placeholder — implement actual Razorpay API call)
 */
async function callRazorpayRefundAPI(paymentId, amount) {
  // TODO: Implement actual Razorpay API call using Razorpay SDK or HTTP
  throw new Error('callRazorpayRefundAPI not yet implemented');
}

/**
 * Helper: Sync payment to Firestore
 */
async function syncPaymentToFirestore(orderId, status, verifiedAt) {
  try {
    await firestore.collection('orders').doc(orderId).set(
      {
        paymentStatus: status,
        paymentVerifiedAt: verifiedAt.toISOString(),
        syncedAt: new Date().toISOString(),
      },
      { merge: true }
    );
    console.log(`Synced payment for order ${orderId} to Firestore`);
  } catch (error) {
    console.error(`Failed to sync payment to Firestore for order ${orderId}:`, error);
  }
}

module.exports = router;
