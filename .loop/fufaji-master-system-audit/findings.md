# System Audit Findings — Fufaji Master System

**Date:** 2026-07-05
**Scope:** 7 areas + 7 missing SaaS modules
**Format:** Severity level + Priority tier

---

## AUDIT FINDINGS

### 1. BACKEND ARCHITECTURE

**Current State:**
- ✅ Express backend exists
- ✅ 31 mounted routes (checkout, payments, auth, orders, delivery, AI, admin, etc.)
- ✅ Workers: event-worker, sync-worker, firestore-sync-worker
- ✅ Cron jobs: cleanup, reconciliation, webhook-retry
- ✅ Services: ~40+ services (Payment, Order, Delivery, Pricing, Recommendation, AI, etc.)
- ✅ Middleware: validation, idempotency, error handling
- ✅ Just consolidated 3→1 codebase (backend-consolidation loop in progress)

**Issues Found:**

| ID | Issue | P-Level | Impact |
|---|---|---|---|
| B0-1 | **CRITICAL: No structured logging** — console.log scattered, no log levels, no context | P0 | Ops blind to production errors |
| B0-2 | **CRITICAL: No request tracing** — no correlation IDs, difficult to debug distributed flows | P0 | Impossible to trace requests across services |
| B0-3 | **No metrics collection** — performance monitor exists but incomplete, no Prometheus/metrics export | P1 | Cannot observe production SLOs |
| B1-1 | **No authentication middleware** — routes lack role-based access checks, `@requireRole` missing | P1 | Security gaps in multi-user flows |
| B1-2 | **Error responses inconsistent** — some return `{ error }`, others `{ success: false }`, no standard | P1 | Client parsing fragile |
| B1-3 | **Webhook retry logic fragile** — webhook-retry-cron exists but no exponential backoff + DLQ | P1 | Lost webhooks in production |
| B1-4 | **No rate limiting at route level** — general rate limit exists but endpoint-specific limits missing | P1 | Abuse vectors (OTP spam, brute force) |
| B2-1 | **Services lack dependency injection** — services import each other circularly, hard to test | P2 | Difficult to unit test, high coupling |
| B2-2 | **No graceful degradation** — service A fails → entire request fails, no fallbacks | P2 | Cascade failures |

**Status:** ⚠️ **P0 + P1 blockers found. Action: Implement structured logging + tracing immediately.**

---

### 2. DATABASE ARCHITECTURE (PostgreSQL / Supabase)

**Current State:**
- ✅ Supabase PostgreSQL (source of truth per CLAUDE.md)
- ✅ 12 migrations (01_init_core_schema → 20260705_webhook_logs_table)
- ✅ RLS policies exist (02_rls_policies.sql)
- ✅ Outbox pattern for Firestore sync (06_firestore_downstream_sync.sql)

**Schema Assessment (reading migrations):**

| Table | Exists | RLS | Indexes | Status |
|---|---|---|---|---|
| orders | ✅ | ✅ | ✓ | Source of truth |
| products | ✅ | ✅ | ✓ | Catalog |
| inventory | ✅ | ✅ | ✓ | 3-layer model (available/reserved/sold) |
| wallets | ✅ | ✅ | ✓ | User balances |
| payments | ✅ | ✅ | ✓ | Razorpay integration |
| delivery | ✅ | ✅ | ✓ | Rider assignments |
| staff | ✅ | ✅ | ✓ | Employee records |
| outbox_events | ✅ | ✅ | ✓ | Firestore sync queue |
| webhook_logs | ✅ | ⚠️ | ? | New (2026-07-05), no RLS check yet |
| analytics | ⚠️ | ? | ? | Exists per 05_enable_rls_analytics.sql, minimal schema |

**Issues Found:**

| ID | Issue | P-Level | Impact |
|---|---|---|---|
| DB0-1 | **CRITICAL: No audit trail tables** — user actions not logged, cannot track who did what | P0 | Compliance + security blind spot |
| DB0-2 | **CRITICAL: No transaction isolation checks** — race conditions possible in payment flows | P0 | Double-charge risk |
| DB1-1 | **Analytics schema incomplete** — table exists but missing KPI views, aggregations | P1 | Cannot build dashboards |
| DB1-2 | **No full-text search indexes** — products searchable only via app-level fuzzy match | P1 | Search performance poor at scale |
| DB1-3 | **No materialized views** — common aggregations (daily revenue, top products) computed on every request | P1 | Query performance degrades |
| DB1-4 | **Missing foreign key constraints** (need to verify) | P1 | Data integrity issues possible |
| DB2-1 | **No data warehouse** — all queries hit OLTP database | P2 | Analytics slows production |

**Status:** ⚠️ **P0 + P1 issues. Action: Add audit tables + verify transaction isolation.**

