# 🔐 Firebase Secret Manager Setup Guide
**Date**: June 24, 2026  
**Purpose**: Migrate all backend secrets to Firebase Secret Manager (defineSecret pattern)

---

## Step 1: Install/Update Firebase CLI

```bash
npm install -g firebase-tools@latest
firebase --version  # Should be 13.0.0 or higher

# Login to Firebase
firebase login
firebase projects:list  # Verify your project
```

---

## Step 2: Enable Secret Manager in Google Cloud

```bash
# Via gcloud CLI
gcloud services enable secretmanager.googleapis.com

# Or manually:
# 1. Go to https://console.cloud.google.com
# 2. Search "Secret Manager"
# 3. Enable API
```

---

## Step 3: Create Secrets in Firebase (One by One)

### ⚠️ **REPLACE ALL PLACEHOLDER VALUES WITH YOUR REAL PRODUCTION VALUES**

```bash
# Start Firebase console
firebase functions:secrets:set RAZORPAY_KEY_SECRET
# When prompted, paste the REAL key (regenerated from Razorpay dashboard)
# Example: ieGG9GcxgN0km2ZVcGyaGEG6

firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
# Example: Fufaji@Webhook2026!

firebase functions:secrets:set WHATSAPP_TOKEN
# Example: EAASZAhYl2VnEBRnXysfExV3vNbuh39CFTHdIGxNk4mIUutmhDhuCAFo7rPP2HIEErCV5sDG8P0NbyobsBlaH

firebase functions:secrets:set WHATSAPP_VERIFY_TOKEN
# Example: fufaji_verify_2026

firebase functions:secrets:set TWILIO_ACCOUNT_SID
# Example: ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

firebase functions:secrets:set TWILIO_AUTH_TOKEN
# Example: your_twilio_auth_token

firebase functions:secrets:set STRIPE_SECRET_KEY
# Example: sk_live_xxxxxxxxxxxxxxxxxxxxxxxx

firebase functions:secrets:set AWS_ACCESS_KEY_ID
# Example: AKIAYJF3JU7AKSWZEYV7
# NOTE: Consider using AWS IAM role instead of access keys for better security

firebase functions:secrets:set AWS_SECRET_ACCESS_KEY
# Example: QFGc+7ae37hfh5pO0w4WTB9xRhkYkrZfLq+WTeYk

firebase functions:secrets:set SUPABASE_S3_SECRET_KEY
# Example: (same as AWS_SECRET_ACCESS_KEY if using same creds)

firebase functions:secrets:set SUPABASE_ANON_KEY
# Example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

firebase functions:secrets:set RDS_PASSWORD
# Example: your_postgres_password

firebase functions:secrets:set RDS_CONNECTION_STRING
# Example: postgresql://user:password@host:5432/database

firebase functions:secrets:set GEMINI_API_KEY
# Example: AIzaSyDxxxxxxxxxxxxxxxxxxxxxxxx
# NOTE: Consider backend-only usage or rate limiting

firebase functions:secrets:set FIREBASE_ADMIN_SDK_KEY
# Export from Firebase Console → Project Settings → Service Accounts
# (if needed separately from default SDK)
```

### Verify Secrets Created:

```bash
firebase functions:secrets:list
# Output should show all secrets with their latest version
```

---

## Step 4: Update functions/package.json

Ensure these dependencies:

```json
{
  "dependencies": {
    "firebase-functions": "^5.1.0",  // MUST be 5.0.0+ for defineSecret
    "firebase-admin": "^13.0.0",
    "crypto": "^1.0.1"
  }
}
```

If versions are older, update:
```bash
cd functions
npm install --save firebase-functions@latest firebase-admin@latest
npm install
```

---

## Step 5: Migrate Functions to Use defineSecret()

### Pattern 1: HTTP Function (Razorpay Webhook Example)

**Before (❌ DEPRECATED)**:
```javascript
const functions = require('firebase-functions');

exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
    const RAZORPAY_WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET;
    // ...
});
```

**After (✅ MODERN)**:
```javascript
const functions = require('firebase-functions');
const { defineSecret } = require('firebase-functions/params');

const razorpayWebhookSecret = defineSecret('RAZORPAY_WEBHOOK_SECRET');

exports.razorpayWebhook = functions.runWith({
    secrets: [razorpayWebhookSecret]
}).https.onRequest(async (req, res) => {
    const RAZORPAY_WEBHOOK_SECRET = razorpayWebhookSecret.value();
    // ... rest of function
});
```

### Pattern 2: Callable Function

```javascript
exports.createRazorpayOrder = functions.runWith({
    secrets: ['RAZORPAY_KEY_SECRET', 'RAZORPAY_KEY_ID']
}).https.onCall(async (data, context) => {
    const keySecret = process.env.RAZORPAY_KEY_SECRET;
    const keyId = process.env.RAZORPAY_KEY_ID;
    // ...
});
```

### Pattern 3: Scheduled Function

```javascript
exports.processPaymentRetries = functions.runWith({
    secrets: ['RAZORPAY_KEY_SECRET', 'STRIPE_SECRET_KEY'],
    timeoutSeconds: 540
}).pubsub.schedule('every 1 hours').onRun(async (context) => {
    const razorpaySecret = process.env.RAZORPAY_KEY_SECRET;
    const stripeSecret = process.env.STRIPE_SECRET_KEY;
    // ...
});
```

### Pattern 4: Multiple Secrets

```javascript
const secrets = [
    'RAZORPAY_KEY_SECRET',
    'RAZORPAY_WEBHOOK_SECRET',
    'WHATSAPP_TOKEN',
    'AWS_SECRET_ACCESS_KEY'
];

exports.multiSecretFunction = functions.runWith({
    secrets: secrets
}).https.onRequest(async (req, res) => {
    const razorpaySecret = process.env.RAZORPAY_KEY_SECRET;
    const whatsappToken = process.env.WHATSAPP_TOKEN;
    // Access all via process.env
});
```

