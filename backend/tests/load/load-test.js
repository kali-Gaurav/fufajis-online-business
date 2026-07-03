// Load Test: Concurrent Checkouts
// Simulate 100+ concurrent checkout attempts on 10-unit stock
// Verify exactly 10 succeed, rest fail (no overselling)

const pool = require('../../src/db/pool');
const CheckoutService = require('../../src/services/checkout-service');

async function runLoadTest() {
  console.log('🚀 Starting load test: 100 concurrent checkouts on 10-unit stock');

  await pool.init();

  const concurrent = 100;
  const productId = 'prod-load-test';
  const stockAvailable = 10;
  let successCount = 0;
  let failureCount = 0;
  const timings = [];

  // Prepare test product with limited stock
  await pool.query(
    `INSERT INTO products (id, name, shop_id, total_quantity, available_quantity, reserved_quantity)
     VALUES ($1, $2, $3, $4, $5, $6)
     ON CONFLICT (id) DO UPDATE SET available_quantity = $5, reserved_quantity = $6`,
    [productId, 'Load Test Product', 'shop-load-test', stockAvailable, stockAvailable, 0]
  );

  // Launch 100 concurrent checkouts
  const promises = [];
  const startTime = Date.now();

  for (let i = 0; i < concurrent; i++) {
    const checkoutPromise = (async () => {
      const attemptStart = Date.now();

      try {
        await CheckoutService.createOrderWithReservation({
          customerId: `load-test-cust-${i}`,
          items: [
            {
              productId,
              quantity: 1,
              price: 100,
              shopId: 'shop-load-test',
            },
          ],
          paymentMethod: 'razorpay',
          idempotencyKey: `load-${i}-${Date.now()}`,
        });

        successCount++;
        timings.push(Date.now() - attemptStart);
        return { status: 'success', timing: Date.now() - attemptStart };
      } catch (err) {
        if (err.message.includes('INSUFFICIENT_STOCK')) {
          failureCount++;
          return { status: 'expected_failure', error: err.message, timing: Date.now() - attemptStart };
        }
        return { status: 'unexpected_error', error: err.message, timing: Date.now() - attemptStart };
      }
    })();

    promises.push(checkoutPromise);
  }

  // Wait for all checkouts to complete
  const results = await Promise.all(promises);
  const totalTime = Date.now() - startTime;

  // Analyze results
  const successes = results.filter(r => r.status === 'success');
  const expectedFailures = results.filter(r => r.status === 'expected_failure');
  const unexpectedErrors = results.filter(r => r.status === 'unexpected_error');

  // Calculate percentiles
  const sortedTimings = timings.sort((a, b) => a - b);
  const p50 = sortedTimings[Math.floor(sortedTimings.length * 0.5)];
  const p95 = sortedTimings[Math.floor(sortedTimings.length * 0.95)];
  const p99 = sortedTimings[Math.floor(sortedTimings.length * 0.99)];

  console.log('\n' + '='.repeat(60));
  console.log('📊 LOAD TEST RESULTS');
  console.log('='.repeat(60));
  console.log(`\nConcurrency: ${concurrent} simultaneous checkouts`);
  console.log(`Stock Available: ${stockAvailable} units`);
  console.log(`Total Time: ${totalTime}ms (${(totalTime / 1000).toFixed(2)}s)`);

  console.log('\n✅ SUCCESSES:');
  console.log(`  Count: ${successes.length} (expected: ${stockAvailable})`);
  console.log(`  Result: ${successes.length === stockAvailable ? '✅ PASS' : '❌ FAIL'}`);

  console.log('\n❌ EXPECTED FAILURES (INSUFFICIENT_STOCK):');
  console.log(`  Count: ${expectedFailures.length} (expected: ${concurrent - stockAvailable})`);
  console.log(`  Result: ${expectedFailures.length === concurrent - stockAvailable ? '✅ PASS' : '❌ FAIL'}`);

  console.log('\n⚠️  UNEXPECTED ERRORS:');
  console.log(`  Count: ${unexpectedErrors.length} (expected: 0)`);
  console.log(`  Result: ${unexpectedErrors.length === 0 ? '✅ PASS' : '❌ FAIL'}`);
  if (unexpectedErrors.length > 0) {
    unexpectedErrors.slice(0, 3).forEach(e => {
      console.log(`    - ${e.error}`);
    });
  }

  console.log('\n⏱️  LATENCY METRICS (successful checkouts):');
  console.log(`  Min: ${Math.min(...timings)}ms`);
  console.log(`  Max: ${Math.max(...timings)}ms`);
  console.log(`  P50: ${p50}ms`);
  console.log(`  P95: ${p95}ms`);
  console.log(`  P99: ${p99}ms`);

  // Verify inventory state
  const inventoryCheck = await pool.query(
    `SELECT available_quantity, reserved_quantity FROM products WHERE id = $1`,
    [productId]
  );

  const { available_quantity: available, reserved_quantity: reserved } = inventoryCheck.rows[0];
  console.log('\n📦 INVENTORY STATE:');
  console.log(`  Available: ${available} (expected: 0)`);
  console.log(`  Reserved: ${reserved} (expected: ${stockAvailable})`);
  console.log(`  Total: ${available + reserved} (expected: ${stockAvailable})`);

  // Overall verdict
  console.log('\n' + '='.repeat(60));
  const allPass =
    successes.length === stockAvailable &&
    expectedFailures.length === concurrent - stockAvailable &&
    unexpectedErrors.length === 0 &&
    available + reserved === stockAvailable;

  console.log(allPass ? '✅ LOAD TEST PASSED' : '❌ LOAD TEST FAILED');
  console.log('='.repeat(60) + '\n');

  await pool.shutdown();
  process.exit(allPass ? 0 : 1);
}

runLoadTest().catch(err => {
  console.error('Load test crashed:', err);
  process.exit(1);
});
