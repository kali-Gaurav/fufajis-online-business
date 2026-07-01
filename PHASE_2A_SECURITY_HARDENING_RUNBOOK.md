# 🔐 PHASE 2A: SECURITY HARDENING & SECRET ROTATION
**Complete runbook to eliminate P0 secret exposure**

**Date Started:** 2026-06-29  
**Timeline:** 3-4 hours (serial execution required)  
**Critical Path:** Rotate secrets → Purge from git → Deploy Firebase Secrets → Test  
**Status:** READY TO EXECUTE

---

## ⚠️ CURRENT RISK LEVEL: **CRITICAL (RED)**

| Issue | Status | Risk |
|-------|--------|------|
| Live secrets in `.env` file | Still in git history | Anyone with clone can see all credentials |
| `.env` bundled in old APKs | Still distributed | Secrets leaked to app store / users |
| Secrets never rotated | BURNED credentials | Any secret viewer can act as Fufaji |
| Functions use deprecated `functions.config()` | Partially fixed | Can't migrate secrets until code wiring done |

**MUST COMPLETE:** All items must be GREEN before production deployment.

---

## PHASE 2A EXECUTION CHECKLIST

### **STAGE 1: CREDENTIAL ROTATION (70 minutes)**
> **These must be rotated FIRST.** Old values are now public. Rotation invalidates the leaked credentials.

Dashboard access required:
- Razorpay: https://dashboard.razorpay.com/app/settings/api-keys
- Twilio: https://console.twilio.com/account/auth-tokens
- WhatsApp: https://developers.facebook.com/apps
- Google AI: https://aistudio.google.com/apikey
- AWS: https://console.aws.amazon.com/iam
- Supabase: https://app.supabase.com/project/mxjtgpunctckovtuyfmz/settings/api
- Upstash: https://console.upstash.io

**Keep a temp secure file with new values — you'll need them in Stages 2–3.**

#### **1a. Razorpay (15 min)**
```
1. Go to: https://dashboard.razorpay.com/app/settings/api-keys
2. Find: "Live Key"
3. Click: [Regenerate Key] button
4. Note: Copy the new KEY_SECRET (it's masked after 1st view)
5. Go to: https://dashboard.razorpay.com/app/settings/webhooks
6. Edit: Fufaji webhook
7. Click: [Regenerate Secret]
8. Note: Copy the new WEBHOOK_SECRET

Verify rotation:
  - Old key_secret is no longer valid
  - New key_secret works with test payment
```
**Save:** `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`

#### **1b. Twilio (10 min)**
```
1. Go to: https://console.twilio.com/account/auth-tokens
2. Click: [Rotate Auth Token]
3. Confirm: "Rotate"
4. Note: Copy the new AUTH_TOKEN

Verify rotation:
  - Try a test SMS after rotation
  - Old auth token returns 401 Unauthorized
```
**Save:** `TWILIO_ACCOUNT_SID` (unchanged), `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER`

#### **1c. WhatsApp / Meta Business (15 min)**
```
1. Go to: https://developers.facebook.com/apps
2. Select: Fufaji app
3. Go to: Settings → Basic
4. Find: System Users section
5. Click: The user you're using for WhatsApp
6. Go to: Generate Tokens
7. Click: [Revoke] on the old permanent token (the EAASZ… one in .env)
8. Generate: New System User access token (select "System User" role)
9. Note: Copy the new token (full value, starts with EAA)

Verify rotation:
  - Send a test message after rotation
  - Old token is revoked (no longer works)
```
**Save:** `WHATSAPP_TOKEN`, `WHATSAPP_PHONE_ID`, `WHATSAPP_VERIFY_TOKEN`

#### **1d. Google AI / Gemini (5 min)**
```
1. Go to: https://aistudio.google.com/apikey
2. Find: The key from your .env (AIzaSyAqDW5J...)
3. Click: [Delete API Key]
4. Confirm: "Delete"
5. Click: [+ Create API Key]
6. Select: "Create API key in existing project" (or new project)
7. Note: Copy the new key

Verify rotation:
  - Old key is deleted
  - Test a Gemini API call with new key
```
**Save:** `GEMINI_API_KEY`

