# Firestore Sync Engine — Fufaji LOOP 2

**Version:** 1.0  
**Purpose:** Synchronize data between Supabase (master) ↔ Firestore (operational cache)  
**Latency Targets:** Realtime < 2 sec | Scheduled < 5 min  
**Failure Handling:** Exponential backoff + Dead Letter Queue + Manual reconciliation  
**Consistency Model:** Strong consistency for inventory, eventual consistency for metadata  
**Production SLA:** 99.9% availability, < 5 min drift detection

---

## 1. Source of Truth Matrix (MANDATORY)

**This defines the absolute authority for each data domain.** No ambiguity allowed.

| Data Domain | Authority | Replica/Cache | Sync Direction | Read Source | Write Source | TTL |
|-------------|-----------|----------------|-----------------|-------------|--------------|-----|
| Products | Supabase | Firestore | Supabase → Firestore | App reads Firestore | Admin writes Supabase | 7 days |
| Variants | Supabase | Firestore | Supabase → Firestore | App reads Firestore | Admin writes Supabase | 7 days |
| Inventory | Supabase | Firestore | Supabase → Firestore | App reads Firestore | Staff writes Supabase | 5 min |
| Search Index | Supabase | Firestore | Supabase → Firestore | App reads Firestore | Backend only | 1 hour |
| Cart | **Firestore** | None | — | App reads Firestore | Customer writes Firestore | 24 hours |
| Orders | **Firestore** | Supabase (analytics) | Firestore → Supabase | App reads Firestore | Function writes Firestore | Never |

**Authority Rules:**
- ✅ Supabase masters are **absolutely authoritative**. Firestore copies are **caches only**. If divergence occurs, Supabase wins.
- ✅ Firestore-canonical data (carts, orders) never modifies Supabase originals. Only append-only sync (orders → analytics).
- ✅ No circular sync (A → B → A). Every domain has one-way direction.
- ✅ Write sources locked per domain. No exceptions. No client writes to Supabase-canonical data.

---

## 2. Sync Event Types

All sync operations emit one of these event types. This taxonomy prevents confusion about what's happening where.

### Product & Variant Events

```
PRODUCT_CREATED
PRODUCT_UPDATED
PRODUCT_SOFT_DELETED (is_deleted=true)
PRODUCT_RESTORED (is_deleted=false)
VARIANT_CREATED
VARIANT_UPDATED
VARIANT_DEACTIVATED
VARIANT_BARCODE_CHANGED
```

### Inventory Events

```
INVENTORY_CREATED (first stock entry for variant)
INVENTORY_STOCK_UPDATED (stock_total changed)
INVENTORY_RESERVED (stock_reserved changed)
INVENTORY_RELEASED (reservation cancelled)
INVENTORY_DAMAGED_UPDATED
INVENTORY_LOW_STOCK_ALERT (threshold crossed)
INVENTORY_PRICE_UPDATED
INVENTORY_RESTOCK_TRIGGERED
```

### Cart Events

```
CART_CREATED
CART_ITEM_ADDED
CART_ITEM_QUANTITY_CHANGED
CART_ITEM_REMOVED
CART_RESERVATION_CONFIRMED
CART_RESERVATION_EXPIRED
CART_ABANDONED
CART_CONVERTED_TO_ORDER
```

### Order Events

```
ORDER_CREATED
ORDER_PAYMENT_INITIATED
ORDER_PAYMENT_CONFIRMED
ORDER_PAYMENT_FAILED
ORDER_PACKED
ORDER_HANDED_TO_RIDER
ORDER_OUT_FOR_DELIVERY
ORDER_DELIVERED
ORDER_DELIVERY_ATTEMPTED (failed)
ORDER_CANCELLED
ORDER_REFUND_INITIATED
ORDER_REFUND_COMPLETED
```

### Search Events

```
SEARCH_CACHE_REFRESHED
SEARCH_TOKENS_UPDATED
SEARCH_INDEX_REINDEXED
```

### System Events

