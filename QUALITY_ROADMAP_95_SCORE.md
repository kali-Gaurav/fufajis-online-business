# Quality Roadmap: 62/100 → 95/100
**Target Date:** End of Sprint  
**Modules:** Checkout, Payment, Inventory, Events, Database

---

## Current Status: 62/100 → 75/100 (POST-AUDIT FIXES)

**Today's Fixes:** 40 issues resolved
- 8 race conditions (transactions + deadlock retry)
- 7 missing validations (inputs + authorization)
- 6 N+1 queries (batch updates)
- 5 deadlock vulnerabilities (retry logic)
- 4 timeout gaps (HTTP + database)
- 3 authentication flaws (dummy user removed)
- 2 audit logging gaps (inventory + payments)

**Current Estimate:** +13 points → 75/100

---

## Remaining Gaps to 95/100 (+20 points)

### A. Rate Limiting (+3 points)
**Why:** Prevent DoS on checkout, payment, shipping endpoints

**Files to Update:**
```
backend/src/middleware/rate-limit.js (NEW)
backend/src/routes/checkout-routes.js (add middleware)
backend/src/routes/webhooks.js (rate limit Razorpay webhook)
```

**Implementation:**
- Per-user rate limit: 10 requests/minute on checkout
- Per-IP rate limit: 100 requests/minute on webhooks
- Use Redis for distributed rate limiting (or in-memory for single-server)

**Test Case:**
```javascript
// Should fail on 11th request in 60s
POST /checkout/create-order (10× success, 11× 429)
```

---

### B. Input Sanitization (+2 points)
**Why:** Prevent injection attacks via user inputs

**Files to Update:**
```
backend/src/middleware/sanitize.js (NEW)
backend/src/routes/checkout-routes.js (apply to all inputs)
```

**Targets:**
- Coupon codes (alphanumeric + dash only)
- Delivery addresses (address validation library)
- Payment methods (enum validation)
- Phone numbers (E.164 format)

**Test Case:**
```javascript
// Should reject
POST /checkout/create-order { couponCode: "DROP TABLE;" }  // 400
POST /checkout/create-order { couponCode: "../../../" }    // 400
```

---

### C. Request/Response Logging (+2 points)
**Why:** Debug production issues, audit trail

**Files to Update:**
```
backend/src/middleware/logger.js (NEW)
backend/src/server.js (add middleware)
```

**Log:**
- Request: method, path, user_id, timestamp, body (sensitive fields redacted)
- Response: status code, response time, error (if any)
- Payment: full payment details + webhook events

**Test Case:**
```javascript
// Check /logs endpoint returns last 100 requests
GET /admin/logs
=> [{ method: 'POST', path: '/checkout/create-order', status: 200, durationMs: 145 }, ...]
```

---

### D. Database Connection Pooling Monitoring (+2 points)
**Why:** Catch resource exhaustion early

**Files Already Modified:**
```
backend/src/db/pool.js (health check added, but needs persistence)
```

**To Add:**
- Expose `/metrics` endpoint with pool stats
- Track slow queries (> 1000ms)
- Alert when > 90% connection utilization

**Test Case:**
```javascript
GET /metrics
=> { connections: { total: 20, idle: 3, in_use: 17, waiting: 2 } }
```

---

### E. Comprehensive Error Codes (+2 points)
**Why:** Clients need actionable errors, not generic "CHECKOUT_FAILED"

**Files to Update:**
```
backend/src/constants/error-codes.js (NEW)
backend/src/routes/*.js (use error codes)
```

**Error Codes Map:**
```javascript
{
  // Inventory
  "STOCK_001": "Product out of stock",
  "STOCK_002": "Insufficient stock for quantity",
  
  // Payment
  "PAY_001": "Payment gateway unavailable",
  "PAY_002": "Payment amount mismatch",
  "PAY_003": "Payment timeout",
  
  // Coupon
  "COUP_001": "Coupon expired",
  "COUP_002": "Coupon usage limit exceeded",
  
  // Delivery
  "DEL_001": "Address coordinates missing",
  "DEL_002": "Delivery distance exceeds limit",
}
```