---

### 3. SUPABASE (Edge Functions, Auth, Storage, Policies)

**Current State:**
- ✅ Auth: Firebase Auth + Supabase RLS policies
- ✅ Edge Functions: process-import-job, extract-receipt, extract-statement, aggregate-usage (per CLAUDE.md)
- ✅ Storage: S3 via boto3 (not Supabase Storage per code read)
- ✅ RLS policies: exist in 02_rls_policies.sql

**Issues Found:**

| ID | Issue | P-Level | Impact |
|---|---|---|---|
| SF0-1 | **CRITICAL: Edge Function errors not visible** — no logging/tracing into Edge Functions | P0 | Cannot debug function failures |
| SF1-1 | **Custom token generation possible** — CLAUDE.md says operational users use backend verification, need to audit | P1 | Auth bypass risk if mis-implemented |
| SF1-2 | **No function versioning** — deployments not versioned, rollback difficult | P1 | Bad deployment can break production |
| SF1-3 | **Storage auth unclear** — S3 used; Supabase Storage exists but integration incomplete | P1 | Unclear where media goes |
| SF2-1 | **RLS policies not tested** — cannot verify policies are tight | P2 | Privilege escalation possible |

**Status:** ⚠️ **P0 + P1 issues. Action: Add Edge Function logging + test RLS policies.**

---

### 4. FIREBASE (Auth, Firestore, FCM, Rules)

**Current State:**
- ✅ Auth: Firebase Auth (read-only per CLAUDE.md — source of truth is PostgreSQL custom tokens)
- ✅ Firestore: Read-only sync layer (outbox pattern from PostgreSQL)
- ✅ FCM: PushNotificationService exists
- ✅ Rules: Firestore security rules exist

**Issues Found:**

| ID | Issue | P-Level | Impact |
|---|---|---|---|
| FB0-1 | **CRITICAL: Firestore can be written to directly by clients** — RLS rules must be enforced | P0 | Data corruption risk |
| FB1-1 | **FCM topic-based subscriptions fragile** — no subscription tracking, lost messages possible | P1 | Users miss notifications |
| FB1-2 | **No analytics on Firestore reads** — cannot measure cache hit rate | P1 | Unknown if cache is effective |
| FB2-1 | **Offline sync to Firestore slow** — 5s polling interval (outbox-sync-worker) | P2 | UI lag possible |

**Status:** ⚠️ **P0 + P1 issues. Action: Audit Firestore RLS rules + implement FCM subscription tracking.**

---

### 5. REDIS / UPSTASH

**Current State:**
- ✅ OTP rate limiting: 3 per 15 min, 10 per hour (auth.js) via Upstash Redis
- ✅ Hot cache exists (per architecture)
- ✅ Used for rate limiting

**Issues Found:**

| ID | Issue | P-Level | Impact |
|---|---|---|---|
| RD0-1 | **CRITICAL: No queue implementation** — Job queue missing (see missing modules) | P0 | Cannot process async jobs reliably |
| RD1-1 | **Cache keys not standardized** — each service uses different key format | P1 | Cache misses, duplicated data |
| RD1-2 | **No cache invalidation strategy** — TTLs hardcoded, no event-driven invalidation | P1 | Stale data in cache |
| RD1-3 | **No Redis monitoring** — cannot see key count, memory usage, evictions | P1 | Out-of-memory risks unknown |
| RD2-1 | **No persistent queue** — job loss possible on Redis restart | P2 | Lost background jobs |

**Status:** ⚠️ **P0 blocker. Action: Implement job queue immediately (Upstash QStash or similar).**

---

### 6. FLUTTER APP

**Current State:**
- ✅ 386 .dart files (recovered from truncation in June 2026)
- ✅ Comprehensive screens: home, orders, delivery, payment, AI voice, support, admin, etc.
- ✅ Providers: auth, cart, orders, products, reports
- ✅ Services: 30+ services (speech_to_text, voice_order_parser, AI, referral, etc.)
- ✅ Security: session management, Firestore rules, biometric support
- ✅ Navigation: GoRouter with guards + role-based routing

**Issues Found:**

| ID | Issue | P-Level | Impact |
|---|---|---|---|
| FL1-1 | **No offline-first caching** — only online mode supported | P1 | Users can't browse catalog offline |
| FL1-2 | **Error messages generic** — users see "Something went wrong", no actionable feedback | P1 | Poor UX, users confused |
| FL1-3 | **No analytics events** — cannot measure user behavior | P1 | Product blind to feature usage |
| FL1-4 | **Deep linking incomplete** — notifications link to hardcoded routes, no dynamic routing | P1 | Notification clicks fail if app state differs |
| FL2-1 | **No performance monitoring** — cannot measure app startup time, frame rates | P2 | Performance regressions undetected |
| FL2-2 | **Providers not tested** — no unit tests visible | P2 | Provider logic regressions possible |

