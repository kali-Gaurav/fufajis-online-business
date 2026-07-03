// Payment Service
// CRITICAL: Verify payments and handle recovery scenarios
// State machine for late webhook arrivals

const pool = require('../db/pool');
const InventoryService = require('./inventory-service');
const EventBus = require('./event-bus');
const { v4: uuidv4 } = require('uuid');

class PaymentService {
  /**
   * Verify Razorpay payment signature
   * Throws on invalid signature or payment failure
   */
  static async verifyRazorpayPayment(razorpayPaymentId, razorpayOrderId, razorpaySignature) {
    const crypto = require('crypto');
    const secret = process.env.RAZORPAY_WEBHOOK_SECRET;

    if (!secret) {
      throw new Error('RAZORPAY_WEBHOOK_SECRET not configured');
    }

    // Verify signature: SHA256(orderId|paymentId, secret)
    const expectedSignature = crypto
      .createHmac('sha256', secret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest('hex');

    if (expectedSignature !== razorpaySignature) {
      throw new Error('INVALID_SIGNATURE: Webhook signature verification failed');
    }

    console.log(`[PaymentService] ✅ Signature verified for payment ${razorpayPaymentId}`);
  }

  /**
   * Process payment webhook with recovery state machine
   * CRITICAL: Handles late arrivals, expired reservations, etc.
   *
   * State machine:
   * Active reservation → Confirm reservation
   * Expired reservation → Recovery (try re-reserve or refund)
   * Confirmed reservation → No-op (duplicate webhook)
   * Released reservation → Anomaly (payment after cancellation)
   */
  static async processPaymentWebhook(razorpayPaymentId, razorpayOrderId, razorpaySignature) {
    // Step 1: Verify signature
    await this.verifyRazorpayPayment(razorpayPaymentId, razorpayOrderId, razorpaySignature);

    // Step 2: Find order by Razorpay order ID
    const orderRes = await pool.query(
      `SELECT o.id as order_id, o.customer_id, r.id as reservation_id, r.status as reservation_status
       FROM orders o
       LEFT JOIN reservations r ON o.reservation_id = r.id
       WHERE o.payment_order_id = $1`,
      [razorpayOrderId]
    );

    if (orderRes.rows.length === 0) {
      throw new Error(`ORDER_NOT_FOUND: No order with payment_order_id ${razorpayOrderId}`);
    }

    const { order_id: orderId, customer_id: customerId, reservation_id: reservationId, reservation_status: reservationStatus } = orderRes.rows[0];

    console.log(
      `[PaymentService] Processing payment webhook for order ${orderId}, reservation status: ${reservationStatus}`
    );

    // Step 3: State machine for reservation status
    if (reservationStatus === 'active') {
      // NORMAL PATH: Reservation is active, confirm it
      return await this.confirmReservationPath(reservationId, orderId, razorpayPaymentId);
    } else if (reservationStatus === 'expired') {
      // RECOVERY PATH: Reservation expired, attempt recovery
      return await this.recoveryPathExpiredReservation(orderId, customerId, razorpayPaymentId);
    } else if (reservationStatus === 'confirmed') {
      // IDEMPOTENT PATH: Already confirmed, no-op
      console.log(
        `[PaymentService] ℹ️ Duplicate webhook: reservation already confirmed for order ${orderId}`
      );
      return { status: 'already_confirmed', orderId };
    } else if (reservationStatus === 'released') {
      // ANOMALY PATH: Payment after cancellation
      return await this.anomalyPathPaymentAfterCancellation(orderId, customerId, razorpayPaymentId);
    } else {
      throw new Error(`UNKNOWN_RESERVATION_STATE: ${reservationStatus}`);
    }
  }

  /**
   * Normal path: Confirm active reservation
   */
  static async confirmReservationPath(reservationId, orderId, paymentId) {
    await pool.query(
      `UPDATE reservations
       SET status = 'confirmed', confirmed_at = CURRENT_TIMESTAMP
       WHERE id = $1`,
      [reservationId]
    );

    // Emit PAYMENT_SUCCESS event for side effects (notifications, loyalty, packing lists, etc.)
    // Event bus will handle asynchronously
    try {
      await EventBus.publishEvent({
        event_type: 'PAYMENT_SUCCESS',
        aggregate_id: orderId,
        partition_key: orderId,  // Ensures this order's events process in order
        payload: {
          orderId,
          reservationId,
          paymentId,
          confirmedAt: new Date().toISOString(),
        },
        priority: 1,  // Critical: notify customer immediately
      });
      console.log(`[PaymentService] ✅ Published PAYMENT_SUCCESS event for order ${orderId}`);
    } catch (err) {
      console.error(`[PaymentService] ⚠️ Failed to publish event: ${err.message}`);
      // Don't fail the payment confirmation if event publishing fails
      // Event worker will retry stale events via DLQ
    }

    console.log(`[PaymentService] ✅ Reservation confirmed for order ${orderId}`);

    return { status: 'confirmed', orderId, reservationId };
  }

  /**
   * Recovery path: Reservation expired before webhook arrived
   * Attempt: Re-lock inventory and create new reservation
   * Fallback: Initiate refund if stock unavailable
   */
  static async recoveryPathExpiredReservation(orderId, customerId, paymentId) {
    console.log(`[PaymentService] ⚠️ Recovery: Reservation expired. Attempting re-lock for order ${orderId}`);

    // Get order details to see what was reserved
    const orderRes = await pool.query(
      `SELECT id, total_amount
       FROM orders
       WHERE id = $1`,
      [orderId]
    );

    if (orderRes.rows.length === 0) {
      throw new Error(`ORDER_NOT_FOUND: ${orderId}`);
    }

    // Get reservation items to re-lock
    const oldReservationRes = await pool.query(
      `SELECT ri.product_id, ri.quantity
       FROM reservation_items ri
       JOIN reservations r ON ri.reservation_id = r.id
       WHERE r.order_id = $1`,
      [orderId]
    );

    const items = oldReservationRes.rows;

    // Try to re-reserve all items atomically
    try {
      await pool.transaction(async (client) => {
        // Lock products in order
        const lockRes = await client.query(
          `SELECT id, available_quantity
           FROM products
           WHERE id = ANY($1)
           ORDER BY id ASC
           FOR UPDATE`,
          [items.map(i => i.product_id)]
        );

        const stockMap = {};
        lockRes.rows.forEach(row => {
          stockMap[row.id] = row.available_quantity;
        });

        // Verify all items still available
        for (const item of items) {
          if (stockMap[item.product_id] < item.quantity) {
            throw new Error(
              `INSUFFICIENT_STOCK_RECOVERY: Product ${item.product_id} only has ${stockMap[item.product_id]} remaining`
            );
          }
        }

        // Create new reservation
        const newReservationId = uuidv4();
        await client.query(
          `INSERT INTO reservations (id, order_id, customer_id, shop_id, status, total_items, expires_at)
           SELECT $1, $2, $3, shop_id, $4, $5, CURRENT_TIMESTAMP + INTERVAL '30 minutes'
           FROM orders WHERE id = $2`,
          [newReservationId, orderId, customerId, 'confirmed', items.length]
        );

        // Create reservation items
        for (const item of items) {
          await client.query(
            `INSERT INTO reservation_items (reservation_id, product_id, quantity, price_per_unit, subtotal)
             VALUES ($1, $2, $3, 0, 0)`,  // Price already recorded in original order
            [newReservationId, item.product_id, item.quantity]
          );

          // Update products
          await client.query(
            `UPDATE products
             SET available_quantity = available_quantity - $2,
                 reserved_quantity = reserved_quantity + $2
             WHERE id = $1`,
            [item.product_id, item.quantity]
          );
        }

        console.log(`[PaymentService] ✅ Recovery successful: New reservation ${newReservationId} created`);
        return { status: 'recovered', orderId, newReservationId };
      });
    } catch (err) {
      // FALLBACK: Stock unavailable, initiate refund
      console.error(
        `[PaymentService] ❌ Recovery failed: ${err.message}. Initiating refund for order ${orderId}`
      );

      await pool.query(
        `INSERT INTO refund_requests (order_id, reason, status, created_at)
         VALUES ($1, $2, $3, CURRENT_TIMESTAMP)`,
        [orderId, `Payment received but reservation expired and stock unavailable`, 'pending']
      );

      // Emit REFUND_REQUIRED event
      return { status: 'recovery_failed_refund_initiated', orderId, paymentId };
    }
  }

  /**
   * Anomaly path: Payment arrived after reservation was released
   * This means customer paid AFTER cancelling checkout
   * Action: Initiate refund
   */
  static async anomalyPathPaymentAfterCancellation(orderId, customerId, paymentId) {
    console.error(
      `[PaymentService] ⚠️ Anomaly: Payment received for cancelled order ${orderId}. Initiating refund.`
    );

    await pool.query(
      `INSERT INTO refund_requests (order_id, reason, status, created_at)
       VALUES ($1, $2, $3, CURRENT_TIMESTAMP)`,
      [orderId, `Payment received after order cancellation`, 'pending']
    );

    return { status: 'refund_initiated', orderId, reason: 'payment_after_cancellation' };
  }
}

module.exports = PaymentService;
