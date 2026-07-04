-- =====================================================
-- FILE: sync_events_schema_fixed.sql
-- FUFAJI LOOP 2 PHASE C — Event Queue & DLQ Tables (Fixed)
-- =====================================================

CREATE TABLE IF NOT EXISTS sync_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    event_id_checksum VARCHAR(64),
    version INT DEFAULT 1,
    retry_count INT DEFAULT 0,
    max_retries INT DEFAULT 5,
    next_retry_at TIMESTAMP,
    sync_started_at TIMESTAMP,
    sync_completed_at TIMESTAMP,
    sync_duration_ms INT,
    error_message TEXT,
    error_code VARCHAR(50),
    error_details JSONB,
    source_system VARCHAR(30) NOT NULL,
    source_table VARCHAR(100),
    source_operation VARCHAR(20),
    created_by VARCHAR(100),
    updated_by VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    target_collection VARCHAR(100),
    priority INT DEFAULT 5,
    tags JSONB
);

CREATE TABLE IF NOT EXISTS sync_dlq (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sync_event_id UUID REFERENCES sync_events(id) ON DELETE SET NULL,
    event_type VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    payload JSONB NOT NULL,
    error_details JSONB,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    retry_count INT DEFAULT 0,
    max_dlq_retries INT DEFAULT 3,
    acknowledged_by VARCHAR(100),
    acknowledged_at TIMESTAMP,
    resolved_by VARCHAR(100),
    resolved_at TIMESTAMP,
    resolution_notes TEXT,
    resolution_type VARCHAR(50),
    last_retry_at TIMESTAMP,
    next_retry_scheduled_at TIMESTAMP,
    failure_reason VARCHAR(100),
    severity VARCHAR(10) DEFAULT 'high',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tags JSONB
);

-- INDEXES
CREATE INDEX IF NOT EXISTS idx_sync_events_status ON sync_events(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sync_events_entity ON sync_events(entity_type, entity_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sync_events_type ON sync_events(event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sync_events_created ON sync_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sync_events_source ON sync_events(source_system, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sync_events_priority ON sync_events(priority, created_at DESC) WHERE priority <= 2;

CREATE INDEX IF NOT EXISTS idx_dlq_pending ON sync_dlq(status, created_at DESC) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_dlq_entity ON sync_dlq(entity_type, entity_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_dlq_severity ON sync_dlq(severity, created_at DESC);

-- TRIGGERS
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
