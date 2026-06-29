# ✅ Fufaji Render Deployment Checklist

## Pre-Deployment (Do Once)

### Code Changes
- [ ] Review `backend/DEPLOYMENT_FIXES.md`
- [ ] Verify `backend/render.yaml` exists
- [ ] Verify `backend/.npmrc` exists
- [ ] Verify `backend/Procfile` exists
- [ ] Verify `backend/src/server.js` exists
- [ ] Verify `backend/package.json` has updated scripts

### Git Commit
```bash
git add backend/render.yaml backend/.npmrc backend/Procfile backend/src/server.js backend/package.json .env.example backend/DEPLOYMENT_FIXES.md
git commit -m "Fix: Render deployment with clean npm install and robust startup script"
git push origin main
```

- [ ] Changes committed and pushed

---

## Deployment Step-by-Step

### 1. Open Render Dashboard
- [ ] Go to https://dashboard.render.com
- [ ] Login with your account
- [ ] Navigate to your Fufaji Backend service

### 2. Set Environment Variables
Go to **Settings > Environment > Environment Variables**

Add these variables (get values from your Firebase console, Razorpay, Twilio, SendGrid):

**Firebase:**
- [ ] `FIREBASE_PROJECT_ID` = your-project-id
- [ ] `FIREBASE_SERVICE_ACCOUNT_KEY` = (see below for encoding)

**Razorpay:**
- [ ] `RAZORPAY_KEY_ID` = rzp_live_xxxxx
- [ ] `RAZORPAY_KEY_SECRET` = your-secret-key
- [ ] `RAZORPAY_WEBHOOK_SECRET` = your-webhook-secret

**Twilio (Optional but recommended):**
- [ ] `TWILIO_ACCOUNT_SID` = ACxxxxxx
- [ ] `TWILIO_AUTH_TOKEN` = your-token
- [ ] `TWILIO_PHONE_NUMBER` = +1234567890

**SendGrid (Optional but recommended):**
- [ ] `SENDGRID_API_KEY` = SG.xxxxx
- [ ] `SENDGRID_FROM_EMAIL` = noreply@fufaji.app

**Secrets:**
- [ ] `JWT_SECRET` = (generate: `openssl rand -base64 32`)
- [ ] `MFA_ENCRYPTION_KEY` = (generate: `openssl rand -base64 32`)

**Node Config:**
- [ ] `NODE_ENV` = production
- [ ] `PORT` = 3001
- [ ] `LOG_LEVEL` = info

### 3. Deploy
- [ ] Go to **Deployments** tab
- [ ] Click **Manual Deploy**
- [ ] Select branch: `main`
- [ ] Click **Deploy**

### 4. Monitor Deployment

Watch the **Logs** tab for:

