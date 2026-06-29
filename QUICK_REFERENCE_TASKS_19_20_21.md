# QUICK REFERENCE: Tasks #19, #20, #21 Deployment

## One-Line Summary
Deploy Firebase auth bridge + storage buckets + Razorpay webhook to Supabase Edge Functions with dual-write (PostgreSQL + Firestore).

---

## TASK #19: Firebase Auth Bridge

### What It Does
- Verifies Firebase JWT tokens in Edge Functions
- Syncs payment & order data to Firestore
- Acts as bridge between Supabase (source of truth) and Firebase (mobile app real-time)

### Quick Deploy
```bash
# 1. Set secret (run from Windows PowerShell)
$content = Get-Content "C:\path\to\serviceAccount.json" -Raw
supabase secrets set FIREBASE_SERVICE_ACCOUNT $content

# 2. Verify
supabase secrets list

# 3. Deploy
supabase functions deploy _shared/firebase-bridge

# 4. Check logs
# Supabase Console → Edge Functions → _shared/firebase-bridge → Logs
# Should show: "Firebase Admin SDK initialized successfully"
```

### Key Files
- `supabase/functions/_shared/firebase-bridge.ts` - Shared library
- Exports: `verifyFirebaseToken()`, `syncToFirestore()`, `syncPaymentToFirestore()`, `syncOrderToFirestore()`

---

## TASK #20: Storage Buckets

### What It Does
- Creates 4 storage buckets (product images, customer documents, receipts, delivery proofs)
- Adds RLS policies for secure access
- Provides helper functions for signed URLs and reference caching
- Tracks storage usage for monitoring

### Quick Deploy
```bash
# 1. Deploy migration
cd C:\Projects\fufaji-online-business\supabase
supabase db push

# 2. Verify buckets created
# Supabase Console → SQL Editor
SELECT * FROM storage.buckets WHERE id IN ('product-images', 'customer-documents', 'order-receipts', 'delivery-proofs');

# Expected: 4 buckets

# 3. Verify policies created
SELECT * FROM storage.policies;

# Expected: 6 policies

# 4. Test public read (in browser, no auth)
https://mxjtgpunctckovtuyfmz.supabase.co/storage/v1/object/public/product-images/test.jpg
# Should work ✅
```

### Key Files
- `supabase/migrations/04_storage_buckets_firestore_sync.sql` - Migration
- Buckets: `product-images` (public), `customer-documents`, `order-receipts`, `delivery-proofs` (private)
- Functions: `get_storage_signed_url()`, `cache_storage_reference()`, `cleanup_expired_storage_references()`
- View: `storage_usage_by_bucket` (materialized)

### Bucket Details
| Bucket | Public | Size Limit | Purpose |
|--------|--------|-----------|---------|
| product-images | Yes | 50MB | Product photos (everyone reads, shop owner writes) |
| customer-documents | No | 10MB | KYC documents (customer reads/writes own) |
| order-receipts | No | 5MB | Receipts (customer reads own) |
| delivery-proofs | No | 10MB | Delivery photos (rider writes proof) |

---

## TASK #21: Razorpay Webhook

### What It Does
- Receives payment webhooks from Razorpay
- Verifies webhook signature (SHA256 HMAC)
- Writes payment transaction to PostgreSQL (source of truth)
- Syncs payment & order to Firestore (real-time mobile app)
- Deducts inventory on successful payment
- Sends push notification to customer
- Handles payment failures and retries (idempotent)