```
SYNC_STARTED
SYNC_COMPLETED
SYNC_FAILED
SYNC_RETRY
DRIFT_DETECTED
DRIFT_RESOLVED
IDEMPOTENCY_DEDUPLICATION (duplicate event ignored)
DLQ_ITEM_CREATED
DLQ_ITEM_RETRIED
DLQ_ITEM_ABANDONED
```

---

## 3. Realtime Sync Flows

Realtime syncs must complete in < 2 seconds from Supabase commit to Firestore write.

### 3.1 Inventory Update (Critical Path)

**Trigger:** Stock change in Supabase shop_inventory table  
**Latency Target:** < 2 seconds  
**SLA:** 99.9% success rate

```
Step 1: Staff/Rider updates inventory
  └─ SQL: UPDATE shop_inventory SET stock_total = 100 WHERE variant_id = ?

Step 2: PostgreSQL WAL emits row change event
  └─ Event: {op: 'UPDATE', table: 'shop_inventory', new: {...}, old: {...}}

Step 3: Supabase Realtime subscription captures event
  └─ Channel: 'supabase_realtime:public:shop_inventory'
  └─ Listener: Cloud Function (pub/sub topic: inventory-changes)

Step 4: Cloud Function processes event
  └─ Extract: {shopId, variantId, stockTotal, stockReserved, stockDamaged}
  └─ Compute: stockAvailable = MAX(stockTotal - stockReserved - stockDamaged, 0)
  └─ Build: eventId = UUID(), version = Supabase.updated_at.timestamp()
  └─ Check: Firestore.inventory[version] is not already present (idempotency)
  └─ If duplicate: SKIP with log "Deduplication: event already processed"
  └─ If fresh: CONTINUE

Step 5: Firestore batch update
  └─ Write: shops/{shopId}/inventory/{variantId}.update({
       stockTotal,
       stockReserved,
       stockAvailable,
       stockDamaged,
       updatedAt: now(),
       syncVersion: version,
       lastSupabaseSyncAt: now(),
       eventId (for dedup)
     })

Step 6: Realtime listeners (app) receive update
  └─ Trigger: onSnapshot(inventory_doc)
  └─ Callback: Update UI with new stock_available, isLowStock flag

Step 7: Log completion
  └─ Message: "✅ INVENTORY_STOCK_UPDATED: {shopId}/{variantId} v{version} in {latency}ms"
  └─ Metric: firestore_sync_latency_ms histogram
```

**Failure Mode:** If Function fails after Supabase write
- Pub/Sub retries automatically (3 times)
- If all retries fail → DLQ entry created
- Manual review + retry via admin endpoint

---

### 3.2 Order Status Update (Realtime)

**Trigger:** Rider or admin updates order status in Firestore  
**Latency Target:** < 1 second (internal app only)  
**No external sync:** Orders are Firestore-canonical. Supabase gets async replica.

```
Step 1: Rider app updates order status
  └─ Firestore: orders/{orderId}.update({
       orderStatus: 'OUT_FOR_DELIVERY',
       updatedAt: now()
     })

Step 2: Firestore write triggers Cloud Function (onWrite listener)
  └─ Listener: exports.onOrderStatusUpdate

Step 3: Function checks business rules
  └─ Validate: order exists, status transition valid
  └─ Check: Rider is assigned to this order
  └─ Check: Order is not already delivered/cancelled

Step 4: If valid, emit event to analytics queue
  └─ Pub/Sub: order-status-changes
  └─ Payload: {orderId, oldStatus, newStatus, timestamp, riderId}

Step 5: Async Cloud Function syncs to Supabase (separate queue)
  └─ Write: Supabase.orders table UPDATE
  └─ Insert: Supabase.analytics_events table INSERT
  └─ May take: 5-30 seconds (not realtime)

Step 6: Customer app listens to Firestore (realtime)
  └─ onSnapshot(orders/{orderId})
  └─ Update: "Your order is out for delivery"
  └─ Latency: < 500ms (internal Firestore only)
```

---

### 3.3 Cart Reservation (Realtime)

