-- MODULE 2 FIX: Complete 3-Layer Inventory System
-- Implements: available → reserved (on checkout) → sold (on payment success)
-- With atomic transactions, row-level locking, and race condition prevention

-- ============================================================================
-- TIER 1: PRODUCTS & INVENTORY BASE
-- ============================================================================

-- Product inventory state (source of truth in PostgreSQL)
CREATE TABLE IF NOT EXISTS product_inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL UNIQUE REFERENCES products(id) ON DELETE CASCADE,
  shop_id UUID NOT NULL,

  -- Three-layer stock model
  available_stock INT NOT NULL DEFAULT 0,  -- Can be ordered
  reserved_stock INT NOT NULL DEFAULT 0,   -- Checkout pending payment
  sold_stock INT NOT NULL DEFAULT 0,       -- Payment confirmed

  -- Metadata
  last_stock_check TIMESTAMP,
  last_mutation TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_product_inventory_product ON product_inventory(product_id);
CREATE INDEX idx_product_inventory_shop ON product_inventory(shop_id);

-- ============================================================================
-- TIER 2: INVENTORY MUTATIONS LOG (Audit Trail)
-- ============================================================================

CREATE TABLE IF NOT EXISTS inventory_mutations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  shop_id UUID NOT NULL,
  order_id UUID,

  -- State change
  mutation_type VARCHAR(50) NOT NULL, -- 'reserve', 'sell', 'cancel', 'backfill', 'adjust'
  quantity INT NOT NULL,

  -- Before/After state
  available_before INT,
  available_after INT,
  reserved_before INT,
  reserved_after INT,
  sold_before INT,
  sold_after INT,

  -- Context
  triggered_by VARCHAR(100), -- 'checkout', 'payment_success', 'order_cancel', 'admin'
  user_id UUID,
  reason TEXT,

  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_inventory_mutations_product ON inventory_mutations(product_id);
CREATE INDEX idx_inventory_mutations_order ON inventory_mutations(order_id);
CREATE INDEX idx_inventory_mutations_created ON inventory_mutations(created_at DESC);

-- ============================================================================
-- TIER 3: ATOMIC FUNCTIONS (Transactional Operations)
-- ============================================================================

-- Function: Reserve stock for checkout (available → reserved)
CREATE OR REPLACE FUNCTION reserve_inventory_atomic(
  p_product_id UUID,
  p_shop_id UUID,
  p_order_id UUID,
  p_quantity INT
)
RETURNS TABLE (
  success BOOLEAN,
  error_message TEXT,
  available_after INT,
  reserved_after INT
) AS $$
DECLARE
  v_inventory RECORD;
  v_available_after INT;
  v_reserved_after INT;
BEGIN
  -- ATOMIC: Lock row + read current state
  SELECT * INTO v_inventory FROM product_inventory
  WHERE product_id = p_product_id AND shop_id = p_shop_id
  FOR UPDATE;  -- Row-level lock prevents concurrent mutations

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, 'Product inventory not found'::TEXT, 0, 0;
    RETURN;
  END IF;

  -- VALIDATION: Check available stock
  IF v_inventory.available_stock < p_quantity THEN
    RETURN QUERY SELECT FALSE,
      'Insufficient available stock. Have: ' || v_inventory.available_stock || ', need: ' || p_quantity,
      v_inventory.available_stock,
      v_inventory.reserved_stock;
    RETURN;
  END IF;

  -- MUTATION: Move stock from available → reserved
  v_available_after := v_inventory.available_stock - p_quantity;
  v_reserved_after := v_inventory.reserved_stock + p_quantity;

  UPDATE product_inventory
  SET
    available_stock = v_available_after,
    reserved_stock = v_reserved_after,
    last_mutation = NOW(),
    updated_at = NOW()
  WHERE product_id = p_product_id AND shop_id = p_shop_id;

  -- LOG MUTATION
  INSERT INTO inventory_mutations (
    product_id, shop_id, order_id, mutation_type, quantity,
    available_before, available_after, reserved_before, reserved_after,
    sold_before, sold_after, triggered_by, reason
  ) VALUES (
    p_product_id, p_shop_id, p_order_id, 'reserve', p_quantity,
    v_inventory.available_stock, v_available_after,
    v_inventory.reserved_stock, v_reserved_after,
    v_inventory.sold_stock, v_inventory.sold_stock,
    'checkout', 'Reserved for order ' || p_order_id
  );

  RETURN QUERY SELECT TRUE, 'Stock reserved successfully'::TEXT,
    v_available_after, v_reserved_after;
END;
$$ LANGUAGE plpgsql;

-- Function: Confirm payment + move reserved → sold
CREATE OR REPLACE FUNCTION confirm_inventory_sale_atomic(
  p_product_id UUID,
  p_shop_id UUID,
  p_order_id UUID,
  p_quantity INT
)
RETURNS TABLE (
  success BOOLEAN,
  error_message TEXT,
  reserved_after INT,
  sold_after INT
) AS $$
DECLARE
  v_inventory RECORD;
  v_reserved_after INT;
  v_sold_after INT;
