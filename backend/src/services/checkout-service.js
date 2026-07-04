// Checkout Service
// CRITICAL: Atomic checkout with inventory lock, order creation, and Razorpay integration
// Everything in ONE PostgreSQL transaction or NOTHING

const pool = require('../db/pool');
const { v4: uuidv4 } = require('uuid');
const razorpay = require('../lib/razorpay');
const CouponService = require('./CouponService');
const ShippingService = require('./ShippingService');

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
    deliveryAddressId,
    deliveryType = 'standard',
    idempotencyKey,
  }) {
    // Step 1: Validate request
    if (!customerId || !items || items.length === 0) {
      throw new Error('INVALID_REQUEST: customerId and items are required');
    }

    if (!idempotencyKey) {
      throw new Error('INVALID_REQUEST: idempotencyKey is required');
    }

    if (!/^[a-zA-Z0-9\-]{20,255}$/.test(idempotencyKey)) {
      throw new Error('INVALID_REQUEST: idempotencyKey must be 20-255 alphanumeric characters');
    }

    // ✅ CRITICAL FIX: Verify all items from same shop
    const shopIds = new Set(items.map(i => i.shopId));
    if (shopIds.size > 1) {
      throw new Error('MULTI_SHOP_NOT_SUPPORTED: All items must be from same shop');
    }
    if (shopIds.size === 0) {
      throw new Error('INVALID_REQUEST: shopId required for all items');
    }
    const shopId = Array.from(shopIds)[0];

    // ✅ CRITICAL FIX: Fetch actual prices from database (don't trust client)
    const productIds = items.map(i => i.productId);
    const productsRes = await pool.query(
      `SELECT id, price FROM products WHERE id = ANY($1)`,
      [productIds]
    );

    if (productsRes.rows.length !== items.length) {
      throw new Error('PRODUCT_NOT_FOUND: Some products in cart do not exist');
    }

    const priceMap = Object.fromEntries(productsRes.rows.map(r => [r.id, r.price]));

    // Calculate subtotal with TRUSTED prices from database
    let subtotal = 0;
    for (const item of items) {
      const trustedPrice = priceMap[item.productId];
      if (!trustedPrice) {
        throw new Error(`PRODUCT_NOT_FOUND: ${item.productId}`);
      }
      subtotal += trustedPrice * item.quantity;
    }
    console.log(`[CheckoutService] Subtotal (from DB prices): ₹${subtotal}`);

    // Step 3: ✅ FIX #1 - Validate and apply coupon (SERVER-SIDE)
    let discountAmount = 0;
    let couponId = null;
    if (couponCode) {
      try {
        const couponResult = await CouponService.validateAndApply({
          couponCode,
          orderTotal: subtotal,
          userId: customerId,
          items: items.map(i => ({product_id: i.productId, category: i.category}))
        });

        if (!couponResult.valid) {
          throw new Error(`COUPON_ERROR: ${couponResult.error}`);
        }

        discountAmount = couponResult.discount;
        couponId = couponResult.couponId;
        console.log(`[CheckoutService] ✅ Coupon applied: ${couponCode}, discount: ₹${discountAmount}`);
      } catch (err) {
        console.error(`[CheckoutService] ❌ Coupon validation failed:`, err.message);
        throw err;
      }
    }

    // ✅ PRE-CHECK: Validate delivery address exists and belongs to customer
    if (deliveryAddressId) {
      const addrRes = await pool.query(
        `SELECT id FROM users_addresses WHERE id = $1 AND user_id = $2`,
        [deliveryAddressId, customerId]
      );
      if (addrRes.rows.length === 0) {
        throw new Error('DELIVERY_ADDRESS_NOT_FOUND: Address does not exist or does not belong to customer');
      }
    }

    // Step 4: ✅ FIX #2 - Calculate shipping fee (SERVER-SIDE)
    let shippingFee = 0;
    let estimatedDeliveryDate = null;
    if (deliveryAddressId) {
      try {
        const shippingResult = await ShippingService.calculateFee({
          deliveryType,
          deliveryAddressId,
          subtotal,
          items
        });
        shippingFee = shippingResult.fee;
        estimatedDeliveryDate = shippingResult.estimatedDeliveryDate;
        console.log(`[CheckoutService] ✅ Shipping calculated: ₹${shippingFee}, type: ${deliveryType}`);
      } catch (err) {
        console.error(`[CheckoutService] ⚠️ Shipping calculation failed:`, err.message);
        // Don't throw - use free shipping as fallback
        shippingFee = 0;
      }
    }

    // Step 5: Calculate final amount (subtotal - discount + shipping)
    const finalAmount = subtotal - discountAmount + shippingFee;
    console.log(`[CheckoutService] Final amount: ₹${subtotal} - ₹${discountAmount} + ₹${shippingFee} = ₹${finalAmount}`);

    // Step 6: Create Razorpay order FIRST (before any DB changes)
    // This prevents the state where stock is reserved but no payment order exists
    // ✅ FIX: Use CORRECT final amount (with discount + shipping)
    let razorpayOrder;
    try {
      const razorpayResponse = await razorpay.createOrder({
        amount: Math.round(finalAmount * 100), // Convert to paise - ✅ CORRECT AMOUNT
        currency: 'INR',
        receipt: `fufaji-${customerId}-${Date.now()}`,
        notes: {
          customerId,
          couponCode: couponCode || 'NONE',
          discountAmount,
          shippingFee,
          paymentMethod,
        },
      });

      if (!razorpayResponse.data || razorpayResponse.data.error) {
        throw new Error(`Razorpay API error: ${JSON.stringify(razorpayResponse.data?.error || 'Unknown error')}`);
      }

      razorpayOrder = razorpayResponse.data;
      console.log(`[CheckoutService] ✅ Created Razorpay order: ${razorpayOrder.id}, amount: ₹${finalAmount}`);
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

      // ✅ FIX: RE-VALIDATE COUPON INSIDE TRANSACTION
      // Coupon could have expired or hit usage limit between initial validation and now
      if (couponCode && couponId) {
        const couponRecheck = await client.query(
          `SELECT id, is_active, valid_to, max_usage, used_count
           FROM coupons WHERE id = $1 AND is_active = true`,
          [couponId]
        );

        if (couponRecheck.rows.length === 0) {
          throw new Error('COUPON_INVALID: Coupon is no longer active');
        }

        const cpn = couponRecheck.rows[0];
        if (cpn.valid_to && new Date(cpn.valid_to) < new Date()) {
          throw new Error('COUPON_EXPIRED: Coupon is no longer valid');
        }

        if (cpn.max_usage && cpn.used_count >= cpn.max_usage) {
          throw new Error('COUPON_LIMIT_EXCEEDED: Coupon usage limit reached');
        }

        // ✅ FIX: Atomically increment coupon usage count
        const incrementRes = await client.query(
          `UPDATE coupons
           SET used_count = used_count + 1
           WHERE id = $1 AND used_count < max_usage
           RETURNING used_count`,
          [couponId]
        );

        if (incrementRes.rows.length === 0) {
          throw new Error('COUPON_LIMIT_EXCEEDED: Could not increment coupon usage');
        }

        console.log(`[CheckoutService] ✅ Coupon re-validated and incremented: ${couponCode}`);
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

      await client.query(
        `INSERT INTO checkout_sessions
         (id, customer_id, shop_id, status, subtotal, discount_amount, shipping_fee, total_amount, razorpay_order_id, coupon_id, coupon_code, delivery_address_id, delivery_type, estimated_delivery_date, idempotency_key, expires_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, CURRENT_TIMESTAMP + INTERVAL '30 minutes')`,
        [
          checkoutSessionId,
          customerId,
          items[0].shopId, // Use first item's shop (same shop assumption)
          'inventory_reserved',
          subtotal,
          discountAmount,
          shippingFee,
          finalAmount, // ✅ CORRECT: includes discount + shipping
          razorpayOrder.id,
          couponId,
          couponCode || null,
          deliveryAddressId || null,
          deliveryType,
          estimatedDeliveryDate,
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
        // ✅ FIX: Use DB price, not client price
        const trustedPrice = priceMap[item.productId];
        const itemSubtotal = trustedPrice * item.quantity;

        // Create reservation_item record
        await client.query(
          `INSERT INTO reservation_items (reservation_id, product_id, quantity, price_per_unit, subtotal)
           VALUES ($1, $2, $3, $4, $5)`,
          [
            reservationId,
            item.productId,
            item.quantity,
            trustedPrice,
            itemSubtotal,
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
        `INSERT INTO orders (id, customer_id, shop_id, status, subtotal_amount, discount_amount, shipping_fee, total_amount, coupon_id, checkout_session_id, reservation_id, payment_order_id, delivery_type, estimated_delivery_date)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
        [
          orderId,
          customerId,
          items[0].shopId,
          'pending',
          subtotal,
          discountAmount,
          shippingFee,
          finalAmount, // ✅ CORRECT: includes discount + shipping
          couponId,
          checkoutSessionId,
          reservationId,
          razorpayOrder.id,
          deliveryType,
          estimatedDeliveryDate,
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
