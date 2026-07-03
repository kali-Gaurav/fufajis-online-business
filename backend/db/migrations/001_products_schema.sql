-- Products Table Schema
-- Adds inventory management columns: reserved_quantity and available_quantity
-- CRITICAL: available_quantity is stored (not derived) and updated atomically

ALTER TABLE products ADD COLUMN IF NOT EXISTS reserved_quantity INT DEFAULT 0;
ALTER TABLE products ADD COLUMN IF NOT EXISTS available_quantity INT DEFAULT 0;

-- CRITICAL: Add constraints to prevent inventory corruption
-- These constraints are enforced at DB level, preventing any bug from corrupting stock
ALTER TABLE products ADD CONSTRAINT IF NOT EXISTS check_reserved_nonnegative
  CHECK (reserved_quantity >= 0);
ALTER TABLE products ADD CONSTRAINT IF NOT EXISTS check_available_nonnegative
  CHECK (available_quantity >= 0);
ALTER TABLE products ADD CONSTRAINT IF NOT EXISTS check_available_within_total
  CHECK (available_quantity <= total_quantity);
ALTER TABLE products ADD CONSTRAINT IF NOT EXISTS check_inventory_consistency
  CHECK (available_quantity + reserved_quantity <= total_quantity);

-- Create index on reserved + available for fast inventory lookups
CREATE INDEX IF NOT EXISTS idx_products_available ON products(available_quantity) WHERE available_quantity > 0;
CREATE INDEX IF NOT EXISTS idx_products_reserved ON products(reserved_quantity);

-- Constraint: available_quantity + reserved_quantity <= total_quantity
-- (Enforced at application level during checkout)

-- View for quick stock status check
CREATE OR REPLACE VIEW product_stock_status AS
SELECT
  id,
  name,
  shop_id,
  total_quantity,
  available_quantity,
  reserved_quantity,
  total_quantity - available_quantity - reserved_quantity AS committed_quantity,
  (available_quantity > 0) AS is_in_stock
FROM products;

-- Helper function to get available quantity without race conditions
CREATE OR REPLACE FUNCTION get_available_quantity(product_id UUID)
RETURNS INT AS $$
DECLARE
  available INT;
BEGIN
  SELECT available_quantity INTO available
  FROM products
  WHERE id = product_id
  FOR UPDATE;  -- Row lock

  RETURN COALESCE(available, 0);
END;
$$ LANGUAGE plpgsql;

-- Helper function to reserve inventory (atomic)
-- Returns: reservation_id if success, NULL if failed
CREATE OR REPLACE FUNCTION reserve_inventory(
  product_id UUID,
  quantity INT,
  OUT reservation_id UUID,
  OUT success BOOLEAN
) AS $$
BEGIN
  reservation_id := gen_random_uuid();

  -- Try to reserve stock atomically
  UPDATE products
  SET available_quantity = available_quantity - quantity,
      reserved_quantity = reserved_quantity + quantity
  WHERE id = product_id
    AND available_quantity >= quantity
  RETURNING id INTO product_id;

  success := (product_id IS NOT NULL);

  IF NOT success THEN
    reservation_id := NULL;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Log for audit trail (optional, for debugging)
CREATE TABLE IF NOT EXISTS inventory_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL,
  action VARCHAR(50),  -- 'reserve', 'confirm', 'release', 'expire'
  quantity INT,
  actor_id UUID,
  reason TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_inventory_audit_product ON inventory_audit_log(product_id);
CREATE INDEX idx_inventory_audit_created ON inventory_audit_log(created_at);
