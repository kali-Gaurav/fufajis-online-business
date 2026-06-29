# RAZORPAY KEY ROTATION - EXECUTION GUIDE
**June 24, 2026 | 8:00 AM - 12:00 PM (4-hour execution window)**

---

## OVERVIEW

This guide provides step-by-step instructions to rotate Razorpay API credentials and webhooks. The plan addresses the critical security issue where `key_secret` was previously used for webhook signature verification (incorrect) instead of using a separate `webhook_secret` (correct).

**Critical Success Criteria**:
- All three credentials are generated FRESH (not reused)
- `key_secret ≠ webhook_secret` (they MUST be different)
- RazorpayService validates this separation at initialization
- All tests pass with new credentials
- GitHub is cleaned of all leaked old credentials

---

## TIMELINE & RESPONSIBILITIES

| Time | Duration | Task | Owner |
|------|----------|------|-------|
| 8:00 AM | 30 min | **STEP 1**: Generate new credentials at Razorpay Dashboard | Backend Engineer |
| 8:30 AM | 30 min | **STEP 2**: Update all environment files (.env files) | Backend Engineer |
| 9:00 AM | 1 hour | **STEP 3**: Verify RazorpayService code (already correct) | Backend Engineer |
| 10:00 AM | 1 hour | **STEP 4**: Test payment flow end-to-end | Backend Engineer |
| 11:00 AM | 30 min | **STEP 5**: Commit to git & deploy | Backend Engineer |
| 11:30 AM | 30 min | **STEP 6**: GitHub cleanup (remove old secrets) | Backend Engineer |
| 12:00 PM | - | COMPLETE ✓ | - |

---

## STEP 1: GENERATE NEW CREDENTIALS AT RAZORPAY (8:00 AM - 8:30 AM)

### Location
Login to: **https://dashboard.razorpay.com**

### Generate New API Keys

1. Navigate to **Settings → API Keys** in the left sidebar
2. You'll see your current API Key ID (the public key)
3. Click **Regenerate API Key** button (top right corner)
4. Confirm the action in the popup
5. **Razorpay will generate**:
   - NEW_KEY_ID: `rzp_live_XXXXXXXXXXXXXXXX` (new public key)
   - NEW_KEY_SECRET: `XXXXXXXXXXXXXXXX` (new secret for API calls)

### Generate New Webhook Secret

1. Navigate to **Settings → Webhooks** in the left sidebar
2. Click **Add New Webhook** button
3. Fill in the webhook details:
   - **Active**: ✓ Checked
   - **URL**: `https://yourdomain.com/api/webhooks/razorpay`
     - For testing locally: Use ngrok or Razorpay's test webhook feature
     - For production: Use your actual domain
   - **Events**: Select these:
     - `payment.authorized`
     - `payment.captured`
     - `payment.failed`
     - `refund.created`
     - `refund.processed`
     - `refund.failed`
4. Click **Create Webhook**
5. **Razorpay will generate**:
   - NEW_WEBHOOK_SECRET: Displayed on the confirmation screen

### CRITICAL VALIDATION

Before proceeding, verify:
- [ ] NEW_KEY_ID starts with `rzp_live_`
- [ ] NEW_KEY_SECRET is 32+ characters
- [ ] NEW_WEBHOOK_SECRET is different from NEW_KEY_SECRET
- [ ] Both secrets copied to a secure temporary location (password manager)

**Save these three values**:
```
NEW_KEY_ID=rzp_live_XXXXX
NEW_KEY_SECRET=key_xxxxx
NEW_WEBHOOK_SECRET=webhook_xxxxx
```

---

## STEP 2: UPDATE ENVIRONMENT FILES (8:30 AM - 9:00 AM)

### File 1: `backend/.env.example` (Placeholder for developers)

**Location**: `C:\Projects\fufaji-online-business\backend\.env.example`

Update the Razorpay section with comments explaining the difference:

