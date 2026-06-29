const express = require('express');
const router = express.Router();
const secrets = require('../secrets');
const { verifyToken } = require('../auth');

router.post('/send', verifyToken, async (req, res) => {
  const { to, type, text, template, interactive } = req.body || {};

  if (!to || !type) {
    return res.status(400).json({ success: false, error: 'Missing to or type parameter.' });
  }

  const token = secrets.get('whatsapp/token');
  const phoneId = secrets.get('whatsapp/phone_id');

  if (!token || !phoneId) {
    return res.status(500).json({ success: false, error: 'WhatsApp service is not configured on server.' });
  }

  const payload = {
    messaging_product: 'whatsapp',
    to: to,
    type: type
  };
  if (text) payload.text = text;
  if (template) payload.template = template;
  if (interactive) payload.interactive = interactive;

  try {
    const response = await fetch(`https://graph.facebook.com/v25.0/${phoneId}/messages`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify(payload)
    });

    const result = await response.json();
    if (response.ok) {
      return res.json({ success: true, data: result });
    } else {
      console.error('[sendWhatsAppNotification] Meta API error:', result);
      return res.status(response.status).json({ success: false, error: result });
    }
  } catch (error) {
    console.error('[sendWhatsAppNotification] Exception:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
