# Inventory Sync Function - Testing Guide

## Local Testing

### Prerequisites
```bash
npm install -g supabase
supabase projects list
supabase link --project-ref your-project-id
```

### Test 1: Local Server + Curl

```bash
# Terminal 1: Start local Supabase and Edge Functions
cd supabase
supabase functions serve --env-file functions/sync-inventory-to-firestore/.env.local

# Terminal 2: Test the function
curl -X POST http://localhost:54321/functions/v1/sync-inventory-to-firestore \
  -H "Content-Type: application/json" \
  -H "X-Cron-Secret: test-secret-123" \
  -d '{}'
```

Expected response:
```json
{
  "timestamp": "2026-07-09T12:00:00.000Z",
  "total_products": 150,
  "synced_count": 150,
  "failed_count": 0,
  "errors": [],
  "duration_ms": 2345
}
```

### Test 2: Authentication Failures

**Test missing secret:**
```bash
curl -X POST http://localhost:54321/functions/v1/sync-inventory-to-firestore \
  -H "Content-Type: application/json" \
  -d '{}'
```

Expected: 401 Unauthorized

**Test wrong secret:**
```bash
curl -X POST http://localhost:54321/functions/v1/sync-inventory-to-firestore \
  -H "Content-Type: application/json" \
  -H "X-Cron-Secret: wrong-secret" \
  -d '{}'
```

Expected: 401 Unauthorized

### Test 3: Verify Sync Data in Firestore

After successful sync, check Firestore:

```javascript
// Use Firebase Console → Firestore → products collection
// Or via Node.js:
const admin = require('firebase-admin');
const serviceAccount = require('./firebase-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

db.collection('products').limit(5).get()
  .then(snapshot => {
    snapshot.forEach(doc => {
      console.log(doc.id, '=>', doc.data());
    });
  });
```

Expected output (sample):
```
product-id-123 => {
  id: 'product-id-123',
  name: 'Tomato Fresh',
  price: 45.00,
  available_stock: 150,
  reserved_stock: 20,
  sold_stock: 30,
  synced_at: '2026-07-09T12:00:00Z',
  source: 'postgresql'
}
```

---

## Production Testing

### Test 1: Deploy to Staging

```bash
supabase functions deploy sync-inventory-to-firestore --project-ref staging-project-id
```

Verify deployment:
```bash
supabase functions describe sync-inventory-to-firestore --project-ref staging-project-id
```

### Test 2: Manual Trigger

```bash
curl -X POST https://staging-project.supabase.co/functions/v1/sync-inventory-to-firestore \
  -H "Content-Type: application/json" \
  -H "X-Cron-Secret: your-cron-secret-here" \
  -d '{}'
```

### Test 3: Check Logs

In Supabase Dashboard → Functions → sync-inventory-to-firestore → Invocations

Look for:
- Status: 200 (success) or 500 (error)
- Duration: Should be < 60 seconds
- Response: Check for any errors

### Test 4: Verify Data Consistency

Run SQL query to verify:
```sql
-- Check product count
SELECT COUNT(*) as product_count FROM public.products WHERE deleted_at IS NULL;

-- Check inventory levels
SELECT 
  p.id,
  p.name,
  p.total_quantity,
  p.reserved_quantity,
  i.quantity,
  i.reserved_quantity,
  i.available_quantity
FROM public.products p
LEFT JOIN public.inventory i ON p.id = i.product_id
WHERE p.deleted_at IS NULL
LIMIT 10;

-- Check sync logs
SELECT 
  sync_type,
  status,
  synced_count,
  failed_count,
  synced_at,
  details
FROM public.sync_logs
WHERE sync_type = 'inventory_to_firestore'
ORDER BY synced_at DESC
LIMIT 5;
```

### Test 5: Load Testing

For 1000+ products, simulate load:

```bash
#!/bin/bash
# test-load.sh - Run sync 10 times in parallel
for i in {1..10}; do
  curl -X POST https://your-project.supabase.co/functions/v1/sync-inventory-to-firestore \
    -H "Content-Type: application/json" \
    -H "X-Cron-Secret: your-cron-secret-here" \
    -d '{}' &
done
wait
echo "Load test complete"
```

Monitor:
- Firestore write throughput (should be < 10,000 writes/sec)
- Supabase database connection pool
- Edge Function memory usage

---

## Error Scenarios & Recovery

### Scenario 1: Firestore Service Account Invalid

**Error log:**
```
Error: Unable to parse service account certificate: Error: Error parsing key
```

**Fix:**
1. Regenerate Firebase service account JSON
2. Ensure entire JSON is escaped properly as environment variable
3. Test credentials separately

### Scenario 2: Product Inventory Null/Missing

