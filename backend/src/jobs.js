const { admin } = require('./firestore');
const secrets = require('./secrets');
const sgMail = require('@sendgrid/mail');

// ── Helper: Send SendGrid Email ─────────────────────────────────────────────
async function sendEmailViaSendGrid({ to, subject, html, categories }) {
  const apiKey = secrets.get('sendgrid/api_key');
  if (!apiKey) {
    console.warn('[SendGrid] API key not found. Skipping email send.');
    return;
  }
  sgMail.setApiKey(apiKey);
  const msg = {
    to,
    from: 'noreply@fufajionline.com',
    subject,
    html,
    categories
  };
  await sgMail.send(msg);
  console.log(`[SendGrid] Email sent successfully to ${to}`);
}

// ── 1. checkInventoryAlerts ─────────────────────────────────────────────────
async function checkInventoryAlerts(db) {
  console.log('[Job] Running checkInventoryAlerts...');
  const shopsSnapshot = await db.collection('shops').get();
  let count = 0;
  
  for (const shopDoc of shopsSnapshot.docs) {
    const shopId = shopDoc.id;
    const productsSnapshot = await db
      .collection('shops')
      .doc(shopId)
      .collection('products')
      .where('stockQuantity', '<=', 10)
      .get();

    for (const productDoc of productsSnapshot.docs) {
      const product = productDoc.data();
      await db.collection('inventory_alerts').add({
        shopId,
        productId: productDoc.id,
        productName: product.name,
        currentStock: product.stockQuantity,
        severity: product.stockQuantity <= 2 ? 'critical' : 'medium',
        status: 'active',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      count++;
    }
  }
  console.log(`[Job] checkInventoryAlerts complete. Generated ${count} alerts.`);
  return { success: true, count };
}

// ── 2. processExpiries ──────────────────────────────────────────────────────
async function processExpiries(db) {
  console.log('[Job] Running processExpiries...');
  const now = admin.firestore.Timestamp.now();
  const threeDaysFromNow = new admin.firestore.Timestamp(now.seconds + (3 * 24 * 60 * 60), 0);
  let count = 0;

  const productsSnapshot = await db
    .collectionGroup('products')
    .where('expiryDate', '<=', threeDaysFromNow)
    .get();

  for (const productDoc of productsSnapshot.docs) {
    const product = productDoc.data();
    if (product.expiryDate <= now) {
      await productDoc.ref.update({
        isAvailable: false,
        status: 'expired'
      });
    } else {
      const originalPrice = product.originalPrice || product.price;
      const discountedPrice = originalPrice * 0.8;
      await productDoc.ref.update({
        price: discountedPrice,
        isDiscounted: true,
        discountPercentage: 20,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    count++;
  }
  console.log(`[Job] processExpiries complete. Updated ${count} products.`);
  return { success: true, count };
}

// ── 3. updateDynamicPricing ─────────────────────────────────────────────────
async function updateDynamicPricing(db) {
  console.log('[Job] Running updateDynamicPricing (simulated)...');
  return { success: true };
}

// ── 4. checkExpiryAlerts ────────────────────────────────────────────────────
async function checkExpiryAlerts(db) {
  console.log('[Job] Running checkExpiryAlerts...');
  const now = new Date();
  const fifteenDaysFromNow = new Date(now.getTime() + 15 * 24 * 60 * 60 * 1000);
  const fifteenDaysTimestamp = admin.firestore.Timestamp.fromDate(fifteenDaysFromNow);

  try {
    const batchesSnapshot = await db
      .collectionGroup('inventory_batches')
      .where('expiryDate', '<=', fifteenDaysTimestamp)
      .get();

    console.log(`Found ${batchesSnapshot.size} batches expiring soon.`);
    if (batchesSnapshot.empty) return { success: true, count: 0 };

    const productCache = {};
    const branchUsersCache = {};
    let alertsCreated = 0;

    for (const batchDoc of batchesSnapshot.docs) {
      const batch = batchDoc.data();
      const pathSegments = batchDoc.ref.path.split('/');
      if (pathSegments.length < 5) continue;
      const shopId = pathSegments[1];
      const branchId = pathSegments[3];

      if (!batch.quantity || batch.quantity <= 0) continue;
      const expDate = batch.expiryDate ? batch.expiryDate.toDate() : null;
      if (!expDate || expDate < now) continue;

      const daysRemaining = Math.ceil((expDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));

      const productKey = `${shopId}_${branchId}_${batch.productId}`;
      if (!productCache[productKey]) {
        const productDoc = await db
          .collection('shops')
          .doc(shopId)
          .collection('branches')
          .doc(branchId)
          .collection('products')
          .doc(batch.productId)
          .get();
        productCache[productKey] = productDoc.exists ? productDoc.data().name : 'Unknown Product';
      }
      const productName = productCache[productKey];

      const branchKey = `${shopId}_${branchId}`;
      if (!branchUsersCache[branchKey]) {
        const usersSnapshot = await db.collection('users').where('isActive', '==', true).get();
        const staff = [];
        usersSnapshot.forEach((userDoc) => {
          const userData = userDoc.data();
          const isStaffRole =
            ['UserRole.employee', 'UserRole.shopOwner', 'UserRole.admin'].includes(userData.role) ||
            (userData.roles &&
              userData.roles.some((r) => ['UserRole.employee', 'UserRole.shopOwner', 'UserRole.admin'].includes(r)));
          const isAssigned = userData.branchId === branchId || userData.assignedBranchId === branchId || userData.shopId === shopId;

          if (isStaffRole && isAssigned && userData.fcmToken) {
            staff.push(userData.fcmToken);
          }
        });
        branchUsersCache[branchKey] = staff;
      }
      const fcmTokens = branchUsersCache[branchKey];

      const alertId = `expiry_alert_${batchDoc.id}`;
      await db
        .collection('shops')
        .doc(shopId)
        .collection('branches')
        .doc(branchId)
        .collection('inventory_alerts')
        .doc(alertId)
        .set(
          {
            id: alertId,
            type: 'near_expiry',
            productId: batch.productId,
            productName: productName,
            batchId: batch.batchId,
            currentStock: batch.quantity,
            expiryDate: batch.expiryDate,
            severity: daysRemaining <= 5 ? 'critical' : 'high',
            status: 'pending',
            message: `Batch ${batch.batchId} of ${productName} is expiring in ${daysRemaining} days. Qty: ${batch.quantity}.`,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
          },
          { merge: true }
        );
      alertsCreated++;

      if (fcmTokens.length > 0) {
        const messages = fcmTokens.map((token) => ({
          notification: {
            title: `⚠️ Near Expiry Alert: ${productName}`,
            body: `Batch ${batch.batchId} (${batch.quantity} units) is expiring in ${daysRemaining} days! Mark it down now.`
          },
          data: {
            type: 'expiryWarning',
            batchId: batch.batchId,
            productId: batch.productId,
            shopId: shopId,
            branchId: branchId
          },
          token: token
        }));
        await Promise.all(messages.map((msg) => admin.messaging().send(msg).catch(() => {})));
      }
    }
    return { success: true, count: alertsCreated };
  } catch (error) {
    console.error('Error executing checkExpiryAlerts:', error);
    return { success: false, error: error.message };
  }
}

// ── 5. processNotificationQueue ─────────────────────────────────────────────
async function processNotificationQueue(db) {
  console.log('[Job] Running processNotificationQueue...');
  const snapshot = await db.collection('notification_queue').where('status', '==', 'pending').limit(50).get();
  let count = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const { userId, fcmToken, title, body, orderId, type } = data;

    if (!fcmToken) {
      await doc.ref.update({
        status: 'skipped',
        reason: 'no_fcm_token',
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      continue;
    }

    try {
      const message = {
        notification: {
          title: title || '📦 Fufaji Update',
          body: body || 'You have a new notification.'
        },
        data: {
          orderId: orderId || '',
          type: type || 'general',
          click_action: 'FLUTTER_NOTIFICATION_CLICK'
        },
        token: fcmToken
      };

      const response = await admin.messaging().send(message);
      await doc.ref.update({
        status: 'sent',
        fcmResponse: response,
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      count++;
    } catch (error) {
      console.error(`[NotificationQueue] Error sending FCM to ${userId}:`, error.message);
      let errorReason = error.message;
      let shouldRemoveToken = false;

      if (error.code === 'messaging/invalid-registration-token' || error.code === 'messaging/registration-token-not-registered') {
        shouldRemoveToken = true;
        errorReason = 'invalid_or_expired_token';

        await db.collection('users').doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
          fcmTokenRemovedAt: admin.firestore.FieldValue.serverTimestamp(),
          fcmTokenRemovalReason: errorReason
        }).catch(() => {});
      }

      await doc.ref.update({
        status: 'failed',
        error: errorReason,
        tokenRemoved: shouldRemoveToken,
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Fallback to in-app notification
      await db.collection('users').doc(userId).collection('notifications').add({
        title: title || 'Fufaji Update',
        body: body || 'You have a new notification.',
        orderId: orderId || '',
        type: type || 'general',
        read: false,
        source: 'fcm_fallback',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      }).catch(() => {});
    }
  }
  return { success: true, count };
}

// ── 6. cleanupNotificationQueue ─────────────────────────────────────────────
async function cleanupNotificationQueue(db) {
  console.log('[Job] Running cleanupNotificationQueue...');
  try {
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const cutoff = admin.firestore.Timestamp.fromDate(sevenDaysAgo);

    const snapshot = await db
      .collection('notification_queue')
      .where('status', 'in', ['sent', 'skipped', 'failed'])
      .where('processedAt', '<', cutoff)
      .limit(500)
      .get();

    if (snapshot.empty) return { success: true, count: 0 };

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    console.log(`Deleted ${snapshot.size} processed notifications.`);
    return { success: true, count: snapshot.size };
  } catch (error) {
    console.error('[Cleanup] Error:', error);
    return { success: false, error: error.message };
  }
}

// ── 7. sendDailyOwnerReport ─────────────────────────────────────────────────
async function sendDailyOwnerReport(db) {
  console.log('[Job] Generating 10 PM owner report...');
  try {
    const WHATSAPP_TOKEN = secrets.get('whatsapp/token');
    const WHATSAPP_PHONE_ID = secrets.get('whatsapp/phone_id');

    if (!WHATSAPP_TOKEN || !WHATSAPP_PHONE_ID) {
      console.error('[DailyReport] Missing WhatsApp config.');
      return { success: false, error: 'Missing WhatsApp config' };
    }

    const settingsDoc = await db.collection('settings').doc('shop_config').get();
    if (!settingsDoc.exists) return { success: false, error: 'shop_config not found' };

    const ownerPhone = settingsDoc.data().ownerPhone;
    if (!ownerPhone) return { success: false, error: 'ownerPhone not set' };

    let cleanPhone = ownerPhone.replace(/\D/g, '');
    if (cleanPhone.length === 10) cleanPhone = '91' + cleanPhone;
    else if (!cleanPhone.startsWith('91')) cleanPhone = '91' + cleanPhone;

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
        ? '• Aaj koi order nahi aaya'
        : topProducts.map(([name, count]) => `• ${name} - ${count} orders`).join('\n');

    const message =
`📊 *Daily Shop Report — Fufaji's Online*
📅 ${dateStr}

📦 *Total Orders:* ${totalOrders}
✅ *Delivered:* ${deliveredOrders}
⏳ *Pending:* ${pendingOrders}
💰 *Revenue:* ₹${Math.round(totalRevenue)}
📈 *Avg Order:* ₹${Math.round(avgOrder)}

🔥 *Top Selling Items:*
${topProductsText}

Great job today! Aaraam se so jao. 🌙
- Fufaji's Online Automation`;

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
    await db.collection('system_logs').add({
      action: 'daily_report_sent',
      phone: cleanPhone,
      success: response.ok,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: response.ok, details: result };
  } catch (error) {
    console.error('[DailyReport] Fatal Error:', error);
    return { success: false, error: error.message };
  }
}

// ── 8. reconcileOrphanedPayments ───────────────────────────────────────────
async function reconcileOrphanedPayments(db) {
  console.log('[ReconcileOrphan] Starting orphan payment scan...');
  try {
    const cutoffTime = new Date(Date.now() - 15 * 60 * 1000);
    const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffTime);

    const snapshot = await db
      .collection('orders')
      .where('paymentStatus', '==', 'pending')
      .where('createdAt', '<', cutoffTimestamp)
      .limit(50)
      .get();

    if (snapshot.empty) return { success: true, count: 0 };

    let reconciled = 0;
    let failedOrExpired = 0;

    for (const doc of snapshot.docs) {
      const orderData = doc.data();
      const paymentId = orderData.paymentId;

      if (!paymentId || paymentId === '') {
        const createdAt = orderData.createdAt?.toDate();
        const thirtyMinAgo = new Date(Date.now() - 30 * 60 * 1000);
        if (createdAt && createdAt < thirtyMinAgo) {
          // Restore stock since order is cancelled due to payment timeout
          for (const item of orderData.items || []) {
            const productRef = db.collection('products').doc(item.productId);
            await productRef.update({
              stockQuantity: admin.firestore.FieldValue.increment(item.quantity)
            }).catch(() => {});
          }

          await doc.ref.update({
            paymentStatus: 'expired',
            status: 'OrderStatus.cancelled',
            cancellationReason: 'Payment not received within 30 minutes',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            reconciliationSource: 'orphan_scanner_timeout'
          });
          failedOrExpired++;
        }
        continue;
      }

      const paymentDoc = await db.collection('payments').doc(paymentId).get();
      let isPaid = false;

      if (paymentDoc.exists && paymentDoc.data().status === 'captured') {
        isPaid = true;
      } else {
        const webhookQuery = await db.collection('webhook_events').where('paymentId', '==', paymentId).limit(1).get();
        if (!webhookQuery.empty) isPaid = true;
      }

      if (isPaid) {
        await doc.ref.update({
          paymentStatus: 'paid',
          status: 'OrderStatus.confirmed',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          reconciliationSource: 'orphan_scanner',
          reconciledAt: admin.firestore.FieldValue.serverTimestamp()
        });
        reconciled++;
      }
    }

    await db.collection('payment_reconciliation_log').add({
      action: 'orphan_scan_complete',
      totalScanned: snapshot.size,
      reconciled: reconciled,
      expiredOrFailed: failedOrExpired,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, reconciled, expired: failedOrExpired };
  } catch (error) {
    console.error('[ReconcileOrphan] Error:', error);
    return { success: false, error: error.message };
  }
}

// ── Main Entry Point for scheduled Events ──────────────────────────────────
async function runJob(event) {
  const jobName = event.job || event.resources?.[0]?.split('/')?.pop() || '';
  console.log(`[Jobs Runner] Invoking job: ${jobName}`);
  const db = admin.firestore();

  switch (jobName) {
    case 'checkInventoryAlerts':
      return checkInventoryAlerts(db);
    case 'processExpiries':
      return processExpiries(db);
    case 'updateDynamicPricing':
      return updateDynamicPricing(db);
    case 'checkExpiryAlerts':
      return checkExpiryAlerts(db);
    case 'processNotificationQueue':
      return processNotificationQueue(db);
    case 'cleanupNotificationQueue':
      return cleanupNotificationQueue(db);
    case 'sendDailyOwnerReport':
      return sendDailyOwnerReport(db);
    case 'reconcileOrphanedPayments':
      return reconcileOrphanedPayments(db);
    case 'checkTimeBasedAutomationRules':
      try {
        const automation = require('./lib/automation');
        await automation.checkTimeBasedAutomationRules(db);
        return { success: true };
      } catch (e) {
        console.error('[Job] AutomationRules failed:', e);
        return { success: false, error: e.message };
      }
    default:
      console.warn(`[Jobs Runner] Unknown job: ${jobName}`);
      return { success: false, error: `Unknown job: ${jobName}` };
  }
}

module.exports = {
  runJob,
  sendEmailViaSendGrid
};
