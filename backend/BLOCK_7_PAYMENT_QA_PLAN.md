# BLOCK 7: PAYMENT QA VALIDATION
**Razorpay Integration, Webhook Reconciliation, Refunds & Security**

**Timeline:** ~120 minutes (parallel execution)  
**Start:** After seeding Batches 1-2-3  
**Target Score:** 100% (all payment flows validated)  
**Critical:** No payment leaks, double-charges, or security breaches

---

## OVERVIEW

Fufaji accepts payments via Razorpay (UPI primary, Cards secondary). This block validates:
- Payment success/failure flows
- Webhook signature verification (security)
- Idempotent refunds (no double-credit)
- Order ↔ Payment reconciliation

---

## CRITICAL: RAZORPAY KEY SECURITY

From project memory: **Razorpay key_secret == webhook_secret** (confirmed breaking payment/refund verification)

**MUST FIX BEFORE PAYMENT QA:**
```
Current (BROKEN):
  key_secret = "rzp_live_xyz..."
  webhook_secret = "rzp_live_xyz..." (SAME)
  
Result: Webhook signature verification passes even with tampered data
  
Fix Required:
  webhook_secret = unique_value_different_from_key_secret
  Regenerate in Razorpay dashboard
  Update .env: RAZORPAY_WEBHOOK_SECRET
  Deploy edge function with new secret
```

**Status:** ⚠️ MUST be fixed before Test 7.5

---

## CORE PAYMENT FLOWS

### Flow 1: Successful Payment
```
Customer → Select UPI/Card → Razorpay widget → Enter credentials 
→ Payment success → Webhook to edge function → Order created in Firestore
→ Confirmation email → Order in history ✅
```

### Flow 2: Failed Payment (Retry)
```
Customer → Payment fails (insufficient funds) → Razorpay error UI
→ Customer retries → Payment succeeds → Order created ✅
```

### Flow 3: Refund (Via Webhook)
```
Order refunded by admin → Razorpay sends refund webhook
→ Edge function receives → Wallet credits → User sees balance increase ✅
```

### Flow 4: Security (Webhook Signature)
```
Webhook arrives → Check signature → Signature valid? Yes → Process
                                    → No → Reject (log attack)
```

---

## TEST SCENARIOS

### Test 7.1: Successful Payment Creates Order
**Purpose:** End-to-end happy path

```
Setup:
  Cart: 2x Coca-Cola (BEV_001_250ML) @ ₹28 each
  Subtotal: ₹56
  GST (28%): ₹15.68
  Total: ₹71.68
  
Action:
  1. Proceed to checkout
  2. Enter UPI/Card details
  3. Razorpay processes payment
  4. Payment successful (callback)
  5. Webhook sent to edge function
  
Expected:
  1. Order created in Firestore: {
       "order_id": "ORD_20260704_001",
       "user_id": "user123",
       "items": [{"variant_id": "BEV_001_250ML", "quantity": 2}],
       "subtotal": 56.00,
       "gst": 15.68,
       "total": 71.68,
       "payment_id": "pay_xyz",
       "status": "confirmed",
       "created_at": "2026-07-04T16:45:00Z"
     }
  2. Wallet transaction logged
  3. Email sent: "Order confirmed"
  4. Order appears in history
  
Timeline: <5 seconds from webhook receipt
Result: ✅ / ❌
```

---

### Test 7.2: Failed Payment Shows Retry
**Purpose:** Graceful failure handling

```
Setup:
  Cart: 1x Maggi Noodles (PAK_001_75G) @ ₹11
  Razorpay configured to simulate failure
  
Action:
  1. Proceed to checkout
  2. Enter test payment details (decline code)
  3. Razorpay rejects payment
  
Expected:
  1. Error UI shows: "Payment failed. Retry or cancel."
  2. Cart preserved (items still in cart)
  3. No order created
  4. No stock locked (or lock released)
  5. Retry button functional
  
Timeline: <2 seconds
Result: ✅ / ❌
```

---

### Test 7.3: Refund Webhook Updates Wallet
**Purpose:** Refund flow validation

```
Setup:
  Order refunded by admin in Razorpay dashboard
  Original payment: ₹71.68
  Refund amount: ₹71.68 (full)
  
Razorpay Sends:
  POST /webhook
  {
    "event": "refund.created",
    "payload": {
      "refund": {
        "id": "rfnd_xyz",
        "payment_id": "pay_xyz",
        "amount": 7168,  // paise
        "status": "processed"
      }
    }
  }

Expected:
  1. Edge function receives webhook
  2. Signature verified ✅
  3. Refund processed:
     - Wallet balance += 71.68
     - Transaction logged: {
         "type": "refund",
         "order_id": "ORD_001",
         "amount": 71.68,
         "created_at": "2026-07-04T17:00:00Z"
       }
  4. User notification sent
  
Timeline: <3 seconds from webhook receipt
Result: ✅ / ❌
```

