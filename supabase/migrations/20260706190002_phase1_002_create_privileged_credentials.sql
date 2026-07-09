-- Phase 1: Database Foundation
-- Migration 002: Create privileged_credentials table
-- Purpose: Store password records as source of truth

BEGIN;

-- Create privileged_credentials table
CREATE TABLE IF NOT EXISTS security.privileged_credentials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL,
  role TEXT NOT NULL,

  -- Password management
  password_hash TEXT NOT NULL,
  password_hash_algorithm TEXT DEFAULT 'pbkdf2-sha256-10000',
  password_salt TEXT, -- stored separately for audit purposes

  -- Status tracking
  status TEXT DEFAULT 'active',
  is_first_login BOOLEAN DEFAULT true,
  requires_password_change BOOLEAN DEFAULT false,

  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_by TEXT,
  revoked_at TIMESTAMP WITH TIME ZONE,
  revoked_by TEXT,
  last_password_change_at TIMESTAMP WITH TIME ZONE,
  last_login_at TIMESTAMP WITH TIME ZONE,

  -- Expiration
  password_expires_at TIMESTAMP WITH TIME ZONE,
  max_password_age_days INT DEFAULT 90,

  -- Password history (prevent reuse of last N passwords)
  password_history TEXT[] DEFAULT '{}',
  max_password_history INT DEFAULT 10,

  -- Admin approval workflow
  requires_admin_approval BOOLEAN DEFAULT false,
  admin_approval_at TIMESTAMP WITH TIME ZONE,
  approved_by TEXT,

  -- Constraints
  CONSTRAINT valid_status CHECK (status IN ('active', 'revoked', 'expired')),
  CONSTRAINT valid_role CHECK (role IN ('admin', 'shopOwner', 'employee', 'deliveryAgent')),
  CONSTRAINT password_hash_not_empty CHECK (password_hash != ''),
  CONSTRAINT email_not_empty CHECK (email != ''),
  CONSTRAINT valid_email CHECK (email LIKE '%@%')
);

-- Create indexes for fast lookups
CREATE INDEX idx_privileged_credentials_user_id
  ON security.privileged_credentials(user_id);

CREATE INDEX idx_privileged_credentials_email
  ON security.privileged_credentials(email);

CREATE INDEX idx_privileged_credentials_status
  ON security.privileged_credentials(status);

CREATE INDEX idx_privileged_credentials_role
  ON security.privileged_credentials(role);

CREATE INDEX idx_privileged_credentials_created_by
  ON security.privileged_credentials(created_by)
  WHERE created_by IS NOT NULL;

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION security.update_privileged_credentials_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_privileged_credentials_updated_at
  BEFORE UPDATE ON security.privileged_credentials
  FOR EACH ROW
  EXECUTE FUNCTION security.update_privileged_credentials_timestamp();

-- Enable RLS (policies defined in Phase 2)
ALTER TABLE security.privileged_credentials ENABLE ROW LEVEL SECURITY;

-- Track this migration
INSERT INTO security.schema_metadata (version, migration_name, description)
VALUES (
  '1.1.0',
  '002_create_privileged_credentials',
  'Create privileged_credentials table as source of truth for passwords'
) ON CONFLICT (version) DO NOTHING;

COMMIT;
