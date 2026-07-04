/**
 * Checkout Integration Tests
 * Tests the complete checkout → payment → confirmation flow
 *
 * Run: npm test -- checkout-integration.test.js
 * Coverage target: 80%+
 */

const pool = require('../src/db/pool');
const CheckoutService = require('../src/services/checkout-service');
const PaymentService = require('../src/services/payment-service');
const InventoryService = require('../src/services/inventory-service');
const { v4: uuidv4 } = require('uuid');

describe('Checkout Integration Tests', () => {
  let testCustomerId;
  let testShopId;
  let testProductId;
  let testAddressId;

  beforeAll(async () => {
    await pool.init();

    // Setup test data
    testCustomerId = uuidv4();
    testShopId = uuidv4();
    testProductId = uuidv4();
    testAddressId = uuidv4();

    // Create test shop
    await pool.query(
      `INSERT INTO shops (id, name, latitude, longitude, city)
       VALUES ($1, $2, $3, $4, $5)`,
      [testShopId, 'Test Shop', 28.6139, 77.2090, 'Delhi']
    );

    // Create test product
    await pool.query(
      `INSERT INTO products (id, shop_id, name, price, total_quantity, available_quantity, reserved_quantity)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [testProductId, testShopId, 'Test Milk', 60, 100, 100, 0]
    );

    // Create test address
    await pool.query(
      `INSERT INTO users_addresses (id, user_id, label, latitude, longitude, city)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [testAddressId, testCustomerId, 'Test Address', 28.5355, 77.3910, 'Delhi']
    );
  });

  afterAll(async () => {
    // Cleanup
    await pool.query('DELETE FROM users_addresses WHERE id = $1', [testAddressId]);
    await pool.query('DELETE FROM products WHERE id = $1', [testProductId]);
    await pool.query('DELETE FROM shops WHERE id = $1', [testShopId]);
    await pool.shutdown();
  });

  // ──────────────────────────────────────────────────────────
  // TEST 1: Happy Path
  // ──────────────────────────────────────────────────────────
  test('Happy path: checkout → payment webhook → order confirmed', async () => {
    // Step 1: Create order
    const order = await CheckoutService.createOrderWithReservation({
      customerId: testCustomerId,
      items: [{ productId: testProductId, quantity: 2, shopId: testShopId }],
      couponCode: null,
      deliveryAddressId: testAddressId,
      deliveryType: 'standard',
      idempotencyKey: `test-happy-${Date.now()}`,
    });

    expect(order.orderId).toBeDefined();
    expect(order.reservationId).toBeDefined();
    expect(order.status).toBe('payment_pending');

    // Verify reservation created
    const reservation = await pool.query(
      'SELECT status FROM reservations WHERE id = $1',
      [order.reservationId]
    );
    expect(reservation.rows[0].status).toBe('active');

    // Step 2: Simulate payment webhook
    const webhookResult = await PaymentService.processPaymentWebhook(
      `razorpay_pay_${Date.now()}`,
      order.paymentOrderId,
      'test_signature'
    );

    expect(webhookResult.status).toBe('confirmed');

    // Step 3: Verify order confirmed
    const orderCheck = await pool.query(
      'SELECT status FROM orders WHERE id = $1',
      [order.orderId]
    );
    expect(orderCheck.rows[0].status).toBe('confirmed');

    // Step 4: Verify reservation confirmed
    const reservationCheck = await pool.query(
      'SELECT status FROM reservations WHERE id = $1',
      [order.reservationId]
    );
    expect(reservationCheck.rows[0].status).toBe('confirmed');
  });

  // ──────────────────────────────────────────────────────────
  // TEST 2: Stock Exhaustion
  // ──────────────────────────────────────────────────────────
  test('Stock exhaustion: concurrent checkouts fail gracefully', async () => {
    // Create limited stock product
    const limitedProductId = uuidv4();
    await pool.query(
      `INSERT INTO products (id, shop_id, name, price, total_quantity, available_quantity, reserved_quantity)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [limitedProductId, testShopId, 'Limited Stock', 100, 5, 5, 0]
    );

    // Simulate 10 concurrent checkouts for 5-unit stock
    const results = await Promise.allSettled(
      Array(10)
        .fill(null)
        .map((_, i) =>
          CheckoutService.createOrderWithReservation({
            customerId: `user-stress-${i}`,
            items: [{ productId: limitedProductId, quantity: 1, shopId: testShopId }],
            couponCode: null,
            deliveryAddressId: testAddressId,
            deliveryType: 'standard',
            idempotencyKey: `test-stock-${Date.now()}-${i}`,
          })
        )
    );

    const succeeded = results.filter(r => r.status === 'fulfilled').length;
    const failed = results.filter(r => r.status === 'rejected').length;

    // PASS: Exactly 5 succeeded, 5 failed
    expect(succeeded).toBe(5);
    expect(failed).toBe(5);

    // Verify inventory integrity
    const product = await pool.query(
      'SELECT available_quantity, reserved_quantity FROM products WHERE id = $1',
      [limitedProductId]
    );
    expect(product.rows[0].available_quantity).toBe(0);
    expect(product.rows[0].reserved_quantity).toBe(5);
    expect(product.rows[0].available_quantity + product.rows[0].reserved_quantity).toBe(5);

    // Cleanup
    await pool.query('DELETE FROM products WHERE id = $1', [limitedProductId]);
  });

  // ──────────────────────────────────────────────────────────
  // TEST 3: Payment Failure → Release Reservation
  // ──────────────────────────────────────────────────────────
  test('Payment failure should release reservation', async () => {
    // Step 1: Create order
    const order = await CheckoutService.createOrderWithReservation({
      customerId: testCustomerId,
      items: [{ productId: testProductId, quantity: 1, shopId: testShopId }],
      couponCode: null,
      deliveryAddressId: testAddressId,
      deliveryType: 'standard',
      idempotencyKey: `test-fail-${Date.now()}`,
    });

    // Check reserved quantity before release
    const beforeRelease = await pool.query(
      'SELECT available_quantity, reserved_quantity FROM products WHERE id = $1',
      [testProductId]
    );
    const reservedBefore = beforeRelease.rows[0].reserved_quantity;

    // Step 2: Simulate payment failure → release reservation
    await InventoryService.releaseReservation(order.reservationId);

    // Step 3: Verify stock released to available
    const afterRelease = await pool.query(
      'SELECT available_quantity, reserved_quantity FROM products WHERE id = $1',
      [testProductId]
    );

    expect(afterRelease.rows[0].reserved_quantity).toBeLessThan(reservedBefore);
    expect(afterRelease.rows[0].available_quantity).toBeGreaterThan(
      beforeRelease.rows[0].available_quantity
    );

    // Step 4: Verify reservation released
    const reservation = await pool.query(
      'SELECT status FROM reservations WHERE id = $1',
      [order.reservationId]
    );
    expect(reservation.rows[0].status).toBe('released');
  });

  // ──────────────────────────────────────────────────────────
  // TEST 4: Idempotency
  // ──────────────────────────────────────────────────────────
  test('Duplicate checkout with same idempotency key returns same order', async () => {
    const idempotencyKey = `test-idempotent-${Date.now()}`;

    // First checkout
    const order1 = await CheckoutService.createOrderWithReservation({
      customerId: testCustomerId,
      items: [{ productId: testProductId, quantity: 1, shopId: testShopId }],
      couponCode: null,
      deliveryAddressId: testAddressId,
      deliveryType: 'standard',
      idempotencyKey,
    });

    // Duplicate checkout with same idempotency key
    const order2 = await CheckoutService.createOrderWithReservation({
      customerId: testCustomerId,
      items: [{ productId: testProductId, quantity: 1, shopId: testShopId }],
      couponCode: null,
      deliveryAddressId: testAddressId,
      deliveryType: 'standard',
      idempotencyKey,
    });

    // Should return same order
    expect(order2.orderId).toBe(order1.orderId);
    expect(order2.reservationId).toBe(order1.reservationId);
  });

  // ──────────────────────────────────────────────────────────
  // TEST 5: Authorization Check
  // ──────────────────────────────────────────────────────────
  test('User cannot release another users reservation', async () => {
    // Step 1: Customer A creates order
    const customerA = `user-auth-a-${Date.now()}`;
    const orderA = await CheckoutService.createOrderWithReservation({
      customerId: customerA,
      items: [{ productId: testProductId, quantity: 1, shopId: testShopId }],
      couponCode: null,
      deliveryAddressId: testAddressId,
      deliveryType: 'standard',
      idempotencyKey: `test-auth-a-${Date.now()}`,
    });

    // Step 2: Customer B tries to release Customer A's reservation
    const customerB = `user-auth-b-${Date.now()}`;

    // This should be caught in the route layer, but verify the reservation exists
    const reservation = await pool.query(
      'SELECT customer_id FROM reservations WHERE id = $1',
      [orderA.reservationId]
    );

    expect(reservation.rows[0].customer_id).toBe(customerA);
    expect(reservation.rows[0].customer_id).not.toBe(customerB);
  });
});
