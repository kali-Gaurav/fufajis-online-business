-- P0-D FIX: DLQ & Retry Strategy (Firestore sync reliability)
-- Handles transient failures + exponential backoff + dead-letter queue

-- ============================================================================
-- TIER 1: SYNC MUTATION STATES (Enhanced from sync_mutations table)
-- ============================================================================

ALTER TABLE sync_mutations ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'pending';
ALTER TABLE sync_mutations ADD COLUMN IF NOT EXISTS retry_count INT DEFAULT 0;
ALTER TABLE sync_mutations ADD COLUMN IF NOT EXISTS next_retry_at TIMESTAMP;
ALTER TABLE sync_mutations ADD COLUMN IF NOT EXISTS dead_letter_reason TEXT;

-- States: PENDING → PROCESSING → SYNCED | FAILED → DEAD_LETTER
CREATE INDEX IF NOT EXISTS idx_sync_mutations_status ON sync_mutations(status);
CREATE INDEX IF NOT EXISTS idx_sync_mutations_retry ON sync_mutations(next_retry_at);

-- ============================================================================
-- TIER 2: DEAD LETTER QUEUE TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS sync_dead_letter_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Original mutation data
  mutation_id UUID NOT NULL REFERENCES sync_mutations(id) ON DELETE CASCADE,
  entity_type VARCHAR(100) NOT NULL,
  entity_id UUID NOT NULL,
  operation VARCHAR(20) NOT NULL,
  data_after JSONB NOT NULL,

  -- Failure tracking
  last_error TEXT NOT NULL,
  total_attempts INT NOT NULL,
  first_attempt_at TIMESTAMP NOT NULL,
  last_attempt_at TIMESTAMP NOT NULL,

  -- DLQ metadata
  queued_at TIMESTAMP DEFAULT NOW(),
  resolved_at TIMESTAMP,
  resolution VARCHAR(100), -- 'manual_retry', 'manual_skip', 'abandoned'

  -- Priority for manual remediation
  priority VARCHAR(50) DEFAULT 'medium', -- 'critical', 'high', 'medium', 'low'

  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_dlq_status ON sync_dead_letter_queue(resolved_at);
CREATE INDEX idx_dlq_priority ON sync_dead_letter_queue(priority);
CREATE INDEX idx_dlq_entity ON sync_dead_letter_queue(entity_type, entity_id);

-- ============================================================================
-- TIER 3: RETRY STRATEGY FUNCTIONS
-- ============================================================================

-- Function: Calculate next retry time (exponential backoff with jitter)
CREATE OR REPLACE FUNCTION calculate_next_retry_time(
  p_retry_count INT,
  p_max_retries INT DEFAULT 7
)
RETURNS TABLE (
  next_retry_at TIMESTAMP,
  should_dlq BOOLEAN
) AS $$
DECLARE
  v_backoff_seconds INT;
  v_jitter_seconds INT;
