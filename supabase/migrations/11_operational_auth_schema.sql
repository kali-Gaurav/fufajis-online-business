/**
 * OPERATIONAL AUTHENTICATION SCHEMA
 * Supports: Owner, Employee, Rider, Supplier, Admin accounts
 * Created: 2026-07-11
 * Purpose: Backend-driven operational user authentication with bcrypt hashing
 */

-- ============================================================================
-- 1. OPERATIONAL USERS TABLE
-- ============================================================================
-- Stores owner, employee, rider, supplier account credentials
-- Source of truth for operational user authentication
-- Replicated to Firestore for UI updates

CREATE TABLE IF NOT EXISTS operational_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  user_type VARCHAR(50) NOT NULL CHECK (user_type IN ('owner', 'employee', 'rider', 'supplier')),
  owner_id UUID REFERENCES operational_users(id) ON DELETE CASCADE,
  full_name VARCHAR(255),
  phone_number VARCHAR(20),
  is_active BOOLEAN DEFAULT true NOT NULL,

  -- Account lockout (5 failures = 15 min lockout)
  failed_login_attempts INT DEFAULT 0,
  locked_until TIMESTAMP WITH TIME ZONE,

  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  last_login_at TIMESTAMP WITH TIME ZONE,

  -- Audit
  created_by UUID REFERENCES operational_users(id) ON DELETE SET NULL,

  CONSTRAINT valid_email CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'),
  CONSTRAINT owner_can_only_have_one_owner CHECK (
    user_type != 'owner' OR owner_id IS NULL
  )
);

CREATE INDEX idx_operational_users_email ON operational_users(email);
CREATE INDEX idx_operational_users_user_type ON operational_users(user_type);
CREATE INDEX idx_operational_users_owner_id ON operational_users(owner_id);
CREATE INDEX idx_operational_users_is_active ON operational_users(is_active);

-- ============================================================================
-- 2. ADMIN ACCOUNTS TABLE
-- ============================================================================
-- Admin accounts for platform-level access (separate from operational users)
-- Supports role hierarchy: L1 (full), L2 (business ops), L3 (limited)

CREATE TABLE IF NOT EXISTS admin_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  admin_level INT NOT NULL CHECK (admin_level IN (1, 2, 3)),
  is_active BOOLEAN DEFAULT true NOT NULL,

  failed_login_attempts INT DEFAULT 0,
  locked_until TIMESTAMP WITH TIME ZONE,

  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  last_login_at TIMESTAMP WITH TIME ZONE,

  CONSTRAINT valid_email CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$')
);

CREATE INDEX idx_admin_accounts_email ON admin_accounts(email);
CREATE INDEX idx_admin_accounts_admin_level ON admin_accounts(admin_level);
CREATE INDEX idx_admin_accounts_is_active ON admin_accounts(is_active);

-- ============================================================================
-- 3. LOGIN AUDIT LOG TABLE
-- ============================================================================
-- Tracks all login attempts (success/failure) for security monitoring
-- Retention: 90 days

CREATE TABLE IF NOT EXISTS login_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_email VARCHAR(255) NOT NULL,
  login_status VARCHAR(50) NOT NULL CHECK (login_status IN ('success', 'failed_invalid_credentials', 'failed_account_locked', 'failed_user_disabled', 'failed_other')),
  user_type VARCHAR(50) NOT NULL,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX idx_login_audit_log_email ON login_audit_log(user_email);
CREATE INDEX idx_login_audit_log_status ON login_audit_log(login_status);
CREATE INDEX idx_login_audit_log_created_at ON login_audit_log(created_at);

-- Cleanup policy: delete logs older than 90 days
CREATE OR REPLACE FUNCTION cleanup_login_audit_logs()
RETURNS void AS $$
BEGIN
  DELETE FROM login_audit_log
  WHERE created_at < now() - interval '90 days';
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. PASSWORD RESET TOKENS TABLE
-- ============================================================================
-- One-time use password reset tokens with 1-hour expiry
-- Hashed for security (never store plaintext tokens)

CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES operational_users(id) ON DELETE CASCADE,
  token_hash VARCHAR(255) NOT NULL UNIQUE,
  is_used BOOLEAN DEFAULT false NOT NULL,
  used_at TIMESTAMP WITH TIME ZONE,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  ip_address INET,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

  CONSTRAINT not_expired CHECK (expires_at > created_at)
);

CREATE INDEX idx_password_reset_tokens_user_id ON password_reset_tokens(user_id);
CREATE INDEX idx_password_reset_tokens_expires_at ON password_reset_tokens(expires_at);
CREATE INDEX idx_password_reset_tokens_is_used ON password_reset_tokens(is_used);

-- ============================================================================
-- 5. PRE-AUTHORIZED USERS TABLE
-- ============================================================================
-- Email addresses approved for owner account creation
-- Must be explicitly added before owner signup is allowed

CREATE TABLE IF NOT EXISTS pre_authorized_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  authorization_type VARCHAR(50) NOT NULL CHECK (authorization_type IN ('owner', 'admin')),
  is_activated BOOLEAN DEFAULT false NOT NULL,
  activated_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_by VARCHAR(255) NOT NULL,

  CONSTRAINT valid_email CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$')
);

CREATE INDEX idx_pre_authorized_users_email ON pre_authorized_users(email);
CREATE INDEX idx_pre_authorized_users_is_activated ON pre_authorized_users(is_activated);

