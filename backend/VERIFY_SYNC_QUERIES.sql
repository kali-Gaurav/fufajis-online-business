-- PRIORITY 2: FIRESTORE SYNC VERIFICATION
-- Fufaji Store Batch 1 Seeding Validation
-- Date: 2026-07-04

-- =========================================
-- PART A: SUPABASE VERIFICATION
-- =========================================

-- Query 1: Product count (should be 45)
SELECT
  COUNT(*) as total_products,
  COUNT(DISTINCT category) as unique_categories
FROM catalog_products
WHERE created_at > NOW() - INTERVAL '30 minutes'
AND category IN ('vegetables', 'fruits', 'dairy', 'rice', 'flour', 'pulses');

-- Expected output:
-- total_products | unique_categories
-- 45             | 6

-- Query 2: Variant count (should be 94)
SELECT
  COUNT(*) as total_variants,
  AVG(variant_count) as avg_variants_per_product,
  MAX(variant_count) as max_variants
FROM (
  SELECT product_id, COUNT(*) as variant_count
  FROM catalog_variants
  WHERE created_at > NOW() - INTERVAL '30 minutes'
  GROUP BY product_id
) variant_counts;

-- Expected output:
-- total_variants | avg_variants_per_product | max_variants
-- 94             | 2.1                      | 3

-- Query 3: Price validation (all MRP >= selling_price)
SELECT
  COUNT(*) as total_valid,
  COUNT(CASE WHEN mrp < selling_price THEN 1 END) as price_violations
FROM catalog_variants
WHERE created_at > NOW() - INTERVAL '30 minutes';

-- Expected output:
-- total_valid | price_violations
-- 94          | 0

-- Query 4: Brand distribution
SELECT
  brand,
  COUNT(*) as product_count,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM catalog_products WHERE created_at > NOW() - INTERVAL '30 minutes'), 1) as percentage
FROM catalog_products
WHERE created_at > NOW() - INTERVAL '30 minutes'
GROUP BY brand
ORDER BY product_count DESC;

-- Expected output:
-- brand         | product_count | percentage
-- Generic       | 35            | 77.8
-- Amul          | 4             | 8.9
-- Aashirvaad    | 1             | 2.2

-- Query 5: Category breakdown
SELECT
  category,
  COUNT(*) as count,
  STRING_AGG(name, ', ' ORDER BY name) as product_names
FROM catalog_products
WHERE created_at > NOW() - INTERVAL '30 minutes'
GROUP BY category
ORDER BY count DESC;

-- Expected output:
-- category   | count | product_names
-- vegetables | 20    | [20 vegetable names]
-- fruits     | 10    | [10 fruit names]
-- dairy      | 6     | [6 dairy names]
-- rice       | 3     | [3 rice names]
-- flour      | 1     | Wheat Flour (Atta)
-- pulses     | 3     | [3 pulse names]

-- =========================================
-- PART B: FIRESTORE SYNC CHECK
-- =========================================

-- Query 6: Sync events status (monitor trigger execution)
SELECT
  status,
  COUNT(*) as event_count,
  ROUND(AVG(EXTRACT(EPOCH FROM (completed_at - created_at))), 3) as avg_latency_seconds,
  MAX(EXTRACT(EPOCH FROM (completed_at - created_at))) as max_latency_seconds
FROM sync_events
WHERE created_at > NOW() - INTERVAL '30 minutes'
AND source_table = 'catalog_products'
GROUP BY status
ORDER BY event_count DESC;

-- Expected output:
-- status    | event_count | avg_latency_seconds | max_latency_seconds
-- completed | 45          | 0.120               | 0.315
-- pending   | 0           | NULL                | NULL
-- failed    | 0           | NULL                | NULL

-- Query 7: Failed sync events (if any)
SELECT
  product_id,
  status,
  error_message,
  created_at,
  retry_count
FROM sync_events
WHERE status = 'failed'
AND created_at > NOW() - INTERVAL '30 minutes'
ORDER BY created_at DESC;

-- Expected output: (empty — no failures)

-- Query 8: Data consistency check (spot-check 5 products)
SELECT
  cp.id,
  cp.name,
  cp.hindi_name,
  cp.unit,
  cp.category,
  COUNT(cv.id) as variant_count,
  cp.created_at,
  cp.firestore_synced_at
FROM catalog_products cp
LEFT JOIN catalog_variants cv ON cp.id = cv.product_id
WHERE cp.created_at > NOW() - INTERVAL '30 minutes'
GROUP BY cp.id, cp.name, cp.hindi_name, cp.unit, cp.category, cp.created_at, cp.firestore_synced_at
LIMIT 5;

