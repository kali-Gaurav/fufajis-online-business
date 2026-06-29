/**
 * ai_hardening.test.js
 * Unit tests to verify anti-anomaly pricing guardrails, confidence review thresholds,
 * supplier cost intelligence, response promise sanitizers, and human ticket handoff logs.
 */

const firestore = require('../src/firestore');
const genkitService = require('../src/services/genkitService');

// Define a dynamic mock response holder for Genkit
let currentMockResponse = null;

// Override getAI BEFORE requiring PricingOptimizationService to prevent module binding gotchas
genkitService.getAI = async () => ({
  generate: async ({ prompt, output }) => {
    if (currentMockResponse) {
      return currentMockResponse({ prompt, output });
    }
    return { text: 'Default mock response' };
  }
});

// ─── Step 1: Mock Firestore Database ─────────────────────────────────────────
const mockCollection = (name) => {
  const mockDocs = name === 'products' ? [
    {
      id: 'prod_atta_123',
      exists: true,
      data: () => ({
        name: 'Aashirvaad Atta 5kg',
        category: 'Staples',
        basePrice: 370,
        price: 370,
        costPrice: 320,
        stockQuantity: 40,
        reorderPoint: 15,
        sku: 'atta_5kg',
        viewCount: 150
      })
    }
  ] : [];

  const collectionRef = {
    where: () => collectionRef,
    orderBy: () => collectionRef,
    limit: () => collectionRef,
    get: async () => {
      return {
        empty: mockDocs.length === 0,
        size: mockDocs.length,
        docs: mockDocs,
        forEach: (cb) => mockDocs.forEach(cb)
      };
    },
    add: async (data) => {
      console.log(`  [Firestore Mock] Created document in '${name}'`);
      return { id: `mock_${name}_id` };
    },
    doc: (id) => {
      return {
        get: async () => {
          if (name === 'products') {
            return {
              exists: true,
              data: () => ({
                name: 'Aashirvaad Atta 5kg',
                category: 'Staples',
                basePrice: 370,
                price: 370,
                costPrice: 320,
                stockQuantity: 40,
                reorderPoint: 15,
                sku: 'atta_5kg',
                viewCount: 150
              })
            };
          }
          return { exists: false };
        },
        update: async (data) => {
          console.log(`  [Firestore Mock] Updated document in '${name}'`);
          return {};
        }
      };
    }
  };
  return collectionRef;
};

firestore.db = () => ({
  collection: mockCollection
});

firestore.admin = {
  firestore: {
    FieldValue: {
      serverTimestamp: () => new Date()
    },
    Timestamp: {
      fromDate: (date) => date
    }
  }
};

// ─── Step 2: Import Hardened Services ────────────────────────────────────────
const ProcurementOptimizationService = require('../src/services/ProcurementOptimizationService');
const PricingOptimizationService = require('../src/services/PricingOptimizationService');
const ResponseGuardrailService = require('../src/services/ResponseGuardrailService');
const TicketEscalationService = require('../src/services/TicketEscalationService');

console.log('\n🎯 PRODUCTION HARDENING & SECURITY GUARDRAILS TESTS\n');

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

