-- Phase 1: Database Foundation
-- Migration 003: Create privileged_sessions table
-- Purpose: Track active sessions with device information

BEGIN;

CREATE TABLE IF NOT EXISTS security.privileged_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,

  -- Session token (stored as SHA256 hash only, never plaintext)
  token_hash TEXT NOT NULL UNIQUE,
  refresh_token_hash TEXT UNIQUE,

  -- Session lifecycle
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

  -- Timeout configuration
  idle_timeout_minutes INT DEFAULT 30,
  absolute_timeout_minutes INT DEFAULT 1440, -- 24 hours

  -- Device information
  device_id TEXT,
  device_fingerprint TEXT,
  device_name TEXT,
  device_model TEXT,

  -- Network information
  ip_address TEXT,
  user_agent TEXT,

  -- Application information
  app_version TEXT,
  platform TEXT, -- 'ios', 'android', 'web'
  os_version TEXT,

  -- Device trust
  is_remembered_device BOOLEAN DEFAULT false,
  device_trusted_at TIMESTAMP WITH TIME ZONE,

  -- Session state
  is_active BOOLEAN DEFAULT true,

  -- Request correlation
  correlation_id TEXT,
  request_id TEXT,

  -- Constraints
  CONSTRAINT session_must_have_expiry CHECK (expires_at > created_at),
  CONSTRAINT valid_platform CHECK (platform IN ('ios', 'android', 'web') OR platform IS NULL),
  CONSTRAINT valid_timeout CHECK (idle_timeout_minutes > 0 AND absolute_timeout_minutes > 0),
  CONSTRAINT ip_address_not_empty CHECK (ip_address != ''),

  -- Foreign key to credentials (optional - for cleanup on revocation)
  CONSTRAINT fk_session_user
    FOREIGN KEY (user_id)
    REFERENCES security.privileged_credentials(user_id)
    ON DELETE CASCADE
);

-- Create indexes for fast lookups
CREATE INDEX idx_privileged_sessions_user_id
  ON security.privileged_sessions(user_id);

CREATE INDEX idx_privileged_sessions_token_hash
  ON security.privileged_sessions(token_hash);

CREATE INDEX idx_privileged_sessions_expires_at
  ON security.privileged_sessions(expires_at);

CREATE INDEX idx_privileged_sessions_is_active
  ON security.privileged_sessions(is_active)
  WHERE is_active = true;

CREATE INDEX idx_privileged_sessions_device_id
  ON security.privileged_sessions(device_id)
  WHERE device_id IS NOT NULL;

CREATE INDEX idx_privileged_sessions_created_at
  ON security.privileged_sessions(created_at DESC);

-- Create trigger to update last_activity_at
CREATE OR REPLACE FUNCTION security.update_session_activity()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_activity_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_privileged_sessions_activity
  BEFORE UPDATE ON security.privileged_sessions
  FOR EACH ROW
  WHEN (OLD.last_activity_at IS DISTINCT FROM NEW.last_activity_at)
  EXECUTE FUNCTION security.update_session_activity();

-- Create trigger to auto-deactivate expired sessions on read
CREATE OR REPLACE FUNCTION security.auto_deactivate_expired_sessions()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.expires_at < now() THEN
    NEW.is_active = false;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_deactivate_sessions
  BEFORE UPDATE ON security.privileged_sessions
  FOR EACH ROW
  EXECUTE FUNCTION security.auto_deactivate_expired_sessions();

-- Enable RLS (policies defined in Phase 2)
ALTER TABLE security.privileged_sessions ENABLE ROW LEVEL SECURITY;

-- Track this migration
INSERT INTO security.schema_metadata (version, migration_name, description)
VALUES (
  '1.2.0',
  '003_create_privileged_sessions',
  'Create privileged_sessions table for session tracking with device info'
) ON CONFLICT (version) DO NOTHING;

COMMIT;
