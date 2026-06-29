import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

const db = admin.firestore();

/**
 * processCashbackTrigger — Firestore onCreate Cloud Function
 *
 * Triggered when OrderProvider.verifyAndDeliverOrder() writes a document to
 * cashback_triggers/{orderId} after delivery confirmation.
 *
 * Awards cashback to the customer's wallet. Idempotent — checks
 * cashbackStatus before crediting to prevent double-credits.
 *
 * Cashback schedule (anti-abuse: only on confirmed delivery):
 *   COD:    2% of order total (minimum ₹5, maximum ₹50)
 *   Online: 1% of order total (minimum ₹2, maximum ₹30)
 *   Wallet: 1.5% of order total (minimum ₹3, maximum ₹40)
 */
export const processCashbackTrigger = functions.firestore
  .document('cashback_triggers/{orderId}')
  .onCreate(async (snap, context) => {
    const orderId = context.params.orderId;
    const data = snap.data();

    if (!data) {
      functions.logger.warn(`[processCashbackTrigger] No data for ${orderId}`);
      return;
    }

    // Idempotency: only process if still pending
    if (data.cashbackStatus !== 'pending') {
      functions.logger.info(`[processCashbackTrigger] Skipping ${orderId} — status: ${data.cashbackStatus}`);
      return;
    }

    const { customerId, orderTotal = 0, paymentMethod = '' } = data;

    if (!customerId || orderTotal <= 0) {
      functions.logger.error(`[processCashbackTrigger] Invalid data for ${orderId}`, data);
      await snap.ref.update({ cashbackStatus: 'error', errorReason: 'missing customerId or orderTotal' });
      return;
    }

    // Determine cashback rate based on payment method
    let rate = 0.01;
    let minCashback = 2;
    let maxCashback = 30;

    const method = String(paymentMethod).toLowerCase();
    if (method.includes('cod')) {
      rate = 0.02; minCashback = 5; maxCashback = 50;
    } else if (method.includes('wallet')) {
      rate = 0.015; minCashback = 3; maxCashback = 40;
    }

    const rawCashback = orderTotal * rate;
    const cashbackAmount = Math.min(Math.max(rawCashback, minCashback), maxCashback);
    const cashbackRounded = Math.round(cashbackAmount * 100) / 100;

    try {
      // Atomic: credit wallet + mark trigger processed
      await db.runTransaction(async (txn) => {
        const userRef = db.collection('users').doc(customerId);
        const triggerRef = snap.ref;

        const userDoc = await txn.get(userRef);
        if (!userDoc.exists) throw new Error(`User ${customerId} not found`);

        const currentBalance = (userDoc.data()?.walletBalance ?? 0) as number;

        // Re-read trigger inside txn to ensure idempotency under concurrent triggers
        const triggerDoc = await txn.get(triggerRef);
        if (triggerDoc.data()?.cashbackStatus !== 'pending') {
          throw new Error('Already processed');
        }

        txn.update(userRef, {
          walletBalance: currentBalance + cashbackRounded,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        txn.update(triggerRef, {
          cashbackStatus: 'credited',
          cashbackAmount: cashbackRounded,
          creditedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Write wallet transaction record
        const txRef = db.collection('users').doc(customerId)
          .collection('wallet_transactions').doc(`cashback_${orderId}`);
        txn.set(txRef, {
          type: 'cashback',
          amount: cashbackRounded,
          orderId,
          description: `Delivery cashback for order #${orderId}`,
          balanceBefore: currentBalance,
          balanceAfter: currentBalance + cashbackRounded,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      functions.logger.info(
        `[processCashbackTrigger] ✅ Credited ₹${cashbackRounded} cashback to ${customerId} for order ${orderId}`
      );
    } catch (e: any) {
      if (e.message === 'Already processed') {
        functions.logger.info(`[processCashbackTrigger] Already processed for ${orderId}`);
        return;
      }
      functions.logger.error(`[processCashbackTrigger] Failed for ${orderId}:`, e);
      await snap.ref.update({
        cashbackStatus: 'error',
        errorReason: e.message,
        lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      }).catch(() => null);
    }
  });