**Error log:**
```
Error processing product 123e4567-e89b-12d3-a456-426614174000: Cannot read property 'available_quantity' of undefined
```

**Fix:**
- Ensure inventory table has records for all products
- Run migration to create missing inventory records:
  ```sql
  INSERT INTO public.inventory (product_id, quantity, reserved_quantity)
  SELECT id, total_quantity, reserved_quantity FROM public.products p
  WHERE NOT EXISTS (SELECT 1 FROM public.inventory i WHERE i.product_id = p.id)
  ```

### Scenario 3: Timeout (>60 seconds)

**Error:** Function killed after 60 seconds

**Causes:**
- Too many products (>10,000)
- Slow database query
- Firestore throughput exceeded

**Fix:**
- Split by shop: `SELECT ... WHERE shop_id = $1`
- Increase batch size to 500 (if not hitting Firestore limits)
- Add index: `CREATE INDEX idx_products_shop_deleted ON products(shop_id, deleted_at)`

### Scenario 4: Partial Failure (Some Products Not Synced)

**Error log:**
```json
{
  "failed_count": 5,
  "errors": [
    { "product_id": "abc123", "reason": "Invalid inventory data" }
  ]
}
```

**Fix:**
- Check sync_logs.details for specific errors
- Manually update failed products
- Implement retry logic in next cron run (already idempotent with `merge: true`)

---

## Monitoring Dashboard SQL

Create a view for ops team:

```sql
CREATE OR REPLACE VIEW inventory_sync_health AS
SELECT 
  'Last Sync Status' as metric,
  CASE 
    WHEN (SELECT status FROM sync_logs WHERE sync_type = 'inventory_to_firestore' ORDER BY synced_at DESC LIMIT 1) = 'success' 
      THEN 'Healthy'
    ELSE 'Failed'
  END as value,
  (SELECT synced_at FROM sync_logs WHERE sync_type = 'inventory_to_firestore' ORDER BY synced_at DESC LIMIT 1) as timestamp
UNION ALL
SELECT 
  'Last Sync Duration (seconds)',
  CAST(ROUND((SELECT (synced_at - created_at) * INTERVAL '1 second' FROM sync_logs 
    WHERE sync_type = 'inventory_to_firestore' ORDER BY synced_at DESC LIMIT 1)) as TEXT),
  (SELECT synced_at FROM sync_logs WHERE sync_type = 'inventory_to_firestore' ORDER BY synced_at DESC LIMIT 1)
UNION ALL
SELECT 
  'Total Products',
  CAST(COUNT(*) as TEXT),
  NOW()
FROM public.products
WHERE deleted_at IS NULL;
```

Query it:
```sql
SELECT * FROM inventory_sync_health;
```

---

## Rollback Procedure

If sync causes issues:

1. **Disable scheduler:**
   - Google Cloud Scheduler: Pause job
   - EasyCron: Disable cron job
   - GitHub Actions: Delete workflow

2. **Clear Firestore (if needed):**
   ```javascript
   // Delete all products from Firestore
   const admin = require('firebase-admin');
   const db = admin.firestore();
   
   const batch = db.batch();
   const docs = await db.collection('products').limit(100).get();
   
   docs.forEach(doc => batch.delete(doc.ref));
   await batch.commit();
   ```

3. **Redeploy fixed version:**
   ```bash
   supabase functions deploy sync-inventory-to-firestore
   ```

4. **Re-enable scheduler**

---

## Performance Benchmarks

### Expected Metrics (1000 products):
- **Duration:** 2-5 seconds
- **Firestore writes:** ~1000 operations
- **PostgreSQL queries:** 1-2 queries
- **Edge Function memory:** ~256MB

### If slower than expected:
- Check PostgreSQL slow query log
- Verify Firestore is not throttled
- Check Edge Function logs for details

---

## Debugging

### Enable verbose logging (local)

Edit `index.ts`:
```typescript
// Add more console.log calls
console.log("Starting sync at", new Date());
console.log("Fetched", products.length, "products");
products.forEach(p => {
  console.log("Syncing:", p.id, p.name);
});
```

Serve locally:
```bash
supabase functions serve --env-file .env.local
```

Logs appear in terminal.

### Remote debugging

Check Supabase dashboard:
1. Functions → sync-inventory-to-firestore
2. Invocations tab
3. Click on failed invocation
4. View logs

---

## Test Checklist

- [ ] Local function runs successfully
- [ ] Authentication (secret) works
- [ ] Test data appears in Firestore
- [ ] sync_logs table records event
- [ ] Edge function deployed to production
- [ ] Cron scheduler configured and tested
- [ ] Manual cron trigger succeeds
- [ ] Firestore shows updated data
- [ ] Monitoring alerts configured
- [ ] Rollback procedure documented and tested
