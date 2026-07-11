-- ============================================================================
-- OPERATIONAL USERS AUTHENTICATION SCHEMA
-- Created: 2026-07-11
-- Purpose: Support Owner, Employee, Delivery Agent, Supplier authentication
--          with Email/ID + Password (not Firebase/Google)
-- ============================================================================

-- ============================================================================
-- 1. OPERATIONAL_USERS TABLE
-- ============================================================================
-- Stores credentials for operational users (Owner, Employee, Rider, Supplier)
-- NOT using Firebase Auth - all credentials in Supabase

CREATE TABLE IF NOT EXISTS operational_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Ownership & Role
  user_type TEXT NOT NULL CHECK (user_type IN ('owner', 'employee', 'rider', 'supplier')),
  owner_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,

  -- Identity
  email TEXT NOT NULL,
  phone TEXT,
  full_name TEXT NOT NULL,

  -- Credentials (NEVER stored plain text)
  password_hash TEXT NOT NULL,
  password_changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  password_expires_at TIMESTAMP,  -- For password rotation policy

  -- Status & Security
  is_active BOOLEAN DEFAULT TRUE,
  is_verified BOOLEAN DEFAULT FALSE,  -- Email verified
  login_attempts INT DEFAULT 0,
  locked_until TIMESTAMP,  -- Account lockout timestamp

  -- Audit Trail
  created_by UUID,  -- Admin or Owner who created this user
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login_at TIMESTAMP,

  -- Device & Security Info (for audit)
  ip_address_on_create TEXT,
  device_info_on_create TEXT,

  UNIQUE(email),
  INDEX idx_operational_users_user_type (user_type),
  INDEX idx_operational_users_owner_id (owner_id),
  INDEX idx_operational_users_email (email),
  INDEX idx_operational_users_is_active (is_active),
  INDEX idx_operational_users_locked_until (locked_until)
);

-- ============================================================================
-- 2. ADMIN_ACCOUNTS TABLE
-- ============================================================================
-- Pre-authorized admin accounts (NOT in Firebase, stored in Supabase)

CREATE TABLE IF NOT EXISTS admin_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Identity
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  full_name TEXT NOT NULL,

  -- Credentials
  password_hash TEXT NOT NULL,
  password_changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  password_expires_at TIMESTAMP,

  -- Permissions & Levels
  admin_level INT DEFAULT 2 CHECK (admin_level IN (1, 2, 3)),
  -- 1 = SuperAdmin (full system access)
  -- 2 = Admin (manage owners, employees)
  -- 3 = Limited Admin (audit & reporting only)

  permissions JSONB DEFAULT '{"can_create_owners": true, "can_manage_system": true}',

  -- Status & Security
  is_active BOOLEAN DEFAULT TRUE,
  login_attempts INT DEFAULT 0,
  locked_until TIMESTAMP,

  -- Audit
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login_at TIMESTAMP,

  INDEX idx_admin_accounts_email (email),
  INDEX idx_admin_accounts_is_active (is_active),
  INDEX idx_admin_accounts_admin_level (admin_level)
);

-- ============================================================================
-- 3. LOGIN_AUDIT_LOG TABLE
-- ============================================================================
-- Track all login attempts (success & failure) for security monitoring

CREATE TABLE IF NOT EXISTS login_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- User Reference
  user_id UUID,
  user_type TEXT,  -- 'customer', 'operational', 'admin'
  user_email TEXT,

  -- Login Details
  login_status TEXT CHECK (login_status IN ('success', 'failed_password', 'failed_not_found', 'account_locked')),
  ip_address TEXT,
  user_agent TEXT,
  device_info JSONB,

  -- Timestamp
  attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_login_audit_user_id (user_id),
  INDEX idx_login_audit_user_email (user_email),
  INDEX idx_login_audit_status (login_status),
  INDEX idx_login_audit_attempted_at (attempted_at)
);

-- ============================================================================
-- 4. PASSWORD_RESET_TOKENS TABLE
-- ============================================================================
-- Store temporary password reset tokens (expires in 1 hour)

CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Token Details
  token_hash TEXT UNIQUE NOT NULL,  -- Hash of the actual token (store hash, not token)
  user_id UUID NOT NULL,
  user_type TEXT NOT NULL,  -- 'operational' or 'admin'

  -- Expiry & Usage
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP DEFAULT (CURRENT_TIMESTAMP + INTERVAL '1 hour'),
  used_at TIMESTAMP,

  INDEX idx_password_reset_tokens_user_id (user_id),
  INDEX idx_password_reset_tokens_expires_at (expires_at)
);

-- ============================================================================
-- 5. MODIFY CUSTOMERS TABLE
-- ============================================================================
-- Add Google Sign-In tracking to existing customers table

ALTER TABLE customers ADD COLUMN IF NOT EXISTS google_id TEXT UNIQUE;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS google_email TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS login_method TEXT DEFAULT 'email' CHECK (login_method IN ('email', 'google'));
ALTER TABLE customers ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS firebase_uid TEXT UNIQUE;

CREATE INDEX IF NOT EXISTS idx_customers_google_id ON customers(google_id);
CREATE INDEX IF NOT EXISTS idx_customers_firebase_uid ON customers(firebase_uid);

-- ============================================================================
-- 6. MODIFY SHOPS TABLE
-- ============================================================================
-- Add owner verification info

ALTER TABLE shops ADD COLUMN IF NOT EXISTS owner_email TEXT;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS owner_phone TEXT;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS owner_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS owner_verified_at TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_shops_owner_email ON shops(owner_email);
CREATE INDEX IF NOT EXISTS idx_shops_owner_verified ON shops(owner_verified);

-- ============================================================================
-- 7. RLS POLICIES
-- ============================================================================

-- ============================================================================
-- operational_users RLS
-- ============================================================================

ALTER TABLE operational_users ENABLE ROW LEVEL SECURITY;

-- Admins can see all operational users
DROP POLICY IF EXISTS "admin_see_all_operational_users" ON operational_users;
CREATE POLICY "admin_see_all_operational_users"
  ON operational_users FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM admin_accounts WHERE id = auth.uid() AND is_active = true)
  );

-- Owners can see their own team (employees, riders, suppliers)
DROP POLICY IF EXISTS "owner_see_own_team" ON operational_users;
CREATE POLICY "owner_see_own_team"
  ON operational_users FOR SELECT
  USING (
    owner_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
  );

-- Users can see themselves
DROP POLICY IF EXISTS "users_see_self_operational" ON operational_users;
CREATE POLICY "users_see_self_operational"
  ON operational_users FOR SELECT
  USING (id = auth.uid());

-- Prevent direct inserts via API (only backend can create)
DROP POLICY IF EXISTS "prevent_inserts_operational_users" ON operational_users;
CREATE POLICY "prevent_inserts_operational_users"
  ON operational_users FOR INSERT
  WITH CHECK (false);

-- ============================================================================
-- admin_accounts RLS
-- ============================================================================

ALTER TABLE admin_accounts ENABLE ROW LEVEL SECURITY;

-- Only superadmins can read admin accounts
DROP POLICY IF EXISTS "superadmin_see_all_admins" ON admin_accounts;
CREATE POLICY "superadmin_see_all_admins"
  ON admin_accounts FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM admin_accounts
            WHERE id = auth.uid() AND admin_level = 1 AND is_active = true)
  );

-- Prevent inserts
DROP POLICY IF EXISTS "prevent_inserts_admin_accounts" ON admin_accounts;
CREATE POLICY "prevent_inserts_admin_accounts"
  ON admin_accounts FOR INSERT
  WITH CHECK (false);

-- ============================================================================
-- login_audit_log RLS (read-only for admins & self)
-- ============================================================================

ALTER TABLE login_audit_log ENABLE ROW LEVEL SECURITY;

-- Admins can read all login logs
DROP POLICY IF EXISTS "admin_read_login_logs" ON login_audit_log;
CREATE POLICY "admin_read_login_logs"
  ON login_audit_log FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM admin_accounts WHERE id = auth.uid() AND is_active = true)
  );

-- Users can read their own login logs
DROP POLICY IF EXISTS "users_read_own_login_logs" ON login_audit_log;
CREATE POLICY "users_read_own_login_logs"
  ON login_audit_log FOR SELECT
  USING (user_id = auth.uid());

