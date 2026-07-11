-- ============================================================================
-- Setup Supabase Database Webhooks
-- ============================================================================
-- Run this in Supabase SQL Editor
-- These webhooks trigger Firestore sync when data changes

-- ─────────────────────────────────────────────────────────────────────────
-- WEBHOOK 1: Orders Table Changes
-- Triggers when orders are created, updated, or deleted
-- ─────────────────────────────────────────────────────────────────────────

-- Create trigger to queue sync events
CREATE TRIGGER order_sync_trigger
AFTER INSERT OR UPDATE OR DELETE ON orders
FOR EACH ROW
EXECUTE FUNCTION sync_to_firestore_trigger();

-- ─────────────────────────────────────────────────────────────────────────
-- WEBHOOK 2: Subscriptions Table Changes
-- Triggers when subscriptions are created, updated, or deleted
-- ─────────────────────────────────────────────────────────────────────────

CREATE TRIGGER subscription_sync_trigger
AFTER INSERT OR UPDATE OR DELETE ON subscriptions
FOR EACH ROW
EXECUTE FUNCTION sync_to_firestore_trigger();

-- ─────────────────────────────────────────────────────────────────────────
-- WEBHOOK 3: Delivery Tracking Changes
-- Triggers when delivery status updates (live tracking)
-- ─────────────────────────────────────────────────────────────────────────

CREATE TRIGGER delivery_tracking_sync_trigger
AFTER INSERT OR UPDATE ON delivery_tracking
FOR EACH ROW
EXECUTE FUNCTION sync_to_firestore_trigger();

-- ─────────────────────────────────────────────────────────────────────────
-- WEBHOOK 4: Product Inventory Changes
-- Triggers when inventory updates (real-time stock)
-- ─────────────────────────────────────────────────────────────────────────

CREATE TRIGGER product_inventory_sync_trigger
AFTER UPDATE ON products
FOR EACH ROW
WHEN (OLD.available_stock != NEW.available_stock
   OR OLD.reserved_stock != NEW.reserved_stock)
EXECUTE FUNCTION sync_to_firestore_trigger();

-- ─────────────────────────────────────────────────────────────────────────
-- WEBHOOK 5: Vendor Commission Changes
-- Triggers when commissions are calculated or paid
-- ─────────────────────────────────────────────────────────────────────────

CREATE TRIGGER vendor_commission_sync_trigger
AFTER INSERT OR UPDATE ON vendor_commissions
FOR EACH ROW
EXECUTE FUNCTION sync_to_firestore_trigger();

-- ─────────────────────────────────────────────────────────────────────────
-- Configure HTTP Webhook to Render Backend
-- This makes Supabase POST to your Render API when changes occur
-- ─────────────────────────────────────────────────────────────────────────

-- Create a function that calls HTTP endpoint
CREATE OR REPLACE FUNCTION notify_firestore_sync()
RETURNS TRIGGER AS $$
DECLARE
  payload JSONB;
BEGIN
  payload := jsonb_build_object(
    'table', TG_TABLE_NAME,
    'operation', TG_OP,
    'data', COALESCE(row_to_json(NEW), row_to_json(OLD))
  );

  -- Call Render backend webhook
  PERFORM
    net.http_post(
      url := 'https://fufajis-online-business.onrender.com/sync/firestore-event',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.sync_webhook_secret')
      ),
      body := payload,
      timeout_milliseconds := 5000
    );

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────────────────────
-- Manual Sync Queue Processor (runs periodically via cron)
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION process_firestore_sync_queue()
RETURNS TABLE(
  queue_id UUID,
  table_name VARCHAR,
  status VARCHAR,
  message TEXT
) AS $$
DECLARE
  queue_item RECORD;
  sync_response TEXT;
BEGIN
  FOR queue_item IN
    SELECT id, table_name, record_id, operation, payload
    FROM firestore_sync_queue
    WHERE status = 'pending' AND retry_count < 3
    LIMIT 50
  LOOP
    BEGIN
      -- Send to Render backend
      SELECT content INTO sync_response
      FROM http(
        'POST',
        'https://fufajis-online-business.onrender.com/sync/firestore-event',
        jsonb_build_object(
          'id', queue_item.id,
          'table', queue_item.table_name,
          'operation', queue_item.operation,
          'data', queue_item.payload
        )::text,
        'Content-Type: application/json'
      );

      -- Mark as synced if successful
      UPDATE firestore_sync_queue
      SET status = 'synced', synced_at = CURRENT_TIMESTAMP
      WHERE id = queue_item.id;

      RETURN QUERY SELECT
        queue_item.id,
        queue_item.table_name,
        'synced'::VARCHAR,
        'Successfully synced to Firestore'::TEXT;

    EXCEPTION WHEN OTHERS THEN
      -- Increment retry count on failure
      UPDATE firestore_sync_queue
      SET retry_count = retry_count + 1,
          error_message = SQLERRM,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = queue_item.id;

      RETURN QUERY SELECT
        queue_item.id,
        queue_item.table_name,
        'failed'::VARCHAR,
        SQLERRM::TEXT;
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────────────────────
-- Alternative: Simple Edge Function Webhook
-- If you prefer to use Supabase Edge Functions instead
-- ─────────────────────────────────────────────────────────────────────────

-- Create trigger that calls Edge Function
-- CREATE TRIGGER sync_to_edge_function
-- AFTER INSERT OR UPDATE OR DELETE ON orders
-- FOR EACH ROW
-- EXECUTE FUNCTION supabase_functions.http_request(
--   'https://your-project.supabase.co/functions/v1/firestore-sync',
--   'POST',
--   '{"Content-Type":"application/json"}'::jsonb,
--   row_to_json(NEW)::text
-- );