```env
# ── Razorpay (Payments) ──────────────────────────────────────────
# IMPORTANT: These are THREE DIFFERENT credentials:
# 
# 1. KEY_ID: Public identifier for Razorpay orders
#    Format: rzp_live_XXXXX or rzp_test_XXXXX
#    Safe to commit to git
#
# 2. KEY_SECRET: Private secret for server-to-server API calls
#    Used for: Order creation, refunds, payment queries
#    DO NOT commit to git - stored in .env or environment
#
# 3. WEBHOOK_SECRET: Private secret for webhook signature verification
#    Used for: Validating incoming webhooks from Razorpay
#    MUST be different from KEY_SECRET
#    DO NOT commit to git - stored in .env or environment
#
# CRITICAL: key_secret ≠ webhook_secret
# Using the same value is a security vulnerability

RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxxx
RAZORPAY_KEY_SECRET=<ask your backend lead for current secret>
RAZORPAY_WEBHOOK_SECRET=<ask your backend lead for current webhook secret>
```

### File 2: `.env.development` (Local development)

**Location**: `C:\Projects\fufaji-online-business\.env.development`

For local development, use Razorpay TEST credentials:

```env
# Development Environment
API_BASE_URL=http://localhost:8000
RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxxxxxx
RAZORPAY_KEY_SECRET=test_key_secret_xxxxxxxxxxxxx
RAZORPAY_WEBHOOK_SECRET=test_webhook_secret_xxxxxxxxxxxxx
SENTRY_DSN=
GOOGLE_MAPS_KEY=
STRIPE_PUBLISHABLE_KEY=
APK_DOWNLOAD_URL=https://github.com/your-user/fufaji-online-business/releases/download
SUPPORT_WHATSAPP_NUMBER=+91XXXXXXXXXX
```

### File 3: `.env.production` (Production deployment)

**Location**: `C:\Projects\fufaji-online-business\.env.production`

Use the NEW live credentials you generated:

```env
# Production Environment
API_BASE_URL=https://api.fufaji.com
RAZORPAY_KEY_ID=rzp_live_XXXXX
RAZORPAY_KEY_SECRET=key_xxxxx
RAZORPAY_WEBHOOK_SECRET=webhook_xxxxx
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id
GOOGLE_MAPS_KEY=your_production_maps_key
STRIPE_PUBLISHABLE_KEY=pk_live_your_publishable_key
APK_DOWNLOAD_URL=https://github.com/your-user/fufaji-online-business/releases/download
SUPPORT_WHATSAPP_NUMBER=+91XXXXXXXXXX
```

### File 4: `backend/.env.example` (Backend-specific)

**Location**: `C:\Projects\fufaji-online-business\backend\.env.example`

```env
# ── Fufaji Backend Environment Variables ──────────────────────
# Copy this to .env for local development.
# For Railway, set these in the Dashboard.

# ── API Config ───────────────────────────────────────────────
PORT=8080
NODE_ENV=development

# ── Firebase (Secret Manager) ────────────────────────────────
# Paste your full service-account JSON here (minify it first)
FIREBASE_SERVICE_ACCOUNT={"type":"service_account","project_id":"fufaji-store",...}

# ── Razorpay (Payments) ──────────────────────────────────────
# Three separate credentials - see above for details
RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxxx
RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxxxx
RAZORPAY_WEBHOOK_SECRET=xxxxxxxxxxxxxxxx

# ── WhatsApp Business API ────────────────────────────────────
WHATSAPP_TOKEN=xxxxxxxxxxxxxxxx
WHATSAPP_PHONE_ID=xxxxxxxxxxxxxxxx

# ── Twilio (SMS) ─────────────────────────────────────────────
TWILIO_ACCOUNT_SID=xxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxxxx
TWILIO_PHONE_NUMBER=+1xxxxxxxxxx

# ── Gemini / AI ──────────────────────────────────────────────
GEMINI_API_KEY=xxxxxxxxxxxxxxxx

# ── AWS (S3 Backup / Legacy) ─────────────────────────────────
AWS_REGION=ap-south-1
AWS_ACCESS_KEY_ID=xxxxxxxxxxxxxxxx
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxx
SSM_PREFIX=/fufaji/
USE_SSM=false
```