-- Prevent direct inserts (backend only)
DROP POLICY IF EXISTS "prevent_inserts_login_audit_log" ON login_audit_log;
CREATE POLICY "prevent_inserts_login_audit_log"
  ON login_audit_log FOR INSERT
  WITH CHECK (false);

-- ============================================================================
-- password_reset_tokens RLS (service role only)
-- ============================================================================

ALTER TABLE password_reset_tokens ENABLE ROW LEVEL SECURITY;

-- Block all direct access
DROP POLICY IF EXISTS "block_password_reset_tokens" ON password_reset_tokens;
CREATE POLICY "block_password_reset_tokens"
  ON password_reset_tokens FOR ALL
  USING (false);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- ============================================================================
-- Function: Increment login attempts & check lockout
-- ============================================================================
CREATE OR REPLACE FUNCTION check_login_lockout(p_user_id UUID, p_user_type TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_attempts INT;
  v_locked_until TIMESTAMP;
BEGIN
  IF p_user_type = 'operational' THEN
    SELECT login_attempts, locked_until INTO v_attempts, v_locked_until
    FROM operational_users WHERE id = p_user_id;

    -- If locked until is in future, return false (account locked)
    IF v_locked_until IS NOT NULL AND v_locked_until > NOW() THEN
      RETURN FALSE;
    END IF;

    RETURN TRUE;
  ELSIF p_user_type = 'admin' THEN
    SELECT login_attempts, locked_until INTO v_attempts, v_locked_until
    FROM admin_accounts WHERE id = p_user_id;

    IF v_locked_until IS NOT NULL AND v_locked_until > NOW() THEN
      RETURN FALSE;
    END IF;

    RETURN TRUE;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- ============================================================================
-- Function: Increment failed login attempts
-- ============================================================================
CREATE OR REPLACE FUNCTION increment_login_attempts(p_user_id UUID, p_user_type TEXT)
RETURNS VOID AS $$
BEGIN
  IF p_user_type = 'operational' THEN
    UPDATE operational_users
    SET login_attempts = login_attempts + 1,
        locked_until = CASE
          WHEN login_attempts + 1 >= 5 THEN NOW() + INTERVAL '15 minutes'
          ELSE locked_until
        END
    WHERE id = p_user_id;
  ELSIF p_user_type = 'admin' THEN
    UPDATE admin_accounts
    SET login_attempts = login_attempts + 1,
        locked_until = CASE
          WHEN login_attempts + 1 >= 5 THEN NOW() + INTERVAL '15 minutes'
          ELSE locked_until
        END
    WHERE id = p_user_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- ============================================================================
-- Function: Reset login attempts on successful login
-- ============================================================================
CREATE OR REPLACE FUNCTION reset_login_attempts(p_user_id UUID, p_user_type TEXT)
RETURNS VOID AS $$
BEGIN
  IF p_user_type = 'operational' THEN
    UPDATE operational_users
    SET login_attempts = 0,
        locked_until = NULL,
        last_login_at = NOW()
    WHERE id = p_user_id;
  ELSIF p_user_type = 'admin' THEN
    UPDATE admin_accounts
    SET login_attempts = 0,
        locked_until = NULL,
        last_login_at = NOW()
    WHERE id = p_user_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- ============================================================================
-- COMMENTS & DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE operational_users IS 'Credentials for Owner, Employee, Rider, Supplier - NOT Firebase Auth';
COMMENT ON TABLE admin_accounts IS 'Pre-authorized admin accounts - centralized access control';
COMMENT ON TABLE login_audit_log IS 'Audit trail for all login attempts (success & failure)';
COMMENT ON TABLE password_reset_tokens IS 'Temporary tokens for password reset (1 hour expiry)';

COMMENT ON COLUMN operational_users.password_hash IS 'Bcrypt hashed password (NEVER plain text)';
COMMENT ON COLUMN operational_users.locked_until IS 'Account locked until this timestamp (security lockout)';
COMMENT ON COLUMN admin_accounts.admin_level IS '1=SuperAdmin, 2=Admin, 3=Limited';
COMMENT ON COLUMN password_reset_tokens.token_hash IS 'Hash of reset token (store hash, not token itself)';