### Quick Deploy
```bash
# 1. Get secret from Razorpay
# Razorpay Dashboard → Settings → Webhooks → [Your webhook] → Secret

# 2. Set secret
supabase secrets set RAZORPAY_WEBHOOK_SECRET "your-secret-from-razorpay"

# 3. Deploy function
supabase functions deploy razorpay-webhook-dual-write

# 4. Note the function URL
# https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/razorpay-webhook-dual-write

# 5. Configure Razorpay webhook (manual)
# Razorpay Dashboard → Settings → Webhooks → Add Webhook
# URL: https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/razorpay-webhook-dual-write
# Secret: [same as RAZORPAY_WEBHOOK_SECRET]
# Events: payment.authorized, payment.failed, payment.completed

# 6. Test with sample payment
# Create test order → Pay with test card → Check logs

# 7. Verify in logs
# Supabase Console → Edge Functions → razorpay-webhook-dual-write → Logs
# Should show: "✅ Valid webhook received: payment.authorized"
```

### Key Files
- `supabase/functions/razorpay-webhook-dual-write/index.ts` - Webhook handler
- Signature algorithm: SHA256 HMAC
- Events handled: `payment.authorized`, `payment.failed`, `payment.completed`

### Webhook Flow
```
Razorpay Payment Event
         ↓
   Webhook POST
         ↓
    Verify Signature (HMAC-SHA256)
         ↓
    Create payment_transactions in PostgreSQL (source of truth)
         ↓
    Sync to Firestore (dual-write)
         ↓
    Deduct Inventory
         ↓
    Send Push Notification
         ↓
    Return 200 OK to Razorpay
```

---

## Verification Checklist

### After Task #19
- [ ] FIREBASE_SERVICE_ACCOUNT secret set
- [ ] firebase-bridge function deployed
- [ ] Logs show "Firebase Admin SDK initialized successfully"

### After Task #20
- [ ] 4 storage buckets exist
- [ ] 6 RLS policies created
- [ ] storage_references table exists
- [ ] Helper functions exist
- [ ] Public can read product images
- [ ] Public cannot read private documents

### After Task #21
- [ ] RAZORPAY_WEBHOOK_SECRET secret set
- [ ] razorpay-webhook-dual-write function deployed
- [ ] Razorpay webhook configured
- [ ] Test payment creates payment_transactions in PostgreSQL
- [ ] Test payment syncs to Firestore
- [ ] Order status updated to "confirmed"
- [ ] Inventory deducted
- [ ] Function logs show "✅ Valid webhook received"

---

## Troubleshooting

### Firebase bridge initialization fails
```bash
# Redeploy secret
supabase secrets set FIREBASE_SERVICE_ACCOUNT "$(cat ~/path/to/serviceAccount.json)"
supabase functions deploy _shared/firebase-bridge
```

### Storage bucket already exists
```bash
# No action needed - migration is idempotent
# If policy errors occur, drop and redeploy:
supabase db push --dry-run  # Check what will happen
supabase db reset           # Reset and redeploy all migrations
```

### Webhook signature verification fails
```bash
# Verify secret matches Razorpay
supabase secrets list

# Check Razorpay webhook secret
# Razorpay Dashboard → Settings → Webhooks → [Your webhook] → Secret

# Update if mismatch
supabase secrets set RAZORPAY_WEBHOOK_SECRET "correct-secret"
supabase functions deploy razorpay-webhook-dual-write
```

### Firestore sync shows as non-fatal failure (OK)
```
This is expected - PostgreSQL is source of truth
PostgreSQL write succeeded = payment is recorded
Firebase sync is async and non-blocking
Both will eventually be consistent
```

### Payment created in PostgreSQL but not Firestore
```bash
# This is OK - PostgreSQL is source of truth
# Mobile app can query PostgreSQL via API
# But for real-time updates, Firestore sync is needed

# To fix Firebase sync:
# 1. Check Firebase credentials in FIREBASE_SERVICE_ACCOUNT
# 2. Verify Firebase project permissions
# 3. Redeploy firebase-bridge
supabase functions deploy _shared/firebase-bridge

# Then retry payment flow
```

---

## Testing After Deployment

