# RAZORPAY KEY ROTATION - QUICK REFERENCE
**Emergency playbook for June 24, 2026 rotation**

---

## CRITICAL CHECKLIST (Do NOT skip)

### Before Starting
- [ ] Old credentials backed up in secure location
- [ ] Razorpay Dashboard accessible
- [ ] Backend code synced from main branch
- [ ] Railway dashboard accessible
- [ ] Text editor ready for .env files

### After Generating New Credentials
- [ ] NEW_KEY_ID copied and verified (starts with `rzp_live_`)
- [ ] NEW_KEY_SECRET copied and verified (32+ chars, NOT same as webhook)
- [ ] NEW_WEBHOOK_SECRET copied and verified (32+ chars, different from key_secret)
- [ ] All three values different from each other ✓

### After Updating .env Files
- [ ] backend/.env.example updated
- [ ] .env.production updated
- [ ] .env.development updated
- [ ] NO real secrets committed to git
- [ ] .gitignore still has .env

### After Code Verification
- [ ] RazorpayService.initialize() validates key_secret ≠ webhook_secret
- [ ] verifySignature() uses webhookSecret
- [ ] verifyWebhookSignature() uses webhookSecret
- [ ] createOrder() uses keySecret
- [ ] refund() uses keySecret

### After Testing
- [ ] RazorpayService initializes without errors
- [ ] Order creation succeeds
- [ ] Payment signature verification succeeds
- [ ] Refund processing succeeds
- [ ] Webhook verification succeeds

### After Deployment
- [ ] Railway variables updated
- [ ] Backend redeployed
- [ ] Production logs show successful initialization
- [ ] Test payment succeeds in production
- [ ] GitHub contains only templates (no real secrets)

---

## QUICK REFERENCE: WHERE EACH SECRET IS USED

| Secret | Type | Used For | Safe to Commit |
|--------|------|----------|----------------|
| `KEY_ID` | Public | Razorpay order creation | YES |
| `KEY_SECRET` | Private | Order creation, refunds, API calls | NO |
| `WEBHOOK_SECRET` | Private | Webhook signature verification | NO |

**Critical Rule**: `KEY_SECRET ≠ WEBHOOK_SECRET`

---

## ENVIRONMENT FILES QUICK EDIT

### Copy-paste templates for each file:

### `.env.development` (Local testing)
```env
API_BASE_URL=http://localhost:8000
RAZORPAY_KEY_ID=rzp_test_[NEW_TEST_KEY_ID]
RAZORPAY_KEY_SECRET=[NEW_TEST_KEY_SECRET]
RAZORPAY_WEBHOOK_SECRET=[NEW_TEST_WEBHOOK_SECRET]
```

### `.env.production` (Live traffic)
```env
API_BASE_URL=https://api.fufaji.com
RAZORPAY_KEY_ID=rzp_live_[NEW_LIVE_KEY_ID]
RAZORPAY_KEY_SECRET=[NEW_LIVE_KEY_SECRET]
RAZORPAY_WEBHOOK_SECRET=[NEW_LIVE_WEBHOOK_SECRET]
SENTRY_DSN=[your_sentry_dsn]
GOOGLE_MAPS_KEY=[your_maps_key]
```

### `backend/.env.example` (For developers)
```env
RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxxx
RAZORPAY_KEY_SECRET=<ask backend lead>
RAZORPAY_WEBHOOK_SECRET=<ask backend lead>
```

---

## TESTING CHECKLIST

### Test 1: Backend Startup
```bash
# Expected log output:
# [RazorpayService] Initialized with KeyID: rzp_live_XXX...
```
Status: [ ] PASS [ ] FAIL

### Test 2: Order Creation
```bash
# Expected response: 200 OK with razorpayOrderId
# Expected log: [RazorpayService] Order created: order_XXXXXXXXXX
```
Status: [ ] PASS [ ] FAIL

### Test 3: Payment Verification
```bash
# Expected response: 200 OK with status='captured'
# Expected log: [RazorpayService] Signature verified: pay_XXXXXXXXXX
```
Status: [ ] PASS [ ] FAIL

### Test 4: Refund Processing
```bash
# Expected response: 200 OK with refundId
# Expected log: [RazorpayService] Refund processed: rfnd_XXXXXXXXXX
```
Status: [ ] PASS [ ] FAIL

### Test 5: Webhook Signature
```bash
# Expected: Webhook accepted with valid signature
# Expected log: No "Webhook signature verification FAILED" message
```
Status: [ ] PASS [ ] FAIL

---

## EMERGENCY ROLLBACK

