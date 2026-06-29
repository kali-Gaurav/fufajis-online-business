/**
 * ConversationMemoryService.js
 * Manages customer conversation context log retrieval and formatting
 * for multi-turn conversational memory.
 */

const { db } = require('../firestore');

class ConversationMemoryService {
  /**
   * Get past conversation turns for a user in a structured string format
   * @param {string} userId
   * @param {number} limit - Max turns to load
   * @returns {Promise<string>} - Context string for prompt
   */
  static async getConversationContextString(userId, limit = 5) {
    try {
      const snapshot = await db()
        .collection('support_conversations')
        .where('userId', '==', userId)
        .orderBy('createdAt', 'desc')
        .limit(limit)
        .get();

      if (snapshot.empty) {
        return 'No previous conversation history.';
      }

      // Convert docs to array and reverse to keep chronological order
      const turns = [];
      snapshot.forEach((doc) => {
        turns.push(doc.data());
      });
      turns.reverse();

      return turns
        .map((t) => `User: ${t.userMessage}\nBot: ${t.botReply}`)
        .join('\n');
    } catch (error) {
      console.warn('[ConversationMemory] Failed to load dialogue context:', error.message);
      return 'No previous conversation history.';
    }
  }

  /**
   * Get conversation history array for support handover logs
   * @param {string} userId
   * @param {number} limit
   * @returns {Promise<Array>}
   */
  static async getRawHistoryArray(userId, limit = 10) {
    try {
      const snapshot = await db()
        .collection('support_conversations')
        .where('userId', '==', userId)
        .orderBy('createdAt', 'desc')
        .limit(limit)
        .get();

      const history = [];
      snapshot.forEach((doc) => {
        const d = doc.data();
        history.push({
          userMessage: d.userMessage,
          botReply: d.botReply,
          intent: d.intent,
          sentiment: d.sentiment,
          timestamp: d.createdAt ? d.createdAt.toDate() : new Date()
        });
      });
      history.reverse();
      return history;
    } catch (error) {
      console.error('[ConversationMemory] Error getting raw history array:', error.message);
      return [];
    }
  }
}

module.exports = ConversationMemoryService;
