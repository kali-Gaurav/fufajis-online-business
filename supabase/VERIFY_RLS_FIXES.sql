-- ============================================================================
-- VERIFICATION SCRIPT FOR RLS SECURITY FIXES
-- Run this in Supabase SQL Editor to verify all fixes are applied
-- ============================================================================

-- ============================================================================
-- 1. VERIFY SECURITY DEFINER FUNCTION FIXED
-- ============================================================================
SELECT
  p.proname as "Function",
  case when p.prosecdef = true then 'SECURITY DEFINER' else 'SECURITY INVOKER' end as "Security"
FROM pg_proc p
WHERE p.proname = 'notify_firestore_sync';

-- Expected: 1 row with "SECURITY INVOKER"

-- ============================================================================
-- 2. VERIFY ALL TABLES HAVE RLS ENABLED
-- ============================================================================
SELECT
  schemaname,
  tablename,
  case when rowsecurity = true then 'ENABLED ✅' else 'DISABLED ❌' end as "RLS Status"
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'catalog_brands', 'catalog_categories', 'catalog_products', 'catalog_variants',
    'shop_inventory', 'product_search_index', 'product_pricing_history', 'product_aliases',
    'products', 'payment_transactions', 'order_otp_logs', 'outbox_events', 'order_audit_logs',
    'delivery_logs', 'cash_collection_logs', 'command_audit_log', 'supplier_audit_log',
    'wallet_transactions', 'webhook_logs', 'webhook_idempotency_log', 'idempotency_log',
    'voice_search_index', 'voice_order_matches', 'revenue_summary', 'delivery_routes',
    'delivery_location_history', 'storage_references', 'wallet_balance'
  )
ORDER BY tablename;

-- Expected: All rows should show "ENABLED ✅"

-- ============================================================================
-- 3. COUNT RLS POLICIES PER TABLE
-- ============================================================================
SELECT
  t.tablename,
  COUNT(p.policyname) as "Policy Count"
FROM pg_tables t
LEFT JOIN pg_policies p ON t.tablename = p.tablename AND t.schemaname = p.schemaname
WHERE t.schemaname = 'public'
  AND t.tablename IN (
    'catalog_brands', 'catalog_categories', 'catalog_products', 'catalog_variants',
    'shop_inventory', 'product_search_index', 'product_pricing_history', 'product_aliases',
    'products', 'payment_transactions', 'order_otp_logs', 'outbox_events', 'order_audit_logs',
    'delivery_logs', 'cash_collection_logs', 'command_audit_log', 'supplier_audit_log',
    'wallet_transactions', 'webhook_logs', 'webhook_idempotency_log', 'idempotency_log',
    'voice_search_index', 'voice_order_matches', 'revenue_summary', 'delivery_routes',
    'delivery_location_history', 'storage_references', 'wallet_balance'
  )
GROUP BY t.tablename
ORDER BY "Policy Count" DESC, tablename;

-- Expected: Each table should have at least 1 policy

-- ============================================================================
-- 4. LIST ALL RLS POLICIES (detailed view)
-- ============================================================================
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  qual as "USING Condition",
  with_check as "WITH CHECK Condition"
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- This shows all RLS policies currently defined

-- ============================================================================
-- 5. VERIFY SENSITIVE TABLES ARE RESTRICTED
-- ============================================================================
-- These should have policies that block or restrict access:
SELECT
  t.tablename,
  COUNT(p.policyname) as policies,
  string_agg(p.policyname, ', ') as policy_names
FROM pg_tables t
LEFT JOIN pg_policies p ON t.tablename = p.tablename AND t.schemaname = p.schemaname
WHERE t.schemaname = 'public'
  AND t.tablename IN ('command_audit_log', 'webhook_logs', 'webhook_idempotency_log',
                      'idempotency_log', 'outbox_events')
GROUP BY t.tablename;

-- Expected: All should have restrictive policies (e.g., "Block authenticated access")

-- ============================================================================
-- 6. VERIFY PUBLIC READ TABLES ARE OPEN
-- ============================================================================
-- These should allow public (anon role) read access:
SELECT
  t.tablename,
  COUNT(p.policyname) as policies
FROM pg_tables t
LEFT JOIN pg_policies p ON t.tablename = p.tablename AND t.schemaname = p.schemaname
WHERE t.schemaname = 'public'
  AND t.tablename IN ('catalog_brands', 'catalog_categories', 'catalog_products',
                      'product_search_index', 'voice_search_index')
GROUP BY t.tablename;

-- Expected: All should have at least one policy for public read

-- ============================================================================
-- 7. VERIFY OWNER-SCOPED POLICIES
-- ============================================================================
-- These should reference auth.uid() for shop owner verification:
SELECT
  tablename,
  policyname,
  qual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('shop_inventory', 'revenue_summary')
ORDER BY tablename, policyname;

-- Expected: Policies should contain "owner_id = auth.uid()" or similar

-- ============================================================================
-- 8. TEST: ANONYMOUS USER CAN READ PUBLIC CATALOGS
-- ============================================================================
-- Run this as anonymous (use Supabase client with anonKey):
-- SELECT COUNT(*) FROM catalog_brands WHERE is_active = true;
-- Expected: Should return count without error

-- ============================================================================
-- 9. TEST: AUTHENTICATED USER CANNOT READ OTHER USERS' DATA
-- ============================================================================
-- Create two test users, log in as User A:
-- SELECT * FROM wallet_balance WHERE user_id != auth.uid();
-- Expected: Should return 0 rows (RLS blocks access)

-- ============================================================================
-- 10. VERIFY NO SPATIAL_REF_SYS RLS (system table)
-- ============================================================================
SELECT
  tablename,
  rowsecurity
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'spatial_ref_sys';

-- Expected: This system table should NOT have RLS (rowsecurity = false)
-- Note: spatial_ref_sys is auto-managed by PostGIS extension

-- ============================================================================
-- SUMMARY QUERY
-- ============================================================================
WITH table_stats AS (
  SELECT
    t.tablename,
    t.rowsecurity,
    COUNT(p.policyname) as policy_count
  FROM pg_tables t
  LEFT JOIN pg_policies p ON t.tablename = p.tablename AND t.schemaname = p.schemaname
  WHERE t.schemaname = 'public'
  GROUP BY t.tablename, t.rowsecurity
)
SELECT
  'Tables with RLS Enabled' as Category,
  COUNT(*) as Count
FROM table_stats
WHERE rowsecurity = true
UNION ALL
SELECT
  'Tables without RLS',
  COUNT(*)
FROM table_stats
WHERE rowsecurity = false
UNION ALL
SELECT
  'Total RLS Policies',
  SUM(policy_count)
FROM table_stats
WHERE rowsecurity = true;

-- ============================================================================
-- END OF VERIFICATION SCRIPT
-- ============================================================================
