/**
 * SupportChatbotService.js
 * AI-powered customer support coordinator for Fufaji Store.
 * Coordinates intent classification, conversation memory, response guardrails,
 * and human handoff ticketing services.
 */

const { db, admin } = require('../firestore');
const { getAI } = require('./genkitService');

const IntentClassificationService = require('./IntentClassificationService');
const ConversationMemoryService = require('./ConversationMemoryService');
const ResponseGuardrailService = require('./ResponseGuardrailService');
const TicketEscalationService = require('./TicketEscalationService');

// Fufaji Store Policy Knowledge Base
const FUFAJI_STORE_POLICIES = `
Fufaji Store Information & Customer Policies:
- Name: Fufaji Store (Fufaji's Online Business)
- Address: Jalawar Road, Tel Factory, Baran, Rajasthan 325205
- Owner/Support Phone: +91 9876543210
- Operating Hours: Everyday from 8:00 AM to 9:00 PM.
- Delivery Area: Baran, Rajasthan (Max delivery radius of 15 km from the store). We do not deliver beyond 15 km.
- Returns Policy: Non-perishable items can be returned within 7 days of delivery. Items must be unused, sealed, and in original packaging. Perishable items (like fresh milk, vegetables, curd) cannot be returned unless they were delivered damaged or stale.
- Refunds Policy: Refunds are processed within 3 to 5 working days back to the customer's original payment method (bank account, card, UPI) or credited instantly to their Fufaji Wallet.
- Payment Methods: Cash on Delivery (COD), UPI (GPay, PhonePe, Paytm), Credit/Debit cards, and Fufaji Wallet.
- Pricing Promise: Transparent, honest pricing. Fixed prices, no surge pricing, and no marketplace gimmicks.
`;

