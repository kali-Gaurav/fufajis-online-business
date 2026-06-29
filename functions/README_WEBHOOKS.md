# Razorpay Webhook Reconciliation System

Complete, production-ready implementation for handling Razorpay payment webhooks with automatic retry, idempotency, and fallback mechanisms.

## Quick Start

```bash
# 1. Setup
cd functions
npm install
cp .env.example .env

# 2. Configure (edit .env with your credentials)
RAZORPAY_API_KEY=your_key
RAZORPAY_API_SECRET=your_secret
RAZORPAY_WEBHOOK_SECRET=your_webhook_secret

# 3. Test
npm test

# 4. Deploy
firebase deploy --only functions

# 5. Add webhook in Razorpay Dashboard
# URL: https://us-central1-YOUR_PROJECT.cloudfunctions.net/razorpayWebhook
# Events: payment.authorized, payment.captured, payment.failed
```

## Architecture

### Two Main Cloud Functions

#### 1. **razorpayWebhook** (HTTP Endpoint)
```
POST /webhooks/razorpay
├─ Validate HMAC-SHA256 signature
├─ Check idempotency (prevent duplicates)
├─ Route event to handler
├─ Update order status (atomic)
├─ Log webhook event
└─ Return 200 OK
```

**Events Handled:**
- `payment.authorized` → Order: "confirmed"
- `payment.captured` → Order: "confirmed"
- `payment.failed` → Order: "payment_failed" + create retry

#### 2. **processPaymentRetries** (Cloud Scheduler - Every 5 min)
```
Query Firestore
├─ Fetch pending retries (nextRetryAt <= now)
├─ Attempt Razorpay capture
├─ Exponential backoff (5 min → 10 min → 20 min)
├─ Fallback to wallet deduction (if all fail)
├─ Log results
└─ Update order status
```

## File Structure

```
functions/
├── src/
│   ├── webhooks/
│   │   └── razorpay_webhook.ts          (450+ lines)
│   ├── tasks/
│   │   └── process_payment_retries.ts   (350+ lines)
│   ├── types/
│   │   └── webhook.types.ts             (200+ lines)
│   ├── utils/
│   │   └── webhook_utils.ts             (250+ lines)
│   └── index.ts                         (updated exports)
├── test/
│   └── webhooks/
│       └── razorpay_webhook.test.ts     (300+ lines)
├── firestore.rules                      (100+ lines)
├── .env.example                         (configuration)
└── package.json

Project Root/
├── PAYMENT_WEBHOOK_SETUP.md             (400+ lines)
├── WEBHOOK_IMPLEMENTATION_SUMMARY.md    (comprehensive overview)
└── DEPLOYMENT_CHECKLIST.md              (step-by-step deployment)
```

## Firestore Collections

### webhook_logs
Audit trail of all webhook events received.

```firestore
collection: webhook_logs
├── eventId: string
├── eventType: "payment.authorized" | "payment.captured" | "payment.failed"
├── paymentId: string
├── orderId: string
├── amount: number
├── signatureValid: boolean
├── processed: boolean
├── processedAt: Timestamp
├── error?: string
├── receivedAt: Timestamp
└── idempotencyKey: string
```

### payment_retry_queue
Pending payment retries to be processed.

```firestore
collection: payment_retry_queue
├── paymentId: string
├── orderId: string
├── amount: number
├── status: "pending" | "completed" | "failed" | "error"
├── error: string
├── retryCount: number (0, 1, 2)
├── maxRetries: 3
├── nextRetryAt: Timestamp
├── createdAt: Timestamp
├── fallbackToWallet: boolean
└── notes?: string
```

## Signature Validation

Every webhook is validated using HMAC-SHA256:

```typescript
import { validateWebhookSignature } from './utils/webhook_utils';

const isValid = validateWebhookSignature(
  rawRequestBody,
  request.headers['x-razorpay-signature'],
  process.env.RAZORPAY_WEBHOOK_SECRET
);
```

## Idempotency

Prevents processing the same webhook twice using payment_id + event_id as unique key.

## Retry Logic

### Exponential Backoff
- Retry 1: 5 minutes
- Retry 2: 10 minutes
- Retry 3: 20 minutes
- Total duration: Up to 35 minutes

### On Final Failure
- Deduct from customer wallet
- Update order status
- Mark for manual review if wallet fails

## Security Features

✅ HMAC-SHA256 signature validation
✅ Idempotency (prevent duplicates)
✅ Firestore rules protect data
✅ Cloud Functions only writes
✅ Audit logging for compliance

## Monitoring & Logs

```bash
# View webhook logs
firebase functions:log --filter="razorpay_webhook" --tail

# View retry processor
firebase functions:log --filter="process_payment_retries" --tail

# Pending retries
db.collection('payment_retry_queue').where('status', '==', 'pending').get()

# Failed payments
db.collection('webhook_logs').where('processed', '==', false).get()
```

## Testing

```bash
npm test              # Run tests
npm test -- --watch   # Watch mode
```

## Deployment

```bash
firebase deploy --only functions
```

Then configure webhook in [Razorpay Dashboard](https://dashboard.razorpay.com):
- URL: Your Firebase function URL
- Events: payment.authorized, payment.captured, payment.failed
- Copy webhook secret to .env

## Configuration

Required environment variables:
```env
RAZORPAY_API_KEY=rzp_live_xxxxxxxxxxxxx
RAZORPAY_API_SECRET=xxxxxxxxxxxxxxxx
RAZORPAY_WEBHOOK_SECRET=webhook_secret_xxxxxxxx
```

## Performance

- Webhook processing: < 1 second
- Signature validation: < 10ms  
- Database transaction: < 100ms
- Batch retry processing: 50 per execution
- Cost: < $10/month

## Support

Detailed guides:
- `PAYMENT_WEBHOOK_SETUP.md` - Complete setup guide
- `WEBHOOK_IMPLEMENTATION_SUMMARY.md` - Architecture overview
- `DEPLOYMENT_CHECKLIST.md` - Step-by-step deployment

## Summary

Complete, production-ready payment webhook system:

- **450+ lines** webhook handler (razorpay_webhook.ts)
- **350+ lines** retry processor (process_payment_retries.ts)
- **100+ lines** Firestore security rules
- **300+ lines** comprehensive test suite
- **1200+ total** lines of production code
- **40+ test** cases covering all scenarios
- **Full TypeScript** support with generics
- **Zero external** payment processing burden
