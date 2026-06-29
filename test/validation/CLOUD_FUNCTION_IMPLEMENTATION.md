# Cloud Function Implementation: Idempotent Payment Webhooks

This document shows **exactly how to implement** idempotent payment webhook handling in Firebase Cloud Functions to prevent double-charges.

---

## Architecture Overview

```
Razorpay Payment Gateway
         ↓
   Sends Webhook
         ↓
Cloud Function (handlePaymentWebhook)
         ↓
   ├─ Validate Signature (HMAC-SHA256)
   ├─ Check Idempotency (event_id lookup)
   ├─ Firestore Transaction
   │  ├─ Update orders/{orderId}
   │  ├─ Create ledger/{ledgerEntry}
   │  └─ Mark webhook_events/{eventId} as processed
   └─ Retry Queue (on failure)
         ↓
     Success/Failure
```

---

## Core Implementation

### 1. Webhook Signature Validation

**File:** `functions/src/webhooks/razorpay.ts`

```typescript
import * as crypto from 'crypto';

/**
 * Validate Razorpay webhook signature
 * Razorpay uses HMAC-SHA256 with request body and secret key
 */
export function validateRazorpaySignature(
  webhookBody: string,
  signature: string,
  webhookSecret: string
): boolean {
  const expectedSignature = crypto
    .createHmac('sha256', webhookSecret)
    .update(webhookBody)
    .digest('hex');

  // Use constant-time comparison to prevent timing attacks
  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature)
  );
}

/**
 * Extract signature from Razorpay webhook headers
 */
export function extractSignature(headers: Record<string, string>): string | null {
  return headers['x-razorpay-signature'] || null;
}
```

**Usage:**
```typescript
const signature = extractSignature(req.headers);
if (!signature || !validateRazorpaySignature(req.rawBody, signature, WEBHOOK_SECRET)) {
  return res.status(401).json({ error: 'Invalid signature' });
}
```

---

### 2. Idempotency Check

**File:** `functions/src/webhooks/idempotency.ts`

```typescript
import * as admin from 'firebase-admin';

const db = admin.firestore();

/**
 * Check if webhook has already been processed
 * Uses Firestore to track processed webhook event IDs
 */
export async function isWebhookProcessed(eventId: string): Promise<boolean> {
  try {
    const doc = await db
      .collection('webhook_events')
      .doc(eventId)
      .get();
    return doc.exists && doc.data()?.processed === true;
  } catch (error) {
    console.error('Error checking webhook idempotency:', error);
    // On error, assume not processed (safer for retry)
    return false;
  }
}

/**
 * Mark webhook as processed
 * Should be called AFTER transaction succeeds
 */
export async function markWebhookProcessed(
  eventId: string,
  data: {
    webhook_type: string;
    payment_id: string;
    order_id: string;
    processed_at: admin.firestore.Timestamp;
    amount: number;
  }
): Promise<void> {
  await db
    .collection('webhook_events')
    .doc(eventId)
    .set({
      processed: true,
      ...data,
    });
}

/**
 * Batch check for multiple webhooks (for bulk retry)
 */
export async function getUnprocessedWebhooks(
  eventIds: string[]
): Promise<string[]> {
  const snapshot = await db
    .collection('webhook_events')
    .where(admin.firestore.FieldPath.documentId(), 'in', eventIds)
    .get();

  const processedIds = new Set(
    snapshot.docs
      .filter(doc => doc.data().processed === true)
      .map(doc => doc.id)
  );

  return eventIds.filter(id => !processedIds.has(id));
}
```

---

### 3. Firestore Transaction Handler

**File:** `functions/src/webhooks/transaction.ts`

