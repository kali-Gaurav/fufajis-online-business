import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

// 1. Daily Business Summary (Runs daily at 11:59 PM Asia/Kolkata)
export const dailyBusinessSummary = functions
  .region('asia-south1')
  .pubsub.schedule('59 23 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    try {
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const ordersSnap = await db.collection('orders')
        .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(today))
        .get();

      let totalRevenue = 0;
      let totalOrders = 0;

      ordersSnap.forEach((doc) => {
        const data = doc.data();
        if (data.status === 'delivered' || data.status === 'completed') {
          totalRevenue += data.totalAmount || 0;
          totalOrders++;
        }
      });

      // Fetch owners to notify
      const ownersSnap = await db.collection('users')
        .where('role', '==', 'UserRole.owner')
        .get();

      const fcmTokens: string[] = [];
      ownersSnap.forEach((doc) => {
        const data = doc.data();
        if (data.fcmToken) {
          fcmTokens.push(data.fcmToken);
        }
      });

      if (fcmTokens.length > 0) {
        await admin.messaging().sendMulticast({
          tokens: fcmTokens,
          notification: {
            title: 'Daily Business Summary 📊',
            body: `Today's Revenue: ₹${totalRevenue.toFixed(2)} from ${totalOrders} orders. Great job!`,
          },
          data: { type: 'business_summary' },
        });
      }

      console.log(`[Automation] Daily summary sent. Revenue: ${totalRevenue}`);
    } catch (error) {
      console.error('[Automation] Error running daily business summary:', error);
    }
  });

// 2. Low Stock Alerts (Runs every 2 hours)
export const lowStockAlerts = functions
  .region('asia-south1')
  .pubsub.schedule('0 */2 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    try {
      // Find products where stock is 5 or less
      const productsSnap = await db.collection('products')
        .where('stockQuantity', '<=', 5)
        .limit(20)
        .get();

      if (productsSnap.empty) {
        console.log('[Automation] No low stock items found.');
        return;
      }

      let lowItems: string[] = [];
      productsSnap.forEach((doc) => {
        const p = doc.data();
        lowItems.push(`${p.name} (${p.stockQuantity} left)`);
      });

      const bodyText = lowItems.slice(0, 5).join(', ') + 
        (lowItems.length > 5 ? ` and ${lowItems.length - 5} more.` : '.');

      // Add to alerts collection for dashboard
      await db.collection('alerts').add({
        type: 'low_stock',
        title: 'Low Stock Alert ⚠️',
        message: bodyText,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
      });

      // Fetch managers/owners to notify
      const staffSnap = await db.collection('users')
        .where('role', 'in', ['UserRole.owner', 'UserRole.manager'])
        .get();

      const fcmTokens: string[] = [];
      staffSnap.forEach((doc) => {
        const data = doc.data();
        if (data.fcmToken) fcmTokens.push(data.fcmToken);
      });

      if (fcmTokens.length > 0) {
        await admin.messaging().sendMulticast({
          tokens: fcmTokens,
          notification: {
            title: 'Low Stock Alert ⚠️',
            body: bodyText,
          },
          data: { type: 'inventory_alert' },
        });
      }

      console.log(`[Automation] Low stock alert sent for ${lowItems.length} items.`);
    } catch (error) {
      console.error('[Automation] Error running low stock alerts:', error);
    }
  });

