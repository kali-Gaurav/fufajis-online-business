# Inventory Consistency Stress Test Plan
**Risk Level:** CRITICAL  
**Timeline:** Must run before launch  
**Objective:** Verify no stock corruption under high concurrency + delays

---

## Hypothesis

**The Hardest Problem in Fufaji:**
```
Customer A: Buys last milk packet (1/1 available)
             Reservation created, stock locked
Customer B: Also buys last milk packet (concurrent)
             Reservation created? (RACE CONDITION)
Webhook A: Delayed 2 hours
Webhook B: Arrives immediately
           Confirms stock for Customer B
Customer A: Webhook arrives after 2 hours
           Tries to confirm... but stock already sold
           What happens?
```

**Risk:** Oversold inventory, customer gets refund, lost revenue.

---

## Test Scenarios

### Scenario 1: Concurrent Checkouts on Limited Stock

**Setup:**
```sql
INSERT INTO products (id, name, price, available_quantity, total_quantity, shop_id)
VALUES ('milk-id', 'Amul Milk 1L', 60, 5, 5, 'shop-1');
```

**Test:**
```javascript
// Simulate 10 concurrent checkout requests for 5 units
const results = await Promise.allSettled(
  Array(10).fill(null).map((_, i) =>
    CheckoutService.createOrderWithReservation({
      customerId: `user-${i}`,
      items: [{ productId: 'milk-id', quantity: 1, shopId: 'shop-1' }],
      idempotencyKey: `test-stress-${i}`,
      deliveryAddressId: 'addr-1',
      deliveryType: 'standard',
    })
  )
);

// Verify results
const succeeded = results.filter(r => r.status === 'fulfilled').length;
const failed = results.filter(r => r.status === 'rejected').length;

console.log(`✓ Checkouts succeeded: ${succeeded}`);
console.log(`✗ Checkouts failed: ${failed}`);

// PASS CONDITION: Exactly 5 succeeded, 5 failed
expect(succeeded).toBe(5);
expect(failed).toBe(5);
```

**Verify Inventory State:**
```javascript
const product = await pool.query(
  'SELECT available_quantity, reserved_quantity FROM products WHERE id = $1',
  ['milk-id']
);

// Should be: 0 available, 5 reserved (no overflow)
expect(product.rows[0].available_quantity).toBe(0);
expect(product.rows[0].reserved_quantity).toBe(5);
expect(product.rows[0].available_quantity + product.rows[0].reserved_quantity).toBe(5);  // Total intact
```

---

### Scenario 2: Delayed Payment Webhook

**Setup:**
```
Order 1: Checkout → Reservation locked → Webhook delayed 2 hours
Order 2: Same product, other customer → Checkout immediately after Order 1
```

**Test:**
```javascript
// Step 1: Customer A orders
const order1 = await CheckoutService.createOrderWithReservation({
  customerId: 'user-a',
  items: [{ productId: 'milk-id', quantity: 1 }],
  idempotencyKey: 'test-delay-a',
  deliveryAddressId: 'addr-1',
  deliveryType: 'standard',
});

// Step 2: Verify reservation created
let reservation1 = await pool.query(
  'SELECT * FROM reservations WHERE id = $1',
  [order1.reservationId]
);
expect(reservation1.rows[0].status).toBe('active');
expect(reservation1.rows[0].expires_at).toBeAfter(Date.now());

// Step 3: Customer B orders (immediately after)
const order2 = await CheckoutService.createOrderWithReservation({
  customerId: 'user-b',
  items: [{ productId: 'milk-id', quantity: 1 }],
  idempotencyKey: 'test-delay-b',
  deliveryAddressId: 'addr-1',
  deliveryType: 'standard',
});

// Should succeed (different unit)
expect(order2.orderId).toBeDefined();

// Step 4: Webhook for Order 1 (delayed 2 hours)
await simulateDelay(2 * 60 * 60 * 1000);  // 2 hours

const webhook1 = await PaymentService.processPaymentWebhook(
  'razorpay_pay_order1',
  order1.paymentOrderId,
  'fake_signature'
);

// Step 5: Verify both orders processed correctly
const orders = await pool.query(
  'SELECT id, status FROM orders WHERE id IN ($1, $2)',
  [order1.orderId, order2.orderId]
);

// Both should be confirmed
expect(orders.rows).toHaveLength(2);
expect(orders.rows.every(o => o.status === 'confirmed')).toBe(true);

// No inventory mismatch
const final = await pool.query(
  'SELECT available_quantity, reserved_quantity FROM products WHERE id = $1',
  ['milk-id']
);
expect(final.rows[0].available_quantity + final.rows[0].reserved_quantity).toBe(5);  // Integrity intact
```