**Trigger:** Customer adds item to cart  
**Latency Target:** < 200ms  

```
Step 1: Customer adds item to cart
  └─ Firestore: carts/{userId}.update({
       items: [..., {variantId, qty: 2, price: 165}],
       reservedUntil: now() + 3hours
     })

Step 2: Firestore onWrite trigger
  └─ Function: validateAndReserveInventory()
  └─ Check: Firestore shops/{SHOP_ID}/inventory/{variantId}.stockAvailable >= qty
  └─ If false: REJECT cart add, throw error
  └─ If true: PROCEED

Step 3: Reserve in Supabase (async)
  └─ Pub/Sub: cart-reservation-events
  └─ Function: updateInventoryReservation()
  └─ SQL: UPDATE shop_inventory SET stock_reserved = stock_reserved + qty
  └─ Latency: 5-30 seconds (async)

Step 4: Cart item confirmed in Firestore
  └─ Mark: items[i].reservationConfirmed = true
  └─ Store: reservationId, expiresAt

Step 5: User sees item added instantly
  └─ Cart UI updates < 200ms (Firestore write is local + cloud fast)
```

---

## 4. Scheduled Sync Flows

Scheduled syncs run on fixed intervals. Freshness is guaranteed by TTL.

### 4.1 Product Sync (Every 5 Minutes)

**Trigger:** Cloud Scheduler (CRON: `*/5 * * * *`)  
**Latency Target:** < 5 minutes  
**Completeness:** All products synced

```
Step 1: Scheduler invokes Cloud Function
  └─ Function: syncProductsScheduled()
  └─ Interval: Every 5 minutes

Step 2: Query Supabase for updated products
  └─ Query: SELECT * FROM catalog_products
            WHERE updated_at > last_sync_time
            AND is_deleted = false
            LIMIT 500

Step 3: For each product, fetch variants
  └─ Query: SELECT * FROM catalog_variants
            WHERE product_id = ?
            AND is_active = true

Step 4: Batch write to Firestore
  └─ Collection: catalog_products/{productId}
  └─ Subcollection: variants/{variantId}
  └─ Write: merge (don't overwrite untouched fields)
  └─ Add: syncVersion = query_timestamp
  └─ Add: lastSupabaseSyncAt = now()

Step 5: Update sync metadata
  └─ Collection: _sync_metadata
  └─ Doc: products_last_sync
  └─ Set: {timestamp: now(), productsSynced: N, variantsSynced: M}

Step 6: Log metrics
  └─ Duration: sync completed in 4.2 seconds
  └─ Count: 127 products, 384 variants synced
  └─ Status: SUCCESS
```

**Failure Mode:** If sync fails
- Cloud Scheduler retries 3 times (automated)
- If all fail → DLQ + alert

---

### 4.2 Search Cache Sync (Every 1 Hour)

**Trigger:** Cloud Scheduler (CRON: `0 * * * *`)  
**Latency Target:** < 1 hour  

```
Step 1: Query Supabase search_index
  └─ Aggregate: GROUP BY category, token_type
  └─ Count: Frequency of each token
  └─ Sort: By weight DESC, frequency DESC

Step 2: For each category
  └─ Build: Top 20 products by popularity
  └─ Build: Top 10 search tokens (brand, product, alias)

Step 3: Write to search_cache
  └─ Doc: search_cache/{cacheId}
  └─ Format: {category, type, suggestions[], lastUpdatedAt}
  └─ TTL: 1 hour

Step 4: Done
  └─ Next sync: +1 hour
```

---

## 5. Conflict Resolution Rules (MANDATORY)

When data diverges between Supabase and Firestore, these rules determine the winner.

