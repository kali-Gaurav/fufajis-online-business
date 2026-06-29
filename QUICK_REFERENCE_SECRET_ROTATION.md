# ⚡ Quick Reference: How to Rotate Individual Secrets

**Use this when you need to rotate a single secret after initial setup**

---

## Razorpay Secret Key

```bash
# 1. GET NEW KEY
#    Go to: https://dashboard.razorpay.com/settings/api
#    Click "Generate New Key" or regenerate existing
#    Copy the SECRET KEY (not Key ID)

# 2. UPDATE FIREBASE SECRET MANAGER
firebase functions:secrets:set RAZORPAY_KEY_SECRET
# Paste the new secret when prompted

# 3. UPDATE RENDER.COM
#    Go to: render.com → fufaji-api → Environment
#    Edit RAZORPAY_KEY_SECRET variable
#    Paste new value
#    Click Save → Service redeploys automatically

# 4. TEST
#    curl -X POST https://fufaji-api.render.com/payments/razorpay-order \
#      -H "Content-Type: application/json" \
#      -d '{"amount": 10000, "customerId": "test"}'
#    Should succeed (not error about secret)

# 5. VERIFY
#    firebase functions:log | grep RAZORPAY
#    Should see: "resolved successfully" or no errors
```

---

## Razorpay Webhook Secret

```bash
# 1. GET NEW KEY
#    Go to: https://dashboard.razorpay.com/settings/webhooks
#    Find your webhook → Click Settings
#    Scroll to "Secret" → Regenerate or copy existing

# 2. UPDATE FIREBASE SECRET MANAGER
firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
# Paste the new secret

# 3. UPDATE RENDER.COM
#    render.com → fufaji-api → Environment
#    Edit RAZORPAY_WEBHOOK_SECRET
#    Paste new value → Save

# 4. TEST
#    Simulate webhook from Razorpay dashboard (if available)
#    Or wait for next payment and check if order updates correctly
```

---

## WhatsApp Token

```bash
# 1. GET NEW TOKEN
#    Go to: https://business.facebook.com
#    Settings → System Users → Select user
#    Click "Generate New Token"
#    Copy token

# 2. UPDATE FIREBASE SECRET MANAGER
firebase functions:secrets:set WHATSAPP_TOKEN
# Paste the new token

# 3. UPDATE RENDER.COM
#    render.com → fufaji-api → Environment
#    Edit WHATSAPP_TOKEN
#    Paste new value → Save

# 4. TEST
#    curl -X POST https://fufaji-api.render.com/communications/whatsapp-message \
#      -d '{"phone": "+91XXXXXXXXXX", "message": "Test"}'
#    Should send message successfully
```

---

## AWS Credentials (Access Key & Secret)

```bash
# 1. CREATE NEW ACCESS KEY
#    Go to: https://console.aws.amazon.com/iam
#    Users → Your User → Security Credentials
#    Click "Create access key"
#    Choose use case, click "Create"
#    Copy both Access Key ID and Secret Access Key

# 2. UPDATE FIREBASE SECRET MANAGER
firebase functions:secrets:set AWS_ACCESS_KEY_ID
# Paste new Access Key ID

firebase functions:secrets:set AWS_SECRET_ACCESS_KEY
# Paste new Secret Access Key

# 3. UPDATE RENDER.COM
#    render.com → fufaji-api → Environment
#    Edit AWS_ACCESS_KEY_ID → Paste new value
#    Edit AWS_SECRET_ACCESS_KEY → Paste new value
#    Save (redeploys)

# 4. DELETE OLD KEY
#    AWS IAM console → Users → Security Credentials
#    Old Access Key → Click "Deactivate" or "Delete"

# 5. TEST
#    Verify S3 uploads work (file upload feature in app)
```

---

## Supabase Secret Key

```bash
# 1. REGENERATE KEY
#    Go to: https://app.supabase.com
#    Project → Settings → API
#    "Service role key" → Regenerate
#    Copy new key

# 2. UPDATE FIREBASE SECRET MANAGER
firebase functions:secrets:set SUPABASE_S3_SECRET_KEY
# Paste new key

# 3. UPDATE RENDER.COM
#    render.com → fufaji-api → Environment
#    Edit SUPABASE_S3_SECRET_KEY
#    Paste new value → Save

# 4. TEST
#    File uploads to Supabase S3 should work
```

---

## Stripe Secret Key (if used)

```bash
# 1. REGENERATE KEY
#    Go to: https://dashboard.stripe.com
#    Developers → API Keys
#    "Secret Key" → Regenerate
#    Copy new key

# 2. UPDATE FIREBASE SECRET MANAGER
firebase functions:secrets:set STRIPE_SECRET_KEY
# Paste new key

# 3. UPDATE RENDER.COM
#    render.com → fufaji-api → Environment
#    Edit STRIPE_SECRET_KEY
#    Paste new value → Save

# 4. TEST
#    Create test payment with Stripe
#    curl -X POST https://fufaji-api.render.com/payments/stripe-order \
#      -d '{"amount": 10000}'
```

---

## Twilio Credentials (if used)

```bash
# 1. REGENERATE AUTH TOKEN
#    Go to: https://www.twilio.com/console
#    Account Info → Auth Token → Regenerate
#    Copy new token

# 2. UPDATE FIREBASE SECRET MANAGER
firebase functions:secrets:set TWILIO_AUTH_TOKEN
# Paste new token

# 3. UPDATE RENDER.COM
#    render.com → fufaji-api → Environment
#    Edit TWILIO_AUTH_TOKEN
#    Paste new value → Save

# 4. TEST
#    Send SMS from app (if feature exists)
#    Check logs for success
```