If something goes wrong, you can quickly rollback to old credentials:

### Steps:
1. Go to Railway Dashboard
2. Set RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET, RAZORPAY_WEBHOOK_SECRET back to old values
3. Deploy
4. Wait for backend to restart
5. Run Test 1 to verify

**Rollback time**: ~5 minutes

---

## CREDENTIAL VALIDATION SCRIPT

Run this before deployment to validate all credentials are correct:

```bash
#!/bin/bash

# Load .env.production
source .env.production

# Validate KEY_ID format
if [[ ! $RAZORPAY_KEY_ID =~ ^rzp_live_ ]]; then
  echo "ERROR: RAZORPAY_KEY_ID doesn't start with rzp_live_"
  exit 1
fi

# Validate KEY_SECRET length
if [ ${#RAZORPAY_KEY_SECRET} -lt 20 ]; then
  echo "ERROR: RAZORPAY_KEY_SECRET too short"
  exit 1
fi

# Validate WEBHOOK_SECRET length
if [ ${#RAZORPAY_WEBHOOK_SECRET} -lt 20 ]; then
  echo "ERROR: RAZORPAY_WEBHOOK_SECRET too short"
  exit 1
fi

# Validate they are different
if [ "$RAZORPAY_KEY_SECRET" = "$RAZORPAY_WEBHOOK_SECRET" ]; then
  echo "ERROR: KEY_SECRET equals WEBHOOK_SECRET - SECURITY VIOLATION"
  exit 1
fi

echo "✓ All credentials validated"
echo "✓ KEY_ID: ${RAZORPAY_KEY_ID:0:15}..."
echo "✓ KEY_SECRET: Set (${#RAZORPAY_KEY_SECRET} chars)"
echo "✓ WEBHOOK_SECRET: Set (${#RAZORPAY_WEBHOOK_SECRET} chars)"
echo "✓ Secrets are different: YES"
```

---

## QUICK TROUBLESHOOTING

| Error | Likely Cause | Fix |
|-------|--------------|-----|
| `Missing Razorpay credentials` | Env vars not set | Check Railway variables |
| `webhook_secret MUST be different` | Key_secret = webhook_secret | Regenerate webhook |
| `Signature verification FAILED` | Wrong webhook_secret | Verify secret in .env |
| `Order creation failed` | Wrong key_secret | Verify secret in .env |
| `Cannot connect to Razorpay` | Network issue or wrong API key | Check firewall/proxy |

---

## RAZORPAY DASHBOARD QUICK LINKS

- **API Keys**: https://dashboard.razorpay.com/app/settings/keys
- **Webhooks**: https://dashboard.razorpay.com/app/settings/webhooks
- **Payments**: https://dashboard.razorpay.com/app/payments

---

## TIME TRACKER

```
8:00 AM - Start STEP 1: Razorpay Dashboard
8:30 AM - Start STEP 2: Update .env files
9:00 AM - Start STEP 3: Verify RazorpayService code
10:00 AM - Start STEP 4: Run payment flow tests
11:00 AM - Start STEP 5: Commit & Deploy
11:30 AM - Start STEP 6: GitHub cleanup
12:00 PM - COMPLETE ✓
```

---

## TEAM COMMUNICATION TEMPLATE

**Pre-rotation notification** (before 8:00 AM):
```
Team, Razorpay credential rotation happening 8:00 AM - 12:00 PM.
Expected impact: None (should be transparent).
If payment failures occur, contact @Backend immediately.
```

**Completion notification** (after 12:00 PM):
```
Razorpay credential rotation COMPLETE.
All new credentials deployed to production.
Payment processing verified working.
Old credentials have been removed from GitHub.
```

---

## DOCUMENT CHECKSUMS

Keep these for audit trail:
- [ ] OLD_KEY_ID: `[record old value]` - Removed: [ ] Yes [ ] No
- [ ] OLD_KEY_SECRET: `[record old value]` - Removed: [ ] Yes [ ] No
- [ ] OLD_WEBHOOK_SECRET: `[record old value]` - Removed: [ ] Yes [ ] No

- [ ] NEW_KEY_ID: `[record new value]` - Deployed: [ ] Yes [ ] No
- [ ] NEW_KEY_SECRET: `[record new value]` - Deployed: [ ] Yes [ ] No
- [ ] NEW_WEBHOOK_SECRET: `[record new value]` - Deployed: [ ] Yes [ ] No

---

## SUCCESS SIGNAL

**All tests pass?** → Rotation successful ✓

**One test fails?** → Verify credentials and retry (or rollback if needed)

---

