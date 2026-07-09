-- ============================================================================
-- DATABASE INDEX VERIFICATION & BENCHMARK SCRIPT
-- ============================================================================
-- Purpose: Verify that critical production queries for DLQ, state machine,
--          wallet, and outbox use indexes correctly and don't require full
--          table scans.
--
-- INSTRUCTIONS:
-- Run this script in your Supabase SQL Editor.
-- Examine the 'QUERY PLAN' output for each query.
-- ✅ GOOD: You see "Index Scan" or "Index Only Scan"
-- ❌ BAD: You see "Seq Scan" on large tables (unless the table is very small)
-- ============================================================================

-- Enable timing to get accurate execution times in the output
\timing on

-- ============================================================================
-- 1. ORDER STATE MACHINE & ROLE CHECKS
-- ============================================================================
EXPLAIN ANALYZE
SELECT id, status, current_role
FROM orders
WHERE status = 'pending' AND current_role = 'delivery';

EXPLAIN ANALYZE
SELECT o.id, o.status, at.allowed_roles
FROM orders o
JOIN allowed_transitions at ON o.status = at.from_state
WHERE o.id = '00000000-0000-0000-0000-000000000000'; -- Replace with real UUID in testing

-- ============================================================================
-- 2. WALLET LEDGER & IDEMPOTENCY
-- ============================================================================
EXPLAIN ANALYZE
SELECT balance, version 
FROM wallet_balance 
WHERE user_id = '00000000-0000-0000-0000-000000000000'
FOR UPDATE;

EXPLAIN ANALYZE
SELECT id 
FROM wallet_transactions 
WHERE order_id = '00000000-0000-0000-0000-000000000000' 
  AND transaction_type = 'refund';

-- ============================================================================
-- 3. DLQ & SYNC RETRY OUTBOX
-- ============================================================================
EXPLAIN ANALYZE
SELECT * 
FROM outbox_events 
WHERE status = 'pending' 
  AND next_retry_at <= NOW()
ORDER BY created_at ASC
LIMIT 100;

EXPLAIN ANALYZE
SELECT * 
FROM dlq_messages 
WHERE resolved_at IS NULL
ORDER BY created_at DESC
LIMIT 50;

-- ============================================================================
-- 4. INVENTORY & RESERVATION LOOKUPS
-- ============================================================================
EXPLAIN ANALYZE
SELECT * 
FROM inventory_reservations 
WHERE status = 'active' 
  AND expires_at < NOW();

EXPLAIN ANALYZE
SELECT total_quantity, available_quantity 
FROM inventory 
WHERE product_id = '00000000-0000-0000-0000-000000000000';