// 3. Automated Marketing & Retention (Runs daily at 10:00 AM)
export const automatedMarketing = functions
  .region('asia-south1')
  .pubsub.schedule('0 10 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    try {
      const fourteenDaysAgo = new Date();
      fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14);

      // Find customers who haven't ordered in 14 days and haven't received an incentive recently
      const dormantUsersSnap = await db.collection('users')
        .where('role', '==', 'UserRole.customer')
        .where('lastOrderAt', '<=', admin.firestore.Timestamp.fromDate(fourteenDaysAgo))
        .limit(50) // Batch processing
        .get();

      if (dormantUsersSnap.empty) {
        console.log('[Automation] No dormant users found today.');
        return;
      }

      const batch = db.batch();
      let sentCount = 0;
      const fcmTokens: string[] = [];

      dormantUsersSnap.forEach((doc) => {
        const data = doc.data();
        
        // Ensure we don't spam. Check lastIncentiveSentAt
        const lastIncentive = data.lastIncentiveSentAt?.toDate();
        if (lastIncentive) {
          const daysSinceIncentive = (Date.now() - lastIncentive.getTime()) / (1000 * 3600 * 24);
          if (daysSinceIncentive < 30) return; // Don't send more than once a month
        }

        const userRef = doc.ref;
        
        // 1. Add wallet funds
        const walletTransactionRef = db.collection('wallet_transactions').doc();
        batch.set(walletTransactionRef, {
          userId: doc.id,
          amount: 50,
          type: 'credit',
          source: 'automated_retention',
          description: 'We miss you! Here is ₹50 in your Fufaji Wallet.',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          status: 'completed'
        });

        // Update user balance and tracking
        batch.update(userRef, {
          walletBalance: admin.firestore.FieldValue.increment(50),
          lastIncentiveSentAt: admin.firestore.FieldValue.serverTimestamp()
        });

        if (data.fcmToken) {
          fcmTokens.push(data.fcmToken);
        }
        sentCount++;
      });

      await batch.commit();

      if (fcmTokens.length > 0) {
        await admin.messaging().sendMulticast({
          tokens: fcmTokens,
          notification: {
            title: 'We Miss You! 🎁',
            body: 'We added ₹50 to your Fufaji Wallet. Come back and enjoy fresh groceries today!',
          },
          data: { type: 'wallet_credit' },
        });
      }

      // Log Enterprise Audit Event
      await db.collection('audit_logs').add({
        userId: 'system_automation',
        userName: 'Automation Engine',
        action: 'MARKETING_AUTOMATION',
        description: `Automated Retention sent ₹50 to ${sentCount} dormant users.`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`[Automation] Retention campaign executed for ${sentCount} users.`);
    } catch (error) {
      console.error('[Automation] Error running automated marketing:', error);
    }
  });

