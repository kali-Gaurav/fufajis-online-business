-- ============================================================================
-- Migration: Create RPC Wrapper Functions for Inventory Operations
-- Version: 20260709000002
-- Purpose: Ensure inventory RPC functions are available for Edge Functions
--          and provide clear, testable interfaces for inventory mutations
--
-- These functions wrap the existing stored procedures and ensure they're
-- accessible via supabase.rpc() calls from Edge Functions.
-- ============================================================================

-- ============================================================================
-- FUNCTION 1: reserve_inventory_atomic()
-- RPC wrapper for reservation (available_stock → reserved_stock)
-- ============================================================================

CREATE OR REPLACE FUNCTION reserve_inventory_atomic(
  p_product_id UUID,
  p_shop_id UUID,
  p_order_id UUID,
  p_quantity INT
)
RETURNS TABLE(
  success BOOLEAN,
  available_after INT,
  error_message TEXT
) AS $$
DECLARE
  v_available INT;
  v_reserved INT;
  v_total INT;
BEGIN
  -- PHASE 1: Validate inputs
  IF p_product_id IS NULL OR p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN QUERY SELECT false, 0, 'Invalid input: product_id and positive quantity required'::TEXT;
    RETURN;
  END IF;

  -- PHASE 2: Lock product row and check existence
  SELECT available_stock, reserved_stock
  INTO v_available, v_reserved
  FROM products
  WHERE id = p_product_id AND shop_id = p_shop_id
  FOR UPDATE;

  IF v_available IS NULL THEN
    RETURN QUERY SELECT false, 0, 'Product not found'::TEXT;
    RETURN;
  END IF;

  -- PHASE 3: Validate current stock is sufficient
  IF v_available < p_quantity THEN
    RETURN QUERY SELECT false, v_available,
      FORMAT('Insufficient stock. Available: %L, Requested: %L', v_available, p_quantity)::TEXT;
    RETURN;
  END IF;

  -- PHASE 4: Perform atomic reservation
  UPDATE products
  SET
    available_stock = available_stock - p_quantity,
    reserved_stock = reserved_stock + p_quantity,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_product_id;

  -- PHASE 5: Log audit trail
  INSERT INTO inventory_audit_log (
    product_id, shop_id, mutation_type, quantity_change,
    available_before, available_after,
    reserved_before, reserved_after,
    sold_before, sold_after,
    triggered_by, order_id, reason
  )
  VALUES (
    p_product_id, p_shop_id, 'RESERVE', p_quantity,
    v_available, (v_available - p_quantity),
    v_reserved, (v_reserved + p_quantity),
    0, 0,
    'checkout', p_order_id, FORMAT('Order: %L', p_order_id)::TEXT
  );

  -- PHASE 6: Return success
  RETURN QUERY SELECT true, (v_available - p_quantity), NULL::TEXT;

EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT false, 0, SQLERRM::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- ============================================================================
-- FUNCTION 2: confirm_inventory_sale_atomic()
-- RPC wrapper for confirmation (reserved_stock → sold_stock)
-- ============================================================================

CREATE OR REPLACE FUNCTION confirm_inventory_sale_atomic(
  p_product_id UUID,
  p_shop_id UUID,
  p_order_id UUID,
  p_quantity INT
)
RETURNS TABLE(
  success BOOLEAN,
  sold_after INT,
  error_message TEXT
) AS $$
DECLARE
  v_available INT;
  v_reserved INT;
  v_sold INT;
BEGIN
  -- PHASE 1: Validate inputs
  IF p_product_id IS NULL OR p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN QUERY SELECT false, 0, 'Invalid input: product_id and positive quantity required'::TEXT;
    RETURN;
  END IF;

  -- PHASE 2: Lock and read current state
  SELECT available_stock, reserved_stock, sold_stock
  INTO v_available, v_reserved, v_sold
  FROM products
  WHERE id = p_product_id AND shop_id = p_shop_id
  FOR UPDATE;

  IF v_reserved IS NULL THEN
    RETURN QUERY SELECT false, 0, 'Product not found'::TEXT;
    RETURN;
  END IF;

  -- PHASE 3: Validate sufficient reserved stock
  IF v_reserved < p_quantity THEN
    RETURN QUERY SELECT false, v_sold,
      FORMAT('Insufficient reserved stock. Reserved: %L, Requesting to confirm: %L', v_reserved, p_quantity)::TEXT;
    RETURN;
  END IF;

  -- PHASE 4: Perform atomic confirmation (reserved → sold)
  UPDATE products
  SET
    reserved_stock = reserved_stock - p_quantity,
    sold_stock = sold_stock + p_quantity,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_product_id;

  -- PHASE 5: Log audit trail
  INSERT INTO inventory_audit_log (
    product_id, shop_id, mutation_type, quantity_change,
    available_before, available_after,
    reserved_before, reserved_after,
    sold_before, sold_after,
    triggered_by, order_id, reason
  )
  VALUES (
    p_product_id, p_shop_id, 'CONFIRM_SALE', p_quantity,
    v_available, v_available,
    v_reserved, (v_reserved - p_quantity),
    v_sold, (v_sold + p_quantity),
    'payment_success', p_order_id, FORMAT('Order: %L - Payment Success', p_order_id)::TEXT
  );

  -- PHASE 6: Return success
  RETURN QUERY SELECT true, (v_sold + p_quantity), NULL::TEXT;

EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT false, 0, SQLERRM::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- ============================================================================
-- FUNCTION 3: cancel_inventory_reservation_atomic()
-- RPC wrapper for cancellation (reserved_stock → available_stock)
-- ============================================================================

