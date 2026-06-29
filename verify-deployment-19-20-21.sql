-- ============================================================================
-- VERIFICATION QUERIES FOR TASKS #19, #20, #21
-- ============================================================================
-- Run these queries in Supabase SQL Editor to verify deployment
-- Copy and paste each query section to check each task

-- ============================================================================
-- TASK #19: Firebase Bridge Verification
-- ============================================================================
-- This task creates a shared Edge Function, so verification is done via logs
-- See Supabase Console → Edge Functions → _shared/firebase-bridge → Logs

-- Expected: "Firebase Admin SDK initialized successfully"
-- Status: ✅ Deployed if function is visible and no initialization errors in logs

-- ============================================================================
-- TASK #20: Storage Buckets Verification
-- ============================================================================

-- Query 1: Check if all 4 buckets were created
SELECT
  id,
  name,
  public,
  file_size_limit,
  created_at
FROM storage.buckets
WHERE id IN ('product-images', 'customer-documents', 'order-receipts', 'delivery-proofs')
ORDER BY created_at;

-- Expected output (4 rows):
-- id                 | name                | public | file_size_limit | created_at
-- product-images     | product-images      | true   | 52428800        | 2026-06-28 ...
-- customer-documents | customer-documents  | false  | 10485760        | 2026-06-28 ...
-- order-receipts     | order-receipts      | false  | 5242880         | 2026-06-28 ...
-- delivery-proofs    | delivery-proofs     | false  | 10485760        | 2026-06-28 ...

-- ============================================================================

-- Query 2: Check storage policies (RLS rules)
SELECT
  id,
  name,
  bucket_id,
  definition,
  check,
  CASE WHEN check = '(bucket_id = ''product-images''::text)' THEN 'PUBLIC READ'
       WHEN check LIKE '%auth.uid()%' THEN 'AUTH REQUIRED'
       ELSE 'CUSTOM RULE'
  END as policy_type
FROM storage.policies
WHERE bucket_id IN ('product-images', 'customer-documents', 'order-receipts', 'delivery-proofs')
ORDER BY bucket_id, name;

-- Expected output (6 policies):
-- 1. Public can read product images (bucket_id = 'product-images')
-- 2. Shop owners upload product images (auth.uid required + folder check)
-- 3. Customers upload own KYC documents (auth.uid required + folder check)
-- 4. Customers read own KYC documents (auth.uid required + folder check)
-- 5. Customers read own receipts (auth.uid required + folder check)
-- 6. Riders upload delivery proofs (auth.uid required + folder check)

-- ============================================================================

-- Query 3: Check storage_references table exists
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'storage_references'
ORDER BY ordinal_position;

-- Expected output (10 columns):
-- id, storage_bucket, storage_path, storage_url, public_url, signed_url,
-- signed_url_expires_at, entity_type, entity_id, file_size, mime_type,
-- created_at, expires_at

-- ============================================================================

-- Query 4: Check indexes on storage_references
SELECT
  indexname,
  tablename,
  indexdef
FROM pg_indexes
WHERE tablename = 'storage_references'
ORDER BY indexname;

-- Expected output (3 indexes):
-- idx_storage_references_entity
-- idx_storage_references_bucket
-- idx_storage_references_created

-- ============================================================================

-- Query 5: Check helper functions exist
SELECT
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_type = 'FUNCTION'
AND routine_name LIKE '%storage%'
ORDER BY routine_name;

-- Expected output (3 functions):
-- get_storage_signed_url | FUNCTION
-- cache_storage_reference | FUNCTION
-- cleanup_expired_storage_references | FUNCTION

-- ============================================================================

-- Query 6: Check materialized view exists
SELECT
  matviewname,
  schemaname
FROM pg_matviews
WHERE matviewname = 'storage_usage_by_bucket';

-- Expected output (1 row):
-- matviewname | schemaname
-- storage_usage_by_bucket | public

-- ============================================================================

-- Query 7: Check storage_usage_by_bucket view content (should be empty initially)
SELECT
  storage_bucket,
  file_count,
  total_size_bytes,
  total_size_mb,
  latest_upload
FROM storage_usage_by_bucket
ORDER BY storage_bucket;

-- Expected output (0-4 rows, empty initially):
-- Empty if no files uploaded yet
-- After uploads, will show:
-- storage_bucket | file_count | total_size_bytes | total_size_mb | latest_upload
-- product-images | N          | XXXX             | X.XX          | 2026-06-28 ...

-- ============================================================================
-- TASK #21: Razorpay Webhook Verification
-- ============================================================================

-- Query 1: Check if payment_transactions table exists
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'payment_transactions'
ORDER BY ordinal_position;

-- Expected output (columns should include):
-- id, order_id, customer_id, razorpay_payment_id, razorpay_order_id,
-- amount, currency, method, status, webhook_received_at, created_at, updated_at

-- ============================================================================

