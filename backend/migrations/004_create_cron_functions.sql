-- ============================================================================
-- Migration 004: Create Cron Job Functions
-- ============================================================================
-- SQL functions that Supabase Cron will call

-- ─────────────────────────────────────────────────────────────────────────
-- Function: process_due_subscriptions()
-- Called by Cron daily at 00:00 UTC
-- Creates orders for subscriptions with next_delivery_date <= today
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION process_due_subscriptions()
RETURNS TABLE(subscription_id UUID, status VARCHAR, message TEXT) AS $$
DECLARE
  sub RECORD;
  order_id UUID;
  reservation_id UUID;
BEGIN
  FOR sub IN
    SELECT id, customer_id, total_amount, items_count, delivery_address_id
    FROM subscriptions
    WHERE status = 'active'
      AND next_delivery_date::date <= CURRENT_DATE
    LIMIT 100
  LOOP
    BEGIN
      -- Create order from subscription
      INSERT INTO orders (
        id, customer_id, total_amount, items_count,
        delivery_address_id, payment_status, order_status,
        subscription_id, created_at, updated_at
      ) VALUES (
        gen_random_uuid(), sub.customer_id, sub.total_amount, sub.items_count,
        sub.delivery_address_id, 'auto_charged', 'pending_confirmation',
        sub.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      );

      -- Update next_delivery_date based on frequency
      UPDATE subscriptions
      SET next_delivery_date = CASE
        WHEN frequency = 'daily' THEN next_delivery_date + INTERVAL '1 day'
        WHEN frequency = 'weekly' THEN next_delivery_date + INTERVAL '7 days'
        WHEN frequency = 'monthly' THEN next_delivery_date + INTERVAL '1 month'
        ELSE next_delivery_date
      END,
      updated_at = CURRENT_TIMESTAMP
      WHERE id = sub.id;

      RETURN QUERY SELECT sub.id, 'success'::VARCHAR, 'Order created'::TEXT;
    EXCEPTION WHEN OTHERS THEN
      RETURN QUERY SELECT sub.id, 'failed'::VARCHAR, SQLERRM::TEXT;
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────────────────────
-- Function: calculate_daily_commissions()
-- Called by Cron daily at 01:00 UTC
-- Calculates commissions for orders paid yesterday
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION calculate_daily_commissions()
RETURNS TABLE(order_id UUID, commission_id UUID, vendor_payout DECIMAL) AS $$
DECLARE
  ord RECORD;
  com_id UUID;
  payout DECIMAL;
  platform_fee DECIMAL;
  gateway_fee DECIMAL;
BEGIN
  FOR ord IN
    SELECT id, vendor_id, customer_id, total_amount
    FROM orders
    WHERE DATE(created_at) = CURRENT_DATE - INTERVAL '1 day'
      AND payment_status = 'completed'
      AND commission_status IS NULL
    LIMIT 500
  LOOP
    BEGIN
      -- Calculate fees
      platform_fee := (ord.total_amount * 5) / 100;
      gateway_fee := (ord.total_amount * 2.5) / 100;
      payout := ord.total_amount - platform_fee - gateway_fee;

      -- Create commission record
      INSERT INTO vendor_commissions (
        id, order_id, vendor_id, customer_id,
        order_total, platform_fee, payment_gateway_fee,
        vendor_payout, status, created_at, updated_at
      ) VALUES (
        gen_random_uuid(), ord.id, ord.vendor_id, ord.customer_id,
        ord.total_amount, platform_fee, gateway_fee,
        payout, 'pending', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      ) RETURNING id INTO com_id;

      -- Update order commission status
      UPDATE orders SET commission_status = 'calculated' WHERE id = ord.id;

      -- Update vendor balance
      UPDATE vendors
      SET balance = balance + payout,
          balance_updated = CURRENT_TIMESTAMP,
          total_commissions_due = total_commissions_due + payout
      WHERE id = ord.vendor_id;

      RETURN QUERY SELECT ord.id, com_id, payout;
    EXCEPTION WHEN OTHERS THEN
      RETURN QUERY SELECT ord.id, NULL::UUID, NULL::DECIMAL;
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────────────────────
-- Function: cleanup_expired_reservations()
-- Called by Cron every 30 minutes
-- Releases inventory from expired reservations (24 hour expiry)
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION cleanup_expired_reservations()
RETURNS TABLE(reservation_id UUID, status VARCHAR, released_qty INT) AS $$
DECLARE
  res RECORD;
  total_qty INT;
BEGIN
  FOR res IN
    SELECT id, status FROM reservations
    WHERE status IN ('active', 'pending')
      AND expires_at < CURRENT_TIMESTAMP
    LIMIT 100
  LOOP
    BEGIN
      -- Sum up quantities to release
      SELECT COALESCE(SUM(quantity), 0)
      INTO total_qty
      FROM reservation_items
      WHERE reservation_id = res.id;

      -- Update reservation as expired
      UPDATE reservations
      SET status = 'expired', updated_at = CURRENT_TIMESTAMP
      WHERE id = res.id;

      -- Release inventory
      UPDATE products
      SET available_stock = available_stock + total_qty,
          reserved_stock = GREATEST(0, reserved_stock - total_qty),
          updated_at = CURRENT_TIMESTAMP
      FROM reservation_items
      WHERE reservation_items.reservation_id = res.id
        AND products.id = reservation_items.product_id;

      RETURN QUERY SELECT res.id, 'expired'::VARCHAR, total_qty;
    EXCEPTION WHEN OTHERS THEN
      RETURN QUERY SELECT res.id, 'failed'::VARCHAR, 0::INT;
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────────────────────
-- Function: reconcile_stale_payments()
-- Called by Cron hourly at minute 0
-- Reconciles payments that may have failed silently
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION reconcile_stale_payments()
RETURNS TABLE(order_id UUID, status VARCHAR, action TEXT) AS $$
BEGIN
  -- Find orders still pending payment after 24 hours
  RETURN QUERY
  UPDATE orders
  SET payment_status = 'failed',
      order_status = 'cancelled',
      updated_at = CURRENT_TIMESTAMP
  WHERE order_status = 'pending_payment'
    AND created_at < CURRENT_TIMESTAMP - INTERVAL '24 hours'
    AND payment_status = 'pending'
  RETURNING id, 'auto_failed'::VARCHAR, 'Stale payment cancelled'::TEXT;

  -- Could also trigger refunds or notifications here
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────────────────────
-- Function: sync_to_firestore_trigger()
-- Called by Database Webhooks when orders/subscriptions change
-- Prepares data for Firestore sync
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION sync_to_firestore_trigger()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert sync event into queue for backend to process
  INSERT INTO firestore_sync_queue (
    id, table_name, record_id, operation, payload,
    status, created_at
  ) VALUES (
    gen_random_uuid(),
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    TG_OP,
    COALESCE(row_to_json(NEW), row_to_json(OLD)),
    'pending',
    CURRENT_TIMESTAMP
  );

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create queue table for webhook events
CREATE TABLE IF NOT EXISTS firestore_sync_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name VARCHAR(100) NOT NULL,
  record_id UUID NOT NULL,
  operation VARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
  payload JSONB,
  status VARCHAR(50) DEFAULT 'pending', -- pending, synced, failed
  retry_count INT DEFAULT 0,
  error_message TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  synced_at TIMESTAMP
);

CREATE INDEX idx_firestore_sync_queue_status ON firestore_sync_queue(status);
CREATE INDEX idx_firestore_sync_queue_table_name ON firestore_sync_queue(table_name);