### Quick Test (2 minutes)
```bash
# 1. Create test order in PostgreSQL
INSERT INTO orders (customer_id, shop_id, total_amount, status)
VALUES ('cust-uuid', 'shop-uuid', 1000.00, 'pending');

# 2. Make test payment in Razorpay test mode
# Card: 4111 1111 1111 1111, any future expiry, CVV: 123

# 3. Check if payment_transactions was created
SELECT * FROM payment_transactions ORDER BY created_at DESC LIMIT 1;

# 4. Check if order status was updated
SELECT * FROM orders ORDER BY updated_at DESC LIMIT 1;
# status should be "confirmed"
```

### Deep Test (5 minutes)
```bash
# 1. Test storage bucket upload
# Supabase Console → Storage → product-images
# Upload test image → Copy public URL
# Paste in browser (no auth) → Should display image

# 2. Test payment webhook
# Razorpay test payment → Check logs
# Supabase Console → Edge Functions → razorpay-webhook-dual-write → Logs
# Should show success messages

# 3. Test Firestore sync
# Firebase Console → Firestore Database
# Collection "payment_transactions" → Should have payment document
# Fields: orderId, customerId, amount, status

# 4. Test inventory deduction
# Check order items and inventory
SELECT i.quantity_sold FROM inventory i WHERE i.product_id = 'prod-uuid';
# Should be > 0
```

---

## Files Created/Modified

### Created
- `DEPLOYMENT_TASKS_19_20_21.md` - Detailed deployment guide
- `QUICK_REFERENCE_TASKS_19_20_21.md` - This file
- `deploy-tasks-19-20-21.ps1` - PowerShell deployment script
- `deploy-tasks-19-20-21.sh` - Bash deployment script
- `verify-deployment-19-20-21.sql` - SQL verification queries

### Modified
- `supabase/functions/_shared/firebase-bridge.ts` - Added Firestore sync functions
- `supabase/functions/razorpay-webhook-dual-write/index.ts` - Fixed import statement

### Existing (Already Ready)
- `supabase/migrations/04_storage_buckets_firestore_sync.sql` - Storage migration
- `supabase/functions/razorpay-webhook-dual-write/index.ts` - Webhook handler

---

## Environment Variables (Secrets)

Set these in Supabase Dashboard (Settings → Secrets):

| Secret | Source | Format |
|--------|--------|--------|
| FIREBASE_SERVICE_ACCOUNT | Firebase Console → Project Settings → Service Accounts | JSON (base64 encoded) |
| RAZORPAY_WEBHOOK_SECRET | Razorpay Dashboard → Settings → Webhooks | Plain text |
| SUPABASE_URL | Already set (project default) | URL |
| SUPABASE_SECRET_KEY | Already set (project default) | JWT token |

---

## Next Steps (Task #22+)

After deployment is verified:

1. **Task #22:** Test end-to-end order flow
   - Create order → Checkout → Payment → Confirm
   
2. **Task #23:** Test delivery flow
   - Order → Packing → Assignment → Pickup → Delivery

3. **Task #24:** Implement storage bucket upload functions
   - Create Edge Functions for file uploads
   - Sync storage references to Firestore

4. **Task #25:** Update mobile app
   - Add Firestore listeners for real-time updates
   - Test payment flow with live webhooks

5. **Task #26:** Setup monitoring
   - Sentry for error tracking
   - CloudWatch for logs
   - Performance monitoring

---

## Support

### Documentation
- Full deployment guide: `DEPLOYMENT_TASKS_19_20_21.md`
- Verification queries: `verify-deployment-19-20-21.sql`
- Quick reference: This file

### Supabase Resources
- Dashboard: https://app.supabase.com/
- Project: mxjtgpunctckovtuyfmz
- Docs: https://supabase.com/docs

### Firebase Resources
- Console: https://console.firebase.google.com/
- Project: fufaji-store
- Docs: https://firebase.google.com/docs

### Razorpay Resources
- Dashboard: https://dashboard.razorpay.com/
- Webhook Docs: https://razorpay.com/docs/webhooks/

---

*Generated: 2026-06-28*
*Supabase Project: mxjtgpunctckovtuyfmz.supabase.co*
*Status: Ready for deployment*
