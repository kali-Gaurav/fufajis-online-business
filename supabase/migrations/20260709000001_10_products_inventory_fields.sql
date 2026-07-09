-- ============================================================================
-- Migration: Add Inventory Fields to Products Table
-- Version: 20260709000001
-- Purpose: Align products table with 3-layer inventory model
--          and add supporting fields for inventory management
-- ============================================================================

-- ============================================================================
-- STEP 1: Add missing inventory columns to products table
-- ============================================================================

ALTER TABLE products ADD COLUMN IF NOT EXISTS available_stock INT DEFAULT 0 CHECK (available_stock >= 0);
ALTER TABLE products ADD COLUMN IF NOT EXISTS reserved_stock INT DEFAULT 0 CHECK (reserved_stock >= 0);
ALTER TABLE products ADD COLUMN IF NOT EXISTS sold_stock INT DEFAULT 0 CHECK (sold_stock >= 0);

-- Branch-level stock mapping for multi-branch operations
ALTER TABLE products ADD COLUMN IF NOT EXISTS branch_stock JSONB DEFAULT '{}'::JSONB;
ALTER TABLE products ADD COLUMN IF NOT EXISTS branch_stock_map JSONB DEFAULT '{}'::JSONB;

-- Minimum stock threshold for reordering
ALTER TABLE products ADD COLUMN IF NOT EXISTS minimum_stock INT DEFAULT 10;

-- Last inventory check timestamp
ALTER TABLE products ADD COLUMN IF NOT EXISTS last_stock_check TIMESTAMP;

-- SKU for product identification
ALTER TABLE products ADD COLUMN IF NOT EXISTS sku VARCHAR(100) UNIQUE;

-- Add constraint to prevent invalid stock allocations
ALTER TABLE products DROP CONSTRAINT IF EXISTS valid_stock_allocation;
ALTER TABLE products ADD CONSTRAINT valid_stock_allocation
  CHECK ((available_stock + reserved_stock + sold_stock) >= 0);

-- ============================================================================
-- STEP 2: Create indexes for performance
-- ============================================================================

-- Index for filtering by shop
CREATE INDEX IF NOT EXISTS idx_products_shop_id
  ON products(shop_id);

-- Index for low stock alerts
CREATE INDEX IF NOT EXISTS idx_products_low_stock
  ON products(shop_id, available_stock)
  WHERE is_active = true AND available_stock < minimum_stock;

-- Index for quick lookups by SKU
CREATE INDEX IF NOT EXISTS idx_products_sku
  ON products(shop_id, sku)
  WHERE sku IS NOT NULL;

-- Index for reserved stock tracking
CREATE INDEX IF NOT EXISTS idx_products_reserved
  ON products(shop_id, reserved_stock DESC)
  WHERE reserved_stock > 0;

-- Index for recent stock checks
CREATE INDEX IF NOT EXISTS idx_products_last_stock_check
  ON products(shop_id, last_stock_check DESC);

-- ============================================================================
-- STEP 3: Create trigger for automatic updated_at timestamp
-- ============================================================================

CREATE OR REPLACE FUNCTION update_products_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_products_auto_updated_at ON products;
CREATE TRIGGER trg_products_auto_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION update_products_updated_at();

-- ============================================================================
-- STEP 4: Create inventory audit table for tracking mutations
-- ============================================================================

CREATE TABLE IF NOT EXISTS inventory_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,

  -- Mutation details
  mutation_type VARCHAR(50) NOT NULL,
  -- Types: RESERVE, CONFIRM_SALE, CANCEL, ADJUST, BACKFILL, DAMAGE_REPORT, RETURN

  quantity_change INT NOT NULL,

  -- Before/After state
  available_before INT,
  available_after INT,
  reserved_before INT,
  reserved_after INT,
  sold_before INT,
  sold_after INT,

  -- Context
  triggered_by VARCHAR(100),  -- 'checkout', 'payment_success', 'order_cancel', 'manual_adjust', etc.
  order_id UUID,
  user_id UUID,
  reason TEXT,

  -- Timestamps
  created_at TIMESTAMP DEFAULT NOW(),

  CONSTRAINT valid_audit_values CHECK (
    (available_before IS NULL OR available_before >= 0) AND
    (available_after IS NULL OR available_after >= 0) AND
    (reserved_before IS NULL OR reserved_before >= 0) AND
    (reserved_after IS NULL OR reserved_after >= 0) AND
    (sold_before IS NULL OR sold_before >= 0) AND
    (sold_after IS NULL OR sold_after >= 0)
  )
);

