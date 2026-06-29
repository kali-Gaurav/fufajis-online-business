# 🔐 Master Security & Secrets Execution Plan
**Date**: June 24, 2026  
**Objective**: Complete security migration from exposed secrets to secure configuration  
**Timeline**: 2-3 days (all can be parallelized)  
**Risk Level**: CRITICAL - Proceed carefully

---

## 🚨 EMERGENCY ACTIONS (Do FIRST - Today)

### Action 1: Verify GitHub Repo is Private
⏱️ **Time**: 5 minutes

**On your Windows terminal:**
```bash
# Check GitHub repo status
cd C:\Projects\fufaji-online-business
git remote -v
# Should show: github.com/kali-Gaurav/fufajis-online-business

# Go to GitHub: https://github.com/kali-Gaurav/fufajis-online-business/settings/visibility
# Ensure "Private" is selected
```

**If repo IS/WAS public:**
- 🚨 ASSUME ALL SECRETS ARE COMPROMISED
- Proceed to Actions 2-4 immediately (today)
- If only recently made private: Contact GitHub support to check access logs

---

### Action 2: Delete `.env` File (if it still exists)
⏱️ **Time**: 5 minutes

**On your Windows terminal:**
```bash
cd C:\Projects\fufaji-online-business

# Check if .env exists
dir .env

# Delete it (FOREVER)
del .env

# Add to gitignore (prevent future commits)
echo .env >> .gitignore

# Commit this change
git add .gitignore
git commit -m "chore: add .env to gitignore - CRITICAL security fix"
git push
```

**Verification:**
```bash
# Verify .env is gone
dir .env
# Should show: "File not found"

# Verify not in git (even history)
git log --all --full-history -- ".env"
# If shows commits: consider git-filter-repo to purge from history
```

---

### Action 3: Rotate ALL Compromised API Keys (Today or Tomorrow)
⏱️ **Time**: 1-2 hours per service

**CRITICAL**: These credentials are in `.env` file and may be exposed. Assume compromised.

#### 3.1: Razorpay Key Rotation
```
🔴 COMPROMISED: ieGG9GcxgN0km2ZVcGyaGEG6 (KEY_SECRET)
🔴 COMPROMISED: Fufaji@Webhook2026! (WEBHOOK_SECRET)

Steps:
1. Go to https://dashboard.razorpay.com/settings/api
2. Scroll to "API Keys"
3. Click "Generate Key"
4. Copy NEW Secret Key (keep Key ID same or regenerate both)
5. Update SECRET in Firebase Secret Manager (see Step 5 below)
6. Revoke old key (click X next to old key)
7. Test: Go to /payments endpoint, should work with new key
```

#### 3.2: WhatsApp Token Rotation
```
🔴 COMPROMISED: EAASZAhYl2VnEBRnXysfExV3vNbuh39CFTHdIGxNk4mIUutmhDhuCAFo7rPP2HIEErCV5sDG8P0NbyobsBlaH

Steps:
1. Go to Meta Business Manager (https://business.facebook.com)
2. Go to System Users → Select your system user
3. Click "Generate New Token"
4. Copy NEW token
5. Update in Firebase Secret Manager
6. Revoke old token
7. Test: /communications/whatsapp-message should work
```

#### 3.3: AWS Credentials Rotation
```
🔴 COMPROMISED: AKIAYJF3JU7AKSWZEYV7 (ACCESS_KEY_ID)
🔴 COMPROMISED: QFGc+7ae37hfh5pO0w4WTB9xRhkYkrZfLq+WTeYk (SECRET_ACCESS_KEY)

Steps:
1. Go to AWS IAM Console (https://console.aws.amazon.com/iam)
2. Users → Select your user → Security credentials
3. Click "Create access key"
4. Choose "Application running on AWS" (or appropriate use case)
5. Copy NEW Access Key ID and Secret
6. Update in Firebase Secret Manager
7. OLD Access Key → Click "Deactivate" (or "Delete" after 24h)
8. Test: AWS services (S3, Bedrock) should work
9. IMPORTANT: Consider using IAM Role instead of access keys for better security
```

#### 3.4: Supabase Secret Rotation
```
🔴 COMPROMISED: (Using same AWS creds)

Steps:
1. Go to Supabase Dashboard (https://app.supabase.com)
2. Project → Settings → API
3. If separate key: "Regenerate" service_role_key
4. Update in Firebase Secret Manager
5. Test: File uploads to Supabase should work
```