| Conflict Scenario | Data | Resolution | Rationale | SLA |
|------------------|------|------------|-----------|-----|
| Inventory mismatch | Supabase stock > Firestore stock | Firestore loses. Re-sync from Supabase. | Supabase is authoritative. | < 2 min |
| Inventory mismatch | Firestore stock > Supabase stock | Firestore loses. Re-sync from Supabase. | Could happen if Firestore write succeeded before Supabase. | < 2 min |
| Product price changed | Supabase price != Firestore price | Firestore loses. Re-sync from Supabase. | Pricing is authoritative in Supabase. | < 5 min |
| Cart reservation expired | Firestore reservedUntil < now() | Release reservation in Supabase. Clear cart item. | Reservation is time-bounded. | < 30 sec |
| Duplicate event (same eventId) | Multiple syncs of same change | Ignore via idempotency key. | Prevent double-counting inventory. | Immediate |
| Order replication duplicate | Same order inserted twice to Supabase | Upsert (ON CONFLICT UPDATE). | No duplicate orders in analytics. | < 1 min |
| Product deleted in Supabase | is_deleted = true | Soft-delete in Firestore (mark inactive). | Never hard-delete. Preserve history. | < 5 min |
| Rider location stale | Firestore location > 5 min old | Refresh from rider app immediately. | Location must be fresh for delivery. | < 10 sec |

**Conflict Resolution Algorithm:**

```javascript
function resolveConflict(supabaseData, firestoreData) {
  // Rule 1: If Supabase is authoritative, Supabase always wins
  if (isSupabaseAuthoritative(collection)) {
    return supabaseData;
  }
  
  // Rule 2: If Firestore is authoritative and Supabase is read-only, use Firestore
  if (isFirestoreAuthoritative(collection)) {
    return firestoreData;
  }
  
  // Rule 3: Timestamp rule (last write wins for timestamps)
  if (supabaseData.timestamp > firestoreData.timestamp) {
    return supabaseData;
  } else {
    return firestoreData;
  }
}
```

---

## 6. Drift Detection Rules (MANDATORY)

Drift = Firestore ≠ Supabase. Detected every 5 minutes.

| Data | Drift Threshold | Severity | Alert | Auto-Fix | TTL |
|------|-----------------|----------|-------|----------|-----|
| Inventory quantity | > 0 units difference | **P0 Critical** | Immediate Slack | Force re-sync | < 5 min |
| Inventory price | > 1 INR difference | P1 High | Email ops | Force re-sync | < 30 min |
| Product metadata | Any field mismatch | P2 Medium | Log only | Re-sync at next cycle | < 1 hour |
| Search cache | Stale > 1 hour | P3 Low | Log only | Re-sync at next cycle | < 1 hour |

**Drift Detection Algorithm:**

```javascript
async function detectDrift() {
  const shops = ['FUFAJI_MAIN_001']; // MVP
  
  for (const shopId of shops) {
    const firestoreInv = await firestore
      .collection('shops').doc(shopId)
      .collection('inventory').get();
    
    for (const doc of firestoreInv.docs) {
      const fData = doc.data();
      const variantId = doc.id;
      
      // Query Supabase
      const { data: sData } = await supabase
        .from('shop_inventory')
        .select('*')
        .eq('variant_id', variantId)
        .single();
      
      // Compute expected Firestore value
      const expectedAvailable = Math.max(
        sData.stock_total - sData.stock_reserved - sData.stock_damaged,
        0
      );
      
      // Check drift
      const drift = Math.abs(fData.stockAvailable - expectedAvailable);
      
      if (drift > 0) { // P0: Any mismatch is critical
        // Alert
        Sentry.captureMessage('DRIFT_DETECTED', 'error', {
          shopId, variantId, drift,
          firestore: fData.stockAvailable,
          expected: expectedAvailable
        });
        
        // Flag in Firestore
        await doc.ref.update({
          driftDetected: true,
          driftNotes: `Firestore: ${fData.stockAvailable}, Expected: ${expectedAvailable}`,
          driftDetectedAt: new Date()
        });
        
        // Auto-fix: Force re-sync
        await forceSyncInventory(shopId, variantId);
      }
    }
  }
}

// Run every 5 minutes
exports.detectDrift = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(detectDrift);
```

---

## 7. Idempotency Strategy (VERY IMPORTANT)

Every sync event must be idempotent. Duplicate events must NOT cause duplicate writes.

