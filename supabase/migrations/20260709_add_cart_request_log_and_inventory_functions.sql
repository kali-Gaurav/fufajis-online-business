-- Migration: Add cart_request_log table and inventory RPC functions for FIX #1 & #2
-- Date: 2026-07-09

-- FIX #2: Request logging for idempotent cart updates
CREATE TABLE IF NOT EXISTS public.cart_request_log (
  id BIGSERIAL PRIMARY KEY,
  item_id TEXT NOT NULL,
  request_version INTEGER NOT NULL,
  processed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

  UNIQUE(item_id, request_version)
);

CREATE INDEX IF NOT EXISTS idx_cart_request_log_item_version
  ON public.cart_request_log(item_id, request_version);

CREATE INDEX IF NOT EXISTS idx_cart_request_log_processed_at
  ON public.cart_request_log(processed_at);

-- FIX #1: Atomic inventory update for checkout (reserves stock)
CREATE OR REPLACE FUNCTION public.update_inventory_for_checkout(
  p_product_id TEXT,
  p_quantity INTEGER
)
RETURNS VOID AS $$
BEGIN
  UPDATE public.inventory
  SET
    available_stock = available_stock - p_quantity,
    reserved_stock = reserved_stock + p_quantity,
    updated_at = NOW()
  WHERE product_id = p_product_id
    AND available_stock >= p_quantity;

  -- Raise error if update didn't happen (insufficient stock)
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Insufficient stock for product %', p_product_id;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- FIX #1: Rollback inventory reservation (used on checkout failure)
CREATE OR REPLACE FUNCTION public.rollback_inventory_reservation(
  p_product_id TEXT,
  p_quantity INTEGER
)
RETURNS VOID AS $$
BEGIN
  UPDATE public.inventory
  SET
    reserved_stock = GREATEST(0, reserved_stock - p_quantity),
    available_stock = available_stock + p_quantity,
    updated_at = NOW()
  WHERE product_id = p_product_id;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.update_inventory_for_checkout(TEXT, INTEGER) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rollback_inventory_reservation(TEXT, INTEGER) TO anon, authenticated;

-- Row-level security for cart_request_log
ALTER TABLE public.cart_request_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY cart_request_log_insert_own ON public.cart_request_log
  FOR INSERT WITH CHECK (true);

CREATE POLICY cart_request_log_select_own ON public.cart_request_log
  FOR SELECT USING (true);
