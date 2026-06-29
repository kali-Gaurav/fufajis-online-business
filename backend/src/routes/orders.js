const express = require('express');
const router = express.Router();
const { admin } = require('../firestore');
const secrets = require('../secrets');
const { verifyToken } = require('../auth');
const SupabaseOrderService = require('../services/SupabaseOrderService');

// ── Helper: Send FCM & WhatsApp notification to customer ───────────────────
async function notifyCustomer(orderId, orderData, status, details = {}) {
  try {
    const db = admin.firestore();
    const customerId = orderData.customerId;
    const orderNumber = orderData.orderNumber || orderId.substring(0, 8).toUpperCase();

    // 1. Get customer FCM token & Phone
    const userDoc = await db.collection('users').doc(customerId).get();
    if (!userDoc.exists) return;
    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;
    const phone = userData.phoneNumber || orderData.customerPhone || (orderData.deliveryAddress && orderData.deliveryAddress.phone);

    let title = `📦 Order Placed!`;
    let body = `We have received your order #${orderNumber}!`;

    if (status) {
      const cleanStatus = status.replace('OrderStatus.', '');
      title = `📦 Order #${orderNumber} Update`;
      switch (cleanStatus) {
        case 'confirmed':
          body = "Your order has been confirmed by the shop!";
          break;
        case 'processing':
          body = "We are preparing your items for delivery.";
          break;
        case 'packed':
          body = "Your order has been packed and is ready!";
          break;
        case 'outForDelivery':
          const otp = orderData.otp || 'N/A';
          const rider = orderData.deliveryEmployeeName || 'a rider';
          body = `Our rider (${rider}) is on the way! 🚴 Your Delivery OTP is: ${otp}`;
          break;
        case 'delivered':
          body = "Order delivered! Enjoy your purchase. 🎉";
          break;
        case 'cancelled':
          body = "Your order has been cancelled.";
          break;
        default:
          body = `Your order status is now: ${cleanStatus}`;
      }
    }

    // 2. Send FCM if token exists
    if (fcmToken) {
      const message = {
        notification: { title, body },
        data: {
          orderId: orderId,
          status: status || 'pending',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          type: 'orderUpdate'
        },
        token: fcmToken
      };
      await admin.messaging().send(message).catch(e => console.error('[FCM Error]', e.message));
    }

    // 3. Save to In-App Notification Center
    await db.collection('users').doc(customerId).collection('notifications').add({
      title,
      body,
      type: 'orderUpdate',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
      data: { orderId }
    }).catch(e => console.error('[Notification Center Error]', e.message));

    // 4. Send WhatsApp if configured (only for place order, confirmed, outForDelivery)
    const normalizedStatus = status ? status.replace('OrderStatus.', '') : 'placed';
    if (phone && (normalizedStatus === 'placed' || normalizedStatus === 'confirmed' || normalizedStatus === 'outForDelivery')) {
      const WHATSAPP_TOKEN = secrets.get('whatsapp/token');
      const WHATSAPP_PHONE_ID = secrets.get('whatsapp/phone_id');
      if (WHATSAPP_TOKEN && WHATSAPP_PHONE_ID) {
        const cleanPhone = phone.replace(/\D/g, '');
        const waPhone = cleanPhone.length === 10 ? '91' + cleanPhone : cleanPhone;

        const textMessage = `Fufaji Update: ${body}\nTrack here: https://fufajionline.com/track/${orderId}`;
        await fetch(`https://graph.facebook.com/v25.0/${WHATSAPP_PHONE_ID}/messages`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${WHATSAPP_TOKEN}`,
          },
          body: JSON.stringify({
            messaging_product: 'whatsapp',
            to: waPhone,
            type: 'text',
            text: { body: textMessage }
          })
        }).catch(e => console.error('[WhatsApp Send Error]', e.message));
      }
    }
  } catch (err) {
    console.error('Error sending order notification:', err);
  }
}

// ── Helper: Check & Trigger Low Stock WhatsApp Alerts ──────────────────────
async function checkAndTriggerLowStock(productId, stockBefore, stockAfter, productData) {
  try {
    const minimumStock = productData.minimumStock ?? 10;
    const justWentLow = stockAfter < minimumStock && stockBefore >= minimumStock;
    if (!justWentLow) return;

    const WHATSAPP_TOKEN = secrets.get('whatsapp/token');
    const PHONE_ID = secrets.get('whatsapp/phone_id');
    if (!WHATSAPP_TOKEN || !PHONE_ID) {
      console.warn('[LowStockAlert] Missing WhatsApp config. Skipping.');
      return;
    }

    const db = admin.firestore();
    const productName = productData.name || 'Unknown Product';
    const unit = productData.unit || 'units';

    const ownerMessage = `⚠️ *Low Stock Alert — Fufaji's Online*\n\n📦 *Product:* ${productName}\n📉 *Current Stock:* ${stockAfter} ${unit}\n🔴 *Minimum Level:* ${minimumStock} ${unit}\n\nJaldi reorder karein ya supplier ko contact karein!\n- Fufaji's Online System`;
    const supplierMessage = `📦 *Reorder Request — Fufaji's Online*\n\nNamaste! Hamara ${productName} ka stock low ho gaya hai.\n\n📉 Current: ${stockAfter} ${unit}\n📋 Product ID: ${productId}\n\nKripya jald se jald supply bhejein.\n- Fufaji's Online, Baran`;

    const sendWA = async (toPhone, body) => {
      const cleanPhone = toPhone.replace(/\D/g, '');
      const waPhone = cleanPhone.length === 10 ? '91' + cleanPhone : cleanPhone;
      await fetch(`https://graph.facebook.com/v18.0/${PHONE_ID}/messages`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${WHATSAPP_TOKEN}`
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          to: waPhone,
          type: 'text',
          text: { body }
        })
      });
    };

    // Send to owner
    const settingsDoc = await db.collection('settings').doc('shop_config').get();
    if (settingsDoc.exists && settingsDoc.data().ownerPhone) {
      await sendWA(settingsDoc.data().ownerPhone, ownerMessage).catch(e => console.error('[WA Owner Error]', e.message));
    }

    // Send to supplier
    const supplierPhone = productData.supplierPhone;
    if (supplierPhone) {
      await sendWA(supplierPhone, supplierMessage).catch(e => console.error('[WA Supplier Error]', e.message));
    }

    // Log the alert
    await db.collection('low_stock_alerts').add({
      productId,
      productName,
      stockAfter,
      minimumStock,
      unit,
      supplierPhone: supplierPhone || null,
      alertSentAt: admin.firestore.FieldValue.serverTimestamp(),
    }).catch(e => console.error('[LowStockLog Error]', e.message));

  } catch (err) {
    console.error('[LowStockAlert] Error:', err);
  }
}