---

## SENTRY_DSN

```bash
# 1. VERIFY KEY
#    Go to: https://sentry.io
#    Project → Settings → Client Keys (DSN)

# 2. UPDATE FIREBASE SECRET MANAGER
firebase functions:secrets:set SENTRY_DSN
# Paste DSN

# 3. UPDATE RENDER.COM
#    render.com → fufaji-api → Environment
#    Edit SENTRY_DSN
#    Paste value → Save

# 4. TEST
#    Check if errors appear in Sentry dashboard
#    Trigger test error: throw new Error('test')
```

---

## Database Password (RDS_PASSWORD)

```bash
# 1. CHANGE RDS PASSWORD
#    Go to: https://console.aws.amazon.com/rds
#    Databases → Your database
#    Modify → Master Password → New password
#    Apply immediately or during maintenance window

# 2. UPDATE FIREBASE SECRET MANAGER
firebase functions:secrets:set RDS_PASSWORD
# Paste new password

# 3. UPDATE RENDER.COM
#    render.com → fufaji-api → Environment
#    Edit RDS_PASSWORD
#    Paste new value → Save

# 4. TEST
#    App should connect to database
#    Orders, products, etc. should load
```

---

## Gemini API Key (if used)

```bash
# 1. CREATE/REGENERATE KEY
#    Go to: https://console.cloud.google.com
#    APIs & Services → Credentials
#    Create API Key or regenerate existing
#    Copy new key

# 2. UPDATE FIREBASE SECRET MANAGER
firebase functions:secrets:set GEMINI_API_KEY
# Paste new key

# 3. UPDATE RENDER.COM
#    render.com → fufaji-api → Environment
#    Edit GEMINI_API_KEY
#    Paste new value → Save

# 4. TEST
#    AI features (if any) should work
```

---

## After EVERY Secret Rotation

```bash
# 1. VERIFY IN FIREBASE
firebase functions:secrets:list
# Should show new version number for rotated secret

# 2. VERIFY IN RENDER
# Dashboard → Environment → Check value updated

# 3. REDEPLOY FUNCTIONS
firebase deploy --only functions
# Should show: "functions deployed"

# 4. REDEPLOY BACKEND
# (Render auto-redeploys when env vars change)
# Or manually trigger: Dashboard → Manual Deploy

# 5. CHECK LOGS
firebase functions:log
# Should see no "undefined" or "error" messages for that secret

# 6. TEST AFFECTED SERVICE
# If Razorpay: Test payment flow
# If WhatsApp: Test message send
# If AWS: Test file upload
# etc.

# 7. MONITOR FOR ERRORS
# Sentry dashboard → Check for new errors
# Render logs → Check for errors from that service
# If all green: Rotation successful! ✅
```

---

## Emergency: Secret Leaked

If a secret is **actively compromised** (exposed in error, sent to wrong person, etc.):

```bash
# 1. ROTATE IMMEDIATELY
firebase functions:secrets:set COMPROMISED_SECRET
# Enter new value NOW

# 2. UPDATE FIREBASE
firebase deploy --only functions

# 3. UPDATE RENDER
render.com → Environment → Update value → Save

# 4. REVOKE OLD CREDENTIAL
# Go to service dashboard (Razorpay, Stripe, AWS, etc.)
# Deactivate or delete the old key/token

# 5. TEST
# Verify service still works with new credential

# 6. AUDIT
# Check logs to see if old credential was used after leak
# If yes: Investigate what happened

# 7. DOCUMENT
# Update SECRET_INVENTORY_AUDIT.md with:
#   - Which secret was leaked
#   - When it was rotated
#   - Whether old value was used after leak
```

---

## Firebase Command Reference

```bash
# List all secrets
firebase functions:secrets:list

# Create/update a secret
firebase functions:secrets:set SECRET_NAME
# Enter value when prompted

# Delete a secret (careful!)
firebase functions:secrets:destroy SECRET_NAME

# View secret versions (metadata only, not values)
firebase functions:secrets:get SECRET_NAME

# Deploy functions with new secrets
firebase deploy --only functions

# Check function logs
firebase functions:log

# View real-time logs
firebase functions:log --follow

# Test locally with emulator
firebase emulators:start --only functions
```

---

## Render.com Environment Variable Reference

```
Dashboard → Your Service (fufaji-api) → Environment

To Edit:
1. Find variable in "Environment Variables" list
2. Click on the variable
3. Change value
4. Click "Save"
5. Service automatically redeploys

To Add New:
1. Click "Add Environment Variable"
2. Enter Key and Value
3. Click "Save"
4. Service auto-redeploys

To Delete:
1. Find variable
2. Click X button
3. Confirm
4. Service auto-redeploys
```

---

## Rotation Schedule Recommendation

| Secret | Frequency | Notes |
|--------|-----------|-------|
| RAZORPAY_KEY_SECRET | Monthly | If high volume, monthly. Otherwise quarterly |
| RAZORPAY_WEBHOOK_SECRET | Monthly | Same as key secret |
| WHATSAPP_TOKEN | Quarterly | Or when Meta sends notifications |
| AWS_ACCESS_KEY | Quarterly | Follow AWS best practices |
| SUPABASE_SECRET | Quarterly | Or after security audit |
| STRIPE_SECRET_KEY | Annually | Or after suspicious activity |
| RDS_PASSWORD | Quarterly | Or after security patch |
| TWILIO_AUTH_TOKEN | Annually | Or when credentials suspected compromised |
| GEMINI_API_KEY | Quarterly | Or when API quota suspicious |

---

**Last Updated**: June 24, 2026  
**Review Frequency**: Monthly (audit against schedule above)
