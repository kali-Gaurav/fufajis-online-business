-- Checkout System Schema
-- Parent: checkout_sessions (initiated → inventory_reserved → payment_pending → payment_success → completed)
-- Child: reservations (active → confirmed → released → expired)
-- Grandchild: reservation_items (per-item tracking)

-- CHECKOUT_SESSIONS: Parent tracking object
CREATE TABLE IF NOT EXISTS checkout_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL,
  shop_id UUID NOT NULL,
  -- Lifecycle status
  status VARCHAR(50) DEFAULT 'initiated',  -- initiated, inventory_reserved, payment_pending, payment_success, completed, failed, expired
  -- Financial snapshot
  subtotal DECIMAL(10, 2) NOT NULL,
  discount_amount DECIMAL(10, 2) DEFAULT 0,
  delivery_fee DECIMAL(10, 2) DEFAULT 0,
  total_amount DECIMAL(10, 2) NOT NULL,
  -- Payment reference
  razorpay_order_id VARCHAR(100),
  -- Metadata
  coupon_code VARCHAR(100),
  delivery_address_id UUID,
  notes TEXT,
  -- Timestamps
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP,
  completed_at TIMESTAMP,
  -- Idempotency
  idempotency_key VARCHAR(255) UNIQUE
);

CREATE INDEX idx_checkout_sessions_customer ON checkout_sessions(customer_id);
CREATE INDEX idx_checkout_sessions_shop ON checkout_sessions(shop_id);
CREATE INDEX idx_checkout_sessions_status ON checkout_sessions(status);
CREATE INDEX idx_checkout_sessions_razorpay ON checkout_sessions(razorpay_order_id);
CREATE INDEX idx_checkout_sessions_expires ON checkout_sessions(expires_at) WHERE status IN ('initiated', 'payment_pending');

-- RESERVATIONS: Stock reservation tracking
CREATE TABLE IF NOT EXISTS reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  checkout_session_id UUID NOT NULL REFERENCES checkout_sessions(id) ON DELETE CASCADE,
  order_id UUID,  -- Linked after payment success
  customer_id UUID NOT NULL,
  shop_id UUID NOT NULL,
  -- Lifecycle
  status VARCHAR(50) DEFAULT 'active',  -- active, confirmed, released, expired
  -- Metadata
  total_items INT NOT NULL,
  -- Timestamps
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,  -- 10 minutes from creation
  confirmed_at TIMESTAMP,
  released_at TIMESTAMP
);

CREATE INDEX idx_reservations_checkout_session ON reservations(checkout_session_id);
CREATE INDEX idx_reservations_order ON reservations(order_id);
CREATE INDEX idx_reservations_customer ON reservations(customer_id);
CREATE INDEX idx_reservations_status ON reservations(status);
CREATE INDEX idx_reservations_expires ON reservations(expires_at) WHERE status = 'active';

-- RESERVATION_ITEMS: Per-item tracking within reservation
CREATE TABLE IF NOT EXISTS reservation_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id UUID NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
  product_id UUID NOT NULL,
  quantity INT NOT NULL,
  price_per_unit DECIMAL(10, 2) NOT NULL,
  subtotal DECIMAL(10, 2) NOT NULL,  -- quantity * price_per_unit
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_reservation_items_reservation ON reservation_items(reservation_id);
CREATE INDEX idx_reservation_items_product ON reservation_items(product_id);

-- FUNCTION: Mark reservation as expired (called by cleanup cron)
CREATE OR REPLACE FUNCTION expire_stale_reservations()
RETURNS int AS $$
DECLARE
  expired_count INT;
BEGIN
  -- Find all active reservations that have expired
  WITH expired_reservations AS (
    SELECT id, checkout_session_id
    FROM reservations
    WHERE status = 'active'
      AND expires_at <= CURRENT_TIMESTAMP
  )
  UPDATE reservations
  SET status = 'expired', released_at = CURRENT_TIMESTAMP
  WHERE id IN (SELECT id FROM expired_reservations);

  GET DIAGNOSTICS expired_count = ROW_COUNT;
  RAISE NOTICE 'Expired % stale reservations', expired_count;

  RETURN expired_count;
END;
$$ LANGUAGE plpgsql;

-- FUNCTION: Release reserved stock back to available pool
-- Called when reservation is released or expired
CREATE OR REPLACE FUNCTION release_reserved_stock(reservation_id UUID)
RETURNS VOID AS $$
BEGIN
  -- Update products table: return reserved stock to available
  UPDATE products p
  SET
    available_quantity = available_quantity + ri.quantity,
    reserved_quantity = reserved_quantity - ri.quantity
  FROM reservation_items ri
  WHERE ri.reservation_id = $1
    AND p.id = ri.product_id;

  -- Mark reservation as released
  UPDATE reservations
  SET status = 'released', released_at = CURRENT_TIMESTAMP
  WHERE id = $1 AND status != 'released';
END;
$$ LANGUAGE plpgsql;

-- FUNCTION: Confirm reservation (after successful payment)
-- Moves reservation from 'active' to 'confirmed' status
CREATE OR REPLACE FUNCTION confirm_reservation(
  reservation_id UUID,
  order_id UUID
)
RETURNS VOID AS $$
BEGIN
  UPDATE reservations
  SET
    status = 'confirmed',
    order_id = $2,
    confirmed_at = CURRENT_TIMESTAMP
  WHERE id = $1;
END;
$$ LANGUAGE plpgsql;

-- View for quick reservation status
CREATE OR REPLACE VIEW reservation_status_view AS
SELECT
  r.id,
  r.checkout_session_id,
  r.order_id,
  r.customer_id,
  r.status,
  r.total_items,
  COUNT(ri.id) as item_count,
  SUM(ri.quantity) as reserved_quantity,
  SUM(ri.subtotal) as total_reserved_value,
  r.expires_at,
  (r.expires_at <= CURRENT_TIMESTAMP AND r.status = 'active') as is_expired
FROM reservations r
LEFT JOIN reservation_items ri ON r.id = ri.reservation_id
GROUP BY r.id, r.checkout_session_id, r.order_id, r.customer_id, r.status, r.total_items, r.expires_at;
