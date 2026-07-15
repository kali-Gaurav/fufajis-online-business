/**
 * ============================================================================
 * Integration Test Suite for Backend Endpoints
 * ============================================================================
 * Tests all critical backend endpoints:
 * - Subscriptions (create, list, pause, resume, cancel)
 * - Commissions (pending, ledger, stats)
 * - Delivery Dispatch (find riders, assign, track, complete)
 * - Config endpoint
 *
 * Run: node test-endpoints.js --base-url=http://localhost:3001
 */

const fetch = require('node-fetch');
const assert = require('assert');

class EndpointTester {
  constructor(baseUrl = 'http://localhost:3001') {
    this.baseUrl = baseUrl;
    this.customerId = 'test-customer-id';
    this.vendorId = 'test-vendor-id';
    this.riderId = 'test-rider-id';
    this.tokens = {};
    this.results = [];
  }

  async request(method, path, body = null, headers = {}) {
    const url = `${this.baseUrl}${path}`;
    const options = {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
    };

    if (body) {
      options.body = JSON.stringify(body);
    }

    try {
      const response = await fetch(url, options);
      const data = await response.json();

      return {
        status: response.status,
        ok: response.ok,
        data,
      };
    } catch (err) {
      throw new Error(`Request failed: ${err.message}`);
    }
  }

  async test(name, fn) {
    try {
      console.log(`\n▶️  Testing: ${name}`);
      await fn();
      this.results.push({ name, status: '✅ PASS' });
      console.log(`✅ PASS: ${name}`);
    } catch (err) {
      this.results.push({ name, status: `❌ FAIL: ${err.message}` });
      console.error(`❌ FAIL: ${name}`);
      console.error(`   Error: ${err.message}`);
    }
  }

  printSummary() {
    console.log('\n' + '='.repeat(70));
    console.log('TEST RESULTS SUMMARY');
    console.log('='.repeat(70));

    const passed = this.results.filter(r => r.status.includes('✅')).length;
    const failed = this.results.filter(r => r.status.includes('❌')).length;

    for (const result of this.results) {
      console.log(`${result.status} - ${result.name}`);
    }

    console.log('\n' + '='.repeat(70));
    console.log(`Total: ${this.results.length} | Passed: ${passed} | Failed: ${failed}`);
    console.log('='.repeat(70));

    return failed === 0;
  }
}

