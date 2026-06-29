/**
 * delivery_optimization.test.js
 * Hardened Unit, Integration, and Stress tests for Delivery Optimization & Route Planning Service
 */

const deliveryOptimizationService = require('../src/services/DeliveryOptimizationService');

console.log('\n🎯 HARDENED DELIVERY OPTIMIZATION & LOGISTICS TESTS\n');

let passedTests = 0;
let failedTests = 0;

function assert(condition, message) {
  if (!condition) {
    throw new Error(message || 'Assertion failed');
  }
}

// 1. Test Haversine Distance
try {
  console.log('✓ Testing: Haversine Distance Calculation');
  const dist = deliveryOptimizationService.haversineDistance(28.6304, 77.2177, 28.6129, 77.2295);
  console.log(`  Distance Connaught Place to India Gate: ${dist.toFixed(2)} km`);
  assert(dist > 2.0 && dist < 4.0, 'Distance calculation is outside expected bounds');
  console.log('  Status: ✅ PASS\n');
  passedTests++;
} catch (error) {
  console.log(`  Status: ❌ FAIL - ${error.message}\n`);
  failedTests++;
}

// 2. Test TSP Route Solver
try {
  console.log('✓ Testing: TSP Route Solver (Sequence Optimization)');
  const startLoc = { lat: 28.6304, lng: 77.2177 };
  const stops = [
    { id: 'stop_A', lat: 28.5355, lng: 77.3910 }, 
    { id: 'stop_B', lat: 28.6129, lng: 77.2295 }, 
    { id: 'stop_C', lat: 28.5708, lng: 77.3218 }  
  ];

  const result = deliveryOptimizationService.optimizeRoute(startLoc, stops);
  console.log('  Optimized sequence:', result.orderedStops.map(s => s.id).join(' -> '));
  assert(result.orderedStops[0].id === 'stop_B', 'First stop should be closest');
  assert(result.totalDistanceKm > 0, 'Total distance must be positive');
  console.log('  Status: ✅ PASS\n');
  passedTests++;
} catch (error) {
  console.log(`  Status: ❌ FAIL - ${error.message}\n`);
  failedTests++;
}

// 3. Test Dynamic Route Re-optimization
try {
  console.log('✓ Testing: Dynamic Route Re-optimization (Rider Mid-Route)');
  const riderLoc = { lat: 28.6129, lng: 77.2295 }; // India Gate
  const remainingStops = [
    { id: 'stop_A', lat: 28.5355, lng: 77.3910 }, 
    { id: 'stop_C', lat: 28.5708, lng: 77.3218 }
  ];
  const newStops = [
    { id: 'stop_Urgent', lat: 28.5900, lng: 77.2500 } // Urgent order inserted in between
  ];

  const reoptimized = deliveryOptimizationService.reoptimizeRoute(riderLoc, remainingStops, newStops);
  console.log('  Reoptimized sequence:', reoptimized.orderedStops.map(s => s.id).join(' -> '));
  assert(reoptimized.orderedStops[0].id === 'stop_Urgent', 'Urgent stop closest to rider should be visited first');
  console.log('  Status: ✅ PASS\n');
  passedTests++;
} catch (error) {
  console.log(`  Status: ❌ FAIL - ${error.message}\n`);
  failedTests++;
}

// 4. Test Advanced ETA Calculations
try {
  console.log('✓ Testing: Advanced Traffic & Weather-aware ETA Calculations');
  const distance = 12.5; // km
  const stopsCount = 3;

  const etaClear = deliveryOptimizationService.predictDeliveryTime(distance, stopsCount, {
    trafficLevel: 'low',
    weatherCondition: 'clear',
    packingDelayMinutes: 5
  });

  const etaStormyRain = deliveryOptimizationService.predictDeliveryTime(distance, stopsCount, {
    trafficLevel: 'high',
    weatherCondition: 'stormy',
    packingDelayMinutes: 10
  });

  console.log(`  ETA under Clear & Low Traffic: ${etaClear} mins`);
  console.log(`  ETA under Stormy & High Traffic: ${etaStormyRain} mins`);

  assert(etaClear < etaStormyRain, 'Stormy/high traffic should increase ETA significantly');
  assert(etaStormyRain >= 90, 'ETA during storm/traffic should be extremely high');
  
  console.log('  Status: ✅ PASS\n');
  passedTests++;
} catch (error) {
  console.log(`  Status: ❌ FAIL - ${error.message}\n`);
  failedTests++;
}

// 5. Test Multi-factor Assignment Score
try {
  console.log('✓ Testing: Multi-factor Rider Assignment Score');
  const startLoc = { lat: 28.6304, lng: 77.2177 };
  const riders = [
    { 
      id: 'rider_near_busy', 
      status: 'active', 
      lat: 28.6305, 
      lng: 77.2180, 
      maxWeightKg: 20, 
      currentWeightKg: 19, // Highly overloaded
      completionRate: 0.95,
      acceptanceRate: 0.90
    },
    { 
      id: 'rider_mid_free', 
      status: 'active', 
      lat: 28.6129, 
      lng: 77.2295, // A bit farther (2.2km) but free load
      maxWeightKg: 20, 
      currentWeightKg: 0, 
      completionRate: 0.98,
      acceptanceRate: 0.95
    }
  ];

  const bestRider = deliveryOptimizationService.findBestRider(startLoc, riders, 5, 5);
  console.log(`  Assigned Rider: ${bestRider.id} (Score: ${bestRider.assignmentScore.toFixed(2)})`);
  assert(bestRider.id === 'rider_mid_free', 'Rider mid-free should be chosen because the near rider is overloaded');
  
  console.log('  Status: ✅ PASS\n');
  passedTests++;
} catch (error) {
  console.log(`  Status: ❌ FAIL - ${error.message}\n`);
  failedTests++;
}