-- Indexes for audit log
CREATE INDEX IF NOT EXISTS idx_audit_product ON inventory_audit_log(product_id);
CREATE INDEX IF NOT EXISTS idx_audit_shop ON inventory_audit_log(shop_id);
CREATE INDEX IF NOT EXISTS idx_audit_order ON inventory_audit_log(order_id);
CREATE INDEX IF NOT EXISTS idx_audit_type ON inventory_audit_log(mutation_type);
CREATE INDEX IF NOT EXISTS idx_audit_created ON inventory_audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_shop_created ON inventory_audit_log(shop_id, created_at DESC);

-- ============================================================================
-- STEP 5: Create inventory consistency check view
-- ============================================================================

CREATE OR REPLACE VIEW v_inventory_consistency AS
SELECT
  p.id,
  p.shop_id,
  p.name,
  p.sku,
  p.available_stock,
  p.reserved_stock,
  p.sold_stock,
  (p.available_stock + p.reserved_stock + p.sold_stock) AS total_allocated,
  p.minimum_stock,
  CASE
    WHEN p.available_stock < p.minimum_stock THEN 'LOW_STOCK'
    WHEN p.reserved_stock > 0 THEN 'RESERVED'
    WHEN p.sold_stock > 0 THEN 'SOLD'
    ELSE 'AVAILABLE'
  END AS stock_status,
  p.last_stock_check,
  (NOW() - p.last_stock_check) AS time_since_check,
  p.created_at,
  p.updated_at
FROM products p
WHERE p.is_active = true;

-- ============================================================================
-- STEP 6: Create atomic inventory operations stored procedures
-- ============================================================================

-- Procedure: Reserve stock (available → reserved)
CREATE OR REPLACE FUNCTION reserve_product_stock(
  p_product_id UUID,
  p_shop_id UUID,
  p_quantity INT,
  p_order_id UUID DEFAULT NULL,
  p_user_id UUID DEFAULT NULL,
  p_reason TEXT DEFAULT 'Checkout reservation'
)
RETURNS TABLE (
  success BOOLEAN,
  error_message TEXT,
  available_stock INT,
  reserved_stock INT
) AS $$
DECLARE
  v_product RECORD;
  v_available_after INT;
  v_reserved_after INT;
BEGIN
  -- Lock row and read current state atomically
  SELECT * INTO v_product FROM products
  WHERE id = p_product_id AND shop_id = p_shop_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, 'Product not found'::TEXT, 0, 0;
    RETURN;
  END IF;

  -- Validate available stock
  IF v_product.available_stock < p_quantity THEN
    RETURN QUERY SELECT FALSE,
      'Insufficient available stock. Have: ' || v_product.available_stock || ', need: ' || p_quantity,
      v_product.available_stock,
      v_product.reserved_stock;
    RETURN;
  END IF;

  -- Calculate new state
  v_available_after := v_product.available_stock - p_quantity;
  v_reserved_after := v_product.reserved_stock + p_quantity;

  -- Update products table
  UPDATE products
  SET
    available_stock = v_available_after,
    reserved_stock = v_reserved_after,
    last_stock_check = NOW(),
    updated_at = NOW()
  WHERE id = p_product_id AND shop_id = p_shop_id;

  -- Log to audit trail
  INSERT INTO inventory_audit_log (
    product_id, shop_id, mutation_type, quantity_change,
    available_before, available_after,
    reserved_before, reserved_after,
    sold_before, sold_after,
    triggered_by, order_id, user_id, reason
  ) VALUES (
    p_product_id, p_shop_id, 'RESERVE', p_quantity,
    v_product.available_stock, v_available_after,
    v_product.reserved_stock, v_reserved_after,
    v_product.sold_stock, v_product.sold_stock,
    'checkout', p_order_id, p_user_id, p_reason
  );

  RETURN QUERY SELECT TRUE, 'Stock reserved successfully'::TEXT,
    v_available_after, v_reserved_after;
