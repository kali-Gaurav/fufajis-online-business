# 🔐 Fufaji Secrets Inventory & Security Audit
**Date**: June 24, 2026  
**Status**: CRITICAL - Secret migration in progress  
**Readiness**: ~40/100 (improved from 28/100 on Jun 21)

---

## Executive Summary

**GOOD NEWS:**
- ✅ `.env` is NOT bundled in APK (not in pubspec.yaml assets)
- ✅ `app_config.dart` correctly returns empty strings for backend secrets
- ✅ Firebase Functions already using modern `secrets:` pattern (functions/index.js line 9)
- ✅ `RuntimeConfigService` fetches configs from backend at runtime (lib/main.dart:71)
- ✅ `keystore_base64.txt` no longer in repo
- ✅ `setup_functions_config.bat` removed
- ✅ Backend `.env` file not in repo (only `.env.example` exists)

**REMAINING CRITICAL ISSUES:**
- ⚠️ Front-end `.env` file STILL EXISTS with exposed secrets (13 sensitive values)
- ⚠️ GitHub repo status unclear (needs verification it's private)
- ⚠️ Some backend services may still use deprecated `functions.config()` pattern
- ⚠️ Razorpay secret values uncertain (conflicting values mentioned in prior audit)
- ⚠️ AWS + Supabase credentials duplicate (need architecture consolidation)
- ⚠️ No Firebase Secret Manager configured yet
- ⚠️ GitHub Actions workflows may expose secrets via logs
- ⚠️ Build scripts still reference `.env` approach

---

## 🔴 CURRENTLY EXPOSED SECRETS (MUST ROTATE IMMEDIATELY)

### 1. **Frontend `.env` File** 
📍 **Location**: `C:\Projects\fufaji-online-business\.env`  
📊 **Exposure Level**: HIGH (file should not exist in repo at all)  
**Exposed Values**:
```
RAZORPAY_KEY_SECRET=ieGG9GcxgN0km2ZVcGyaGEG6
RAZORPAY_WEBHOOK_SECRET=Fufaji@Webhook2026!
WHATSAPP_TOKEN=EAASZAhYl2VnEBRnXysfExV3vNbuh39CFTHdIGxNk4mIUutmhDhuCAFo7rPP2HIEErCV5sDG8P0NbyobsBlaH
AWS_ACCESS_KEY_ID=AKIAYJF3JU7AKSWZEYV7
AWS_SECRET_ACCESS_KEY=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
SUPABASE_S3_ACCESS_KEY=AKIAYJF3JU7AKSWZEYV7
SUPABASE_S3_SECRET_KEY=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
SUPABASE_URL=https://orfikmmpbboesbxdiwzb.supabase.co
ANDROID_STORE_PASSWORD=fufaji123
ANDROID_KEY_PASSWORD=fufaji123
GOOGLE_MAPS_KEY=your_production_maps_key (placeholder, but if real: restricted?)
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id (example)
```

**Risk**: 
- These credentials would be leaked if .env is ever bundled in APK
- Current: NOT in APK, BUT file should never be committed or exist unencrypted
- If repo is public and .env was ever committed: **ALL THESE NEED ROTATION**

**Action**: 🚨 **IMMEDIATE**: Delete `.env` file locally, add to `.gitignore`, assume AWS/Razorpay/WhatsApp credentials are compromised, begin rotation.

---

### 2. **GitHub Repository Visibility**
📍 **Location**: `https://github.com/kali-Gaurav/fufajis-online-business`  
📊 **Risk Level**: CRITICAL (per June 21 audit)  
**Status**: Needs verification - May be private now (audit said PUBLIC with live secrets)  

**Action**: 
- ✅ Confirm repo is PRIVATE in GitHub Settings → Visibility
- If was PUBLIC: Assume all committed secrets are compromised
- Revoke: Razorpay keys, WhatsApp token, Twilio credentials, AWS keys

---

### 3. **Firebase Secrets (Already Configured)**
📍 **Current Status**: Partially migrated  
✅ `functions/index.js` line 9: Already using `secrets: ['RAZORPAY_WEBHOOK_SECRET']`  
⚠️ **Need to verify**: All functions follow this pattern

**Functions needing audit**:
- `functions/src/webhooks/razorpay_webhook.ts` - uses defineSecret?
- `functions/src/payments/createRazorpayOrder.ts` - uses defineSecret?
- `functions/src/payments/verifyRazorpayPayment.ts` - uses defineSecret?
- All functions in `functions/src/` and `functions/*.js`

---

## 📋 SECRETS CATEGORIZATION & STORAGE

### **Category A: Backend-Only (NEVER in APK)**
| Secret | Current Location | Target Location | Status | Note |
|--------|-----------------|-----------------|--------|------|
| RAZORPAY_KEY_SECRET | `.env` (exposed) | Firebase Secret Manager | ❌ Exposed - ROTATE |
| RAZORPAY_WEBHOOK_SECRET | `.env` (exposed) | Firebase Secret Manager | ❌ Exposed - ROTATE |
| WHATSAPP_TOKEN | `.env` (exposed) | Firebase Secret Manager | ❌ Exposed - ROTATE |
| WHATSAPP_PHONE_ID | `.env` | Firebase Secret Manager | ⚠️ OK (public identifier) |
| WHATSAPP_VERIFY_TOKEN | `.env` | Firebase Secret Manager | ❌ SECRET - ROTATE |
| TWILIO_ACCOUNT_SID | Not found | Firebase Secret Manager | ✅ Missing (good) |
| TWILIO_AUTH_TOKEN | Not found | Firebase Secret Manager | ✅ Missing (good) |
| RDS_PASSWORD | Not found | Firebase Secret Manager | ✅ Missing (good) |
| RDS_CONNECTION_STRING | Not found | Firebase Secret Manager | ✅ Missing (good) |
| STRIPE_SECRET_KEY | `.env` (empty) | Firebase Secret Manager | ✅ Not configured |
| AWS_SECRET_ACCESS_KEY | `.env` (exposed) | Firebase Secret Manager | ❌ Exposed - ROTATE |
| SUPABASE_S3_SECRET_KEY | `.env` (exposed) | Firebase Secret Manager | ❌ Exposed - ROTATE |
| GEMINI_API_KEY | `.env` (empty) | Firebase Secret Manager | ✅ Not configured |

### **Category B: Frontend-Safe (OK in APK via --dart-define)**
| Config | Current Location | Target Location | Status | Safe? |
|--------|-----------------|-----------------|--------|-------|
| API_BASE_URL | `.env` | --dart-define | ✅ Public URL | YES |
| RAZORPAY_KEY_ID | `.env` | --dart-define | ✅ Public key (rzp_live_*) | YES |
| STRIPE_PUBLISHABLE_KEY | `.env` | --dart-define | ✅ Public key (pk_live_*) | YES |
| GOOGLE_MAPS_KEY | `.env` | --dart-define | ⚠️ Needs restriction to app | MAYBE |
| SENTRY_DSN | `.env` | --dart-define | ✅ Public DSN | YES |
| SUPPORT_WHATSAPP_NUMBER | `.env` | --dart-define | ✅ Public number | YES |
| UPSTASH_REDIS_REST_URL | `.env` | --dart-define | ⚠️ Read-only token only | MAYBE |
| UPSTASH_REDIS_REST_TOKEN | `.env` | Backend endpoint | ❌ Backend only | NO |

### **Category C: Build Signing (Local .gitignore + GitHub Secrets)**
| Secret | Location | Storage | Status |
|--------|----------|---------|--------|
| ANDROID_STORE_PASSWORD | `.env` | GitHub Secrets + local key.properties | ⚠️ In .env (should be local only) |
| ANDROID_KEY_PASSWORD | `.env` | GitHub Secrets + local key.properties | ⚠️ In .env (should be local only) |
| ANDROID_KEY_ALIAS | `.env` | GitHub Secrets + local key.properties | ⚠️ In .env (should be local only) |
| ANDROID_STORE_FILE | `.env` (fufaji-upload-key.jks path) | Local .gitignore | ⚠️ File location in .env |
| google-services.json | Not found | GitHub Secrets | ✅ Missing (good) |
| keystore_base64 | Removed ✅ | GitHub Secrets (base64) | ✅ Removed from repo |

---

## 🛠️ CURRENT CONFIGURATION STATE

### Flutter/App Side
**File**: `lib/config/app_config.dart`
```dart
✅ GOOD: razorpayKeySecret() returns '' (line 49-51)
✅ GOOD: razorpayWebhookSecret() returns '' (line 75-77)
✅ GOOD: All secrets marked @deprecated with empty returns
✅ GOOD: Uses String.fromEnvironment() for public values (--dart-define)
```

### Firebase Functions Side
**File**: `functions/index.js` (partial)
```javascript
✅ GOOD: razorpayWebhook uses secrets: ['RAZORPAY_WEBHOOK_SECRET'] (line 9)
✅ GOOD: Accesses via process.env.RAZORPAY_WEBHOOK_SECRET (line 16)
⚠️ UNKNOWN: Other functions (.ts files) - need to audit
```

### Backend Services
**Files to audit**: `backend/src/services/*.js`, `backend/src/routes/*.js`
```javascript
❌ UNKNOWN: May still use deprecated functions.config()
❌ NEEDS: Conversion to process.env approach
❌ NEEDS: Firebase Secret Manager integration
```

### Build Configuration
**File**: `BUILD_APK.bat`
```batch
⚠️ NEEDS: Updated to use --dart-define instead of loading .env
```

---

## 🚨 IMMEDIATE ACTION ITEMS (Next 24 Hours)

### Step 1: Verify GitHub Repo Status
- [ ] Go to https://github.com/kali-Gaurav/fufajis-online-business/settings/visibility
- [ ] Confirm repo is PRIVATE
- [ ] If PUBLIC: Mark as INCIDENT, begin secret rotation NOW

### Step 2: Delete `.env` File & Add to `.gitignore`
```bash
# From your local machine (Windows terminal, NOT sandbox):
cd C:\Projects\fufaji-online-business
del .env
echo .env >> .gitignore
git add .gitignore
git commit -m "chore: add .env to gitignore"
git push
```

### Step 3: Create New Firebase Secret Manager Secrets
```bash
# From Firebase CLI on your local machine:
firebase functions:secrets:set RAZORPAY_KEY_SECRET --data "YOUR_NEW_KEY_FROM_RAZORPAY"
firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET --data "YOUR_NEW_WEBHOOK_SECRET"
firebase functions:secrets:set WHATSAPP_TOKEN --data "YOUR_NEW_WHATSAPP_TOKEN"
# ... and all others from Category A above
```

### Step 4: Rotate Compromised API Keys
- 🔴 **Razorpay**: Go to Razorpay Dashboard → Settings → API Keys → Regenerate both Key ID and Secret
- 🔴 **WhatsApp**: Regenerate token in Meta Business Manager
- 🔴 **AWS**: Go to IAM → Users → Create new access keys, revoke old ones
- 🔴 **Supabase**: Dashboard → Settings → API → Regenerate service_role key
- 🔴 **Twilio**: (if used) Account dashboard → API keys → Regenerate

### Step 5: Update All Functions to Use `secrets:`
Verify all functions in `functions/src/` use:
```typescript
exports.myFunction = functions.runWith({
  secrets: ['SECRET_NAME']
}).https.onRequest(async (req, res) => {
  const mySecret = process.env.SECRET_NAME;
  ...
});
```

---

## 📊 SECURITY READINESS SCORECARD

| Category | Score | Status | Details |
|----------|-------|--------|---------|
| **Frontend Secrets (APK)** | 85/100 | ✅ GOOD | Not bundled; .env exists but unused |
| **Backend Secrets (Databases)** | 20/100 | 🔴 CRITICAL | Still need Firebase Secret Manager setup |
| **Firebase Functions** | 60/100 | ⚠️ PARTIAL | Some using secrets:, others need audit |
| **Exposed Secrets (Public Repo)** | 0/100 | 🔴 CRITICAL | IF repo was public, all exposed |
| **Build/Signing Secrets** | 40/100 | ⚠️ MEDIUM | Need GitHub Secrets + local key.properties |
| **Documentation** | 30/100 | ⚠️ WEAK | Need runbook for secret rotation |
| **CI/CD Pipeline** | 20/100 | ⚠️ CRITICAL | Workflows need to use GitHub Secrets |
| **Backend API Endpoints** | 70/100 | ✅ GOOD | `/config/app-config` endpoint should work |
| **OVERALL READINESS** | **40/100** | 🔴 NOT READY | Needs secret migration + verification |

---

## 📚 Related Documentation

- Prior audit: [Infra/Secrets Audit 2026-06-21](project_infra_secrets_audit_20260621.md)
- Architecture: [Backend Architecture](BACKEND_ARCHITECTURE.md)
- Deployment: [Deployment Guide](DEPLOYMENT_GUIDE.md)
- Firebase: [Firebase Implementation Checklist](FIREBASE_IMPLEMENTATION_CHECKLIST.md)

---

## ✅ VERIFICATION CHECKLIST

Before declaring "Production Ready":

- [ ] GitHub repo is PRIVATE
- [ ] `.env` file deleted locally and in repo
- [ ] `.env` added to `.gitignore`
- [ ] All Firebase Functions use `secrets:` pattern with `process.env`
- [ ] All backend services use `process.env` (not `functions.config()`)
- [ ] Firebase Secret Manager has all Category A secrets
- [ ] GitHub Actions use `${{ secrets.SECRET_NAME }}`
- [ ] Backend deployed with env vars (Render.com or other platform)
- [ ] APK built with `--dart-define` flags only (no `.env` bundled)
- [ ] APK tested: no strings for backend secrets found
- [ ] End-to-end test: payment flow works with new secrets
- [ ] Monitoring: Sentry/logs show no secret leakage
- [ ] Runbook created: "How to rotate a secret"

---

**Generated**: 2026-06-24  
**Next Review**: 2026-06-25 (after secret rotation complete)
