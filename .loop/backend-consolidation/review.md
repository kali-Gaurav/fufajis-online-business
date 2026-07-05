# Code Review — Backend Consolidation P1/P2/P4

**Reviewer:** Claude (fresh-eyes review)
**Date:** 2026-07-05
**Scope:** Razorpay webhook refactor, health endpoints, middleware, worker metrics

---

## Findings

### ✅ PASS — Razorpay Webhook Refactor (webhooks.js)

**What's Good:**
1. **Outbox Pattern** — PostgreSQL writes → outbox_events table → sync worker → Firestore. Correct separation of concerns.
2. **Signature Validation** — HMAC-SHA256 verification before processing. Rejects invalid signatures with 401.
3. **Idempotency** — Uses payment_id + webhook_logs table to prevent duplicate processing. Handles `PGRST116` (no rows) error correctly.
4. **Error Handling** — Returns 200 OK to Razorpay even on error (prevents infinite retries). Error details logged in webhook_logs.
5. **Event Routing** — Handles payment.authorized, payment.captured, payment.failed with appropriate status updates.
6. **Firestore Sync** — Uses writeOutboxEvent() to queue Firestore sync asynchronously. Non-blocking.
7. **WhatsApp Handler Preserved** — Kept intact from original implementation.

**Minor Concerns:**
- **Supabase client initialization** — Uses process.env.SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY. Must be set or webhook fails silently. *(Consider: log warning if not set on module load)*
- **No timeout protection** — If updateOrderStatus() hangs, webhook will block indefinitely. *(Consider: 10s timeout per handler)*
- **Payment failure handling** — Sets order status to 'cancelled', but cancellation_reason is not captured. *(Minor: log error code for ops visibility)*

**Status:** ✅ **PASS** — Ready for merge. Nits optional.

---

### ✅ PASS — Health Endpoints (app.js)

**What's Good:**
1. **Middleware Ordering** — CORS → helmet() → compression() → morgan() → rate limit → webhooks (raw) → json. Correct order for signature validation.
2. **GET /health** — Simple liveness probe. Returns 200 with { success, status, ts }.
3. **GET /health/sync-worker** — Calls getHealth(), returns processed/failed/queue_depth. Handles errors with 503.
4. **POST /worker/sync-start / /worker/sync-stop** — Ops endpoints to control worker. Return immediately with success/error.
5. **Rate Limiting** — 1000 req/15min per IP. Reasonable for a backend.
6. **Security Headers** — helmet() applied globally.

**Concerns:**
- **Worker control endpoints have no auth** — Any client can POST /worker/sync-start to start/stop the worker. *(Blocking nit: should require auth token or IP allowlist for production)*.
- **health/sync-worker error handling** — Catches errors and returns 503. Good, but doesn't log the exception object. *(Minor: add console.error(error) not just error.message)*

**Status:** ⚠️ **CONDITIONAL PASS** — Blocking: /worker/* endpoints need auth before merge.

---

### ✅ PASS — Worker Metrics (firestore-sync-worker.js)

**What's Good:**
1. **Metrics Tracking** — processed, failed, queue_depth, last_poll, last_error. All updated in processOutbox().
2. **getHealth() Export** — Returns metrics object. Matches health endpoint expectations.
3. **start() / stop() Methods** — Control worker via interval management. Guard against double-start.
4. **Auto-Start** — Module initializes worker on load. Useful for background polling.
5. **Error Logging** — Updates _metrics.last_error on failures. Accessible via getHealth().

**Concerns:**
- **Metrics only update during processOutbox()** — If worker crashes or queue_depth isn't fetched, metrics go stale. *(Minor: add periodic heartbeat metric)*
- **No persistence of metrics** — On worker restart, counters reset to 0. *(Minor: could query PostgreSQL for historical counts if needed)*
- **processed/failed counters increment during session only** — Not meant to be the source of truth. *(Consider: use DB-backed counters for audit trail)*

**Status:** ✅ **PASS** — Metrics are appropriate for ops visibility. Counters reset on restart is expected.

---

### ✅ PASS — package.json & Config

**What's Good:**
1. **Node 20.x Pinned** — Changed from `>=20.0.0` to `20.x`. Matches Render expectation.
2. **All Dependencies Present** — helmet, compression, morgan, express-rate-limit already in package.json.

**Status:** ✅ **PASS**

---

## Summary

| Item | Status | Notes |
|------|--------|-------|
| Razorpay webhook refactor | ✅ PASS | Outbox pattern correct. Nits: timeout, error logging. |
| Health endpoints | ⚠️ BLOCKING | /worker/* endpoints need auth. |
| Worker metrics | ✅ PASS | Appropriate for ops visibility. |
| package.json | ✅ PASS | Node 20.x pinned, deps present. |

---

## Blocking Issues (FIXED)

### 1. ✅ Worker Control Endpoints Now Require Authentication

**File:** `backend/src/app.js`

**Fix Applied:** 
- Added `verifyWorkerToken` middleware that validates `Authorization: Bearer <WORKER_CONTROL_TOKEN>`
- Requires `WORKER_CONTROL_TOKEN` environment variable
- Returns 503 if token not configured, 401 if unauthorized
- Both /worker/sync-start and /worker/sync-stop protected

---

## Nits (Nice-to-have, optional)

1. **Razorpay webhook error logging** — Add payment error_code to webhook_logs for audit trail
2. **Sync worker heartbeat** — Add timestamp of last successful poll to metrics
3. **Health endpoint exception logging** — Log full error object, not just message

---

**Reviewer Sign-Off:** Ready to fix blocking issue then proceed to VERIFY phase.
