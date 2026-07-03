/**
 * PHASE C DATABASE MIGRATIONS
 *
 * Creates:
 * - sync_events (event log for all sync operations)
 * - sync_dlq (dead letter queue for failed syncs)
 * - system_flags (kill switches for operational safety)
 * - reservations (inventory reservations with expiry)
 *
 * File: /backend/src/db/migrations/003-phase-c-schema.sql
 * Status: Phase C Execution Layer
 */

-- =====================================================
-- 1. SYNC_EVENTS TABLE
-- =====================================================
-- Immutable log of all sync operations
-- Source of truth for sync audit trail

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
    -- Values: pending, processing, completed, failed, dlq_sent, archived

    -- Idempotency
    event_id_checksum VARCHAR(255),
    version INT DEFAULT 1,

    -- Retry tracking
    retry_count INT DEFAULT 0,
    max_retries INT DEFAULT 3,
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
    -- Values: supabase, firestore, api, lambda
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
    -- Where this event should sync to (e.g., 'firestore:catalog_products')

    -- Metadata
    priority INT DEFAULT 5,
    -- 1 = critical (inventory), 5 = normal, 9 = low
    tags JSONB
);

-- Indexes for sync_events
CREATE INDEX IF NOT EXISTS idx_sync_events_status
ON sync_events(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sync_events_entity
ON sync_events(entity_type, entity_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sync_events_type
ON sync_events(event_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sync_events_created
ON sync_events(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sync_events_failed
ON sync_events(status, next_retry_at)
WHERE status = 'failed' AND retry_count < max_retries;

CREATE INDEX IF NOT EXISTS idx_sync_events_checksum
ON sync_events(event_id_checksum, entity_type)
WHERE event_id_checksum IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_sync_events_source
ON sync_events(source_system, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sync_events_priority
ON sync_events(priority, created_at DESC)
WHERE priority <= 2;

-- Trigger: auto-update updated_at
CREATE OR REPLACE FUNCTION update_sync_events_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_events_updated_at ON sync_events;
CREATE TRIGGER trg_sync_events_updated_at
BEFORE UPDATE ON sync_events
FOR EACH ROW
EXECUTE FUNCTION update_sync_events_timestamp();

-- Trigger: prevent hard deletes
CREATE OR REPLACE FUNCTION prevent_hard_delete_sync_events()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Hard delete of sync_events not allowed. Set status to archived instead.';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_sync_events_delete ON sync_events;
CREATE TRIGGER trg_prevent_sync_events_delete
BEFORE DELETE ON sync_events
FOR EACH ROW
EXECUTE FUNCTION prevent_hard_delete_sync_events();

-- =====================================================
-- 2. SYNC_DLQ TABLE
-- =====================================================
-- Dead Letter Queue for failed syncs requiring manual intervention

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
    -- Values: pending, acknowledged, resolved, abandoned

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
    -- Values: replay_success, manual_fix, duplicate_discarded, data_corruption, permanent_failure

    -- Retry attempts within DLQ
    last_retry_at TIMESTAMP,
    next_retry_scheduled_at TIMESTAMP,

    -- Classification
    failure_reason VARCHAR(100),
    -- e.g., 'timeout', 'validation_error', 'conflict', 'permission_denied'

    severity VARCHAR(10) DEFAULT 'high',
    -- Values: critical, high, medium, low

    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Metadata
    tags JSONB
);

-- Indexes for sync_dlq
CREATE INDEX IF NOT EXISTS idx_dlq_pending
ON sync_dlq(status, created_at DESC)
WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_dlq_entity
ON sync_dlq(entity_type, entity_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_dlq_severity
ON sync_dlq(severity, created_at DESC);

-- Trigger: auto-update updated_at
CREATE OR REPLACE FUNCTION update_sync_dlq_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_dlq_updated_at ON sync_dlq;
CREATE TRIGGER trg_sync_dlq_updated_at
BEFORE UPDATE ON sync_dlq
FOR EACH ROW
EXECUTE FUNCTION update_sync_dlq_timestamp();

-- =====================================================
-- 3. SYSTEM_FLAGS TABLE
-- =====================================================
-- Kill switches for operational safety (disable broken workers instantly)

CREATE TABLE IF NOT EXISTS system_flags (
    id SERIAL PRIMARY KEY,

    flag_name VARCHAR(100) UNIQUE NOT NULL,
    enabled BOOLEAN DEFAULT TRUE,
    reason TEXT,
    disabled_by VARCHAR(100),
    disabled_at TIMESTAMP,
    re_enable_at TIMESTAMP,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for flag lookups
CREATE INDEX IF NOT EXISTS idx_system_flags_name
ON system_flags(flag_name);

-- Insert required flags
INSERT INTO system_flags (flag_name, enabled, reason, created_at, updated_at)
VALUES
    ('inventory_sync_enabled', TRUE, 'Default: enabled', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('product_sync_enabled', TRUE, 'Default: enabled', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('order_replication_enabled', TRUE, 'Default: enabled', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('search_cache_refresh_enabled', TRUE, 'Default: enabled', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('drift_detection_enabled', TRUE, 'Default: enabled', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('retry_jobs_enabled', TRUE, 'Default: enabled', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('dlq_processing_enabled', TRUE, 'Default: enabled', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT (flag_name) DO NOTHING;

-- Trigger: auto-update updated_at
CREATE OR REPLACE FUNCTION update_system_flags_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_system_flags_updated_at ON system_flags;
CREATE TRIGGER trg_system_flags_updated_at
BEFORE UPDATE ON system_flags
FOR EACH ROW
EXECUTE FUNCTION update_system_flags_timestamp();

-- =====================================================
-- 4. RESERVATIONS TABLE
-- =====================================================
-- Inventory reservations with expiry (for pending orders)

CREATE TABLE IF NOT EXISTS reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    variant_id UUID NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    quantity_reserved INT NOT NULL,

    -- Idempotency
    idempotency_key VARCHAR(255) UNIQUE,

    -- Status tracking
    status VARCHAR(20) DEFAULT 'active',
    -- Values: active, confirmed, released, expired, cancelled

    order_id UUID,

    -- Expiry (for pending orders that never checkout)
    expires_at TIMESTAMP NOT NULL,
    expired_at TIMESTAMP,

    -- Lifecycle timestamps
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMP,
    released_at TIMESTAMP,
    cancelled_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for reservations
CREATE INDEX IF NOT EXISTS idx_reservations_user_status
ON reservations(user_id, status);

CREATE INDEX IF NOT EXISTS idx_reservations_variant_active
ON reservations(variant_id, status)
WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_reservations_expires
ON reservations(expires_at)
WHERE status = 'active';

-- Trigger: auto-update updated_at
CREATE OR REPLACE FUNCTION update_reservations_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_reservations_updated_at ON reservations;
CREATE TRIGGER trg_reservations_updated_at
BEFORE UPDATE ON reservations
FOR EACH ROW
EXECUTE FUNCTION update_reservations_timestamp();

-- =====================================================
-- 5. VIEWS
-- =====================================================

-- View: Sync health dashboard
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

-- =====================================================
-- 6. CONSTRAINTS & VALIDATION
-- =====================================================

-- Validate event types
ALTER TABLE sync_events
ADD CONSTRAINT check_event_type_valid
CHECK (event_type IN (
    'PRODUCT_CREATED', 'PRODUCT_UPDATED', 'PRODUCT_DELETED',
    'VARIANT_CREATED', 'VARIANT_UPDATED',
    'INVENTORY_UPDATED', 'INVENTORY_RESERVED',
    'ORDER_CREATED', 'ORDER_CONFIRMED', 'ORDER_STATUS_CHANGED',
    'SYNC_RETRY', 'DRIFT_DETECTED',
    'SEARCH_CACHE_STALE'
)) ON CONFLICT DO NOTHING;

-- Validate sync event status
ALTER TABLE sync_events
ADD CONSTRAINT check_sync_status_valid
CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'dlq_sent', 'archived'))
ON CONFLICT DO NOTHING;

-- Validate DLQ status
ALTER TABLE sync_dlq
ADD CONSTRAINT check_dlq_status_valid
CHECK (status IN ('pending', 'acknowledged', 'resolved', 'abandoned'))
ON CONFLICT DO NOTHING;

-- Validate resolution type
ALTER TABLE sync_dlq
ADD CONSTRAINT check_resolution_type_valid
CHECK (resolution_type IS NULL OR resolution_type IN (
    'replay_success', 'manual_fix', 'duplicate_discarded', 'data_corruption', 'permanent_failure'
))
ON CONFLICT DO NOTHING;

-- =====================================================
-- 7. COMMENTS
-- =====================================================

COMMENT ON TABLE sync_events IS
'Immutable event log for all sync operations. Source of truth for sync audit trail. Used for replay, debugging, and compliance.';

COMMENT ON TABLE sync_dlq IS
'Dead Letter Queue for sync events that fail after max retries. Requires manual intervention or review.';

COMMENT ON TABLE system_flags IS
'Emergency control switches. Allows instant disable of broken workers without redeployment.';

COMMENT ON TABLE reservations IS
'Inventory reservations for pending orders. Expires after checkout timeout to prevent blocking stock.';

COMMENT ON COLUMN sync_events.event_id_checksum IS
'Checksum from source system (e.g., webhook ID). Used for deduplication to prevent duplicate processing.';

COMMENT ON COLUMN sync_events.priority IS
'1 = critical (inventory/orders), 5 = normal, 9 = low. Used for SLA and alerting prioritization.';

COMMENT ON COLUMN sync_dlq.failure_reason IS
'Why the sync failed: timeout, validation_error, conflict, permission_denied, etc. Used for diagnostics.';

COMMENT ON COLUMN sync_dlq.resolution_type IS
'How the DLQ item was resolved. Required for postmortem analysis. Only set when status = resolved.';

-- =====================================================
-- 8. GRANTS (if using separate roles)
-- =====================================================

-- GRANT SELECT, INSERT, UPDATE ON sync_events TO authenticated;
-- GRANT SELECT ON sync_dlq TO authenticated;
-- GRANT ALL ON sync_events, sync_dlq TO service_role;

-- =====================================================
-- DEPLOYMENT NOTES
-- =====================================================

-- 1. Run this migration in Supabase SQL Editor
-- 2. Verify tables created: SELECT * FROM information_schema.tables WHERE table_schema = 'public';
-- 3. Test indexes: EXPLAIN SELECT * FROM sync_events WHERE status = 'pending';
-- 4. Grant permissions if using role-based access
-- 5. Monitor: Watch sync_health view for queue buildup
