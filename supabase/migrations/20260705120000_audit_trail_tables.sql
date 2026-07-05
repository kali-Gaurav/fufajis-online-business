-- Audit Trail Tables for Compliance & Debugging
-- Tracks all user actions, system events, and security events

-- ═══════════════════════════════════════════════════════════════════════
-- AUDIT LOGS TABLE (User & System Actions)
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  correlation_id TEXT NOT NULL,  -- Request correlation ID for tracing
  user_id TEXT,                   -- User who performed action (NULL for system)
  user_role TEXT,                 -- Role of user (owner, admin, employee, delivery, customer)
  action TEXT NOT NULL,           -- Action name: create_order, update_inventory, cancel_payment, etc.
  resource_type TEXT NOT NULL,    -- Type of resource: orders, products, payments, deliveries, etc.
  resource_id TEXT NOT NULL,      -- ID of the resource being acted upon
  resource_before JSONB,          -- Previous state of resource (for updates/deletes)
  resource_after JSONB,           -- New state of resource (for creates/updates)
  status TEXT NOT NULL,           -- success | failure | pending
  error_message TEXT,             -- If status=failure, error details
  metadata JSONB,                 -- Additional context: IP, user agent, location, etc.
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

  -- Constraints
  CONSTRAINT audit_logs_user_id_check CHECK (user_id IS NOT NULL OR user_role = 'system'),
  CONSTRAINT audit_logs_status_check CHECK (status IN ('success', 'failure', 'pending'))
);

-- Indexes for efficient querying
CREATE INDEX idx_audit_logs_correlation_id ON audit_logs(correlation_id);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_logs_status ON audit_logs(status) WHERE status = 'failure';

-- ═══════════════════════════════════════════════════════════════════════
-- SECURITY EVENTS TABLE (Auth, Access Control, Anomalies)
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS security_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  correlation_id TEXT,
  event_type TEXT NOT NULL,  -- login_success, login_failure, unauthorized_access, mfa_enabled, session_revoked, etc.
  user_id TEXT,
  severity TEXT NOT NULL,    -- info, warning, critical
  description TEXT NOT NULL,
  ip_address INET,
  user_agent TEXT,
  location TEXT,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

  -- Constraints
  CONSTRAINT security_events_severity_check CHECK (severity IN ('info', 'warning', 'critical'))
);

CREATE INDEX idx_security_events_user_id ON security_events(user_id);
CREATE INDEX idx_security_events_event_type ON security_events(event_type);
CREATE INDEX idx_security_events_severity ON security_events(severity) WHERE severity IN ('warning', 'critical');
CREATE INDEX idx_security_events_created_at ON security_events(created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════
-- CHANGE LOG TABLE (Data Change Tracking)
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS change_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  correlation_id TEXT,
  table_name TEXT NOT NULL,       -- orders, products, inventory, wallets, etc.
  operation TEXT NOT NULL,        -- INSERT, UPDATE, DELETE
  record_id TEXT NOT NULL,        -- Primary key of the changed record
  changed_by_user_id TEXT,        -- User who triggered the change
  changed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  changes JSONB NOT NULL,         -- { field_name: { old_value, new_value } }
  reason TEXT,                    -- Why the change was made (from audit_logs.action)

  CONSTRAINT change_logs_operation_check CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE'))
);

CREATE INDEX idx_change_logs_table ON change_logs(table_name);
CREATE INDEX idx_change_logs_record ON change_logs(table_name, record_id);
CREATE INDEX idx_change_logs_user ON change_logs(changed_by_user_id) WHERE changed_by_user_id IS NOT NULL;
CREATE INDEX idx_change_logs_timestamp ON change_logs(changed_at DESC);

-- ═══════════════════════════════════════════════════════════════════════
-- API CALL LOG TABLE (Webhook & External API Tracking)
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS api_call_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  correlation_id TEXT,
  service_name TEXT NOT NULL,     -- razorpay, stripe, twilio, sendgrid, firebase, etc.
  endpoint TEXT NOT NULL,         -- /payments, /webhooks, etc.
  method TEXT NOT NULL,           -- GET, POST, PUT, DELETE
  status_code INTEGER,
  request_body JSONB,
  response_body JSONB,
  error_message TEXT,
  duration_ms INTEGER,            -- How long the call took
  called_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  retry_count INTEGER DEFAULT 0,

  CONSTRAINT api_call_logs_method_check CHECK (method IN ('GET', 'POST', 'PUT', 'DELETE', 'PATCH'))
);

