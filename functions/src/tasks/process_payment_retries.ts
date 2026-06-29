import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import axios, { AxiosError } from 'axios';

const db = admin.firestore();

/**
 * PAYMENT RETRY PROCESSOR
 *
 * Cloud Task: Runs every 5 minutes
 *
 * Responsibilities:
 * 1. Query Firestore for failed payments awaiting retry
 * 2. Attempt Razorpay payment again with exponential backoff
 * 3. Update retry count and next retry timestamp
 * 4. If all retries exhausted: fall back to wallet deduction
 * 5. Log all retry attempts to audit collection
 *
 * Retry Logic:
 * - Max retries: 3
 * - Backoff: 5 min → 10 min → 20 min
 * - On all retries failed: Deduct from customer wallet
 * - Update order status based on outcome
 *
 * Failure Handling:
 * - Network errors: Schedule next retry
 * - Invalid payment ID: Mark as unrecoverable
 * - Wallet deduction failure: Alert admin
 */

interface PaymentRetryEntry {
  id: string;
  paymentId: string;
  orderId: string;
  amount: number;
  status: string;
  error: string;
  retryCount: number;
  maxRetries: number;
  nextRetryAt: admin.firestore.Timestamp;
  createdAt: admin.firestore.Timestamp;
  lastRetryAt?: admin.firestore.Timestamp;
  fallbackToWallet: boolean;
  notes?: string;
}

interface RetryAuditLog {
  id: string;
  retryEntryId: string;
  paymentId: string;
  orderId: string;
  retryAttempt: number;
  status: 'pending' | 'success' | 'failed' | 'wallet_deduction' | 'exhausted';
  previousError: string;
  newError?: string;
  amount: number;
  attemptedAt: admin.firestore.Timestamp;
  nextRetryAt?: admin.firestore.Timestamp;
  reason?: string;
}

// Razorpay configuration
const RAZORPAY_API_KEY = process.env.RAZORPAY_API_KEY || '';
const RAZORPAY_API_SECRET = process.env.RAZORPAY_API_SECRET || '';
const RAZORPAY_API_BASE = 'https://api.razorpay.com/v1';

// Retry configuration
const RETRY_CONFIG = {
  maxRetries: 3,
  backoffDelays: [
    5 * 60 * 1000,   // 5 minutes
    10 * 60 * 1000,  // 10 minutes
    20 * 60 * 1000,  // 20 minutes
  ],
};

/**
 * Calculate next retry timestamp based on retry count
 */
function getNextRetryTimestamp(retryCount: number): admin.firestore.Timestamp {
  const delayMs = RETRY_CONFIG.backoffDelays[retryCount] || RETRY_CONFIG.backoffDelays[RETRY_CONFIG.maxRetries - 1];
  return admin.firestore.Timestamp.fromMillis(Date.now() + delayMs);
}

/**
 * Fetch payment details from Razorpay API
 */
async function fetchPaymentFromRazorpay(paymentId: string): Promise<any> {
  try {
    const auth = Buffer.from(`${RAZORPAY_API_KEY}:${RAZORPAY_API_SECRET}`).toString('base64');

    const response = await axios.get(`${RAZORPAY_API_BASE}/payments/${paymentId}`, {
      headers: {
        Authorization: `Basic ${auth}`,
      },
      timeout: 10000,
    });

    return response.data;
  } catch (error: any) {
    if (axios.isAxiosError(error)) {
      const axiosError = error as AxiosError<any>;
      throw new Error(
        `Razorpay API error: ${axiosError.response?.status} - ${axiosError.response?.data?.error?.description || axiosError.message}`
      );
    }
    throw error;
  }
}

/**
 * Capture a payment that was previously authorized
 */
async function capturePayment(
  paymentId: string,
  amount: number
): Promise<{ success: boolean; message: string; capturedAmount?: number }> {
  try {
    const auth = Buffer.from(`${RAZORPAY_API_KEY}:${RAZORPAY_API_SECRET}`).toString('base64');

    // First, fetch the payment to check status
    const payment = await fetchPaymentFromRazorpay(paymentId);

    if (payment.status === 'captured') {
      return {
        success: true,
        message: 'Payment already captured',
        capturedAmount: payment.amount,
      };
    }

    if (payment.status === 'failed') {
      throw new Error(`Payment failed: ${payment.error_code}`);
    }

    if (payment.status !== 'authorized') {
      throw new Error(`Cannot capture payment with status: ${payment.status}`);
    }

    // Capture the authorized payment
    const response = await axios.post(
      `${RAZORPAY_API_BASE}/payments/${paymentId}/capture`,
      { amount: Math.round(amount * 100) }, // Razorpay uses paise
      {
        headers: {
          Authorization: `Basic ${auth}`,
          'Content-Type': 'application/json',
        },
        timeout: 10000,
      }
    );

    return {
      success: true,
      message: 'Payment captured successfully',
      capturedAmount: response.data.amount / 100, // Convert back to rupees
    };
  } catch (error: any) {
    return {
      success: false,
      message: error.message || 'Failed to capture payment',
    };
  }
}

