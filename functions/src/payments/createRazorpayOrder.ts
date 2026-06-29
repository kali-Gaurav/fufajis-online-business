import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import * as https from 'https';

const db = admin.firestore();

/**
 * createRazorpayOrder — Callable Cloud Function
 *
 * Creates a Razorpay order server-side using the Razorpay REST API.
 * The order_id returned MUST be passed to the Flutter Razorpay SDK checkout.
 *
 * Called by: lib/services/razorpay_service.dart → createOrder()
 *
 * Input:
 *   amount: number (INR, full rupees — converted to paise here)
 *   currency: string (default 'INR')
 *   receipt: string (Firestore order ID — stored in notes for webhook reconciliation)
 *   notes: { order_id: string }  ← Firestore order ID for webhook lookup
 *
 * Output:
 *   { success: true, razorpayOrderId: 'order_XXXXXXX', amount: <paise> }
 */
export const createRazorpayOrder = functions.https.onCall(async (data, context) => {
  // Auth check — must be a signed-in customer
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated to create a payment order.');
  }

  const { amount, currency = 'INR', receipt, notes } = data;

  if (!amount || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Amount must be a positive number (INR).');
  }
  if (!receipt) {
    throw new functions.https.HttpsError('invalid-argument', 'receipt (Firestore orderId) is required.');
  }

  const keyId = process.env.RAZORPAY_KEY_ID || functions.config().razorpay?.key_id || '';
  const keySecret = process.env.RAZORPAY_KEY_SECRET || functions.config().razorpay?.key_secret || '';

  if (!keyId || !keySecret) {
    functions.logger.error('[createRazorpayOrder] Razorpay credentials not configured.');
    throw new functions.https.HttpsError('internal', 'Payment gateway not configured. Contact support.');
  }

  const amountPaise = Math.round(amount * 100);

  // ── Idempotency guard ──────────────────────────────────────────────────────
  // If the same Firestore order already has a razorpayOrderId, return it
  // without creating a duplicate. This handles double-tap and UI re-renders.
  try {
    const existingOrder = await db.collection('orders').doc(receipt).get();
    const existingRzpId = existingOrder.data()?.razorpayOrderId;
    if (existingRzpId) {
      functions.logger.info(`[createRazorpayOrder] Idempotency hit — returning existing ${existingRzpId} for ${receipt}`);
      return {
        success: true,
        razorpayOrderId: existingRzpId,
        amount: amountPaise,
        currency,
        receipt,
        idempotent: true,
      };
    }
  } catch (_) { /* order doc may not exist yet — proceed */ }
  // ──────────────────────────────────────────────────────────────────────────

  const orderPayload = JSON.stringify({
    amount: amountPaise,
    currency,
    receipt,
    notes: {
      ...notes,
      firestore_order_id: receipt, // Explicit — used by webhook for reconciliation
      created_by_uid: context.auth.uid,
    },
  });

  // Razorpay Orders API
  const razorpayOrderId = await new Promise<string>((resolve, reject) => {
    const credentials = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
    const options = {
      hostname: 'api.razorpay.com',
      path: '/v1/orders',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${credentials}`,
        'Content-Length': Buffer.byteLength(orderPayload),
      },
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          if (parsed.id) {
            resolve(parsed.id);
          } else {
            functions.logger.error('[createRazorpayOrder] Razorpay API error:', parsed);
            reject(new Error(parsed.error?.description || 'Razorpay order creation failed'));
          }
        } catch (e) {
          reject(new Error('Failed to parse Razorpay response'));
        }
      });
    });

    req.on('error', (e) => reject(e));
    req.write(orderPayload);
    req.end();
  });

  functions.logger.info(`[createRazorpayOrder] Created Razorpay order ${razorpayOrderId} for Firestore order ${receipt}`);

  // Stamp the Firestore order with the Razorpay order ID for webhook lookup
  try {
    await db.collection('orders').doc(receipt).update({
      razorpayOrderId: razorpayOrderId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    functions.logger.warn(`[createRazorpayOrder] Could not stamp razorpayOrderId on order ${receipt}:`, e);
    // Non-fatal — webhook reconciliation can still use notes.firestore_order_id
  }

  return {
    success: true,
    razorpayOrderId,
    amount: amountPaise,
    currency,
    receipt,
  };
});
