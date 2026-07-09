# Inventory Sync - Error Handling & Retry Strategy

## Architecture Principles

✅ **Idempotent:** Safe to run multiple times - uses `merge: true` on Firestore writes
✅ **Atomic per batch:** 450 products per Firestore batch transaction
✅ **Recoverable:** Partial failures don't block entire sync
✅ **Observable:** All errors logged to sync_logs table

---

## Error Classification

### Level 1: Function Initialization Errors (FATAL)

These stop the entire sync immediately.

#### 1.1 Missing Environment Variables

**Error:**
```
FIREBASE_SERVICE_ACCOUNT_JSON environment variable not set
```

**Cause:** Environment variable not configured in Supabase

**Recovery:**
1. Add to Supabase → Project Settings → Edge Functions → Secrets
2. Redeploy function
3. Retry manually

**SQL Diagnostic:**
```sql
-- Check last error in sync_logs
SELECT details FROM sync_logs 
WHERE status = 'error' 
ORDER BY created_at DESC LIMIT 1;
```

#### 1.2 Invalid Firebase Credentials

**Error:**
```
Error: Unable to parse service account certificate
```

**Cause:** Corrupted/invalid JSON in FIREBASE_SERVICE_ACCOUNT_JSON

**Recovery:**
```bash
# Regenerate Firebase service account
# 1. Go to Firebase Console → Project Settings → Service Accounts
# 2. Click "Generate New Private Key"
# 3. Copy full JSON
# 4. Update environment variable (escape quotes properly)
# 5. Redeploy function

supabase functions deploy sync-inventory-to-firestore
```

#### 1.3 Invalid Cron Secret

**Error:**
```
Unauthorized
```

**Cause:** X-Cron-Secret header missing or mismatched

**Recovery:**
- Verify scheduler is sending correct header
- Check secret matches environment variable
```bash
supabase secrets list | grep INVENTORY_SYNC_CRON_SECRET
```

---

### Level 2: Database Query Errors (RECOVERABLE)

These are retryable - function will log and exit gracefully.

#### 2.1 Supabase Connection Failure

**Error:**
```
Failed to fetch products: connection refused
```

**Cause:** Network issue, Supabase maintenance, or rate limit

**Recovery:**
- **Automatic:** Cron will retry on next cycle (5 min)
- **Manual:** Run sync again immediately
- **Escalation:** Check Supabase status page

**Retry Strategy:**
```
Attempt 1: Immediate
Attempt 2: +5 minutes (next cron)
Attempt 3: +5 minutes (cron again)
After 3 failures: Alert ops team
```

#### 2.2 Inventory Table Missing Data

**Error:**
```
Error processing product 123: Cannot read property 'available_quantity'
```

**Cause:** Product exists but inventory record is NULL/missing

**Recovery:**
```sql
-- Create missing inventory records
INSERT INTO public.inventory (product_id, quantity, reserved_quantity)
SELECT 
  p.id, 
  COALESCE(p.total_quantity, 0),
  COALESCE(p.reserved_quantity, 0)
FROM public.products p
LEFT JOIN public.inventory i ON p.id = i.product_id
WHERE i.id IS NULL
  AND p.deleted_at IS NULL;

-- Run sync again
curl -X POST https://your-project.supabase.co/functions/v1/sync-inventory-to-firestore \
  -H "X-Cron-Secret: your-secret"
```

#### 2.3 Query Timeout (>60 seconds)

**Error:**
```
Function killed after 60 seconds
```

**Cause:** Too many products or slow database

**Recovery:**
```sql
-- Add missing indexes
CREATE INDEX CONCURRENTLY idx_products_shop_deleted 
  ON public.products(shop_id, deleted_at);

CREATE INDEX CONCURRENTLY idx_inventory_product 
  ON public.inventory(product_id);

-- Or split sync by shop
-- Edit function to add: WHERE shop_id = $1
-- Create separate cron jobs per shop
```

---

### Level 3: Partial Sync Errors (NON-FATAL)

Individual products fail but sync continues.

#### 3.1 Invalid Firestore Document

**Error:**
```json
{
  "failed_count": 3,
  "errors": [
    { "product_id": "abc123", "reason": "Document size exceeds limit" }
  ]
}
```