---

### Test 7.4: Idempotency (No Double-Credit)
**Purpose:** Webhook retry should not double-credit

```
Scenario:
  Webhook with refund.id = "rfnd_001" received
  Edge function processes refund → Wallet += 71.68
  Razorpay retries webhook (because no ACK)
  Edge function receives SAME webhook again
  
Expected:
  1. Edge function checks: Has refund "rfnd_001" been processed?
  2. Yes → Return 200 OK without re-processing
  3. Wallet balance still 71.68 (not doubled to 143.36)
  4. Audit log shows: "Webhook deduplicated (rfnd_001)"
  
Implementation:
  Use Firestore document ID = refund_id
  If doc exists, idempotent (no reprocessing)
  
Result: ✅ / ❌
```

---

### Test 7.5: Webhook Signature Validation (CRITICAL)
**Purpose:** Security — reject tampered webhooks

```
PREREQUISITE: Fix Razorpay webhook_secret (currently broken)

Setup:
  Razorpay sends webhook with signature header:
  "x-razorpay-signature": "abc123def456..."
  
  Webhook body:
  {
    "event": "payment.authorized",
    "payload": {...}
  }

Edge Function Code:
  1. Get request body + signature from header
  2. Compute HMAC-SHA256(body, webhook_secret)
  3. Compare: computed == provided signature?
  
Test 7.5a: Valid Signature
  Signature provided = correct HMAC
  Expected: Webhook processed ✅
  Result: ✅ / ❌

Test 7.5b: Tampered Body
  Body modified in transit (e.g., amount changed)
  Signature still valid? NO
  Expected: 403 Forbidden, webhook rejected, logged as attack
  Result: ✅ / ❌

Test 7.5c: Invalid Signature
  Attacker sends webhook with fake signature
  Expected: 403 Forbidden, logged, NOT processed
  Result: ✅ / ❌
```

---

### Test 7.6: Settlement Reconciliation
**Purpose:** Payments in Razorpay match orders in Firestore

```
Setup:
  Run this for last 24 hours of payments
  
Action:
  1. Pull all orders from Firestore (status = "confirmed")
  2. Pull all payments from Razorpay API
  3. Match payment_id in both systems
  
Expected:
  Every Firestore order with payment_id = "pay_xyz" has matching Razorpay payment
  No orphaned payments in Razorpay (unmatched)
  No orphaned orders in Firestore (unmatched)
  All amounts reconcile exactly
  
Report:
  {
    "total_orders": 50,
    "total_razorpay_payments": 50,
    "matched": 50,
    "unmatched_orders": 0,
    "unmatched_payments": 0,
    "reconciliation_status": "perfect"
  }
  
Result: ✅ / ❌
```

---

## IMPLEMENTATION: Webhook Handler

### Edge Function: /functions/razorpay-webhook.ts
```typescript
import { createClient } from '@supabase/supabase-js';
import * as crypto from 'crypto';

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_KEY')!);

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  const signature = req.headers.get('x-razorpay-signature');
  const body = await req.text();
  
  // 🔒 SECURITY: Verify signature
  const webhookSecret = Deno.env.get('RAZORPAY_WEBHOOK_SECRET')!;
  const computed = crypto
    .createHmac('sha256', webhookSecret)
    .update(body)
    .digest('hex');
  
  if (computed !== signature) {
    console.error('[Razorpay] Invalid signature detected — potential attack');
    return new Response('Unauthorized', { status: 403 });
  }

  const payload = JSON.parse(body);
  const event = payload.event;
  const data = payload.payload;

  console.log(`[Razorpay] Event: ${event}`);

  if (event === 'payment.authorized') {
    const paymentId = data.payment.id;
    const amount = data.payment.amount / 100; // Convert paise to rupees
    const orderId = data.payment.notes?.order_id;

    // Create order in Firestore (use Supabase trigger)
    await supabase.from('orders').insert({
      payment_id: paymentId,
      order_id: orderId,
      amount: amount,
      status: 'confirmed',
      created_at: new Date().toISOString(),
    });

    console.log(`[Razorpay] Order created: ${orderId}`);
    return new Response(JSON.stringify({ status: 'ok' }), { status: 200 });
  }

  if (event === 'refund.created') {
    const refundId = data.refund.id;
    const paymentId = data.refund.payment_id;
    const amount = data.refund.amount / 100; // paise to rupees

    // ✅ Idempotency: Check if refund already processed
    const { data: existing } = await supabase
      .from('wallet_transactions')
      .select('id')
      .eq('refund_id', refundId);

    if (existing && existing.length > 0) {
      console.log(`[Razorpay] Refund already processed (idempotent): ${refundId}`);
      return new Response(JSON.stringify({ status: 'ok' }), { status: 200 });
    }

    // Process refund (credit wallet)
    await supabase.from('wallet_transactions').insert({
      refund_id: refundId,
      payment_id: paymentId,
      type: 'refund',
      amount: amount,
      created_at: new Date().toISOString(),
    });

    console.log(`[Razorpay] Refund processed: ${refundId} (+₹${amount})`);
    return new Response(JSON.stringify({ status: 'ok' }), { status: 200 });
  }

  return new Response(JSON.stringify({ status: 'event_not_handled' }), { status: 200 });
});
```