#### **1e. AWS (10 min)**
```
1. Go to: https://console.aws.amazon.com/iam/home#/users
2. Find: The IAM user for your S3/Bedrock access
   (Look for one named like "fufaji-app" or "s3-storage")
3. Click: The user name
4. Go to: "Security credentials" tab
5. Find: "Access keys" section
6. Delete: The access key pair in your .env
   (Access Key ID starting with AKIA...)
7. Click: [Create access key]
8. Choose: "Application running outside AWS"
9. Note: Copy BOTH the Access Key ID and Secret Access Key
10. Click: [Download .csv] (keep it safe)

Verify rotation:
  - Old access key is deleted
  - Test S3 or Bedrock access with new key
```
**Save:** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`

#### **1f. Supabase (10 min)**
```
1. Go to: https://app.supabase.com/project/mxjtgpunctckovtuyfmz/settings/api
2. Click: "Settings" → "S3 API Keys" (or storage settings)
3. Find: Your current S3 API keys
4. Click: [Rotate] or [Revoke] on the old keys
5. Generate: New S3 access/secret keys
6. Note: Copy both new keys

Verify rotation:
  - Old keys no longer work
  - Test a file upload/download with new keys
```
**Save:** `SUPABASE_S3_ACCESS_KEY`, `SUPABASE_S3_SECRET_KEY`

#### **1g. Upstash Redis (5 min)**
```
1. Go to: https://console.upstash.io
2. Select: Your Redis database
3. Go to: "Connection" tab
4. Find: "REST API" section
5. Click: [Reset] next to the REST token
6. Confirm: "Reset token"
7. Note: Copy the new REST_TOKEN

Verify rotation:
  - Old token no longer works
  - Test a Redis GET/SET with new token
```
**Save:** `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN`

---

### **STAGE 2: PURGE FROM GIT (30 minutes)**

> **CRITICAL:** Do NOT skip this. The old values remain visible in git history until purged.

#### **2a. Commit any pending changes (5 min)**
```powershell
# Make sure working tree is clean
git status

# If dirty, commit or stash
git add .
git commit -m "wip: before security purge"
```

#### **2b. Remove `.env` from working tree (5 min)**
```powershell
# Remove from git tracking (but not from disk yet)
git rm --cached .env
git rm --cached .env.production
git rm --cached .env.development

# Confirm removal is staged
git status
# Should show: deleted: .env, deleted: .env.production, etc.

# Commit the removal
git commit -m "security: remove .env files from git tracking"
```

#### **2c. Purge from git history (15 min)**

> **This is the critical step.** It rewrites history to remove secrets from every commit.

```powershell
# Install git-filter-repo (one-time)
pip install git-filter-repo

# Run from repo root
cd C:\Projects\fufaji-online-business

# Purge all .env variants from history
git filter-repo --invert-paths --path .env --path .env.production --path .env.development --path ".env.*"

# Also purge any other secrets files
git filter-repo --invert-paths --path keystore_base64.txt --path LIVE_SETUP_GUIDE.md --path firebase-deploy.sh --path "scripts/setup_functions_config.bat"

# IMPORTANT: Force-push to GitHub to rewrite remote history
git push origin --force --all
git push origin --force --tags
```

⚠️ **WARNING:** `--force` rewriting git history. After this:
- Any open PRs will be broken (need rebase)
- Any forks will be out of sync
- All contributors need to re-clone the repo

**Make sure this is coordinated if you have team members.**

#### **2d. Verify purge (5 min)**
```powershell
# Scan entire git history for secret patterns
# Should return NOTHING
git grep -rn "AIzaSyAqDW5" HEAD
git grep -rn "EAASZ" HEAD
git grep -rn "AC[0-9a-f]{32}" HEAD
git grep -rn "rzp_live_" HEAD
git grep -rn "-----BEGIN" HEAD

