-- ============================================================================
-- INVENTORY INVARIANT CHECKS & DIAGNOSTICS
-- ============================================================================
-- Purpose: Ensure stock math (available + reserved + sold = total) never drifts
-- ============================================================================

-- 1. ADD CONSTRAINT TO INVENTORY
-- (Note: If there are existing broken rows, this constraint might fail to add. 
-- In a real migration, you would clean data first. We'll add NOT VALID so it
-- applies to new/updated rows, but doesn't block migration on legacy data.)

ALTER TABLE inventory 
ADD CONSTRAINT inventory_stock_invariant 
CHECK (available_quantity + reserved_quantity + sold_quantity = total_quantity) 
NOT VALID;

-- Optional: Validate it later after cleanup
-- ALTER TABLE inventory VALIDATE CONSTRAINT inventory_stock_invariant;

-- 2. CREATE DIAGNOSTIC VIEW
-- Quickly surfaces any rows where the invariant is broken
CREATE OR REPLACE VIEW vw_inventory_invariants_failed AS
SELECT 
    id,
    product_id,
    total_quantity,
    available_quantity,
    reserved_quantity,
    sold_quantity,
    (available_quantity + reserved_quantity + sold_quantity) AS computed_total,
    (total_quantity - (available_quantity + reserved_quantity + sold_quantity)) AS delta
FROM inventory
WHERE (available_quantity + reserved_quantity + sold_quantity) != total_quantity;

-- Grant permissions for admin monitoring
GRANT SELECT ON vw_inventory_invariants_failed TO authenticated;