class SupportChatbotService {
  /**
   * Process customer message and generate response using Gemini AI and security guardrails
   * @param {string} userId
   * @param {string} message - Customer message (Hindi, Hinglish, or English)
   * @returns {Object} - { reply, intent, sentiment, shouldEscalate, ticketId }
   */
  static async processMessage(userId, message) {
    try {
      const startTime = Date.now();

      // 1. Intent & Sentiment Classification
      const analysis = await IntentClassificationService.classify(message);

      // 2. Fetch Order Context (if checking status)
      let orderTrackResult = null;
      let orderDetailsContext = '';
      if (analysis.intent === 'TRACK_ORDER') {
        orderTrackResult = await this.handleTrackOrder(userId);
        if (orderTrackResult.orderData) {
          orderDetailsContext = `
Customer Order Information:
- Order Number: ${orderTrackResult.orderData.orderNumber}
- Current Status: ${orderTrackResult.orderData.status}
- Expected Delivery Date: ${orderTrackResult.orderData.deliveryDate || 'Not specified'}
- Total Amount: ₹${orderTrackResult.orderData.totalAmount}
- Total Items: ${orderTrackResult.orderData.itemCount}
`;
        } else {
          orderDetailsContext = 'Customer has no recent orders in the system.';
        }
      }

      // 3. Load past dialogue memory
      const chatHistory = await ConversationMemoryService.getConversationContextString(userId, 5);

      // 4. Generate Response via Gemini
      const responsePrompt = `
You are the customer support assistant for "Fufaji Store".
Fufaji Store is located in Baran, Rajasthan and sells groceries. 
Our voice is warm, respectful, neighborly, and community-focused. 
Respond in the language/style the customer is using. If they speak in Hinglish (Hindi written in English alphabet) or Hindi, reply in clear, friendly Hinglish/Hindi. If they speak in English, reply in English.

Context:
${FUFAJI_STORE_POLICIES}
${orderDetailsContext}

Previous Chat History:
${chatHistory}

Customer Message: "${message}"
Detected Intent: ${analysis.intent}
Detected Sentiment: ${analysis.sentiment}

Guidelines:
- Answer the customer's question directly based on the Store Policies and Order details.
- Never make up information or promise refunds/deliveries that violate our policy.
- If you cannot answer based on the policies, or if the user is complaining about a severe issue (like payment fail or stale food), be extremely apologetic and state that a human support ticket has been created.
- Keep replies brief and conversational.
`;

      let botReply = '';
      try {
        const ai = await getAI();
        const responseGen = await ai.generate({ prompt: responsePrompt });
        botReply = responseGen.text;
      } catch (aiError) {
        console.warn('[SupportChatbot] AI response generation failed, using rule-based reply:', aiError.message);
        botReply = this.generateRuleBasedReply(analysis.intent, orderTrackResult);
      }

      // 5. Enforce AI Safety Guardrails
      const guardrailResult = ResponseGuardrailService.sanitizeResponse(botReply);
      let sanitizedReply = guardrailResult.sanitizedReply;

      // 6. Escalation and Ticketing
      let shouldEscalate = analysis.shouldEscalate;
      if (analysis.sentiment === 'NEGATIVE' && analysis.confidence > 0.7) {
        shouldEscalate = true;
      }
      // Payment issues and quality complaints are auto-escalated immediately
      if (analysis.intent === 'QUALITY_COMPLAINT' || analysis.intent === 'PAYMENT_ISSUE') {
        shouldEscalate = true;
      }

      let ticketId = null;
      if (shouldEscalate) {
        ticketId = await TicketEscalationService.escalate(
          userId,
          message,
          analysis.intent,
          `Escalated automatically due to ${analysis.intent} intent or negative sentiment.`,
          orderTrackResult ? orderTrackResult.orderData : null
        );

        // Append ticket details to the reply if not already present
        if (ticketId && !sanitizedReply.includes('ticket') && !sanitizedReply.includes('Ticket')) {
          sanitizedReply += `\n\n(Aapka support ticket raise kar diya gaya hai. Ticket ID: ${ticketId}. Humari team jald hi aapko contact karegi.)`;
        }
      }

      // 7. Save conversation to memory logs
      const conversationId = await this.saveConversation({
        userId,
        userMessage: message,
        botReply: sanitizedReply,
        intent: analysis.intent,
        sentiment: analysis.sentiment,
        shouldEscalate,
        ticketId,
        processingTime: Date.now() - startTime
      });

      return {
        success: true,
        conversationId,
        reply: sanitizedReply,
        intent: analysis.intent,
        sentiment: analysis.sentiment,
        shouldEscalate,
        ticketId,
        processingTimeMs: Date.now() - startTime
      };
    } catch (error) {
      console.error('[SupportChatbot] Exception processing message:', error.message);
      
      const fallbackReply = "Kripaya khed prakat karein, server network me thodi samasya hai. Humari team aapki madad ke liye taiyar hai. Aap humein +91 9876543210 par call kar sakte hain.";
      return {
        success: false,
        reply: fallbackReply,
        error: error.message,
        shouldEscalate: true
      };
    }
  }

  /**
   * Simple rule-based backup response generator if LLM fails
   */
  static generateRuleBasedReply(intent, orderTrackResult) {
    if (intent === 'TRACK_ORDER') {
      return orderTrackResult && orderTrackResult.orderData 
        ? `Aapka order #${orderTrackResult.orderData.orderNumber} status: ${orderTrackResult.orderData.status} hai.`
        : 'Aapka koi recent order history nahi mili. Kripaya double-check karein.';
    }
    if (intent === 'RETURN_REFUND') {
      return 'Returns delivery ke 7 days ke andar allow hai. Item unused aur sealed hona chahiye. Humare manager return verify karenge.';
    }
    return 'Fufaji Store support me aapka swagat hai. Hum Baran, Rajasthan me 8 AM se 9 PM tak open rehte hain. Aap humein +91 9876543210 par contact kar sakte hain.';
  }

  /**
   * Legacy Hinglish translator stub - kept for backward compatibility
   */
  static getHinglishReply(englishText) {
    return englishText;
  }