END;
$$ LANGUAGE plpgsql;

-- Procedure: Confirm sale (reserved → sold)
CREATE OR REPLACE FUNCTION confirm_product_sale(
  p_product_id UUID,
  p_shop_id UUID,
  p_quantity INT,
  p_order_id UUID DEFAULT NULL,
  p_user_id UUID DEFAULT NULL,
  p_reason TEXT DEFAULT 'Payment confirmed'
)
RETURNS TABLE (
  success BOOLEAN,
  error_message TEXT,
  reserved_stock INT,
  sold_stock INT
) AS $$
DECLARE
  v_product RECORD;
  v_reserved_after INT;
  v_sold_after INT;
BEGIN
  -- Lock row and read current state atomically
  SELECT * INTO v_product FROM products
  WHERE id = p_product_id AND shop_id = p_shop_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, 'Product not found'::TEXT, 0, 0;
    RETURN;
  END IF;

  -- Validate reserved stock
  IF v_product.reserved_stock < p_quantity THEN
    RETURN QUERY SELECT FALSE,
      'Insufficient reserved stock. Have: ' || v_product.reserved_stock || ', need: ' || p_quantity,
      v_product.reserved_stock,
      v_product.sold_stock;
    RETURN;
  END IF;

  -- Calculate new state
  v_reserved_after := v_product.reserved_stock - p_quantity;
  v_sold_after := v_product.sold_stock + p_quantity;

  -- Update products table
  UPDATE products
  SET
    reserved_stock = v_reserved_after,
    sold_stock = v_sold_after,
    last_stock_check = NOW(),
    updated_at = NOW()
  WHERE id = p_product_id AND shop_id = p_shop_id;

  -- Log to audit trail
  INSERT INTO inventory_audit_log (
    product_id, shop_id, mutation_type, quantity_change,
    available_before, available_after,
    reserved_before, reserved_after,
    sold_before, sold_after,
    triggered_by, order_id, user_id, reason
  ) VALUES (
    p_product_id, p_shop_id, 'CONFIRM_SALE', p_quantity,
    v_product.available_stock, v_product.available_stock,
    v_product.reserved_stock, v_reserved_after,
    v_product.sold_stock, v_sold_after,
    'payment_success', p_order_id, p_user_id, p_reason
  );

  RETURN QUERY SELECT TRUE, 'Sale confirmed successfully'::TEXT,
    v_reserved_after, v_sold_after;
END;
$$ LANGUAGE plpgsql;

-- Procedure: Cancel reservation (reserved → available)
CREATE OR REPLACE FUNCTION cancel_product_reservation(
  p_product_id UUID,
  p_shop_id UUID,
  p_quantity INT,
  p_order_id UUID DEFAULT NULL,
  p_user_id UUID DEFAULT NULL,
  p_reason TEXT DEFAULT 'Order cancelled'
)
RETURNS TABLE (
  success BOOLEAN,
  error_message TEXT,
  available_stock INT,
  reserved_stock INT
) AS $$
DECLARE
  v_product RECORD;
  v_available_after INT;
  v_reserved_after INT;
BEGIN
  -- Lock row and read current state atomically
  SELECT * INTO v_product FROM products
  WHERE id = p_product_id AND shop_id = p_shop_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, 'Product not found'::TEXT, 0, 0;
    RETURN;
  END IF;

  -- Validate reserved stock
  IF v_product.reserved_stock < p_quantity THEN
    RETURN QUERY SELECT FALSE,
      'Cannot cancel: insufficient reserved stock',
      v_product.available_stock,
      v_product.reserved_stock;
    RETURN;
  END IF;

  -- Calculate new state
  v_available_after := v_product.available_stock + p_quantity;
  v_reserved_after := v_product.reserved_stock - p_quantity;

  -- Update products table
  UPDATE products
  SET
    available_stock = v_available_after,
    reserved_stock = v_reserved_after,
    last_stock_check = NOW(),
    updated_at = NOW()
  WHERE id = p_product_id AND shop_id = p_shop_id;

  -- Log to audit trail
  INSERT INTO inventory_audit_log (
    product_id, shop_id, mutation_type, quantity_change,
    available_before, available_after,
    reserved_before, reserved_after,
    sold_before, sold_after,
    triggered_by, order_id, user_id, reason
  ) VALUES (
    p_product_id, p_shop_id, 'CANCEL', p_quantity,
    v_product.available_stock, v_available_after,
    v_product.reserved_stock, v_reserved_after,
    v_product.sold_stock, v_product.sold_stock,
    'order_cancel', p_order_id, p_user_id, p_reason
  );

  RETURN QUERY SELECT TRUE, 'Reservation cancelled successfully'::TEXT,
    v_available_after, v_reserved_after;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 7: Enable RLS policies for inventory operations
