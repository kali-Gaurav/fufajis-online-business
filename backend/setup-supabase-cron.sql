-- ============================================================================
-- Setup Supabase Cron Jobs
-- ============================================================================
-- Run this in Supabase SQL Editor to set up all cron jobs
-- Requirements: pg_cron extension (must be installed in Supabase)

-- Enable pg_cron if not already enabled
-- ALTER DATABASE postgres SET "cron.database_name" = 'postgres';

-- ─────────────────────────────────────────────────────────────────────────
-- CRON JOB 1: Process Due Subscriptions
-- Runs daily at 00:00 UTC (05:30 IST)
-- ─────────────────────────────────────────────────────────────────────────

SELECT cron.schedule(
  'process_due_subscriptions',
  '0 0 * * *',  -- Daily at 00:00 UTC
  $$SELECT process_due_subscriptions()$$
);

-- ─────────────────────────────────────────────────────────────────────────
-- CRON JOB 2: Calculate Daily Commissions
-- Runs daily at 01:00 UTC (06:30 IST)
-- ─────────────────────────────────────────────────────────────────────────

SELECT cron.schedule(
  'calculate_daily_commissions',
  '0 1 * * *',  -- Daily at 01:00 UTC
  $$SELECT calculate_daily_commissions()$$
);

-- ─────────────────────────────────────────────────────────────────────────
-- CRON JOB 3: Cleanup Expired Reservations
-- Runs every 30 minutes
-- ─────────────────────────────────────────────────────────────────────────

SELECT cron.schedule(
  'cleanup_expired_reservations',
  '*/30 * * * *',  -- Every 30 minutes
  $$SELECT cleanup_expired_reservations()$$
);

-- ─────────────────────────────────────────────────────────────────────────
-- CRON JOB 4: Reconcile Stale Payments
-- Runs every hour at minute 0
-- ─────────────────────────────────────────────────────────────────────────

SELECT cron.schedule(
  'reconcile_stale_payments',
  '0 * * * *',  -- Every hour at minute 0
  $$SELECT reconcile_stale_payments()$$
);

-- ─────────────────────────────────────────────────────────────────────────
-- Verify cron jobs are scheduled
-- ─────────────────────────────────────────────────────────────────────────

SELECT
  jobid,
  jobname,
  schedule,
  command,
  nodename,
  nodeport,
  database,
  username,
  active
FROM cron.job
ORDER BY jobid;