---

## QA CHECKLIST

### Pre-Test Validation
- [ ] Razorpay webhook_secret fixed (different from key_secret)
- [ ] Edge function deployed with new secret
- [ ] Razorpay API keys in .env (not hardcoded)
- [ ] Test payment method configured
- [ ] Test UPI/Card details available
- [ ] Firestore `orders` collection exists
- [ ] Firestore `wallet_transactions` collection exists

### Test Execution
- [ ] Test 7.1: Successful Payment — PASS / FAIL
- [ ] Test 7.2: Failed Payment Retry — PASS / FAIL
- [ ] Test 7.3: Refund Webhook — PASS / FAIL
- [ ] Test 7.4: Idempotency (no double-credit) — PASS / FAIL
- [ ] Test 7.5a: Valid Signature Accepted — PASS / FAIL
- [ ] Test 7.5b: Tampered Body Rejected — PASS / FAIL
- [ ] Test 7.5c: Invalid Signature Rejected — PASS / FAIL
- [ ] Test 7.6: Settlement Reconciliation — PASS / FAIL

### Post-Test Validation
- [ ] All payment records logged (audit trail)
- [ ] No failed webhook logs
- [ ] Wallet balances correct (spot check 5 users)
- [ ] Order amounts reconcile (spot check 10 orders)
- [ ] Security: Zero unauthorized webhook attempts

---

## SUCCESS CRITERIA

### Target: 100% Pass Rate
```
✅ 8/8 tests passing = PROCEED TO BLOCK 8
⚠️  7/8 tests passing = MINOR ISSUE (investigate payment retry)
⚠️  6/8 tests passing = MODERATE ISSUE (security risk — fix before launch)
❌ <6/8 tests passing = CRITICAL ISSUE (cannot launch)
```

### Payment Processing Targets
- Payment creation: <1 second
- Webhook delivery: <5 seconds
- Refund processing: <3 seconds
- Signature verification: <100ms

### Security Targets
- ✅ Zero webhook tampering detected
- ✅ All signatures validated
- ✅ Zero double-charges
- ✅ Zero orphaned transactions

---

## CRITICAL ISSUES (STOP-SHIP)

If ANY of these occur → Cannot proceed to launch:
1. ❌ Double-charge detected (same refund credited twice)
2. ❌ Invalid signature accepted (security breach)
3. ❌ Webhook tampered data processed (security breach)
4. ❌ Payment/order reconciliation mismatch >5%
5. ❌ Razorpay secret still broken (security)

---

## ROLLBACK PLAN

If critical payment issues:
```
1. Disable payment processing (checkout blocked)
2. Notify all customers (email: "Payments down")
3. Investigate webhook logs
4. Fix edge function code
5. Replay failed webhooks (after fix)
6. Reconcile wallet balances
7. Re-test all scenarios
8. Resume payments
```

---

## PASS/FAIL SUMMARY

```
BLOCK 7 RESULT:
┌──────────────────────────────────────┐
│ Tests Passed:      /8                │
│ Tests Failed:      /8                │
│ Critical Issues:   0/0 ✅            │
│ Security Issues:   0/0 ✅            │
│ Status:            PASS/FAIL         │
│ Final Score:       /100              │
└──────────────────────────────────────┘
```

---

## NEXT STEPS

- If PASS: Proceed to Block 8 (Launch Audit — final orchestration)
- If FAIL: Debug and retry before launch

**Timeline:** 120 minutes to complete all tests  
**Parallel Execution:** Runs alongside Block 6 & 8  
**Critical Path:** Payment system is critical for launch