---

## Step 6: Files to Update

### Critical Function Files:

1. **functions/index.js** ✅ (Already updated!)
   - razorpayWebhook: Uses secrets pattern

2. **functions/src/webhooks/razorpay_webhook.ts** ❌ (Needs audit)
   ```typescript
   export const razorpayWebhook = functions.runWith({
       secrets: ['RAZORPAY_WEBHOOK_SECRET']
   }).https.onRequest(async (req, res) => {
       const secret = process.env.RAZORPAY_WEBHOOK_SECRET;
   });
   ```

3. **functions/src/payments/createRazorpayOrder.ts** ❌ (Needs audit)
   ```typescript
   export const createRazorpayOrder = functions.runWith({
       secrets: ['RAZORPAY_KEY_SECRET', 'RAZORPAY_KEY_ID']
   }).https.onCall(async (data, context) => {
       const secret = process.env.RAZORPAY_KEY_SECRET;
       const keyId = process.env.RAZORPAY_KEY_ID;
   });
   ```

4. **functions/src/payments/verifyRazorpayPayment.ts** ❌ (Needs audit)
   ```typescript
   export const verifyRazorpayPayment = functions.runWith({
       secrets: ['RAZORPAY_KEY_SECRET']
   }).https.onCall(async (data, context) => {
       const secret = process.env.RAZORPAY_KEY_SECRET;
   });
   ```

5. **functions/src/tasks/process_payment_retries.ts** ❌ (Needs audit)
   - Scheduled function: likely needs secrets

6. **backend/src/services/RazorpayService.js** ❌ (Needs audit)
   - If calling Firebase functions, already has secrets
   - If using local process.env, update to use Firebase Secret Manager or pass via API

---

## Step 7: Update backend/src/services/*.js

For services that DON'T run in Firebase Functions (e.g., Node.js on Render):

```javascript
// ❌ OLD (deprecated):
const config = functions.config().razorpay;
const keySecret = config.key_secret;

// ✅ NEW:
const keySecret = process.env.RAZORPAY_KEY_SECRET;

// With validation:
if (!keySecret) {
    throw new Error('RAZORPAY_KEY_SECRET is not configured in environment variables');
}
```

**Files to update**:
- `backend/src/services/RazorpayService.js`
- `backend/src/services/SmsService.js` (Twilio)
- `backend/src/services/genkitService.js` (if using Gemini)
- `backend/src/routes/webhooks.js`
- `backend/src/routes/config.js`

---

## Step 8: Deploy Functions with Secrets

```bash
cd functions
firebase deploy --only functions

# Output will show:
# ✓ function1 deployed (runtime: nodejs18)
# ✓ razorpayWebhook deployed (runtime: nodejs18)
#   secrets: [RAZORPAY_WEBHOOK_SECRET]
```

### Troubleshooting:

If deployment fails with "Secret not found":
```bash
firebase functions:secrets:list
# Verify the secret name matches exactly (case-sensitive)

# If secret not listed, create it:
firebase functions:secrets:set SECRET_NAME
```

---

## Step 9: Test Functions Locally

```bash
# Start emulator
firebase emulators:start --only functions

# In another terminal, test:
curl -X POST http://localhost:5001/your-project/us-central1/razorpayWebhook \
  -H "Content-Type: application/json" \
  -d '{"event":"payment.captured","payload":{"payment":{"entity":{"id":"pay_123","amount":10000,"notes":{"order_id":"order_456"}}}}}'

# Logs should show secret was accessed successfully (no "undefined" errors)
```

---

## Step 10: Verify in Production

After deployment:

```bash
# Check function logs
firebase functions:log

# Look for:
# ✅ "RAZORPAY_WEBHOOK_SECRET resolved"
# ✅ "payment.captured processed"
# ❌ "undefined" or "SECRET_NAME is not defined"
```

---

## 🚨 Critical Reminders

1. **Never** log secrets:
   ```javascript
   ❌ console.log(`Secret: ${process.env.RAZORPAY_KEY_SECRET}`);
   ✅ console.log('Secret loaded successfully');
   ```

2. **Never** return secrets in responses:
   ```javascript
   ❌ res.json({ razorpaySecret: process.env.RAZORPAY_KEY_SECRET });
   ✅ res.json({ status: 'success' });
   ```

3. **Always** validate on startup:
   ```javascript
   if (!process.env.RAZORPAY_KEY_SECRET) {
       throw new Error('Missing RAZORPAY_KEY_SECRET');
   }
   ```

4. **Document** which functions use which secrets in comments:
   ```javascript
   /**
    * Handles Razorpay payment webhooks
    * 
    * Secrets: RAZORPAY_WEBHOOK_SECRET
    * Environment: production, staging
    */
   exports.razorpayWebhook = functions.runWith({
       secrets: ['RAZORPAY_WEBHOOK_SECRET']
   }).https.onRequest(async (req, res) => {
       // ...
   });
   ```

---

## Verification Checklist

- [ ] All secrets created in Firebase Secret Manager
- [ ] All Firebase Functions use `secrets:` array
- [ ] All functions access via `process.env.SECRET_NAME`
- [ ] No `functions.config()` calls remain
- [ ] Functions tested locally with emulator
- [ ] Functions deployed and logs show success
- [ ] Backend services updated to use `process.env`
- [ ] No secrets logged or returned in responses
- [ ] Error handling validates all required secrets

---

**Status**: In Progress  
**Next**: Backend environment configuration (Render.com)