**Test Case:**
```javascript
// Should include error code
POST /checkout/create-order (out of stock)
=> { error: 'STOCK_002', message: 'Insufficient stock for quantity' }
```

---

### F. Webhook Retry + Dead Letter Queue (+3 points)
**Why:** Ensure no payments are lost to transient failures

**Files to Update:**
```
backend/src/jobs/webhook-retry-cron.js (NEW)
backend/src/routes/webhooks.js (already partially done)
```

**Implementation:**
- Webhook events stored in DB with status (pending/processed/failed/dlq)
- Retry job runs every 5 minutes for failed webhooks
- Exponential backoff: 1min, 5min, 15min, 1hr, 4hr
- After 5 retries → dead letter queue (manual review)

**Test Case:**
```javascript
// Simulate Razorpay webhook timeout, verify auto-retry
POST /webhooks/razorpay (timeout on first call)
// Wait 5 minutes
// Verify webhook re-processed on retry

GET /admin/dlq  // Show failed webhooks
=> [{ eventId, orderId, reason, retries: 5 }]
```

---

### G. Payment Reconciliation Improvements (+2 points)
**Why:** Catch stuck payments earlier

**Files to Update:**
```
backend/src/jobs/reconciliation-cron.js (modify frequency + thresholds)
```

**Changes:**
- Run every 15 minutes (was 1 hour)
- Alert if > 10 orders stuck for > 1 hour
- Auto-refund if stuck for > 4 hours without manual intervention
- Track metrics: stuck orders, recovered orders, failed orders

**Test Case:**
```javascript
// Create order, simulate webhook delay for 1+ hour
// Verify reconciliation detects stuck order
// Verify alert sent to ops
```

---

### H. Customer Refund Flow (+2 points)
**Why:** Customers need to see refunds, admin needs approval workflow

**Files to Create:**
```
backend/src/routes/refund-routes.js (NEW)
backend/src/services/refund-service.js (NEW)
```

**Endpoints:**
```
POST /refunds/request-refund         # Customer requests refund
GET  /refunds/my-refunds             # View refund status
POST /admin/refunds/:id/approve      # Admin approves
POST /admin/refunds/:id/reject       # Admin rejects
```

**Test Case:**
```javascript
// Customer requests refund
POST /refunds/request-refund { orderId, reason }
=> { refundId, status: 'pending' }

// Admin approves
POST /admin/refunds/:refundId/approve
=> { refundId, status: 'approved' }

// Verify Razorpay refund issued
// Verify customer sees refund status
```

---

### I. Integration Tests (+1 point)
**Why:** Catch bugs before production

**Files to Create:**
```
backend/__tests__/checkout-integration.test.js (NEW)
backend/__tests__/payment-integration.test.js (NEW)
```

**Test Scenarios:**
1. Happy path: create order → pay → confirm
2. Inventory exhaustion: concurrent checkouts
3. Payment failure + recovery
4. Refund flow
5. Authorization checks (users can't access other users' orders)

**Target:** 80%+ coverage on services

---

### J. Documentation (+1 point)
**Why:** Onboarding, debugging, incident response

**Files to Create:**
```
backend/API_SPEC.md              # API endpoint reference
backend/PAYMENT_FLOW.md          # Payment state machine diagram
backend/INCIDENT_RESPONSE.md     # What to do if X breaks
backend/SETUP.md                 # Local dev setup
```

---

## Prioritization (by impact + effort)

### PHASE 1 (Week 1) — Must Have
1. **Comprehensive Error Codes** (+2) ← Easy, high client value
2. **Webhook Retry + DLQ** (+3) ← Critical for payments
3. **Payment Reconciliation Improvements** (+2) ← High impact, low effort
4. **Request/Response Logging** (+2) ← Debug production

**Estimated Points:** +9 → **84/100**

