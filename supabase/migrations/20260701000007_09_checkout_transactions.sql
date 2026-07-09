-- Function to process a checkout safely within a transaction
CREATE OR REPLACE FUNCTION process_checkout(
  p_user_id UUID,
  p_items JSONB,
  p_address JSONB,
  p_subtotal NUMERIC,
  p_tax NUMERIC,
  p_delivery_fee NUMERIC,
  p_total NUMERIC
) RETURNS JSONB AS $$
DECLARE
  v_order_id UUID;
  v_item JSONB;
  v_product RECORD;
BEGIN
  -- Insert the order
  INSERT INTO orders (
    user_id, items, delivery_address, subtotal, tax, delivery_fee, total, status, created_at
  ) VALUES (
    p_user_id, p_items, p_address, p_subtotal, p_tax, p_delivery_fee, p_total, 'pending_payment', NOW()
  ) RETURNING id INTO v_order_id;

  -- Return the new order as JSON
  RETURN (
    SELECT row_to_json(o)
    FROM orders o
    WHERE o.id = v_order_id
  );
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Checkout failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;