-- ============================================================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all auth tables
ALTER TABLE operational_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE login_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE password_reset_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE pre_authorized_users ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own record
CREATE POLICY "Users view own record" ON operational_users FOR SELECT
  USING (auth.uid()::text = id::text);

-- Policy: Admin L1 can view all operational users
CREATE POLICY "Admin L1 view all users" ON operational_users FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM admin_accounts
      WHERE admin_accounts.id = auth.uid()::uuid
      AND admin_accounts.admin_level = 1
      AND admin_accounts.is_active = true
    )
  );

-- Policy: Owner can view own employees
CREATE POLICY "Owner view employees" ON operational_users FOR SELECT
  USING (
    owner_id = auth.uid()::uuid
    OR id = auth.uid()::uuid
  );

-- Policy: Prevent direct user manipulation (all writes through backend API)
CREATE POLICY "Backend updates users" ON operational_users FOR UPDATE
  USING (false) WITH CHECK (false);

CREATE POLICY "Backend inserts users" ON operational_users FOR INSERT
  WITH CHECK (false);

CREATE POLICY "Backend deletes users" ON operational_users FOR DELETE
  USING (false);

-- Policy: Admin can view audit logs
CREATE POLICY "Admin view audit logs" ON login_audit_log FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM admin_accounts
      WHERE admin_accounts.id = auth.uid()::uuid
      AND admin_accounts.is_active = true
    )
  );

-- ============================================================================
-- 7. HELPER FUNCTIONS
-- ============================================================================

-- Reset failed login attempts
CREATE OR REPLACE FUNCTION reset_login_attempts(user_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE operational_users
  SET failed_login_attempts = 0, locked_until = NULL
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql;

-- Increment failed login attempts and lock if threshold exceeded
CREATE OR REPLACE FUNCTION increment_login_attempts(user_id UUID)
RETURNS TABLE(attempts INT, is_locked BOOLEAN) AS $$
DECLARE
  v_attempts INT;
BEGIN
  UPDATE operational_users
  SET failed_login_attempts = failed_login_attempts + 1,
      locked_until = CASE
        WHEN (failed_login_attempts + 1) >= 5 THEN now() + interval '15 minutes'
        ELSE locked_until
      END
  WHERE id = user_id
  RETURNING failed_login_attempts INTO v_attempts;

  RETURN QUERY SELECT v_attempts, (v_attempts >= 5);
END;
$$ LANGUAGE plpgsql;

-- Check if user is locked out
CREATE OR REPLACE FUNCTION is_user_locked(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM operational_users
    WHERE id = user_id
    AND locked_until IS NOT NULL
    AND locked_until > now()
  );
END;
$$ LANGUAGE plpgsql;

-- Unlock user (auto-unlock after 15 minutes, or admin unlock)
CREATE OR REPLACE FUNCTION unlock_user(user_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE operational_users
  SET locked_until = NULL, failed_login_attempts = 0
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 8. GRANT PERMISSIONS
-- ============================================================================

-- Allow anon user (from backend) to query tables
GRANT SELECT ON operational_users TO anon;
GRANT SELECT ON admin_accounts TO anon;
GRANT INSERT ON login_audit_log TO anon;
GRANT SELECT ON password_reset_tokens TO anon;
GRANT INSERT, UPDATE ON password_reset_tokens TO anon;
GRANT SELECT ON pre_authorized_users TO anon;

-- Allow authenticated users to query own data
GRANT SELECT ON operational_users TO authenticated;
GRANT SELECT ON login_audit_log TO authenticated;

-- ============================================================================
-- 9. TRIGGERS FOR TIMESTAMPS
-- ============================================================================

CREATE OR REPLACE FUNCTION update_operational_users_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_admin_accounts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_operational_users_updated_at
  BEFORE UPDATE ON operational_users
  FOR EACH ROW
  EXECUTE FUNCTION update_operational_users_updated_at();

CREATE TRIGGER trigger_admin_accounts_updated_at
  BEFORE UPDATE ON admin_accounts
  FOR EACH ROW
  EXECUTE FUNCTION update_admin_accounts_updated_at();

-- ============================================================================
-- 10. COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE operational_users IS 'Stores operational user credentials (owner, employee, rider, supplier). Source of truth for authentication.';
COMMENT ON TABLE admin_accounts IS 'Platform admin accounts with role-based hierarchy (L1/L2/L3).';
COMMENT ON TABLE login_audit_log IS 'Audit trail of all login attempts for security monitoring. Deleted after 90 days.';
COMMENT ON TABLE password_reset_tokens IS 'One-time use password reset tokens with 1-hour expiry. Stored as bcrypt hash.';
COMMENT ON TABLE pre_authorized_users IS 'Email addresses pre-approved for owner account creation by admins.';

COMMENT ON COLUMN operational_users.password_hash IS 'Bcrypt hash (12 salt rounds) - never store plaintext passwords.';
COMMENT ON COLUMN operational_users.failed_login_attempts IS 'Counter for brute-force protection. Increments on failed login, resets to 0 on success.';
COMMENT ON COLUMN operational_users.locked_until IS 'User account locked after 5 failed attempts for 15 minutes.';
COMMENT ON COLUMN login_audit_log.ip_address IS 'INET type for geolocation and abuse tracking.';
COMMENT ON COLUMN password_reset_tokens.token_hash IS 'Bcrypt hash of the token. Never store plaintext reset tokens.';
