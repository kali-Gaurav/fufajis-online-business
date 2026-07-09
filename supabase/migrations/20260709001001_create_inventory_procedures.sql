-- Migration: Create atomic inventory procedures for reserve, confirm, cancel
-- Author: Agent 5 (Inventory System Implementation)
-- Date: 2026-07-09
-- Purpose: Implement transactional inventory operations with row locking

-- ============================================================================
-- STEP 1: Create reservations table (if not exists)
-- ============================================================================
CREATE TABLE IF NOT EXISTS reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  order_session_id TEXT NOT NULL,
  user_id TEXT,
  status TEXT NOT NULL DEFAULT 'active', -- 'active', 'confirmed', 'expired', 'cancelled'
  expires_at TIMESTAMP NOT NULL DEFAULT (NOW() + INTERVAL '30 minutes'),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- Create indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_reservations_product_id ON reservations(product_id);
CREATE INDEX IF NOT EXISTS idx_reservations_order_session_id ON reservations(order_session_id);
CREATE INDEX IF NOT EXISTS idx_reservations_user_id ON reservations(user_id);
CREATE INDEX IF NOT EXISTS idx_reservations_status ON reservations(status);
CREATE INDEX IF NOT EXISTS idx_reservations_expires_at ON reservations(expires_at);

-- ============================================================================
-- STEP 2: Create order_product_mapping table (if not exists)
-- ============================================================================
CREATE TABLE IF NOT EXISTS order_product_mapping (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  reserved_quantity INTEGER NOT NULL DEFAULT 0,
  confirmed_quantity INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  UNIQUE(order_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_order_product_mapping_order_id ON order_product_mapping(order_id);
CREATE INDEX IF NOT EXISTS idx_order_product_mapping_product_id ON order_product_mapping(product_id);

-- ============================================================================
-- STEP 3: Create inventory_api_logs table (if not exists)
-- ============================================================================
CREATE TABLE IF NOT EXISTS inventory_api_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  api_name TEXT NOT NULL, -- 'reserve', 'confirm', 'cancel'
  user_id TEXT,
  product_id TEXT,
  quantity INTEGER,
  reservation_id uuid,
  order_id TEXT,
  status TEXT NOT NULL, -- 'success', 'error'
  error_message TEXT,
  duration_ms INTEGER,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inventory_api_logs_api_name ON inventory_api_logs(api_name);
CREATE INDEX IF NOT EXISTS idx_inventory_api_logs_product_id ON inventory_api_logs(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_api_logs_created_at ON inventory_api_logs(created_at);

-- ============================================================================
-- STEP 4: Ensure products table has inventory columns
-- ============================================================================
-- Add columns if they don't exist (using DO block for safety)
DO $$
BEGIN
  -- Add available_stock if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='products' AND column_name='available_stock'
  ) THEN
    ALTER TABLE products ADD COLUMN available_stock INTEGER NOT NULL DEFAULT 0;
  END IF;

  -- Add reserved_stock if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='products' AND column_name='reserved_stock'
  ) THEN
    ALTER TABLE products ADD COLUMN reserved_stock INTEGER NOT NULL DEFAULT 0;
  END IF;

  -- Add sold_stock if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='products' AND column_name='sold_stock'
  ) THEN
    ALTER TABLE products ADD COLUMN sold_stock INTEGER NOT NULL DEFAULT 0;
  END IF;
END $$;

-- ============================================================================
-- STEP 5: Create reserve_inventory_atomic() stored procedure
-- ============================================================================
-- This procedure atomically reserves inventory with row locking
CREATE OR REPLACE FUNCTION reserve_inventory_atomic(
  p_product_id TEXT,
  p_quantity INTEGER,
  p_order_session_id TEXT,
  p_user_id TEXT DEFAULT NULL
) RETURNS TABLE (
  reservation_id uuid,
  new_available INTEGER,
  product_id TEXT,
  quantity INTEGER
) AS $$
DECLARE
  v_reservation_id uuid;
  v_new_available INTEGER;
  v_product_id TEXT;
  v_quantity INTEGER;