#### 3.5: Twilio (if applicable)
```
📋 STATUS: Not found in current .env (good)
If you use Twilio:
1. Go to Twilio Console (https://www.twilio.com/console)
2. Account SID + Auth Token → Regenerate Auth Token
3. Update in Firebase Secret Manager
```

#### 3.6: Stripe (if applicable)
```
📋 STATUS: Not configured (placeholder)
If you use Stripe:
1. Go to Stripe Dashboard (https://dashboard.stripe.com)
2. Developers → API Keys → Regenerate secret key
3. Update in Firebase Secret Manager
```

**After ALL rotations:**
- [ ] Razorpay rotated
- [ ] WhatsApp rotated
- [ ] AWS rotated
- [ ] Supabase verified
- [ ] Twilio verified (if used)
- [ ] Stripe verified (if used)
- [ ] Delete `.env` file ✅ (done in Action 2)
- [ ] Proceed to Step 5

---

## 📋 REGULAR ACTIONS (Parallel - Next 24-48 hours)

### Step 1: Set Up Firebase Secret Manager (1-2 hours)
📍 **See**: `FIREBASE_SECRET_MANAGER_SETUP.md`

**What you'll do:**
1. Install Firebase CLI (if not already done)
2. Run: `firebase functions:secrets:set SECRET_NAME`
3. Enter each rotated credential one by one
4. Verify all secrets created: `firebase functions:secrets:list`

**Secrets to add:**
- RAZORPAY_KEY_SECRET (new value from rotation)
- RAZORPAY_WEBHOOK_SECRET (new value from rotation)
- WHATSAPP_TOKEN (new value from rotation)
- AWS_ACCESS_KEY_ID (new value from rotation)
- AWS_SECRET_ACCESS_KEY (new value from rotation)
- SUPABASE_S3_SECRET_KEY (new value)
- TWILIO_ACCOUNT_SID & AUTH_TOKEN (if used)
- STRIPE_SECRET_KEY (if used)
- RDS_PASSWORD, GEMINI_API_KEY, etc.

**Time**: ~15 minutes per secret, ~2 hours total

---

### Step 2: Update Firebase Functions to Use defineSecret() (2-3 hours)
📍 **See**: `FIREBASE_SECRET_MANAGER_SETUP.md` Sections 5-7

**What you'll do:**
1. Open `functions/index.js` - Already done! ✅
2. Check other function files:
   - `functions/src/webhooks/razorpay_webhook.ts`
   - `functions/src/payments/createRazorpayOrder.ts`
   - `functions/src/payments/verifyRazorpayPayment.ts`
   - `functions/src/tasks/process_payment_retries.ts`
3. Add `secrets: ['SECRET_NAME']` to each function
4. Replace `process.env.SECRET` access
5. Test locally with emulator: `firebase emulators:start --only functions`
6. Deploy: `firebase deploy --only functions`

**Time**: ~3 hours

---

### Step 3: Configure Render.com Backend Environment (1 hour)
📍 **See**: `RENDER_BACKEND_ENV_SETUP.md`

**What you'll do:**
1. Go to Render Dashboard → Your "fufaji-api" service
2. Click "Environment"
3. Add each variable one by one:
   - RAZORPAY_KEY_SECRET (new value)
   - RAZORPAY_KEY_ID
   - WHATSAPP_TOKEN (new value)
   - AWS_ACCESS_KEY_ID (new value)
   - AWS_SECRET_ACCESS_KEY (new value)
   - RDS_PASSWORD, SENTRY_DSN, etc.
4. Manual Deploy or push to GitHub
5. Check logs: Deployment should succeed
6. Test endpoints:
   ```bash
   curl https://fufaji-api.render.com/config/app-config
   # Should return ONLY public configs, no secrets
   ```

**Time**: ~1 hour

---

### Step 4: Update Backend Services (1-2 hours)
📍 **See**: `FIREBASE_SECRET_MANAGER_SETUP.md` Step 8

**What you'll do:**
1. Update `backend/src/secrets.js`:
   ```javascript
   module.exports = {
       razorpayKeySecret: process.env.RAZORPAY_KEY_SECRET,
       razorpayKeyId: process.env.RAZORPAY_KEY_ID,
       // ... all other secrets from process.env
   };
   ```

2. Update all service files:
   - `backend/src/services/RazorpayService.js`
   - `backend/src/services/SmsService.js` (if Twilio)
   - `backend/src/routes/webhooks.js`
   - `backend/src/routes/config.js` (ONLY return public configs!)

3. Replace: `functions.config().razorpay.*` → `process.env.RAZORPAY_*`