---

## STEP 3: VERIFY RAZORPAYSERVICE CODE (9:00 AM - 10:00 AM)

### Current Implementation Review

**File**: `C:\Projects\fufaji-online-business\backend\src\services\RazorpayService.js`

The current implementation is ALREADY CORRECT. Verify these critical sections:

### Section A: Constructor validation (lines 38-65)
```javascript
async initialize() {
  if (this.initialized) return;

  try {
    await secrets.loadSecrets();
    this.keyId = secrets.get('razorpay/key_id');
    this.keySecret = secrets.get('razorpay/key_secret');
    this.webhookSecret = secrets.get('razorpay/webhook_secret');

    if (!this.keyId || !this.keySecret || !this.webhookSecret) {
      throw new Error('Missing Razorpay credentials in SSM Parameter Store');
    }

    // CRITICAL VALIDATION
    if (this.keySecret === this.webhookSecret) {
      throw new Error(
        'CRITICAL SECURITY ERROR: webhook_secret MUST be different from key_secret. ' +
        'These are two distinct credentials with different purposes.'
      );
    }

    this.initialized = true;
    console.log('[RazorpayService] Initialized with KeyID: ' + this.keyId.substring(0, 10) + '...');
  } catch (error) {
    console.error('[RazorpayService] Initialization failed:', error.message);
    throw error;
  }
}
```

✓ **Validates**: key_secret ≠ webhook_secret
✓ **Handles**: Missing credentials
✓ **Logs**: Initialization status

### Section B: Signature verification (lines 124-156)
```javascript
verifySignature(razorpayOrderId, razorpayPaymentId, razorpaySignature) {
  if (!this.initialized) {
    throw new Error('RazorpayService not initialized');
  }

  try {
    // CRITICAL: Use webhookSecret here, NOT keySecret
    const secret = this.webhookSecret;

    const data = `${razorpayOrderId}|${razorpayPaymentId}`;
    const expectedSignature = crypto
      .createHmac('sha256', secret)
      .update(data)
      .digest('hex');

    if (expectedSignature !== razorpaySignature) {
      console.error('[RazorpayService] Signature verification FAILED...');
      return false;
    }

    console.log(`[RazorpayService] Signature verified: ${razorpayPaymentId}`);
    return true;
  } catch (error) {
    console.error('[RazorpayService] Signature verification error:', error.message);
    return false;
  }
}
```

✓ **Uses**: webhook_secret (not key_secret)
✓ **Error handling**: Logs signature mismatch
✓ **Timing-safe**: Uses simple string comparison (acceptable for this use case)

### Section C: Webhook signature verification (lines 286-314)
```javascript
verifyWebhookSignature(rawBody, signature) {
  if (!this.initialized) {
    throw new Error('RazorpayService not initialized');
  }

  try {
    const secret = this.webhookSecret;
    const buffer = Buffer.isBuffer(rawBody) ? rawBody : Buffer.from(JSON.stringify(rawBody || {}));

    const expectedSignature = crypto
      .createHmac('sha256', secret)
      .update(buffer)
      .digest('hex');

    if (expectedSignature !== signature) {
      console.error('[RazorpayService] Webhook signature verification FAILED...');
      return false;
    }

    return true;
  } catch (error) {
    console.error('[RazorpayService] Webhook signature verification error:', error.message);
    return false;
  }
}
```

✓ **Uses**: webhook_secret (not key_secret)
✓ **Handles**: Buffer or JSON input
✓ **Error handling**: Catches exceptions

### Verification Checklist
- [ ] Constructor validates key_secret ≠ webhook_secret
- [ ] Constructor throws error if secrets are the same
- [ ] verifySignature() uses webhook_secret
- [ ] verifyWebhookSignature() uses webhook_secret
- [ ] Order creation and refunds use key_secret (lines 73-112, 233-277)

---

## STEP 4: TEST PAYMENT FLOW (10:00 AM - 11:00 AM)

