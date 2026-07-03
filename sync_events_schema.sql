-- =====================================================
-- FILE: sync_events_schema.sql
-- FUFAJI LOOP 2 PHASE C — Event Queue & DLQ Tables
-- =====================================================

-- Add to existing Supabase instance
-- These tables form the backbone of the sync engine

-- =====================================================
-- TABLE: sync_events
-- Purpose: Immutable log of all sync operations
-- Authority: Single source of truth for event tracking
-- =====================================================

CREATE TABLE IF NOT EXISTS sync_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Event metadata
    event_type VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,

    -- Event payload (full change data)
    payload JSONB NOT NULL,

    -- Sync status tracking
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    -- Statuses: pending, processing, completed, failed, dlq_sent

    -- Idempotency
    event_id_checksum VARCHAR(64),
    -- External event ID from source system (Webhook)
    version INT DEFAULT 1,
    -- Version counter for conflict resolution

    -- Retry tracking
    retry_count INT DEFAULT 0,
    max_retries INT DEFAULT 5,
    next_retry_at TIMESTAMP,

    -- Processing details
    sync_started_at TIMESTAMP,
    sync_completed_at TIMESTAMP,
    sync_duration_ms INT,

    -- Error tracking
    error_message TEXT,
    error_code VARCHAR(50),
    error_details JSONB,

    -- Source tracking
    source_system VARCHAR(30) NOT NULL,
    -- Values: supabase, firestore, external_webhook

    source_table VARCHAR(100),
    source_operation VARCHAR(20),
    -- Values: INSERT, UPDATE, DELETE

    -- Audit trail
    created_by VARCHAR(100),
    updated_by VARCHAR(100),

    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Sync routing
    target_collection VARCHAR(100),
    -- Where this event should sync to (e.g. 'firestore:catalog_products')

    -- Metadata
    priority INT DEFAULT 5,
    -- 1 = critical (inventory), 5 = normal, 9 = low priority

    tags JSONB
    -- Free-form tags for filtering/debugging
);

-- =====================================================
-- TABLE: sync_dlq (Dead Letter Queue)
-- Purpose: Failed syncs that need manual intervention
-- =====================================================

CREATE TABLE IF NOT EXISTS sync_dlq (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Link to original sync_event
    sync_event_id UUID REFERENCES sync_events(id) ON DELETE SET NULL,

    -- Job metadata
    event_type VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,

    -- Failed payload
    payload JSONB NOT NULL,
    error_details JSONB,

    -- DLQ status
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    -- Statuses: pending, acknowledged, resolved, abandoned

    -- Retry information
    retry_count INT DEFAULT 0,
    max_dlq_retries INT DEFAULT 3,

    -- Manual intervention (ops audit trail)
    acknowledged_by VARCHAR(100),
    acknowledged_at TIMESTAMP,

    resolved_by VARCHAR(100),
    resolved_at TIMESTAMP,
    resolution_notes TEXT,
    resolution_type VARCHAR(50),
    -- Allowed values: replay_success, manual_fix, duplicate_discarded, data_corruption, permanent_failure
    -- Used for postmortem analysis and recurring issue detection

    -- Retry attempts within DLQ
    last_retry_at TIMESTAMP,
    next_retry_scheduled_at TIMESTAMP,

    -- Classification
    failure_reason VARCHAR(100),
    -- E.g.: 'timeout', 'validation_error', 'conflict', 'permission_denied'

    severity VARCHAR(10) DEFAULT 'high',
    -- Values: critical, high, medium, low

    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Metadata
    tags JSONB
);

-- =====================================================
-- INDEXES — sync_events
-- =====================================================

-- Query by status (find pending syncs)
CREATE INDEX IF NOT EXISTS idx_sync_events_status
ON sync_events(status, created_at DESC);

-- Query by entity (find all syncs for a product)
CREATE INDEX IF NOT EXISTS idx_sync_events_entity
ON sync_events(entity_type, entity_id, created_at DESC);

-- Query by event type (find specific event class)
CREATE INDEX IF NOT EXISTS idx_sync_events_type
ON sync_events(event_type, created_at DESC);

-- Query by created_at (range scans)
CREATE INDEX IF NOT EXISTS idx_sync_events_created
ON sync_events(created_at DESC);

-- Find failed events for retry
CREATE INDEX IF NOT EXISTS idx_sync_events_failed
ON sync_events(status, next_retry_at)
WHERE status = 'failed' AND retry_count < max_retries;

