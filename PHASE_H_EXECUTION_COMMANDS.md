# Phase H: Execution Commands

Copy-paste ready commands for the 3 final deployment tasks.

---

## TASK 1: Deploy Render Sync Worker

### Option A: Via Render Web UI (Recommended)

1. Go to https://render.com/dashboard
2. Click **"New +"** → **"Web Service"**
3. Connect GitHub repo
4. Set Root Directory to: `render-backend`
5. Build Command: `npm ci && npm run build`
6. Start Command: `npm start`
7. Add these Environment Variables:

```
SUPABASE_URL = https://mxjtgpunctckovtuyfmz.supabase.co
SUPABASE_SERVICE_ROLE_KEY = (paste from .env)
FIREBASE_SERVICE_ACCOUNT_KEY = (paste JSON from Firebase console)
AUTO_START_SYNC_WORKER = true
NODE_ENV = production
```

8. Click **"Create Web Service"**
9. Wait for deployment (2-3 minutes)

### Option B: Via Render CLI

```bash
cd C:\Projects\fufaji-online-business\render-backend

# Install Render CLI
npm install -g render-cli

# Login
render login

# Deploy
render deploy
```

### Verify Deployment

```bash
# After Render shows "Service is live"
curl https://fufaji-firestore-sync.onrender.com/health

# Expected response:
# { "status": "healthy", "service": "fufaji-render-backend", "uptime": 45.2, "timestamp": "..." }

# Check sync worker specifically:
curl https://fufaji-firestore-sync.onrender.com/health/sync-worker

# Expected response:
# { "status": "healthy", "uptime": 40.1, "processedCount": 0, "failedCount": 0, "retryingCount": 0 }
```

---

## TASK 2: Run Concurrency Test

### Windows PowerShell Commands

```powershell
# Navigate to project
cd C:\Projects\fufaji-online-business

# Load environment variables
$env:SUPABASE_URL = "https://mxjtgpunctckovtuyfmz.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY = (Get-Content .env | Select-String "SUPABASE_SERVICE_ROLE_KEY").Line.Split('=')[1].Trim()

# Compile test
npx tsc tests/phase_h_concurrency_test.ts --outDir dist --module esnext --target es2020

# Run test
node dist/tests/phase_h_concurrency_test.js
```

### Expected Output

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

### What to Do If Test Fails

1. **If test hangs:** Sync worker may not be running
   ```powershell
   curl https://fufaji-firestore-sync.onrender.com/health/sync-worker
   ```
   Should return status: "healthy"

2. **If stock leakage detected:** Transaction isolation issue
   ```sql
   -- Check database state:
   SELECT available_stock, reserved_stock, sold_stock 
   FROM products 
   WHERE id = 'test-product-concurrency-001';
   ```
   Total should equal 10.

3. **If connectivity error:** Supabase credentials issue
   - Verify SUPABASE_URL in .env
   - Verify SUPABASE_SERVICE_ROLE_KEY has correct permissions

---

## TASK 3: Delete Deprecated Firebase Functions

### Windows PowerShell

```powershell
cd C:\Projects\fufaji-online-business

# Step 1: Verify quarantined folder exists
dir functions\src\_deprecated

# Step 2: Delete the folder
Remove-Item functions\src\_deprecated -Recurse -Force

# Step 3: Verify it's gone
dir functions\src\_deprecated  # Should return: Cannot find path...

# Step 4: Check nothing exported from index.ts
findstr /N "_deprecated" functions\src\index.ts  # Should return nothing
```

### Git Bash / WSL

```bash
cd /c/Projects/fufaji-online-business

# Step 1: Verify quarantined folder exists
ls functions/src/_deprecated

# Step 2: Delete the folder
rm -rf functions/src/_deprecated

# Step 3: Verify it's gone
ls functions/src/_deprecated  # Should return: No such file or directory

# Step 4: Check nothing exported
grep "_deprecated" functions/src/index.ts  # Should return nothing
```

### Git Commit & Push

```powershell
# From Windows PowerShell
cd C:\Projects\fufaji-online-business

git add -A
git commit -m "Remove deprecated Firebase Cloud Functions after Edge Function migration

- Removed functions/src/_deprecated folder
- All 8 functions migrated to Supabase Edge Functions
- No breaking changes (functions not exported)
- Verified safe cleanup in PHASE_H_DEPLOYMENT_GUIDE.md"

git push origin main

# Verify on GitHub
# Visit: https://github.com/yourusername/fufaji-online-business/commits/main
# Should show your commit
```

---

## Quick Reference Timeline

| Task | Time | Status |
| --- | --- | --- |
| Deploy Render | 5 min | ⏳ User |
| Run Concurrency Test | 10 min | ⏳ User |
| Delete Firebase Functions | 2 min | ⏳ User |
| **TOTAL** | **17 min** | **⏳ User** |

---

## Exit Criteria (Phase H Complete)

All 3 of these must be true:

1. ✅ `curl https://fufaji-firestore-sync.onrender.com/health` returns status: "healthy"
2. ✅ Concurrency test output shows: `🎉 CONCURRENCY TEST PASSED`
3. ✅ `dir functions\src\_deprecated` returns: `Cannot find path...`

When all 3 pass:

```
Phase H Status: ✅ COMPLETE (10/10)
```

---

## Troubleshooting Quick Links

**Render Issues?**
- Dashboard: https://render.com/dashboard
- Logs: Click service → "Logs" tab
- Check environment variables: Service Settings → Environment

**Supabase Issues?**
- Dashboard: https://app.supabase.com
- Check Edge Function logs: Functions → order-lifecycle → Logs
- Query database directly: SQL Editor

**Edge Function Not Working?**
```bash
# Test directly from PowerShell:
$token = (Get-Content .env | Select-String "SUPABASE_ANON_KEY").Line.Split('=')[1].Trim()
curl -X POST "https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/order-lifecycle/health" `
  -H "Authorization: Bearer $token" `
  -H "Content-Type: application/json" `
  -d "{}"
```

---

## Success Indicators

### Task 1 Success
- Render shows "Service is live" (green badge)
- `/health` endpoint returns JSON
- No error logs in Render dashboard

### Task 2 Success
- Test output shows "🎉 CONCURRENCY TEST PASSED"
- Stock integrity check: "NONE (Pass)"
- Process exit code: 0

### Task 3 Success
- Folder delete succeeds without errors
- Git commit pushed to main
- No "Cannot find module" errors when deploying

---

## After All 3 Tasks Complete

```powershell
# From Windows PowerShell:
Write-Host "Phase H Complete! ✅"
Write-Host ""
Write-Host "Current Score: 10/10"
Write-Host ""
Write-Host "Completed:"
Write-Host "  ✅ Edge Function deployed (BOOT_ERROR resolved)"
Write-Host "  ✅ Database hardened (outbox events, constraints)"
Write-Host "  ✅ Flutter services migrated"
Write-Host "  ✅ Render sync worker deployed"
Write-Host "  ✅ Concurrency test passed"
Write-Host "  ✅ Deprecated Firebase functions deleted"
Write-Host ""
Write-Host "Next: Phase I (Mobile App Polish)"
```

---

**Remember:** Execute these tasks in order. Each task depends on setup from previous tasks.

**Questions?** Check `PHASE_H_DEPLOYMENT_GUIDE.md` for detailed explanations.
