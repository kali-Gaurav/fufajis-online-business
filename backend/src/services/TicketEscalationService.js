/**
 * TicketEscalationService.js
 * Manages human support ticket creation and handoff continuity logs.
 * Attaches order context and conversation history to tickets.
 */

const { db, admin } = require('../firestore');
const ConversationMemoryService = require('./ConversationMemoryService');

class TicketEscalationService {
  /**
   * Create an escalated ticket for human support agents with full history context
   * @param {string} userId
   * @param {string} lastMessage - The message triggering the escalation
   * @param {string} intent - Detected intent
   * @param {string} reason - Escalation reason description
   * @param {Object} orderContext - Optional customer order status
   * @returns {Promise<string>} - The ticket ID
   */
  static async escalate(userId, lastMessage, intent, reason, orderContext = null) {
    try {
      // 1. Get recent conversation transcript logs for handoff continuity
      const conversationHistory = await ConversationMemoryService.getRawHistoryArray(userId, 8);

      // 2. Set priority
      const priority = ['QUALITY_COMPLAINT', 'PAYMENT_ISSUE', 'DELIVERY_ISSUE'].includes(intent) 
        ? 'HIGH' 
        : 'NORMAL';

      // 3. Save ticket to Firestore support_tickets
      const ticketRef = await db()
        .collection('support_tickets')
        .add({
          userId,
          message: lastMessage,
          intent,
          escalationReason: reason,
          status: 'OPEN',
          priority,
          conversationHistory,
          orderContext,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          assignedAgent: null
        });

      console.log(`[TicketEscalation] Escalated ticket ${ticketRef.id} with priority ${priority} and full conversation history.`);
      return ticketRef.id;
    } catch (error) {
      console.error('[TicketEscalation] Ticket creation failed:', error.message);
      return null;
    }
  }
}

module.exports = TicketEscalationService;
