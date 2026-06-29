# Razorpay Integration - Quick Reference

## Critical Security Fact

**webhook_secret MUST NOT equal key_secret**

These are different Razorpay credentials:
- `key_secret` → Backend authentication (API calls)
- `webhook_secret` → Signature verification (payment callbacks & webhooks)

Current values in `.env`:
```
RAZORPAY_KEY_SECRET=ieGG9GcxgN0km2ZVcGyaGEG6
RAZORPAY_WEBHOOK_SECRET=Fufaji@Webhook2026!
✓ DIFFERENT (correct)
```

---

## API Endpoints

### Create Order
```
POST /payments/razorpay/order
Authorization: Bearer {token}

Request:
{
  "amount": 500,
  "orderId": "O-12345",
  "customerId": "C-67890",
  "notes": { "reason": "order" }
}

Response:
{
  "success": true,
  "razorpayOrderId": "order_abc123",
  "amount": 50000,
  "currency": "INR"
}
```

### Verify Payment
```
POST /payments/razorpay/verify
Authorization: Bearer {token}

Request:
{
  "razorpay_payment_id": "pay_xyz789",
  "razorpay_order_id": "order_abc123",
  "razorpay_signature": "HMAC...",
  "order_id": "O-12345"
}

Response:
{
  "success": true,
  "paymentId": "pay_xyz789",
  "orderId": "O-12345",
  "amount": 500
}
```

### Process Refund
```
POST /payments/{paymentId}/refund
Authorization: Bearer {admin-token}

Request:
{
  "amount": 500,
  "reason": "Customer request"
}

Response:
{
  "success": true,
  "refundId": "rfnd_abc123",
  "amount": 500
}
```

### Get Payment Status
```
GET /payments/{paymentId}
Authorization: Bearer {token}

Response:
{
  "success": true,
  "payment": {
    "paymentId": "pay_xyz789",
    "status": "captured",
    "amount": 500,
    "verified": true
  },
  "razorpayStatus": {
    "status": "captured"
  },
  "reconciled": true
}
```

### Reconcile Payment
```
POST /payments/{paymentId}/reconcile
Authorization: Bearer {admin-token}

Response:
{
  "success": true,
  "paymentId": "pay_xyz789",
  "status": "captured"
}
```

---

## Webhook Events

### Razorpay → Backend
```
POST /webhooks/razorpay
X-Razorpay-Signature: {HMAC-SHA256(...webhook_secret)}

Events handled:
- payment.captured      → Order PAID
- payment.failed        → Order CANCELLED
- refund.created        → Order REFUNDED
- order.paid            → Logged (informational)
```

---

## Files Changed

| File | Change | Lines |
|------|--------|-------|
| `backend/src/services/RazorpayService.js` | NEW | 299 |
| `backend/src/services/PaymentService.js` | NEW | 250 |
| `backend/src/routes/payments.js` | UPDATED | 200 |
| `backend/src/routes/webhooks.js` | UPDATED | 300 |
| `lib/services/razorpay_service.dart` | UPDATED | 60 |

---

## Deployment Checklist

### Before Deployment
- [ ] Code merged to main
- [ ] AWS SSM parameters set:
  - `/fufaji/razorpay/key_id`
  - `/fufaji/razorpay/key_secret`
  - `/fufaji/razorpay/webhook_secret` (DIFFERENT)

### During Deployment
- [ ] `npm install && sam build && sam deploy`
- [ ] Verify Lambda function deployed
- [ ] Check CloudWatch logs for errors

### After Deployment
- [ ] Configure webhook URL in Razorpay dashboard
- [ ] Enable events: payment.captured, payment.failed, refund.created
- [ ] Test order creation endpoint
- [ ] Test payment verification flow
- [ ] Verify webhook delivery in logs
- [ ] Monitor payment_reconciliation_log for errors

---

## Troubleshooting

### Signature Verification Failed
```
Error: "Payment signature verification failed"

Cause: webhook_secret ≠ key_secret (incorrect)
Solution: Verify both values in AWS SSM are different
```

### Webhook Not Delivering
```
Check:
1. Webhook URL in Razorpay dashboard correct?
2. HTTPS certificate valid?
3. Events selected in Razorpay dashboard?
4. CloudWatch logs for errors?
```

### Order Not Created
```
Check payment_reconciliation_log:
- Missing order_id?
- Order ID mismatch?
- Amount mismatch?
- Firestore rules blocking write?
```

### Duplicate Order Created
```
Idempotency should prevent this.
If it happens:
1. Check webhook_events collection
2. Verify event ID recorded
3. Manually delete duplicate order (admin UI)
```

---

## Success Indicators

1. ✓ Razorpay order created on checkout
2. ✓ Payment callback returns success
3. ✓ `/payments/razorpay/verify` responds with success
4. ✓ Order document created in Firestore
5. ✓ Payment document created with status="captured"
6. ✓ Payment ledger entry created
7. ✓ Webhook delivered from Razorpay
8. ✓ Webhook signature validated
9. ✓ No duplicate processing

---

## Key Metrics

| Metric | Target | Alert |
|--------|--------|-------|
| Payment success rate | >95% | <95% |
| Webhook latency | <1s | >2s |
| Signature errors | <1/hour | >5/hour |
| Failed payments | <2% | >2% |
| Reconciliation errors | 0 | >0 |

---

## Contacts

- **Razorpay Support**: https://razorpay.com/support
- **API Docs**: https://razorpay.com/docs/
- **Backend Logs**: CloudWatch `/fufaji/payments`
- **Admin Dashboard**: Razorpay merchant.razorpay.com

---

**Last Updated**: 2026-06-22
**Status**: PRODUCTION READY
