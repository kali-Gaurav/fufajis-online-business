-- Phase 2: Security Layer
-- Migration 001: Row-Level Security (RLS) Policies
-- Purpose: Database-level access control - users see/modify only authorized data

BEGIN;

-- ==================== AUTHORIZATION HELPER FUNCTIONS ====================

/**
 * Check if current user is admin
 * Used by RLS policies to determine admin access
 */
CREATE OR REPLACE FUNCTION security.is_current_user_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
    AND role IN ('admin', 'shopOwner')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

/**
 * Check if current user owns a record
 * Used by RLS policies for user isolation
 */
CREATE OR REPLACE FUNCTION security.user_owns_record(record_user_id TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN record_user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

/**
 * Check if caller is service role
 * Used for Edge Function operations
 */
CREATE OR REPLACE FUNCTION security.is_service_role()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN auth.role() = 'service_role';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- ==================== PRIVILEGED_CREDENTIALS ====================

-- Users can read only their own credentials
CREATE POLICY "user_read_own_credentials"
  ON security.privileged_credentials
  FOR SELECT
  USING (security.user_owns_record(user_id));

-- Admins can read all credentials
CREATE POLICY "admin_read_all_credentials"
  ON security.privileged_credentials
  FOR SELECT
  USING (security.is_current_user_admin());

-- Service role (Edge Functions) can do everything
CREATE POLICY "service_manage_credentials"
  ON security.privileged_credentials
  FOR ALL
  USING (security.is_service_role())
  WITH CHECK (security.is_service_role());

-- **CRITICAL**: No other writes allowed
CREATE POLICY "prevent_direct_credential_writes"
  ON security.privileged_credentials
  FOR INSERT
  WITH CHECK (false);

CREATE POLICY "prevent_direct_credential_updates"
  ON security.privileged_credentials
  FOR UPDATE
  USING (false);

CREATE POLICY "prevent_direct_credential_deletes"
  ON security.privileged_credentials
  FOR DELETE
  USING (false);

-- ==================== PRIVILEGED_SESSIONS ====================

-- Users can read only their own sessions
CREATE POLICY "user_read_own_sessions"
  ON security.privileged_sessions
  FOR SELECT
  USING (security.user_owns_record(user_id));

-- Admins can read all sessions
CREATE POLICY "admin_read_all_sessions"
  ON security.privileged_sessions
  FOR SELECT
  USING (security.is_current_user_admin());

-- Service role can manage sessions
CREATE POLICY "service_manage_sessions"
  ON security.privileged_sessions
  FOR ALL
  USING (security.is_service_role())
  WITH CHECK (security.is_service_role());

-- No direct client writes
CREATE POLICY "prevent_direct_session_writes"
  ON security.privileged_sessions
  FOR INSERT
  WITH CHECK (false);

CREATE POLICY "prevent_direct_session_updates"
  ON security.privileged_sessions
  FOR UPDATE
  USING (false);

CREATE POLICY "prevent_direct_session_deletes"
  ON security.privileged_sessions
  FOR DELETE
  USING (false);

-- ==================== PRIVILEGED_DEVICES ====================

-- Users can read only their own devices
CREATE POLICY "user_read_own_devices"
  ON security.privileged_devices
  FOR SELECT
  USING (security.user_owns_record(user_id));

-- Admins can read all devices
CREATE POLICY "admin_read_all_devices"
  ON security.privileged_devices
  FOR SELECT
  USING (security.is_current_user_admin());

-- Service role can manage devices
CREATE POLICY "service_manage_devices"
  ON security.privileged_devices
  FOR ALL
  USING (security.is_service_role())
  WITH CHECK (security.is_service_role());

-- No direct client writes
CREATE POLICY "prevent_direct_device_writes"
  ON security.privileged_devices
  FOR INSERT
  WITH CHECK (false);

CREATE POLICY "prevent_direct_device_updates"
  ON security.privileged_devices
  FOR UPDATE
  USING (false);

CREATE POLICY "prevent_direct_device_deletes"
  ON security.privileged_devices
  FOR DELETE
  USING (false);

-- ==================== RATE_LIMITS ====================

-- Users can read their own rate limits (informational)
CREATE POLICY "user_read_own_rate_limits"
  ON security.rate_limits
  FOR SELECT
  USING (security.user_owns_record(user_id));

-- Admins can read all rate limits
CREATE POLICY "admin_read_all_rate_limits"
  ON security.rate_limits
  FOR SELECT
  USING (security.is_current_user_admin());

-- **CRITICAL**: NO direct client writes to rate_limits
-- Only service role can modify
CREATE POLICY "prevent_client_rate_limit_writes"
  ON security.rate_limits
  FOR INSERT
  WITH CHECK (false);

CREATE POLICY "prevent_client_rate_limit_updates"
  ON security.rate_limits
  FOR UPDATE
  USING (false);

CREATE POLICY "prevent_client_rate_limit_deletes"
  ON security.rate_limits
  FOR DELETE
  USING (false);

-- Service role (Edge Functions) can manage
CREATE POLICY "service_manage_rate_limits"
  ON security.rate_limits
  FOR ALL
  USING (security.is_service_role())
  WITH CHECK (security.is_service_role());

-- ==================== AUDIT_LOGS ====================

-- Users can read only their own audit logs
CREATE POLICY "user_read_own_audit_logs"
  ON security.audit_logs
  FOR SELECT
  USING (security.user_owns_record(user_id));

-- Admins can read all audit logs
CREATE POLICY "admin_read_all_audit_logs"
  ON security.audit_logs
  FOR SELECT
  USING (security.is_current_user_admin());

-- **CRITICAL**: NO direct writes to audit_logs from any role
CREATE POLICY "prevent_client_audit_inserts"
  ON security.audit_logs
  FOR INSERT
  WITH CHECK (false);

CREATE POLICY "prevent_client_audit_updates"
  ON security.audit_logs
  FOR UPDATE
  USING (false);

CREATE POLICY "prevent_client_audit_deletes"
  ON security.audit_logs
  FOR DELETE
  USING (false);

-- Service role (Edge Functions) can INSERT only
-- Updates/deletes are prevented by trigger
CREATE POLICY "service_create_audit_logs"
  ON security.audit_logs
  FOR INSERT
  WITH CHECK (security.is_service_role());

-- ==================== PASSWORD_HISTORY ====================

-- Users can read only their own history (informational)
CREATE POLICY "user_read_own_password_history"
  ON security.password_history
  FOR SELECT
  USING (security.user_owns_record(user_id));

-- Admins can read all history
CREATE POLICY "admin_read_all_password_history"
  ON security.password_history
  FOR SELECT
  USING (security.is_current_user_admin());

-- **CRITICAL**: NO direct client writes
CREATE POLICY "prevent_client_history_inserts"
  ON security.password_history
  FOR INSERT
  WITH CHECK (false);

CREATE POLICY "prevent_client_history_updates"
  ON security.password_history
  FOR UPDATE
  USING (false);

CREATE POLICY "prevent_client_history_deletes"
  ON security.password_history
  FOR DELETE
  USING (false);

-- Service role can manage
CREATE POLICY "service_manage_password_history"
  ON security.password_history
  FOR ALL
  USING (security.is_service_role())
  WITH CHECK (security.is_service_role());

-- ==================== SCHEMA_METADATA ====================

-- Only admins and service role can read schema metadata
CREATE POLICY "admin_read_schema_metadata"
  ON security.schema_metadata
  FOR SELECT
  USING (security.is_current_user_admin() OR security.is_service_role());

-- No direct writes to schema metadata
CREATE POLICY "prevent_schema_metadata_insert"
  ON security.schema_metadata
  FOR INSERT
  WITH CHECK (false);

CREATE POLICY "prevent_schema_metadata_update"
  ON security.schema_metadata
  FOR UPDATE
  USING (false);

CREATE POLICY "prevent_schema_metadata_delete"
  ON security.schema_metadata
  FOR DELETE
  USING (false);

-- Service role can manage (for migrations)
CREATE POLICY "service_manage_schema_metadata"
  ON security.schema_metadata
  FOR ALL
  USING (security.is_service_role())
  WITH CHECK (security.is_service_role());

-- ==================== TRACK MIGRATION ====================

INSERT INTO security.schema_metadata (version, migration_name, description)
VALUES (
  '2.0.0',
  '001_row_level_security_policies',
  'Implement RLS policies for database-level access control'
) ON CONFLICT (version) DO NOTHING;

-- ==================== VERIFICATION ====================

/*
AFTER DEPLOYMENT, RUN THESE TESTS:

-- Test 1: Regular user sees only own data
SET ROLE authenticated;
SET SESSION "request.jwt.claims" = '{"sub":"user-123"}';
SELECT user_id FROM security.privileged_credentials;
-- Should return only records where user_id = 'user-123'

-- Test 2: Admin sees all data
SET ROLE authenticated;
SET SESSION "request.jwt.claims" = '{"sub":"admin-456"}';
-- (Assume admin-456 has role='admin' in public.users)
SELECT COUNT(*) FROM security.privileged_credentials;
-- Should return count of ALL records

-- Test 3: Regular user cannot write
SET ROLE authenticated;
SET SESSION "request.jwt.claims" = '{"sub":"user-789"}';
INSERT INTO security.privileged_credentials (user_id, email, role, password_hash)
VALUES ('user-789', 'test@example.com', 'employee', 'hash');
-- Should FAIL with: new row violates row-level security policy

-- Test 4: Regular user cannot modify rate_limits
SET ROLE authenticated;
SET SESSION "request.jwt.claims" = '{"sub":"user-789"}';
UPDATE security.rate_limits SET failed_attempts = 1 WHERE user_id = 'user-789';
-- Should FAIL: insufficient privilege for UPDATE on rate_limits

-- Test 5: Service role can do everything
SET ROLE service_role;
INSERT INTO security.privileged_credentials (user_id, email, role, password_hash)
VALUES ('service-test', 'service@test.local', 'admin', 'hash');
-- Should succeed

UPDATE security.rate_limits
SET failed_attempts = 5
WHERE user_id = 'service-test';
-- Should succeed

DELETE FROM security.privileged_credentials WHERE user_id = 'service-test';
-- Should succeed
*/

COMMIT;