### Test 1: Initialize RazorpayService with new credentials

**Command**: Start your backend server with new `.env.production` file

```bash
cd backend
# Make sure .env.production is loaded
NODE_ENV=production node src/index.js
```

**Expected Output**:
```
[RazorpayService] Initialized with KeyID: rzp_live_X...
```

**Failure Signs**:
- `Missing Razorpay credentials` → Check environment variables
- `webhook_secret MUST be different from key_secret` → Check new credentials were generated separately

### Test 2: Create a test order

**HTTP Request**:
```bash
curl -X POST http://localhost:8080/api/orders/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your_token>" \
  -d '{
    "customerId": "test-customer-123",
    "items": [
      {
        "productId": "prod-001",
        "quantity": 2,
        "price": 250
      }
    ],
    "deliveryAddress": {
      "street": "123 Main St",
      "city": "Bangalore",
      "state": "Karnataka",
      "zipCode": "560001"
    }
  }'
```

**Expected Response**:
```json
{
  "orderId": "order_123456",
  "razorpayOrderId": "order_XXXXXXXXXX",
  "amount": 500,
  "currency": "INR",
  "status": "pending"
}
```

**Backend Logs**:
```
[RazorpayService] Order created: order_XXXXXXXXXX for ₹500
```

### Test 3: Simulate payment with Razorpay test card

**Razorpay Test Environment**:
1. Use the orderId from Test 2
2. In Razorpay checkout, use test card:
   - **Card**: 4111111111111111
   - **CVV**: Any 3 digits
   - **Expiry**: Any future date
   - **Name**: Test User

3. After payment, Razorpay redirects with:
   - `razorpay_payment_id`
   - `razorpay_order_id`
   - `razorpay_signature`

### Test 4: Verify payment signature

**HTTP Request**:
```bash
curl -X POST http://localhost:8080/api/orders/verify-payment \
  -H "Content-Type: application/json" \
  -d '{
    "razorpayOrderId": "order_XXXXXXXXXX",
    "razorpayPaymentId": "pay_XXXXXXXXXX",
    "razorpaySignature": "XXXXXXXXXXXXX"
  }'
```

**Expected Response**:
```json
{
  "success": true,
  "message": "Payment verified successfully",
  "paymentId": "pay_XXXXXXXXXX",
  "status": "captured"
}
```

**Backend Logs**:
```
[RazorpayService] Signature verified: pay_XXXXXXXXXX
```

**Failure Signs**:
- `Signature verification FAILED` → Webhook_secret is incorrect

### Test 5: Process refund

**HTTP Request**:
```bash
curl -X POST http://localhost:8080/api/orders/order_XXXXXXXXXX/refund \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your_token>" \
  -d '{
    "amount": 500,
    "reason": "Customer requested"
  }'
```

**Expected Response**:
```json
{
  "refundId": "rfnd_XXXXXXXXXX",
  "paymentId": "pay_XXXXXXXXXX",
  "amount": 500,
  "status": "processed"
}
```

**Backend Logs**:
```
[RazorpayService] Refund processed: rfnd_XXXXXXXXXX for ₹500
```

### Test 6: Webhook signature verification

**Simulate Razorpay webhook**:

1. Get the raw body and signature from Razorpay webhook delivery
2. In your webhook endpoint, verify:

```javascript
// In your webhook handler (typically at /api/webhooks/razorpay)
const razorpayService = require('./services/RazorpayService');

router.post('/webhooks/razorpay', async (req, res) => {
  const signature = req.headers['x-razorpay-signature'];
  const rawBody = req.rawBody; // Raw request body as buffer

  const isValid = razorpayService.verifyWebhookSignature(rawBody, signature);

  if (!isValid) {
    return res.status(401).json({ error: 'Invalid webhook signature' });
  }

  // Process webhook...
  res.json({ success: true });
});
```

**Test Command**:
```bash
curl -X POST http://localhost:8080/api/webhooks/razorpay \
  -H "Content-Type: application/json" \
  -H "X-Razorpay-Signature: <signature_from_razorpay>" \
  -d '<raw_body_from_razorpay>'
```

