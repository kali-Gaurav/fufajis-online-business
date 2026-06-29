-- ============================================================
-- Migration 015: Delivery Operating System (Module 8)
-- Adds support for:
--  1. Rider shifts and clock-in/out records
--  2. Delivery status change logs (audit events trail)
--  3. Delivery exception records
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Rider Shifts Table
CREATE TABLE IF NOT EXISTS rider_shifts (
    shift_id VARCHAR(128) PRIMARY KEY,
    rider_id VARCHAR(128) NOT NULL,
    branch_id VARCHAR(128) NOT NULL,
    status VARCHAR(50) NOT NULL CHECK (status IN ('online', 'offline', 'on_break')),
    started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP WITH TIME ZONE,
    total_deliveries INT DEFAULT 0,
    total_earnings NUMERIC(10, 2) DEFAULT 0.00,
    total_distance_km NUMERIC(10, 2) DEFAULT 0.00,
    total_incidents INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Delivery Status Logs (Audit Trail)
CREATE TABLE IF NOT EXISTS delivery_status_logs (
    log_id SERIAL PRIMARY KEY,
    delivery_id VARCHAR(128) NOT NULL,
    order_id VARCHAR(128) NOT NULL,
    rider_id VARCHAR(128),
    from_status VARCHAR(50),
    to_status VARCHAR(50) NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Delivery Exceptions Table
CREATE TABLE IF NOT EXISTS delivery_exceptions (
    id VARCHAR(128) PRIMARY KEY,
    delivery_id VARCHAR(128) NOT NULL,
    rider_id VARCHAR(128) NOT NULL,
    branch_id VARCHAR(128) NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN (
        'customer_unreachable', 'wrong_address', 'vehicle_breakdown', 
        'weather_delay', 'item_missing', 'payment_failure', 
        'customer_rejected_order', 'other'
    )),
    description TEXT,
    status VARCHAR(50) DEFAULT 'open' CHECK (status IN ('open', 'under_review', 'resolved')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolution_notes TEXT,
    resolved_by_user_id VARCHAR(128)
);

-- 4. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_rider_shifts_rider ON rider_shifts(rider_id);
CREATE INDEX IF NOT EXISTS idx_rider_shifts_status ON rider_shifts(status);
CREATE INDEX IF NOT EXISTS idx_delivery_status_logs_delivery ON delivery_status_logs(delivery_id);
CREATE INDEX IF NOT EXISTS idx_delivery_status_logs_order ON delivery_status_logs(order_id);
CREATE INDEX IF NOT EXISTS idx_delivery_exceptions_delivery ON delivery_exceptions(delivery_id);
CREATE INDEX IF NOT EXISTS idx_delivery_exceptions_rider ON delivery_exceptions(rider_id);
CREATE INDEX IF NOT EXISTS idx_delivery_exceptions_status ON delivery_exceptions(status);

-- 5. Trigger for updated_at on rider_shifts if trigger function exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at') THEN
        CREATE TRIGGER trg_set_updated_at_rider_shifts
        BEFORE UPDATE ON rider_shifts
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at();
    END IF;
END $$;
