import * as functions from 'firebase-functions';
import * as crypto from 'crypto';
import * as admin from 'firebase-admin';

const db = admin.firestore();

/**
 * verifyRazorpayPayment — Callable Cloud Function
 *
 * Server-side HMAC-SHA256 signature verification for Razorpay payment responses.
 * The Flutter SDK calls this immediately after the user completes payment.
 *
 * Called by: lib/services/razorpay_service.dart → _verifyAndUpdateOrder()
 *
 * Input:
 *   paymentId:  string  (PaymentSuccessResponse.paymentId)
 *   orderId:    string  (PaymentSuccessResponse.orderId — Razorpay order_id)
 *   signature:  string  (PaymentSuccessResponse.signature)
 *   firestoreOrderId: string  (optional — the Firestore order doc ID for immediate update)
 *
 * Output:
 *   { success: true } on valid signature
 *   throws HttpsError on invalid signature or missing credentials
 *
 * HMAC formula (per Razorpay docs):
 *   HMAC-SHA256( razorpay_order_id + '|' + razorpay_payment_id, key_secret )
 */
export const verifyRazorpayPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
  }

  const { paymentId, orderId, signature, firestoreOrderId } = data;

  if (!paymentId || !orderId || !signature) {
    throw new functions.https.HttpsError('invalid-argument', 'paymentId, orderId, and signature are required.');
  }

  const keySecret = process.env.RAZORPAY_KEY_SECRET || functions.config().razorpay?.key_secret || '';
  if (!keySecret) {
    functions.logger.error('[verifyRazorpayPayment] RAZORPAY_KEY_SECRET not configured.');
    throw new functions.https.HttpsError('internal', 'Payment verification not configured.');
  }

  // Razorpay HMAC formula: orderId + '|' + paymentId
  const body = `${orderId}|${paymentId}`;
  const expectedSignature = crypto
    .createHmac('sha256', keySecret)
    .update(body)
    .digest('hex');

  const isValid = crypto.timingSafeEqual(
    Buffer.from(expectedSignature, 'hex'),
    Buffer.from(signature, 'hex')
  );

  functions.logger.info(
    `[verifyRazorpayPayment] Payment ${paymentId}: signature ${isValid ? 'VALID ✅' : 'INVALID ❌'}`
  );

  if (!isValid) {
    // Log the tamper attempt
    await db.collection('security_events').add({
      type: 'payment_signature_tamper',
      paymentId,
      orderId,
      uid: context.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    }).catch(() => null);

    throw new functions.https.HttpsError('permission-denied', 'Payment signature verification failed.');
  }

  // Immediately update Firestore order on valid signature
  // This is the fast path — webhook is the authoritative path but this is faster
  const fOrderId = firestoreOrderId || null;
  if (fOrderId) {
    try {
      await db.collection('orders').doc(fOrderId).update({
        paymentStatus: 'paid',
        paymentId: paymentId,
        razorpayPaymentId: paymentId,
        razorpayOrderId: orderId,
        status: 'OrderStatus.confirmed',
        paymentVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      functions.logger.info(`[verifyRazorpayPayment] Firestore order ${fOrderId} marked paid ✅`);
    } catch (e) {
      functions.logger.warn(`[verifyRazorpayPayment] Could not update order ${fOrderId}:`, e);
      // Non-fatal — webhook will reconcile
    }

    // Write to payments ledger
    try {
      await db.collection('payments').doc(paymentId).set({
        paymentId,
        razorpayOrderId: orderId,
        firestoreOrderId: fOrderId,
        status: 'captured',
        verified: true,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        verifiedBy: 'client_verification',
        uid: context.auth.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    } catch (e) {
      functions.logger.warn('[verifyRazorpayPayment] Could not write payment ledger:', e);
    }
  }

  return { success: true, verified: true };
});
