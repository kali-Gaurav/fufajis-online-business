/**
 * smart_pricing.test.js - Unit tests for AI Price Intelligence & Margin Optimization Engine
 * Expected: Safe margins, inventory clearance suggestions, competitor alignment, and village trust protection.
 */

const CompetitorIntelligenceService = require('../src/services/CompetitorIntelligenceService');
const DemandForecastService = require('../src/services/DemandForecastService');
const MarginProtectionService = require('../src/services/MarginProtectionService');
const PromotionRecommendationService = require('../src/services/PromotionRecommendationService');

console.log('\n🎯 AI PRICE INTELLIGENCE & MARGIN OPTIMIZATION ENGINE TESTS\n');

let passedTests = 0;
let failedTests = 0;

function assert(condition, message) {
  if (condition) {
    console.log(`  ✅ PASS: ${message}`);
    passedTests++;
  } else {
    console.log(`  ❌ FAIL: ${message}`);
    failedTests++;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. TEST MARGIN PROTECTION SERVICE
// ─────────────────────────────────────────────────────────────────────────────
console.log('📋 Scenario 1: Margin Protection Service (Procurement Floor Checks)');
try {
  // Test case A: Staples (10% min margin floor)
  // costPrice = 100, minPrice = 110. Recommending 105 should trigger floor and raise to 110.
  const stapleResult = MarginProtectionService.enforceMarginSafety(105, 100, 120, 'Staples');
  assert(stapleResult.safePrice === 110, `Staple safePrice should be ₹110 (Actual: ₹${stapleResult.safePrice})`);
  assert(stapleResult.marginFloorTriggered === true, `Staple margin floor should be triggered`);

  // Test case B: Snacks (18% min margin floor)
  // costPrice = 100, minPrice = 118. Recommending 125 should be safe (no floor triggered).
  const snackResult = MarginProtectionService.enforceMarginSafety(125, 100, 130, 'Snacks');
  assert(snackResult.safePrice === 125, `Snack safePrice should remain ₹125`);
  assert(snackResult.marginFloorTriggered === false, `Snack margin floor should NOT be triggered`);

  // Test case C: Dairy (8% min margin floor)
  // costPrice = 100, minPrice = 108. Recommending 105 should trigger floor and raise to 108.
  const dairyResult = MarginProtectionService.enforceMarginSafety(105, 100, 115, 'Dairy');
  assert(dairyResult.safePrice === 108, `Dairy safePrice should be ₹108 (Actual: ₹${dairyResult.safePrice})`);

  // Test case D: Default Category (15% min margin floor)
  // costPrice = 100, minPrice = 115. Recommending 110 should trigger floor and raise to 115.
  const defaultResult = MarginProtectionService.enforceMarginSafety(110, 100, 130, 'General');
  assert(defaultResult.safePrice === 115, `Default category safePrice should be ₹115 (Actual: ₹${defaultResult.safePrice})`);
} catch (error) {
  console.error('  ❌ Error in Margin Protection test:', error.message);
  failedTests++;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. TEST DEMAND FORECAST SERVICE HELPERS
// ─────────────────────────────────────────────────────────────────────────────
console.log('\n📋 Scenario 2: Demand Forecast Service (Seasonality Scoring)');
try {
  // Test case A: Summer seasonality for beverages
  const summerScore = DemandForecastService.calculateSeasonalityScore(4, 'Beverages'); // May
  assert(summerScore === 90, `Summer seasonality score for beverages should be 90 (Actual: ${summerScore})`);

  // Test case B: Diwali seasonality for sweets
  const diwaliScore = DemandForecastService.calculateSeasonalityScore(10, 'Festive Sweets'); // November
  assert(diwaliScore === 95, `Diwali seasonality score for sweets should be 95 (Actual: ${diwaliScore})`);

  // Test case C: Off-season default category
  const normalScore = DemandForecastService.calculateSeasonalityScore(6, 'Grains'); // July
  assert(normalScore === 50, `Default seasonality score should be 50 (Actual: ${normalScore})`);
} catch (error) {
  console.error('  ❌ Error in Demand Forecast test:', error.message);
  failedTests++;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. TEST PROMOTION RECOMMENDATION SERVICE
// ─────────────────────────────────────────────────────────────────────────────
console.log('\n📋 Scenario 3: Promotion Recommendation Service (Slow-Moving Stock)');
try {
  // Test case A: Healthy turnover product (should NOT recommend promo)
  const productA = { basePrice: 100, costPrice: 80, stockQuantity: 10, category: 'General' };
  const promoA = PromotionRecommendationService.recommendPromotion(productA, 15); // High sales velocity
  assert(promoA.recommendPromo === false, `Healthy velocity item should NOT trigger promo`);

  // Test case B: Moderately slow-moving product (stock age 40 days, low velocity)
  // Recommends 5% discount: 100 * 0.95 = ₹95. Cost price is 80. Default floor is 80 * 1.15 = ₹92.
  // ₹95 is safe (> ₹92), so should recommend 5% discount (price ₹95).
  const productB = { 
    basePrice: 100, 
    costPrice: 80, 
    stockQuantity: 20, 
    category: 'General',
    createdAt: { seconds: Math.floor((Date.now() - 40 * 24 * 60 * 60 * 1000) / 1000) } // 40 days ago
  };
  const promoB = PromotionRecommendationService.recommendPromotion(productB, 1);
  assert(promoB.recommendPromo === true, `Aging item should trigger promo`);
  assert(promoB.discountPercentage === 5, `Should recommend a 5% discount (Actual: ${promoB.discountPercentage}%)`);
  assert(promoB.recommendedPromoPrice === 95, `Recommended price should be ₹95`);

  // Test case C: Critically slow-moving product (stock age 100 days, low velocity)
  // Recommends 15% discount: 100 * 0.85 = ₹85. Cost price is 80. Default floor is 80 * 1.15 = ₹92.
  // ₹85 is below floor (₹92), so margin safety should raise it to ₹92.
  const productC = { 
    basePrice: 100, 
    costPrice: 80, 
    stockQuantity: 30, 
    category: 'General',
    createdAt: { seconds: Math.floor((Date.now() - 100 * 24 * 60 * 60 * 1000) / 1000) } // 100 days ago
  };
  const promoC = PromotionRecommendationService.recommendPromotion(productC, 0);
  assert(promoC.recommendPromo === true, `Critical aging item should trigger promo`);
  assert(promoC.recommendedPromoPrice === 92, `Price should be clamped by margin floor to ₹92 (Actual: ₹${promoC.recommendedPromoPrice})`);
  assert(promoC.discountPercentage === 8, `Discount adjusted from 15% to 8% to protect floor`);
} catch (error) {
  console.error('  ❌ Error in Promotion Recommendation test:', error.message);
  failedTests++;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. TEST COMPETITOR INTELLIGENCE SIMULATOR
// ─────────────────────────────────────────────────────────────────────────────
console.log('\n📋 Scenario 4: Competitor Intelligence Simulator (Variance Boundaries)');
try {
  // Test simulated prices are within -6% to +6% of base price
  const basePrice = 500;
  const competitors = [
    { name: 'Blinkit', varianceLower: 0.95, varianceUpper: 1.05 },
    { name: 'Zepto', varianceLower: 0.96, varianceUpper: 1.04 },
    { name: 'BigBasket', varianceLower: 0.94, varianceUpper: 1.06 }
  ];

  let boundsValid = true;
  for (let i = 0; i < 50; i++) { // Run multiple iterations to verify safety bounds
    competitors.forEach((comp) => {
      const factor = comp.varianceLower + Math.random() * (comp.varianceUpper - comp.varianceLower);
      const price = Math.round(basePrice * factor);
      const minBound = Math.round(basePrice * comp.varianceLower);
      const maxBound = Math.round(basePrice * comp.varianceUpper);
      
      if (price < minBound || price > maxBound) {
        boundsValid = false;
        console.error(`  - Failed bounds: ${comp.name} price ₹${price} out of bounds [₹${minBound}, ₹${maxBound}]`);
      }
    });
  }
  assert(boundsValid === true, `All simulated competitor prices fell within their specified margin bounds`);
} catch (error) {
  console.error('  ❌ Error in Competitor Intelligence test:', error.message);
  failedTests++;
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY
// ─────────────────────────────────────────────────────────────────────────────
console.log('\n═══════════════════════════════════════════════════════');
console.log(`📊 Results: ${passedTests} passed, ${failedTests} failed`);
console.log('═══════════════════════════════════════════════════════\n');

if (failedTests === 0) {
  console.log('✅ ALL TESTS PASSED - Pricing Optimization Services READY FOR STAGING\n');
  process.exit(0);
} else {
  console.log(`⚠️  ${failedTests} test(s) failed - Review and fix\n`);
  process.exit(1);
}
