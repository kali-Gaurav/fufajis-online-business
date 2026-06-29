// Ported from functions/index.js: generateAndSendInvoice
//   -> POST /invoices/generate   (signed-in user)
//
// Sends a formatted WhatsApp text invoice via the Meta Graph API (same as the
// old function), then stamps invoiceSentAt on the order.
// Contract: body { orderId } -> { success, messageId, sentTo, orderNumber }.

const express = require('express');
const router = express.Router();
const { admin } = require('../firestore');
const secrets = require('../secrets');
const { verifyToken } = require('../auth');

router.post('/generate', verifyToken, async (req, res) => {
  const { orderId } = req.body || {};
  if (!orderId) return res.status(400).json({ success: false, error: 'orderId is required.' });

  const WHATSAPP_TOKEN = secrets.get('whatsapp/token') || '';
  const PHONE_ID = secrets.get('whatsapp/phone_id') || '';
  if (!WHATSAPP_TOKEN || !PHONE_ID) {
    return res.status(412).json({ success: false, error: 'WhatsApp not configured on the backend.' });
  }

  try {
    const db = admin.firestore();
    const orderDoc = await db.collection('orders').doc(orderId).get();
    if (!orderDoc.exists) {
      return res.status(404).json({ success: false, error: `Order ${orderId} not found.` });
    }

    const order = orderDoc.data();
    const orderNumber = order.orderNumber || orderId.substring(0, 8).toUpperCase();
    const customerPhone = order.customerPhone || (order.deliveryAddress && order.deliveryAddress.phone);
    if (!customerPhone) {
      return res.status(412).json({ success: false, error: 'Customer phone not found on order.' });
    }

    const items = order.items || [];
    let itemLines = '';
    for (const item of items) {
      const name = item.productName || item.name || 'Item';
      const qty = item.quantity || 1;
      const unit = item.unit || 'pcs';
      const price = item.price || item.unitPrice || 0;
      const total = (qty * price).toFixed(2);
      itemLines += `  • ${name}: ${qty} ${unit} × ₹${price} = ₹${total}\n`;
    }

    const subtotal = order.subtotal != null ? order.subtotal : (order.totalAmount || 0);
    const deliveryFee = order.deliveryFee != null ? order.deliveryFee : 0;
    const discount = order.discount != null ? order.discount : 0;
    const total = order.totalAmount != null ? order.totalAmount : subtotal;

    const createdAt =
      order.createdAt && order.createdAt.toDate
        ? order.createdAt.toDate().toLocaleDateString('en-IN', {
            day: '2-digit', month: 'short', year: 'numeric', timeZone: 'Asia/Kolkata',
          })
        : new Date().toLocaleDateString('en-IN', { timeZone: 'Asia/Kolkata' });

    const paymentMethod = order.paymentMethod || 'COD';
    const paymentStatus = order.paymentStatus || 'pending';

    const invoiceMessage =
`🧾 *INVOICE — Fufaji's Online*
━━━━━━━━━━━━━━━━━━━━━━
📋 Order #${orderNumber}
📅 Date: ${createdAt}
━━━━━━━━━━━━━━━━━━━━━━

*Items:*
${itemLines}
━━━━━━━━━━━━━━━━━━━━━━
🛒 Subtotal:    ₹${subtotal.toFixed ? subtotal.toFixed(2) : subtotal}
🚴 Delivery:    ₹${deliveryFee}
${discount > 0 ? `🎁 Discount:    -₹${discount}\n` : ''}💰 *TOTAL:       ₹${total.toFixed ? total.toFixed(2) : total}*
━━━━━━━━━━━━━━━━━━━━━━
💳 Payment: ${paymentMethod.toUpperCase()} (${paymentStatus})

Aapka shukriya! 🙏
Fufaji's Online — Baran, Rajasthan
`;

    let cleanPhone = customerPhone.replace(/\D/g, '');
    if (cleanPhone.length === 10) cleanPhone = '91' + cleanPhone;
    else if (!cleanPhone.startsWith('91')) cleanPhone = '91' + cleanPhone;

    const response = await fetch(`https://graph.facebook.com/v18.0/${PHONE_ID}/messages`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${WHATSAPP_TOKEN}` },
      body: JSON.stringify({
        messaging_product: 'whatsapp',
        to: cleanPhone,
        type: 'text',
        text: { body: invoiceMessage },
      }),
    });
    const result = await response.json();

    if (!response.ok) {
      console.error(`[Invoice] WA send failed: ${JSON.stringify(result)}`);
      return res.status(500).json({ success: false, error: 'WhatsApp send failed.' });
    }

    const messageId = result.messages && result.messages[0] && result.messages[0].id;
    await orderDoc.ref.update({
      invoiceSentAt: admin.firestore.FieldValue.serverTimestamp(),
      invoiceMessageId: messageId || '',
    });

    console.log(`[Invoice] Invoice sent for order ${orderNumber} to ${cleanPhone}`);
    return res.json({ success: true, messageId, sentTo: cleanPhone, orderNumber });
  } catch (e) {
    console.error('[Invoice] Error:', e);
    return res.status(500).json({ success: false, error: 'Invoice generation failed: ' + e.message });
  }
});

module.exports = router;
