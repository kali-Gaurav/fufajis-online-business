// Checkout Integration Tests
// Test critical race conditions and idempotency

const pool = require('../../src/db/pool');
const CheckoutService = require('../../src/services/checkout-service');

describe('Checkout Service', () => {
  beforeAll(async () => {
    await pool.init();
  });

  afterAll(async () => {
    await pool.shutdown();
  });

  test('Happy path: Valid checkout creates order + reservation + locks inventory', async () => {
    const result = await CheckoutService.createOrderWithReservation({
      customerId: 'cust-001',
      items: [
        { productId: 'prod-001', quantity: 2, price: 100, shopId: 'shop-001' },
      ],
      paymentMethod: 'razorpay',
      idempotencyKey: `test-${Date.now()}-001`,
    });

    expect(result.orderId).toBeDefined();
    expect(result.paymentOrderId).toBeDefined();
    expect(result.reservationId).toBeDefined();
    expect(result.expiresAt).toBeDefined();
  });

  test('Overselling prevention: Second checkout fails when stock exhausted', async () => {
    const idempotencyKey1 = `test-${Date.now()}-overs-1`;
    const idempotencyKey2 = `test-${Date.now()}-overs-2`;

    // First checkout takes last 2 units
    const checkout1 = await CheckoutService.createOrderWithReservation({
      customerId: 'cust-002',
      items: [{ productId: 'prod-002', quantity: 2, price: 100, shopId: 'shop-001' }],
      paymentMethod: 'razorpay',
      idempotencyKey: idempotencyKey1,
    });

    expect(checkout1.orderId).toBeDefined();

    // Second checkout tries to take 1 unit (should fail - none left)
    try {
      await CheckoutService.createOrderWithReservation({
        customerId: 'cust-003',
        items: [{ productId: 'prod-002', quantity: 1, price: 100, shopId: 'shop-001' }],
        paymentMethod: 'razorpay',
        idempotencyKey: idempotencyKey2,
      });
      fail('Should have thrown INSUFFICIENT_STOCK');
    } catch (err) {
      expect(err.message).toContain('INSUFFICIENT_STOCK');
    }
  });

  test('Idempotency: Same key returns same order', async () => {
    const idempotencyKey = `test-${Date.now()}-idempotent`;

    const result1 = await CheckoutService.createOrderWithReservation({
      customerId: 'cust-004',
      items: [{ productId: 'prod-003', quantity: 1, price: 100, shopId: 'shop-001' }],
      paymentMethod: 'razorpay',
      idempotencyKey,
    });

    const result2 = await CheckoutService.createOrderWithReservation({
      customerId: 'cust-004',
      items: [{ productId: 'prod-003', quantity: 1, price: 100, shopId: 'shop-001' }],
      paymentMethod: 'razorpay',
      idempotencyKey,
    });

    // Same idempotency key should return same order
    expect(result1.orderId).toBe(result2.orderId);
    expect(result1.reservationId).toBe(result2.reservationId);
  });

  test('TTL expiry: Expired reservation releases stock', async () => {
    // Create reservation that will expire
    const idempotencyKey = `test-${Date.now()}-expire`;

    const result = await CheckoutService.createOrderWithReservation({
      customerId: 'cust-005',
      items: [{ productId: 'prod-004', quantity: 3, price: 100, shopId: 'shop-001' }],
      paymentMethod: 'razorpay',
      idempotencyKey,
    });

    // Manually expire the reservation
    await pool.query(
      `UPDATE reservations SET status = 'active', expires_at = CURRENT_TIMESTAMP - INTERVAL '1 second' WHERE id = $1`,
      [result.reservationId]
    );

    // Run cleanup job
    const CleanupCron = require('../../src/jobs/cleanup-cron');
    await CleanupCron.execute();

    // Verify reservation is marked expired
    const resCheck = await pool.query(
      `SELECT status FROM reservations WHERE id = $1`,
      [result.reservationId]
    );

    expect(resCheck.rows[0].status).toBe('expired');

    // Verify stock was released
    const prodCheck = await pool.query(
      `SELECT available_quantity, reserved_quantity FROM products WHERE id = $1`,
      [result.items[0].productId]
    );

    expect(prodCheck.rows[0].reserved_quantity).toBe(0);
  });

  test('Concurrent checkouts on same stock (race condition test)', async () => {
    // This test verifies locking prevents race conditions
    // Both checkouts try to reserve same 2 units simultaneously
    // Only one should succeed

    const promises = [];
    for (let i = 0; i < 2; i++) {
      promises.push(
        CheckoutService.createOrderWithReservation({
          customerId: `cust-race-${i}`,
          items: [{ productId: 'prod-005', quantity: 2, price: 100, shopId: 'shop-001' }],
          paymentMethod: 'razorpay',
          idempotencyKey: `test-${Date.now()}-race-${i}`,
        }).catch(err => ({ error: err.message }))
      );
    }

    const results = await Promise.all(promises);

    // One should succeed, one should fail
    const successes = results.filter(r => !r.error);
    const failures = results.filter(r => r.error);

    expect(successes.length).toBe(1);
    expect(failures.length).toBe(1);
    expect(failures[0].error).toContain('INSUFFICIENT_STOCK');
  });
});

module.exports = {};