### Idempotency Key Structure

Every sync event carries:

```json
{
  "eventId": "uuid-v4-generated-by-source",
  "entityId": "product_id or order_id",
  "entityType": "product|variant|inventory|order|cart",
  "version": 1626283200,
  "timestamp": "2026-07-03T16:45:23Z",
  "checksum": "md5-hash-of-data"
}
```

### Idempotency Rules

| Rule | Implementation | Example |
|------|-----------------|---------|
| Event dedup by eventId | Store eventId in Firestore doc. Check before write. | `inventory.doc.eventId === current.eventId ? SKIP : WRITE` |
| Version check | If Firestore version >= incoming version, SKIP | Old sync arrives late, ignore it |
| Checksum verification | If data didn't change (same checksum), SKIP expensive write | Re-sync detects no change, noop |
| Last-writer-wins | If timestamps equal, use eventId alphabetical order | Deterministic without conflicts |

### Implementation

```javascript
async function syncWithIdempotency(collection, documentId, newData, idempotencyKey) {
  const docRef = firestore.collection(collection).doc(documentId);
  const currentDoc = await docRef.get();
  const current = currentDoc.data() || {};
  
  // Rule 1: If same eventId, skip (already processed)
  if (current.eventId === idempotencyKey.eventId) {
    console.log(`✅ DEDUP: Event ${idempotencyKey.eventId} already processed`);
    return { status: 'deduped', reason: 'Same eventId' };
  }
  
  // Rule 2: If incoming version is older, skip
  if (idempotencyKey.version < current.version) {
    console.log(`✅ DEDUP: Incoming version ${idempotencyKey.version} < current ${current.version}`);
    return { status: 'deduped', reason: 'Stale version' };
  }
  
  // Rule 3: If data unchanged (same checksum), skip
  if (idempotencyKey.checksum === current.checksum) {
    console.log(`✅ DEDUP: Data unchanged (checksum match)`);
    return { status: 'deduped', reason: 'Checksum match' };
  }
  
  // All checks passed: Write new data
  await docRef.update({
    ...newData,
    eventId: idempotencyKey.eventId,
    version: idempotencyKey.version,
    checksum: idempotencyKey.checksum,
    lastSyncAt: new Date()
  });
  
  return { status: 'written', version: idempotencyKey.version };
}
```

---

## 8. Retry & Dead Letter Queue Strategy

When sync fails, retry exponentially. If all retries fail, move to DLQ for manual review.

### Retry Policy

| Attempt | Delay | Backoff | Max Wait |
|---------|-------|---------|----------|
| 1 | Immediate | 1x | — |
| 2 | 5 sec | 2x | 5 sec |
| 3 | 30 sec | 6x | 30 sec |
| 4 | 5 min | 10x | 5 min |
| 5 | 30 min | 6x | 30 min |
| DLQ | Manual | — | ∞ |

**Formula:** `delay = min(base_delay * (2 ^ attempt), max_delay)`

### DLQ Entry Schema

```json
{
  "id": "dlq-entry-uuid",
  "failedSyncId": "event-uuid",
  "collection": "inventory",
  "documentId": "variant-id",
  "payload": { ... },
  "error": "Connection timeout: DEADLINE_EXCEEDED",
  "errorCode": "DEADLINE_EXCEEDED",
  "retryCount": 5,
  "attempts": [
    { "attempt": 1, "timestamp": "2026-07-03T16:45:00Z", "error": "timeout" },
    { "attempt": 2, "timestamp": "2026-07-03T16:45:05Z", "error": "timeout" }
  ],
  "firstFailedAt": "2026-07-03T16:45:00Z",
  "lastFailedAt": "2026-07-03T16:50:30Z",
  "status": "pending|acknowledged|resolved|abandoned",
  "resolutionNotes": null
}
```

### DLQ Handling

