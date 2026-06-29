const fs = require('fs');
const path = require('path');

console.log('🏁 Starting Full-System Service Audit and Verification...\n');

// 1. Load root .env
try {
  const envPath = path.join(__dirname, '../../.env');
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf8');
    envContent.split(/\r?\n/).forEach(line => {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) return;
      const index = trimmed.indexOf('=');
      if (index === -1) return;
      const key = trimmed.substring(0, index).trim();
      let value = trimmed.substring(index + 1).trim().replace(/^['"]|['"]$/g, '');
      if (key) process.env[key] = value;
    });
    console.log('✅ Loaded root .env environment variables successfully.');
  }
} catch (e) {
  console.warn('⚠️ Failed to load root .env:', e.message);
}

const firebaseAdmin = require('./services/firebaseAdmin');
const secrets = require('./secrets');

// Import services to test
const CompetitorIntelligenceService = require('./services/CompetitorIntelligenceService');
const DemandForecastService = require('./services/DemandForecastService');
const MarginProtectionService = require('./services/MarginProtectionService');
const PromotionRecommendationService = require('./services/PromotionRecommendationService');
const ProcurementOptimizationService = require('./services/ProcurementOptimizationService');
const PricingOptimizationService = require('./services/PricingOptimizationService');
const RouteOptimizationService = require('./services/RouteOptimizationService');
const DeliveryOptimizationService = require('./services/DeliveryOptimizationService');
const DeliveryAssignmentService = require('./services/DeliveryAssignmentService');
const DeliveryCompletionService = require('./services/DeliveryCompletionService');
const RazorpayService = require('./services/RazorpayService');
const PaymentService = require('./services/PaymentService');
const { getAI } = require('./services/genkitService');

const results = {};

async function testService(name, testFn) {
  try {
    process.stdout.write(`⏳ Testing ${name}... `);
    const detail = await testFn();
    results[name] = { success: true, detail };
    console.log(`✅ Success!`);
  } catch (error) {
    results[name] = { success: false, error: error.message };
    console.log(`❌ Failed: ${error.message}`);
  }
}