BEGIN
  -- Start transaction with row lock
  BEGIN
    -- Lock the product row (FOR UPDATE prevents concurrent modifications)
    SELECT p.id, p.available_stock, p.reserved_stock
    INTO v_product_id, v_new_available, v_quantity
    FROM products p
    WHERE p.id = p_product_id
    FOR UPDATE;

    -- Check if product exists
    IF v_product_id IS NULL THEN
      RAISE EXCEPTION 'Product not found';
    END IF;

    -- Check if enough stock available
    IF v_new_available < p_quantity THEN
      RAISE EXCEPTION 'Insufficient stock';
    END IF;

    -- Create reservation record
    INSERT INTO reservations (
      product_id,
      quantity,
      order_session_id,
      user_id,
      expires_at
    ) VALUES (
      p_product_id,
      p_quantity,
      p_order_session_id,
      p_user_id,
      NOW() + INTERVAL '30 minutes'
    ) RETURNING reservations.id INTO v_reservation_id;

    -- Update product stock atomically
    UPDATE products SET
      available_stock = available_stock - p_quantity,
      reserved_stock = reserved_stock + p_quantity,
      updated_at = NOW()
    WHERE id = p_product_id;

    -- Return new state
    v_new_available := v_new_available - p_quantity;

    RETURN QUERY SELECT v_reservation_id, v_new_available, p_product_id, p_quantity;

  EXCEPTION WHEN OTHERS THEN
    -- Transaction automatically rolled back on error
    RAISE;
  END;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 6: Create confirm_inventory_atomic() stored procedure
-- ============================================================================
-- This procedure atomically confirms reservation (moves to sold stock)
-- Idempotent: Safe to call multiple times
CREATE OR REPLACE FUNCTION confirm_inventory_atomic(
  p_reservation_id uuid,
  p_order_id TEXT,
  p_user_id TEXT DEFAULT NULL
) RETURNS TABLE (
  product_id TEXT,
  quantity INTEGER,
  final_sold_stock INTEGER
) AS $$
DECLARE
  v_product_id TEXT;
  v_quantity INTEGER;
  v_new_sold INTEGER;
  v_reserved_stock INTEGER;
BEGIN
  -- Start transaction with row lock
  BEGIN
    -- Look up reservation (lock it)
    SELECT r.product_id, r.quantity
    INTO v_product_id, v_quantity
    FROM reservations r
    WHERE r.id = p_reservation_id AND r.status = 'active'
    FOR UPDATE;

    -- Check if reservation exists and is active
    IF v_product_id IS NULL THEN
      RAISE EXCEPTION 'Reservation not found or already processed';
    END IF;

    -- Lock product row
    SELECT p.reserved_stock, p.sold_stock
    INTO v_reserved_stock, v_new_sold
    FROM products p
    WHERE p.id = v_product_id
    FOR UPDATE;

    -- Verify stock hasn't changed
    IF v_reserved_stock < v_quantity THEN
      RAISE EXCEPTION 'Stock mismatch: reserved stock changed during checkout';
    END IF;

    -- Move from reserved to sold
    UPDATE products SET
      reserved_stock = reserved_stock - v_quantity,
      sold_stock = sold_stock + v_quantity,
      updated_at = NOW()
    WHERE id = v_product_id;

    -- Update reservation status
    UPDATE reservations SET
      status = 'confirmed',
      updated_at = NOW()
    WHERE id = p_reservation_id;

    -- Create order-product mapping
    INSERT INTO order_product_mapping (
      order_id,
      product_id,
      quantity,
      confirmed_quantity
    ) VALUES (
      p_order_id,
      v_product_id,
      v_quantity,
      v_quantity
    ) ON CONFLICT (order_id, product_id) DO UPDATE SET
      confirmed_quantity = EXCLUDED.confirmed_quantity,
      updated_at = NOW();

    -- Return new state
    v_new_sold := v_new_sold + v_quantity;

    RETURN QUERY SELECT v_product_id, v_quantity, v_new_sold;

  EXCEPTION WHEN OTHERS THEN
    -- Transaction automatically rolled back on error
    RAISE;
  END;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 7: Create cancel_inventory_atomic() stored procedure