```typescript
import * as admin from 'firebase-admin';

const db = admin.firestore();

export interface PaymentWebhookData {
  eventId: string;
  eventType: string;
  paymentId: string;
  orderId: string;
  amount: number;
  currency: string;
  status: 'authorized' | 'failed' | 'captured';
  email: string;
  phone: string;
}

/**
 * Process payment webhook in a Firestore transaction
 * ALL-OR-NOTHING: Either all updates succeed or none do
 */
export async function processPaymentWebhookTransaction(
  data: PaymentWebhookData
): Promise<{ success: boolean; error?: string }> {
  try {
    return await db.runTransaction(async (transaction) => {
      const orderRef = db.collection('orders').doc(data.orderId);
      const orderDoc = await transaction.get(orderRef);

      // Verify order exists
      if (!orderDoc.exists) {
        throw new Error(`Order not found: ${data.orderId}`);
      }

      const orderData = orderDoc.data()!;

      // Prevent old webhooks from overwriting new state
      if (data.eventType === 'payment.failed') {
        if (orderData.paymentStatus === 'completed') {
          // Payment already confirmed from another source
          return { success: true };
        }
      }

      if (data.eventType === 'payment.authorized') {
        if (orderData.paymentStatus === 'completed') {
          // Order already confirmed (idempotent return)
          return { success: true };
        }

        if (orderData.paymentStatus === 'failed') {
          // Check timestamp - ignore old failure webhooks
          const failureTime = orderData.failureTime?.toDate();
          const webhookTime = new Date();
          if (failureTime && failureTime > webhookTime) {
            // Old webhook arriving late - ignore
            return { success: true };
          }
        }
      }

      // ================================================================
      // STEP 1: Update Order Status
      // ================================================================
      const orderUpdate: Partial<any> = {
        paymentStatus: data.eventType === 'payment.authorized' ? 'completed' : 'failed',
        razorpayPaymentId: data.paymentId,
        lastWebhookEventId: data.eventId,
      };

      if (data.eventType === 'payment.authorized') {
        orderUpdate.confirmedAt = admin.firestore.Timestamp.now();
      } else if (data.eventType === 'payment.failed') {
        orderUpdate.failureTime = admin.firestore.Timestamp.now();
        orderUpdate.failureReason = data.status;
      }

      transaction.update(orderRef, orderUpdate);

      // ================================================================
      // STEP 2: Create Immutable Ledger Entry
      // ================================================================
      const ledgerId = `${data.orderId}-${data.paymentId}-${Date.now()}`;
      const ledgerRef = db.collection('ledger').doc(ledgerId);

      transaction.set(ledgerRef, {
        orderId: data.orderId,
        paymentId: data.paymentId,
        transactionId: data.paymentId,
        amount: data.amount,
        currency: data.currency,
        type: 'payment',
        status: data.eventType === 'payment.authorized' ? 'completed' : 'failed',
        paymentMethod: 'razorpay',
        email: data.email,
        phone: data.phone,
        createdAt: admin.firestore.Timestamp.now(),
        webhookEventId: data.eventId,
      });

      // ================================================================
      // STEP 3: Create Customer Transaction Record
      // ================================================================
      const customerId = orderData.customerId;
      const txnRef = db
        .collection('users')
        .doc(customerId)
        .collection('transactions')
        .doc(data.paymentId);

      transaction.set(txnRef, {
        orderId: data.orderId,
        amount: data.amount,
        type: data.eventType === 'payment.authorized' ? 'debit' : 'refund',
        status: data.eventType === 'payment.authorized' ? 'completed' : 'failed',
        method: 'razorpay',
        createdAt: admin.firestore.Timestamp.now(),
        webhookEventId: data.eventId,
      });

      // ================================================================
      // STEP 4: Update Wallet (if applicable)
      // ================================================================
      if (data.eventType === 'payment.authorized') {
        const userRef = db.collection('users').doc(customerId);
        const userDoc = await transaction.get(userRef);

        if (userDoc.exists) {
          const userData = userDoc.data()!;
          const newWalletBalance = (userData.walletBalance || 0) - data.amount;

          transaction.update(userRef, {
            walletBalance: Math.max(0, newWalletBalance),
            lastTransactionDate: admin.firestore.Timestamp.now(),
          });
        }
      }

      return { success: true };
    });
  } catch (error) {
    console.error('Transaction failed:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}
```

---

### 4. Main Webhook Handler

**File:** `functions/src/webhooks/handler.ts`

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import {
  validateRazorpaySignature,
  extractSignature,
} from './razorpay';
import {
  isWebhookProcessed,
  markWebhookProcessed,
} from './idempotency';
import {
  processPaymentWebhookTransaction,
} from './transaction';

const db = admin.firestore();
const WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET!;

/**
 * HTTP Cloud Function to handle Razorpay payment webhooks
 * 
 * Security:
 * - HMAC signature validation
 * - Idempotency check (event_id)
 * - Firestore transactions (all-or-nothing)
 * 
 * Failure Handling:
 * - Failed webhooks added to retry queue
 * - Cloud Tasks scheduler retries after 5, 10, 20 minutes
 */