**Expected Output**: 200 OK with valid signature

### Success Criteria Checklist
- [ ] RazorpayService initializes without errors
- [ ] Order creation returns 200 OK with razorpayOrderId
- [ ] Payment verification returns 200 OK with status='captured'
- [ ] Signature verification passes
- [ ] Refund processing returns 200 OK with refundId
- [ ] Webhook signature verification accepts valid signatures
- [ ] All logs show correct secrets are being used

---

## STEP 5: COMMIT TO GIT & DEPLOY (11:00 AM - 11:30 AM)

### Stage changes
```bash
cd C:\Projects\fufaji-online-business

# Add only environment templates (NOT actual .env files)
git add backend/.env.example
git add .env.example

# Verify no real secrets are being added
git diff --cached | grep -E "rzp_live_|key_|secret"
# Output should be empty

# Commit
git commit -m "Security: Update Razorpay environment documentation with new credential format

- Updated .env.example files with NEW credential format
- Added documentation explaining key_id, key_secret, and webhook_secret
- Added warning about credential separation requirement
- RazorpayService already validates credential separation at init

This commit contains NO real secrets, only templates for developers.
Real credentials are in .env (git-ignored) or Railway dashboard."
```

### Deploy to production

**For Railway deployment**:

1. Go to **Railway Dashboard** → Your Fufaji project
2. Navigate to **Variables** tab
3. Update these variables:
   - `RAZORPAY_KEY_ID`: Set to NEW_KEY_ID
   - `RAZORPAY_KEY_SECRET`: Set to NEW_KEY_SECRET
   - `RAZORPAY_WEBHOOK_SECRET`: Set to NEW_WEBHOOK_SECRET
4. Click **Deploy** to trigger a rebuild

**For manual VPS deployment**:
```bash
# On your VPS
cd /opt/fufaji-backend
git pull origin main

# Update environment variables
nano .env.production

# Restart backend
pm2 restart fufaji-backend
```

### Verify deployment

```bash
# Check logs on Railway
# Should see: [RazorpayService] Initialized with KeyID: rzp_live_X...

# Or on VPS
pm2 logs fufaji-backend | grep RazorpayService
```

---

## STEP 6: GITHUB CLEANUP (11:30 AM - 12:00 PM)

### Identify leaked secrets

Search GitHub for any old leaked Razorpay credentials:

```bash
cd C:\Projects\fufaji-online-business

# Search for old credentials in git history
git log -p --all -S "rzp_live_" | head -100
git log -p --all -S "RAZORPAY_KEY_SECRET" | head -100
```

### Remove from git history

If found, use BFG Repo-Cleaner (safer than git filter-branch):

**Option 1: Using git filter-branch** (if limited commits)
```bash
# Create a file listing patterns to remove
cat > redact.txt << 'EOF'
rzp_live_.*
key_.*secret.*
RAZORPAY_KEY_SECRET=.*
RAZORPAY_WEBHOOK_SECRET=.*
EOF

# Run filter
git filter-branch --tree-filter 'sed -i "/$(cat redact.txt)/d" .env* *.md' HEAD~10..HEAD
git push origin main --force-with-lease
```

**Option 2: Using BFG Repo-Cleaner** (recommended)
```bash
# Download BFG from https://rtyley.github.io/bfg-repo-cleaner/
java -jar bfg.jar --replace-text redact.txt C:\Projects\fufaji-online-business

git reflog expire --expire=now --all && git gc --prune=now
git push origin main --force-with-lease
```

### Verify cleanup

```bash
# Search for any remaining secrets
git log --all -p | grep -i "key_secret\|webhook_secret"

# Should return empty
```

### Update GitHub security

1. **Go to GitHub** → Your repo → **Settings**
2. Navigate to **Secrets and variables** → **Actions**
3. Check for any hardcoded Razorpay secrets in CI/CD config
4. If found, replace with new values from Railway/environment