  /**
   * Handle track order - fetch latest order status from Firestore
   */
  static async handleTrackOrder(userId) {
    try {
      const orders = await db()
        .collection('orders')
        .where('customerId', '==', userId)
        .orderBy('createdAt', 'desc')
        .limit(1)
        .get();

      if (orders.empty) {
        return {
          reply: 'You have no recent orders.',
          orderData: null
        };
      }

      const orderDoc = orders.docs[0];
      const order = orderDoc.data();
      const orderNumber = order.orderNumber || orderDoc.id;

      const statusMap = {
        'OrderStatus.confirmed': 'Confirmed ✓',
        'OrderStatus.processing': 'Processing 🔄',
        'OrderStatus.packed': 'Packed 📦',
        'OrderStatus.shipped': 'Shipped 🚚',
        'OrderStatus.out_for_delivery': 'Out for delivery 🚴',
        'OrderStatus.delivered': 'Delivered ✅',
        'OrderStatus.cancelled': 'Cancelled ❌',
        'OrderStatus.returned': 'Returned ⤴️',
      };

      const status = statusMap[order.status] || order.status || 'Pending';

      return {
        reply: `Order #${orderNumber} is: ${status}.`,
        orderData: {
          orderNumber,
          status,
          deliveryDate: order.estimated_delivery_time || order.deliveryDate || null,
          totalAmount: order.final_amount || order.totalAmount || 0,
          itemCount: (order.items || []).length,
        }
      };
    } catch (error) {
      console.error('[Support] Track order error:', error.message);
      return {
        reply: 'Could not fetch order status.',
        orderData: null
      };
    }
  }

  /**
   * Save conversation to support_conversations collection
   */
  static async saveConversation(data) {
    try {
      const conversationRef = await db()
        .collection('support_conversations')
        .add({
          ...data,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          resolved: false
        });

      return conversationRef.id;
    } catch (error) {
      console.error('[Support] Failed to save conversation:', error.message);
      return null;
    }
  }

  /**
   * Create support ticket (direct method kept for backward compatibility/helper tests)
   */
  static async createTicket(userId, message, intent, reason) {
    try {
      const priority = ['QUALITY_COMPLAINT', 'PAYMENT_ISSUE', 'DELIVERY_ISSUE'].includes(intent) 
        ? 'HIGH' 
        : 'NORMAL';

      const ticketRef = await db()
        .collection('support_tickets')
        .add({
          userId,
          message,
          intent,
          escalationReason: reason,
          status: 'OPEN',
          priority,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          assignedAgent: null
        });

      return ticketRef.id;
    } catch (error) {
      console.error('[Support] Failed to create ticket:', error.message);
      return null;
    }
  }

  /**
   * Get conversation history for a user
   */
  static async getConversationHistory(userId, limit = 50) {
    try {
      const conversations = await db()
        .collection('support_conversations')
        .where('userId', '==', userId)
        .orderBy('createdAt', 'desc')
        .limit(limit)
        .get();

      return {
        success: true,
        totalConversations: conversations.size,
        conversations: conversations.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        })),
      };
    } catch (error) {
      console.error('[Support] Failed to fetch history:', error.message);
      return { success: false, error: error.message };
    }
  }

  /**
   * Get support metrics & analytics
   */
  static async getSupportAnalytics(days = 30) {
    try {
      const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

      const conversations = await db()
        .collection('support_conversations')
        .where('createdAt', '>=', startDate)
        .get();

      const tickets = await db()
        .collection('support_tickets')
        .where('createdAt', '>=', startDate)
        .get();

      const sentiments = {};
      const intents = {};
      let totalEscalations = 0;

      conversations.forEach((doc) => {
        const data = doc.data();
        sentiments[data.sentiment] = (sentiments[data.sentiment] || 0) + 1;
        intents[data.intent] = (intents[data.intent] || 0) + 1;
        if (data.shouldEscalate) totalEscalations++;
      });

      return {
        success: true,
        period: `Last ${days} days`,
        totalConversations: conversations.size,
        totalTickets: tickets.size,
        escalationRate: conversations.size > 0 
          ? ((totalEscalations / conversations.size) * 100).toFixed(1) + '%'
          : '0%',
        sentimentBreakdown: sentiments,
        topIntents: Object.entries(intents)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 5),
        estimatedCostSavings: `₹${(conversations.size * 50).toLocaleString()}`,
        estimatedTimeSavedHours: (conversations.size * 0.25).toFixed(1),
      };
    } catch (error) {
      console.error('[Support] Failed to get analytics:', error.message);
      return { success: false, error: error.message };
    }
  }
}

module.exports = SupportChatbotService;