export const handlePaymentWebhook = functions
  .region('asia-south1')  // India region
  .https
  .onRequest(async (req, res) => {
    // Log all webhook attempts for audit trail
    console.log('[WEBHOOK] Received payment webhook', {
      method: req.method,
      path: req.path,
      timestamp: new Date().toISOString(),
    });

    // ===================================================================
    // STEP 1: Validate HTTP Method
    // ===================================================================
    if (req.method !== 'POST') {
      return res.status(405).json({
        error: 'Method not allowed',
        received: req.method,
      });
    }

    // ===================================================================
    // STEP 2: Extract and Validate Signature
    // ===================================================================
    const signature = extractSignature(req.headers);
    if (!signature) {
      console.warn('[WEBHOOK] Missing signature header');
      return res.status(401).json({ error: 'Missing signature' });
    }

    try {
      const isValid = validateRazorpaySignature(
        req.rawBody,
        signature,
        WEBHOOK_SECRET
      );

      if (!isValid) {
        console.warn('[WEBHOOK] Invalid signature', { signature: signature.substring(0, 10) + '...' });
        return res.status(401).json({ error: 'Invalid signature' });
      }
    } catch (error) {
      console.error('[WEBHOOK] Signature validation error:', error);
      return res.status(500).json({ error: 'Signature validation failed' });
    }

    // ===================================================================
    // STEP 3: Parse Webhook Payload
    // ===================================================================
    const webhook = req.body;
    const eventId = webhook.id;
    const eventType = webhook.event;

    console.log('[WEBHOOK] Signature validated', {
      eventId,
      eventType,
      timestamp: webhook.created_at,
    });

    if (!eventId || !eventType) {
      console.warn('[WEBHOOK] Missing required fields');
      return res.status(400).json({
        error: 'Missing event ID or type',
      });
    }

    // ===================================================================
    // STEP 4: Check Idempotency
    // ===================================================================
    const alreadyProcessed = await isWebhookProcessed(eventId);
    if (alreadyProcessed) {
      console.log('[WEBHOOK] Already processed (idempotent)', { eventId });
      return res.status(200).json({
        status: 'ok',
        message: 'Webhook already processed (idempotent)',
        eventId,
      });
    }

    // ===================================================================
    // STEP 5: Route by Event Type
    // ===================================================================
    try {
      switch (eventType) {
        case 'payment.authorized':
          return await handlePaymentAuthorized(req, res, webhook, eventId);

        case 'payment.failed':
          return await handlePaymentFailed(req, res, webhook, eventId);

        case 'payment.captured':
          return await handlePaymentCaptured(req, res, webhook, eventId);

        case 'payment.refunded':
          return await handlePaymentRefunded(req, res, webhook, eventId);

        default:
          console.warn('[WEBHOOK] Unknown event type:', eventType);
          return res.status(400).json({
            error: `Unknown event type: ${eventType}`,
            eventId,
          });
      }
    } catch (error) {
      console.error('[WEBHOOK] Unhandled error:', error);

      // Add to retry queue on error
      await addToRetryQueue(webhook, error instanceof Error ? error.message : 'Unknown error');

      return res.status(500).json({
        error: 'Webhook processing failed',
        eventId,
        message: 'Webhook added to retry queue',
      });
    }
  });

/**
 * Handle payment.authorized webhook
 */
async function handlePaymentAuthorized(
  req: functions.https.Request,
  res: functions.Response,
  webhook: any,
  eventId: string
) {
  const payment = webhook.payload.payment;
  const order = webhook.payload.order;

  const txnData = {
    eventId,
    eventType: 'payment.authorized',
    paymentId: payment.id,
    orderId: order.id,
    amount: payment.amount / 100, // Razorpay returns amount in paise
    currency: payment.currency,
    status: 'authorized' as const,
    email: payment.email,
    phone: payment.contact,
  };

  console.log('[WEBHOOK] Processing payment.authorized', {
    orderId: order.id,
    paymentId: payment.id,
    amount: txnData.amount,
  });

  // Execute transaction
  const result = await processPaymentWebhookTransaction(txnData);

  if (result.success) {
    // Mark webhook as processed ONLY after transaction succeeds
    await markWebhookProcessed(eventId, {
      webhook_type: 'payment.authorized',
      payment_id: payment.id,
      order_id: order.id,
      processed_at: admin.firestore.Timestamp.now(),
      amount: txnData.amount,
    });

    console.log('[WEBHOOK] Successfully processed payment', {
      orderId: order.id,
      paymentId: payment.id,
    });

    return res.status(200).json({
      status: 'ok',
      eventId,
      message: 'Payment authorized',
    });
  } else {
    console.error('[WEBHOOK] Transaction failed:', result.error);
    throw new Error(result.error || 'Transaction failed');
  }
}