### Final verification

```bash
# Commit the .env.example updates
git add backend/.env.example .env.example
git commit -m "docs: Final Razorpay environment template after secret rotation"
git push origin main

# Verify no secrets in recent commits
git log --oneline -5
# All commits should be safe to public view
```

---

## POST-ROTATION CHECKLIST

### Immediate Actions (Today)
- [ ] New Razorpay credentials generated
- [ ] Environment files updated with NEW credentials
- [ ] RazorpayService code verified (already correct)
- [ ] All payment flow tests passed
- [ ] Code committed to git
- [ ] Production deployed
- [ ] GitHub cleaned of old secrets

### Monitoring (Next 24 hours)
- [ ] Production logs show RazorpayService initialized correctly
- [ ] No signature verification failures in logs
- [ ] Test payments work end-to-end
- [ ] Refunds process successfully
- [ ] Webhooks are received and verified

### Follow-up Tasks (Next week)
- [ ] Update any documentation about Razorpay setup
- [ ] Train team on credential management
- [ ] Set up alerts for signature verification failures
- [ ] Create backup credentials for disaster recovery
- [ ] Schedule next rotation (quarterly or as needed)

---

## TROUBLESHOOTING

### Issue: "Missing Razorpay credentials"
**Solution**: Check that environment variables are loaded:
```bash
# Verify variables are set
echo $RAZORPAY_KEY_ID
echo $RAZORPAY_KEY_SECRET
echo $RAZORPAY_WEBHOOK_SECRET
```

### Issue: "webhook_secret MUST be different from key_secret"
**Solution**: Regenerate credentials at Razorpay Dashboard. New webhook must have different secret.

### Issue: "Signature verification FAILED"
**Solution**: 
1. Check webhook_secret value is correct
2. Verify signature was calculated with correct formula: HMAC-SHA256(order_id|payment_id, webhook_secret)
3. Check for whitespace or encoding issues in secret value

### Issue: Webhook not received
**Solution**:
1. In Razorpay Dashboard, check webhook URL is accessible (not localhost)
2. Check webhook events are selected
3. Verify firewall/security rules allow Razorpay IP ranges

---

## SUCCESS INDICATORS

✓ **RazorpayService initializes** without credential mismatch errors

✓ **Test payment** creates order, processes payment, verifies signature

✓ **Refund processing** succeeds with new key_secret

✓ **Webhook verification** succeeds with new webhook_secret

✓ **Logs show** correct secrets are being used:
```
[RazorpayService] Initialized with KeyID: rzp_live_XXXXX...
[RazorpayService] Order created: order_XXXXXXXXXX for ₹500
[RazorpayService] Signature verified: pay_XXXXXXXXXX
[RazorpayService] Refund processed: rfnd_XXXXXXXXXX
```

✓ **GitHub history** contains no leaked credentials

---

## APPENDIX: SECRET CREDENTIAL FORMATS

### Razorpay Key ID
- **Format**: `rzp_live_XXXXXXXXXXXXXXXX` (production) or `rzp_test_XXXXXXXXXXXXXXXX` (testing)
- **Length**: ~15 characters
- **Safe to commit**: YES (it's a public identifier)

### Razorpay Key Secret
- **Format**: Alphanumeric, 32+ characters
- **Example**: `key_live_abc123def456ghi789jkl012`
- **Safe to commit**: NO (used for API authentication)
- **Used for**: Order creation, refunds, payment queries

### Razorpay Webhook Secret
- **Format**: Alphanumeric, 32+ characters
- **Example**: `webhook_live_xyz789qrs456tuv123abc`
- **Safe to commit**: NO (used for webhook signature verification)
- **Used for**: Verifying incoming webhooks from Razorpay
- **CRITICAL**: Must be DIFFERENT from key_secret

---

## DOCUMENT HISTORY

- **June 24, 2026**: Initial creation for key rotation execution
- **Status**: Ready for execution

---

**Next Steps**: Start STEP 1 at 8:00 AM with Razorpay Dashboard login.
