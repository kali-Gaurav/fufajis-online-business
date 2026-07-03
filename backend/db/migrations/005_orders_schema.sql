-- Orders Table Schema Modifications
-- Links orders to checkout_sessions and reservations
-- Adds payment references for end-to-end tracking

ALTER TABLE orders ADD COLUMN IF NOT EXISTS checkout_session_id UUID REFERENCES checkout_sessions(id);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS reservation_id UUID REFERENCES reservations(id);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_order_id VARCHAR(100);  -- Razorpay order ID

-- Indexes for fast lookups during payment processing
CREATE INDEX IF NOT EXISTS idx_orders_checkout_session ON orders(checkout_session_id);
CREATE INDEX IF NOT EXISTS idx_orders_reservation ON orders(reservation_id);
CREATE INDEX IF NOT EXISTS idx_orders_payment_order_id ON orders(payment_order_id);

-- Constraint: payment_order_id should be unique (prevent duplicate payment orders)
ALTER TABLE orders ADD CONSTRAINT unique_payment_order_id UNIQUE (payment_order_id);

-- View: Full order context with checkout + reservation details
CREATE OR REPLACE VIEW order_context_view AS
SELECT
  o.id as order_id,
  o.status as order_status,
  o.customer_id,
  o.shop_id,
  -- Checkout context
  cs.id as checkout_session_id,
  cs.status as checkout_status,
  cs.razorpay_order_id,
  cs.total_amount,
  -- Reservation context
  r.id as reservation_id,
  r.status as reservation_status,
  r.expires_at as reservation_expires_at,
  -- Payment references
  o.payment_order_id,
  -- Audit
  o.created_at as order_created_at,
  cs.created_at as checkout_created_at,
  r.confirmed_at as reservation_confirmed_at
FROM orders o
LEFT JOIN checkout_sessions cs ON o.checkout_session_id = cs.id
LEFT JOIN reservations r ON o.reservation_id = r.id;

-- Function: Reconcile order state with reservation state
-- Used by background job to fix stale orders
CREATE OR REPLACE FUNCTION reconcile_order_state(order_id UUID)
RETURNS TABLE(order_status varchar, reservation_status varchar, action_needed varchar) AS $$
BEGIN
  RETURN QUERY
  SELECT
    o.status,
    r.status,
    CASE
      WHEN r.status = 'expired' AND o.status IN ('pending', 'confirmed') THEN 'CANCEL_ORDER'
      WHEN o.status = 'completed' AND r.status IN ('active', 'released') THEN 'CONFIRM_RESERVATION'
      WHEN o.status IN ('cancelled', 'failed') AND r.status = 'active' THEN 'RELEASE_RESERVATION'
      ELSE 'OK'
    END as action_needed
  FROM orders o
  LEFT JOIN reservations r ON o.reservation_id = r.id
  WHERE o.id = $1;
END;
$$ LANGUAGE plpgsql;

-- Function: Get order payment status from Razorpay
-- This queries Razorpay API to sync payment state (called during reconciliation)
-- Implementation assumes integration with razorpay-service.js
CREATE OR REPLACE FUNCTION get_order_payment_status(order_id UUID)
RETURNS TABLE(
  order_id uuid,
  razorpay_order_id varchar,
  payment_order_id varchar,
  current_status varchar,
  razorpay_status varchar
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    o.id,
    cs.razorpay_order_id,
    o.payment_order_id,
    o.status,
    NULL::varchar as razorpay_status  -- Populated by backend app via Razorpay API
  FROM orders o
  LEFT JOIN checkout_sessions cs ON o.checkout_session_id = cs.id
  WHERE o.id = $1;
END;
$$ LANGUAGE plpgsql;