async function runAudit() {
  // Initialize Core Services
  try {
    await secrets.loadSecrets();
    await firebaseAdmin.init();
    console.log('✅ Core Firebase & Secret Manager initialized.\n');
  } catch (e) {
    console.error('❌ Failed to initialize core Firebase/Secrets:', e.message);
    process.exit(1);
  }

  // 1. Test Secrets Module
  await testService('Secrets Service', async () => {
    const rzpKey = secrets.get('RAZORPAY_KEY_ID');
    return `RAZORPAY_KEY_ID configured: ${!!rzpKey}`;
  });

  // 2. Test Firestore Connection
  await testService('Firestore DB Connection', async () => {
    const db = firebaseAdmin.db();
    const testDoc = await db.collection('products').limit(1).get();
    return `Connection active. Fetched products count: ${testDoc.size}`;
  });

  // 3. Test Competitor Intelligence
  await testService('Competitor Intelligence Service', async () => {
    const prices = await CompetitorIntelligenceService.getCompetitorPrices('prod_test', 'Aashirvaad Atta', 'Grocery', 420.0);
    return `Retrieved ${prices.length} competitor prices. Avg: ₹${(prices.reduce((sum, p) => sum + p.price, 0) / prices.length).toFixed(2)}`;
  });

  // 4. Test Demand Forecast
  await testService('Demand Forecast Service', async () => {
    const demand = await DemandForecastService.calculateDemand('prod_test');
    return `Demand score calculated: ${demand.demandScore} (${demand.demandState})`;
  });

  // 5. Test Margin Protection
  await testService('Margin Protection Service', async () => {
    const check = MarginProtectionService.enforceMarginSafety(100.0, 95.0, 110.0, 'Grocery');
    return `Margin safety check: Proposed: ₹100, Cost: ₹95, Floor enforced: ₹${check.safePrice} (Is Safe: ${check.isSafe})`;
  });

  // 6. Test Genkit Gemini AI
  await testService('Gemini AI / Genkit Engine', async () => {
    // If Gemini key is empty, check mock or warn
    const apiKey = secrets.get('gemini/api_key');
    if (!apiKey) {
      throw new Error('GEMINI_API_KEY is not configured in environment.');
    }
    const ai = await getAI();
    return `Genkit engine initialized with model: ${ai.config.model?.name || 'gemini15Flash'}`;
  });

  // 7. Test Pricing Optimization
  await testService('Pricing Optimization Service', async () => {
    // Check if we can run pricing optimization with mock database data
    const db = firebaseAdmin.db();
    // Use an existing product or insert a temporary mock product for the test run
    let testProdId = 'mock_pricing_test';
    await db.collection('products').doc(testProdId).set({
      name: 'Test Atta',
      price: 250.0,
      costPrice: 200.0,
      category: 'Grocery',
      sku: 'TEST-SKU-ATTA'
    });
    
    try {
      const rec = await PricingOptimizationService.analyzeAndRecommend(testProdId);
      await db.collection('products').doc(testProdId).delete();
      return `AI price recommendation: ₹${rec.recommendedPrice} (Rationale: ${rec.rationale.substring(0, 40)}...)`;
    } catch (e) {
      await db.collection('products').doc(testProdId).delete().catch(() => {});
      throw e;
    }
  });

  // 8. Test Route Optimization
  await testService('Route Optimization Service', async () => {
    const stops = [
      { id: 'shop', lat: 25.1006, lng: 76.5156 },
      { id: 'customer_1', lat: 25.1050, lng: 76.5200 },
      { id: 'customer_2', lat: 25.0980, lng: 76.5100 }
    ];
    const route = await RouteOptimizationService.optimizeRoute(stops);
    return `Optimized stop sequence: ${route.optimizedSequence.join(' -> ')} (Total distance: ${route.totalDistance.toFixed(2)} km)`;
  });

  // 9. Test Delivery Optimization
  await testService('Delivery Optimization Service', async () => {
    const shopLocation = { lat: 25.1006, lng: 76.5156 };
    const tasks = [
      { id: 'task_1', deliveryAddress: { lat: 25.1050, lng: 76.5200 }, status: 'ready_to_pack' },
      { id: 'task_2', deliveryAddress: { lat: 25.0980, lng: 76.5100 }, status: 'ready_to_pack' }
    ];
    const assignments = await DeliveryOptimizationService.createBatchesAndAssign(tasks, shopLocation);
    return `Created ${assignments.batches?.length || 0} delivery batches.`;
  });

  // 10. Test Razorpay & Payment Service Wiring
  await testService('Razorpay Gateway Service', async () => {
    await RazorpayService.initialize();
    return `Razorpay API initialized with credentials: ${secrets.get('RAZORPAY_KEY_ID')?.substring(0, 10)}...`;
  });

  // ── Show Router Endpoint Audit ──
  console.log('\n🔍 EXPRESS ROUTER ENDPOINT MAP AUDIT:');
  const app = require('./app');
  const routesMapped = [];
  
  app._router.stack.forEach((middleware) => {
    if (middleware.route) {
      // Direct route on app (e.g. health)
      const methods = Object.keys(middleware.route.methods).map(m => m.toUpperCase());
      routesMapped.push({ path: middleware.route.path, methods });
    } else if (middleware.name === 'router') {
      // Router group mounted on path
      const base = middleware.regexp.toString()
        .replace('/^\\', '')
        .replace('\\/?(?=\\/|$)/i', '')
        .replace('\\/i', '')
        .replace(/\\\//g, '/');
      
      const cleanBase = base.startsWith('/') ? base : '/' + base;
      
      middleware.handle.stack.forEach((handler) => {
        if (handler.route) {
          const path = cleanBase + handler.route.path;
          const methods = Object.keys(handler.route.methods).map(m => m.toUpperCase());
          routesMapped.push({ path, methods });
        }
      });
    }
  });

  console.table(routesMapped.slice(0, 30));
  if (routesMapped.length > 30) console.log(`... and ${routesMapped.length - 30} more endpoints mounted.`);

  // ── Final Summary ──
  console.log('\n📊 VERIFICATION SUMMARY REPORT:');
  console.log('================================================');
  Object.keys(results).forEach(name => {
    const res = results[name];
    if (res.success) {
      console.log(`✅ [OK] ${name}: ${res.detail}`);
    } else {
      console.log(`❌ [FAIL] ${name}: ${res.error}`);
    }
  });
  console.log('================================================');
  console.log('🏁 Auditing finished.');
}

runAudit();
