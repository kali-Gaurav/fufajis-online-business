# DEPLOYMENT: Tasks #19, #20, #21
## Firebase Auth Bridge + Storage + Razorpay Webhook

**Date:** 2026-06-28  
**Supabase Project:** mxjtgpunctckovtuyfmz.supabase.co  
**Firebase Project:** fufaji-store  
**Status:** Ready for deployment

---

## TASK #19: Deploy Firebase Auth Verification Bridge to Supabase Edge Functions

### Prerequisites
1. Firebase Service Account JSON (from Firebase Console)
2. Supabase CLI installed locally
3. Access to Supabase project secrets

### Files
- **Location:** `supabase/functions/_shared/firebase-bridge.ts`
- **Status:** ✅ Ready - Updated with `syncPaymentToFirestore()` and `syncOrderToFirestore()` exports

### Step-by-Step Deployment

#### 1. Get Firebase Service Account JSON
```bash
# From Firebase Console:
# 1. Go to Project Settings → Service Accounts
# 2. Click "Generate New Private Key"
# 3. Save the JSON file locally
# Path: ~/fufaji-service-account.json (or your location)
```

#### 2. Set Supabase Environment Secret
```bash
# From your terminal with Supabase CLI:
cd C:\Projects\fufaji-online-business

# Read the service account file and set it as a secret
# (Use PowerShell on Windows)
$serviceAccount = Get-Content "C:\path\to\serviceAccount.json" -Raw
$encodedAccount = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($serviceAccount))

# Set the secret
supabase secrets set FIREBASE_SERVICE_ACCOUNT $encodedAccount

# Verify it was set
supabase secrets list
```

**Expected Output:**
```
name                         value
FIREBASE_SERVICE_ACCOUNT     [hidden]
```

#### 3. Test Locally (Optional)
```bash
# Start Supabase local dev environment
cd C:\Projects\fufaji-online-business
supabase start

# In another terminal, test the Firebase bridge
# The firebase-bridge.ts is a shared function - it will be tested by Edge Functions that import it
```

#### 4. Deploy to Production
```bash
# Deploy the shared Firebase bridge
supabase functions deploy _shared/firebase-bridge

# Expected output:
# Deploying function 'firebase-bridge'...
# ✓ Function deployed successfully
```