BEGIN
  -- ATOMIC: Lock row + read current state
  SELECT * INTO v_inventory FROM product_inventory
  WHERE product_id = p_product_id AND shop_id = p_shop_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, 'Product inventory not found'::TEXT, 0, 0;
    RETURN;
  END IF;

  -- VALIDATION: Check reserved stock
  IF v_inventory.reserved_stock < p_quantity THEN
    RETURN QUERY SELECT FALSE,
      'Insufficient reserved stock. Have: ' || v_inventory.reserved_stock || ', need: ' || p_quantity,
      v_inventory.reserved_stock,
      v_inventory.sold_stock;
    RETURN;
  END IF;

  -- MUTATION: Move stock from reserved → sold
  v_reserved_after := v_inventory.reserved_stock - p_quantity;
  v_sold_after := v_inventory.sold_stock + p_quantity;

  UPDATE product_inventory
  SET
    reserved_stock = v_reserved_after,
    sold_stock = v_sold_after,
    last_mutation = NOW(),
    updated_at = NOW()
  WHERE product_id = p_product_id AND shop_id = p_shop_id;

  -- LOG MUTATION
  INSERT INTO inventory_mutations (
    product_id, shop_id, order_id, mutation_type, quantity,
    available_before, available_after, reserved_before, reserved_after,
    sold_before, sold_after, triggered_by, reason
  ) VALUES (
    p_product_id, p_shop_id, p_order_id, 'sell', p_quantity,
    v_inventory.available_stock, v_inventory.available_stock,
    v_inventory.reserved_stock, v_reserved_after,
    v_inventory.sold_stock, v_sold_after,
    'payment_success', 'Payment confirmed for order ' || p_order_id
  );

  RETURN QUERY SELECT TRUE, 'Sale confirmed successfully'::TEXT,
    v_reserved_after, v_sold_after;
END;
$$ LANGUAGE plpgsql;

-- Function: Cancel reservation (reserved → available on order cancel)
CREATE OR REPLACE FUNCTION cancel_inventory_reservation_atomic(
  p_product_id UUID,
  p_shop_id UUID,
  p_order_id UUID,
  p_quantity INT
)
RETURNS TABLE (
  success BOOLEAN,
  error_message TEXT,
  available_after INT,
  reserved_after INT
) AS $$
DECLARE
  v_inventory RECORD;
  v_available_after INT;
  v_reserved_after INT;
BEGIN
  -- ATOMIC: Lock row + read current state
  SELECT * INTO v_inventory FROM product_inventory
  WHERE product_id = p_product_id AND shop_id = p_shop_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, 'Product inventory not found'::TEXT, 0, 0;
    RETURN;
  END IF;

  -- VALIDATION: Check reserved stock
  IF v_inventory.reserved_stock < p_quantity THEN
    RETURN QUERY SELECT FALSE,
      'Cannot cancel: insufficient reserved stock',
      v_inventory.available_stock,
      v_inventory.reserved_stock;
    RETURN;
  END IF;

  -- MUTATION: Move stock from reserved → available
  v_available_after := v_inventory.available_stock + p_quantity;
  v_reserved_after := v_inventory.reserved_stock - p_quantity;

  UPDATE product_inventory
  SET
    available_stock = v_available_after,
    reserved_stock = v_reserved_after,
    last_mutation = NOW(),
    updated_at = NOW()
  WHERE product_id = p_product_id AND shop_id = p_shop_id;

  -- LOG MUTATION
  INSERT INTO inventory_mutations (
    product_id, shop_id, order_id, mutation_type, quantity,
    available_before, available_after, reserved_before, reserved_after,
    sold_before, sold_after, triggered_by, reason
  ) VALUES (
    p_product_id, p_shop_id, p_order_id, 'cancel', p_quantity,
    v_inventory.available_stock, v_available_after,
    v_inventory.reserved_stock, v_reserved_after,
    v_inventory.sold_stock, v_inventory.sold_stock,
    'order_cancel', 'Cancellation for order ' || p_order_id
  );

  RETURN QUERY SELECT TRUE, 'Reservation cancelled successfully'::TEXT,
    v_available_after, v_reserved_after;
END;
$$ LANGUAGE plpgsql;

-- Function: Check available stock without mutation
CREATE OR REPLACE FUNCTION check_available_stock(
  p_product_id UUID,
  p_shop_id UUID
)
RETURNS TABLE (
  available INT,
  reserved INT,
  sold INT,
  total_allocated INT,
  can_order_qty INT
) AS $$
DECLARE
  v_inventory RECORD;
BEGIN
  SELECT * INTO v_inventory FROM product_inventory
  WHERE product_id = p_product_id AND shop_id = p_shop_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT 0, 0, 0, 0, 0;
  ELSE
    RETURN QUERY SELECT
      v_inventory.available_stock,
      v_inventory.reserved_stock,
      v_inventory.sold_stock,
      v_inventory.reserved_stock + v_inventory.sold_stock,
      v_inventory.available_stock;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SUMMARY: 3-LAYER INVENTORY WITH ATOMIC LOCKING
-- ============================================================================
--
-- BEFORE (VULNERABLE):
-- - Direct Firestore writes allowed (race conditions)
-- - No three-layer separation (available, reserved, sold)
-- - Concurrent orders can oversell
-- - No audit trail
-- - Stock mutation not atomic
--
-- AFTER (FIXED):
-- 1. product_inventory table = source of truth
-- 2. Atomic operations with FOR UPDATE row locking
-- 3. Three-layer flow: available → reserved → sold
-- 4. Full mutation audit trail
-- 5. Concurrent operations serialize safely
--
-- FLOW:
-- Checkout: reserve_inventory_atomic() → available -= qty, reserved += qty
-- Payment: confirm_inventory_sale_atomic() → reserved -= qty, sold += qty
-- Cancel: cancel_inventory_reservation_atomic() → reserved -= qty, available += qty
--
-- RACE CONDITION PREVENTION:
-- FOR UPDATE lock ensures only one thread modifies row at a time
-- Validation checks happen inside transaction
-- No time-of-check/time-of-use (TOCTOU) gap
--
-- COMPLIANCE:
-- - Full audit trail in inventory_mutations
-- - Can reconcile: available + reserved + sold = original stock
-- - Can replay mutations to debug issues
-- - Complete visibility into stock lifecycle