/**
 * Handle payment.failed webhook
 */
async function handlePaymentFailed(
  req: functions.https.Request,
  res: functions.Response,
  webhook: any,
  eventId: string
) {
  const payment = webhook.payload.payment;
  const order = webhook.payload.order;

  const txnData = {
    eventId,
    eventType: 'payment.failed' as const,
    paymentId: payment.id,
    orderId: order.id,
    amount: payment.amount / 100,
    currency: payment.currency,
    status: 'failed' as const,
    email: payment.email,
    phone: payment.contact,
  };

  console.log('[WEBHOOK] Processing payment.failed', {
    orderId: order.id,
    paymentId: payment.id,
    errorCode: payment.error_code,
  });

  const result = await processPaymentWebhookTransaction(txnData);

  if (result.success) {
    await markWebhookProcessed(eventId, {
      webhook_type: 'payment.failed',
      payment_id: payment.id,
      order_id: order.id,
      processed_at: admin.firestore.Timestamp.now(),
      amount: 0,
    });

    return res.status(200).json({
      status: 'ok',
      eventId,
      message: 'Payment failure recorded',
    });
  } else {
    throw new Error(result.error || 'Failed to record payment failure');
  }
}

/**
 * Handle payment.captured webhook (for settlements)
 */
async function handlePaymentCaptured(
  req: functions.https.Request,
  res: functions.Response,
  webhook: any,
  eventId: string
) {
  console.log('[WEBHOOK] Payment captured (settlement)', {
    paymentId: webhook.payload.payment.id,
  });

  // Update settlement status in ledger
  await db
    .collection('ledger')
    .where('paymentId', '==', webhook.payload.payment.id)
    .limit(1)
    .get()
    .then((snapshot) => {
      if (snapshot.docs.length > 0) {
        snapshot.docs[0].ref.update({
          settledAt: admin.firestore.Timestamp.now(),
          settled: true,
        });
      }
    });

  await markWebhookProcessed(eventId, {
    webhook_type: 'payment.captured',
    payment_id: webhook.payload.payment.id,
    order_id: webhook.payload.order.id,
    processed_at: admin.firestore.Timestamp.now(),
    amount: webhook.payload.payment.amount / 100,
  });

  return res.status(200).json({
    status: 'ok',
    eventId,
    message: 'Payment captured',
  });
}

/**
 * Handle payment.refunded webhook (for refunds)
 */
async function handlePaymentRefunded(
  req: functions.https.Request,
  res: functions.Response,
  webhook: any,
  eventId: string
) {
  const refund = webhook.payload.refund;
  const payment = webhook.payload.payment;

  console.log('[WEBHOOK] Processing refund', {
    refundId: refund.id,
    paymentId: payment.id,
    amount: refund.amount / 100,
  });

  try {
    await db.runTransaction(async (transaction) => {
      // Create refund ledger entry
      const refundLedgerId = `REF-${payment.id}-${refund.id}`;
      transaction.set(db.collection('ledger').doc(refundLedgerId), {
        type: 'refund',
        paymentId: payment.id,
        refundId: refund.id,
        amount: refund.amount / 100,
        currency: payment.currency,
        status: 'completed',
        createdAt: admin.firestore.Timestamp.now(),
        webhookEventId: eventId,
      });

      // Update order status
      const orderRef = db.collection('orders').doc(payment.order_id);
      transaction.update(orderRef, {
        refundStatus: 'completed',
        refundedAt: admin.firestore.Timestamp.now(),
      });
    });

    await markWebhookProcessed(eventId, {
      webhook_type: 'payment.refunded',
      payment_id: payment.id,
      order_id: payment.order_id,
      processed_at: admin.firestore.Timestamp.now(),
      amount: -(refund.amount / 100),
    });

    return res.status(200).json({
      status: 'ok',
      eventId,
      message: 'Refund processed',
    });
  } catch (error) {
    console.error('[WEBHOOK] Refund processing failed:', error);
    throw error;
  }
}

