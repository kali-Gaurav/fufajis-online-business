const express = require('express');
const router = express.Router();
const { admin } = require('../firestore');
const secrets = require('../secrets');
const { verifyToken, requireRole } = require('../auth');

router.post(
  '/trigger',
  verifyToken,
  requireRole('UserRole.admin', 'UserRole.shopOwner'),
  async (req, res) => {
    console.log('[OnDemandReport] Test report requested by owner...');

    try {
      const db = admin.firestore();
      const WHATSAPP_TOKEN = secrets.get('whatsapp/token');
      const WHATSAPP_PHONE_ID = secrets.get('whatsapp/phone_id');

      if (!WHATSAPP_TOKEN || !WHATSAPP_PHONE_ID) {
        console.error('[OnDemandReport] Missing WhatsApp config.');
        return res.status(500).json({ success: false, error: 'Missing WhatsApp config' });
      }

      const settingsDoc = await db.collection('settings').doc('shop_config').get();
      if (!settingsDoc.exists) {
        return res.status(404).json({ success: false, error: 'shop_config not found' });
      }

      const ownerPhone = settingsDoc.data().ownerPhone;
      if (!ownerPhone) {
        return res.status(400).json({ success: false, error: 'ownerPhone not set in shop_config' });
      }

      let cleanPhone = ownerPhone.replace(/\D/g, '');
      if (cleanPhone.length === 10) cleanPhone = '91' + cleanPhone;
      else if (!cleanPhone.startsWith('91')) cleanPhone = '91' + cleanPhone;

      // Calculate today's stats (IST midnight boundary)
      const now = new Date();
      const istOffset = 5.5 * 60 * 60 * 1000;
      const nowIST = new Date(now.getTime() + istOffset);
      const midnightIST = new Date(nowIST);
      midnightIST.setHours(0, 0, 0, 0);
      const midnightUTC = new Date(midnightIST.getTime() - istOffset);
      const midnightTimestamp = admin.firestore.Timestamp.fromDate(midnightUTC);

      const ordersSnap = await db
        .collection('orders')
        .where('createdAt', '>=', midnightTimestamp)
        .get();

      const orders = ordersSnap.docs.map((d) => d.data());
      const totalOrders = orders.length;
      const totalRevenue = orders.reduce((sum, o) => sum + (o.totalAmount || 0), 0);
      const deliveredOrders = orders.filter((o) => (o.status || '').toLowerCase().includes('delivered')).length;
      const pendingOrders = orders.filter(
        (o) =>
          !(o.status || '').toLowerCase().includes('delivered') &&
          !(o.status || '').toLowerCase().includes('cancelled')
      ).length;
      const avgOrder = totalOrders > 0 ? totalRevenue / totalOrders : 0;

      const productCount = {};
      for (const order of orders) {
        for (const item of order.items || []) {
          const name = item.productName || 'Unknown';
          productCount[name] = (productCount[name] || 0) + (item.quantity || 1);
        }
      }
      const topProducts = Object.entries(productCount).sort((a, b) => b[1] - a[1]).slice(0, 3);

      const dateStr = nowIST.toLocaleDateString('en-IN', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        timeZone: 'Asia/Kolkata'
      });

      const topProductsText =
        topProducts.length === 0
          ? '• Koi bhi orders nahi aaye aaj'
          : topProducts.map(([name, count]) => `• ${name} - ${count} orders`).join('\n');

      const message =
`🧪 *TEST REPORT — Fufaji's Online*
📅 ${dateStr} (on-demand)

📦 *Total Orders:* ${totalOrders}
✅ *Delivered:* ${deliveredOrders}
⏳ *Pending:* ${pendingOrders}
💰 *Revenue:* ₹${Math.round(totalRevenue)}
📈 *Average Order:* ₹${Math.round(avgOrder)}

🔥 *Top Products:*
${topProductsText}

Yeh test report tha. Real report 10 PM pe aayega! 🙏
- Fufaji's Online Team`;

      const response = await fetch(`https://graph.facebook.com/v25.0/${WHATSAPP_PHONE_ID}/messages`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${WHATSAPP_TOKEN}`
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          to: cleanPhone,
          type: 'text',
          text: { body: message }
        })
      });

      const result = await response.json();
      const success = response.ok;

      // Log the on-demand report doc
      await db.collection('report_trigger_queue').add({
        type: 'daily_owner_report',
        status: success ? 'sent' : 'failed',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        whatsappResponse: JSON.stringify(result).substring(0, 200)
      });

      if (success) {
        return res.json({ success: true, message: `Report sent successfully to ${cleanPhone}` });
      } else {
        return res.status(500).json({ success: false, error: result.error || 'WhatsApp API failed' });
      }
    } catch (error) {
      console.error('[OnDemandReport] Error:', error);
      return res.status(500).json({ success: false, error: error.message });
    }
  }
);

module.exports = router;