-- Expected output:
-- id   | name              | hindi_name | unit | category    | variant_count | created_at              | firestore_synced_at
-- .... | Potatoes (Aloo)   | आलू       | kg   | vegetables  | 2             | 2026-07-04 10:00:00 UTC | 2026-07-04 10:00:12 UTC
-- .... | Amul Milk         | अमूल दूध  | L    | dairy       | 3             | 2026-07-04 10:01:30 UTC | 2026-07-04 10:01:42 UTC
-- [etc]

-- Query 9: Voice metadata presence (all products should have it)
SELECT
  COUNT(*) as total_products,
  COUNT(CASE WHEN voice_metadata IS NOT NULL AND voice_metadata != '{}' THEN 1 END) as with_metadata,
  COUNT(CASE WHEN voice_metadata IS NULL OR voice_metadata = '{}' THEN 1 END) as without_metadata
FROM catalog_products
WHERE created_at > NOW() - INTERVAL '30 minutes';

-- Expected output:
-- total_products | with_metadata | without_metadata
-- 45             | 45            | 0

-- Query 10: Dual-DB sync latency summary
SELECT
  'Supabase to Firestore Sync' as metric,
  ROUND(AVG(EXTRACT(EPOCH FROM (completed_at - created_at)))::numeric, 3) as avg_latency_sec,
  ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (completed_at - created_at)))::numeric, 3) as p95_latency_sec,
  ROUND(MAX(EXTRACT(EPOCH FROM (completed_at - created_at)))::numeric, 3) as max_latency_sec,
  COUNT(*) as total_syncs,
  ROUND(100.0 * COUNT(CASE WHEN status = 'completed' THEN 1 END) / COUNT(*), 1) as success_rate_percent
FROM sync_events
WHERE created_at > NOW() - INTERVAL '30 minutes'
AND source_table IN ('catalog_products', 'catalog_variants');

-- Expected output:
-- metric                          | avg_latency_sec | p95_latency_sec | max_latency_sec | total_syncs | success_rate_percent
-- Supabase to Firestore Sync      | 0.120           | 0.180           | 0.315           | 139         | 100.0

-- =========================================
-- PART C: PERFORMANCE BASELINE
-- =========================================

-- Query 11: Insert performance
SELECT
  (SELECT COUNT(*) FROM catalog_products WHERE created_at > NOW() - INTERVAL '30 minutes') as products_inserted,
  (SELECT COUNT(*) FROM catalog_variants WHERE created_at > NOW() - INTERVAL '30 minutes') as variants_inserted,
  ROUND((SELECT MAX(created_at) - MIN(created_at) FROM catalog_products WHERE created_at > NOW() - INTERVAL '30 minutes')::numeric / INTERVAL '1 second', 1) as total_insertion_time_sec;

-- Expected output:
-- products_inserted | variants_inserted | total_insertion_time_sec
-- 45                | 94                | 15.0

-- Query 12: Ready for production check (must pass all conditions)
SELECT
  'Products count >= 45' as check_name,
  (SELECT COUNT(*) >= 45 FROM catalog_products WHERE created_at > NOW() - INTERVAL '30 minutes') as result
UNION ALL
SELECT 'Variants count >= 94', COUNT(*) >= 94 FROM catalog_variants WHERE created_at > NOW() - INTERVAL '30 minutes'
UNION ALL
SELECT 'No price violations', COUNT(CASE WHEN mrp >= selling_price THEN 1 END) = COUNT(*) FROM catalog_variants WHERE created_at > NOW() - INTERVAL '30 minutes'
UNION ALL
SELECT 'Sync success rate = 100%', COUNT(CASE WHEN status = 'completed' THEN 1 END) = COUNT(*) FROM sync_events WHERE created_at > NOW() - INTERVAL '30 minutes' AND source_table IN ('catalog_products', 'catalog_variants')
UNION ALL
SELECT 'Voice metadata present', COUNT(CASE WHEN voice_metadata IS NOT NULL THEN 1 END) = COUNT(*) FROM catalog_products WHERE created_at > NOW() - INTERVAL '30 minutes';

-- Expected output:
-- check_name                      | result
-- Products count >= 45            | true
-- Variants count >= 94            | true
-- No price violations             | true
-- Sync success rate = 100%        | true
-- Voice metadata present          | true

-- =========================================
-- EXECUTION INSTRUCTIONS
-- =========================================

-- Run these queries immediately after seeding:
--   1. Copy-paste each query into Supabase SQL Editor
--   2. Note the results in the validation report
--   3. All "Expected output" must match actual output
--   4. If any mismatch, BLOCK release and diagnose

-- Run every 5 seconds for first 2 minutes (check Query 6 status)
-- CRITICAL: If sync_events shows 'failed' or 'pending', investigate before proceeding
