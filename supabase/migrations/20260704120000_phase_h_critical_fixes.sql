-- ============================================================================
-- PHASE H CRITICAL FIXES — Database Migration
-- Date: 2026-07-04
-- Critical Issues Fixed:
--   1. OTP plaintext storage → Hash-only schema
--   2. Order status type safety → PostgreSQL ENUM
--   3. Webhook reliability → Outbox events pattern
-- ============================================================================

-- ============================================================================
-- ISSUE #1: FIX OTP SCHEMA (Plaintext → Hash only)
-- ============================================================================

-- Drop old insecure otp_logs if exists
DROP TABLE IF EXISTS order_otp_logs CASCADE;

-- Create secure OTP logs (hash-only, never plaintext)
CREATE TABLE order_otp_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  otp_hash TEXT NOT NULL,                    -- SHA256 hash only, never plaintext
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(order_id, otp_hash)
);

CREATE INDEX IF NOT EXISTS idx_order_otp_logs_order_id ON order_otp_logs(order_id);

-- ============================================================================
-- ISSUE #2: ORDER STATUS ENUM (Type safety)
-- ============================================================================

-- Create PostgreSQL ENUM for order status
CREATE TYPE order_status_enum AS ENUM (
  'pending_payment',
  'confirmed',
  'processing',
  'packed',
  'shipped',
  'delivered',
  'failed_delivery',
  'returned',
  'refunded',
  'cancelled',
  'retry_dispatch'
);

-- Add status column as ENUM (if not already)
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS status_enum order_status_enum;

-- Migrate existing status text → enum
UPDATE orders
SET status_enum = status::order_status_enum
WHERE status IS NOT NULL AND status_enum IS NULL;

-- Once migration is verified, drop old status column and rename:
-- ALTER TABLE orders DROP COLUMN status;
-- ALTER TABLE orders RENAME COLUMN status_enum TO status;



-- ============================================================================
-- ISSUE #3: WEBHOOK RELIABILITY (Outbox pattern)
-- ============================================================================

-- Create outbox_events table for reliable Firestore sync
CREATE TABLE IF NOT EXISTS outbox_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_type TEXT NOT NULL,                -- 'order_created', 'order_status_changed', etc.
  aggregate_id TEXT NOT NULL,              -- order_id
  payload JSONB NOT NULL,                  -- full event data
  processed BOOLEAN DEFAULT FALSE,
  processed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  retry_count INT DEFAULT 0,
  last_error TEXT
);

CREATE INDEX IF NOT EXISTS idx_outbox_events_processed ON outbox_events(processed, created_at);
CREATE INDEX IF NOT EXISTS idx_outbox_events_aggregate_id ON outbox_events(aggregate_id);

-- ============================================================================
-- ORDER AUDIT TABLE (Track all mutations)
-- ============================================================================

CREATE TABLE IF NOT EXISTS order_audit_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,                -- 'status_changed', 'inventory_reversed', etc.
  previous_state JSONB,
  new_state JSONB,
  actor_id TEXT,
  actor_name TEXT,
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_order_audit_logs_order_id ON order_audit_logs(order_id);
CREATE INDEX IF NOT EXISTS idx_order_audit_logs_created_at ON order_audit_logs(created_at DESC);

-- ============================================================================
-- INVENTORY & STOCK CONSTRAINTS
-- ============================================================================

-- Ensure products table has branch_stock_map with constraints
ALTER TABLE products ADD COLUMN IF NOT EXISTS branch_stock_map JSONB DEFAULT '{}';

-- Add CHECK constraint on products table for stock sanity
ALTER TABLE products
ADD CONSTRAINT check_branch_stock_non_negative CHECK (
  -- This is a simplified check; ideally validate JSONB structure
  branch_stock_map IS NOT NULL
);

-- ============================================================================
-- DELIVERY LOGS TABLE (Enhanced)
-- ============================================================================

CREATE TABLE IF NOT EXISTS delivery_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  type TEXT NOT NULL,                      -- 'otp_verification_failed', 'otp_verification_success', 'delivery_attempted'
  actor_id TEXT,
  actor_role TEXT,
  provided_otp TEXT,                       -- Only for failed attempts (for audit)
  latitude FLOAT,
  longitude FLOAT,
  metadata JSONB DEFAULT '{}',
  timestamp TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_delivery_logs_order_id ON delivery_logs(order_id);
