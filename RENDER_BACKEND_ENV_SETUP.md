# 🚀 Render.com Backend Environment Setup
**Date**: June 24, 2026  
**Purpose**: Configure all backend secrets and configs in Render.com Node.js service

---

## Step 1: Access Render Dashboard

1. Go to https://render.com
2. Log in with your account
3. Click "Dashboard" → Find your service "fufaji-api"
4. Click on the service name

---

## Step 2: Navigate to Environment Variables

**In Render Dashboard:**
1. Click the service name (e.g., "fufaji-api")
2. Left sidebar → "Environment"
3. You'll see "Environment Variables" section
4. Click "Add Environment Variable"

---

## Step 3: Add Backend-Only Secrets

### ⚠️ **REPLACE ALL VALUES WITH YOUR REAL PRODUCTION CREDENTIALS**

Add each of these as separate environment variables:

### Payment Gateway (Razorpay)
```
RAZORPAY_KEY_SECRET = ieGG9GcxgN0km2ZVcGyaGEG6
(Get from: Razorpay Dashboard → Settings → API Keys → Secret Key)

RAZORPAY_KEY_ID = rzp_live_Sr7JfZt4NbXzMw
(This is your public key, safe to share)

RAZORPAY_WEBHOOK_SECRET = Fufaji@Webhook2026!
(Get from: Razorpay Dashboard → Settings → Webhooks → Secret Key)
```

### Payment Gateway (Stripe) - Fallback
```
STRIPE_SECRET_KEY = sk_live_xxxxxxxxxxxxxxxxxxxxxxxx
(Get from: Stripe Dashboard → Developers → API Keys → Secret Key)

STRIPE_PUBLISHABLE_KEY = pk_live_xxxxxxxxxxxxxxxxxxxxxxxx
(This is your public key, safe to share)
```

### WhatsApp Business API
```
WHATSAPP_TOKEN = EAASZAhYl2VnEBRnXysfExV3vNbuh39CFTHdIGxNk4mIUutmhDhuCAFo7rPP2HIEErCV5sDG8P0NbyobsBlaH
(Get from: Meta Business Manager → Settings → System Users → Verify token)

WHATSAPP_PHONE_ID = 1086896934513865
(Get from: Meta Business Manager → WhatsApp → Phone Numbers)

WHATSAPP_VERIFY_TOKEN = fufaji_verify_2026
(You create this - for webhook verification)
```

### SMS (Twilio)
```
TWILIO_ACCOUNT_SID = ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
(Get from: Twilio Console → Account Info)

TWILIO_AUTH_TOKEN = your_auth_token_here
(Get from: Twilio Console → Account Info)

TWILIO_PHONE_NUMBER = +15017122661
(Your Twilio phone number)
```

### Database (PostgreSQL / RDS)
```
RDS_HOST = your-database-host.rds.amazonaws.com
RDS_PORT = 5432
RDS_USER = postgres
RDS_PASSWORD = your_postgres_password
RDS_DATABASE = postgres

RDS_CONNECTION_STRING = postgresql://user:password@host:port/database
(Or use individual RDS_* variables above)
```

### AWS S3 & Services
```
AWS_ACCESS_KEY_ID = AKIAYJF3JU7AKSWZEYV7
AWS_SECRET_ACCESS_KEY = QFGc+7ae37hfh5pO0w4WTB9xRhkYkrZfLq+WTeYk
AWS_REGION = ap-south-1
```

### Supabase
```
SUPABASE_URL = https://orfikmmpbboesbxdiwzb.supabase.co
SUPABASE_ANON_KEY = your_supabase_anon_key
SUPABASE_S3_ACCESS_KEY = AKIAYJF3JU7AKSWZEYV7
SUPABASE_S3_SECRET_KEY = QFGc+7ae37hfh5pO0w4WTB9xRhkYkrZfLq+WTeYk
```

### Caching (Upstash Redis)
```
UPSTASH_REDIS_REST_URL = https://your-upstash-url.upstash.io
UPSTASH_REDIS_REST_TOKEN = your_redis_token
```

### AI/ML (Google Gemini)
```
GEMINI_API_KEY = AIzaSyDxxxxxxxxxxxxxxxxxxxxxxxx
(Get from: Google Cloud Console → APIs → Generative AI → API Key)
```