**Status:** ✅ **Minor issues (P1 + P2 only). Action: Add offline caching + analytics.**

---

### 7. DEVOPS

**Current State:**
- ✅ Render deployment (backend)
- ✅ Secrets management (env vars)
- ✅ Database: Supabase (managed)
- ✅ render.yaml: 2 services (web + worker)

**Issues Found:**

| ID | Issue | P-Level | Impact |
|---|---|---|---|
| OP0-1 | **CRITICAL: No health checks** — Render cannot auto-restart unhealthy services | P0 | Service hangs go undetected |
| OP0-2 | **CRITICAL: No database backups visible** — Supabase auto-backups but no restore procedure docs | P0 | Data loss recovery unknown |
| OP1-1 | **No secrets rotation** — Razorpay keys, Firebase keys, API keys never rotated | P1 | Key compromise unrecovered |
| OP1-2 | **No alerting** — production errors logged but no alerts to owner | P1 | Owner unaware of production issues |
| OP1-3 | **No log aggregation** — logs scattered across Render console, Firebase, stdout | P1 | Cannot search logs |
| OP1-4 | **No deployment rollback procedure** — cannot quickly revert bad deploy | P1 | Incident recovery slow |
| OP2-1 | **No load testing** — cannot verify capacity | P2 | Unknown scalability limits |
| OP2-2 | **No staging environment** — all changes tested on prod or locally | P2 | Risky deployments |

**Status:** ⚠️ **P0 + P1 blockers. Action: Add health checks + alerting immediately.**

---

## MISSING SAAS MODULES

### Module 1: Observability Layer ❌ **MISSING**

**Need:**
- ✅ Structured logging (Sentry exists partially, need Sentry SDK integration)
- ✅ Metrics collection (Prometheus format)
- ✅ Tracing (OpenTelemetry or Jaeger)
- ✅ Alerts (Slack, email, SMS)

**Current:**
- Partial: performance_monitor.js + error_handler.js exist but incomplete
- Missing: centralized log aggregation, metric exports, distributed tracing

**Blocker:** P1 — Cannot operate production without observability

---

### Module 2: Security Layer ❌ **PARTIALLY DONE**

**Need:**
- ✅ RBAC (role-based access control) — exists in auth but incomplete at route level
- ✅ Audit logs — **MISSING entirely**
- ✅ Rate limiting — exists globally, need endpoint-specific limits
- ✅ Session management — exists, verified in code
- ✅ Anomaly detection — **MISSING**

**Current:**
- Session mgmt: ✅ Firestore sessions + invalidation
- RBAC: ⚠️ Exists in auth but not enforced at routes
- Audit logs: ❌ No table, no logging
- Anomaly detection: ❌ Missing

**Blocker:** P0 — No audit trail for compliance

---

### Module 3: Job Queue ❌ **MISSING**

**Need:**
- Async job processing (order processing, notifications, exports, cleanup)
- Retries + exponential backoff
- Dead-letter queue (DLQ)
- Delayed jobs (schedule SMS/email for later)
- Job status tracking

**Current:**
- Cron jobs exist (cleanup, reconciliation, webhook-retry)
- But NO reliable job queue — jobs can be lost

**Blocker:** P0 — Production webhook/notification failures

---

### Module 4: Notification Engine ⚠️ **PARTIALLY DONE**