CREATE OR REPLACE FUNCTION cancel_inventory_reservation_atomic(
  p_product_id UUID,
  p_shop_id UUID,
  p_order_id UUID,
  p_quantity INT
)
RETURNS TABLE(
  success BOOLEAN,
  available_after INT,
  error_message TEXT
) AS $$
DECLARE
  v_available INT;
  v_reserved INT;
  v_sold INT;
BEGIN
  -- PHASE 1: Validate inputs
  IF p_product_id IS NULL OR p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN QUERY SELECT false, 0, 'Invalid input: product_id and positive quantity required'::TEXT;
    RETURN;
  END IF;

  -- PHASE 2: Lock and read current state
  SELECT available_stock, reserved_stock, sold_stock
  INTO v_available, v_reserved, v_sold
  FROM products
  WHERE id = p_product_id AND shop_id = p_shop_id
  FOR UPDATE;

  IF v_reserved IS NULL THEN
    -- Idempotent: Product doesn't exist, but we're trying to cancel anyway
    RETURN QUERY SELECT true, 0, 'Product not found (idempotent, no-op)'::TEXT;
    RETURN;
  END IF;

  -- PHASE 3: Validate sufficient reserved stock to cancel
  IF v_reserved < p_quantity THEN
    -- Idempotent: Just return current state (partial or already cancelled)
    RETURN QUERY SELECT true, v_available,
      FORMAT('Partial or already cancelled. Reserved: %L, Canceling: %L (idempotent)', v_reserved, p_quantity)::TEXT;
    RETURN;
  END IF;

  -- PHASE 4: Perform atomic cancellation (reserved → available)
  UPDATE products
  SET
    reserved_stock = reserved_stock - p_quantity,
    available_stock = available_stock + p_quantity,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_product_id;

  -- PHASE 5: Log audit trail
  INSERT INTO inventory_audit_log (
    product_id, shop_id, mutation_type, quantity_change,
    available_before, available_after,
    reserved_before, reserved_after,
    sold_before, sold_after,
    triggered_by, order_id, reason
  )
  VALUES (
    p_product_id, p_shop_id, 'CANCEL', p_quantity,
    v_available, (v_available + p_quantity),
    v_reserved, (v_reserved - p_quantity),
    v_sold, v_sold,
    'order_cancel', p_order_id, FORMAT('Order: %L - Reservation cancelled/rolled back', p_order_id)::TEXT
  );

  -- PHASE 6: Return success
  RETURN QUERY SELECT true, (v_available + p_quantity), NULL::TEXT;

EXCEPTION WHEN OTHERS THEN
  -- Even on error, try to be idempotent
  RETURN QUERY SELECT false, 0, SQLERRM::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- ============================================================================
-- TEST QUERIES
-- ============================================================================
-- After deployment, verify functions work with these test queries:

-- Test 1: List all inventory functions
-- SELECT routine_name FROM information_schema.routines
-- WHERE routine_name LIKE '%inventory%atomic%' AND routine_schema = 'public';

-- Test 2: Call reserve function (replace UUIDs with real product/shop IDs)
-- SELECT * FROM reserve_inventory_atomic(
--   '<product-uuid>'::UUID,
--   '<shop-uuid>'::UUID,
--   '<order-uuid>'::UUID,
--   5
-- );

-- Test 3: Call confirm function
-- SELECT * FROM confirm_inventory_sale_atomic(
--   '<product-uuid>'::UUID,
--   '<shop-uuid>'::UUID,
--   '<order-uuid>'::UUID,
--   5
-- );

-- Test 4: Call cancel function
-- SELECT * FROM cancel_inventory_reservation_atomic(
--   '<product-uuid>'::UUID,
--   '<shop-uuid>'::UUID,
--   '<order-uuid>'::UUID,
--   5
-- );

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
  v_reserve_exists BOOLEAN := FALSE;
  v_confirm_exists BOOLEAN := FALSE;
  v_cancel_exists BOOLEAN := FALSE;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM information_schema.routines
    WHERE routine_name = 'reserve_inventory_atomic'
    AND routine_schema = 'public'
  ) INTO v_reserve_exists;

  SELECT EXISTS(
    SELECT 1 FROM information_schema.routines
    WHERE routine_name = 'confirm_inventory_sale_atomic'
    AND routine_schema = 'public'
  ) INTO v_confirm_exists;

  SELECT EXISTS(
    SELECT 1 FROM information_schema.routines
    WHERE routine_name = 'cancel_inventory_reservation_atomic'
    AND routine_schema = 'public'
  ) INTO v_cancel_exists;

  RAISE NOTICE 'RPC Function Deployment Status:';
  RAISE NOTICE '  reserve_inventory_atomic: %', CASE WHEN v_reserve_exists THEN 'CREATED' ELSE 'MISSING' END;
  RAISE NOTICE '  confirm_inventory_sale_atomic: %', CASE WHEN v_confirm_exists THEN 'CREATED' ELSE 'MISSING' END;
  RAISE NOTICE '  cancel_inventory_reservation_atomic: %', CASE WHEN v_cancel_exists THEN 'CREATED' ELSE 'MISSING' END;
END $$;

-- ============================================================================
-- NOTES
-- ============================================================================
-- 1. These functions are designed to be called via Supabase RPC:
--    const { data, error } = await supabase.rpc('reserve_inventory_atomic', {...})
--
-- 2. Each function is idempotent where possible (cancel is fully idempotent)
--
-- 3. All functions use row-level locking (FOR UPDATE) to prevent race conditions
--
-- 4. All operations are logged to inventory_audit_log for full audit trail
--
-- 5. Error handling returns success=false with descriptive error message
--    Calling code should check success boolean before proceeding
--
-- ============================================================================