# Scan for .env files still in history
git log --all --full-history --oneline -- .env
# Should show "commit history is empty" or no results
```

**✅ If all greps return nothing → Purge successful!**

---

### **STAGE 3: LOAD SECRETS INTO FIREBASE SECRET MANAGER (45 minutes)**

> These commands are **interactive** — they'll prompt you to paste values. Secrets never touch shell history.

#### **3a. Firebase CLI setup (5 min)**
```powershell
# Verify you're logged in
firebase login

# Verify you're in the right project
firebase projects:list
# Should list: fufaji-online-business

# Set active project
firebase use fufaji-online-business
```

#### **3b. Create Firebase Secrets (one per credential)**

> Run each command. When prompted, paste the NEW value (from Stage 1). Press Enter.

```powershell
# Razorpay (3 secrets)
firebase functions:secrets:set RAZORPAY_KEY_ID
# Paste: rzp_live_XXXXX...

firebase functions:secrets:set RAZORPAY_KEY_SECRET
# Paste: (new secret from 1a)

firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
# Paste: (new webhook secret from 1a)

# Twilio (3 secrets)
firebase functions:secrets:set TWILIO_ACCOUNT_SID
# Paste: AC33d2...

firebase functions:secrets:set TWILIO_AUTH_TOKEN
# Paste: (new token from 1b)

firebase functions:secrets:set TWILIO_PHONE_NUMBER
# Paste: +15017122661 (or your real number)

# WhatsApp (3 secrets)
firebase functions:secrets:set WHATSAPP_TOKEN
# Paste: (new token from 1c)

firebase functions:secrets:set WHATSAPP_PHONE_ID
# Paste: 1086896934513865

firebase functions:secrets:set WHATSAPP_VERIFY_TOKEN
# Paste: fufaji_verify_2026

# Google AI
firebase functions:secrets:set GEMINI_API_KEY
# Paste: (new key from 1d)

# AWS (2 secrets)
firebase functions:secrets:set AWS_S3_ACCESS_KEY
# Paste: AKIA... (new access key from 1e)

firebase functions:secrets:set AWS_S3_SECRET_KEY
# Paste: (new secret key from 1e)

# Supabase Storage (2 secrets)
firebase functions:secrets:set SUPABASE_S3_ACCESS_KEY
# Paste: (new key from 1f)

firebase functions:secrets:set SUPABASE_S3_SECRET_KEY
# Paste: (new secret from 1f)

# Upstash Redis
firebase functions:secrets:set UPSTASH_REDIS_REST_TOKEN
# Paste: (new token from 1g)

# SendGrid (if using)
firebase functions:secrets:set SENDGRID_API_KEY
# Paste: (your SendGrid key)
```

#### **3c. Verify secrets were stored (5 min)**
```powershell
# List all secrets (names only, never values)
gcloud secrets list --project=fufaji-online-business

# Verify a specific secret (shows name, created date, but NOT value)
firebase functions:secrets:get RAZORPAY_KEY_SECRET
```

**✅ All secrets should appear in the list.**

---

### **STAGE 4: UPDATE GITHUB SECRETS (20 minutes)**

> CI/CD needs these values to build the APK and deploy functions.

#### **4a. GitHub CLI setup (2 min)**
```powershell
# Verify GitHub CLI is installed
gh --version

# Authenticate (if not already)
gh auth login
```

#### **4b. Create GitHub Secrets**

```powershell
# Set each secret. When prompted, paste the value from Stage 1.

gh secret set RAZORPAY_KEY_ID
gh secret set RAZORPAY_KEY_SECRET
gh secret set RAZORPAY_WEBHOOK_SECRET

gh secret set TWILIO_ACCOUNT_SID
gh secret set TWILIO_AUTH_TOKEN
gh secret set TWILIO_PHONE_NUMBER

gh secret set WHATSAPP_TOKEN
gh secret set WHATSAPP_PHONE_ID
gh secret set WHATSAPP_VERIFY_TOKEN