**Cause:** Product data too large (>1MB), invalid characters, or circular reference

**Recovery:**
```sql
-- Check problematic product
SELECT id, name, gallery_images, json_array_length(gallery_images) as img_count
FROM public.products
WHERE id = 'abc123';

-- Trim gallery images if too many
UPDATE public.products
SET gallery_images = gallery_images[1:5]  -- Keep only first 5
WHERE id = 'abc123';

-- Sync will pick it up on next run (idempotent)
```

#### 3.2 Firestore Rate Limit

**Error:**
```
RESOURCE_EXHAUSTED: Too many requests for document (429)
```

**Cause:** Writing to same document too frequently

**Recovery:**
- **Automatic:** Firestore queues writes internally
- **Manual:** Increase time between syncs from 5 to 10 minutes
- **Long-term:** Reduce batch size from 450 to 300

```bash
# Update Cloud Scheduler / EasyCron
# Change cron from: */5 * * * *
# To:              */10 * * * *
```

#### 3.3 Firestore Authentication Error

**Error:**
```
Permission denied for collection: products
```

**Cause:** Service account doesn't have Firestore write permission

**Recovery:**
```
1. Firebase Console → Firestore → Rules
2. Add rule:
   match /products/{document=**} {
     allow read, write: if request.auth.uid != null;
   }
3. Or use service account auth (already configured)
4. Verify credentials have role: Editor or Cloud Datastore User
```

---

### Level 4: Data Consistency Errors (WARNING)

These don't stop sync but indicate potential issues.

#### 4.1 Mismatched Inventory

**Error:**
```
Warning: Product ABC has total_quantity=100 but inventory.quantity=80
```

**Cause:** Data inconsistency between products and inventory tables

**Prevention:**
```sql
-- Create trigger to keep in sync
CREATE OR REPLACE FUNCTION sync_inventory_quantity()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.inventory
  SET quantity = NEW.total_quantity
  WHERE product_id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_inventory_qty
AFTER UPDATE OF total_quantity ON public.products
FOR EACH ROW
EXECUTE FUNCTION sync_inventory_quantity();
```

#### 4.2 Deleted Products in Firestore

**Error:**
```
Warning: Synced 150 products but Firestore has 160
```

**Cause:** Old products deleted from PostgreSQL but not from Firestore

**Resolution:**
```sql
-- Find products in Firestore but deleted in PostgreSQL
-- Manual verification in Firebase Console

-- Then delete from Firestore:
const admin = require('firebase-admin');
const db = admin.firestore();

const deletedIds = ['id1', 'id2']; // From PostgreSQL

for (const id of deletedIds) {
  await db.collection('products').doc(id).delete();
}
```

---

## Monitoring & Alerting

### SQL Query: Recent Failures

```sql
SELECT 
  sync_type,
  status,
  failed_count,
  synced_at,
  details,
  EXTRACT(EPOCH FROM (NOW() - synced_at)) as seconds_ago
FROM public.sync_logs
WHERE sync_type = 'inventory_to_firestore'
  AND (status = 'error' OR (status = 'partial_failure' AND failed_count > 5))
ORDER BY synced_at DESC
LIMIT 20;
```

### SQL Query: Sync Health Trend

```sql
SELECT 
  DATE_TRUNC('hour', synced_at) as hour,
  COUNT(*) as sync_count,
  SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) as successes,
  SUM(CASE WHEN status != 'success' THEN 1 ELSE 0 END) as failures,
  AVG(synced_count) as avg_products_synced
FROM public.sync_logs
WHERE sync_type = 'inventory_to_firestore'
  AND synced_at > NOW() - INTERVAL '24 hours'
GROUP BY DATE_TRUNC('hour', synced_at)
ORDER BY hour DESC;
```

### Alert Thresholds

Set alerts in your monitoring system:

| Metric | Threshold | Action |
|--------|-----------|--------|
| Sync duration | > 30 seconds | Warning |
| Failed count | > 10 | Critical |
| No sync in 15 min | True | Critical |
| Error rate | > 5% | Warning |
| Firestore writes/sec | > 1000 | Warning |

