-- Phase 1: Database Foundation
-- Migrations 004-007: Create remaining core tables
-- Purpose: Complete the security subsystem schema

BEGIN;

-- ==================== MIGRATION 004: PRIVILEGED DEVICES ====================

CREATE TABLE IF NOT EXISTS security.privileged_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,

  -- Device identification
  device_fingerprint TEXT NOT NULL,
  device_id TEXT,
  device_name TEXT,
  device_model TEXT,

  -- OS information
  platform TEXT,
  os_version TEXT,
  app_version TEXT,

  -- Trust status
  is_trusted BOOLEAN DEFAULT false,
  is_revoked BOOLEAN DEFAULT false,
  trusted_at TIMESTAMP WITH TIME ZONE,
  revoked_at TIMESTAMP WITH TIME ZONE,

  -- History
  registered_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  last_seen_at TIMESTAMP WITH TIME ZONE,
  last_ip_address TEXT,

  -- Security
  public_key TEXT, -- For future device verification
  security_score INT DEFAULT 0,

  -- Constraints
  CONSTRAINT device_trust_state CHECK (
    (is_trusted = false AND is_revoked = false) OR
    (is_trusted = true AND is_revoked = false) OR
    (is_trusted = false AND is_revoked = true)
  ),
  CONSTRAINT fk_device_user
    FOREIGN KEY (user_id)
    REFERENCES security.privileged_credentials(user_id)
    ON DELETE CASCADE
);

CREATE INDEX idx_privileged_devices_user_id
  ON security.privileged_devices(user_id);

CREATE INDEX idx_privileged_devices_fingerprint
  ON security.privileged_devices(device_fingerprint);

CREATE INDEX idx_privileged_devices_is_trusted
  ON security.privileged_devices(is_trusted);

CREATE INDEX idx_privileged_devices_registered_at
  ON security.privileged_devices(registered_at DESC);

ALTER TABLE security.privileged_devices ENABLE ROW LEVEL SECURITY;

-- ==================== MIGRATION 005: RATE LIMITS ====================

CREATE TABLE IF NOT EXISTS security.rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL UNIQUE,

  -- Attempt tracking
  failed_attempts INT DEFAULT 0,
  last_failed_attempt_at TIMESTAMP WITH TIME ZONE,
  last_successful_attempt_at TIMESTAMP WITH TIME ZONE,

  -- Lockout state
  locked_until TIMESTAMP WITH TIME ZONE,
  lock_reason TEXT,
  lock_applied_by TEXT, -- 'auto' or admin user_id

  -- Cooldown state
  cooldown_until TIMESTAMP WITH TIME ZONE,

  -- Admin approval
  requires_admin_approval BOOLEAN DEFAULT false,

  -- Window tracking (for rate limit window)
  window_start_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  window_attempt_count INT DEFAULT 0,

  -- History
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

  -- Constraints
  CONSTRAINT valid_attempts CHECK (failed_attempts >= 0),
  CONSTRAINT fk_rate_limit_user
    FOREIGN KEY (user_id)
    REFERENCES security.privileged_credentials(user_id)
    ON DELETE CASCADE
);

CREATE INDEX idx_rate_limits_user_id
  ON security.rate_limits(user_id);

CREATE INDEX idx_rate_limits_locked_until
  ON security.rate_limits(locked_until)
  WHERE locked_until IS NOT NULL;

CREATE TRIGGER trigger_rate_limits_updated_at
  BEFORE UPDATE ON security.rate_limits
  FOR EACH ROW
  EXECUTE FUNCTION security.update_privileged_credentials_timestamp();

ALTER TABLE security.rate_limits ENABLE ROW LEVEL SECURITY;

-- ==================== MIGRATION 006: AUDIT LOGS ====================