CREATE INDEX idx_api_call_logs_service ON api_call_logs(service_name);
CREATE INDEX idx_api_call_logs_status ON api_call_logs(status_code) WHERE status_code >= 400;
CREATE INDEX idx_api_call_logs_called_at ON api_call_logs(called_at DESC);
CREATE INDEX idx_api_call_logs_correlation ON api_call_logs(correlation_id);

-- ═══════════════════════════════════════════════════════════════════════
-- ANOMALY LOG TABLE (System-detected Anomalies)
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS anomaly_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  correlation_id TEXT,
  anomaly_type TEXT NOT NULL,     -- revenue_drop, orders_drop, low_stock, failed_payments_spike, etc.
  severity TEXT NOT NULL,         -- low, medium, high, critical
  description TEXT NOT NULL,
  affected_resource TEXT,         -- product_id, order_id, etc.
  metric_name TEXT,               -- revenue, order_count, stock_level, etc.
  metric_value NUMERIC,
  baseline_value NUMERIC,         -- Normal value for comparison
  deviation_percent NUMERIC,      -- % deviation from baseline
  detected_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  acknowledged_at TIMESTAMP WITH TIME ZONE,
  acknowledged_by TEXT,
  action_taken TEXT,

  CONSTRAINT anomaly_logs_severity_check CHECK (severity IN ('low', 'medium', 'high', 'critical'))
);

CREATE INDEX idx_anomaly_logs_type ON anomaly_logs(anomaly_type);
CREATE INDEX idx_anomaly_logs_severity ON anomaly_logs(severity) WHERE severity IN ('high', 'critical');
CREATE INDEX idx_anomaly_logs_detected_at ON anomaly_logs(detected_at DESC);
CREATE INDEX idx_anomaly_logs_unacknowledged ON anomaly_logs(acknowledged_at) WHERE acknowledged_at IS NULL;

-- ═══════════════════════════════════════════════════════════════════════
-- RLS POLICIES (Access Control)
-- ═══════════════════════════════════════════════════════════════════════

-- Enable RLS
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE security_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE change_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_call_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE anomaly_logs ENABLE ROW LEVEL SECURITY;

-- Only owner/admins can read audit logs
CREATE POLICY audit_logs_owner_read ON audit_logs FOR SELECT
  USING (auth.jwt() ->> 'role' IN ('owner', 'admin'));

CREATE POLICY security_events_owner_read ON security_events FOR SELECT
  USING (auth.jwt() ->> 'role' IN ('owner', 'admin'));

-- System can insert (via backend service role)
CREATE POLICY audit_logs_service_insert ON audit_logs FOR INSERT
  WITH CHECK (auth.jwt() ->> 'role' = 'service');

-- Owner/Admin can view anomalies
CREATE POLICY anomaly_logs_owner_read ON anomaly_logs FOR SELECT
  USING (auth.jwt() ->> 'role' IN ('owner', 'admin'));

-- ═══════════════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════

-- Function to log audit event (called from backend)
CREATE OR REPLACE FUNCTION log_audit_event(
  p_correlation_id TEXT,
  p_user_id TEXT,
  p_user_role TEXT,
  p_action TEXT,
  p_resource_type TEXT,
  p_resource_id TEXT,
  p_resource_before JSONB,
  p_resource_after JSONB,
  p_status TEXT,
  p_error_message TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO audit_logs (
    correlation_id, user_id, user_role, action, resource_type, resource_id,
    resource_before, resource_after, status, error_message, metadata
  ) VALUES (
    p_correlation_id, p_user_id, p_user_role, p_action, p_resource_type, p_resource_id,
    p_resource_before, p_resource_after, p_status, p_error_message, p_metadata
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to log security event
CREATE OR REPLACE FUNCTION log_security_event(
  p_correlation_id TEXT,
  p_event_type TEXT,
  p_user_id TEXT,
  p_severity TEXT,
  p_description TEXT,
  p_ip_address INET DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL,
  p_location TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO security_events (
    correlation_id, event_type, user_id, severity, description,
    ip_address, user_agent, location, metadata
  ) VALUES (
    p_correlation_id, p_event_type, p_user_id, p_severity, p_description,
    p_ip_address, p_user_agent, p_location, p_metadata
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════════════════
-- ENABLE REPLICATION (for log export to data warehouse)
-- ═══════════════════════════════════════════════════════════════════════

ALTER PUBLICATION supabase_realtime ADD TABLE audit_logs;
ALTER PUBLICATION supabase_realtime ADD TABLE security_events;
ALTER PUBLICATION supabase_realtime ADD TABLE anomaly_logs;

-- End migration