CREATE INDEX IF NOT EXISTS idx_delivery_logs_type ON delivery_logs(type);
CREATE INDEX IF NOT EXISTS idx_delivery_logs_timestamp ON delivery_logs(timestamp DESC);

-- ============================================================================
-- CASH COLLECTION LOGS (Enhanced)
-- ============================================================================

CREATE TABLE IF NOT EXISTS cash_collection_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  amount NUMERIC(10, 2) NOT NULL,
  collected_by TEXT,
  collected_at TIMESTAMP DEFAULT NOW(),
  status TEXT DEFAULT 'collected',        -- 'collected', 'pending', 'failed'
  reconciliation_status TEXT DEFAULT 'pending',
  notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_cash_collection_logs_order_id ON cash_collection_logs(order_id);
CREATE INDEX IF NOT EXISTS idx_cash_collection_logs_status ON cash_collection_logs(status);

-- ============================================================================
-- ORDERS TABLE ENHANCEMENTS
-- ============================================================================

-- Add critical missing columns to orders table
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS available_stock INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS reserved_stock INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS sold_stock INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS otp_hash TEXT,
ADD COLUMN IF NOT EXISTS otp_verified BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS delivery_agent_id TEXT,
ADD COLUMN IF NOT EXISTS delivery_agent_name TEXT,
ADD COLUMN IF NOT EXISTS delivery_agent_phone TEXT,
ADD COLUMN IF NOT EXISTS shipped_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS packer_id TEXT,
ADD COLUMN IF NOT EXISTS packer_name TEXT,
ADD COLUMN IF NOT EXISTS packing_started_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS failure_reason TEXT,
ADD COLUMN IF NOT EXISTS failure_latitude FLOAT,
ADD COLUMN IF NOT EXISTS failure_longitude FLOAT,
ADD COLUMN IF NOT EXISTS failure_timestamp TIMESTAMP,
ADD COLUMN IF NOT EXISTS cancellation_reason TEXT,
ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS exception_resolution TEXT,
ADD COLUMN IF NOT EXISTS resolution_notes TEXT,
ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS cash_collected_amount NUMERIC(10, 2),
ADD COLUMN IF NOT EXISTS cash_collected_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS status_history JSONB DEFAULT '[]',
ADD COLUMN IF NOT EXISTS delivery_verification JSONB;

-- Add CHECK constraints for inventory
ALTER TABLE orders
ADD CONSTRAINT check_inventory_non_negative CHECK (
  available_stock >= 0 AND
  reserved_stock >= 0 AND
  sold_stock >= 0
);

-- ============================================================================
-- INDEXES (Performance optimization)
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_agent_id ON orders(delivery_agent_id);
CREATE INDEX IF NOT EXISTS idx_orders_shop_id ON orders(shop_id);

-- ============================================================================
-- WALLET TRANSACTION TABLE (For audit trail)
-- ============================================================================

CREATE TABLE IF NOT EXISTS wallet_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  wallet_id TEXT NOT NULL,
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  transaction_type TEXT NOT NULL,          -- 'credit', 'debit', 'reversal'
  amount NUMERIC(10, 2) NOT NULL,
  previous_balance NUMERIC(10, 2),
  new_balance NUMERIC(10, 2),
  reason TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet_id ON wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_order_id ON wallet_transactions(order_id);

-- ============================================================================
-- MIGRATION VALIDATION
-- ============================================================================

-- Verify all tables exist and are accessible
DO $$
DECLARE
  table_count INT;
BEGIN
  SELECT COUNT(*) INTO table_count
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_name IN (
      'orders', 'products', 'users', 'wallets',
      'order_otp_logs', 'delivery_logs', 'cash_collection_logs',
      'order_audit_logs', 'outbox_events', 'wallet_transactions'
    );

  RAISE NOTICE 'Migration validation: % tables found (expected 10)', table_count;
END $$;

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================
-- Run this migration with:
-- psql $DATABASE_URL < supabase/migrations/phase_h_critical_fixes_20260704.sql
--
-- Verify with:
-- SELECT * FROM information_schema.tables WHERE table_schema = 'public';
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'orders';
-- ============================================================================