---

## Retry Strategy

### Automatic Retries

The function does NOT implement internal retries. Instead, rely on cron scheduler:

```
Cron runs every 5 minutes
If sync fails, next run in 5 minutes automatically retries
Data is idempotent (merge: true prevents duplicates)
```

### Manual Retry

```bash
# Manually trigger sync immediately
curl -X POST https://your-project.supabase.co/functions/v1/sync-inventory-to-firestore \
  -H "Content-Type: application/json" \
  -H "X-Cron-Secret: your-secret"
```

### Exponential Backoff (if needed)

If implementing custom retry logic:

```typescript
// Add to index.ts
async function syncWithRetry(supabase, maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await syncInventoryToFirestore(supabase);
    } catch (error) {
      if (attempt === maxRetries) throw error;
      
      // Exponential backoff: 1s, 2s, 4s
      const delay = Math.pow(2, attempt - 1) * 1000;
      console.log(`Retry ${attempt}/${maxRetries} after ${delay}ms`);
      await new Promise(r => setTimeout(r, delay));
    }
  }
}
```

---

## Escalation Procedure

### Level 1: Auto-Recovery (Cron Retry)
- Sync fails
- Logged to sync_logs with status='error'
- Next cron run (5 min) auto-retries
- If same error occurs 3 times: → Level 2

### Level 2: Manual Investigation
- Check sync_logs for error details
- Run diagnostic SQL queries
- Check Firestore write permissions
- If fixable: Fix and manually trigger sync
- If not: → Level 3

### Level 3: Escalation
- Contact Supabase support (database issues)
- Contact Firebase support (Firestore issues)
- Check infra costs (if rate-limited)
- Consider architecture change (e.g., split by shop)

---

## Recovery Runbook

### Complete Sync Failure

```bash
# 1. Check what happened
psql -h $SUPABASE_HOST -U postgres -d postgres \
  -c "SELECT * FROM sync_logs ORDER BY created_at DESC LIMIT 5;"

# 2. Fix underlying issue (check Error Handling section)

# 3. Clear corrupted Firestore data if needed
node -e "
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();
db.collection('products').get()
  .then(snap => {
    let batch = db.batch();
    let count = 0;
    snap.forEach(doc => {
      batch.delete(doc.ref);
      count++;
      if (count % 450 === 0) {
        batch.commit();
        batch = db.batch();
      }
    });
    return batch.commit();
  })
  .then(() => console.log('Cleared all products'));
"

# 4. Redeploy function
supabase functions deploy sync-inventory-to-firestore

# 5. Manually trigger sync
curl -X POST https://your-project.supabase.co/functions/v1/sync-inventory-to-firestore \
  -H "X-Cron-Secret: your-secret"

# 6. Verify
psql -h $SUPABASE_HOST -U postgres -d postgres \
  -c "SELECT status, synced_count, failed_count FROM sync_logs WHERE sync_type='inventory_to_firestore' ORDER BY created_at DESC LIMIT 1;"
```

---

## Cost Optimization

### Firestore Write Costs

Current implementation: ~1000 writes per sync (1000 products)
Running every 5 minutes = 288 syncs/day = **288,000 writes/day**

Firestore pricing: $0.06 per 100K writes = **~$0.17/day** ✅ Cheap

### If costs spike:

1. Increase sync interval from 5 to 10 minutes (-50%)
2. Only sync if inventory changed (add triggers)
3. Split by shop (reduce batch size)

---

## Testing Error Scenarios

### Test Timeout

```bash
# Add artificial delay to index.ts
await new Promise(r => setTimeout(r, 65000)); // 65 seconds
supabase functions serve
# Should see: Function killed after 60 seconds
```

### Test Firebase Failure

```bash
# Corrupt Firebase credentials in .env.local
# Run local function
# Should see: Unable to parse service account certificate
```

### Test Partial Failure

```sql
-- Corrupt a product record
UPDATE public.products 
SET gallery_images = ARRAY['a'.repeat(1000000)]  -- 1MB string
WHERE id = 'test-id';

-- Run sync
# Should see: Document size exceeds limit error
# Other products synced successfully
```