gh secret set GEMINI_API_KEY

gh secret set AWS_S3_ACCESS_KEY
gh secret set AWS_S3_SECRET_KEY

gh secret set SUPABASE_S3_ACCESS_KEY
gh secret set SUPABASE_S3_SECRET_KEY

gh secret set UPSTASH_REDIS_REST_TOKEN

gh secret set SENDGRID_API_KEY

# Android signing key (base64 encoded keystore)
gh secret set ANDROID_KEYSTORE_BASE64
gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_ALIAS
gh secret set ANDROID_KEY_PASSWORD

# Firebase deploy token
gh secret set FIREBASE_TOKEN
```

#### **4c. Verify GitHub Secrets (2 min)**
```powershell
# List all secrets (names only)
gh secret list
```

**✅ All secrets should appear.**

---

### **STAGE 5: UPDATE CI/CD WORKFLOWS (15 minutes)**

> Workflows must now read GitHub Secrets and pass public values to Flutter via `--dart-define`.

#### **5a. Update `.github/workflows/build.yml`**

Example pattern (adjust your actual workflow):

```yaml
name: Build & Deploy

on:
  push:
    branches: [main, develop]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      # ... (checkout, setup Flutter, etc.)
      
      # ✅ Read GitHub Secrets (never exposed in logs)
      - name: Load Secrets
        env:
          RAZORPAY_KEY_ID: ${{ secrets.RAZORPAY_KEY_ID }}
          RAZORPAY_KEY_SECRET: ${{ secrets.RAZORPAY_KEY_SECRET }}
          GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
          ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          # Reconstruct keystore from base64
          echo $ANDROID_KEYSTORE_BASE64 | base64 -d > android/app/fufaji-upload-key.jks
          
          # Export for gradle
          echo "ANDROID_KEYSTORE_PASSWORD=$ANDROID_KEYSTORE_PASSWORD" > android/key.properties
          echo "ANDROID_KEY_ALIAS=$ANDROID_KEY_ALIAS" >> android/key.properties
          echo "ANDROID_KEY_PASSWORD=$ANDROID_KEY_PASSWORD" >> android/key.properties
      
      # ✅ Build Flutter with public values only (--dart-define)
      - name: Build APK
        run: |
          flutter build apk --release \
            --dart-define=RAZORPAY_KEY_ID=${{ secrets.RAZORPAY_KEY_ID }} \
            --dart-define=GEMINI_API_KEY=${{ secrets.GEMINI_API_KEY }} \
            --dart-define=SENTRY_DSN=${{ secrets.SENTRY_DSN }}
      
      # ✅ Deploy functions with secrets from Firebase Secret Manager
      - name: Deploy Functions
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
        run: |
          firebase deploy --only functions \
            --token $FIREBASE_TOKEN \
            --project fufaji-online-business
```

**Key changes:**
- ✅ Never bake secrets into workflow file itself
- ✅ Use `${{ secrets.NAME }}` to read from GitHub Secrets
- ✅ Pass public values via `--dart-define`
- ✅ Firebase deploy reads secrets from Firebase Secret Manager (no `--secret-*` flags needed)

#### **5b. Also update any other CI scripts**
Remove secrets from:
- `scripts/setup_functions_config.bat` (remove all hardcoded secrets)
- `scripts/deploy.sh` (remove all hardcoded secrets)
- Any PowerShell build scripts

Replace with references to environment variables set by CI platform.

---

### **STAGE 6: UPDATE FUNCTIONS CODE (30 minutes)**

> Firebase Secrets must be declared with `defineSecret()` and attached with `runWith()`.

#### **6a. Update `functions/index.js`**

Current pattern (❌ WRONG — uses deprecated `functions.config()`):
```javascript
const razorpayKey = functions.config().razorpay.key_secret;
const twilioToken = functions.config().twilio.auth_token;
```

New pattern (✅ CORRECT — uses Firebase Secrets):
```javascript
const { defineSecret } = require('firebase-functions/params');