CREATE TABLE IF NOT EXISTS security.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Event information
  event_type TEXT NOT NULL,
  status TEXT NOT NULL,

  -- Subject
  user_id TEXT NOT NULL,
  email TEXT,
  role TEXT,

  -- Actor (who performed the action)
  actor_id TEXT, -- NULL for user self-actions, admin user_id for admin actions
  actor_role TEXT,

  -- Context
  ip_address TEXT,
  user_agent TEXT,
  device_id TEXT,
  device_fingerprint TEXT,

  -- Operational metadata
  platform TEXT,
  app_version TEXT,
  os_version TEXT,
  country TEXT,
  timezone TEXT,

  -- Request tracking
  request_id TEXT,
  correlation_id TEXT,

  -- Details
  reason TEXT,
  error_code TEXT,
  metadata JSONB,

  -- Duration
  duration_ms INT,

  -- Timestamp (immutable after creation)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

  -- Constraints
  CONSTRAINT valid_event_type CHECK (event_type IN (
    'PASSWORD_CREATED', 'PASSWORD_CHANGED', 'PASSWORD_RESET', 'PASSWORD_REVOKED',
    'PASSWORD_EXPIRED', 'LOGIN_SUCCESS', 'LOGIN_FAILED', 'ACCOUNT_LOCKED',
    'ACCOUNT_UNLOCKED', 'SESSION_CREATED', 'SESSION_EXPIRED', 'SESSION_TERMINATED',
    'DEVICE_REGISTERED', 'DEVICE_REVOKED', 'DEVICE_TRUSTED', 'ADMIN_OVERRIDE'
  )),
  CONSTRAINT valid_status CHECK (status IN ('success', 'failed', 'blocked')),
  CONSTRAINT user_id_not_empty CHECK (user_id != '')
);

CREATE INDEX idx_audit_logs_user_id
  ON security.audit_logs(user_id);

CREATE INDEX idx_audit_logs_event_type
  ON security.audit_logs(event_type);

CREATE INDEX idx_audit_logs_created_at
  ON security.audit_logs(created_at DESC);

CREATE INDEX idx_audit_logs_actor_id
  ON security.audit_logs(actor_id)
  WHERE actor_id IS NOT NULL;

CREATE INDEX idx_audit_logs_status
  ON security.audit_logs(status);

CREATE INDEX idx_audit_logs_user_event_time
  ON security.audit_logs(user_id, event_type, created_at DESC);

-- **CRITICAL**: Prevent any modifications to audit logs
ALTER TABLE security.audit_logs ENABLE ROW LEVEL SECURITY;

-- ==================== MIGRATION 007: PASSWORD HISTORY ====================

CREATE TABLE IF NOT EXISTS security.password_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,

  -- Password hash (for comparison, not for authentication)
  password_hash TEXT NOT NULL,
  password_hash_algorithm TEXT DEFAULT 'pbkdf2-sha256-10000',

  -- Change information
  changed_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  changed_by TEXT, -- 'self' or admin user_id

  -- Reason for change
  reason TEXT, -- 'initial', 'manual', 'reset', 'expiration'

  -- Retention
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

  -- Constraints
  CONSTRAINT fk_history_user
    FOREIGN KEY (user_id)
    REFERENCES security.privileged_credentials(user_id)
    ON DELETE CASCADE,
  CONSTRAINT valid_reason CHECK (reason IN ('initial', 'manual', 'reset', 'expiration'))
);

CREATE INDEX idx_password_history_user_id
  ON security.password_history(user_id);

CREATE INDEX idx_password_history_changed_at
  ON security.password_history(changed_at DESC);

CREATE INDEX idx_password_history_user_changed
  ON security.password_history(user_id, changed_at DESC);

ALTER TABLE security.password_history ENABLE ROW LEVEL SECURITY;

-- ==================== TRACK MIGRATIONS ====================

INSERT INTO security.schema_metadata (version, migration_name, description) VALUES
  ('1.3.0', '004_create_privileged_devices', 'Create privileged_devices table for device trust management'),
  ('1.4.0', '005_create_rate_limits', 'Create rate_limits table for tracking failed attempts and lockouts'),
  ('1.5.0', '006_create_audit_logs', 'Create audit_logs table for immutable event logging'),
  ('1.6.0', '007_create_password_history', 'Create password_history table for preventing password reuse')
ON CONFLICT (version) DO NOTHING;

-- ==================== VERIFY ALL TABLES ====================

-- This will be checked manually after migration
/*
SELECT
  tablename,
  (SELECT COUNT(*) FROM pg_indexes WHERE tablename = tables.tablename AND schemaname = 'security') as index_count
FROM pg_tables tables
WHERE schemaname = 'security'
ORDER BY tablename;

-- Should show 6 tables + schema_metadata
*/

COMMIT;