4. Add validation on startup:
   ```javascript
   if (!process.env.RAZORPAY_KEY_SECRET) {
       throw new Error('Missing RAZORPAY_KEY_SECRET');
   }
   ```

**Time**: ~1-2 hours

---

### Step 5: Create Secure APK Build Scripts (30 minutes)
📍 **See**: `BUILD_APK_PRODUCTION.bat` & `BUILD_APK_PRODUCTION.ps1`

**What you'll do:**
1. Already created! ✅
2. Update the values inside the script:
   ```batch
   set "RAZORPAY_KEY_ID=rzp_live_Sr7JfZt4NbXzMw"
   set "GOOGLE_MAPS_KEY=your_production_maps_key"
   set "SENTRY_DSN=your_sentry_dsn"
   ```
3. Run the script:
   ```bash
   # Windows CMD
   BUILD_APK_PRODUCTION.bat

   # Or PowerShell
   powershell -ExecutionPolicy Bypass -File BUILD_APK_PRODUCTION.ps1
   ```
4. Verify APK is created at: `build/app/outputs/flutter-apk/app-release.apk`

**Time**: ~30 minutes

---

### Step 6: Set Up GitHub Secrets for CI/CD (30 minutes)
📍 **See**: GitHub Actions documentation

**What you'll do:**
1. Go to GitHub repo → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add these secrets:
   ```
   ANDROID_STORE_PASSWORD = fufaji123
   ANDROID_KEY_PASSWORD = fufaji123
   ANDROID_KEY_ALIAS = upload
   keystore_base64 = (base64 of fufaji-upload-key.jks file)
   google_services_json = (base64 of google-services.json)
   
   RAZORPAY_KEY_SECRET = (new value)
   RAZORPAY_WEBHOOK_SECRET = (new value)
   WHATSAPP_TOKEN = (new value)
   AWS_SECRET_ACCESS_KEY = (new value)
   STRIPE_SECRET_KEY = (if used)
   RDS_PASSWORD = (if applicable)
   ```

4. Update `.github/workflows/*.yml` to reference secrets:
   ```yaml
   - name: Deploy
     env:
       RAZORPAY_KEY_SECRET: ${{ secrets.RAZORPAY_KEY_SECRET }}
       WHATSAPP_TOKEN: ${{ secrets.WHATSAPP_TOKEN }}
   ```

**Time**: ~30 minutes

---

## ✅ VERIFICATION PHASE (Next 24 hours)

### Test 1: Build APK with No Secrets
```bash
# Run the build script
BUILD_APK_PRODUCTION.bat

# Verify APK created
ls build/app/outputs/flutter-apk/app-release.apk

# Extract and check for secrets (apktool):
apktool d build/app/outputs/flutter-apk/app-release.apk
grep -r "ieGG9GcxgN0km2ZVcGyaGEG6" apktool_output/
# Should return: NOTHING (secret not found = good!)
```

### Test 2: Test Payment Flow
```bash
# Install APK on device/emulator
adb install -r build/app/outputs/flutter-apk/app-release.apk

# In app:
1. Create test customer account
2. Add product to cart
3. Checkout → Pay (Razorpay)
4. Verify payment succeeds
5. Check Razorpay dashboard for order
6. Check backend logs for no errors
```

### Test 3: Test Backend Endpoints
```bash
# Config endpoint (public only)
curl -X GET https://fufaji-api.render.com/config/app-config
# Should return: API_BASE_URL, RAZORPAY_KEY_ID (not secret!), etc.

# Payment endpoint
curl -X POST https://fufaji-api.render.com/payments/razorpay-order \
  -H "Content-Type: application/json" \
  -d '{"amount": 10000, "customerId": "test_123"}'
# Should succeed (using RAZORPAY_KEY_SECRET from Render env)

# WhatsApp endpoint
curl -X POST https://fufaji-api.render.com/communications/whatsapp-message \
  -d '{"phone": "+91XXXXXXXXXX", "message": "Test"}'
# Should succeed
```

### Test 4: Check Logs for Errors
```bash
# Render.com logs
# Dashboard → Logs → Look for "undefined", "secret", "error"
# Should see: Service running, no config errors

# Firebase functions logs
firebase functions:log
# Should see: All functions deployed, secrets resolved

# Sentry errors
# Go to Sentry dashboard → Errors
# Should see: No "secret" related errors
```

