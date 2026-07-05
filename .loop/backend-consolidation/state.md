# Loop: backend-consolidation
phase: pr
cycle: 0
started: 2026-07-05T00:00
spec_approved: yes
pr_url: (none yet)
monitor_until: (not started)

## Log
- 2026-07-05 SPEC created: backend consolidation 3→1 codebase merge
- 2026-07-05 SPEC APPROVED by user
- 2026-07-05 10:05 IMPLEMENT starting: P0 Redis fix, P1 webhook consolidation, P2 worker health, P3 cleanup
- 2026-07-05 10:15 P0 COMPLETE: Upstash Redis OTP rate limiting already implemented in auth.js ✅
  - OTP endpoints: POST /auth/send-otp, POST /auth/verify-otp
  - Rate limits: 3 per 15 min, 10 per hour (using Upstash Redis)
  - Redis client already initialized with UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN

- 2026-07-05 10:45 IMPLEMENT CYCLE 0 COMPLETE — All P1/P2/P4 code written
  - Razorpay webhook refactored to outbox pattern
  - Health endpoints added (/health, /health/sync-worker)
  - Worker control secured (POST /worker/sync-start, /worker/sync-stop with token auth)
  - Worker metrics added (processed, failed, queue_depth)
  - Node 20.x pinned in package.json

- 2026-07-05 11:00 REVIEW CYCLE 0 COMPLETE — 1 blocking issue found
  - ✅ FIXED: Worker control endpoints now require WORKER_CONTROL_TOKEN

- 2026-07-05 11:05 FIX CYCLE 0 COMPLETE
  - Added verifyWorkerToken middleware to secure /worker/* endpoints

- 2026-07-05 11:10 VERIFY PHASE COMPLETE ✅
  - Static verification: ALL PASS
    - Import structure: ✅
    - Endpoint mounting: ✅
    - Middleware order: ✅
    - Razorpay webhook logic: ✅
    - Worker health endpoints: ✅
    - Worker metrics: ✅
    - package.json: ✅
  - Manual verification: PENDING (user action)
    - npm install, npm start, curl endpoints, delete dead files

- 2026-07-05 11:20 HANDOFF READY
  - handoff.md created with git commands & PR template
  - evidence/verification.md created with test checklist
  - review.md shows: 1 blocking issue FIXED (worker auth)
  
- 2026-07-05 11:25 Moving to PR PHASE — awaiting user to:
  1. Delete 10 dead files (inventory*.js, payments_v*.js, etc.)
  2. Delete 2 dead directories (render-backend/, fufaji-backend-nodejs/)
  3. npm install && npm start (local test)
  4. Paste git commands from handoff.md
  5. Create PR and return URL
  
## Session 2 Progress (2026-07-05)

### P0 — COMPLETE ✅
- Upstash Redis OTP rate limiting already in auth.js

### P1 — Webhook Consolidation (COMPLETE) ✅ 
- ✅ `backend/src/routes/webhooks.js` — Refactored Razorpay webhook to outbox pattern
  - Signature validation via HMAC-SHA256
  - Idempotency checking via webhook_logs table
  - PostgreSQL as source of truth
  - Outbox pattern: orders → outbox_events → sync worker → Firestore
  - Handlers for payment.authorized, payment.captured, payment.failed
  - WhatsApp webhook handler preserved

- ✅ `backend/src/app.js` — Added health endpoints & middleware
  - GET /health — basic liveness probe
  - GET /health/sync-worker — worker metrics (processed, failed, queue_depth)
  - POST /worker/sync-start — start sync worker (ops control)
  - POST /worker/sync-stop — stop sync worker (ops control)
  - Security middleware: helmet(), compression(), morgan(), rateLimit()

- ✅ `backend/src/services/firestore-sync-worker.js` — Added getHealth() method
  - Metrics tracking: processed, failed, queue_depth, last_poll, last_error
  - Export: start(), stop(), getHealth()
  - Auto-starts on module load

- ✅ `backend/package.json` — Pinned Node 20.x
  - Middleware deps already present: helmet, compression, morgan, express-rate-limit

### P3 — Dead Files Cleanup (PENDING — user action needed)
Files to delete (user must run these in terminal):
```bash
rm -f backend/src/routes/inventory.js
rm -f backend/src/routes/inventory_v2.js
rm -f backend/src/routes/delivery_routes.js
rm -f backend/src/routes/orders_v2.js
rm -f backend/src/routes/payments_v2.js
rm -f backend/src/routes/payments_v3.js
rm -f backend/src/routes/order-status-routes.js
rm -f backend/src/routes/payment-webhook-routes.js
rm -f backend/src/services/notification_preferences_screen.dart
rm -f backend/src/services/push_notification_service.dart
rm -rf render-backend/
rm -rf fufaji-backend-nodejs/
```

### P2 — Worker Health & Metrics (COMPLETE) ✅
- Metrics tracking in firestore-sync-worker.js: ✅ DONE

### P4 — Config Updates (COMPLETE) ✅
- Node 20.x pinned in package.json: ✅ DONE

---

# Original Implementation Notes
1. `backend/src/routes/webhooks.js` — Port Razorpay webhook from render-backend/src/webhooks/razorpay.ts
   - Should write to: PostgreSQL orders table + outbox_events table (not just Firestore)
   - Should use Supabase client (service role key)
   - Full implementation exists in render-backend/src/webhooks/razorpay.ts (847 lines)

2. `backend/src/app.js` — Add health endpoints
   - Add: GET /health/sync-worker endpoint
   - Add: POST /worker/sync-start and /worker/sync-stop endpoints
   - Mount middleware: helmet(), compression(), morgan('combined'), rateLimit()

### P2 — Worker Health & Metrics
1. `backend/src/services/firestore-sync-worker.js`
   - Add getHealth() method that returns: { processed, failed, queue_depth }
   - Ensure polling outbox_events table

### P3 — Cleanup Dead Files (DELETE THESE)
- backend/src/routes/inventory.js
- backend/src/routes/inventory_v2.js
- backend/src/routes/delivery_routes.js
- backend/src/routes/orders_v2.js
- backend/src/routes/payments_v2.js
- backend/src/routes/payments_v3.js
- backend/src/routes/order-status-routes.js
- backend/src/routes/payment-webhook-routes.js
- backend/src/services/notification_preferences_screen.dart
- backend/src/services/push_notification_service.dart
- render-backend/ (entire directory)
- fufaji-backend-nodejs/ (entire directory)

### P4 — Config Updates
1. backend/package.json
   - Add: "engines": { "node": "20.x" }
   - Ensure middleware dependencies: helmet, compression, morgan, express-rate-limit

## VERIFICATION CHECKLIST
- [ ] npm install succeeds
- [ ] npm start — all services initialize, no require() errors
- [ ] GET /health returns 200
- [ ] GET /health/sync-worker returns valid JSON with metrics
- [ ] POST /webhooks/razorpay with test payload returns 200, updates PostgreSQL orders
- [ ] OTP rate limiting works (10 requests rejected, 3rd+ returns 429)
- [ ] No broken imports on startup
- [ ] All 31 mounted routes work

## FILES THAT ARE ALREADY WORKING
✅ auth.js — OTP rate limiting complete
✅ render-backend/src/webhooks/razorpay.ts — Complete implementation (ready to port)
