-- Sync Logs Table for tracking inventory synchronization events
-- Created: 2026-07-09

CREATE TABLE IF NOT EXISTS public.sync_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Sync metadata
  sync_type TEXT NOT NULL CHECK (sync_type IN (
    'inventory_to_firestore',
    'wallet_to_firestore',
    'orders_to_firestore',
    'inventory_from_firestore'
  )),

  status TEXT NOT NULL CHECK (status IN ('success', 'partial_failure', 'error')),

  -- Statistics
  total_products INT DEFAULT 0,
  synced_count INT DEFAULT 0,
  failed_count INT DEFAULT 0,

  -- Error tracking
  details JSONB DEFAULT NULL,

  -- Timing
  synced_at TIMESTAMP NOT NULL DEFAULT now(),
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

-- Index for querying recent syncs
CREATE INDEX IF NOT EXISTS idx_sync_logs_type_created
  ON public.sync_logs(sync_type, created_at DESC);

-- Index for finding recent failures
CREATE INDEX IF NOT EXISTS idx_sync_logs_status_created
  ON public.sync_logs(status, created_at DESC);

-- Enable RLS
ALTER TABLE public.sync_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Allow service role (cron/edge functions) to read/write
-- This allows the edge function to log sync events
CREATE POLICY "sync_logs_service_role"
  ON public.sync_logs
  FOR ALL
  TO authenticated, service_role
  USING (true)
  WITH CHECK (true);