```javascript
async function handleFailedSync(error, event) {
  const dlqEntry = {
    id: uuid(),
    failedSyncId: event.eventId,
    collection: event.collection,
    documentId: event.documentId,
    payload: event.data,
    error: error.message,
    errorCode: error.code,
    retryCount: event.retryCount,
    firstFailedAt: new Date(),
    lastFailedAt: new Date(),
    status: 'pending'
  };
  
  // Save to DLQ
  await firestore.collection('_dlq').doc(dlqEntry.id).set(dlqEntry);
  
  // Alert operations
  await alertOps({
    type: 'SYNC_DLQ_ENTRY',
    message: `Sync failed after 5 retries: ${event.collection}/${event.documentId}`,
    dlqId: dlqEntry.id,
    error: error.message,
    severity: 'high'
  });
  
  // Link for manual retry
  console.log(`Manual retry: POST /admin/dlq/retry?id=${dlqEntry.id}`);
}

// Admin endpoint to retry
async function retryDLQEntry(dlqId) {
  const dlqEntry = await firestore.collection('_dlq').doc(dlqId).get();
  
  if (!dlqEntry.exists) {
    throw new Error('DLQ entry not found');
  }
  
  try {
    // Retry the sync
    await performSync(dlqEntry.data().payload);
    
    // Mark resolved
    await firestore.collection('_dlq').doc(dlqId).update({
      status: 'resolved',
      resolutionNotes: 'Manual retry successful'
    });
  } catch (error) {
    // Still failing, update with latest error
    await firestore.collection('_dlq').doc(dlqId).update({
      lastFailedAt: new Date(),
      error: error.message
    });
    throw error;
  }
}
```

---

## 9. Monitoring & Alerts (MANDATORY)

Production sync requires continuous monitoring.

### Key Metrics & Thresholds

| Metric | Calculation | Target | Alert Threshold | Severity |
|--------|-------------|--------|-----------------|----------|
| Realtime Sync Latency | P99 latency (inventory updates) | < 2 sec | > 5 sec | P1 |
| Scheduled Sync Duration | Time to complete product sync | < 5 min | > 10 min | P2 |
| Sync Success Rate | (Successful syncs) / (Total syncs) | 99.9% | < 99% | P1 |
| DLQ Queue Depth | Count of pending items in DLQ | 0 | > 10 | P2 |
| Drift Detection Count | Drifts detected per hour | 0 | > 1 | P0 |
| Idempotency Dedup Rate | Duplicates caught per hour | Varies | Trend increase = bug | P3 |

### Monitoring Implementation

```javascript
// Publish metrics to Cloud Monitoring
const metric = new google.monitoring.v3.MetricServiceClient();

async function recordSyncMetric(metricName, value, labels) {
  const projectName = metric.projectPath('fufaji-store');
  
  const timeSeries = {
    metric: {
      type: `custom.googleapis.com/firestore_sync/${metricName}`,
      labels: labels
    },
    points: [
      {
        interval: {
          endTime: { seconds: Math.floor(Date.now() / 1000) }
        },
        value: { doubleValue: value }
      }
    ]
  };
  
  await metric.createTimeSeries({
    name: projectName,
    timeSeries: [timeSeries]
  });
}

// Example: Record sync latency
await recordSyncMetric('sync_latency_ms', 1250, {
  collection: 'inventory',
  status: 'success'
});
```

### Alert Rules (Stackdriver)

```yaml
Alerts:
  - name: "High Realtime Sync Latency"
    metric: "firestore_sync/sync_latency_ms"
    filters: { collection: "inventory" }
    condition: "p99 > 5000"
    duration: "5 minutes"
    notification: "slack:#fufaji-alerts"
    
  - name: "High DLQ Queue Depth"
    metric: "firestore_sync/dlq_queue_depth"
    condition: "value > 10"
    duration: "10 minutes"
    notification: "email:ops@fufaji.com"
    
  - name: "Inventory Drift Detected"
    metric: "firestore_sync/drift_count"
    condition: "value > 0"
    duration: "1 minute"
    notification: "sentry:fufaji-critical"
```

---

## 10. Production Guarantees (MANDATORY)

These are hard SLAs. Failures mean paging ops.

