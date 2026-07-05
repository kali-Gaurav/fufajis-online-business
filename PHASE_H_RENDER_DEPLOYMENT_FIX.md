# Phase H: Render Deployment Fix

## Problem
Previous deployment failed because:
1. `package.json` had wrong start script
2. Tried to run Express server (which isn't needed for Background Worker)
3. No DATABASE_URL environment variable set

## Solution
Updated for Background Worker deployment:
1. ✅ `start` script now points to worker directly
2. ✅ Removed Express dependencies
3. ✅ Worker runs as pure background service

---

## Fixed Files

### 1. package.json
```json
{
  "scripts": {
    "build": "tsc",
    "start": "node dist/services/firestore-sync-worker.js"
  }
}
```

### 2. firestore-sync-worker.ts
- Removed Express server code
- Added graceful shutdown handlers
- Pure worker logic only

---

## Render Deployment Settings (Corrected)

### Service Type
**Background Worker** (not Web Service)

### Root Directory
```
render-backend
```

### Build Command
```bash
npm install && npm run build
```

### Start Command
```bash
npm start
```

This will run:
```bash
node dist/services/firestore-sync-worker.js
```

### Environment Variables (Required)
```env
SUPABASE_URL=https://mxjtgpunctckovtuyfmz.supabase.co
SUPABASE_SERVICE_ROLE_KEY=(from .env)
FIREBASE_SERVICE_ACCOUNT_KEY=(JSON from Firebase)
```

**DO NOT** add DATABASE_URL (not needed for this worker)

---

## Local Test Before Deploy

Test locally to ensure it builds and runs:

```powershell
cd C:\Projects\fufaji-online-business\render-backend

# Install dependencies
npm install

# Build
npm run build

# Verify output exists
ls dist\services\firestore-sync-worker.js  # Should exist

# Test run (will start worker, press Ctrl+C to stop after 5 seconds)
npm start
```

Expected output:
```
[FirestoreSyncWorker] Starting background worker...
[FirestoreSyncWorker] Started. Poll interval: 2000ms
[FirestoreSyncWorker] Processing 0 events
```

---

## Deploy to Render (Corrected)

### Step 1: Push Code
```powershell
cd C:\Projects\fufaji-online-business

git add render-backend/
git commit -m "Fix Render worker deployment - remove Express, correct start script"
git push origin main
```

### Step 2: Create Render Service
1. Go to https://render.com/dashboard
2. Click **"New +"** → **"Background Worker"**
3. Connect GitHub repo
4. Select branch: `main`
5. Configure:
   - **Root Directory:** `render-backend`
   - **Build Command:** `npm install && npm run build`
   - **Start Command:** `npm start`
   - **Plan:** Free tier

### Step 3: Add Environment Variables
In Render dashboard, set these as **Secret**:
```
SUPABASE_URL = https://mxjtgpunctckovtuyfmz.supabase.co
SUPABASE_SERVICE_ROLE_KEY = (paste from .env)
FIREBASE_SERVICE_ACCOUNT_KEY = (paste JSON from Firebase)
```

### Step 4: Deploy
Click **"Create Background Worker"**

Wait for:
- Build: ✅ Complete
- Logs: `[FirestoreSyncWorker] Started. Poll interval: 2000ms`

---

## Verify Deployment

Check Render logs:
```
[FirestoreSyncWorker] Starting background worker...
[FirestoreSyncWorker] Started. Poll interval: 2000ms
[FirestoreSyncWorker] Processing 0 events
```

Should see continuous polling output like:
```
[FirestoreSyncWorker] Batch complete. Next poll in 2000ms
```

**Success:** Worker is running and polling for events.

---

## Why This Fix Works

| Before | After |
| --- | --- |
| Tried to run Express | Runs worker directly |
| Needed DATABASE_URL | No extra dependencies |
| Complex start logic | Simple: `node dist/services/firestore-sync-worker.js` |
| Would fail on startup | Polls and syncs immediately |

---

## Next Steps After Deployment

1. **Verify worker is live** (check logs above)
2. **Run concurrency test** (from PHASE_H_EXECUTION_COMMANDS.md)
3. **Delete deprecated Firebase functions**
4. **Mark Phase H complete** (10/10)

---

**Summary:** 3-minute fix. Deploy and move on to Task 2.
