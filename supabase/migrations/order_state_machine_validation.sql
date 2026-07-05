-- P0 FIX: Enforce order state machine on server (not just client)
-- Prevents invalid state transitions like:
-- - shipped → confirmed (invalid)
-- - delivered → processing (invalid)
-- - completed → cancelled (invalid)

CREATE TABLE order_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  value TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Insert valid statuses
INSERT INTO order_status (value) VALUES
  ('pending'),
  ('confirmed'),
  ('processing'),
  ('packed'),
  ('shipped'),
  ('out_for_delivery'),
  ('delivered'),
  ('completed'),
  ('cancelled'),
  ('returned'),
  ('refunded');

-- Table for valid state transitions
CREATE TABLE order_state_transitions (
  from_status TEXT NOT NULL,
  to_status TEXT NOT NULL,
  PRIMARY KEY (from_status, to_status),
  FOREIGN KEY (from_status) REFERENCES order_status(value),
  FOREIGN KEY (to_status) REFERENCES order_status(value)
);

-- Define valid transitions
INSERT INTO order_state_transitions (from_status, to_status) VALUES
  -- pending → confirmed OR cancelled
  ('pending', 'confirmed'),
  ('pending', 'cancelled'),

  -- confirmed → processing OR cancelled
  ('confirmed', 'processing'),
  ('confirmed', 'cancelled'),

  -- processing → packed OR cancelled
  ('processing', 'packed'),
  ('processing', 'cancelled'),

  -- packed → shipped OR out_for_delivery OR cancelled
  ('packed', 'shipped'),
  ('packed', 'out_for_delivery'),
  ('packed', 'cancelled'),

  -- shipped → delivered OR cancelled
  ('shipped', 'delivered'),
  ('shipped', 'cancelled'),

  -- out_for_delivery → delivered OR cancelled
  ('out_for_delivery', 'delivered'),
  ('out_for_delivery', 'cancelled'),

  -- delivered → refunded OR cancelled OR returned OR completed
  ('delivered', 'refunded'),
  ('delivered', 'cancelled'),
  ('delivered', 'returned'),
  ('delivered', 'completed'),

  -- completed → refunded OR cancelled OR returned
  ('completed', 'refunded'),
  ('completed', 'cancelled'),
  ('completed', 'returned'),

  -- cancelled → refunded only
  ('cancelled', 'refunded'),

  -- returned → refunded only
  ('returned', 'refunded');

-- Stored procedure to validate and update order status
CREATE OR REPLACE FUNCTION update_order_status_validated(
  p_order_id UUID,
  p_current_status TEXT,
  p_new_status TEXT
)
RETURNS TABLE (
  success BOOLEAN,
  error_message TEXT,
  new_status TEXT
) AS $$
DECLARE
  v_valid_transition BOOLEAN;
  v_is_terminal BOOLEAN;
BEGIN
  -- SECURITY: Verify transition is valid
  SELECT EXISTS (
    SELECT 1 FROM order_state_transitions
    WHERE from_status = p_current_status
    AND to_status = p_new_status
  ) INTO v_valid_transition;

  IF NOT v_valid_transition THEN
    RETURN QUERY SELECT FALSE,
      'Invalid state transition: ' || p_current_status || ' → ' || p_new_status,
      p_current_status;
    RETURN;
  END IF;

  -- Check if destination is terminal (no further transitions)
  IF p_new_status IN ('completed', 'cancelled', 'refunded') THEN
    v_is_terminal := TRUE;
  ELSE
    v_is_terminal := FALSE;
  END IF;

  -- Update order status atomically
  UPDATE orders
  SET
    status = p_new_status,
    updated_at = NOW(),
    is_terminal = v_is_terminal
  WHERE id = p_order_id
  AND status = p_current_status;  -- Optimistic lock: only update if status matches

  IF FOUND THEN
    -- Log state transition for audit
    INSERT INTO order_status_history (order_id, from_status, to_status, changed_at)
    VALUES (p_order_id, p_current_status, p_new_status, NOW());

    RETURN QUERY SELECT TRUE, 'Order status updated successfully', p_new_status;
  ELSE
    RETURN QUERY SELECT FALSE,
      'Order status mismatch. Expected: ' || p_current_status,
      p_current_status;
  END IF;

EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT FALSE, 'Error updating order: ' || SQLERRM, p_current_status;
END;
$$ LANGUAGE plpgsql;

-- Audit table to track all status changes
CREATE TABLE IF NOT EXISTS order_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id),
  from_status TEXT NOT NULL,
  to_status TEXT NOT NULL,
  changed_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_order_status_history_order_id ON order_status_history(order_id);
