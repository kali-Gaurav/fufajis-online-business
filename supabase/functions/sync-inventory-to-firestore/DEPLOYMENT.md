# Inventory Sync Function - Deployment & Setup Guide

## Function Overview

**Path:** `/supabase/functions/sync-inventory-to-firestore/`
**Type:** Supabase Edge Function (TypeScript/Deno)
**Trigger:** HTTP (external cron scheduler)
**Frequency:** Every 5 minutes
**Purpose:** Sync product inventory from Supabase PostgreSQL → Firestore (read-only cache)

---

## Prerequisites

1. **Supabase Project** - with PostgreSQL database
2. **Firebase Project** - with Firestore
3. **Firebase Admin SDK Credentials** - service account JSON
4. **External Cron Service** - Cloud Scheduler, EasyCron, or similar
5. **Environment Variables** - configured in Supabase

---

## Step 1: Set Environment Variables

Add to your Supabase project settings (Project Settings → Edge Functions → Secrets):

```bash
FIREBASE_SERVICE_ACCOUNT_JSON="<paste full service account JSON here>"
INVENTORY_SYNC_CRON_SECRET="generate-strong-random-secret-here"
```

To generate a secure secret:
```bash
openssl rand -base64 32
```

---

## Step 2: Deploy the Edge Function

### Option A: Using Supabase CLI

```bash
cd supabase/functions
supabase functions deploy sync-inventory-to-firestore
```

Verify deployment:
```bash
supabase functions list
```

You should see:
```
sync-inventory-to-firestore  https://your-project-id.supabase.co/functions/v1/sync-inventory-to-firestore
```

### Option B: Deploy via Supabase Dashboard

1. Go to Supabase Dashboard → Functions
2. Click "Create a new function"
3. Select "Sync Inventory to Firestore"
4. Copy and paste the code from `index.ts`
5. Deploy

---

## Step 3: Test the Edge Function

### Test 1: Local Testing (Before Deployment)

```bash
supabase functions serve --env-file .env.local
```

Then curl the function:
```bash
curl -X POST http://localhost:54321/functions/v1/sync-inventory-to-firestore \
  -H "Content-Type: application/json" \
  -H "X-Cron-Secret: your-cron-secret-here"
```

### Test 2: Production Testing (After Deployment)

```bash
curl -X POST https://your-project.supabase.co/functions/v1/sync-inventory-to-firestore \
  -H "Content-Type: application/json" \
  -H "X-Cron-Secret: your-cron-secret-here"
```

Expected response (success):
```json
{
  "timestamp": "2026-07-09T12:00:00Z",
  "total_products": 150,
  "synced_count": 150,
  "failed_count": 0,
  "errors": [],
  "duration_ms": 2345
}
```

---

## Step 4: Set Up HTTP Cron Scheduler

### Option A: Google Cloud Scheduler (Recommended)

**Pros:** Free tier available, reliable, integrated with GCP
**Cons:** Requires GCP project

1. Go to Google Cloud Console → Cloud Scheduler
2. Click "Create Job"
3. Configure:
   - **Name:** `fufaji-inventory-sync-5min`
   - **Frequency:** `*/5 * * * *` (every 5 minutes)
   - **Timezone:** Asia/Kolkata (or your timezone)
   - **HTTP method:** POST
   - **URL:** `https://your-project.supabase.co/functions/v1/sync-inventory-to-firestore`
   - **Auth header:** Add OIDC token (if using GCP auth) OR custom header

4. Add custom header:
   - **Header name:** `X-Cron-Secret`
   - **Header value:** `your-cron-secret-here`

5. Set **Retry policy:** 3 retries with 5-minute backoff
6. Click Create

**Cron Expression:** `*/5 * * * *`
- Field 1 (minute): `*/5` = every 5 minutes
- Field 2 (hour): `*` = every hour
- Field 3 (day): `*` = every day
- Field 4 (month): `*` = every month
- Field 5 (dow): `*` = every day of week

---

### Option B: EasyCron (Free Alternative)

1. Go to https://www.easycron.com/
2. Sign up for free account
3. Click "Cron Jobs" → "Create Cron Job"
4. Configure:
   - **URL:** `https://your-project.supabase.co/functions/v1/sync-inventory-to-firestore`
   - **Cron expression:** `*/5 * * * *`
   - **HTTP method:** POST
   - **HTTP Basic Auth:** Disable
   - **Custom HTTP Headers:**
     ```
     X-Cron-Secret: your-cron-secret-here
     Content-Type: application/json
     ```
   - **Request body:** `{}` (empty)
   - **Alert email:** your-email@example.com (for failures)

5. Save and activate

---

### Option C: GitHub Actions (Self-Hosted Alternative)

Create `.github/workflows/inventory-sync.yml`:

```yaml
name: Inventory Sync Cron

on:
  schedule:
    - cron: '*/5 * * * *'  # Every 5 minutes

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Inventory Sync
        run: |
          curl -X POST https://your-project.supabase.co/functions/v1/sync-inventory-to-firestore \
            -H "Content-Type: application/json" \
            -H "X-Cron-Secret: ${{ secrets.INVENTORY_SYNC_CRON_SECRET }}" \
            -d '{}'
        env:
          INVENTORY_SYNC_CRON_SECRET: ${{ secrets.INVENTORY_SYNC_CRON_SECRET }}
```