### Monitoring & Logging
```
SENTRY_DSN = https://your-sentry-dsn@sentry.io/project-id
(Get from: Sentry Dashboard → Project Settings → Client Keys)
```

### Configuration
```
NODE_ENV = production
API_BASE_URL = https://fufaji-api.render.com
(Your Render.com service URL)

SUPPORT_WHATSAPP_NUMBER = +91XXXXXXXXXX
APK_DOWNLOAD_URL = https://github.com/kali-Gaurav/fufajis-online-business/releases/download
```

### Firebase Admin SDK
```
FIREBASE_PROJECT_ID = your-firebase-project-id
FIREBASE_PRIVATE_KEY_ID = key-id-from-service-account-json
FIREBASE_PRIVATE_KEY = "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL = firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
FIREBASE_CLIENT_ID = xxxxxxxxxxxxx
FIREBASE_AUTH_URI = https://accounts.google.com/o/oauth2/auth
FIREBASE_TOKEN_URI = https://oauth2.googleapis.com/token
FIREBASE_AUTH_PROVIDER_X509_CERT_URL = https://www.googleapis.com/oauth2/v1/certs
FIREBASE_CLIENT_X509_CERT_URL = https://www.googleapis.com/robot/v1/metadata/x509/...
```

---

## Step 4: How to Add Variables in Render

**For each variable:**

1. In "Environment Variables" section, click **"Add Environment Variable"**
2. **Key**: Enter the variable name (e.g., `RAZORPAY_KEY_SECRET`)
3. **Value**: Enter the secret value
4. Click **"Save"** (or drag to reorder if needed)

**Example Screenshot:**
```
Key:   RAZORPAY_KEY_SECRET
Value: ieGG9GcxgN0km2ZVcGyaGEG6
       [Save] [X]
```

---

## Step 5: Verify Environment Variables are Set

After adding all variables:

1. Go to your service → "Environment" section
2. Scroll to "Environment Variables"
3. You should see all variables listed
4. Click on a variable to see it's masked (shouldn't see full value)

---

## Step 6: Deploy Backend with New Environment

1. In Render Dashboard, find your "fufaji-api" service
2. Click **"Manual Deploy"** or push to GitHub (if auto-deploy enabled)
3. Watch deployment logs in "Logs" tab
4. Look for messages like:
   ```
   INFO: Configuration loaded successfully
   INFO: Payment service initialized
   INFO: WhatsApp service initialized
   ```

---

## Step 7: Test Backend Configuration

Once deployed, test that backend can read environment variables:

### Test 1: Config Endpoint
```bash
curl -X GET https://fufaji-api.render.com/config/app-config

# Expected response (only PUBLIC configs):
{
  "apiBaseUrl": "https://fufaji-api.render.com",
  "razorpayKeyId": "rzp_live_Sr7JfZt4NbXzMw",
  "stripePublishableKey": "pk_live_...",
  "googleMapsKey": "...",
  "sentryDsn": "https://...",
  "supportWhatsappNumber": "+91..."
}
```

### Test 2: Payment Service
```bash
curl -X POST https://fufaji-api.render.com/payments/razorpay-order \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 10000,
    "currency": "INR",
    "customerId": "cust_123"
  }'

# Expected: 
# ✅ Success: Order created (razorpay_order_id returned)
# ❌ Error: "RAZORPAY_KEY_SECRET not configured" = missing secret
```

### Test 3: WhatsApp Service
```bash
curl -X POST https://fufaji-api.render.com/communications/whatsapp-message \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+919876543210",
    "message": "Test message"
  }'

# Expected:
# ✅ Success: Message sent
# ❌ Error: "WHATSAPP_TOKEN not configured" = missing secret
```

### Test 4: Check Logs for Errors
```
In Render Dashboard → Logs:
- Look for "secret" or "undefined" errors
- Look for "RAZORPAY", "WHATSAPP", "STRIPE" related messages
- ✅ Should see: "Initialized successfully"
- ❌ Should NOT see: "Cannot read property of undefined"
```

---

## Step 8: Backend Service Code Updates

Ensure all backend services use `process.env`:

**File**: `backend/src/secrets.js`
```javascript
// ✅ MODERN (Render.com):
module.exports = {
  razorpayKeySecret: process.env.RAZORPAY_KEY_SECRET,
  razorpayKeyId: process.env.RAZORPAY_KEY_ID,
  razorpayWebhookSecret: process.env.RAZORPAY_WEBHOOK_SECRET,
  whatsappToken: process.env.WHATSAPP_TOKEN,
  twilioAccountSid: process.env.TWILIO_ACCOUNT_SID,
  // ... etc
};
```

**File**: `backend/src/services/RazorpayService.js`
```javascript
const { razorpayKeySecret, razorpayKeyId } = require('../secrets');

if (!razorpayKeySecret) {
    throw new Error('RAZORPAY_KEY_SECRET is not configured');
}

const razorpay = new Razorpay({
    key_id: razorpayKeyId,
    key_secret: razorpayKeySecret
});
```

---

## Step 9: Rotate Secrets Regularly

### Monthly Rotation Checklist:

- [ ] Razorpay: Re-generate API keys, update RAZORPAY_KEY_SECRET
- [ ] WhatsApp: Verify token hasn't expired, regenerate if needed
- [ ] AWS: Create new access keys, revoke old ones
- [ ] Stripe: Review API usage, rotate key if suspicious activity
- [ ] Supabase: Verify service role key security

After rotation:
1. Add new secret to Render environment
2. Run tests (Test 1-3 above)
3. Delete old secret from Render
4. Monitor logs for errors

---

## Troubleshooting

### Issue: "secret is undefined"
```javascript
❌ Problem: const secret = process.env.RAZORPAY_KEY_SECRET; // undefined
✅ Solution: 
  1. Check variable name matches exactly (case-sensitive)
  2. Verify variable is in Render environment
  3. Redeploy service (sometimes cached)
  4. Check logs: firebase functions:log
```

### Issue: "Cannot connect to database"
```
✅ Solution:
  1. Verify RDS_CONNECTION_STRING is correct
  2. Check RDS_HOST, RDS_PORT, RDS_USER, RDS_PASSWORD individually
  3. Test from Render: psql postgresql://user:pass@host/db
  4. Check RDS security group allows Render IP
```

### Issue: "Razorpay webhook fails"
```
✅ Solution:
  1. Verify RAZORPAY_WEBHOOK_SECRET matches Razorpay dashboard
  2. Check webhook signature validation in code
  3. Test with: curl -X POST -d '{}' https://fufaji-api.render.com/webhooks/razorpay
  4. Check logs for "HMAC mismatch"
```

### Issue: "Sentry not receiving errors"
```
✅ Solution:
  1. Verify SENTRY_DSN format: https://key@sentry.io/projectid
  2. Check Sentry dashboard for API key validity
  3. Re-initialize Sentry in code after loading env
  4. Test error: throw new Error('test') in endpoint
```

---

## 🔐 Security Best Practices

1. **Never log secrets:**
   ```javascript
   ❌ console.log(`Secret: ${process.env.RAZORPAY_KEY_SECRET}`);
   ✅ console.log('Secret loaded successfully');
   ```

2. **Never expose in responses:**
   ```javascript
   ❌ res.json({ secret: process.env.RAZORPAY_KEY_SECRET });
   ✅ res.json({ status: 'success' });
   ```

3. **Validate on startup:**
   ```javascript
   if (!process.env.RAZORPAY_KEY_SECRET) {
       throw new Error('Missing RAZORPAY_KEY_SECRET - cannot start server');
   }
   ```

4. **Rotate regularly:**
   - Razorpay: Monthly
   - AWS: Quarterly
   - Supabase: Quarterly
   - Stripe: Annually or on suspicious activity

---

## Verification Checklist

- [ ] All environment variables added to Render
- [ ] No secrets logged in output
- [ ] Config endpoint returns only PUBLIC values
- [ ] Payment endpoint works with Razorpay
- [ ] WhatsApp endpoint sends messages successfully
- [ ] Database connection works
- [ ] Sentry receives error reports
- [ ] All tests pass without "undefined" errors
- [ ] Monitoring/logs show service running healthy

---

**Status**: Ready for implementation  
**Next**: Deploy Firebase Functions with defineSecret()
