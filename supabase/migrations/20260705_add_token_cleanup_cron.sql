-- Migration: Add pg_cron job for token_blacklist cleanup
-- Date: 2026-07-05
-- Purpose: Automatically prune expired revoked tokens to prevent table bloat

-- Ensure the pg_cron extension is enabled (Supabase typically has this available)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule a job to run every hour to delete expired tokens from token_blacklist
-- The job name is 'cleanup-expired-tokens'
SELECT cron.schedule(
  'cleanup-expired-tokens',  
  '0 * * * *',               
  $$ DELETE FROM public.token_blacklist WHERE expires_at < NOW(); $$
);
