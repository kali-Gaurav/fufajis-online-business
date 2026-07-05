# Phase H Deployment Guide

**Goal:** Complete Phase H (Order Lifecycle Production Launch Readiness) by executing 3 final tasks.

**Current Status:** 9.7/10 ✅

---

## Task 1: Deploy Render Sync Worker

The Firestore sync worker runs on Render and handles asynchronous synchronization of order events from PostgreSQL to Firestore.

### Prerequisites

- Render account at https://render.com
- SUPABASE_SERVICE_ROLE_KEY from Supabase dashboard
- FIREBASE_SERVICE_ACCOUNT_KEY (JSON) from Firebase console

### Step 1: Create New Render Service

1. Go to https://render.com/dashboard
2. Click **"New +"** → **"Web Service"**
3. Connect your GitHub repo: https://github.com/yourusername/fufaji-online-business
4. Configure:
   - **Name:** `fufaji-firestore-sync`
   - **Root Directory:** `render-backend`
   - **Runtime:** Node
   - **Build Command:** `npm ci && npm run build`
   - **Start Command:** `npm start`

### Step 2: Add Environment Variables

In Render dashboard, add:

| Key | Value | Scope |
| --- | --- | --- |
| `SUPABASE_URL` | `https://mxjtgpunctckovtuyfmz.supabase.co` | Secret |
| `SUPABASE_SERVICE_ROLE_KEY` | (from Supabase) | Secret |
| `FIREBASE_SERVICE_ACCOUNT_KEY` | (JSON from Firebase) | Secret |
| `AUTO_START_SYNC_WORKER` | `true` | Public |
| `NODE_ENV` | `production` | Public |

### Step 3: Deploy

1. Click **"Create Web Service"**
2. Render will automatically build and deploy
3. Wait for deployment to complete (usually 2-3 minutes)
4. Note the service URL: `https://fufaji-firestore-sync.onrender.com`

### Step 4: Verify Deployment

```bash
curl -s https://fufaji-firestore-sync.onrender.com/health
```

Expected response:
```json
{
  "status": "healthy",
  "service": "fufaji-render-backend",
  "uptime": 45.2,
  "timestamp": "2026-07-04T10:30:00.000Z"
}
```

Check Firestore sync worker health:

```bash
curl -s https://fufaji-firestore-sync.onrender.com/health/sync-worker
```

Expected response:
```json
{
  "status": "healthy",
  "uptime": 40.1,
  "processedCount": 0,
  "failedCount": 0,
  "retryingCount": 0
}
```

---

## Task 2: Run Concurrency Test

This test validates that 50 concurrent checkouts with only 10 units of stock:
- 10 succeed (reserve stock)
- 40 fail
- 0 stock leakage

### Step 1: Build Test

```bash
cd C:\Projects\fufaji-online-business
npx tsc tests/phase_h_concurrency_test.ts --outDir dist --module esnext --target es2020
```

### Step 2: Run Test

From Windows PowerShell:

```powershell
$env:SUPABASE_URL = "https://mxjtgpunctckovtuyfmz.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY = (Get-Content .env | Select-String "SUPABASE_SERVICE_ROLE_KEY").Line.Split('=')[1].Trim()

node dist/tests/phase_h_concurrency_test.js
```

### Step 3: Expected Output

```
[Setup] Preparing test product...
[Setup] ✅ Product created with 10 available stock

[Test] Running 50 concurrent checkouts...

[Results] Checkout Outcomes:
  ✅ Successful: 10
  ❌ Failed: 40
  Total: 50

[Results] Stock Integrity:
  Available: 0
  Reserved: 10
  Sold: 0
  Total: 10 (should be 10)

[Verdict]
  ✅ Successful checkouts: 10 (expected 10)
  ✅ Failed checkouts: 40 (expected 40)
  ✅ Stock leakage: NONE (Pass)

🎉 CONCURRENCY TEST PASSED
```

### Step 4: What This Validates

✅ PostgreSQL row-level locking works  
✅ Edge Function concurrency handling is correct  
✅ Stock is never over-allocated  
✅ Transaction safety is maintained  
✅ State machine constraints are enforced  

---

## Task 3: Delete Deprecated Firebase Functions

Once all live tests pass, permanently remove the old Firebase Cloud Functions.

### Step 1: Verify Quarantine Status

```bash
ls -la functions/src/_deprecated/
```

You should see 8 files:
- processCheckout.js
- changeOrderStatus.js
- dispatchCluster.js
- verifyDeliveryOtp.js
- cancelOrder.js
- failOrderDelivery.js
- resolveDeliveryException.js
- releaseExpiredReservations.js

### Step 2: Verify They Are Dead Code

Check that nothing exports them:

```bash
grep -n "_deprecated" functions/src/index.ts
```

Should return nothing (they are NOT exported).

### Step 3: Delete the Folder

From Windows PowerShell:

```powershell
Remove-Item C:\Projects\fufaji-online-business\functions\src\_deprecated -Recurse -Force
```

Or from Git Bash:

```bash
rm -rf functions/src/_deprecated
```

### Step 4: Commit

```bash
git add -A
git commit -m "Remove deprecated Firebase Cloud Functions after Edge Function migration"
git push origin main
```

### Step 5: Verify in Firebase Console

1. Go to Firebase Console → Functions
2. Confirm only these remain deployed:
   - (None from _deprecated folder)
   - All other functions from functions/src/ are still there

---

## Phase H Completion Checklist

- [ ] Task 1: Render sync worker deployed
  - [ ] Service created in Render
  - [ ] Environment variables configured
  - [ ] Health check passes
  - [ ] Sync worker health check passes
- [ ] Task 2: Concurrency test passed
  - [ ] 10 successful checkouts
  - [ ] 40 failed checkouts
  - [ ] 0 stock leakage
  - [ ] All assertions pass
- [ ] Task 3: Deprecated functions deleted
  - [ ] _deprecated folder removed
  - [ ] Changes committed to Git
  - [ ] Firebase Console verified

---

## Final Phase H Score

When all 3 tasks complete:

```
Architecture:   10/10 ✅
Database:       10/10 ✅
Runtime:        10/10 ✅
Reliability:    10/10 ✅
Firestore Sync: 10/10 ✅
─────────────────────────
Overall:        10/10 ✅

Phase H Status: COMPLETE ✅
```

---

## Troubleshooting

### Render Deployment Failed

**Error:** `Cannot find module @supabase/supabase-js`

**Fix:**
```bash
cd render-backend
npm ci
npm run build
```

### Concurrency Test Hangs

**Cause:** Sync worker not running or Supabase unreachable

**Fix:**
```bash
curl -s https://fufaji-firestore-sync.onrender.com/health/sync-worker
```

### Stock Leakage Detected

**Cause:** Transaction isolation issue or query bug

**Action:**
1. Check PostgreSQL transaction logs
2. Verify Edge Function database lock code
3. Run test again with smaller concurrency (10 requests, stock=5)

---

## Next Steps After Phase H

Once Phase H is complete:

1. **Phase I:** Mobile App Polish
   - UI/UX refinements
   - Performance optimization
   - Analytics integration

2. **Phase J:** Production Hardening
   - Secrets rotation
   - DDoS protection
   - Backup automation

3. **Phase K:** Go Live
   - Customer onboarding
   - Performance monitoring
   - Support escalation procedures

---

**Author:** Claude  
**Date:** 2026-07-04  
**Status:** READY FOR EXECUTION