### PHASE 2 (Week 2) — Should Have
5. **Rate Limiting** (+3) ← Security
6. **Input Sanitization** (+2) ← Security
7. **Database Connection Monitoring** (+2) ← Ops visibility

**Estimated Points:** +7 → **91/100**

### PHASE 3 (Week 3) — Nice to Have
8. **Customer Refund Flow** (+2) ← UX
9. **Integration Tests** (+1) ← Quality assurance

**Estimated Points:** +3 → **94/100**

---

## Quality Gate Checklist (for 95+)

**Functionality:**
- [x] Checkout flow end-to-end
- [x] Payment webhook processing
- [x] Inventory locking + release
- [x] Coupon validation
- [x] Shipping fee calculation
- [ ] Refund request + approval
- [ ] Webhook retry on failure
- [ ] Dead letter queue handling

**Security:**
- [x] Authentication (Firebase tokens)
- [x] Authorization (customer ownership)
- [ ] Rate limiting
- [ ] Input sanitization
- [x] SQL injection protection
- [x] Webhook signature verification

**Performance:**
- [x] Query optimization (no N+1)
- [x] Batch processing (cron jobs)
- [ ] Database metrics + alerting
- [x] Timeout protection
- [x] Deadlock handling

**Reliability:**
- [x] Transaction atomicity
- [x] Audit logging
- [ ] Error recovery (retry logic)
- [ ] Dead letter queue
- [x] Idempotency

**Operability:**
- [x] Structured logging
- [ ] Detailed error codes
- [ ] Incident response docs
- [x] Health checks
- [ ] Metrics endpoint

---

## Success Criteria for 95/100

1. **All 40 audit fixes deployed** ✅ (done)
2. **Error codes standardized** (Implement E)
3. **Webhook retry + DLQ working** (Implement F)
4. **Rate limiting active** (Implement A)
5. **Integration tests passing** (80%+ coverage)
6. **Logging + metrics visible** (Implement B, C, D)
7. **Refund flow functional** (Implement H)
8. **Zero high-severity production issues** (2-week monitoring)

---

## Monitoring Queries (for OPS)

```sql
-- Stuck payments (> 30 min in payment_pending)
SELECT id, created_at, status FROM orders 
WHERE status = 'payment_pending' 
  AND created_at < NOW() - INTERVAL '30 minutes'
ORDER BY created_at ASC;

-- Connection pool utilization
SELECT COUNT(*) as in_use FROM pg_stat_activity 
WHERE datname = 'fufaji_db';

-- Slow queries (> 1s)
SELECT query, calls, mean_time FROM pg_stat_statements 
WHERE mean_time > 1000 
ORDER BY mean_time DESC;

-- Dead letter events
SELECT * FROM events WHERE status = 'dead_letter' 
ORDER BY created_at DESC LIMIT 50;

-- Failed webhooks (ready for retry)
SELECT * FROM webhook_events 
WHERE status = 'failed' AND next_retry_at <= NOW()
ORDER BY created_at ASC;
```

---

## Risk Assessment

**Highest Risk (if not addressed):**
1. Payment loss due to webhook failures → **Implement F** (Webhook Retry)
2. Authorization bypass (users seeing other users' data) → **Already fixed in audit**
3. Database connection exhaustion → **Implement D** (Monitoring)
4. DoS via rate limiting → **Implement A** (Rate Limiting)

**Medium Risk:**
5. Production debugging (no logs) → **Implement C** (Logging)
6. Refund disputes (no refund flow) → **Implement H** (Refunds)

---

## Questions for Product/PM

1. Should refunds require manual admin approval?
2. What's the max acceptable payment recovery time (target: < 1 hour)?
3. Should we notify customer on refund request, or only on approval?
4. Should failed payments auto-refund after 24 hours, or wait for manual approval?

---

**Target Completion:** End of Sprint  
**Quality Target:** 95/100 or higher  
**Confidence Level:** HIGH (40 critical issues already fixed + clear roadmap)