// 4. Generate AI Forecasts (Runs daily at 2:00 AM)
export const generateForecasts = functions
  .region('asia-south1')
  .pubsub.schedule('0 2 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    try {
      console.log('[AI Pipeline] Starting AI Forecast Generation');
      const now = new Date();
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(now.getDate() - 30);

      // 1. Fetch recent sales data to aggregate
      const recentOrdersSnap = await db.collection('orders')
        .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
        .get();

      // Aggregate branch metrics
      const branchMetrics: { [branchId: string]: { rev30: number; count30: number } } = {};
      const productDemand: { [branchId: string]: { [productId: string]: number } } = {};

      let totalGlobalRev = 0;
      let totalGlobalCount = 0;

      recentOrdersSnap.forEach(doc => {
        const order = doc.data();
        if (order.status !== 'delivered' && order.status !== 'completed') return;

        const branchId = order.branchId || 'global';
        const amount = order.totalAmount || 0;

        if (!branchMetrics[branchId]) {
          branchMetrics[branchId] = { rev30: 0, count30: 0 };
        }
        if (!productDemand[branchId]) {
          productDemand[branchId] = {};
        }

        branchMetrics[branchId].rev30 += amount;
        branchMetrics[branchId].count30 += 1;

        totalGlobalRev += amount;
        totalGlobalCount += 1;

        // Aggregate product demands
        if (order.items && Array.isArray(order.items)) {
          order.items.forEach((item: any) => {
            const pId = item.productId;
            const qty = item.quantity || 1;
            if (!productDemand[branchId][pId]) productDemand[branchId][pId] = 0;
            productDemand[branchId][pId] += qty;
          });
        }
      });

      const batch = db.batch();

      // 2. Save Business Forecasts
      const writeForecast = (bId: string, rev30: number, count30: number) => {
        // Statistical Mock: 7 days is approx 30 days / 4
        const docRef = db.collection('business_forecasts').doc(bId);
        batch.set(docRef, {
          branchId: bId,
          predictedRevenue30Days: rev30 * 1.1, // assuming 10% growth
          predictedRevenue7Days: (rev30 / 4) * 1.1,
          predictedOrders30Days: Math.ceil(count30 * 1.1),
          predictedOrders7Days: Math.ceil((count30 / 4) * 1.1),
          generatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      };

      // Global forecast
      writeForecast('global', totalGlobalRev, totalGlobalCount);

      // Branch forecasts
      for (const [bId, metrics] of Object.entries(branchMetrics)) {
        writeForecast(bId, metrics.rev30, metrics.count30);

        // 3. Save Product Demand Predictions
        for (const [pId, qty] of Object.entries(productDemand[bId])) {
          const demandRef = db.collection('product_demand_predictions').doc(`${bId}_${pId}`);
          const predictedDemand = Math.ceil(qty * 1.05); // 5% expected growth
          batch.set(demandRef, {
            productId: pId,
            branchId: bId,
            predictedDemand: predictedDemand,
            confidence: 0.85, // Mock confidence score
            generatedAt: admin.firestore.FieldValue.serverTimestamp()
          });

          // Check if this triggers an auto-reorder request
          // (Usually, we'd compare this against current stock in a joined query. For the cron, we let the client service AutoReorderService handle or we can do it here)
        }
      }

      await batch.commit();

      // Log Audit Event
      await db.collection('audit_logs').add({
        userId: 'system_ai',
        userName: 'AI Engine',
        action: 'FORECAST_GENERATION',
        description: `Generated forecasts for ${Object.keys(branchMetrics).length} branches.`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log('[AI Pipeline] Forecast Generation Completed Successfully');
    } catch (error) {
      console.error('[AI Pipeline] Error generating forecasts:', error);
    }
  });

// 5. Generate Branch Health AI Scores (Runs daily at 3:00 AM)
export const generateBranchScores = functions
  .region('asia-south1')
  .pubsub.schedule('0 3 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    try {
      console.log('[AI Pipeline] Starting Branch Score Generation');
      
      const branchesSnap = await db.collection('branches').get();
      const batch = db.batch();

      // For each branch, calculate a mock score based on general rules.
      // In a real production system, this would query orders, inventory accuracy (audit logs), and employees.
      for (const doc of branchesSnap.docs) {
        const branchId = doc.id;
        
        // Mocking the data generation
        const revGrowth = Math.floor(Math.random() * 20) - 5; // -5 to +15
        const ordGrowth = Math.floor(Math.random() * 15) - 3; // -3 to +12
        const invAccuracy = Math.floor(Math.random() * 20) + 80; // 80 to 100
        const custRetention = Math.floor(Math.random() * 30) + 70; // 70 to 100
        const empProductivity = Math.floor(Math.random() * 25) + 75; // 75 to 100
        
        const healthScore = Math.floor((
          (revGrowth > 0 ? 100 : 80) * 0.3 + 
          invAccuracy * 0.2 + 
          custRetention * 0.3 + 
          empProductivity * 0.2
        ));

        const scoreRef = db.collection('branch_ai_scores').doc(branchId);
        batch.set(scoreRef, {
          branchId: branchId,
          healthScore: Math.min(100, healthScore),
          revenueGrowth: revGrowth,
          orderGrowth: ordGrowth,
          inventoryAccuracy: invAccuracy,
          customerRetention: custRetention,
          employeeProductivity: empProductivity,
          generatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      await batch.commit();
      console.log('[AI Pipeline] Branch Score Generation Completed');
    } catch (error) {
      console.error('[AI Pipeline] Error generating branch scores:', error);
    }
  });

// 6. Generate Marketing Campaigns (Runs weekly or daily)
export const generateMarketingCampaigns = functions
  .region('asia-south1')
  .pubsub.schedule('0 4 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    try {
      console.log('[AI Pipeline] Starting Marketing Campaign Generation');
      
      const batch = db.batch();
      const campaignRef = db.collection('marketing_campaigns').doc();
      
      batch.set(campaignRef, {
        title: 'Win Back Dormant Users',
        description: 'Send a ₹50 wallet credit push notification to 120 users who haven\'t ordered in 21 days.',
        targetAudience: 'Dormant Users',
        campaignType: 'Wallet Cashback',
        estimatedCost: 6000,
        expectedRoi: 350,
        estimatedReach: 120,
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      await batch.commit();
      console.log('[AI Pipeline] Marketing Campaign Generated');
    } catch (error) {
      console.error('[AI Pipeline] Error generating marketing campaigns:', error);
    }
  });

// 7. Delivery Intelligence (Runs every hour)
export const generateDeliveryIntelligence = functions
  .region('asia-south1')
  .pubsub.schedule('0 * * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    try {
      console.log('[AI Pipeline] Starting Delivery Intelligence');
      
      const branchesSnap = await db.collection('branches').get();
      const batch = db.batch();

      for (const doc of branchesSnap.docs) {
        const branchId = doc.id;
        
        const riskLevels = ['low', 'medium', 'high', 'critical'];
        const randomRisk = riskLevels[Math.floor(Math.random() * riskLevels.length)];
        
        const intelRef = db.collection('delivery_intelligence').doc(branchId);
        batch.set(intelRef, {
          branchId: branchId,
          expectedDelayRisk: randomRisk,
          bottlenecks: randomRisk === 'high' || randomRisk === 'critical' ? ['Insufficient Riders', 'Traffic at Main Junction'] : [],
          peakWindow: '18:00 - 20:00',
          driverUtilization: Math.floor(Math.random() * 40) + 60, // 60-100%
          generatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      await batch.commit();
      console.log('[AI Pipeline] Delivery Intelligence Generated');
    } catch (error) {
      console.error('[AI Pipeline] Error generating delivery intelligence:', error);
    }
  });

// 8. Automated Payout Requests (Task #53)
//
// Runs weekly (Monday 02:30 Asia/Kolkata). Aggregates unpaid rider delivery
// earnings and unpaid vendor dues from delivered orders into `payout_requests`
// documents with status 'pending'. NOTHING is paid out automatically — per
// the owner-review-and-approval policy (same philosophy as the
// inventory_change_requests flow), an owner must approve each request in
// the Automated Payouts screen before any transfer or ledger entry is made.
//
// To avoid double-counting, every order processed here is stamped with
// `payoutRequestId` pointing at the request it was rolled into. The lookback
// window (21 days) is wider than the weekly cadence so any orders missed by
// a prior run (e.g. delivered late) are still picked up, while the
// `payoutRequestId == null` filter prevents re-processing.
export const generatePayoutRequests = functions
  .region('asia-south1')
  .pubsub.schedule('30 2 * * 1')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    try {
      console.log('[Payouts] Starting automated payout request generation');

      const lookbackStart = new Date();
      lookbackStart.setDate(lookbackStart.getDate() - 21);

      const ordersSnap = await db.collection('orders')
        .where('status', '==', 'delivered')
        .where('deliveredAt', '>=', admin.firestore.Timestamp.fromDate(lookbackStart))
        .get();

      type OrderRef = { id: string; amount: number };
      const riderOrders = new Map<string, OrderRef[]>();
      const shopOrders = new Map<string, OrderRef[]>();
      let earliestDate: admin.firestore.Timestamp | null = null;
      let latestDate: admin.firestore.Timestamp | null = null;

      ordersSnap.forEach((doc) => {
        const data = doc.data();
        if (data.payoutRequestId) return; // already rolled into a request

        const deliveredAt = data.deliveredAt as admin.firestore.Timestamp | undefined;
        if (deliveredAt) {
          if (!earliestDate || deliveredAt.toMillis() < earliestDate.toMillis()) earliestDate = deliveredAt;
          if (!latestDate || deliveredAt.toMillis() > latestDate.toMillis()) latestDate = deliveredAt;
        }

        const riderId = data.deliveryAgentId as string | undefined;
        if (riderId) {
          const deliveryCharge = (data.deliveryCharge as number) > 0 ? data.deliveryCharge : 45;
          const arr = riderOrders.get(riderId) || [];
          arr.push({ id: doc.id, amount: deliveryCharge });
          riderOrders.set(riderId, arr);
        }

        const shopId = data.shopId as string | undefined;
        const totalAmount = (data.totalAmount as number) || 0;
        if (shopId && totalAmount > 0) {
          const arr = shopOrders.get(shopId) || [];
          arr.push({ id: doc.id, amount: totalAmount });
          shopOrders.set(shopId, arr);
        }
      });

      if (riderOrders.size === 0 && shopOrders.size === 0) {
        console.log('[Payouts] No unprocessed delivered orders found — nothing to do');
        return;
      }

      const periodStart = admin.firestore.Timestamp.fromDate(
        earliestDate ? earliestDate.toDate() : lookbackStart,
      );
      const periodEnd = admin.firestore.Timestamp.fromDate(
        latestDate ? latestDate.toDate() : new Date(),
      );

      let batch = db.batch();
      let opCount = 0;
      const commitIfNeeded = async () => {
        if (opCount >= 450) {
          await batch.commit();
          batch = db.batch();
          opCount = 0;
        }
      };

      let riderRequestCount = 0;
      let vendorRequestCount = 0;

      // --- Rider earnings ---
      const RIDER_PAYOUT_MIN = 100; // mirrors RiderPayoutService minimum
      for (const [riderId, orders] of riderOrders.entries()) {
        const amount = orders.reduce((sum, o) => sum + o.amount, 0);
        if (amount < RIDER_PAYOUT_MIN) continue; // too small to action this cycle

        const riderDoc = await db.collection('users').doc(riderId).get();
        const riderName = (riderDoc.exists && (riderDoc.data()?.name as string)) || 'Rider';

        const requestRef = db.collection('payout_requests').doc();
        batch.set(requestRef, {
          type: 'rider',
          recipientId: riderId,
          recipientName: riderName,
          amount,
          currency: 'INR',
          periodStart,
          periodEnd,
          orderIds: orders.map((o) => o.id),
          orderCount: orders.length,
          status: 'pending',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        opCount++;

        for (const o of orders) {
          batch.update(db.collection('orders').doc(o.id), { payoutRequestId: requestRef.id });
          opCount++;
          await commitIfNeeded();
        }
        riderRequestCount++;
        await commitIfNeeded();
      }

      // --- Vendor dues ---
      const VENDOR_PAYOUT_MIN = 100;
      for (const [shopId, orders] of shopOrders.entries()) {
        const shopDoc = await db.collection('shops').doc(shopId).get();
        const shopData = shopDoc.data();
        const shopName = (shopData?.shopName as string) || 'Vendor';
        const commissionPercent = (shopData?.commissionPercent as number) ?? 10;

        const grossAmount = orders.reduce((sum, o) => sum + o.amount, 0);
        const vendorDue = grossAmount * (1 - commissionPercent / 100);
        if (vendorDue < VENDOR_PAYOUT_MIN) continue;

        const requestRef = db.collection('payout_requests').doc();
        batch.set(requestRef, {
          type: 'vendor',
          recipientId: shopId,
          recipientName: shopName,
          amount: Math.round(vendorDue * 100) / 100,
          currency: 'INR',
          periodStart,
          periodEnd,
          orderIds: orders.map((o) => o.id),
          orderCount: orders.length,
          status: 'pending',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          notes: `Commission @ ${commissionPercent}% on gross ₹${grossAmount.toFixed(2)}`,
        });
        opCount++;

        for (const o of orders) {
          batch.update(db.collection('orders').doc(o.id), { payoutRequestId: requestRef.id });
          opCount++;
          await commitIfNeeded();
        }
        vendorRequestCount++;
        await commitIfNeeded();
      }

      if (opCount > 0) {
        await batch.commit();
      }

      await db.collection('audit_logs').add({
        userId: 'system_automation',
        userName: 'Automation Engine',
        action: 'generate_payout_requests',
        description: `Generated ${riderRequestCount} rider and ${vendorRequestCount} vendor payout request(s) pending owner approval`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`[Payouts] Done — ${riderRequestCount} rider request(s), ${vendorRequestCount} vendor request(s)`);
    } catch (error) {
      console.error('[Payouts] Error generating payout requests:', error);
    }
  });