**Implemented:**
- ✅ Email: Resend (lib/email/*)
- ✅ SMS: Twilio (services/SmsService.dart)
- ✅ Push: FCM (PushNotificationService)
- ✅ WhatsApp: WhatsApp Business API (routes/whatsapp.js)

**Issues:**
- ❌ No notification queuing (notifications not retried if user offline)
- ❌ No preference management (users cannot opt-in/out of notification types)
- ❌ No delivery status tracking (cannot verify SMS delivered)
- ❌ No template management (notifications hardcoded in code)

**Blocker:** P1 — Notifications unreliable at scale

---

### Module 5: Admin Control Center ❌ **PARTIALLY DONE**

**Implemented:**
- ✅ Owner dashboard (team_room_screen.dart)
- ✅ Reports: daily business analyst narrative
- ✅ Operations console (operations routes)

**Missing:**
- ❌ Alerting dashboard (see alerts, acknowledge, assign)
- ❌ Override controls (skip approval, force state change, manual adjustments)
- ❌ User management (create/disable users, reset passwords)
- ❌ Analytics sandbox (run custom queries on analytics)
- ❌ System health console (Redis status, DB connections, service status)

**Blocker:** P2 — Ops cannot respond quickly to issues

---

### Module 6: AI Intelligence Layer ⚠️ **PARTIALLY DONE**

**Implemented:**
- ✅ Demand forecasting: `DemandForecastService` (services/DemandForecastService.dart)
- ✅ Reorder prediction: built into inventory logic
- ✅ Delivery intelligence: `DeliveryOptimizationService` (route optimization, assignment)
- ✅ Support chatbot: `SupportChatbotService` (conversation AI via Gemini)
- ✅ Business analyst: `businessAnalyst.ts` (daily narrative generation)

**Issues:**
- ⚠️ Services exist but activation/integration unclear
- ⚠️ Gemini API key required but not always present (fallback exists)
- ❌ No anomaly detection service visible
- ❌ No competitor intelligence automation
- ❌ No price optimization feedback loop

**Status:** P2 — Mostly done, needs integration audit

---

### Module 7: Analytics Engine ⚠️ **PARTIALLY DONE**

**Implemented:**
- ✅ Business KPIs: computed via `computeBusinessKPIs` (metrics.ts)
- ✅ Customer analytics: `SmartAnalyticsService` (customer segmentation)
- ✅ Operational metrics: inventory, delivery performance

**Missing:**
- ❌ No data warehouse (BigQuery, Snowflake, etc.)
- ❌ No BI tool integration (Tableau, Looker, Grafana)
- ❌ No custom KPI builder for owner
- ❌ No cohort analysis (customer groups by behavior)
- ❌ No attribution (which marketing channel drove revenue)

**Blocker:** P2 — Cannot build complex dashboards

---

## PRIORITY SUMMARY

### P0 Blockers (Production Risk — Build Now)

| ID | Item | Module |
|---|---|---|
| B0-1 | Structured logging | Backend |
| B0-2 | Request tracing | Backend |
| DB0-1 | Audit trail tables | Database |
| DB0-2 | Transaction isolation verification | Database |
| SF0-1 | Edge Function logging | Supabase |
| FB0-1 | Firestore RLS audit | Firebase |
| RD0-1 | Job queue implementation | Redis |
| OP0-1 | Health checks | DevOps |
| OP0-2 | Backup/restore procedures | DevOps |
| B1-4 | Endpoint rate limiting | Backend |
| MODULE-Security | Audit logs table | Security Layer |

**Total P0: 11 items**

---

### P1 Infrastructure (Core SAAS Capability)

| ID | Item | Module |
|---|---|---|
| B1-1 | Route-level auth middleware | Backend |
| B1-2 | Consistent error responses | Backend |
| B1-3 | Webhook retry + DLQ | Backend |
| B1-4 | Endpoint rate limiting | Backend |
| DB1-1 | Analytics schema completion | Database |
| DB1-2 | Full-text search indexes | Database |
| DB1-3 | Materialized views | Database |
| SF1-1 to SF1-3 | Edge Function versioning + monitoring | Supabase |
| FB1-1 to FB1-2 | FCM subscriptions + metrics | Firebase |
| RD1-1 to RD1-3 | Cache standardization + monitoring | Redis |
| FL1-1 to FL1-4 | Offline caching + analytics | Flutter |
| OP1-1 to OP1-4 | Secrets rotation + alerting + logs | DevOps |
| MODULE-Observability | Full stack | Observability |

**Total P1: 27+ items**

---

### P2 Intelligence & Optimization

| ID | Item | Module |
|---|---|---|
| B2-1, B2-2 | Dependency injection + graceful degradation | Backend |
| DB2-1 | Data warehouse | Database |
| RD2-1 | Persistent job queue | Redis |
| FL2-1, FL2-2 | Performance monitoring + unit tests | Flutter |
| OP2-1, OP2-2 | Load testing + staging environment | DevOps |
| MODULE-AI | Anomaly detection, competitor intel | AI Layer |
| MODULE-Analytics | BI tool integration, cohort analysis | Analytics |
| MODULE-Admin | Override controls, user management | Admin Control |

**Total P2: 15+ items**

---

## IMMEDIATE ACTIONS

**Phase 1 (THIS CYCLE):** Build P0 + critical P1

1. **Add structured logging** (Sentry SDK + Winston/Bunyan)
2. **Add request tracing** (correlation IDs + OpenTelemetry)
3. **Create audit tables** (PostgreSQL audit schema)
4. **Implement job queue** (Upstash QStash)
5. **Add health checks** (Render + Datadog)
6. **Implement route auth middleware** (require @role checks)

**Phase 2 (Next cycle):** P1 infrastructure

7. Observability full stack (logs + metrics + dashboards)
8. Firebase RLS audit + tests
9. Cache standardization
10. Alerting system

---

**END AUDIT FINDINGS**
