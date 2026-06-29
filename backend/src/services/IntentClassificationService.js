/**
 * IntentClassificationService.js
 * Uses Gemini 1.5 Flash via Genkit to dynamically classify customer intents
 * and assess sentiment using structured schemas.
 */

const { getAI } = require('./genkitService');
const { z } = require('zod');

class IntentClassificationService {
  /**
   * Classify user message intent and sentiment
   * @param {string} message
   * @returns {Promise<Object>} - { intent, sentiment, confidence, shouldEscalate }
   */
  static async classify(message) {
    try {
      const ai = await getAI();

      const response = await ai.generate({
        prompt: `
Analyze this customer support message for Fufaji Store: "${message}".
Classify it into one of these intents:
- TRACK_ORDER: Asking about where their order is, delivery ETA, or order status.
- RETURN_REFUND: Asking about returning an item, initiating a refund, or refund status.
- PRODUCT_INFO: Inquiring about item details, stock availability, pricing, or fresh stock.
- PAYMENT_ISSUE: Issues with failing payments, cards, UPI, or double charges.
- DELIVERY_ISSUE: Delivery delay, rider not responding, or cancellation of delivery.
- QUALITY_COMPLAINT: Complaining about damaged, stale, or expired items.
- ACCOUNT_LOGIN: Trouble logging in, resetting passwords, or account issues.
- FAQ: General questions about store hours, location, delivery radius, or payment methods.
- GENERAL: Casual greetings, chit-chat, or general comments.

Determine the sentiment as POSITIVE, NEUTRAL, or NEGATIVE.
If the customer is extremely angry, uses abusive terms, or expresses intense frustration, set shouldEscalate to true.
If the request is too complex for an automated assistant, set shouldEscalate to true.
`,
        output: {
          schema: z.object({
            intent: z.enum([
              'TRACK_ORDER',
              'RETURN_REFUND',
              'PRODUCT_INFO',
              'PAYMENT_ISSUE',
              'DELIVERY_ISSUE',
              'QUALITY_COMPLAINT',
              'ACCOUNT_LOGIN',
              'FAQ',
              'GENERAL'
            ]),
            sentiment: z.enum(['POSITIVE', 'NEUTRAL', 'NEGATIVE']),
            confidence: z.number().describe('Confidence score from 0.0 to 1.0'),
            shouldEscalate: z.boolean().describe('True if this needs immediate human support')
          })
        }
      });

      return response.output || {
        intent: 'GENERAL',
        sentiment: 'NEUTRAL',
        confidence: 0.5,
        shouldEscalate: false
      };
    } catch (error) {
      console.warn('[IntentClassification] AI classification failed, using keyword fallback:', error.message);
      return this.fallbackKeywordClassifier(message);
    }
  }

  /**
   * Resilient keyword-based fallback if Gemini is offline or unconfigured
   */
  static fallbackKeywordClassifier(message) {
    const p = message.toLowerCase();
    let intent = 'GENERAL';
    let sentiment = 'NEUTRAL';
    let shouldEscalate = false;

    if (p.includes('order') || p.includes('track') || p.includes('kaha h') || p.includes('kab aayega')) {
      intent = 'TRACK_ORDER';
    } else if (p.includes('refund') || p.includes('wapas') || p.includes('cancel')) {
      intent = 'RETURN_REFUND';
    } else if (p.includes('damaged') || p.includes('sada') || p.includes('kharab') || p.includes('quality') || p.includes('expired')) {
      intent = 'QUALITY_COMPLAINT';
      sentiment = 'NEGATIVE';
      shouldEscalate = true;
    } else if (p.includes('payment') || p.includes('failed') || p.includes('paytm') || p.includes('gpay')) {
      intent = 'PAYMENT_ISSUE';
      shouldEscalate = true;
    } else if (p.includes('timing') || p.includes('hours') || p.includes('open') || p.includes('delivery charge')) {
      intent = 'FAQ';
    }

    if (p.includes('abusive_term') || p.includes('bakwas') || p.includes('ghatiya')) {
      sentiment = 'NEGATIVE';
      shouldEscalate = true;
    }

    return {
      intent,
      sentiment,
      confidence: 0.70,
      shouldEscalate
    };
  }
}

module.exports = IntentClassificationService;