### Availability & Latency Guarantees

| Guarantee | SLA | Measurement | Breach Action |
|-----------|-----|-------------|----------------|
| Inventory data freshness | < 5 min stale | (max_firestore_sync_time - max_supabase_change_time) | Page ops if > 5 min |
| Realtime sync success | 99.9% uptime | (successful_syncs / total_syncs) per hour | Alert if < 99.8% |
| Order visibility latency | < 500ms to customer | Time from order creation to app display | Track P99 latency |
| Cart reservation consistency | 100% (no double-sells) | (reserved_inventory == cart_items) | Critical: never allow oversell |
| Search freshness | < 1 hour | (now - last_sync) on search_cache | Low priority if stale |

### Consistency Guarantees

| Guarantee | Rule | Enforcement | Failure Impact |
|-----------|------|------------|-----------------|
| No overselling inventory | Firestore + Supabase combined reserved ≤ total | Validate at checkout time | Order creation fails (safe) |
| No duplicate orders | Order upserted by orderId | Idempotent writes with eventId | Same order appears once |
| Cart items always have stock | Cart validation against Firestore inventory | Reject add-to-cart if no stock | Cart operation fails (safe) |
| Prices never increase in checkout | Price locked at cart-add time | Store price in cart item | Customer charged agreed price |

### Recovery Time Objectives (RTO)

| Failure Scenario | Detection Time | Recovery Time | Total RTO |
|-----------------|-----------------|---------------|----------|
| Realtime sync offline | < 5 min | 5-10 min (restart function) | < 15 min |
| Scheduled sync failed | < 10 min | 5 min (retry) | < 15 min |
| Inventory drift | < 5 min | 2 min (force re-sync) | < 7 min |
| Widespread data mismatch | < 30 min | 15 min (full reconciliation) | < 45 min |
| DLQ backlog | < 60 min | 30 min (manual resolution) | < 90 min |

---

## 11. Sync Status Dashboard

For ops team to monitor sync health in real-time.

**Dashboard Panels:**

1. **Sync Latency (Last 24h)**
   - Chart: P50, P95, P99 realtime sync latency
   - Alert zones: Green (< 2s), Yellow (2-5s), Red (> 5s)

2. **Sync Success Rate (Last 24h)**
   - Gauge: % successful syncs
   - Target: 99.9%
   - Alert if below 99%

3. **DLQ Queue Depth**
   - Counter: Pending items awaiting retry
   - Alert: > 10 items
   - Link: Retry all

4. **Drift Detections (Last 24h)**
   - Counter: Drifts found
   - Breakdown: By collection (inventory, products, etc.)
   - Alert: Any drift = critical

5. **Last Sync Times**
   - Inventory: Last synced 2 min ago ✅
   - Products: Last synced 4 min ago ✅
   - Search: Last synced 31 min ago ✅

---

## 12. Production Deployment Checklist

- [ ] Supabase webhooks configured & tested
- [ ] Pub/Sub topics created (inventory-changes, order-status-changes, firestore-scheduled-sync)
- [ ] Cloud Functions deployed (all 8 functions)
- [ ] Cloud Scheduler jobs created (every 5 min products, every 1 hour search)
- [ ] Firestore collections created (_dlq, _sync_metadata)
- [ ] Firestore indexes created (per firestore_indexes.json)
- [ ] Monitoring dashboards created (Stackdriver)
- [ ] Alert policies created (all 5 alerts)
- [ ] Sentry project linked for error tracking
- [ ] DLQ admin endpoint deployed
- [ ] Manual reconciliation runbook documented
- [ ] Tested: Realtime sync < 2 sec with traffic
- [ ] Tested: Scheduled sync completes in < 5 min
- [ ] Tested: DLQ retry succeeds after first failure
- [ ] Tested: Drift detection catches mismatch
- [ ] Tested: Idempotency dedup works (duplicate events ignored)
- [ ] Load test: 100+ concurrent users
- [ ] Rollback plan: Revert functions, restore backup
- [ ] War room contact list established

---

**End of Documentation**
