# FUFAJI PHASE C — EXECUTION LAYER ARCHITECTURE

**Status:** Implementation in progress  
**Target Quality:** 95+  
**Last Updated:** 2026-07-03  
**Integration:** AWS Lambda + Supabase + Firestore  

---

## 1. WORKER CLASS ARCHITECTURE

### Class A: Realtime Workers (<2 second SLA)

**Purpose:** Immediate consistency for critical operations  
**Trigger:** Supabase webhooks or API calls  
**Workers:**
- `syncInventoryToFirestore` — inventory → Firestore cache
- `replicateOrdersToSupabase` — orders Firestore → Supabase

**Configuration in template.yaml:**
- Runtime: nodejs20.x
- Timeout: 30s (Class A must complete in <2s, timeout for safety)
- Memory: 1024MB (larger = faster CPU)
- Reserved concurrency: 100 (avoid cold starts)

**Retry Strategy:**
- Attempt 1: immediate
- Attempt 2: 5s delay
- Attempt 3: 30s delay
- Max retries: 3 → then move to sync_dlq

---

### Class B: Scheduled Workers (5 min to 1 hour SLA)

**Purpose:** Consistent batch sync at scale  
**Trigger:** AWS EventBridge cron schedules  
**Workers:**
- `syncProductsToFirestore` — batch product sync (every 5 min)
- `refreshSearchCache` — FTS rebuild (every 1 hour)
- `detectDrift` — compare Firestore ↔ Supabase (every 5 min)

**Configuration in template.yaml:**
- Timeout: 300s (5 minutes)
- Memory: 2048MB (batch processing)
- Batch size: 500 items per sync

**Retry Strategy:**
- Automatic retry via EventBridge schedule (next cycle)
- Manual replay via `/sync/manual` API

---

### Class C: Recovery Workers (Best Effort)

**Purpose:** Manual recovery and cleanup  
**Trigger:** Manual API + periodic schedules  
**Workers:**
- `retryFailedSyncJobs` — re-process failed events (every 10 min)
- `processDeadLetterQueue` — manual/auto DLQ resolution (every 30 min)

**Configuration in template.yaml:**
- Timeout: 600s (10 minutes)
- Memory: 1024MB
- Focus: Correctness over speed

---

## 2. EVENT ROUTER ARCHITECTURE

**File:** `/backend/src/services/event-router.js`

Routes events to correct worker class based on:
- `event_type` (PRODUCT_UPDATED, INVENTORY_UPDATED, etc.)
- `source_system` (supabase, firestore, api)
- Batch size (single vs. bulk)

**Decision Tree:**
```
INVENTORY_UPDATED → Class A: syncInventoryToFirestore
ORDER_CREATED → Class A: replicateOrdersToSupabase
PRODUCT_UPDATED → Class B: syncProductsToFirestore (batch)
PRICE_CHANGED → Class B: syncProductsToFirestore
SEARCH_CACHE_STALE → Class B: refreshSearchCache
DRIFT_DETECTED → Class B: detectDrift
SYNC_FAILED → Class C: retryFailedSyncJobs
DLQ_ITEM_PENDING → Class C: processDeadLetterQueue
```