-- Query 2: Check payment transactions after test payment (run AFTER test payment)
SELECT
  id,
  order_id,
  customer_id,
  razorpay_payment_id,
  amount,
  currency,
  method,
  status,
  webhook_received_at,
  created_at
FROM payment_transactions
WHERE status IN ('authorized', 'failed', 'completed')
ORDER BY created_at DESC
LIMIT 10;

-- Expected output (after test payment):
-- id | order_id | customer_id | razorpay_payment_id | amount | currency | method | status | webhook_received_at | created_at
-- [uuid] | [order-id] | [cust-id] | pay_test_123 | 1000.00 | INR | card | authorized | 2026-06-28 ... | 2026-06-28 ...

-- ============================================================================

-- Query 3: Check order status was updated after payment
SELECT
  id,
  status,
  payment_status,
  razorpay_payment_id,
  updated_at
FROM orders
WHERE razorpay_payment_id IS NOT NULL
ORDER BY updated_at DESC
LIMIT 10;

-- Expected output (after test payment):
-- id | status | payment_status | razorpay_payment_id | updated_at
-- [order-id] | confirmed | completed | pay_test_123 | 2026-06-28 ...

-- ============================================================================

-- Query 4: Check if deduction happened for test order
SELECT
  i.id,
  i.product_id,
  i.quantity_available,
  i.quantity_reserved,
  i.quantity_sold,
  i.updated_at
FROM inventory i
WHERE i.id IN (
  SELECT DISTINCT oi.inventory_id
  FROM order_items oi
  WHERE oi.order_id IN (
    SELECT id FROM orders WHERE razorpay_payment_id IS NOT NULL
    ORDER BY updated_at DESC LIMIT 1
  )
)
ORDER BY i.updated_at DESC;

-- Expected output (after test payment):
-- quantity_sold should be > 0 for products in test order
-- id | product_id | quantity_available | quantity_reserved | quantity_sold | updated_at
-- [uuid] | [prod-id] | X | 0 | 1 | 2026-06-28 ...

-- ============================================================================
-- COMPREHENSIVE STATUS CHECK
-- ============================================================================

-- Run this final query to get overall status:
SELECT
  'Task #19: Firebase Bridge' as task,
  'Check Supabase Console → Edge Functions → _shared/firebase-bridge' as verification,
  'Deployed' as status
UNION ALL
SELECT
  'Task #20: Storage Buckets' as task,
  'Query above: Check 4 buckets + 6 policies + functions' as verification,
  CASE
    WHEN (SELECT COUNT(*) FROM storage.buckets
          WHERE id IN ('product-images', 'customer-documents', 'order-receipts', 'delivery-proofs')) = 4
    THEN 'Deployed ✅'
    ELSE 'Pending'
  END as status
UNION ALL
SELECT
  'Task #21: Razorpay Webhook' as task,
  'Query above: Check payment_transactions after test payment' as verification,
  'Deployed (verify after test payment)' as status;

-- ============================================================================
-- POST-DEPLOYMENT TESTING (Run after test payment)
-- ============================================================================

-- Test 1: Verify payment_transactions created
SELECT COUNT(*) as payment_tx_count FROM payment_transactions;

-- Test 2: Verify order status updated
SELECT COUNT(*) as confirmed_orders FROM orders WHERE status = 'confirmed';

-- Test 3: Verify dual-write (payment record exists)
SELECT COUNT(*) as recent_payments
FROM payment_transactions
WHERE created_at > now() - interval '5 minutes';

-- Test 4: Verify Firestore sync attempted (check logs)
-- In Supabase Console → Edge Functions → razorpay-webhook-dual-write → Logs
-- Should see: "Synced payment to Firestore" and "Synced order to Firestore"

-- ============================================================================
-- CLEANUP QUERIES (Only if rollback needed)
-- ============================================================================

-- WARNING: Only run these if you need to rollback!

-- To disable RLS policies:
-- ALTER POLICY "Public can read product images" ON storage.objects DISABLE;
-- ALTER POLICY "Shop owners upload product images" ON storage.objects DISABLE;
-- ... etc for all policies

-- To drop storage buckets (DESTRUCTIVE):
-- DELETE FROM storage.buckets
-- WHERE id IN ('product-images', 'customer-documents', 'order-receipts', 'delivery-proofs');

-- To drop storage_references table:
-- DROP TABLE storage_references;

-- To drop functions:
-- DROP FUNCTION IF EXISTS get_storage_signed_url(text, text, int);
-- DROP FUNCTION IF EXISTS cache_storage_reference(text, text, text, text, text, uuid, int, text);
-- DROP FUNCTION IF EXISTS cleanup_expired_storage_references();

-- To drop materialized view:
-- DROP MATERIALIZED VIEW IF EXISTS storage_usage_by_bucket;

-- ============================================================================
-- END OF VERIFICATION QUERIES
-- ============================================================================
