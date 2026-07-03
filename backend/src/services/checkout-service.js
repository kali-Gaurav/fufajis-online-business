// Checkout Service
// CRITICAL: Atomic checkout with inventory lock, order creation, and Razorpay integration
// Everything in ONE PostgreSQL transaction or NOTHING

const pool = require('../db/pool');
const { v4: uuidv4 } = require('uuid');
const razorpay = require('../lib/razorpay');

class CheckoutService {
  /**
   * Create order with inventory reservation in ONE atomic transaction
   * CRITICAL FLOW:
   * 1. Validate cart items
   * 2. Create Razorpay order (BEFORE DB commit to prevent orphaned reservations)
   * 3. Lock inventory rows (SELECT...FOR UPDATE)
   * 4. Create checkout_sessions record
   * 5. Create reservations record
   * 6. Create reservation_items records
   * 7. Update products table (deduct available, add reserved)
   * 8. All in one transaction or rollback
   */
  static async createOrderWithReservation({
    customerId,
    items,
    paymentMethod,
    paymentMethodId,
    couponCode,
    discountAmount = 0,
    deliveryAddressId,
    idempotencyKey,
  }) {
    // Step 1: Validate request
    if (!customerId || !items || items.length === 0) {
      throw new Error('INVALID_REQUEST: customerId and items are required');
    }

    // Step 2: Create Razorpay order FIRST (before any DB changes)
    // This prevents the state where stock is reserved but no payment order exists
    let razorpayOrder;
    try {
      const totalAmount = items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
      const finalAmount = totalAmount - discountAmount;

      razorpayOrder = await razorpay.createOrder({
        amount: Math.round(finalAmount * 100), // Convert to paise
        currency: 'INR',
        receipt: `fufaji-${customerId}-${Date.now()}`,
        notes: {
          customerId,
          couponCode,
          paymentMethod,
        },
      });

      console.log(`[CheckoutService] ✅ Created Razorpay order: ${razorpayOrder.id}`);
    } catch (err) {
      console.error(`[CheckoutService] ❌ Razorpay order creation failed:`, err.message);
      throw err;
    }

    // Step 3-8: All DB operations in ONE transaction
    try {
      return await pool.transaction(async (client) => {
      // Check idempotency (if same key exists, return cached response)
      const idempotencyCheck = await client.query(
        `SELECT response_body FROM idempotency_keys
         WHERE idempotency_key = $1 AND operation_type = 'checkout_create_order'`,
        [idempotencyKey]
      );

      if (idempotencyCheck.rows.length > 0) {
        console.log(`[CheckoutService] ✅ Idempotency cache hit: ${idempotencyKey}`);
        return idempotencyCheck.rows[0].response_body;
      }

      // Lock inventory rows (SELECT...FOR UPDATE) to prevent race conditions
      // CRITICAL: Lock in deterministic order (by ID ASC) to prevent deadlocks
      const lockQuery = `
        SELECT id, available_quantity, reserved_quantity
        FROM products
        WHERE id = ANY($1)
        ORDER BY id ASC
        FOR UPDATE
      `;
      const productIds = items.map(i => i.productId);
      const lockResult = await client.query(lockQuery, [productIds]);

      if (lockResult.rows.length !== items.length) {
        throw new Error('PRODUCT_NOT_FOUND: Some products in cart do not exist');
      }

      // Verify stock availability for ALL items
      const stockMap = {};
      lockResult.rows.forEach(row => {
        stockMap[row.id] = row.available_quantity;
      });

      for (const item of items) {
        if (stockMap[item.productId] < item.quantity) {
          throw new Error(
            `INSUFFICIENT_STOCK: Product ${item.productId} only has ${stockMap[item.productId]} remaining`
          );
        }
      }

      // Create checkout_sessions record
      const checkoutSessionId = uuidv4();
      const totalSubtotal = items.reduce((sum, i) => sum + (i.price * i.quantity), 0);
      const finalAmount = totalSubtotal - discountAmount;

      await client.query(
        `INSERT INTO checkout_sessions
         (id, customer_id, shop_id, status, subtotal, discount_amount, total_amount, razorpay_order_id, coupon_code, delivery_address_id, idempotency_key, expires_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, CURRENT_TIMESTAMP + INTERVAL '30 minutes')`,
        [
          checkoutSessionId,
          customerId,
          items[0].shopId, // Use first item's shop (same shop assumption)
          'inventory_reserved',
          totalSubtotal,
          discountAmount,
          finalAmount,
          razorpayOrder.id,
          couponCode || null,
          deliveryAddressId || null,
          idempotencyKey,
        ]
      );

      // Create reservation record
      const reservationId = uuidv4();
      await client.query(
        `INSERT INTO reservations
         (id, checkout_session_id, customer_id, shop_id, status, total_items, expires_at)
         VALUES ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP + INTERVAL '10 minutes')`,
        [
          reservationId,
          checkoutSessionId,
          customerId,
          items[0].shopId,
          'active',
          items.length,
        ]
      );

      // Create reservation_items and update products
      for (const item of items) {
        // Create reservation_item record
        await client.query(
          `INSERT INTO reservation_items (reservation_id, product_id, quantity, price_per_unit, subtotal)
           VALUES ($1, $2, $3, $4, $5)`,
          [
            reservationId,
            item.productId,
            item.quantity,
            item.price,
            item.price * item.quantity,
          ]
        );

        // Update product inventory
        await client.query(
          `UPDATE products
           SET available_quantity = available_quantity - $2,
               reserved_quantity = reserved_quantity + $2
           WHERE id = $1`,
          [item.productId, item.quantity]
        );
      }

      // Create order record
      const orderId = uuidv4();
      await client.query(
        `INSERT INTO orders (id, customer_id, shop_id, status, total_amount, checkout_session_id, reservation_id, payment_order_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [
          orderId,
          customerId,
          items[0].shopId,
          'pending',
          finalAmount,
          checkoutSessionId,
          reservationId,
          razorpayOrder.id,
        ]
      );

      // Cache idempotency response
      const response = {
        orderId,
        paymentOrderId: razorpayOrder.id,
        reservationId,
        expiresAt: new Date(Date.now() + 10 * 60 * 1000), // 10 minutes
      };

      await client.query(
        `INSERT INTO idempotency_keys
         (idempotency_key, operation_type, entity_type, entity_id, response_status, response_body, user_id, expires_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, NOW() + INTERVAL '7 days')`,
        [
          idempotencyKey,
          'checkout_create_order',
          'order',
          orderId,
          200,
          JSON.stringify(response),
          customerId,
        ]
      );

      console.log(
        `[CheckoutService] ✅ Order created atomically: orderId=${orderId}, reservationId=${reservationId}`
      );

      return response;
      });
    } catch (err) {
      // CRITICAL: On transaction failure, log the orphan Razorpay order for reconciliation
      // Do NOT try to cancel - let reconciliation cron handle stale unpaid orders
      console.error(
        `[CheckoutService] ❌ Transaction failed for Razorpay order ${razorpayOrder.id}:`,
        err.message
      );
      console.error(
        `[CheckoutService] ⚠️ Orphan Razorpay order created. Reconciliation cron will handle cleanup.`
      );
      throw err;
    }
  }
}

module.exports = CheckoutService;