---

### Scenario 3: Refund Race Condition

**Setup:**
```
Order confirmed
Payment succeeded
Customer requests refund (2 concurrent requests)
```

**Test:**
```javascript
// Step 1: Create & confirm order
const order = await CheckoutService.createOrderWithReservation({...});
await PaymentService.processPaymentWebhook(...);

// Step 2: Two concurrent refund requests
const refunds = await Promise.allSettled([
  pool.query('POST /refunds/request', { orderId: order.orderId, reason: 'Damaged' }),
  pool.query('POST /refunds/request', { orderId: order.orderId, reason: 'Wrong item' }),
]);

// PASS: Only 1 refund created
const refundCount = await pool.query(
  'SELECT COUNT(*) FROM refund_requests WHERE order_id = $1 AND status = "pending"',
  [order.orderId]
);
expect(refundCount.rows[0].count).toBe(1);
```

---

### Scenario 4: Stale Reservation Cleanup

**Setup:**
```
Order 1: Reservation created, expires in 10 minutes
Wait 12 minutes (expiry passes)
Cleanup cron runs
Verify stock returned to available
```

**Test:**
```javascript
// Step 1: Create order (10 min expiry)
const before = await pool.query(
  'SELECT available_quantity, reserved_quantity FROM products WHERE id = $1',
  ['milk-id']
);
const availableBefore = before.rows[0].available_quantity;
const reservedBefore = before.rows[0].reserved_quantity;

const order = await CheckoutService.createOrderWithReservation({...});

// Verify stock locked
const afterCheckout = await pool.query(
  'SELECT available_quantity, reserved_quantity FROM products WHERE id = $1',
  ['milk-id']
);
expect(afterCheckout.rows[0].available_quantity).toBe(availableBefore - 1);
expect(afterCheckout.rows[0].reserved_quantity).toBe(reservedBefore + 1);

// Step 2: Wait for expiry
await simulateDelay(12 * 60 * 1000);  // 12 minutes

// Step 3: Run cleanup cron
await CleanupCron.execute();

// Step 4: Verify stock released
const afterCleanup = await pool.query(
  'SELECT available_quantity, reserved_quantity FROM products WHERE id = $1',
  ['milk-id']
);
expect(afterCleanup.rows[0].available_quantity).toBe(availableBefore);  // Back to original
expect(afterCleanup.rows[0].reserved_quantity).toBe(reservedBefore);

// Verify reservation marked as expired
const reservation = await pool.query(
  'SELECT status FROM reservations WHERE id = $1',
  [order.reservationId]
);
expect(reservation.rows[0].status).toBe('expired');
```

---

### Scenario 5: Concurrent Cancellations

**Setup:**
```
Order 1: Confirmed
Customer hits cancel 3 times concurrently
```

**Test:**
```javascript
const order = await CheckoutService.createOrderWithReservation({...});

// Concurrent cancellations
const cancels = await Promise.allSettled([
  InventoryService.releaseReservation(order.reservationId),
  InventoryService.releaseReservation(order.reservationId),
  InventoryService.releaseReservation(order.reservationId),
]);

// PASS: All succeed (idempotent)
expect(cancels.every(r => r.status === 'fulfilled')).toBe(true);

// Inventory released exactly once
const product = await pool.query(
  'SELECT available_quantity FROM products WHERE id = $1',
  [order.items[0].productId]
);
// Should not double-release (available_quantity not > original)
expect(product.rows[0].available_quantity).toBeLessThanOrEqual(5);  // Assuming 5 total
```

---

### Scenario 6: Payment After Expiry

**Setup:**
```
Order: Checkout → Reservation expires (10 min) → Payment webhook arrives (delayed)
```