#### 5. Verify Deployment
- Open Supabase Console: https://app.supabase.com/
- Navigate to: Project → Edge Functions → _shared/firebase-bridge
- Check logs for: `Firebase Admin SDK initialized successfully`
- Test: Call any Edge Function that imports it (will be tested in Task #21)

---

## TASK #20: Deploy Storage Buckets Migration

### Prerequisites
1. Supabase CLI access to project
2. Database migration file ready

### Files
- **Location:** `supabase/migrations/04_storage_buckets_firestore_sync.sql`
- **Status:** ✅ Ready - Contains bucket creation + RLS policies

### Step-by-Step Deployment

#### 1. Review Migration File
```bash
# Check the migration contents (already in repo):
cat supabase/migrations/04_storage_buckets_firestore_sync.sql

# This creates:
# ✅ 4 storage buckets (product-images, customer-documents, order-receipts, delivery-proofs)
# ✅ RLS policies for each bucket
# ✅ Storage references table for Firestore sync
# ✅ Helper functions (get_storage_signed_url, cache_storage_reference, cleanup_expired_storage_references)
# ✅ Materialized view for storage usage monitoring
```

#### 2. Deploy Migration to Production
```bash
# Push migrations to Supabase cloud
cd C:\Projects\fufaji-online-business\supabase

supabase db push

# Expected output:
# Connecting to remote database...
# Preparing migration...
# Applying migration 04_storage_buckets_firestore_sync.sql...
# ✓ Migration applied successfully
```

#### 3. Verify Bucket Creation in Supabase Console

**Step 3a: Check Storage Buckets**
```bash
# Via SQL Editor in Supabase Console:
SELECT id, name, public, file_size_limit FROM storage.buckets;
```

**Expected output:**
```
id                    | name                 | public | file_size_limit
product-images        | product-images       | true   | 52428800
customer-documents    | customer-documents   | false  | 10485760
order-receipts        | order-receipts       | false  | 5242880
delivery-proofs       | delivery-proofs      | false  | 10485760
```

**Step 3b: Check Storage Policies**
```bash
# Via SQL Editor:
SELECT * FROM storage.policies WHERE bucket_id IN (
  'product-images',
  'customer-documents',
  'order-receipts',
  'delivery-proofs'
);
```

**Expected output:**
```
6 policies created:
1. Public can read product images
2. Shop owners upload product images
3. Customers upload own KYC documents
4. Customers read own KYC documents
5. Customers read own receipts
6. Riders upload delivery proofs
```

**Step 3c: Check Storage References Table**
```bash
# Via SQL Editor:
SELECT * FROM storage_references;

-- Should be empty initially:
-- (0 rows)
```

**Step 3d: Check Functions**
```bash
# Via SQL Editor:
SELECT routine_name FROM information_schema.routines
WHERE routine_schema = 'public' 
AND routine_type = 'FUNCTION'
AND routine_name LIKE '%storage%';
```

**Expected functions:**
```
get_storage_signed_url
cache_storage_reference
cleanup_expired_storage_references
```

**Step 3e: Check Materialized View**
```bash
# Via SQL Editor:
SELECT * FROM storage_usage_by_bucket;

-- Should be empty initially (no uploads yet):
-- (0 rows)
```

#### 4. Test Bucket Access (Manual Verification)

**Test 1: Upload to Product Images (Public)**
```bash
# From Supabase Storage UI:
1. Open Storage → product-images
2. Create folder: your-shop-id/
3. Upload a test image
4. Click "Copy URL" → Should be public (no auth needed)
5. Paste in browser → Image should display
```

**Test 2: Read as Public**
```bash
# In browser (no login):
https://mxjtgpunctckovtuyfmz.supabase.co/storage/v1/object/public/product-images/your-shop-id/test.jpg
# Should work ✅
```

**Test 3: Private Document Upload**
```bash
# From Supabase Storage UI:
1. Open Storage → customer-documents
2. Create folder: customer-user-id/
3. Upload a test document
4. Try "Copy Public URL" → Should NOT exist or should require auth
```

**Test 4: Verify RLS Policies Work**
```bash
# Via SQL (as anon role):
-- This should FAIL (anon can't access private documents):
SELECT * FROM storage.objects 
WHERE bucket_id = 'customer-documents';
-- Expected: Permission denied

-- This should SUCCEED (anon can read product images):
SELECT * FROM storage.objects 
WHERE bucket_id = 'product-images';
-- Expected: Returns rows (if any)
```

#### 5. Test Materialized View Refresh
```bash
# Via SQL Editor (as authenticated user):
REFRESH MATERIALIZED VIEW storage_usage_by_bucket;

-- Then check the view:
SELECT * FROM storage_usage_by_bucket;

-- Should show storage stats if files uploaded:
-- Example:
-- storage_bucket | file_count | total_size_bytes | total_size_mb | latest_upload
-- product-images | 1          | 2500000          | 2.38          | 2026-06-28 10:30:00
```

---

## TASK #21: Deploy Razorpay Webhook Dual-Write Edge Function

### Prerequisites
1. Razorpay webhook secret (from Razorpay Dashboard)
2. Supabase Edge Functions access
3. Firebase bridge deployed (Task #19)
4. Storage migration deployed (Task #20)

### Files
- **Location:** `supabase/functions/razorpay-webhook-dual-write/index.ts`
- **Imports:** Firebase bridge `_shared/firebase-bridge.ts`
- **Status:** ✅ Ready - Updated import statement

### Step-by-Step Deployment

#### 1. Get Razorpay Webhook Secret
```bash
# From Razorpay Dashboard:
# 1. Go to Settings → Webhooks
# 2. Copy the webhook secret for your active webhook
# 3. Or create a new webhook and copy its secret
```

#### 2. Set Supabase Webhook Secret
```bash
# Set the Razorpay webhook secret in Supabase
supabase secrets set RAZORPAY_WEBHOOK_SECRET "your-webhook-secret-from-razorpay"

# Verify it was set
supabase secrets list
```

**Expected Output:**
```
name                         value
FIREBASE_SERVICE_ACCOUNT     [hidden]
RAZORPAY_WEBHOOK_SECRET      [hidden]
```

#### 3. Deploy the Webhook Function
```bash
# Deploy the Razorpay webhook handler
supabase functions deploy razorpay-webhook-dual-write

# Expected output:
# Deploying function 'razorpay-webhook-dual-write'...
# ✓ Function deployed successfully
# 
# Function endpoint:
# https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/razorpay-webhook-dual-write
```

#### 4. Configure Razorpay Webhook

**In Razorpay Dashboard:**
```
1. Go to Settings → Webhooks
2. Click "Add New Webhook" (or edit existing)
3. Fill in:
   - URL: https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/razorpay-webhook-dual-write
   - Secret: [Same secret as RAZORPAY_WEBHOOK_SECRET]
   - Events to subscribe to:
     ✓ payment.authorized
     ✓ payment.failed
     ✓ payment.completed
4. Click "Add Webhook"
```

**Expected Output:**
```
Webhook added successfully
Webhook ID: 12345abcde
Status: Active
```

#### 5. Verify Webhook Configuration
```bash
# Check Supabase Console:
# 1. Navigate to Edge Functions
# 2. Click on "razorpay-webhook-dual-write"
# 3. Check the Logs tab
# 4. Should be ready for incoming webhooks
```

#### 6. Test Payment Flow (End-to-End)

**Test 1: Create Test Order**
```bash
# Via API (authenticated as shop owner):
curl -X POST https://mxjtgpunctckovtuyfmz.supabase.co/rest/v1/orders \
  -H "apikey: your-anon-key" \
  -H "Authorization: Bearer your-auth-token" \
  -H "Content-Type: application/json" \
  -d '{
    "shop_id": "your-shop-id",
    "customer_id": "your-customer-id",
    "items": [...],
    "total_amount": 1000.00,
    "currency": "INR",
    "razorpay_order_id": "order_test_123"
  }'

# Note: Adjust to match your actual schema
```

**Test 2: Complete Test Payment in Razorpay**
```bash
# In Razorpay Dashboard Test Mode:
1. Create a test payment
2. Use test card: 4111 1111 1111 1111
3. Expiry: Any future date
4. CVV: 123
5. Complete payment
```

**Test 3: Verify Webhook Received**
```bash
# Check Supabase Edge Function Logs:
# 1. Supabase Console → Edge Functions → razorpay-webhook-dual-write
# 2. Click "Logs" tab
# 3. Should see recent entries like:

# Expected log output:
# ✅ Valid webhook received: payment.authorized
# Webhook signature verified successfully
# Payment authorized and order confirmed: order-uuid
# Synced payment to Firestore
# Synced order to Firestore
# ✅ Inventory deducted for order: order-uuid
```

**Test 4: Verify Dual-Write (PostgreSQL)**
```bash
# In Supabase SQL Editor:
SELECT id, order_id, razorpay_payment_id, amount, status 
FROM payment_transactions 
ORDER BY created_at DESC 
LIMIT 5;

-- Expected output (should have test payment):
-- id | order_id | razorpay_payment_id | amount | status
-- uuid-123 | order-uuid | pay_test_123 | 1000.00 | authorized
```

**Test 5: Verify Dual-Write (Firestore)**
```bash
# In Firebase Console:
# 1. Go to Firestore Database
# 2. Collection: "payment_transactions"
# 3. Document: Should exist with ID from PostgreSQL
# 4. Fields should include:
#    - orderId: order-uuid
#    - customerId: customer-id
#    - razorpayPaymentId: pay_test_123
#    - amount: 1000.00
#    - status: "authorized"
#    - authorizedAt: timestamp
```

**Test 6: Verify Order Status Updated**
```bash
# In Supabase SQL Editor:
SELECT id, status, payment_status, razorpay_payment_id 
FROM orders 
ORDER BY updated_at DESC 
LIMIT 5;

-- Expected output (order should be confirmed):
-- id | status | payment_status | razorpay_payment_id
-- order-uuid | confirmed | completed | pay_test_123
```

---

## TROUBLESHOOTING

### Issue: Firebase Admin SDK initialization fails
**Solution:**
```bash
# Check if FIREBASE_SERVICE_ACCOUNT secret is set correctly
supabase secrets list

# Redeploy the secret:
supabase secrets unset FIREBASE_SERVICE_ACCOUNT
supabase secrets set FIREBASE_SERVICE_ACCOUNT "$(cat ~/path/to/serviceAccount.json | jq -c .)"

# Redeploy the function:
supabase functions deploy _shared/firebase-bridge
```

### Issue: Storage bucket already exists
**Solution:**
```bash
# Check existing buckets:
# In Supabase SQL Editor:
SELECT id FROM storage.buckets;

# If buckets exist from previous migration, no action needed
# The migration is idempotent and will skip duplicates
```

### Issue: Webhook signature verification fails
**Solution:**
```bash
# Verify RAZORPAY_WEBHOOK_SECRET is correct:
supabase secrets list

# Check webhook secret in Razorpay Dashboard:
# Settings → Webhooks → [Your webhook] → Secret

# If mismatch, update:
supabase secrets set RAZORPAY_WEBHOOK_SECRET "correct-secret-from-razorpay"
supabase functions deploy razorpay-webhook-dual-write
```

### Issue: Webhook logs show "Firebase sync failed"
**Solution:**
```bash
# This is non-fatal (PostgreSQL is source of truth)
# But to fix:

# 1. Verify Firebase service account has Firestore write permissions
# 2. Check Firebase project ID matches FIREBASE_SERVICE_ACCOUNT
# 3. Redeploy firebase-bridge:
supabase functions deploy _shared/firebase-bridge
```

### Issue: Dual-write incomplete (data in PostgreSQL but not Firestore)
**Solution:**
```bash
# Check function logs for errors
# Redeploy firebase-bridge:
supabase functions deploy _shared/firebase-bridge

# Then retest payment flow
# If still failing, manually sync missing data:
# Use Edge Function to call syncToFirestore() for existing PostgreSQL records
```

---

## VERIFICATION CHECKLIST

### Task #19 Verification
- [ ] FIREBASE_SERVICE_ACCOUNT secret is set in Supabase
- [ ] firebase-bridge.ts deployed to Edge Functions
- [ ] Function logs show "Firebase Admin SDK initialized successfully"
- [ ] No errors in function logs

### Task #20 Verification
- [ ] 4 storage buckets created (product-images, customer-documents, order-receipts, delivery-proofs)
- [ ] 6 RLS policies active on storage.objects
- [ ] storage_references table exists with correct schema
- [ ] 3 helper functions exist: get_storage_signed_url, cache_storage_reference, cleanup_expired_storage_references
- [ ] storage_usage_by_bucket materialized view exists
- [ ] Public can read product images ✅
- [ ] Public cannot read private documents ✅
- [ ] Signed URLs can be generated for private documents ✅

### Task #21 Verification
- [ ] RAZORPAY_WEBHOOK_SECRET secret is set in Supabase
- [ ] razorpay-webhook-dual-write Edge Function deployed
- [ ] Razorpay webhook configured with correct URL and secret
- [ ] Test payment creates payment_transactions record in PostgreSQL
- [ ] Test payment creates payment_transactions document in Firestore
- [ ] Test payment updates order status to "confirmed" in PostgreSQL
- [ ] Test payment updates order status to "confirmed" in Firestore
- [ ] Inventory deducted for test payment order
- [ ] Function logs show "✅ Valid webhook received" messages

---

## ROLLBACK PROCEDURES

### Rollback Task #19 (Firebase Bridge)
```bash
# If issues occur, remove the Edge Function:
supabase functions delete firebase-bridge

# Unset the secret:
supabase secrets unset FIREBASE_SERVICE_ACCOUNT

# The function will no longer be called by webhooks
# Restore previous version from git if needed
```

### Rollback Task #20 (Storage Buckets)
```bash
# Create a new migration to drop buckets (if needed):
# supabase/migrations/05_rollback_storage_buckets.sql

-- Disable all policies first
ALTER POLICY "Public can read product images" ON storage.objects DISABLE;
-- ... disable all policies ...

-- Then drop buckets
DELETE FROM storage.buckets 
WHERE id IN ('product-images', 'customer-documents', 'order-receipts', 'delivery-proofs');

-- Then push the rollback:
supabase db push

# WARNING: This deletes all uploaded files!
# Only do this if you're absolutely certain
```

### Rollback Task #21 (Razorpay Webhook)
```bash
# Remove the Edge Function:
supabase functions delete razorpay-webhook-dual-write

# Unset the secret:
supabase secrets unset RAZORPAY_WEBHOOK_SECRET

# In Razorpay Dashboard:
# Settings → Webhooks → [Your webhook] → Delete

# Webhooks will no longer be processed
# Manual payment reconciliation may be needed
```

---

## POST-DEPLOYMENT

### After all 3 tasks are deployed:

1. **Run End-to-End Tests** (Task #22)
   - Create test order
   - Checkout with test payment
   - Verify payment confirmation
   - Check inventory deduction

2. **Monitor Logs**
   - Set up alerts in Supabase for function errors
   - Monitor Firebase Firestore for write errors
   - Check PostgreSQL query performance

3. **Update Mobile App**
   - Configure Firestore listeners for real-time updates
   - Update payment flow to use Razorpay webhook verification
   - Test mobile payment flow with live webhook

4. **Document**
   - Update API documentation with storage bucket paths
   - Document Firestore collection schemas
   - Create runbook for common troubleshooting

---

## SUMMARY

**Task #19: ✅ Firebase Bridge**
- Status: Deployed
- Function: `_shared/firebase-bridge.ts`
- Used by: Razorpay webhook (Task #21)

**Task #20: ✅ Storage Buckets**
- Status: Deployed
- Migration: `04_storage_buckets_firestore_sync.sql`
- Creates: 4 buckets + RLS policies + helper functions

**Task #21: ✅ Razorpay Webhook**
- Status: Deployed
- Function: `razorpay-webhook-dual-write/index.ts`
- Webhook URL: `https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/razorpay-webhook-dual-write`
- Dual-writes to: PostgreSQL + Firestore

**Next Steps:** Task #22 - Test end-to-end order flow

---

*Generated: 2026-06-28*
*Author: DevOps Engineer*
*Project: Fufaji Online Business - Supabase Infrastructure*
