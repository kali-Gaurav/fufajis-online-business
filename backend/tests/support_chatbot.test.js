/**
 * support_chatbot.test.js
 * Unit tests for upgraded Intelligent Customer Support Chatbot.
 * Verifies intent classification, sentiment analysis, Hinglish response generation,
 * and automated human routing ticket creation.
 */

const firestore = require('../src/firestore');
const genkitService = require('../src/services/genkitService');

// ─── Step 1: Mock Firestore Database ─────────────────────────────────────────
const mockCollection = (collectionName) => {
  return {
    where: () => mockCollection(collectionName),
    orderBy: () => mockCollection(collectionName),
    limit: () => mockCollection(collectionName),
    get: async () => {
      if (collectionName === 'orders') {
        const docs = [
          {
            id: 'order_abc123',
            data: () => ({
              orderNumber: 'F-98765',
              status: 'OrderStatus.confirmed',
              final_amount: 450,
              estimated_delivery_time: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
              items: [{ productId: 'prod_atta', quantity: 1, price_at_purchase: 370 }]
            })
          }
        ];
        return {
          empty: false,
          size: docs.length,
          docs,
          forEach: (cb) => docs.forEach(cb)
        };
      }
      return {
        empty: true,
        size: 0,
        docs: [],
        forEach: (cb) => {}
      };
    },
    add: async (data) => {
      console.log(`  [Firestore Mock] Added document to '${collectionName}' collection`);
      return { id: `mock_${collectionName}_id` };
    }
  };
};

// Override the db() handle to return mock collections
firestore.db = () => ({
  collection: mockCollection
});

// Mock Firestore FieldValue & Timestamp
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

// ─── Step 2: Mock Gemini AI / Genkit ─────────────────────────────────────────
genkitService.getAI = async () => {
  return {
    generate: async ({ prompt, output }) => {
      // 1. Structured Intent & Sentiment Classifier mock
      if (output && output.schema) {
        let intent = 'GENERAL';
        let sentiment = 'NEUTRAL';
        let shouldEscalate = false;

        const messageMatch = prompt.match(/Fufaji Store: "([^"]+)"/);
        const p = messageMatch ? messageMatch[1].toLowerCase() : prompt.toLowerCase();

        if (p.includes('order status') || p.includes('kaha h') || p.includes('where is')) {
          intent = 'TRACK_ORDER';
        } else if (p.includes('refund') || p.includes('wapas')) {
          intent = 'RETURN_REFUND';
        } else if (p.includes('bakwas') || p.includes('kharab') || p.includes('sade') || p.includes('angry')) {
          intent = 'QUALITY_COMPLAINT';
          sentiment = 'NEGATIVE';
          shouldEscalate = true;
        } else if (p.includes('delivery hours') || p.includes('timing') || p.includes('radius') || p.includes('open')) {
          intent = 'FAQ';
        }

        return {
          output: {
            intent,
            sentiment,
            confidence: 0.96,
            shouldEscalate
          }
        };
      }

      // 2. Chat Response Generator mock
      let reply = 'Fufaji Store helpdesk me aapka swagat hai. Main aapki kya madad kar sakta hoon?';
      
      if (prompt.includes('TRACK_ORDER')) {
        reply = 'Aapka order #F-98765 Confirmed hai aur kal tak deliver ho jayega bhaiya. Delivery details message par bhej di hain.';
      } else if (prompt.includes('RETURN_REFUND')) {
        reply = 'Aap fresh items ke alawa baki cheezein 7 days me return kar sakte hain. Kya main refund process shuru karu?';
      } else if (prompt.includes('QUALITY_COMPLAINT')) {
        reply = 'Humein behad khed hai ki aapko kharab items mile. Humne ek High Priority support ticket raise kar diya hai.';
      } else if (prompt.includes('FAQ')) {
        reply = 'Fufaji Store Baran, Rajasthan me hai aur hum subah 8 baje se raat 9 baje tak open rehte hain.';
      }

      return { text: reply };
    }
  };
};

const SupportChatbotService = require('../src/services/SupportChatbotService');

console.log('\n🎯 INTELLIGENT CUSTOMER SUPPORT CHATBOT TESTS\n');

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

// Run unit tests
async function runTests() {
  const userId = 'user_gaurav_789';

  // ─── Test 1: Order Tracking Inquiries (Hinglish response) ────────────────
  console.log('📋 Scenario 1: Order Tracking Inquiry ("where is my order status?")');
  try {
    const result = await SupportChatbotService.processMessage(userId, 'bhaiya mera order kaha h status batana?');
    assert(result.success === true, 'Message processed successfully');
    assert(result.intent === 'TRACK_ORDER', 'Intent correctly classified as TRACK_ORDER');
    assert(result.reply.includes('#F-98765'), 'Reply contains correct mocked order number');
    assert(result.reply.includes('Confirmed'), 'Reply correctly informs the order is Confirmed');
    assert(result.shouldEscalate === false, 'No human escalation needed for regular tracking');
  } catch (error) {
    console.error('  ❌ Exception:', error.message);
    failedTests++;
  }

  // ─── Test 2: Standard FAQ Queries (Store hours/timing) ───────────────────
  console.log('\n📋 Scenario 2: Store FAQ Inquiry ("what are the store timing details?")');
  try {
    const result = await SupportChatbotService.processMessage(userId, 'store timing kya hai aur delivery hours kya h?');
    assert(result.success === true, 'Message processed successfully');
    assert(result.intent === 'FAQ', 'Intent correctly classified as FAQ');
    assert(result.reply.includes('8 baje से') || result.reply.includes('8 baje'), 'Reply correctly details operating hours');
  } catch (error) {
    console.error('  ❌ Exception:', error.message);
    failedTests++;
  }

  // ─── Test 3: Quality Complaints (Negative sentiment & Escalation) ────────
  console.log('\n📋 Scenario 3: Negative Quality Complaint ("damaged product received")');
  try {
    const result = await SupportChatbotService.processMessage(userId, 'bakwas service hai aaloo sade hue mile!');
    assert(result.success === true, 'Message processed successfully');
    assert(result.intent === 'QUALITY_COMPLAINT', 'Intent correctly classified as QUALITY_COMPLAINT');
    assert(result.sentiment === 'NEGATIVE', 'Sentiment correctly classified as NEGATIVE');
    assert(result.shouldEscalate === true, 'Human escalation correctly triggered');
    assert(result.ticketId !== null, 'Support ticket created and ticketId returned');
  } catch (error) {
    console.error('  ❌ Exception:', error.message);
    failedTests++;
  }

  // ─── Summary ─────────────────────────────────────────────────────────────
  console.log('\n═══════════════════════════════════════════════════════');
  console.log(`📊 Results: ${passedTests} passed, ${failedTests} failed`);
  console.log('═══════════════════════════════════════════════════════\n');

  if (failedTests === 0) {
    console.log('✅ ALL TESTS PASSED - Intelligent Chatbot Engine READY FOR PRODUCTION\n');
    process.exit(0);
  } else {
    console.log(`⚠️  ${failedTests} test(s) failed - Review and fix\n`);
    process.exit(1);
  }
}

runTests();