-- Find duplicates by checksum (idempotency)
CREATE INDEX IF NOT EXISTS idx_sync_events_checksum
ON sync_events(event_id_checksum, entity_type)
WHERE event_id_checksum IS NOT NULL;

-- Find events by source (debugging)
CREATE INDEX IF NOT EXISTS idx_sync_events_source
ON sync_events(source_system, created_at DESC);

-- Find high-priority events
CREATE INDEX IF NOT EXISTS idx_sync_events_priority
ON sync_events(priority, created_at DESC)
WHERE priority <= 2;

-- Full-text search on error messages (debugging)
CREATE INDEX IF NOT EXISTS idx_sync_events_error_tsvector
ON sync_events USING GIN(to_tsvector('english', COALESCE(error_message, '')));

-- =====================================================
-- INDEXES — sync_dlq
-- =====================================================

-- Find pending DLQ items (operational)
CREATE INDEX IF NOT EXISTS idx_dlq_pending
ON sync_dlq(status, created_at DESC)
WHERE status = 'pending';

-- Find items awaiting manual review
CREATE INDEX IF NOT EXISTS idx_dlq_acknowledged
ON sync_dlq(acknowledged_at DESC)
WHERE status = 'acknowledged';

-- Find items ready for retry
CREATE INDEX IF NOT EXISTS idx_dlq_next_retry
ON sync_dlq(next_retry_scheduled_at)
WHERE status = 'pending' AND next_retry_scheduled_at <= CURRENT_TIMESTAMP;

-- Find by entity (which product's DLQ entries)
CREATE INDEX IF NOT EXISTS idx_dlq_entity
ON sync_dlq(entity_type, entity_id, created_at DESC);

-- Find by severity (filter critical issues)
CREATE INDEX IF NOT EXISTS idx_dlq_severity
ON sync_dlq(severity, created_at DESC);

-- Find old DLQ entries (cleanup candidates)
CREATE INDEX IF NOT EXISTS idx_dlq_stale
ON sync_dlq(created_at ASC)
WHERE status != 'resolved';

-- =====================================================
-- TRIGGERS — Auto-update updated_at
-- =====================================================

CREATE OR REPLACE FUNCTION update_sync_events_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_events_updated_at
BEFORE UPDATE ON sync_events
FOR EACH ROW
EXECUTE FUNCTION update_sync_events_timestamp();

---

CREATE OR REPLACE FUNCTION update_sync_dlq_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_dlq_updated_at
BEFORE UPDATE ON sync_dlq
FOR EACH ROW
EXECUTE FUNCTION update_sync_dlq_timestamp();

-- =====================================================
-- TRIGGER — Auto-move failed events to DLQ
-- =====================================================

CREATE OR REPLACE FUNCTION move_to_dlq_on_failure()
RETURNS TRIGGER AS $$
BEGIN
    -- If event failed after max retries, log to DLQ
    IF NEW.status = 'failed' AND NEW.retry_count >= NEW.max_retries THEN
        INSERT INTO sync_dlq (
            sync_event_id,
            event_type,
            entity_type,
            entity_id,
            payload,
            error_details,
            status,
            failure_reason,
            severity,
            tags
        )
        VALUES (
            NEW.id,
            NEW.event_type,
            NEW.entity_type,
            NEW.entity_id,
            NEW.payload,
            JSONB_BUILD_OBJECT(
                'error_message', NEW.error_message,
                'error_code', NEW.error_code,
                'retry_count', NEW.retry_count,
                'last_attempt_at', NEW.updated_at
            ),
            'pending',
            NEW.error_code,
            CASE
                WHEN NEW.event_type = 'INVENTORY_UPDATED' THEN 'critical'
                WHEN NEW.event_type = 'ORDER_CREATED' THEN 'critical'
                ELSE 'high'
            END,
            JSONB_BUILD_OBJECT('source_event_id', NEW.id::text)
        );

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_failed_to_dlq
AFTER UPDATE ON sync_events
FOR EACH ROW
EXECUTE FUNCTION move_to_dlq_on_failure();

-- =====================================================
-- TRIGGER — Prevent hard deletes
-- =====================================================

CREATE OR REPLACE FUNCTION prevent_hard_delete_sync_events()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Hard delete of sync_events not allowed. Set status to archived instead.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_sync_events_delete
BEFORE DELETE ON sync_events
FOR EACH ROW
EXECUTE FUNCTION prevent_hard_delete_sync_events();

-- =====================================================
-- VIEWS — Sync metrics & diagnostics
-- =====================================================

CREATE OR REPLACE VIEW v_sync_health AS
SELECT
    'pending' AS status,
    COUNT(*) AS count,
    AVG(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - created_at))) AS avg_age_seconds