// ── 1. Place Order ──────────────────────────────────────────────────────────
router.post('/', verifyToken, async (req, res) => {
  const db = admin.firestore();
  const order = req.body;

  if (!order || !order.id || !Array.isArray(order.items)) {
    return res.status(400).json({ success: false, error: 'Invalid order payload' });
  }

  try {
    const result = await db.runTransaction(async (transaction) => {
      // Step 1: Validate stock
      const productSnaps = {};
      for (const item of order.items) {
        const productRef = db.collection('products').doc(item.productId);
        const productSnap = await transaction.get(productRef);
        if (!productSnap.exists) {
          throw new Error(`Product ${item.productName || item.productId} not found`);
        }
        const currentStock = productSnap.data().stockQuantity ?? 0;
        if (currentStock < item.quantity) {
          throw new Error(`Insufficient stock for ${item.productName || item.productId}`);
        }
        productSnaps[item.productId] = { snap: productSnap, before: currentStock };
      }

      // Step 2: Write order
      const orderRef = db.collection('orders').doc(order.id);
      order.createdAt = admin.firestore.FieldValue.serverTimestamp();
      order.updatedAt = admin.firestore.FieldValue.serverTimestamp();
      transaction.set(orderRef, order);

      // Step 3: Deduct stock
      for (const item of order.items) {
        const productRef = db.collection('products').doc(item.productId);
        const newStock = productSnaps[item.productId].before - item.quantity;
        transaction.update(productRef, {
          stockQuantity: newStock,
          lastInventoryUpdateAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      return { order, productSnaps };
    });

    // Step 4: Run alerts & notifications after transaction succeeds
    for (const item of order.items) {
      const { snap, before } = result.productSnaps[item.productId];
      const after = before - item.quantity;
      checkAndTriggerLowStock(item.productId, before, after, snap.data());
    }

    await notifyCustomer(order.id, order, null);

    // Step 5: Dual-write to Supabase (gradual migration)
    try {
      await SupabaseOrderService.createOrder({
        firestoreId: order.id,
        customerId: order.customerId,
        shopId: order.shopId,
        items: order.items,
        subtotal: order.subtotal,
        total: order.totalAmount || order.total,
        deliveryCharge: order.deliveryCharge || 0,
        discount: order.discount || 0,
        tax: order.tax || 0,
        paymentMethod: order.paymentMethod,
        deliveryAddress: order.deliveryAddress,
        deliveryType: order.deliveryType,
      });
      console.log(`[Supabase] Order dual-write successful: ${order.id}`);
    } catch (sbErr) {
      console.error(`[Supabase] Order dual-write failed for ${order.id}:`, sbErr.message);
      // Non-blocking: failure to write to Supabase doesn't fail the API call
    }

    return res.json({ success: true, order: result.order });

  } catch (e) {
    console.error('Order placement failed:', e);
    return res.status(500).json({ success: false, error: e.message });
  }
});

// ── 2. Update Order Status ──────────────────────────────────────────────────
router.post('/:id/status', verifyToken, async (req, res) => {
  const db = admin.firestore();
  const orderId = req.params.id;
  const { status, note, actorId, actorRole, actorName } = req.body || {};

  if (!status) {
    return res.status(400).json({ success: false, error: 'Missing status field' });
  }

  try {
    const orderRef = db.collection('orders').doc(orderId);
    const orderDoc = await orderRef.get();
    if (!orderDoc.exists) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    const orderData = orderDoc.data();
    if (orderData.orderStatus === status) {
      return res.json({ success: true, message: 'Status is already updated' });
    }

    const statusEntry = {
      status: status,
      timestamp: new Date(), // using local date object for array union formatting compatibility
      note: note || '',
      actorId: actorId || req.user.uid,
      actorRole: actorRole || '',
      actorName: actorName || req.user.name || ''
    };

    // If order is cancelled, restore stock
    if (status === 'OrderStatus.cancelled') {
      await db.runTransaction(async (transaction) => {
        const orderSnap = await transaction.get(orderRef);
        const data = orderSnap.data();
        if (data.orderStatus === 'OrderStatus.cancelled') return;

        // Restore product stock
        for (const item of data.items || []) {
          const productRef = db.collection('products').doc(item.productId);
          const productSnap = await transaction.get(productRef);
          if (productSnap.exists) {
            transaction.update(productRef, {
              stockQuantity: admin.firestore.FieldValue.increment(item.quantity)
            });
          }
        }

        transaction.update(orderRef, {
          orderStatus: status,
          cancellationReason: note || 'Cancelled',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          timeline: admin.firestore.FieldValue.arrayUnion(statusEntry)
        });
      });
    } else {
      await orderRef.update({
        orderStatus: status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        timeline: admin.firestore.FieldValue.arrayUnion(statusEntry)
      });
    }

    // Trigger notification
    const updatedOrder = { ...orderData, status };
    await notifyCustomer(orderId, updatedOrder, status);

    // Dual-write status update to Supabase
    try {
      await SupabaseOrderService.updateOrderStatus(orderId, status);
    } catch (sbErr) {
      console.error(`[Supabase] Status update dual-write failed for ${orderId}:`, sbErr.message);
    }

    return res.json({ success: true, message: `Status updated to ${status}` });

  } catch (e) {
    console.error('Status update failed:', e);
    return res.status(500).json({ success: false, error: e.message });
  }
});

module.exports = router;