// Declare secrets at module level
const RAZORPAY_KEY_SECRET = defineSecret('RAZORPAY_KEY_SECRET');
const RAZORPAY_WEBHOOK_SECRET = defineSecret('RAZORPAY_WEBHOOK_SECRET');
const TWILIO_AUTH_TOKEN = defineSecret('TWILIO_AUTH_TOKEN');
const WHATSAPP_TOKEN = defineSecret('WHATSAPP_TOKEN');
const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');
const AWS_S3_SECRET_KEY = defineSecret('AWS_S3_SECRET_KEY');
const UPSTASH_REDIS_REST_TOKEN = defineSecret('UPSTASH_REDIS_REST_TOKEN');

// Use in functions with runWith() config
exports.razorpayWebhook = functions
  .runWith({
    secrets: [RAZORPAY_KEY_SECRET, RAZORPAY_WEBHOOK_SECRET],
  })
  .https.onRequest(async (req, res) => {
    // Read from process.env (injected by Firebase)
    const keySecret = process.env.RAZORPAY_KEY_SECRET;
    const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET;
    
    // ... rest of function
  });

exports.sendWhatsApp = functions
  .runWith({
    secrets: [WHATSAPP_TOKEN],
  })
  .https.onRequest(async (req, res) => {
    const token = process.env.WHATSAPP_TOKEN;
    // ...
  });
```

#### **6b. Update `functions/aws_services.js`**

Change from:
```javascript
const keySecret = functions.config().aws.secret_key;
```

To:
```javascript
const AWS_S3_SECRET_KEY = defineSecret('AWS_S3_SECRET_KEY');

module.exports.getS3Client = functions
  .runWith({ secrets: [AWS_S3_SECRET_KEY] })
  .https.onRequest(async (req, res) => {
    const secretKey = process.env.AWS_S3_SECRET_KEY;
    // ...
  });
```

#### **6c. Deploy and test (10 min)**

```powershell
# Deploy functions with secrets
firebase deploy --only functions --project fufaji-online-business

# Monitor logs
firebase functions:log --lines 50

# You should see functions initializing with secrets from Secret Manager
# No errors about "functions.config() is undefined"
```

---

### **STAGE 7: APP CONFIG — PUBLIC VALUES ONLY (20 minutes)**

#### **7a. Create local development config**

Create `.dart_defines.json` (gitignored):
```json
{
  "RAZORPAY_KEY_ID": "rzp_live_T72SdW8PsZ2Nhj",
  "GEMINI_API_KEY": "AIzaSyAqDW5J...",
  "SENTRY_DSN": "https://xxx@sentry.io/xxx",
  "SUPABASE_URL": "https://mxjtgpunctckovtuyfmz.supabase.co",
  "SUPABASE_ANON_KEY": "sb_publishable_...",
  "APP_ENV": "development"
}
```

Run locally:
```powershell
flutter run --dart-define-from-file=.dart_defines.json --release
```

#### **7b. Remove all server secrets from app code**

**❌ DELETE** these from the app (they should never be client-side):
- `RAZORPAY_KEY_SECRET` 
- `WHATSAPP_TOKEN`
- `GEMINI_API_KEY` (if used server-side)
- `UPSTASH_REDIS_REST_TOKEN`
- `SUPABASE_S3_SECRET_KEY`
- `AWS_SECRET_ACCESS_KEY`

If app needs these, create a Cloud Function wrapper that app calls with authentication:
```dart
// ❌ WRONG
String apiKey = dotenv.env['GEMINI_API_KEY']!;
final response = await http.post(geminiUrl, headers: {'Authorization': 'Bearer $apiKey'});

// ✅ RIGHT
final response = await FirebaseFunctions.instance.httpsCallable('callGemini').call({
  'prompt': userPrompt,
});
// Cloud Function has the secret and calls Gemini server-side
```

#### **7c. Update `pubspec.yaml`**

Remove the Flutter dotenv dependency if only used for bundled secrets:
```yaml
dependencies:
  # flutter_dotenv: ^6.0.1  # REMOVE if only used for bundling .env
