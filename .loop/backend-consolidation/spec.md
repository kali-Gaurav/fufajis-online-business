# Backend Consolidation Spec

## Problem / Goal

Fufaji currently has **3 backend directories** with overlapping and conflicting code:
- `backend/` — canonical Node.js CJS backend (20+ routes, all business logic)
- `render-backend/` — TypeScript/ESM thin shell with Razorpay webhook + Firestore sync worker
- `fufaji-backend-nodejs/` — empty skeleton with no entry point

**Goal:** Consolidate into **one clean `backend/` codebase** that owns all webhooks, workers, and integrations. Remove dead code, fix Upstash Redis (P0 blocking OTP), and ensure proper separation between API and async worker logic.

## Scope

### Files to Modify (Port logic from render-backend)
- `backend/src/app.js` — add health endpoints, worker management, security middleware
- `backend/src/routes/webhooks.js` — port Razorpay webhook with Supabase writes + outbox pattern
- `backend/src/services/firestore-sync-worker.js` — add getHealth() method
- `backend/src/server.js` — wire up cron jobs
- `backend/src/redis-config.js` — fix Upstash auth for OTP rate limiting (P0)
- `backend/package.json` — pin Node 20.x, add middleware dependencies
- `backend/render.yaml` — keep 2 services (web + worker)

### Files to Delete (Dead/duplicate code)
- `backend/src/routes/inventory.js` (broken, superseded)
- `backend/src/routes/inventory_v2.js` (broken, superseded)
- `backend/src/routes/delivery_routes.js` (duplicate)
- `backend/src/routes/orders_v2.js` (superseded)
- `backend/src/routes/payments_v2.js` (superseded)
- `backend/src/routes/payments_v3.js` (superseded)
- `backend/src/routes/order-status-routes.js` (dead)
- `backend/src/routes/payment-webhook-routes.js` (stub)
- `backend/src/services/notification_preferences_screen.dart` (misplaced Flutter file)
- `backend/src/services/push_notification_service.dart` (misplaced Flutter file)
- `render-backend/` (entire directory)
- `fufaji-backend-nodejs/` (entire directory)

### Non-Goals
- Do NOT move checkout, order lifecycle, or OTP verification out of Supabase Edge Functions
- Do NOT refactor the 31 existing routes (only delete duplicates)
- Do NOT touch src/backend database schema or migrations

## Exit Criteria (Objectively Checkable)

1. ✅ **Single backend codebase** — `render-backend/` and `fufaji-backend-nodejs/` deleted
2. ✅ **No broken imports** — all 31 mounted routes require() cleanly on startup
3. ✅ **No dead routes** — removed 10 duplicate/broken route files
4. ✅ **Upstash Redis fixed** — `GET /api/auth/otp-check` rate limiting works (OTP verified in test)
5. ✅ **Worker health endpoint** — `GET /health/sync-worker` returns `{ processed: N, failed: M, queue_depth: K }`
6. ✅ **Worker metrics visible** — processed/failed/retry counts tracked in sync worker
7. ✅ **Security middleware active** — helmet, compression, morgan, rateLimit mounted
8. ✅ **Node 20.x pinned** — package.json has `"engines": { "node": "20.x" }`
9. ✅ **Clean Render deployment** — backend starts without DATABASE_URL errors
10. ✅ **Razorpay webhook working** — POST /webhooks/razorpay → writes to PostgreSQL + outbox_events

## Verification Plan

**Mode:** Static (tests + linter + startup check)

1. Build backend: `npm run build`
2. Lint: `npm run lint` (zero errors)
3. Startup: `npm start` — all services initialized, no require() errors
4. Redis test: OTP rate limiting active (manual check: send 10 requests, 6+ rejected)
5. Webhook test: POST /webhooks/razorpay with test payload → 200 OK, order updated in PostgreSQL
6. Worker health: GET /health/sync-worker → valid JSON with processed/failed/queue_depth
7. Route test: GET / → 404 or home page (app running)

## Hard Rules (Non-negotiable)

1. **backend/ is the only backend** — No render-backend or fufaji-backend-nodejs after merge
2. **Transactional logic stays in Edge Functions** — Checkout, order lifecycle, OTP verification live in Supabase
3. **Outbox pattern for webhooks** — PostgreSQL → outbox_events → sync worker → Firestore (not direct writes)
4. **Separated folder structure** — API routes in `/routes`, workers in `/workers`, jobs in `/cron`

---

**Spec version:** 1.0  
**Approved:** (awaiting user confirmation)
