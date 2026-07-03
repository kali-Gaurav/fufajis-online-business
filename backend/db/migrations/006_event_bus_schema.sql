-- Event Bus Schema
-- Durable, reliable async event processing with Dead Letter Queue (DLQ)
-- Priority-based processing with partition key for ordered execution

-- EVENTS: Core event bus table
CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Event metadata
  event_type VARCHAR(100) NOT NULL,  -- ORDER_CREATED, PAYMENT_SUCCESS, ORDER_PACKED, ORDER_DELIVERED, REFUND_COMPLETED
  aggregate_id UUID NOT NULL,        -- order_id, payment_id, etc
  partition_key VARCHAR(100) NOT NULL,  -- Ensures ordered processing per entity (e.g., order_id)
  -- Payload
  payload JSONB NOT NULL,
  -- Async execution
  priority INT DEFAULT 5,            -- 1=critical, 5=normal, 10=background
  scheduled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  -- Processing status
  status VARCHAR(50) DEFAULT 'pending',  -- pending, processing, completed, dead_letter
  worker_id VARCHAR(100),            -- Which worker is processing this
  attempt_count INT DEFAULT 0,
  max_attempts INT DEFAULT 5,
  last_error TEXT,
  -- Retry tracking
  next_retry_at TIMESTAMP,
  -- Timestamps
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  processed_at TIMESTAMP,
  failed_at TIMESTAMP
);

