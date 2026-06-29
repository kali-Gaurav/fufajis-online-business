# 🔐 FUFAJI SECURITY MIGRATION - Complete Execution Guide
**Date**: June 24, 2026  
**Status**: CRITICAL - Start immediately  
**Timeline**: 2-3 days to complete  
**Readiness**: 40/100 → Target: 95/100 after execution

---

## 📌 WHAT HAPPENED

Your `.env` file contains **13 sensitive production secrets** that could be exposed if your GitHub repo was public. These secrets control:
- ✅ Payments (Razorpay) 
- ✅ Messaging (WhatsApp)
- ✅ Cloud Services (AWS, Supabase)
- ✅ Database access (RDS)
- ✅ Mobile signing credentials

**Good news**: Most are NOT currently in your APK (it's safe). But the `.env` file itself should never exist, and the keys should be rotated.

---

## 🚨 ACTION PLAN (IN ORDER)

### TODAY - Emergency Actions (2-3 hours)

**1️⃣ Verify GitHub is Private** (5 min)
```
Go to: https://github.com/kali-Gaurav/fufajis-online-business/settings/visibility
Ensure "Private" is selected
If it WAS public: Assume all secrets are compromised → Rotate ALL immediately
```

**2️⃣ Delete `.env` File** (5 min)
```powershell
# Windows terminal:
cd C:\Projects\fufaji-online-business
del .env
echo .env >> .gitignore
git add .gitignore
git commit -m "chore: add .env to gitignore - CRITICAL security"
git push
```

**3️⃣ Rotate Compromised Keys** (1-2 hours)
Use this as guide for each service:

**Razorpay:**
- Go to https://dashboard.razorpay.com/settings/api
- Generate new secret key
- Note the new values

**WhatsApp:**
- Go to https://business.facebook.com
- System Users → Generate New Token

**AWS:**
- Go to https://console.aws.amazon.com/iam
- Users → Security Credentials → Create new access key

**After rotation, keep the new values handy for Step 2 below**

---

### NEXT 48 HOURS - Implementation (Do these in parallel)

**2️⃣ Set Up Firebase Secret Manager** (2 hours)
```bash
# Run for each rotated key:
firebase functions:secrets:set RAZORPAY_KEY_SECRET
firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
firebase functions:secrets:set WHATSAPP_TOKEN
firebase functions:secrets:set AWS_ACCESS_KEY_ID
firebase functions:secrets:set AWS_SECRET_ACCESS_KEY
# ... etc for others

# Verify all created:
firebase functions:secrets:list
```

📍 **Full Guide**: See `FIREBASE_SECRET_MANAGER_SETUP.md`

---

**3️⃣ Update Firebase Functions** (3 hours)
Functions need to be updated to use `secrets:` pattern (some already are!)

Check and update:
- `functions/index.js` ✅ (Already good!)
- `functions/src/webhooks/razorpay_webhook.ts`
- `functions/src/payments/*.ts`
- Other `.ts` files in functions/src/

Pattern:
```typescript
export const myFunction = functions.runWith({
    secrets: ['SECRET_NAME']
}).https.onRequest(async (req, res) => {
    const secret = process.env.SECRET_NAME;
    // ... use secret
});
```

Test locally:
```bash
firebase emulators:start --only functions
# Should see: "secrets resolved" messages
```

Deploy:
```bash
firebase deploy --only functions
```

📍 **Full Guide**: See `FIREBASE_SECRET_MANAGER_SETUP.md` Sections 5-8

---

**4️⃣ Configure Render.com** (1 hour)
```
1. Go to: https://render.com/dashboard
2. Click your "fufaji-api" service
3. Left sidebar → "Environment"
4. Add each secret as environment variable:
   - RAZORPAY_KEY_SECRET = (new value)
   - RAZORPAY_KEY_ID = rzp_live_Sr7JfZt4NbXzMw
   - WHATSAPP_TOKEN = (new value)
   - AWS_ACCESS_KEY_ID = (new value)
   - AWS_SECRET_ACCESS_KEY = (new value)
   - ... etc

5. Click Save after each
6. Service auto-redeploys
7. Check logs: Should see "Service is running"
```

Test:
```bash
# Config endpoint (should return ONLY public values, NO secrets):
curl https://fufaji-api.render.com/config/app-config

# Payment endpoint (should work with new credentials):
curl -X POST https://fufaji-api.render.com/payments/razorpay-order \
  -H "Content-Type: application/json" \
  -d '{"amount": 10000, "customerId": "test"}'
```

📍 **Full Guide**: See `RENDER_BACKEND_ENV_SETUP.md`

---

**5️⃣ Update Backend Code** (1-2 hours)
Update files to use `process.env` instead of `functions.config()`:

```javascript
// File: backend/src/secrets.js
module.exports = {
    razorpayKeySecret: process.env.RAZORPAY_KEY_SECRET,
    razorpayKeyId: process.env.RAZORPAY_KEY_ID,
    whatsappToken: process.env.WHATSAPP_TOKEN,
    awsAccessKeyId: process.env.AWS_ACCESS_KEY_ID,
    awsSecretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    // ... all others from process.env
};
```

Files to update:
- `backend/src/secrets.js`
- `backend/src/services/RazorpayService.js`
- `backend/src/services/SmsService.js`
- `backend/src/routes/webhooks.js`
- Any other file using `functions.config()`

📍 **Full Guide**: See `FIREBASE_SECRET_MANAGER_SETUP.md` Section 8

---

**6️⃣ Build APK Safely** (30 min)
Already created! Two scripts for you:

```bash
# Option 1: Batch script
BUILD_APK_PRODUCTION.bat

# Option 2: PowerShell
powershell -ExecutionPolicy Bypass -File BUILD_APK_PRODUCTION.ps1
```

What the script does:
- ✅ Verifies `.env` is NOT in assets
- ✅ Builds with `--dart-define` for public configs only
- ✅ Creates release APK
- ✅ Verifies size & location

The `.env` file is NEVER loaded, secrets are NEVER bundled.

📍 **See**: `BUILD_APK_PRODUCTION.bat` and `BUILD_APK_PRODUCTION.ps1`

---

**7️⃣ GitHub Actions Setup** (30 min)
CI/CD needs secrets too!

Go to: https://github.com/kali-Gaurav/fufajis-online-business/settings/secrets/actions

Add these secrets:
```
ANDROID_STORE_PASSWORD = fufaji123
ANDROID_KEY_PASSWORD = fufaji123
ANDROID_KEY_ALIAS = upload
keystore_base64 = (base64-encode fufaji-upload-key.jks)
google_services_json = (base64-encode google-services.json)

RAZORPAY_KEY_SECRET = (new value)
RAZORPAY_WEBHOOK_SECRET = (new value)
WHATSAPP_TOKEN = (new value)
AWS_SECRET_ACCESS_KEY = (new value)
```

Update workflows to reference:
```yaml
env:
  RAZORPAY_KEY_SECRET: ${{ secrets.RAZORPAY_KEY_SECRET }}
  WHATSAPP_TOKEN: ${{ secrets.WHATSAPP_TOKEN }}
```

---

### FINAL 24 HOURS - Verification

**Test 1: APK Has No Secrets**
```bash
# Build APK
BUILD_APK_PRODUCTION.bat

# Verify no secrets embedded:
apktool d build/app/outputs/flutter-apk/app-release.apk

# Search for exposed secrets (should find NOTHING):
cd apktool_output
grep -r "ieGG9GcxgN0km2ZVcGyaGEG6" .  # RAZORPAY secret
grep -r "EAASZAhYl2VnEBRnXysfExV3" .   # WhatsApp token
grep -r "QFGc+7ae37hfh5pO0w4WTB9xRhkYkrZfLq" .  # AWS secret

# If NOTHING found = GOOD! ✅
```

**Test 2: Full Payment Flow**
```
1. adb install -r build/app/outputs/flutter-apk/app-release.apk
2. Open app on phone/emulator
3. Create customer account
4. Add product to cart
5. Checkout → Pay (Razorpay)
6. Verify payment succeeds
7. Check Razorpay dashboard for order
8. Check backend logs: no errors
```

**Test 3: Backend Endpoints Work**
```bash
# These should all work:
curl https://fufaji-api.render.com/config/app-config  # ✅ Should succeed
curl -X POST https://fufaji-api.render.com/payments/razorpay-order -d '...'  # ✅ Should create order
curl -X POST https://fufaji-api.render.com/communications/whatsapp-message -d '...'  # ✅ Should send message
```

**Test 4: No Exposed Secrets in Logs**
- Render logs → No "undefined", "secret", "error"
- Firebase logs → No errors
- Sentry → No secret-related errors
- All green ✅

---

## 📚 DOCUMENTATION CREATED FOR YOU

| Document | Purpose | When to Use |
|----------|---------|------------|
| `SECRET_INVENTORY_AUDIT_20260624.md` | Full audit of current state | Reference - understand what's exposed |
| `FIREBASE_SECRET_MANAGER_SETUP.md` | Firebase setup guide | Step 2 - Set up Firebase Secrets |
| `RENDER_BACKEND_ENV_SETUP.md` | Render.com configuration | Step 4 - Configure backend environment |
| `BUILD_APK_PRODUCTION.bat/.ps1` | APK build scripts | Step 6 - Build APK safely |
| `MASTER_SECURITY_EXECUTION_PLAN.md` | Complete execution plan | Reference - full timeline & checklists |
| `QUICK_REFERENCE_SECRET_ROTATION.md` | How to rotate individual secrets | After launch - monthly rotations |
| This file | Summary & quick start | You are here! |

---

## ⏰ ESTIMATED TIMELINE

| Phase | Tasks | Time | Days |
|-------|-------|------|------|
| **Emergency** | Verify private, delete .env, rotate keys | 2-3 hrs | Day 1 |
| **Implementation** | Firebase setup, functions update, Render config, code update, APK build | 8-10 hrs | Days 1-2 (parallel) |
| **Verification** | Test APK, test endpoints, test payment flow, check logs | 2-3 hrs | Day 3 |
| **Go-Live** | Deploy to Play Store (optional) | 30 min | Day 3+ |

**Total**: 2-3 days to complete  
**Can run in parallel**: Firebase setup, Render config, code updates (saves time!)

---

## ✅ SUCCESS CRITERIA

After completion, you should have:

- ✅ GitHub repo is PRIVATE
- ✅ `.env` file deleted (locally & in git)
- ✅ All compromised keys ROTATED
- ✅ Firebase Secret Manager configured
- ✅ All functions using `secrets:` pattern
- ✅ Render.com backend configured
- ✅ Backend code updated to use `process.env`
- ✅ APK builds with `--dart-define` (no `.env`)
- ✅ APK tested: NO secrets found
- ✅ Full payment flow works end-to-end
- ✅ All logs clean, no errors
- ✅ Production readiness: 95/100+ ✨

---

## 🆘 QUICK TROUBLESHOOTING

### "I forgot to rotate keys before setting up Firebase"
→ Go back and rotate them first, then create secrets in Firebase with NEW values

### "Firebase functions deployment failed"
→ Check: `firebase functions:secrets:list` shows your secrets created?
→ Redeploy: `firebase deploy --only functions`

### "APK still contains secrets"
→ Delete `.env` file: `del .env`
→ Rebuild: `flutter clean && BUILD_APK_PRODUCTION.bat`
→ Verify no `.env` in pubspec.yaml assets

### "Backend still can't connect to Razorpay"
→ Check Render environment has RAZORPAY_KEY_SECRET set
→ Verify value is NEW rotated key (not old)
→ Test: `curl https://fufaji-api.render.com/payments/razorpay-order`
→ Check logs for error message

### "Payment still fails after everything"
→ Check: Does backend code use `process.env.RAZORPAY_KEY_SECRET`?
→ Not `functions.config().razorpay.key_secret`?
→ Add validation: `if (!process.env.RAZORPAY_KEY_SECRET) throw new Error(...)`

---

## 🎯 START HERE

1. **Right now**: Read `MASTER_SECURITY_EXECUTION_PLAN.md` (30 min read)
2. **Today**: Do Emergency Actions (verify private, delete .env, start key rotation)
3. **Next 48h**: Parallel implementation (Firebase, Render, code updates)
4. **Final 24h**: Verification & testing
5. **Then**: Deploy to Play Store (optional, but recommended)

---

## 📞 KEEP HANDY

When you're working on each phase, keep these docs open:

- **Phase 1 (Emergency)**: `MASTER_SECURITY_EXECUTION_PLAN.md` (Emergency Actions section)
- **Phase 2 (Firebase)**: `FIREBASE_SECRET_MANAGER_SETUP.md`
- **Phase 3 (Render)**: `RENDER_BACKEND_ENV_SETUP.md`
- **Phase 4 (APK)**: `BUILD_APK_PRODUCTION.bat` (already ready to run)
- **Phase 5 (Test)**: `QUICK_REFERENCE_SECRET_ROTATION.md` (testing section)

---

## 🚀 YOU'VE GOT THIS!

This looks complex, but it's just:
1. Delete `.env` ✅
2. Rotate keys ✅
3. Add to Firebase ✅
4. Update code ✅
5. Build APK ✅
6. Test ✅

Most steps are copy-paste. Follow the checklists, one at a time.

**By June 26**, your app will be production-secure! 🎉

---

**Questions?** Re-read the relevant doc  
**Stuck?** Check Troubleshooting section  
**Ready?** Start with `MASTER_SECURITY_EXECUTION_PLAN.md`

Good luck! 💪