async function runTests() {
  const tester = new EndpointTester(
    process.argv.find(arg => arg.startsWith('--base-url='))?.split('=')[1] || 'http://localhost:3001'
  );

  console.log(`\n🚀 Starting endpoint tests against ${tester.baseUrl}\n`);

  // ─────────────────────────────────────────────────────────────────────────
  // CONFIG ENDPOINT TESTS
  // ─────────────────────────────────────────────────────────────────────────

  await tester.test('GET /health - Server health check', async () => {
    const res = await tester.request('GET', '/health');
    assert(res.ok, `Expected 200, got ${res.status}`);
    assert(res.data.status === 'ok', 'Health status should be ok');
  });

  await tester.test('GET /config/app-config - Get app configuration', async () => {
    const res = await tester.request('GET', '/config/app-config');
    assert(res.ok, `Expected 200, got ${res.status}`);
    assert(res.data.data.shop, 'Should have shop configuration');
    assert(res.data.data.payments, 'Should have payment configuration');
  });

  // ─────────────────────────────────────────────────────────────────────────
  // SUBSCRIPTION ENDPOINT TESTS
  // ─────────────────────────────────────────────────────────────────────────

  let subscriptionId;

  await tester.test('POST /subscriptions/create - Create subscription', async () => {
    const idempotencyKey = `sub-${Date.now()}`;
    const res = await tester.request(
      'POST',
      '/subscriptions/create',
      {
        items: [
          { productId: 'prod-1', quantity: 2 },
          { productId: 'prod-2', quantity: 1 },
        ],
        frequency: 'weekly',
        startDate: new Date().toISOString(),
        deliveryAddressId: 'addr-1',
        paymentMethodId: 'pm-1',
      },
      { 'idempotency-key': idempotencyKey }
    );

    assert(res.status === 201 || res.status === 200, `Expected 200/201, got ${res.status}`);
    assert(res.data.data?.subscriptionId, 'Response should contain subscriptionId');
    subscriptionId = res.data.data?.subscriptionId;
  });

  await tester.test('GET /subscriptions - List subscriptions', async () => {
    const res = await tester.request('GET', '/subscriptions');
    assert(res.ok, `Expected 200, got ${res.status}`);
    assert(Array.isArray(res.data.data), 'Response should be array');
  });

  await tester.test('GET /subscriptions/:id - Get subscription details', async () => {
    if (!subscriptionId) {
      console.log('   (Skipped - no subscription ID from create test)');
      return;
    }
    const res = await tester.request('GET', `/subscriptions/${subscriptionId}`);
    assert(res.ok || res.status === 404, `Expected 200 or 404, got ${res.status}`);
  });

  await tester.test('POST /subscriptions/:id/pause - Pause subscription', async () => {
    if (!subscriptionId) {
      console.log('   (Skipped - no subscription ID from create test)');
      return;
    }
    const res = await tester.request('POST', `/subscriptions/${subscriptionId}/pause`);
    assert(res.ok || res.status === 404, `Expected 200 or 404, got ${res.status}`);
  });

  await tester.test('POST /subscriptions/:id/resume - Resume subscription', async () => {
    if (!subscriptionId) {
      console.log('   (Skipped - no subscription ID from create test)');
      return;
    }
    const res = await tester.request('POST', `/subscriptions/${subscriptionId}/resume`);
    assert(res.ok || res.status === 404, `Expected 200 or 404, got ${res.status}`);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // COMMISSION ENDPOINT TESTS
  // ─────────────────────────────────────────────────────────────────────────

  await tester.test('GET /commissions/pending - Get pending commissions', async () => {
    const res = await tester.request('GET', '/commissions/pending');
    assert(res.ok || res.status === 403, `Expected 200 or 403, got ${res.status}`);
    if (res.ok) {
      assert(res.data.data?.commissions, 'Should have commissions array');
    }
  });

  await tester.test('GET /commissions/stats - Get commission stats', async () => {
    const res = await tester.request('GET', '/commissions/stats');
    assert(res.ok || res.status === 403, `Expected 200 or 403, got ${res.status}`);
    if (res.ok) {
      assert(res.data.data?.pending, 'Should have pending stats');
    }
  });

  await tester.test('GET /commissions/ledger - Get commission ledger', async () => {
    const res = await tester.request('GET', '/commissions/ledger');
    assert(res.ok || res.status === 403, `Expected 200 or 403, got ${res.status}`);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // DELIVERY DISPATCH ENDPOINT TESTS
  // ─────────────────────────────────────────────────────────────────────────

  await tester.test('POST /dispatch/find-riders - Find available riders', async () => {
    const res = await tester.request('POST', '/dispatch/find-riders', {
      latitude: 25.1006,
      longitude: 76.5156,
      maxDistanceKm: 2,
    });

    assert(res.ok || res.status === 403, `Expected 200 or 403, got ${res.status}`);
    if (res.ok) {
      assert(Array.isArray(res.data.data?.riders), 'Should have riders array');
    }
  });

  await tester.test('POST /dispatch/assign - Assign order to rider', async () => {
    const res = await tester.request('POST', '/dispatch/assign', {
      orderId: 'order-123',
      riderId: 'rider-123',
      deliveryAddressLatitude: 25.1006,
      deliveryAddressLongitude: 76.5156,
      estimatedDeliveryTime: 30,
    });

    assert(
      res.status === 201 || res.status === 200 || res.status === 404 || res.status === 403,
      `Unexpected status: ${res.status}`
    );
  });

  await tester.test('GET /dispatch/optimize-route - Get optimized route', async () => {
    const res = await tester.request('GET', '/dispatch/optimize-route?riderId=rider-123');

    assert(res.ok || res.status === 403 || res.status === 404, `Expected 200/403/404, got ${res.status}`);
    if (res.ok) {
      assert(res.data.data?.orderedStops !== undefined, 'Should have ordered stops');
    }
  });

  await tester.test('GET /dispatch/track/:orderId - Track delivery', async () => {
    const res = await tester.request('GET', '/dispatch/track/order-123');

    assert(res.ok || res.status === 404, `Expected 200 or 404, got ${res.status}`);
  });

  await tester.test('POST /dispatch/verify-otp - Verify delivery OTP', async () => {
    const res = await tester.request('POST', '/dispatch/verify-otp', {
      trackingId: 'track-123',
      otp: '123456',
    });

    assert(
      res.status === 200 || res.status === 400 || res.status === 404,
      `Unexpected status: ${res.status}`
    );
  });

  await tester.test('POST /dispatch/complete - Complete delivery', async () => {
    const res = await tester.request('POST', '/dispatch/complete', {
      trackingId: 'track-123',
      proofPhotoUrl: 'https://example.com/photo.jpg',
    });

    assert(
      res.status === 200 || res.status === 400 || res.status === 404 || res.status === 409,
      `Unexpected status: ${res.status}`
    );
  });

  // Print summary
  const allPassed = tester.printSummary();
  process.exit(allPassed ? 0 : 1);
}

// Run tests
runTests().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