-- ============================================================================

ALTER TABLE inventory_audit_log ENABLE ROW LEVEL SECURITY;

-- Policy: Customers can only view inventory logs for their own orders
CREATE POLICY "inventory_audit_log_customer_select" ON inventory_audit_log
  FOR SELECT USING (
    (SELECT shop_id FROM products WHERE id = product_id) IN (
      SELECT s.id FROM shops s
      WHERE s.owner_id = auth.uid()
    )
    OR
    order_id IN (
      SELECT id FROM orders WHERE customer_id = auth.uid()
    )
  );

-- Policy: Shop owners can view all inventory logs for their shop
CREATE POLICY "inventory_audit_log_owner_select" ON inventory_audit_log
  FOR SELECT USING (
    shop_id IN (
      SELECT id FROM shops WHERE owner_id = auth.uid()
    )
  );

-- ============================================================================
-- STEP 8: Migration verification and diagnostics
-- ============================================================================

-- Create function to verify inventory consistency
CREATE OR REPLACE FUNCTION verify_inventory_consistency()
RETURNS TABLE (
  product_id UUID,
  shop_id UUID,
  product_name TEXT,
  status TEXT,
  total_stock INT,
  available INT,
  reserved INT,
  sold INT,
  last_check TIMESTAMP
) AS $$
SELECT
  p.id,
  p.shop_id,
  p.name,
  CASE
    WHEN p.available_stock < 0 THEN 'ERROR: Negative available stock'
    WHEN p.reserved_stock < 0 THEN 'ERROR: Negative reserved stock'
    WHEN p.sold_stock < 0 THEN 'ERROR: Negative sold stock'
    WHEN (p.available_stock + p.reserved_stock + p.sold_stock) < 0 THEN 'ERROR: Invalid allocation'
    ELSE 'OK'
  END,
  (p.available_stock + p.reserved_stock + p.sold_stock),
  p.available_stock,
  p.reserved_stock,
  p.sold_stock,
  p.last_stock_check
FROM products p
WHERE p.is_active = true
ORDER BY p.shop_id, p.name;
$$ LANGUAGE sql;

-- ============================================================================
-- SUMMARY
-- ============================================================================
-- Added fields:
--   - available_stock (INT) - Can be ordered
--   - reserved_stock (INT) - Reserved during checkout, pending payment
--   - sold_stock (INT) - Confirmed after payment
--   - branch_stock (JSONB) - Multi-branch stock mapping
--   - branch_stock_map (JSONB) - Alternative stock mapping format
--   - minimum_stock (INT) - Reorder threshold (default 10)
--   - last_stock_check (TIMESTAMP) - Last inventory verification
--   - sku (VARCHAR) - Product SKU for identification
--
-- New tables:
--   - inventory_audit_log - Full audit trail of all mutations
--
-- New indexes:
--   - idx_products_shop_id
--   - idx_products_low_stock
--   - idx_products_sku
--   - idx_products_reserved
--   - idx_products_last_stock_check
--   - idx_audit_product, idx_audit_shop, idx_audit_order, etc.
--
-- New stored procedures:
--   - reserve_product_stock() - Atomic reserve operation with row locking
--   - confirm_product_sale() - Atomic confirm sale operation with row locking
--   - cancel_product_reservation() - Atomic cancel operation with row locking
--   - verify_inventory_consistency() - Diagnostic function
--
-- New views:
--   - v_inventory_consistency - Real-time inventory status
--
-- Constraints:
--   - All stock fields >= 0
--   - Total allocation consistency check
--
-- RLS Policies:
--   - Customers can view logs for their orders
--   - Owners can view all logs for their shop
--
-- ============================================================================