Add to GitHub Secrets:
```
INVENTORY_SYNC_CRON_SECRET = your-cron-secret-here
```

---

## Step 5: Error Handling & Monitoring

### View Sync Logs in Supabase

```sql
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
LIMIT 10;
```

### Alert on Failures

**SQL Query** (run this to create an alert view):

```sql
CREATE OR REPLACE VIEW sync_failures AS
SELECT 
  sync_type,
  synced_at,
  failed_count,
  details,
  EXTRACT(EPOCH FROM (NOW() - synced_at)) as age_seconds
FROM public.sync_logs
WHERE status = 'error' 
  OR (status = 'partial_failure' AND failed_count > 5)
ORDER BY synced_at DESC;
```

Query failures:
```sql
SELECT * FROM sync_failures WHERE age_seconds < 300; -- Last 5 mins
```

### Monitoring Best Practices

1. **Check sync logs** every morning
2. **Set alerts** if failed_count > 10 for any single sync
3. **Check Firestore** - verify products are updated with current prices/stock
4. **Watch Edge Function logs** in Supabase dashboard

---

## Step 6: Troubleshooting

### Issue: 401 Unauthorized

**Cause:** Missing or incorrect `X-Cron-Secret` header
**Fix:** Verify the secret matches between scheduler config and environment variable

```bash
# Check current secret in Supabase
supabase secrets list
```

### Issue: Timeouts

**Cause:** Too many products (>1000), Firestore batch write limits
**Fix:** 
- Increase Edge Function timeout in `supabase/config.toml`:
  ```toml
  [functions."sync-inventory-to-firestore"]
  memory_size = 1024
  timeout_sec = 60  # Increase from default 60
  ```
- Reduce batch size in function (already set to 450)

### Issue: Products Not Appearing in Firestore

**Cause:** Firebase credentials invalid or Firestore not initialized
**Fix:**
```bash
# Test Firebase connection manually
node -e "
const admin = require('firebase-admin');
const sa = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
admin.initializeApp({ credential: admin.credential.cert(sa) });
admin.firestore().collection('products').limit(1).get()
  .then(snap => console.log('Connected:', snap.size, 'docs'))
  .catch(e => console.error('Error:', e.message));
"
```

### Issue: High Latency (>10 seconds per sync)

**Cause:** Large product catalog (1000+), Firestore throughput limits
**Fix:**
- Split into multiple sync functions (one per shop)
- Reduce sync frequency (every 10 minutes instead of 5)
- Add Firestore index on `shop_id` and `synced_at`

---

## Step 7: Production Checklist

- [ ] Edge function deployed and tested
- [ ] Environment variables configured (FIREBASE_SERVICE_ACCOUNT_JSON, INVENTORY_SYNC_CRON_SECRET)
- [ ] sync_logs table migrated
- [ ] HTTP cron scheduler configured (Cloud Scheduler / EasyCron / GitHub Actions)
- [ ] Cron secret secure and not exposed
- [ ] Test sync completed successfully (check sync_logs table)
- [ ] Firestore products collection verified with updated data
- [ ] Alert/monitoring in place for failed syncs
- [ ] Documentation shared with team

---

## Step 8: Scaling Considerations

### For 1,000-10,000 Products

- Current implementation: ✅ Works fine
- Batch size: 450 (can increase to 500 if needed)
- Recommended frequency: Every 5 minutes

### For 10,000+ Products

- **Recommended:** Split by shop_id
- Create separate function: `sync-inventory-shop-specific`
- Run each shop sync serially (prevents Firestore write conflicts)
- Increase sync frequency check to 15 minutes

---

## Maintenance

### Weekly
- Check sync_logs for errors
- Verify sync duration is < 60 seconds

### Monthly
- Review Firestore write costs
- Audit failed syncs and resolve any recurring issues

### Quarterly
- Review batch size efficiency
- Consider performance optimizations based on growth

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Cron Scheduler (Every 5 min)             │
│            (Cloud Scheduler / EasyCron / GitHub Actions)     │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
                   ┌──────────────────┐
                   │  Edge Function   │
                   │   (Deno/TS)      │
                   └─────────┬────────┘
                             │
                ┌────────────┴────────────┐
                ▼                         ▼
        ┌─────────────────┐       ┌──────────────────┐
        │   PostgreSQL    │       │   Firebase       │
        │   (Source)      │       │   Firestore      │
        │   - products    │───────│   (Read Cache)   │
        │   - inventory   │       │   - products/*   │
        └─────────────────┘       └──────────────────┘
                                           │
                                           ▼
                                  ┌──────────────────┐
                                  │  Flutter App     │
                                  │  (Real-time UI)  │
                                  └──────────────────┘
```

---

## Questions?

- Check Supabase docs: https://supabase.com/docs/guides/functions
- Check Firebase docs: https://firebase.google.com/docs/firestore
- Review sync_logs table for error details