### Test 5: Verify APK Doesn't Contain Secrets
```bash
# Use apktool to decompile APK
apktool d build/app/outputs/flutter-apk/app-release.apk -o fufaji_apktool

# Search for exposed secrets
cd fufaji_apktool
grep -r "ieGG9GcxgN0km2ZVcGyaGEG6" .  # RAZORPAY secret
grep -r "EAASZAhYl2VnEBRnXysfExV3vNbuh39" .  # WhatsApp token
grep -r "QFGc+7ae37hfh5pO0w4WTB9xRhkYkrZfLq+WTeYk" .  # AWS secret

# EXPECTED: No matches found
# If any match: FAIL - Do not deploy!
```

---

## 📋 Final Checklist

### Before Deploying to Play Store:

- [ ] GitHub repo is PRIVATE
- [ ] `.env` file deleted from repo and local machine
- [ ] All compromised API keys rotated (Razorpay, WhatsApp, AWS)
- [ ] Firebase Secret Manager configured with all backend secrets
- [ ] Firebase Functions updated to use `secrets:` pattern
- [ ] Backend services updated to use `process.env`
- [ ] Render.com environment variables configured
- [ ] APK built with `--dart-define` (no `.env`)
- [ ] APK tested: No backend secrets found
- [ ] APK tested: Payment flow works end-to-end
- [ ] Backend tested: Config endpoint returns only public values
- [ ] Backend tested: Payment, WhatsApp, all services work
- [ ] No errors in logs (Render, Firebase, Sentry)
- [ ] DEPLOYMENT RUNBOOK created for future secret rotation

---

## 🚀 Deployment Timeline

| Day | Task | Duration | Parallel? |
|-----|------|----------|-----------|
| **Day 1** | Emergency actions (verify private, delete .env, rotate keys) | 2-3 hours | - |
| **Day 2** | Firebase Secret Manager setup | 2 hours | Yes |
| **Day 2** | Update Firebase Functions | 3 hours | Yes |
| **Day 2** | Configure Render.com | 1 hour | Yes |
| **Day 2** | Update backend services | 1-2 hours | Yes |
| **Day 2** | Create build scripts | 30 mins | Yes |
| **Day 3** | Verification & testing | 2-3 hours | - |
| **Day 3** | Deploy to Play Store | 30 mins | - |

**Total**: 2-3 days (most tasks can run in parallel)

---

## 🆘 If Something Goes Wrong

### Problem: "Secret not found" in Firebase functions
```
Fix:
1. firebase functions:secrets:list  # Verify secret created
2. firebase functions:secrets:set SECRET_NAME  # Recreate if needed
3. firebase deploy --only functions  # Redeploy
4. firebase functions:log  # Check for "resolved" message
```

### Problem: "Razorpay order creation fails"
```
Fix:
1. Verify RAZORPAY_KEY_SECRET in Render.com environment
2. Verify it matches NEW rotated key (not old one)
3. Check Razorpay dashboard that key is active
4. Test manually: curl /payments/razorpay-order
5. Check backend logs for error message
```

### Problem: "APK still contains secrets"
```
Fix:
1. Verify .env is NOT in pubspec.yaml assets
2. Rebuild with: flutter clean && flutter pub get
3. Rebuild APK: BUILD_APK_PRODUCTION.bat
4. Verify --dart-define used (not .env loading)
5. Re-run apktool decompile check
```

### Problem: "GitHub Actions fails"
```
Fix:
1. Check GitHub Secrets are set correctly
2. Verify secret values don't have quotes or extra chars
3. Verify workflow references correct secret names
4. Re-run workflow (sometimes cache issue)
5. Check GitHub Actions logs for error message
```

---

## 📚 Documentation Created

1. **SECRET_INVENTORY_AUDIT_20260624.md** - Current state audit
2. **FIREBASE_SECRET_MANAGER_SETUP.md** - Firebase Secret Manager guide
3. **RENDER_BACKEND_ENV_SETUP.md** - Render.com configuration
4. **BUILD_APK_PRODUCTION.bat & .ps1** - Secure APK build scripts
5. **MASTER_SECURITY_EXECUTION_PLAN.md** - This document

---

## 📞 Support

If you get stuck:
1. Read the ERROR message carefully
2. Check the relevant documentation file
3. Check logs: Firebase, Render.com, Sentry
4. Run the test commands (Test 1-5 above)
5. Re-run the action that failed

---

**Status**: READY FOR EXECUTION  
**Start**: Today with Emergency Actions  
**Target Completion**: June 26, 2026  
**Go-Live**: June 26-27, 2026

🎯 **You've got this! Follow the checklist, one step at a time.**
