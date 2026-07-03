-- Firestore Sync Queue
-- Durable, persistent queue for eventual consistency
-- All retries stored in PostgreSQL (survives process restart)

CREATE TABLE IF NOT EXISTS sync_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id VARCHAR(100) NOT NULL UNIQUE,
  -- What to sync
  entity_type VARCHAR(50) NOT NULL,  -- 'inventory', 'order', 'payment'
  entity_id VARCHAR(100) NOT NULL,
  -- The payload to sync
  payload JSONB NOT NULL,
  -- Retry tracking
  attempt_count INT DEFAULT 0,
  max_attempts INT DEFAULT 5,
  -- Backoff schedule
  next_retry_at TIMESTAMP NOT NULL,
  last_error TEXT,
  -- Status tracking
  status VARCHAR(50) DEFAULT 'pending',  -- 'pending', 'processing', 'completed', 'dead_letter'
  -- Timestamps
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP,
  failed_at TIMESTAMP
);

-- Indexes for efficient queries
CREATE INDEX idx_sync_queue_status ON sync_queue(status);
CREATE INDEX idx_sync_queue_retry ON sync_queue(status, next_retry_at) WHERE status = 'retry_pending';
CREATE INDEX idx_sync_queue_entity ON sync_queue(entity_type, entity_id);
CREATE INDEX idx_sync_queue_dlq ON sync_queue(status) WHERE status = 'dead_letter';

-- Dead Letter Queue table (for failed syncs that need ops attention)
CREATE TABLE IF NOT EXISTS sync_queue_dlq (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sync_queue_id UUID NOT NULL REFERENCES sync_queue(id),
  entity_type VARCHAR(50),
  entity_id VARCHAR(100),
  reason VARCHAR(500),  -- Why it failed
  alert_sent BOOLEAN DEFAULT FALSE,
  alert_sent_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  resolved_at TIMESTAMP
);

CREATE INDEX idx_dlq_alert ON sync_queue_dlq(alert_sent, created_at);

-- Retry Policy Implementation
-- Backoff curve: 30s, 2m, 10m, 30m, 2h
-- Calculate next_retry_at based on attempt_count:
-- attempt 1: NOW() + 30 seconds
-- attempt 2: NOW() + 2 minutes
-- attempt 3: NOW() + 10 minutes
-- attempt 4: NOW() + 30 minutes
-- attempt 5: NOW() + 2 hours
-- attempt 6+: move to dead letter queue

CREATE OR REPLACE FUNCTION calculate_next_retry_time(attempt_count INT)
RETURNS TIMESTAMP AS $$
DECLARE
  backoff_seconds INT;
BEGIN
  CASE attempt_count
    WHEN 0 THEN backoff_seconds := 30;        -- 30 seconds
    WHEN 1 THEN backoff_seconds := 120;       -- 2 minutes
    WHEN 2 THEN backoff_seconds := 600;       -- 10 minutes
    WHEN 3 THEN backoff_seconds := 1800;      -- 30 minutes
    WHEN 4 THEN backoff_seconds := 7200;      -- 2 hours
    ELSE
      -- Max retries exceeded
      RETURN NULL;
  END CASE;

  -- Add jitter (±10%) to prevent thundering herd
  backoff_seconds := backoff_seconds + (random() * backoff_seconds * 0.2 - backoff_seconds * 0.1)::INT;

  RETURN CURRENT_TIMESTAMP + (backoff_seconds || ' seconds')::INTERVAL;
END;
$$ LANGUAGE plpgsql;

-- Automatic DLQ move for failed jobs
CREATE OR REPLACE FUNCTION move_failed_job_to_dlq()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'dead_letter' THEN
    INSERT INTO sync_queue_dlq (sync_queue_id, entity_type, entity_id, reason)
    VALUES (NEW.id, NEW.entity_type, NEW.entity_id, NEW.last_error);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_queue_dlq_trigger
AFTER UPDATE ON sync_queue
FOR EACH ROW
WHEN (NEW.status = 'dead_letter')
EXECUTE FUNCTION move_failed_job_to_dlq();

-- Alert function (would call external alerting service)
CREATE OR REPLACE FUNCTION alert_dlq_jobs()
RETURNS void AS $$
BEGIN
  -- Find unalerted DLQ jobs
  UPDATE sync_queue_dlq
  SET alert_sent = TRUE, alert_sent_at = CURRENT_TIMESTAMP
  WHERE alert_sent = FALSE
  AND created_at > CURRENT_TIMESTAMP - INTERVAL '1 hour';

  -- TODO: Send to alerting service (PagerDuty, Slack, etc)
  RAISE NOTICE 'Alerted ops about % DLQ jobs', (SELECT COUNT(*) FROM sync_queue_dlq WHERE alert_sent = TRUE AND alert_sent_at > CURRENT_TIMESTAMP - INTERVAL '1 hour');
END;
$$ LANGUAGE plpgsql;