-- Indexes for efficient event processing
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);
CREATE INDEX IF NOT EXISTS idx_events_priority_status ON events(priority, status) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_events_partition_status ON events(partition_key, scheduled_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_events_scheduled ON events(scheduled_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_events_aggregate ON events(aggregate_id, event_type);
CREATE INDEX IF NOT EXISTS idx_events_worker ON events(worker_id) WHERE status = 'processing';
CREATE INDEX IF NOT EXISTS idx_events_retry ON events(next_retry_at) WHERE status = 'pending' AND attempt_count > 0;
CREATE INDEX IF NOT EXISTS idx_events_dlq ON events(status) WHERE status = 'dead_letter';

-- EVENTS_DLQ: Dead Letter Queue for permanently failed events
CREATE TABLE IF NOT EXISTS events_dlq (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id),
  event_type VARCHAR(100),
  aggregate_id UUID,
  partition_key VARCHAR(100),
  -- Why it failed
  reason TEXT,
  last_error TEXT,
  -- Alert tracking
  alert_sent BOOLEAN DEFAULT FALSE,
  alert_sent_at TIMESTAMP,
  -- Resolution
  resolved BOOLEAN DEFAULT FALSE,
  resolved_at TIMESTAMP,
  resolution_notes TEXT,
  -- Audit
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_dlq_alert ON events_dlq(alert_sent, created_at);
CREATE INDEX IF NOT EXISTS idx_dlq_unresolved ON events_dlq(resolved, created_at);

-- FUNCTION: Calculate next retry time with exponential backoff
-- Backoff: 30s → 2m → 10m → 30m → 2h → DLQ
CREATE OR REPLACE FUNCTION calculate_event_retry_time(attempt INT)
RETURNS TIMESTAMP AS $$
DECLARE
  backoff_seconds INT;
BEGIN
  CASE attempt
    WHEN 1 THEN backoff_seconds := 30;      -- 30 seconds
    WHEN 2 THEN backoff_seconds := 120;     -- 2 minutes
    WHEN 3 THEN backoff_seconds := 600;     -- 10 minutes
    WHEN 4 THEN backoff_seconds := 1800;    -- 30 minutes
    WHEN 5 THEN backoff_seconds := 7200;    -- 2 hours
    ELSE
      -- Max retries exceeded
      RETURN NULL;
  END CASE;

  -- Add jitter (±10%) to prevent thundering herd
  backoff_seconds := backoff_seconds + (random() * backoff_seconds * 0.2 - backoff_seconds * 0.1)::INT;

  RETURN CURRENT_TIMESTAMP + (backoff_seconds || ' seconds')::INTERVAL;
END;
$$ LANGUAGE plpgsql;

-- FUNCTION: Mark event as failed and move to DLQ if max retries exceeded
CREATE OR REPLACE FUNCTION fail_event(
  event_id UUID,
  error_message TEXT
)
RETURNS VOID AS $$
DECLARE
  evt RECORD;
BEGIN
  SELECT * INTO evt FROM events WHERE id = event_id FOR UPDATE;

  IF evt IS NULL THEN
    RAISE EXCEPTION 'Event % not found', event_id;
  END IF;

  -- Increment attempt counter
  UPDATE events
  SET
    attempt_count = attempt_count + 1,
    last_error = error_message,
    next_retry_at = calculate_event_retry_time(attempt_count + 1),
    status = CASE
      WHEN (attempt_count + 1) >= max_attempts THEN 'dead_letter'
      ELSE 'pending'
    END,
    failed_at = CASE
      WHEN (attempt_count + 1) >= max_attempts THEN CURRENT_TIMESTAMP
      ELSE NULL
    END
  WHERE id = event_id;

  -- If moving to DLQ, insert into DLQ table
  IF evt.attempt_count + 1 >= evt.max_attempts THEN
    INSERT INTO events_dlq (event_id, event_type, aggregate_id, partition_key, reason, last_error)
    VALUES (event_id, evt.event_type, evt.aggregate_id, evt.partition_key, 'Max retries exceeded', error_message);
  END IF;
END;
$$ LANGUAGE plpgsql;

-- FUNCTION: Mark event as completed
CREATE OR REPLACE FUNCTION complete_event(event_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE events
  SET
    status = 'completed',
    processed_at = CURRENT_TIMESTAMP,
    worker_id = NULL
  WHERE id = event_id;
END;
$$ LANGUAGE plpgsql;

-- FUNCTION: Claim event for processing (atomically lock by worker)
CREATE OR REPLACE FUNCTION claim_event_for_processing(worker_id_param VARCHAR)
RETURNS TABLE(
  id UUID,
  event_type VARCHAR,
  aggregate_id UUID,
  partition_key VARCHAR,
  payload JSONB,
  priority INT,
  attempt_count INT
) AS $$
BEGIN
  -- Find lowest ID pending event (FIFO within priority level)
  -- Ordered by priority (ascending, so 1=first) then scheduled_at
  -- Lock by partition_key to ensure order within an aggregate
  RETURN QUERY
  UPDATE events
  SET
    status = 'processing',
    worker_id = worker_id_param,
    attempt_count = attempt_count + 1
  WHERE id = (
    SELECT id FROM events
    WHERE status = 'pending'
      AND scheduled_at <= CURRENT_TIMESTAMP
    ORDER BY priority ASC, scheduled_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED
  )
  RETURNING
    events.id,
    events.event_type,
    events.aggregate_id,
    events.partition_key,
    events.payload,
    events.priority,
    events.attempt_count;
END;
$$ LANGUAGE plpgsql;

-- FUNCTION: Get next batch of events to process (by partition for ordered processing)
CREATE OR REPLACE FUNCTION get_next_event_batch(batch_size INT DEFAULT 10)
RETURNS TABLE(
  id UUID,
  event_type VARCHAR,
  aggregate_id UUID,
  partition_key VARCHAR,
  payload JSONB,
  priority INT,
  attempt_count INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id,
    e.event_type,
    e.aggregate_id,
    e.partition_key,
    e.payload,
    e.priority,
    e.attempt_count
  FROM events e
  WHERE e.status = 'pending'
    AND e.scheduled_at <= CURRENT_TIMESTAMP
  ORDER BY e.priority ASC, e.scheduled_at ASC
  LIMIT batch_size;
END;
$$ LANGUAGE plpgsql;

-- TRIGGER: Automatically move to DLQ when status updated to 'dead_letter'
CREATE OR REPLACE FUNCTION trigger_event_dlq_insert()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'dead_letter' AND OLD.status != 'dead_letter' THEN
    INSERT INTO events_dlq (event_id, event_type, aggregate_id, partition_key, reason, last_error)
    VALUES (NEW.id, NEW.event_type, NEW.aggregate_id, NEW.partition_key, 'Max retries exceeded', NEW.last_error)
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER events_dlq_trigger
AFTER UPDATE ON events
FOR EACH ROW
WHEN (NEW.status = 'dead_letter' AND OLD.status != 'dead_letter')
EXECUTE FUNCTION trigger_event_dlq_insert();

-- CLEANUP: Remove completed events older than 30 days (configurable)
CREATE OR REPLACE FUNCTION cleanup_old_events()
RETURNS INT AS $$
DECLARE
  deleted_count INT;
BEGIN
  DELETE FROM events
  WHERE status = 'completed'
    AND processed_at < CURRENT_TIMESTAMP - INTERVAL '30 days';

  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- View: Event processing metrics
CREATE OR REPLACE VIEW event_metrics AS
SELECT
  COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
  COUNT(*) FILTER (WHERE status = 'processing') as processing_count,
  COUNT(*) FILTER (WHERE status = 'completed') as completed_count,
  COUNT(*) FILTER (WHERE status = 'dead_letter') as dlq_count,
  AVG(attempt_count) FILTER (WHERE status = 'completed') as avg_attempts,
  MAX(attempt_count) FILTER (WHERE status = 'dead_letter') as max_attempts_on_dlq
FROM events;