// 6. Test Exceptions
try {
  console.log('✓ Testing: Delivery Exception Engine');
  const log = deliveryOptimizationService.handleDeliveryException('order_999', 'PAYMENT_FAILURE', { gatewayReason: 'Insufficient funds' });
  
  assert(log.orderId === 'order_999', 'Exception log order ID should match');
  assert(log.exceptionType === 'PAYMENT_FAILURE', 'Exception type should match');
  
  console.log('  Status: ✅ PASS\n');
  passedTests++;
} catch (error) {
  console.log(`  Status: ❌ FAIL - ${error.message}\n`);
  failedTests++;
}

// 7. Test Cost Optimization Metrics
try {
  console.log('✓ Testing: Cost Optimization Engine');
  const metrics = deliveryOptimizationService.calculateCostMetrics(8.4, 2, 12);
  
  console.log(`  Total calculated route cost: ₹${metrics.totalDeliveryCost.toFixed(2)}`);
  console.log(`  Cost per order: ₹${metrics.costPerOrder.toFixed(2)}`);
  
  assert(metrics.totalDeliveryCost > 0, 'Cost should be calculated');
  assert(metrics.costPerOrder === metrics.totalDeliveryCost / 2, 'Cost per order calculation mismatch');

  console.log('  Status: ✅ PASS\n');
  passedTests++;
} catch (error) {
  console.log(`  Status: ❌ FAIL - ${error.message}\n`);
  failedTests++;
}

// 8. Stress/Performance Testing (100 orders, 20 riders)
try {
  console.log('⚡ Stress & Performance Testing (100 Orders & 20 Riders)');

  const storeLoc = { lat: 28.6139, lng: 77.2090 };
  const mockOrders = [];
  for (let i = 0; i < 100; i++) {
    mockOrders.push({
      id: `order_${i}`,
      lat: 28.6139 + (Math.random() - 0.5) * 0.15, // random spread
      lng: 77.2090 + (Math.random() - 0.5) * 0.15,
      createdAt: new Date(Date.now() - Math.random() * 120 * 60000), // age up to 2 hours
      promisedDeliveryTime: new Date(Date.now() + Math.random() * 90 * 60000), // SLA up to 90 mins
      weight: Math.random() * 20,
      volume: Math.random() * 30
    });
  }

  const mockRiders = [];
  for (let i = 0; i < 20; i++) {
    mockRiders.push({
      id: `rider_${i}`,
      status: 'active',
      lat: 28.6139 + (Math.random() - 0.5) * 0.20,
      lng: 77.2090 + (Math.random() - 0.5) * 0.20,
      maxWeightKg: 30,
      currentWeightKg: Math.random() * 10,
      maxVolumeLiters: 50,
      completionRate: 0.8 + Math.random() * 0.2,
      acceptanceRate: 0.8 + Math.random() * 0.2
    });
  }

  const startTime = Date.now();

  // Cluster the orders (includes prioritization calculation)
  const clusters = deliveryOptimizationService.clusterOrders(mockOrders, 2.0, storeLoc);
  
  // Optimize routes & Assign riders
  let assignmentsMade = 0;
  for (const cluster of clusters) {
    const optimization = deliveryOptimizationService.optimizeRoute(storeLoc, cluster);
    const totalWeight = cluster.reduce((sum, o) => sum + (o.weight || 0), 0);
    const totalVolume = cluster.reduce((sum, o) => sum + (o.volume || 0), 0);
    
    // Find best rider
    const assignedRider = deliveryOptimizationService.findBestRider(storeLoc, mockRiders, totalWeight, totalVolume);
    if (assignedRider) assignmentsMade++;
  }

  const duration = Date.now() - startTime;
  console.log(`  Processed 100 orders into ${clusters.length} batches & scheduled riders in ${duration} ms`);
  console.log(`  Rider assignments resolved: ${assignmentsMade}`);

  assert(duration < 2000, `Performance target exceeded! Finished in ${duration}ms (target < 2000ms)`);

  console.log('  Status: ✅ PASS\n');
  passedTests++;
} catch (error) {
  console.log(`  Status: ❌ FAIL - ${error.message}\n`);
  failedTests++;
}

console.log('═══════════════════════════════════════════════════════');
console.log(`📊 Results: ${passedTests} passed, ${failedTests} failed`);
console.log('═══════════════════════════════════════════════════════\n');

if (failedTests > 0) {
  console.error('❌ SOME TESTS FAILED');
  process.exit(1);
} else {
  console.log('✅ ALL PRODUCTION HARDENING TESTS PASSED SUCCESSFULLY');
  process.exit(0);
}