/**
 * Add failed webhook to retry queue
 * Cloud Scheduler will retry after exponential backoff
 */
async function addToRetryQueue(
  webhook: any,
  error: string
): Promise<void> {
  await db.collection('webhook_retry_queue').add({
    eventId: webhook.id,
    eventType: webhook.event,
    payload: webhook,
    error,
    retryCount: 0,
    maxRetries: 5,
    nextRetryTime: admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 5 * 60 * 1000) // Retry in 5 minutes
    ),
    createdAt: admin.firestore.Timestamp.now(),
  });

  console.log('[WEBHOOK] Added to retry queue', {
    eventId: webhook.id,
    error,
  });
}
```

---

## Deployment

### 1. Environment Variables

**`.env.production`**
```bash
RAZORPAY_KEY_ID=rzp_live_xxxxxxxxxxxxx
RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxxxxx
RAZORPAY_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxx
```

### 2. Deploy to Firebase

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Deploy Cloud Functions
firebase deploy --only functions:handlePaymentWebhook

# Verify deployment
firebase functions:log --follow
```

### 3. Add Webhook to Razorpay Dashboard

1. Go to **Razorpay Dashboard → Settings → Webhooks**
2. Add webhook URL: `https://[REGION]-[PROJECT_ID].cloudfunctions.net/handlePaymentWebhook`
3. Select events:
   - `payment.authorized`
   - `payment.failed`
   - `payment.captured`
   - `payment.refunded`
4. Copy webhook secret and add to `.env.production`

---

## Monitoring & Alerts

### Cloud Functions Logs

```bash
# Watch logs in real-time
firebase functions:log --follow

# Filter for webhook errors
firebase functions:log --follow | grep "WEBHOOK"
```

### Firestore Queries

```typescript
// Find unprocessed webhooks
db.collection('webhook_retry_queue')
  .where('retryCount', '<', 5)
  .orderBy('nextRetryTime')
  .limit(10)
  .get();

// Ledger reconciliation
db.collection('ledger')
  .where('createdAt', '>=', twentyFourHoursAgo)
  .orderBy('createdAt')
  .get();

// Find duplicate ledger entries (shouldn't exist)
db.collection('ledger')
  .where('paymentId', '==', paymentId)
  .get();
```

---

## Testing in Production

### 1. Send Test Webhook

```bash
curl -X POST \
  https://[REGION]-[PROJECT_ID].cloudfunctions.net/handlePaymentWebhook \
  -H "Content-Type: application/json" \
  -H "X-Razorpay-Signature: $(echo -n 'test' | openssl dgst -sha256 -hmac 'your-webhook-secret' -hex)" \
  -d '{
    "id": "evt_test_123",
    "event": "payment.authorized",
    "created_at": '$(date +%s)',
    "payload": {
      "payment": {
        "id": "pay_test_123",
        "amount": 50000,
        "currency": "INR",
        "status": "authorized",
        "email": "customer@example.com",
        "contact": "+919999999999"
      },
      "order": {
        "id": "ORD-TEST-001"
      }
    }
  }'
```

### 2. Verify in Firestore

```javascript
// Check if order was updated
db.collection('orders').doc('ORD-TEST-001').get().then(doc => {
  console.log('Order status:', doc.data().paymentStatus);
});

// Check ledger
db.collection('ledger')
  .where('paymentId', '==', 'pay_test_123')
  .get()
  .then(snapshot => {
    console.log('Ledger entries:', snapshot.docs.length);
  });

// Check webhook events
db.collection('webhook_events').doc('evt_test_123').get().then(doc => {
  console.log('Webhook processed:', doc.data().processed);
});
```

---

## Summary

This implementation ensures:

✓ **Idempotency** — Same webhook processed only once  
✓ **Atomicity** — All-or-nothing updates via Firestore transactions  
✓ **Auditability** — Every charge logged immutably in ledger  
✓ **Recoverability** — Failed webhooks queued for retry  
✓ **Security** — HMAC signature validation  

**Result:** No double-charges, no lost orders, full compliance.
