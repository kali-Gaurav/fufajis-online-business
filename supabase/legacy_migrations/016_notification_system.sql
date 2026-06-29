-- ============================================================
-- Migration 016: Notification Operating System (Module 9)
-- Adds support for:
--  1. Unified notifications list
--  2. Notification logs (audit trail of channel deliveries)
--  3. Notification failures (DLQ and retries tracking)
--  4. Operational and system alert logs
-- ============================================================

-- 1. Notifications Table (Relational Mirror of Firestore Notifications)
CREATE TABLE IF NOT EXISTS notifications (
    id VARCHAR(128) PRIMARY KEY,
    recipient_id VARCHAR(128) NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'orderUpdate', 'promotion', 'priceDrop', 'shopUpdate', 'systemMessage', 'alert'
    channel VARCHAR(50) NOT NULL, -- 'fcm', 'whatsapp', 'sms', 'email', 'in_app'
    status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'delivered', 'failed', 'retrying')),
    is_read BOOLEAN DEFAULT FALSE,
    deep_link TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Notification Delivery Logs (Channel-level Audit Trails)
CREATE TABLE IF NOT EXISTS notification_logs (
    log_id SERIAL PRIMARY KEY,
    notification_id VARCHAR(128),
    recipient_id VARCHAR(128) NOT NULL,
    channel VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    delivered_at TIMESTAMP WITH TIME ZONE,
    response_payload TEXT
);

-- 3. Notification Failures (DLQ tracking & retries manager)
CREATE TABLE IF NOT EXISTS notification_failures (
    id VARCHAR(128) PRIMARY KEY,
    notification_id VARCHAR(128),
    recipient_id VARCHAR(128) NOT NULL,
    channel VARCHAR(50) NOT NULL,
    error_message TEXT,
    retry_count INT DEFAULT 0,
    last_tried_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    next_retry_at TIMESTAMP WITH TIME ZONE,
    is_dlq BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Alert Logs (System and Operational alarms)
CREATE TABLE IF NOT EXISTS alert_logs (
    id VARCHAR(128) PRIMARY KEY,
    type VARCHAR(50) NOT NULL CHECK (type IN (
        'payment_dispute', 'fraud_alert', 'system_failure', 
        'reconciliation_mismatch', 'low_stock', 'delivery_failure', 'other'
    )),
    severity VARCHAR(50) NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by VARCHAR(128),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Indexes for Query Optimization
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications(recipient_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON notifications(status);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notification_logs_notification ON notification_logs(notification_id);
CREATE INDEX IF NOT EXISTS idx_notification_failures_notification ON notification_failures(notification_id);
CREATE INDEX IF NOT EXISTS idx_alert_logs_type ON alert_logs(type);
CREATE INDEX IF NOT EXISTS idx_alert_logs_resolved ON alert_logs(resolved);

-- 6. Trigger for updated_at on notifications if set_updated_at procedure exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at') THEN
        CREATE TRIGGER trg_set_updated_at_notifications
        BEFORE UPDATE ON notifications
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at();
    END IF;
END $$;