FROM sync_events
WHERE status = 'pending'
GROUP BY status

UNION ALL

SELECT
    'failed' AS status,
    COUNT(*) AS count,
    AVG(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - created_at))) AS avg_age_seconds
FROM sync_events
WHERE status = 'failed'
GROUP BY status

UNION ALL

SELECT
    'dlq' AS status,
    COUNT(*) AS count,
    AVG(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - created_at))) AS avg_age_seconds
FROM sync_dlq
WHERE status = 'pending'
GROUP BY status;

-- View: Failed events by type
CREATE OR REPLACE VIEW v_failed_events_by_type AS
SELECT
    event_type,
    COUNT(*) AS fail_count,
    MAX(updated_at) AS last_failure,
    STRING_AGG(DISTINCT error_code, ', ') AS error_codes
FROM sync_events
WHERE status = 'failed'
GROUP BY event_type
ORDER BY fail_count DESC;

-- View: DLQ inventory
CREATE OR REPLACE VIEW v_dlq_inventory AS
SELECT
    status,
    severity,
    COUNT(*) AS count,
    MIN(created_at) AS oldest,
    MAX(created_at) AS newest
FROM sync_dlq
GROUP BY status, severity
ORDER BY severity ASC, status ASC;

-- =====================================================
-- CONSTRAINTS & VALIDATION
-- =====================================================

ALTER TABLE sync_events
ADD CONSTRAINT check_event_type_valid
CHECK (event_type IN (
    'PRODUCT_CREATED', 'PRODUCT_UPDATED', 'PRODUCT_DELETED',
    'VARIANT_CREATED', 'VARIANT_UPDATED',
    'INVENTORY_CREATED', 'INVENTORY_UPDATED',
    'CART_CREATED', 'CART_ITEM_ADDED', 'CART_ABANDONED',
    'ORDER_CREATED', 'ORDER_STATUS_CHANGED',
    'SYNC_RETRY', 'DRIFT_DETECTED'
));

ALTER TABLE sync_events
ADD CONSTRAINT check_status_valid
CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'dlq_sent', 'archived'));

ALTER TABLE sync_dlq
ADD CONSTRAINT check_dlq_status_valid
CHECK (status IN ('pending', 'acknowledged', 'resolved', 'abandoned'));

ALTER TABLE sync_dlq
ADD CONSTRAINT check_severity_valid
CHECK (severity IN ('critical', 'high', 'medium', 'low'));

ALTER TABLE sync_dlq
ADD CONSTRAINT check_resolution_type_valid
CHECK (resolution_type IS NULL OR resolution_type IN ('replay_success', 'manual_fix', 'duplicate_discarded', 'data_corruption', 'permanent_failure'));

-- =====================================================
-- INITIAL DATA (Optional)
-- =====================================================

-- Insert empty summary row for monitoring
INSERT INTO sync_events (
    event_type, entity_type, entity_id, payload,
    status, source_system
) VALUES (
    'SYNC_INITIALIZED', 'SYSTEM', '00000000-0000-0000-0000-000000000000'::UUID,
    '{"message": "Fufaji sync engine initialized"}'::JSONB,
    'completed', 'system'
)
ON CONFLICT DO NOTHING;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE sync_events IS
'Immutable event log for all sync operations. Source of truth for sync audit trail.';

COMMENT ON TABLE sync_dlq IS
'Dead Letter Queue for sync events that fail after max retries. Requires manual intervention.';

COMMENT ON COLUMN sync_events.event_id_checksum IS
'Checksum from source system (e.g., webhook ID). Used for deduplication.';

COMMENT ON COLUMN sync_events.status IS
'pending = awaiting sync, processing = in flight, completed = success, failed = error, dlq_sent = moved to DLQ';

COMMENT ON COLUMN sync_dlq.failure_reason IS
'Why the sync failed (timeout, validation_error, conflict, permission_denied, etc.)';