✅ Success markers (you'll see these):
```
✅ Loaded environment from: /opt/render/project/src/.env
✅ firebase-admin
✅ speakeasy
✅ twilio
✅ @sendgrid/mail
✅ Firebase Admin initialized
✅ Secrets loaded
🚀 Fufaji Backend Server running on port 3001
```

❌ Failure markers (if you see these, check below):
```
Cannot find module 'speakeasy'
FIREBASE_PROJECT_ID is required
Failed to initialize services
```

- [ ] Deployment succeeds (green checkmark)
- [ ] Logs show server running
- [ ] Wait 2-3 minutes for service to be ready

### 5. Test Service

In terminal:
```bash
# Health check
curl https://your-backend-service-name.onrender.com/health

# Should return:
# {"status":"ok","timestamp":"2026-06-29T...","environment":"production"}
```

- [ ] Health check responds with 200 OK

---

## Troubleshooting

### ❌ Build Failed: "Cannot find module 'speakeasy'"

**Cause:** npm install didn't work properly  
**Fix:**
1. Go to Render dashboard
2. **Settings > Build & Deploy**
3. Check **Build Command** is: `echo "🧹 Cleaning..." && rm -rf node_modules && npm ci --legacy-peer-deps`
4. Restart build: **Deployments > Manual Deploy**

### ❌ Build Failed: "Node.js version"

**Cause:** Mismatched Node version  
**Fix:**
1. Check `backend/package.json` has: `"engines": {"node": ">=20.0.0"}`
2. Go to Render: **Settings > Build & Deploy > Node Version**
3. Set to latest (26+ recommended)
4. Redeploy

### ❌ Server Crashed: "FIREBASE_PROJECT_ID is required"

**Cause:** Environment variable not set  
**Fix:**
1. Go to **Settings > Environment**
2. Add `FIREBASE_PROJECT_ID` variable
3. Redeploy

### ❌ Server Crashed: "Cannot verify Razorpay webhook"

**Cause:** Wrong webhook secret  
**Fix:**
1. Go to Razorpay Dashboard
2. Find webhook secret for this endpoint
3. Update `RAZORPAY_WEBHOOK_SECRET` in Render
4. Redeploy

### ❌ No SMS/Email Working

**Expected behavior!** If Twilio/SendGrid not configured:
- SMS logs to console, doesn't send (OK for testing)
- Email logs to console, doesn't send (OK for testing)

**To fix:**
1. Add `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER`
2. Add `SENDGRID_API_KEY`, `SENDGRID_FROM_EMAIL`
3. Redeploy

---

## How to Encode Firebase Service Account

You need to base64-encode your service account JSON file:

**On macOS/Linux:**
```bash
cat ~/Downloads/firebase-service-account.json | base64
```

**On Windows (PowerShell):**
```powershell
[Convert]::ToBase64String([System.IO.File]::ReadAllBytes("C:\Downloads\firebase-service-account.json"))
```

Then:
1. Copy the entire base64 output
2. Go to Render: **Settings > Environment**
3. Add `FIREBASE_SERVICE_ACCOUNT_KEY` = (paste base64 string)

---

## Health Check URLs

After deployment, these should work:

```bash
# Health check
curl https://your-service.onrender.com/health

# API endpoints (if configured)
curl -X POST https://your-service.onrender.com/api/orders \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"items": [], "deliveryAddress": {}}'
```

---

## Performance Baseline

After deployment, typical response times:
- Health check: <100ms
- Create order: 200-500ms
- Webhook processing: <1000ms
- Database queries: <500ms

If significantly slower, check:
- Render instance specs (Settings > Plan)
- Firestore quota (might need upgrade)
- Network latency (use global regions)

---

## Post-Deployment Monitoring

### Daily Checks
- [ ] Error rate < 1% (Render dashboard)
- [ ] Response time < 1s (p95)
- [ ] No SIGKILL errors (OOM)
- [ ] Database quota OK (Firebase console)

### Weekly Checks
- [ ] Review error logs
- [ ] Check build times
- [ ] Verify backup working
- [ ] Test payment flow end-to-end

### Monthly Checks
- [ ] Audit environment variables
- [ ] Rotate secrets if needed
- [ ] Review scaling needs
- [ ] Update dependencies

---

## Success Criteria ✅

Your deployment is successful when:

1. ✅ Render shows green "Active" status
2. ✅ Logs show "Server running on port 3001"
3. ✅ Health check returns 200 OK
4. ✅ API endpoints respond with 202/200 (not 500)
5. ✅ No "Cannot find module" errors
6. ✅ Environment variables loaded
7. ✅ Service stays running for >5 minutes

---

## Need Help?

**Quick Resources:**
- Check `backend/DEPLOYMENT_FIXES.md` for detailed explanations
- Check `DEPLOYMENT_CONFIG.md` for architecture details
- Check `QUICK_START_GUIDE.md` for API examples

**External Help:**
- Render Status: https://status.render.com
- Render Docs: https://render.com/docs
- Firebase Status: https://firebase.google.com/status
- Razorpay Docs: https://razorpay.com/docs/api/

---

**Last Updated:** 2026-06-29  
**Deployment Method:** Render (Node.js)  
**Status:** Ready for Production
