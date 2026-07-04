-- ============================================================================
-- FIRESTORE DOWNSTREAM SYNC (Postgres -> Firestore)
-- ============================================================================
-- Purpose: Setup PostgreSQL triggers to automatically call the Edge Function
--          `sync-to-firestore` whenever an inventory or product record changes.
-- ============================================================================

-- Ensure the pg_net extension is enabled for HTTP requests
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Create the trigger function
CREATE OR REPLACE FUNCTION public.notify_firestore_sync()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_url TEXT;
  v_secret TEXT;
  v_payload JSONB;
BEGIN
  -- We assume the Edge Function URL and Service Role Key are stored in vault or environment.
  -- For local dev or standard setups, this calls the local/remote Edge Function.
  -- In a production Supabase project, you can set these via SQL or Dashboard.
  
  -- Fallback for local development if custom settings aren't defined
  v_url := COALESCE(current_setting('app.edge_function_url', true), 'http://host.docker.internal:54321/functions/v1/sync-to-firestore');
  v_secret := COALESCE(current_setting('app.service_role_key', true), 'anon');

  IF TG_OP = 'DELETE' THEN
    v_payload := json_build_object(
      'type', TG_OP,
      'table', TG_TABLE_NAME,
      'old_record', row_to_json(OLD)
    )::jsonb;
  ELSE
    v_payload := json_build_object(
      'type', TG_OP,
      'table', TG_TABLE_NAME,
      'record', row_to_json(NEW),
      'old_record', row_to_json(OLD)
    )::jsonb;
  END IF;

  PERFORM net.http_post(
      url:=v_url,
      headers:=json_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_secret
      )::jsonb,
      body:=v_payload
  );
  
  RETURN NEW;
END;
$$;

-- Create triggers for the relevant tables
DROP TRIGGER IF EXISTS sync_inventory_to_firestore_trigger ON public.inventory;
CREATE TRIGGER sync_inventory_to_firestore_trigger
  AFTER INSERT OR UPDATE ON public.inventory
  FOR EACH ROW EXECUTE FUNCTION public.notify_firestore_sync();

DROP TRIGGER IF EXISTS sync_products_to_firestore_trigger ON public.products;
CREATE TRIGGER sync_products_to_firestore_trigger
  AFTER INSERT OR UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.notify_firestore_sync();

-- (Optional) If you want order status changes to immediately sync back:
DROP TRIGGER IF EXISTS sync_orders_to_firestore_trigger ON public.orders;
CREATE TRIGGER sync_orders_to_firestore_trigger
  AFTER UPDATE OF status, payment_status ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.notify_firestore_sync();