**Idempotency:**
- Check sync_events table for duplicate event_id_checksum
- If duplicate and completed → skip
- If duplicate and in-progress → skip (don't double-process)
- If new → process normally

---

## 3. INVENTORY RESERVATION & LOCKING

**File:** `/backend/src/services/inventory-locking.js`

**Dual-Layer Strategy:**

**Layer 1: Redis Distributed Lock**
- Key: `inventory:lock:{variantId}`
- TTL: 5 seconds (auto-release on crash)
- Tool: Upstash Redis (use existing connection)
- Timeout: 100ms (fail fast, fallback to Postgres)

**Layer 2: Postgres Row Lock**
- SQL: `SELECT FOR UPDATE inventory WHERE variant_id = ?`
- Ensures atomicity and prevents race conditions

**Flow:**
1. Try acquire Redis lock (100ms timeout)
2. If Redis down → fallback to Postgres-only (slower but safe)
3. SELECT FOR UPDATE inventory
4. Check available >= requested
5. UPDATE reserved
6. Insert to sync_events
7. Release locks

**Race Condition Prevention:**
- 10 concurrent requests for 5-item stock → 5 succeed, 5 fail (no oversell)
- Lock contention p99 < 500ms at 1000 writes/sec

---

## 4. API GATEWAY ROUTES

**File:** `/backend/src/routes/sync.js` (new)

**10 New Routes:**

| Method | Path | Purpose | Auth | SLA |
|--------|------|---------|------|-----|
| POST | `/sync/reserve` | Reserve stock | user | 500ms |
| POST | `/sync/release` | Release reservation | user | 500ms |
| POST | `/sync/confirm` | Confirm order | user/admin | 500ms |
| POST | `/sync/manual` | Trigger worker manually | admin | 30s |
| GET | `/sync/health` | Sync status dashboard | admin | 1s |
| GET | `/sync/workers` | Worker list + status | admin | 1s |
| GET | `/sync/dlq` | List DLQ items | admin | 2s |
| POST | `/sync/dlq/:id/resolve` | Resolve DLQ item | admin | 1s |
| POST | `/sync/dlq/:id/replay` | Replay DLQ item | admin | 30s |
| GET | `/sync/metrics` | Sync metrics (for Grafana) | admin | 1s |

---

## 5. 4-LAYER MONITORING

**Layer 1: Infrastructure Monitoring**
- Lambda errors, duration, memory, cold starts
- EventBridge job execution time
- API Gateway request count/latency
- Supabase/Firestore quota usage
- Redis connection status

**Layer 2: Worker Monitoring**
- Per-worker success rate, latency, retry count
- Class A: p99 latency < 2s, success rate > 99.95%
- Class B: p99 latency < 5min, success rate > 99.5%
- Class C: best effort, logged for review

**Layer 3: Sync Monitoring**
- Inventory drift % (Firestore vs Supabase)
- Stock mismatches (count)
- Order replication lag (seconds)
- Search cache staleness (hours)
- Failed syncs by event_type

**Layer 4: Business Impact**
- Oversells detected (P0 alert)
- Cancelled orders due to sync (count + $)
- Customer-facing errors (cart issues)
- Reservation expiry rate (%)

**Tools:**
- Prometheus for metrics collection
- Grafana for dashboards
- PagerDuty for escalation

---

## 6. KILL SWITCH SYSTEM (system_flags)

**File:** `/backend/src/services/system-flags.js` (new)

**Purpose:** Instant disable of broken workers without redeployment

**Database Table:**
```sql
CREATE TABLE system_flags (
  id SERIAL PRIMARY KEY,
  flag_name VARCHAR(100) UNIQUE,
  enabled BOOLEAN DEFAULT TRUE,
  reason TEXT,
  disabled_by VARCHAR(100),
  disabled_at TIMESTAMP,
  re_enable_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Required Flags:**
- `inventory_sync_enabled`
- `product_sync_enabled`
- `order_replication_enabled`
- `search_cache_refresh_enabled`
- `drift_detection_enabled`
- `retry_jobs_enabled`
- `dlq_processing_enabled`

**Worker Check:**
Every worker starts with:
```javascript
const { enabled } = await systemFlags.check('inventory_sync_enabled');
if (!enabled) {
  console.log('WORKER DISABLED - exiting gracefully');
  return { status: 'skipped', reason: 'worker_disabled' };
}
```

**Admin API:**
```
POST /sync/system-flags/:flag_name/disable
{ "reason": "deployment in progress" }

POST /sync/system-flags/:flag_name/enable
```

---

## 7. DEPLOYMENT SEQUENCE

**Step 1:** Deploy database schema (migration)
```bash
npm run migrate
```

**Step 2:** Deploy Lambda + routes
```bash
sam build
sam deploy --stack-name fufaji-phase-c
```

**Step 3:** Deploy Supabase webhook configuration
```bash
# Configure Supabase webhooks → Lambda Function URL
# Webhook events: PRODUCT_*, INVENTORY_*, ORDER_*
```

**Step 4:** Verify EventBridge schedules
- Check AWS console: all rules ENABLED
- Test manually: `aws events put-events --entries '[{"Source":"test"}]'`

**Step 5:** Smoke tests
```bash
curl https://<lambda-url>/health
curl https://<lambda-url>/sync/health
```

**Step 6:** Monitor first 30 minutes
- Watch Grafana dashboard
- Check PagerDuty for alerts

---

## 8. FILE STRUCTURE

```
/backend/src/
├── services/
│   ├── event-router.js          [NEW] Event routing logic
│   ├── inventory-locking.js     [NEW] Redis + Postgres locking
│   ├── system-flags.js          [NEW] Kill switch management
│   ├── sync-queue.js            [EXISTING - enhance]
│   └── SupabaseInventoryService.js  [EXISTING - enhance]
│
├── workers/
│   ├── sync-workers.js          [NEW] 7 worker functions
│   └── event-worker.js          [EXISTING - enhance]
│
├── routes/
│   ├── sync.js                  [NEW] 10 sync API endpoints
│   ├── system-flags.js          [NEW] Flag management routes
│   └── [existing]
│
├── db/
│   └── migrations/
│       └── 003-phase-c-schema.sql  [NEW] sync_events, sync_dlq, system_flags tables
│
├── app.js                        [UPDATE] Mount /sync and /system-flags routes
├── jobs.js                       [UPDATE] Add new job types
└── lambda.js                     [UPDATE] Route job events

/backend/
├── template.yaml                [UPDATE] Add EventBridge schedules for Class B/C
└── package.json                 [VERIFY] Dependencies already present
```

---

## 9. TESTING STRATEGY

**Unit Tests:**
- Inventory locking: concurrent reserve requests
- Event router: correct worker selection
- Idempotency: duplicate request handling

**Integration Tests:**
- Full sync pipeline: Supabase → Router → Worker → Firestore
- Failure recovery: DLQ movement and replay

**Concurrency Tests:**
- 10 concurrent reserves for 5-item stock → no overselling
- Lock contention p99 < 500ms

**Load Tests:**
- 1000 writes/sec sustained
- p99 latency < 2s (Class A), < 5min (Class B)

---

## 10. QUALITY TARGETS

| Metric | Target |
|--------|--------|
| **Latency** | |
| Class A p99 | < 2s |
| Class B p99 | < 5min |
| **Reliability** | |
| Class A success rate | 99.95% |
| Class B success rate | 99.5% |
| **Throughput** | |
| Sustained | 500 writes/sec |
| Burst | 2000 writes/sec (30s) |
| **Availability** | 99.9% uptime |

---

## NEXT STEPS

1. ✅ C2.1a: This architecture doc (complete)
2. ⏳ C2.1b: Implement event-router.js
3. ⏳ C2.1c: Implement inventory-locking.js + schema
4. ⏳ C2.1d: Implement sync.js routes + system-flags routes
5. ⏳ C2.1e: Create monitoring dashboard queries
6. ⏳ C2.1f: Create system-flags routes + table
7. ⏳ Integration + testing
8. ⏳ Deployment to production

---

**All code follows your existing patterns:**
- Services as classes
- Routes as Express handlers
- Jobs as async EventBridge functions
- Error handling via secrets + error_handler.js
- Database via Supabase + Firestore clients