async function runTests() {
  // ─── Test 1: Procurement Cost Intelligence ───────────────────────────────
  console.log('📋 Scenario 1: Procurement Cost Optimization');
  try {
    const result = await ProcurementOptimizationService.optimizeProcurement(
      'atta_5kg',
      'Aashirvaad Atta 5kg',
      320
    );
    assert(result.success === true, 'Supplier cost query successful');
    assert(result.recommendSwitch === true, 'Cheaper alternative distributor identified');
    assert(result.potentialSavingsPercent > 0, `Potential savings calculated: ${result.potentialSavingsPercent}%`);
    assert(result.advice.includes('Switch to'), 'Correct advice generated');
  } catch (error) {
    console.error('  ❌ Exception:', error.message);
    failedTests++;
  }

  // ─── Test 2: AI Pricing Anomaly Clamps (Guardrails) ────────────────────────
  console.log('\n📋 Scenario 2: Pricing Anomaly Guardrails (+/-10% clamp)');
  try {
    // Set dynamic Genkit mock to return an anomalous high price (₹450 on ₹370 base price)
    // 370 + 10% = ₹407 max.
    currentMockResponse = ({ prompt, output }) => {
      return {
        output: {
          recommendedPrice: 450, // anomalous +21% increase
          expectedRevenueIncreasePercent: 12,
          expectedSalesVolumeChangePercent: -2,
          rationale: 'High demand surge.',
          aiConfidence: 90
        }
      };
    };

    const result = await PricingOptimizationService.analyzeAndRecommend('prod_atta_123');
    assert(result.success === true, 'Pricing analysis query successful');
    assert(result.recommendation.recommendedPrice === 407, `Price clamped to ₹407 (Actual: ₹${result.recommendation.recommendedPrice})`);
    assert(result.recommendation.anomalyClamped === true, 'Anomaly clamp triggered');
    assert(result.recommendation.clampReason.includes('Clamped to ₹407'), 'Correct clamp reason returned');
  } catch (error) {
    console.error('  ❌ Exception:', error.message);
    failedTests++;
  }

  // ─── Test 3: AI Pricing Confidence Thresholds ──────────────────────────────
  console.log('\n📋 Scenario 3: Pricing Confidence Thresholds');
  try {
    // Mock Genkit to return a low confidence score (65)
    currentMockResponse = ({ prompt, output }) => {
      return {
        output: {
          recommendedPrice: 360,
          expectedRevenueIncreasePercent: 2,
          expectedSalesVolumeChangePercent: 1,
          rationale: 'Slight competitor undercut.',
          aiConfidence: 65 // low confidence
        }
      };
    };

    const result = await PricingOptimizationService.analyzeAndRecommend('prod_atta_123');
    assert(result.recommendation.ownerReviewMandatory === true, 'Flagged low-confidence recommendation for mandatory owner review');
  } catch (error) {
    console.error('  ❌ Exception:', error.message);
    failedTests++;
  }

  // ─── Test 4: Chatbot Response Sanitizer Guardrails ─────────────────────────
  console.log('\n📋 Scenario 4: Chatbot Response Sanitizer (Promise Blocking)');
  try {
    // Test refund promise violation
    const rawReplyA = "Okay, bhaiya, aapka refund approved ho gaya hai aur paise turant wapas milenge.";
    const resultA = ResponseGuardrailService.sanitizeResponse(rawReplyA);
    assert(resultA.guardrailTriggered === true, 'Refund promise violation detected');
    assert(resultA.violations.includes('Unauthorized refund approval promise.'), 'Correct violation logged');
    assert(!resultA.sanitizedReply.includes('approved'), 'Reply sanitized of unauthorized approval');

    // Test free order promise violation
    const rawReplyB = "Aapko next order free milega as compensation.";
    const resultB = ResponseGuardrailService.sanitizeResponse(rawReplyB);
    assert(resultB.guardrailTriggered === true, 'Free compensation promise violation detected');
    assert(resultB.sanitizedReply.includes('pricing promise'), 'Reply sanitized with compliant pricing promise');
  } catch (error) {
    console.error('  ❌ Exception:', error.message);
    failedTests++;
  }

  // ─── Test 5: Human Handoff Ticket Continuity ───────────────────────────────
  console.log('\n📋 Scenario 5: Support Handoff Continuity Context');
  try {
    const ticketId = await TicketEscalationService.escalate(
      'user_abc_123',
      'kharab milk mila h!',
      'QUALITY_COMPLAINT',
      'Damaged fresh goods',
      { status: 'Delivered', orderNumber: '123' }
    );
    assert(ticketId !== null, 'Support ticket created successfully');
  } catch (error) {
    console.error('  ❌ Exception:', error.message);
    failedTests++;
  }

  // ─── Summary ─────────────────────────────────────────────────────────────
  console.log('\n═══════════════════════════════════════════════════════');
  console.log(`📊 Results: ${passedTests} passed, ${failedTests} failed`);
  console.log('═══════════════════════════════════════════════════════\n');

  if (failedTests === 0) {
    console.log('✅ ALL TESTS PASSED - Security Guardrails & Hardening fully validated\n');
    process.exit(0);
  } else {
    console.log(`⚠️  ${failedTests} test(s) failed - Review and fix\n`);
    process.exit(1);
  }
}

runTests();
