-- Increment retry_count helper RPC for firestore-sync-worker
-- Run this once: supabase db push (it will be picked up with next push)

CREATE OR REPLACE FUNCTION increment_retry_count(event_id UUID)
RETURNS VOID AS $$
  UPDATE outbox_events
  SET retry_count = retry_count + 1
  WHERE id = event_id;
$$ LANGUAGE SQL;