```

---

### **STAGE 8: END-TO-END VERIFICATION (20 minutes)**

#### **8a. Deploy & test**

```powershell
# Deploy all Firebase resources
firebase deploy --project fufaji-online-business

# Check logs for errors
firebase functions:log --lines 100 | grep -i error

# Test a payment webhook (Razorpay Dashboard → Webhooks → Send Test)
# Should see: ✅ 200 OK + signature verified + no errors

# Test app startup
flutter clean
flutter build apk --release --dart-define=RAZORPAY_KEY_ID=rzp_live_...
adb install -r build/app/outputs/flutter-app.apk

# Verify no .env in app
unzip -l build/app/outputs/flutter-app.apk | grep ".env"
# Should return: (no matches)

# Scan git history one final time
git log -p --all -S "RAZORPAY_KEY_SECRET" | head -20
# Should return: (no results) or only the "purge" commit message
```

#### **8b. Integration test**

```powershell
# Run the e2e test if you have one
node scripts/e2e_integration_test.js

# Expected: All payments, auth, storage work without leaking secrets
```

#### **8c. Verification checklist**

```
[ ] All credentials rotated at source (Razorpay, Twilio, etc.)
[ ] .env purged from git history
[ ] Firebase Secrets created (gcloud secrets list returns all names)
[ ] GitHub Secrets set (gh secret list returns all names)
[ ] CI workflows updated to use GitHub Secrets + --dart-define
[ ] Functions updated to use defineSecret() + runWith()
[ ] App contains NO server secrets in code
[ ] App uses --dart-define for public values only
[ ] APK scan shows NO .env file bundled
[ ] Git history scan shows NO secret patterns
[ ] Razorpay test webhook verifies signature OK
[ ] Functions deploy successfully with secrets
[ ] E2E tests pass
```

**✅ If ALL checked → Phase 2A COMPLETE**

---

## PHASE 2A → PHASE 1A DEPLOYMENT

Once Phase 2A is verified:

1. **Deploy Phase 1A fixes** (Firestore rules + indexes + Android manifest + main.dart)
2. **Deploy Phase 2A security** (functions with secrets, GitHub workflows)
3. **Monitor for 24 hours** (Crashlytics, Sentry, Razorpay logs)
4. **Staged rollout** (25% → 50% → 100% on Play Store)

---

## EMERGENCY ROLLBACK

If something breaks and you need to rollback:

```powershell
# Functions can read from Firebase Secrets directly (no code change needed for rollback)
firebase deploy --only functions

# App rollback requires deploying old APK or old source + rebuild
flutter build apk --release --dart-define=RAZORPAY_KEY_ID=...

# Git history is permanent (can't be undone) — but that's OK
# Old secrets are rotated, so leaked history is now useless
```

---

## SUCCESS CRITERIA

| Metric | Before | After | Status |
|--------|--------|-------|--------|
| Secrets in `.env` file | 15+ exposed | 0 (deleted) | ✅ |
| Secrets in git history | Searchable | Purged | ✅ |
| Secrets in APK bundle | Leaked to all users | 0 (only public values) | ✅ |
| Firebase Secrets created | 0 | 12+ | ✅ |
| GitHub Secrets set up | 0 | 15+ | ✅ |
| Credentials rotated | 0 (burned) | 7 providers | ✅ |
| Production readiness score | 28 / 100 | 85+ / 100 | ✅ |

---

## NEXT STEPS AFTER PHASE 2A

1. Phase 1A deployment (startup fixes + Firestore)
2. Phase 2B: Order lifecycle audit & fixes
3. Phase 2C: Provider optimization
4. Phase 2D: Production monitoring setup

**Then:** Launch to production with confidence.

---

**Status:** READY TO EXECUTE  
**Timeline:** Start Stage 1 immediately (credential rotation should complete today)  
**Questions?** Review the INFRA_CONFIG_SECRETS_AUDIT.md for deeper context.