**Test:**
```javascript
const order = await CheckoutService.createOrderWithReservation({...});

// Wait for expiry
await simulateDelay(12 * 60 * 1000);

// Run cleanup to expire reservation
await CleanupCron.execute();

// Verify reservation expired
const reservation = await pool.query(
  'SELECT status FROM reservations WHERE id = $1',
  [order.reservationId]
);
expect(reservation.rows[0].status).toBe('expired');

// Now payment webhook arrives (late)
const webhookResult = await PaymentService.processPaymentWebhook(
  'razorpay_pay_late',
  order.paymentOrderId,
  'fake_signature'
);

// Should trigger RECOVERY path (re-lock inventory or refund)
expect(webhookResult.status).toMatch(/recovered|refund_initiated/);
```

---

## Load Test

**Concurrent Users:** 50  
**Duration:** 10 minutes  
**Requests:** Checkout every 5 seconds per user = 500 checkouts/min

```javascript
const loadTest = async () => {
  const startTime = Date.now();
  const results = [];
  let checkout_count = 0;
  let failed_count = 0;

  for (let minute = 0; minute < 10; minute++) {
    for (let user = 0; user < 50; user++) {
      try {
        const order = await CheckoutService.createOrderWithReservation({
          customerId: `user-${user}`,
          items: [{ productId: 'milk-id', quantity: 1 }],
          idempotencyKey: `load-${Date.now()}-${user}`,
          deliveryAddressId: 'addr-1',
          deliveryType: 'standard',
        });
        checkout_count++;
        results.push({ orderId: order.orderId, success: true });
      } catch (err) {
        failed_count++;
        results.push({ error: err.message, success: false });
      }
    }

    // Simulate payment webhooks (10s delay on average)
    for (const result of results.slice(-50)) {
      if (result.success) {
        try {
          await simulateDelay(Math.random() * 10000);  // 0-10s delay
          await PaymentService.processPaymentWebhook(...);
        } catch (err) {
          console.error('Webhook failed:', err.message);
        }
      }
    }

    console.log(`Minute ${minute}: ${checkout_count} checkouts, ${failed_count} failed`);
  }

  return { checkout_count, failed_count, duration: Date.now() - startTime };
};

const result = await loadTest();
console.log(`Load test complete: ${result.checkout_count} orders in ${result.duration}ms`);
```

---

## Pass/Fail Criteria

| Test | Condition | Status |
|------|-----------|--------|
| Concurrent Checkouts | Exactly 5 succeed, 5 fail on 5-unit stock | MUST PASS |
| Delayed Webhook | Both orders processed, no inventory mismatch | MUST PASS |
| Refund Race | Only 1 refund created, not duplicate | MUST PASS |
| Stale Cleanup | Stock released after expiry, inventory intact | MUST PASS |
| Concurrent Cancels | All idempotent, stock released once | MUST PASS |
| Payment After Expiry | Recovery path triggered, no corruption | MUST PASS |
| Load Test | 5000 checkouts, <1% failure, inventory accurate | MUST PASS |

**LAUNCH DECISION:** All 7 tests pass OR defer launch.

---

## Monitoring During Test

**Metrics to Watch:**
```sql
-- Inventory mismatch detector
SELECT id, name,
  (available_quantity + reserved_quantity) as total_tracked,
  total_quantity as actual_total,
  (available_quantity + reserved_quantity - total_quantity) as discrepancy
FROM products
WHERE total_quantity > 0
HAVING (available_quantity + reserved_quantity) != total_quantity;

-- Stuck orders
SELECT COUNT(*) as stuck_orders FROM orders
WHERE status = 'payment_pending'
  AND created_at < NOW() - INTERVAL '5 minutes';

-- Reservation anomalies
SELECT COUNT(*) FROM reservations
WHERE status NOT IN ('active', 'confirmed', 'expired', 'released');

-- Deadlock detection
SELECT wait_event, count(*) FROM pg_stat_activity
WHERE wait_event_type = 'Lock'
GROUP BY wait_event;
```

---

## Before Test Checklist

- [ ] Database backed up
- [ ] Cleanup cron disabled (will run manually)
- [ ] Payment reconciliation cron disabled (will run manually)
- [ ] All code changes deployed
- [ ] Logging enabled (query slow_query_log)
- [ ] Monitoring dashboard ready
- [ ] Team on standby

---

## Success Criteria

**Zero inventory corruption under:**
- 10 concurrent checkouts on 5-unit stock
- 2-hour payment webhook delays
- Concurrent cancellations
- Stale reservation cleanup
- 5000 concurrent orders over 10 minutes

**If ANY test fails:** Do NOT launch. Debug and fix.