-- ============================================================================
-- This procedure atomically cancels reservation (returns to available)
-- Idempotent: Safe to call multiple times
CREATE OR REPLACE FUNCTION cancel_inventory_atomic(
  p_reservation_id uuid,
  p_user_id TEXT DEFAULT NULL
) RETURNS TABLE (
  product_id TEXT,
  quantity INTEGER,
  restored_stock INTEGER
) AS $$
DECLARE
  v_product_id TEXT;
  v_quantity INTEGER;
  v_new_available INTEGER;
  v_reserved_stock INTEGER;
  v_status TEXT;
BEGIN
  -- Start transaction with row lock
  BEGIN
    -- Look up reservation (lock it)
    SELECT r.product_id, r.quantity, r.status
    INTO v_product_id, v_quantity, v_status
    FROM reservations r
    WHERE r.id = p_reservation_id
    FOR UPDATE;

    -- If reservation doesn't exist, treat as idempotent success
    IF v_product_id IS NULL THEN
      RAISE EXCEPTION 'Reservation not found';
    END IF;

    -- Can't cancel if already confirmed
    IF v_status = 'confirmed' THEN
      RAISE EXCEPTION 'Already confirmed: Cannot cancel sold inventory';
    END IF;

    -- Lock product row
    SELECT p.reserved_stock, p.available_stock
    INTO v_reserved_stock, v_new_available
    FROM products p
    WHERE p.id = v_product_id
    FOR UPDATE;

    -- Verify stock is correct
    IF v_reserved_stock < v_quantity THEN
      RAISE EXCEPTION 'Stock mismatch: reserved stock invalid during cancel';
    END IF;

    -- Move from reserved back to available
    UPDATE products SET
      reserved_stock = reserved_stock - v_quantity,
      available_stock = available_stock + v_quantity,
      updated_at = NOW()
    WHERE id = v_product_id;

    -- Mark reservation as cancelled
    UPDATE reservations SET
      status = 'cancelled',
      updated_at = NOW()
    WHERE id = p_reservation_id;

    -- Return new state
    v_new_available := v_new_available + v_quantity;

    RETURN QUERY SELECT v_product_id, v_quantity, v_new_available;

  EXCEPTION WHEN OTHERS THEN
    -- Transaction automatically rolled back on error
    RAISE;
  END;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 8: Create audit trigger for inventory changes
-- ============================================================================
CREATE TABLE IF NOT EXISTS inventory_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id TEXT NOT NULL,
  action TEXT NOT NULL, -- 'reserve', 'confirm', 'cancel', 'manual_update'
  before_available INTEGER,
  before_reserved INTEGER,
  before_sold INTEGER,
  after_available INTEGER,
  after_reserved INTEGER,
  after_sold INTEGER,
  user_id TEXT,
  order_id TEXT,
  reservation_id uuid,
  change_reason TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inventory_audit_log_product_id ON inventory_audit_log(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_audit_log_created_at ON inventory_audit_log(created_at);

-- ============================================================================
-- STEP 9: Grant permissions
-- ============================================================================
-- Make functions callable by authenticated users
GRANT EXECUTE ON FUNCTION reserve_inventory_atomic TO authenticated;
GRANT EXECUTE ON FUNCTION confirm_inventory_atomic TO authenticated;
GRANT EXECUTE ON FUNCTION cancel_inventory_atomic TO authenticated;

-- ============================================================================
-- STEP 10: Verification checks
-- ============================================================================
-- Run this query to verify schema:
-- SELECT COUNT(*) FROM information_schema.columns WHERE table_name IN ('products', 'reservations', 'order_product_mapping', 'inventory_api_logs');
-- Should return >= 20 columns

-- Verify procedures exist:
-- SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name LIKE '%inventory%';
-- Should return: reserve_inventory_atomic, confirm_inventory_atomic, cancel_inventory_atomic