COMMENT ON COLUMN sync_dlq.resolution_type IS
'How the DLQ item was resolved (replay_success, manual_fix, duplicate_discarded, data_corruption, permanent_failure). Required for postmortem analysis and recurring issue tracking. Null until resolved.';

-- =====================================================
-- WRITE THROUGHPUT SLA (MANDATORY)
-- =====================================================

-- Production write requirements for sync_events:
-- - p95 latency: < 20ms
-- - p99 latency: < 50ms
-- - sustained throughput: 500 inserts/sec
-- - burst capacity: 2,000 inserts/sec for 30 sec
--
-- Scaling thresholds:
-- - If inserts/day > 100k OR rows > 500k: enable partitioning
-- - If p99 latency > 50ms: re-index or partition by created_at
-- - Benchmark before going live: PGBENCH sync_events insert workload
--
-- Optimization strategy:
-- Prefer batch events over individual events:
--   Instead of: 100 INVENTORY_UPDATED events
--   Prefer: 1 BULK_INVENTORY_UPDATE event with affected_variants = 100
-- This reduces write amplification by 100x.

-- =====================================================
-- PARTITIONING STRATEGY (FUTURE)
-- =====================================================

-- When to partition:
-- Condition 1: sync_events table > 500k rows
-- Condition 2: inserts > 100k/day
-- Condition 3: p99 query latency > 50ms
--
-- Partition key: created_at (monthly)
-- Retention policy:
--   Hot (queryable):  sync_events, last 90 days
--   Warm (archive):   sync_events_archive_*, 90-180 days
--   Cold (delete):    sync_events_archive_*, > 180 days
--
-- Implementation (when needed):
--   1. Install pg_partman extension
--   2. Run: SELECT partman.create_parent('public.sync_events', 'created_at', 'native', 'monthly');
--   3. Automate maintenance: SELECT partman.run_maintenance_proc();
--
-- For now (MVP): Single table, rely on indexes + cleanup cron

-- =====================================================
-- DEPLOYMENT NOTES
-- =====================================================

-- 1. Run this SQL script in Supabase SQL Editor
-- 2. Verify tables created: SELECT * FROM information_schema.tables WHERE table_schema = 'public';
-- 3. Test indexes: EXPLAIN SELECT * FROM sync_events WHERE status = 'pending' ORDER BY created_at DESC;
-- 4. Benchmark write latency:
--    CREATE TABLE _benchmark_sync (LIKE sync_events);
--    \timing on
--    INSERT INTO _benchmark_sync SELECT * FROM sync_events LIMIT 1000;
--    (Should complete in < 50ms)
-- 5. Grant permissions:
--    GRANT SELECT, INSERT, UPDATE ON sync_events TO authenticated;
--    GRANT SELECT ON sync_dlq TO authenticated;
--    GRANT ALL ON sync_events, sync_dlq TO service_role;
-- 6. Create cron jobs in Supabase (pg_cron extension):
--    SELECT cron.schedule('sync_events_cleanup', '0 2 * * *', 'DELETE FROM sync_events WHERE status = "archived" AND created_at < now() - interval ''30 days''');
-- 7. Monitor metrics (daily):
--    SELECT COUNT(*) as total_events FROM sync_events;
--    SELECT COUNT(*) as pending_events FROM sync_events WHERE status = 'pending';
--    SELECT COUNT(*) as dlq_items FROM sync_dlq WHERE status = 'pending';

-- =====================================================
-- TESTING CHECKLIST
-- =====================================================

-- Test 1: Insert event
-- INSERT INTO sync_events (event_type, entity_type, entity_id, payload, source_system)
-- VALUES ('INVENTORY_UPDATED', 'variant', gen_random_uuid(), '{"stock": 100}'::JSONB, 'supabase');

-- Test 2: Query pending events
-- SELECT * FROM sync_events WHERE status = 'pending' ORDER BY created_at DESC LIMIT 10;

-- Test 3: Query DLQ inventory
-- SELECT * FROM v_dlq_inventory;

-- Test 4: Simulate DLQ move (update status to failed with max retries)
-- UPDATE sync_events SET status = 'failed', retry_count = 5, max_retries = 5 WHERE id = ?;
-- Then verify DLQ entry was created

-- Test 5: Performance: Index on status + created_at
-- EXPLAIN ANALYZE SELECT * FROM sync_events WHERE status = 'failed' LIMIT 100;

-- End of sync_events_schema.sql
