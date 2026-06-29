/**
 * routes/support.js
 * AI-powered 24/7 customer support endpoints
 */

const express = require('express');
const router = express.Router();
const { verifyToken } = require('../auth');
const SupportChatbotService = require('../services/SupportChatbotService');

// ── Send Chat Message ──────────────────────────────────────────────────────
router.post('/chat', verifyToken, async (req, res) => {
  const { message } = req.body || {};
  const userId = req.user.uid;

  if (!message || message.trim().length === 0) {
    return res.status(400).json({ success: false, error: 'Message is required.' });
  }

  try {
    const result = await SupportChatbotService.processMessage(userId, message);

    if (result.shouldEscalate && !result.ticketId) {
      const ticketId = await SupportChatbotService.createTicket(
        userId,
        message,
        result.intent,
        'Auto-escalated due to complexity or sentiment'
      );
      result.ticketId = ticketId;
    }

    return res.json(result);
  } catch (error) {
    console.error('[support/chat] Error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ── Get Conversation History ───────────────────────────────────────────────
router.get('/history', verifyToken, async (req, res) => {
  const userId = req.user.uid;
  const { limit = 50 } = req.query;

  try {
    const result = await SupportChatbotService.getConversationHistory(
      userId,
      parseInt(limit)
    );
    return res.json(result);
  } catch (error) {
    console.error('[support/history] Error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ── Create Support Ticket ──────────────────────────────────────────────────
router.post('/create-ticket', verifyToken, async (req, res) => {
  const { message, reason } = req.body || {};
  const userId = req.user.uid;

  if (!message) {
    return res.status(400).json({ success: false, error: 'Message is required.' });
  }

  try {
    const ticketId = await SupportChatbotService.createTicket(
      userId,
      message,
      'MANUAL_TICKET',
      reason || 'Customer requested human support'
    );

    return res.json({
      success: true,
      message: 'Ticket created. Our team will contact you shortly.',
      ticketId,
    });
  } catch (error) {
    console.error('[support/create-ticket] Error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ── Get Support Analytics (Admin Only) ──────────────────────────────────────
router.get('/analytics', verifyToken, async (req, res) => {
  const { days = 30 } = req.query;

  // Check if admin
  if (req.user.role !== 'UserRole.admin' && req.user.role !== 'UserRole.shopOwner') {
    return res.status(403).json({ success: false, error: 'Admin access required.' });
  }

  try {
    const result = await SupportChatbotService.getSupportAnalytics(parseInt(days));
    return res.json(result);
  } catch (error) {
    console.error('[support/analytics] Error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ── Track Order (Support Helper) ───────────────────────────────────────────
router.get('/track-order', verifyToken, async (req, res) => {
  const userId = req.user.uid;

  try {
    const result = await SupportChatbotService.handleTrackOrder(userId);
    return res.json(result);
  } catch (error) {
    console.error('[support/track-order] Error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
