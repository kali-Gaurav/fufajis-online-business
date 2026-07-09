-- ============================================================================
-- Inventory Schema Verification Script
-- Run this AFTER applying migration 20260709000001
-- ============================================================================

-- Set to quiet mode for cleaner output
\set QUIET on

-- ============================================================================
-- PART 1: Verify All Columns Added
-- ============================================================================

\echo '=== COLUMN VERIFICATION ==='

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'available_stock') THEN '✓ available_stock'
    ELSE '✗ MISSING: available_stock'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'reserved_stock') THEN '✓ reserved_stock'
    ELSE '✗ MISSING: reserved_stock'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'sold_stock') THEN '✓ sold_stock'
    ELSE '✗ MISSING: sold_stock'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'branch_stock') THEN '✓ branch_stock'
    ELSE '✗ MISSING: branch_stock'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'branch_stock_map') THEN '✓ branch_stock_map'
    ELSE '✗ MISSING: branch_stock_map'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'minimum_stock') THEN '✓ minimum_stock'
    ELSE '✗ MISSING: minimum_stock'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'sku') THEN '✓ sku'
    ELSE '✗ MISSING: sku'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'last_stock_check') THEN '✓ last_stock_check'
    ELSE '✗ MISSING: last_stock_check'
  END as status;

-- ============================================================================
-- PART 2: Verify All Constraints
-- ============================================================================

\echo '=== CONSTRAINT VERIFICATION ==='

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_name = 'products' AND constraint_name LIKE '%valid_stock_allocation%') THEN '✓ valid_stock_allocation constraint'
    ELSE '✗ MISSING: valid_stock_allocation constraint'
  END as status;

-- ============================================================================
-- PART 3: Verify All Indexes
-- ============================================================================

\echo '=== INDEX VERIFICATION ==='

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'products' AND indexname = 'idx_products_shop_id') THEN '✓ idx_products_shop_id'
    ELSE '✗ MISSING: idx_products_shop_id'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'products' AND indexname = 'idx_products_low_stock') THEN '✓ idx_products_low_stock'
    ELSE '✗ MISSING: idx_products_low_stock'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'products' AND indexname = 'idx_products_sku') THEN '✓ idx_products_sku'
    ELSE '✗ MISSING: idx_products_sku'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'products' AND indexname = 'idx_products_reserved') THEN '✓ idx_products_reserved'
    ELSE '✗ MISSING: idx_products_reserved'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'products' AND indexname = 'idx_products_last_stock_check') THEN '✓ idx_products_last_stock_check'
    ELSE '✗ MISSING: idx_products_last_stock_check'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'inventory_audit_log' AND indexname = 'idx_audit_product') THEN '✓ idx_audit_product'
    ELSE '✗ MISSING: idx_audit_product'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'inventory_audit_log' AND indexname = 'idx_audit_shop') THEN '✓ idx_audit_shop'
    ELSE '✗ MISSING: idx_audit_shop'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'inventory_audit_log' AND indexname = 'idx_audit_order') THEN '✓ idx_audit_order'
    ELSE '✗ MISSING: idx_audit_order'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'inventory_audit_log' AND indexname = 'idx_audit_type') THEN '✓ idx_audit_type'
    ELSE '✗ MISSING: idx_audit_type'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'inventory_audit_log' AND indexname = 'idx_audit_created') THEN '✓ idx_audit_created'
    ELSE '✗ MISSING: idx_audit_created'
  END as status;

-- ============================================================================
-- PART 4: Verify Tables Created
-- ============================================================================

\echo '=== TABLE VERIFICATION ==='

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'inventory_audit_log') THEN '✓ inventory_audit_log table'
    ELSE '✗ MISSING: inventory_audit_log table'
  END as status;

-- ============================================================================
-- PART 5: Verify Functions Created
-- ============================================================================