/**
 * Deduct from customer wallet as fallback
 */
async function deductFromWallet(
  customerId: string,
  orderId: string,
  amount: number,
  reason: string
): Promise<{ success: boolean; message: string; newBalance?: number }> {
  try {
    return await db.runTransaction(async (transaction) => {
      const userRef = db.collection('users').doc(customerId);
      const userSnapshot = await transaction.get(userRef);

      if (!userSnapshot.exists) {
        return {
          success: false,
          message: `Customer ${customerId} not found`,
        };
      }

      const userData = userSnapshot.data()!;
      const currentBalance = (userData.walletBalance || 0) as number;

      // Check if sufficient balance
      if (currentBalance < amount) {
        return {
          success: false,
          message: `Insufficient wallet balance. Required: ${amount}, Available: ${currentBalance}`,
        };
      }

      const newBalance = currentBalance - amount;

      // Update wallet
      transaction.update(userRef, {
        walletBalance: newBalance,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Create wallet transaction record
      const txnRef = db
        .collection('users')
        .doc(customerId)
        .collection('wallet_transactions')
        .doc();

      transaction.set(txnRef, {
        id: txnRef.id,
        userId: customerId,
        type: 'payment_fallback',
        amount,
        orderReference: orderId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        description: `Payment fallback deduction for order #${orderId}`,
        balanceAfter: newBalance,
        reason,
      });

      // Update order to mark payment resolved
      const orderRef = db.collection('orders').doc(orderId);
      transaction.update(orderRef, {
        paymentMethod: 'wallet_fallback',
        paymentConfirmed: true,
        paymentConfirmedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'confirmed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      functions.logger.info(
        `[process_payment_retries] Deducted ${amount} from wallet for customer ${customerId}`
      );

      return {
        success: true,
        message: 'Deducted from wallet successfully',
        newBalance,
      };
    });
  } catch (error: any) {
    functions.logger.error('[process_payment_retries] Wallet deduction error:', error);
    return {
      success: false,
      message: error.message || 'Failed to deduct from wallet',
    };
  }
}

/**
 * Log retry attempt to audit collection
 */
async function logRetryAttempt(
  retryEntryId: string,
  paymentId: string,
  orderId: string,
  retryAttempt: number,
  status: string,
  previousError: string,
  newError?: string,
  amount?: number,
  nextRetryAt?: admin.firestore.Timestamp
): Promise<void> {
  const auditRef = db.collection('payment_retry_audit').doc();

  const auditLog: RetryAuditLog = {
    id: auditRef.id,
    retryEntryId,
    paymentId,
    orderId,
    retryAttempt,
    status: status as any,
    previousError,
    newError,
    amount: amount || 0,
    attemptedAt: admin.firestore.Timestamp.now(),
    nextRetryAt,
  };

  await auditRef.set(auditLog);
}

/**
 * Process a single retry entry
 */
async function processRetryEntry(retryEntry: PaymentRetryEntry & { docId: string }): Promise<void> {
  const {
    docId,
    id,
    paymentId,
    orderId,
    amount,
    retryCount,
    maxRetries,
    error: previousError,
  } = retryEntry;

  try {
    functions.logger.info(
      `[process_payment_retries] Processing retry #${retryCount + 1}/${maxRetries} for payment ${paymentId}`
    );

    // If retries exhausted, fallback to wallet
    if (retryCount >= maxRetries) {
      functions.logger.warn(
        `[process_payment_retries] All retries exhausted for payment ${paymentId}. Attempting wallet deduction.`
      );

      // Get customer ID from order
      const orderSnapshot = await db.collection('orders').doc(orderId).get();
      if (!orderSnapshot.exists) {
        throw new Error(`Order ${orderId} not found`);
      }

      const customerId = orderSnapshot.data()!.customerId;

      // Attempt wallet deduction
      const walletResult = await deductFromWallet(
        customerId,
        orderId,
        amount,
        `Fallback payment after ${maxRetries} failed Razorpay retry attempts`
      );

      if (walletResult.success) {
        // Mark retry entry as completed
        await db.collection('payment_retry_queue').doc(docId).update({
          status: 'completed',
          fallbackToWallet: true,
          notes: 'Payment resolved via wallet deduction',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await logRetryAttempt(
          id,
          paymentId,
          orderId,
          retryCount + 1,
          'wallet_deduction',
          previousError,
          undefined,
          amount
        );

        functions.logger.info(
          `[process_payment_retries] Payment ${paymentId} resolved via wallet deduction`
        );
      } else {
        // Wallet deduction failed - mark for manual review
        await db.collection('payment_retry_queue').doc(docId).update({
          status: 'failed',
          notes: `Wallet deduction failed: ${walletResult.message}`,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await logRetryAttempt(
          id,
          paymentId,
          orderId,
          retryCount + 1,
          'exhausted',
          previousError,
          walletResult.message,
          amount
        );

        // Alert admin - payment unresolved
        functions.logger.error(
          `[process_payment_retries] ALERT: Payment ${paymentId} for order ${orderId} could not be resolved. Manual review required.`
        );
      }

      return;
    }

    // Try to capture or refetch payment
    const captureResult = await capturePayment(paymentId, amount);

    if (captureResult.success) {
      // Payment successful - mark retry entry as completed
      await db.collection('payment_retry_queue').doc(docId).update({
        status: 'completed',
        notes: 'Payment captured successfully on retry',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update order status
      await db.collection('orders').doc(orderId).update({
        paymentStatus: 'captured',
        paymentConfirmed: true,
        paymentConfirmedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'confirmed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await logRetryAttempt(
        id,
        paymentId,
        orderId,
        retryCount + 1,
        'success',
        previousError,
        undefined,
        amount
      );

      functions.logger.info(
        `[process_payment_retries] Payment ${paymentId} captured successfully on retry`
      );
    } else {
      // Payment still failed - schedule next retry
      const nextRetryAt = getNextRetryTimestamp(retryCount + 1);

      await db.collection('payment_retry_queue').doc(docId).update({
        retryCount: retryCount + 1,
        lastRetryAt: admin.firestore.FieldValue.serverTimestamp(),
        nextRetryAt,
        error: captureResult.message,
        notes: `Retry attempt #${retryCount + 1} failed. Next retry at ${nextRetryAt.toDate()}`,
      });

      await logRetryAttempt(
        id,
        paymentId,
        orderId,
        retryCount + 1,
        'failed',
        previousError,
        captureResult.message,
        amount,
        nextRetryAt
      );

      functions.logger.info(
        `[process_payment_retries] Payment ${paymentId} retry #${retryCount + 1} failed. Scheduled next retry.`
      );
    }
  } catch (error: any) {
    functions.logger.error(
      `[process_payment_retries] Error processing retry for payment ${paymentId}:`,
      error
    );

    // Mark for manual review
    await db.collection('payment_retry_queue').doc(docId).update({
      status: 'error',
      notes: `Unexpected error: ${error.message}`,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await logRetryAttempt(
      id,
      paymentId,
      orderId,
      retryCount + 1,
      'failed',
      previousError,
      error.message,
      amount
    );
  }
}

/**
 * Cloud Task: Process payment retries
 * Runs every 5 minutes via Cloud Scheduler
 */
export const processPaymentRetries = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    functions.logger.info('[process_payment_retries] Starting payment retry processor');

    try {
      // Query for pending retries that are ready to process
      const retryQueue = await db
        .collection('payment_retry_queue')
        .where('status', '==', 'pending')
        .where('nextRetryAt', '<=', admin.firestore.Timestamp.now())
        .limit(50) // Process up to 50 at a time
        .get();

      functions.logger.info(
        `[process_payment_retries] Found ${retryQueue.size} pending retries to process`
      );

      if (retryQueue.empty) {
        functions.logger.info('[process_payment_retries] No pending retries to process');
        return { success: true, processed: 0 };
      }

      // Process each retry entry
      const processedCount = 0;
      const errors: string[] = [];

      for (const doc of retryQueue.docs) {
        try {
          const retryEntry = doc.data() as PaymentRetryEntry;
          await processRetryEntry({ ...retryEntry, docId: doc.id });
        } catch (error: any) {
          const errorMsg = `Error processing retry entry ${doc.id}: ${error.message}`;
          functions.logger.error(`[process_payment_retries] ${errorMsg}`);
          errors.push(errorMsg);
        }
      }

      functions.logger.info(
        `[process_payment_retries] Completed processing. Errors: ${errors.length}`
      );

      return {
        success: true,
        processed: retryQueue.size,
        errors: errors.length > 0 ? errors : undefined,
      };
    } catch (error: any) {
      functions.logger.error('[process_payment_retries] Fatal error:', error);
      return {
        success: false,
        error: error.message,
      };
    }
  });