BEGIN
  -- If max retries exceeded, send to DLQ
  IF p_retry_count >= p_max_retries THEN
    RETURN QUERY SELECT NULL::TIMESTAMP, true;
    RETURN;
  END IF;

  -- Exponential backoff: 1m → 5m → 15m → 1h → 6h → 24h → 72h
  CASE p_retry_count
    WHEN 0 THEN v_backoff_seconds := 60;       -- 1 minute
    WHEN 1 THEN v_backoff_seconds := 300;      -- 5 minutes
    WHEN 2 THEN v_backoff_seconds := 900;      -- 15 minutes
    WHEN 3 THEN v_backoff_seconds := 3600;     -- 1 hour
    WHEN 4 THEN v_backoff_seconds := 21600;    -- 6 hours
    WHEN 5 THEN v_backoff_seconds := 86400;    -- 24 hours
    WHEN 6 THEN v_backoff_seconds := 259200;   -- 72 hours
    ELSE v_backoff_seconds := 604800;          -- 7 days (shouldn't reach)
  END CASE;

  -- Add 20% jitter to prevent thundering herd
  v_jitter_seconds := (v_backoff_seconds * 0.2 * RANDOM())::INT;
  v_backoff_seconds := v_backoff_seconds + v_jitter_seconds;

  RETURN QUERY SELECT
    NOW() + (v_backoff_seconds || ' seconds')::INTERVAL,
    false;
END;
$$ LANGUAGE plpgsql;

-- Function: Process retry for a failed sync mutation
CREATE OR REPLACE FUNCTION process_sync_retry()
RETURNS TABLE (
  processed_count INT,
  dlq_count INT,
  error_message TEXT
) AS $$
DECLARE
  v_mutation RECORD;
  v_next_retry RECORD;
  v_processed INT := 0;
  v_dlq_count INT := 0;
BEGIN
  -- Find mutations ready for retry
  -- Use SKIP LOCKED to prevent contention between workers
  FOR v_mutation IN
    SELECT * FROM sync_mutations
    WHERE status IN ('failed', 'processing')
      AND (next_retry_at IS NULL OR next_retry_at < NOW())
    ORDER BY next_retry_at ASC
    FOR UPDATE SKIP LOCKED
    LIMIT 100
  LOOP
    -- Calculate next retry time
    SELECT * INTO v_next_retry
    FROM calculate_next_retry_time(v_mutation.retry_count, 7);

    IF v_next_retry.should_dlq THEN
      -- Send to DLQ
      INSERT INTO sync_dead_letter_queue (
        mutation_id, entity_type, entity_id, operation, data_after,
        last_error, total_attempts, first_attempt_at, last_attempt_at,
        priority
      ) VALUES (
        v_mutation.id,
        v_mutation.entity_type,
        v_mutation.entity_id,
        v_mutation.operation,
        v_mutation.data_after,
        v_mutation.last_sync_error || ' (after ' || v_mutation.sync_attempts || ' attempts)',
        v_mutation.sync_attempts,
        v_mutation.created_at,
        NOW(),
        CASE
          WHEN v_mutation.entity_type = 'order' THEN 'critical'
          WHEN v_mutation.entity_type = 'payment' THEN 'critical'
          WHEN v_mutation.entity_type = 'wallet' THEN 'high'
          ELSE 'medium'
        END
      );

      -- Mark mutation as DLQ
      UPDATE sync_mutations
      SET
        status = 'dead_letter',
        dead_letter_reason = 'Max retries exceeded (' || v_mutation.sync_attempts || ' attempts)',
        updated_at = NOW()
      WHERE id = v_mutation.id;

      v_dlq_count := v_dlq_count + 1;
    ELSE
      -- Schedule for retry
      UPDATE sync_mutations
      SET
        status = 'pending',
        retry_count = v_mutation.retry_count + 1,
        next_retry_at = v_next_retry.next_retry_at,
        updated_at = NOW()
      WHERE id = v_mutation.id;

      v_processed := v_processed + 1;
    END IF;
  END LOOP;

  RETURN QUERY SELECT v_processed, v_dlq_count, NULL::TEXT;

EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT NULL::INT, NULL::INT, SQLERRM::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Function: Manual retry of DLQ item
CREATE OR REPLACE FUNCTION retry_dlq_item(
  p_dlq_id UUID,
  p_operator_id VARCHAR(100) DEFAULT 'admin'
)
RETURNS TABLE (
  success BOOLEAN,
  error_message TEXT,
  mutation_id UUID
) AS $$
DECLARE
  v_dlq RECORD;
BEGIN
  SELECT * INTO v_dlq FROM sync_dead_letter_queue
  WHERE id = p_dlq_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, 'DLQ item not found'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  -- Reset mutation for retry
  UPDATE sync_mutations
  SET
    status = 'pending',
    retry_count = 0,
    next_retry_at = NOW(),
    updated_at = NOW()
  WHERE id = v_dlq.mutation_id;

  -- Mark DLQ as resolved (manual_retry)
  UPDATE sync_dead_letter_queue
  SET
    resolved_at = NOW(),
    resolution = 'manual_retry'
  WHERE id = p_dlq_id;

  RETURN QUERY SELECT TRUE, 'DLQ item moved back to pending for retry'::TEXT,
    v_dlq.mutation_id;

EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT FALSE, SQLERRM::TEXT, NULL::UUID;
END;
$$ LANGUAGE plpgsql;

-- Function: Skip DLQ item (mark abandoned)
CREATE OR REPLACE FUNCTION skip_dlq_item(
  p_dlq_id UUID,
  p_reason TEXT,
  p_operator_id VARCHAR(100) DEFAULT 'admin'
)
RETURNS TABLE (
  success BOOLEAN,
  error_message TEXT
) AS $$
BEGIN
  UPDATE sync_dead_letter_queue
  SET
    resolved_at = NOW(),
    resolution = 'manual_skip',
    last_error = p_reason
  WHERE id = p_dlq_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, 'DLQ item not found'::TEXT;
    RETURN;
  END IF;

  RETURN QUERY SELECT TRUE, 'DLQ item marked as skipped'::TEXT;

EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT FALSE, SQLERRM::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TIER 4: MONITORING VIEWS
-- ============================================================================

CREATE OR REPLACE VIEW sync_health_view AS
SELECT
  'pending' AS status,
  COUNT(*) AS count,
  NULL::INT AS retry_count,
  NULL::TEXT AS error
FROM sync_mutations
WHERE status = 'pending'
UNION ALL
SELECT
  'processing',
  COUNT(*),
  NULL,
  NULL
FROM sync_mutations
WHERE status = 'processing'
UNION ALL
SELECT
  'synced',
  COUNT(*),
  NULL,
  NULL
FROM sync_mutations
WHERE status = 'synced'
UNION ALL
SELECT
  'failed',
  COUNT(*),
  AVG(retry_count)::INT,
  'Waiting for retry'
FROM sync_mutations
WHERE status = 'failed'
UNION ALL
SELECT
  'dead_letter',
  COUNT(*),
  NULL,
  'Manual intervention required'
FROM sync_mutations
WHERE status = 'dead_letter'
ORDER BY status;

CREATE OR REPLACE VIEW dlq_backlog_view AS
SELECT
  id,
  mutation_id,
  entity_type,
  entity_id,
  priority,
  total_attempts,
  last_error,
  queued_at,
  (NOW() - queued_at) AS time_in_dlq
FROM sync_dead_letter_queue
WHERE resolved_at IS NULL
ORDER BY priority DESC, queued_at ASC;

-- ============================================================================
-- TIER 5: SCHEDULING (pg_cron)
-- ============================================================================

-- Run every 5 minutes to process retries and move to DLQ
-- SELECT cron.schedule('process-sync-retries', '*/5 * * * *', 'SELECT process_sync_retry();');

-- Run every hour to cleanup old DLQ items (resolved > 30 days)
-- SELECT cron.schedule('cleanup-dlq', '0 * * * *', 'DELETE FROM sync_dead_letter_queue WHERE resolved_at < NOW() - INTERVAL ''30 days'';');

-- ============================================================================
-- SUMMARY: DLQ & RETRY STRATEGY (P0-D)
-- ============================================================================
--
-- PROBLEM:
-- Firestore sync can fail transiently (network, rate limits)
-- Without retry: mutation lost, Firestore stale
-- Without DLQ: retry forever, burn CPU
--
-- SOLUTION:
-- 1. Exponential backoff: 1m → 5m → 15m → 1h → 6h → 24h → 72h
-- 2. After 7 attempts → move to DLQ (dead-letter queue)
-- 3. Manual intervention for DLQ items
-- 4. Observable health dashboard
--
-- RETRY STATES:
-- PENDING → first attempt
-- PROCESSING → attempting sync
-- SYNCED → success
-- FAILED → transient failure, scheduled for retry
-- DEAD_LETTER → permanent failure, awaiting intervention
--
-- DLQ WORKFLOW:
-- 1. Manual review of DLQ items (by priority)
-- 2. Retry: reset to PENDING + retry count = 0
-- 3. Skip: abandon mutation (after manual verification)
--
-- BENEFITS:
-- ✅ Transient failures self-heal
-- ✅ Permanent failures don't burn resources
-- ✅ Observable via health_view
-- ✅ Actionable backlog via dlq_backlog_view
-- ✅ Manual control for edge cases
--
-- PRODUCTION READY FOR P0-D