\echo '=== FUNCTION VERIFICATION ==='

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'reserve_product_stock' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')) THEN '✓ reserve_product_stock()'
    ELSE '✗ MISSING: reserve_product_stock()'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'confirm_product_sale' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')) THEN '✓ confirm_product_sale()'
    ELSE '✗ MISSING: confirm_product_sale()'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'cancel_product_reservation' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')) THEN '✓ cancel_product_reservation()'
    ELSE '✗ MISSING: cancel_product_reservation()'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'verify_inventory_consistency' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')) THEN '✓ verify_inventory_consistency()'
    ELSE '✗ MISSING: verify_inventory_consistency()'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_products_updated_at' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')) THEN '✓ update_products_updated_at() trigger function'
    ELSE '✗ MISSING: update_products_updated_at() trigger function'
  END as status;

-- ============================================================================
-- PART 6: Verify Views Created
-- ============================================================================

\echo '=== VIEW VERIFICATION ==='

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'v_inventory_consistency') THEN '✓ v_inventory_consistency'
    ELSE '✗ MISSING: v_inventory_consistency'
  END as status;

-- ============================================================================
-- PART 7: Verify Triggers Created
-- ============================================================================

\echo '=== TRIGGER VERIFICATION ==='

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_products_auto_updated_at' AND tgrelid = (SELECT oid FROM pg_class WHERE relname = 'products')) THEN '✓ trg_products_auto_updated_at'
    ELSE '✗ MISSING: trg_products_auto_updated_at'
  END as status;

-- ============================================================================
-- PART 8: Verify RLS Policies
-- ============================================================================

\echo '=== RLS POLICY VERIFICATION ==='

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'inventory_audit_log_customer_select' AND tablename = 'inventory_audit_log') THEN '✓ inventory_audit_log_customer_select policy'
    ELSE '✗ MISSING: inventory_audit_log_customer_select policy'
  END as status;

SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'inventory_audit_log_owner_select' AND tablename = 'inventory_audit_log') THEN '✓ inventory_audit_log_owner_select policy'
    ELSE '✗ MISSING: inventory_audit_log_owner_select policy'
  END as status;

-- ============================================================================
-- PART 9: Data Consistency Check
-- ============================================================================

\echo '=== DATA CONSISTENCY CHECK ==='

-- Check for any rows with negative stock values (should never happen)
SELECT
  COUNT(*) as products_with_negative_stock
FROM products
WHERE available_stock < 0 OR reserved_stock < 0 OR sold_stock < 0;

-- Check for constraint violations
SELECT
  COUNT(*) as constraint_violations
FROM products
WHERE (available_stock + reserved_stock + sold_stock) < 0;

-- ============================================================================
-- PART 10: Sample Data Verification
-- ============================================================================

\echo '=== SAMPLE DATA VERIFICATION ==='

-- Show first few products with inventory data
\echo 'Sample products with inventory data:'
SELECT
  id,
  name,
  sku,
  available_stock,
  reserved_stock,
  sold_stock,
  (available_stock + reserved_stock + sold_stock) as total,
  minimum_stock,
  last_stock_check,
  updated_at
FROM products
WHERE is_active = true
LIMIT 5;

-- Show audit log entries if any
\echo 'Sample audit log entries (if any):'
SELECT
  id,
  product_id,
  mutation_type,
  quantity_change,
  triggered_by,
  created_at
FROM inventory_audit_log
ORDER BY created_at DESC
LIMIT 5;

-- ============================================================================
-- PART 11: Schema Statistics
-- ============================================================================

\echo '=== SCHEMA STATISTICS ==='

\echo 'Products table size:'
SELECT pg_size_pretty(pg_total_relation_size('products')) as size;

\echo 'Inventory audit log size:'
SELECT pg_size_pretty(pg_total_relation_size('inventory_audit_log')) as size;

\echo 'Total indexes size:'
SELECT pg_size_pretty(SUM(pg_relation_size(indexrelid))) as size
FROM pg_index
WHERE indrelname IN (SELECT indexname FROM pg_indexes WHERE tablename IN ('products', 'inventory_audit_log'));

-- ============================================================================
-- PART 12: Final Summary
-- ============================================================================

\echo ''
\echo '=== VERIFICATION COMPLETE ==='
\echo 'If all items show ✓, the migration was successful.'
\echo 'If any items show ✗, review the migration output for errors.'
\echo ''

-- Reset settings
\set QUIET off
