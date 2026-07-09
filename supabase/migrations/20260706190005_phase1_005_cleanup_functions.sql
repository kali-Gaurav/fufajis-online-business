-- Phase 1: Database Foundation
-- Cleanup Functions and Maintenance Triggers
-- Purpose: Automatic maintenance of security schema

BEGIN;

-- ==================== SESSION CLEANUP ====================

/**
 * Clean up expired sessions
 * Call periodically (e.g., via cron job)
 */
CREATE OR REPLACE FUNCTION security.cleanup_expired_sessions()
RETURNS TABLE (
  deleted_count INT,
  processed_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
  v_deleted INT;
BEGIN
  DELETE FROM security.privileged_sessions
  WHERE expires_at < now()
  OR (is_active = false AND created_at < now() - INTERVAL '7 days');

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  -- Log cleanup event
  INSERT INTO security.audit_logs (
    event_type, status, user_id, email, reason, metadata
  ) VALUES (
    'SESSION_EXPIRED',
    'success',
    'system',
    'system@fufaji.local',
    'automatic_cleanup',
    jsonb_build_object('sessions_deleted', v_deleted)
  );

  RETURN QUERY SELECT v_deleted, now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- ==================== PASSWORD EXPIRATION CHECK ====================

/**
 * Find credentials with expired passwords
 * Returns list of users whose passwords have expired
 */
CREATE OR REPLACE FUNCTION security.get_expired_passwords()
RETURNS TABLE (
  user_id TEXT,
  email TEXT,
  password_expires_at TIMESTAMP WITH TIME ZONE,
  days_expired INT
) AS $$
  SELECT
    user_id,
    email,
    password_expires_at,
    EXTRACT(DAY FROM (now() - password_expires_at))::INT as days_expired
  FROM security.privileged_credentials
  WHERE status = 'active'
  AND password_expires_at IS NOT NULL
  AND password_expires_at < now()
  ORDER BY password_expires_at DESC;
$$ LANGUAGE sql;

-- ==================== RATE LIMIT RESET ====================

/**
 * Reset rate limit for a user (admin-only operation)
 * Called via Edge Function with proper authorization
 */
CREATE OR REPLACE FUNCTION security.reset_user_rate_limit(
  p_user_id TEXT,
  p_admin_id TEXT
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT
) AS $$
DECLARE
  v_admin_check BOOLEAN;
BEGIN
  -- Verify admin (this is security-critical)
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = p_admin_id
    AND role IN ('admin', 'shopOwner')
  ) INTO v_admin_check;

  IF NOT v_admin_check THEN
    RETURN QUERY SELECT false::BOOLEAN, 'Unauthorized: caller is not admin'::TEXT;
    RETURN;
  END IF;

  -- Reset rate limit
  UPDATE security.rate_limits
  SET
    failed_attempts = 0,
    locked_until = NULL,
    requires_admin_approval = false,
    window_attempt_count = 0,
    window_start_at = now(),
    updated_at = now()
  WHERE user_id = p_user_id;

  -- Log the action
  INSERT INTO security.audit_logs (
    event_type, status, user_id, actor_id, reason, metadata
  ) VALUES (
    'ACCOUNT_UNLOCKED',
    'success',
    p_user_id,
    p_admin_id,
    'admin_reset',
    jsonb_build_object('reason', 'admin_override')
  );

  RETURN QUERY SELECT true::BOOLEAN, 'Rate limit reset successfully'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- ==================== ACCOUNT STATUS CHECK ====================

/**
 * Get account status (helper for Edge Functions)
 * Returns comprehensive status information for a user
 */
CREATE OR REPLACE FUNCTION security.get_account_status(p_user_id TEXT)
RETURNS TABLE (
  user_id TEXT,
  email TEXT,
  role TEXT,
  status TEXT,
  is_locked BOOLEAN,
  lock_until TIMESTAMP WITH TIME ZONE,
  requires_password_change BOOLEAN,
  password_expires_at TIMESTAMP WITH TIME ZONE,
  last_login_at TIMESTAMP WITH TIME ZONE,
  active_sessions_count INT
) AS $$
  SELECT
    c.user_id,
    c.email,
    c.role,
    c.status,
    (r.locked_until IS NOT NULL AND r.locked_until > now())::BOOLEAN as is_locked,
    r.locked_until,
    c.requires_password_change,
    c.password_expires_at,
    c.last_login_at,
    (SELECT COUNT(*) FROM security.privileged_sessions
     WHERE user_id = p_user_id AND is_active = true AND expires_at > now())::INT as active_sessions_count
  FROM security.privileged_credentials c
  LEFT JOIN security.rate_limits r ON c.user_id = r.user_id
  WHERE c.user_id = p_user_id;
$$ LANGUAGE sql;

-- ==================== AUDIT LOG RETENTION ====================

/**
 * Archive old audit logs (for compliance and storage optimization)
 * Call periodically to move old logs out of hot storage
 */
CREATE OR REPLACE FUNCTION security.archive_old_audit_logs(
  p_days_old INT DEFAULT 90
)
RETURNS TABLE (
  archived_count INT,
  processed_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
  v_cutoff TIMESTAMP WITH TIME ZONE;
  v_count INT;
BEGIN
  v_cutoff := now() - (p_days_old || ' days')::INTERVAL;

  -- In production, you'd copy these to archive table or separate storage
  -- For now, we just track the count
  SELECT COUNT(*) INTO v_count
  FROM security.audit_logs
  WHERE created_at < v_cutoff;

  RETURN QUERY SELECT v_count, now();
END;
$$ LANGUAGE plpgsql;

-- ==================== PASSWORD HISTORY MAINTENANCE ====================

/**
 * Trigger to enforce password history limit
 * Prevents storing more than max_password_history passwords per user
 */
CREATE OR REPLACE FUNCTION security.enforce_password_history_limit()
RETURNS TRIGGER AS $$
DECLARE
  v_max_history INT;
  v_excess_count INT;
BEGIN
  -- Get the max history setting for this user
  SELECT max_password_history INTO v_max_history
  FROM security.privileged_credentials
  WHERE user_id = NEW.user_id;

  -- Remove excess history (keep only the most recent max_password_history)
  DELETE FROM security.password_history
  WHERE user_id = NEW.user_id
  AND id NOT IN (
    SELECT id FROM security.password_history
    WHERE user_id = NEW.user_id
    ORDER BY changed_at DESC
    LIMIT v_max_history
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_enforce_password_history
  AFTER INSERT ON security.password_history
  FOR EACH ROW
  EXECUTE FUNCTION security.enforce_password_history_limit();

-- ==================== PREVENT DIRECT TABLE MODIFICATIONS ====================

/**
 * Critical: Prevent any direct modifications to audit_logs
 * These must go through Edge Functions only
 */
CREATE OR REPLACE FUNCTION security.prevent_audit_modification()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'Audit logs cannot be modified. Contact system administrator.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_prevent_audit_modification
  BEFORE UPDATE OR DELETE ON security.audit_logs
  FOR EACH ROW
  EXECUTE FUNCTION security.prevent_audit_modification();

-- ==================== DATABASE MAINTENANCE MONITORING ====================

/**
 * Get schema statistics for monitoring
 * Useful for capacity planning and health checks
 */
CREATE OR REPLACE FUNCTION security.get_schema_statistics()
RETURNS TABLE (
  table_name TEXT,
  row_count BIGINT,
  size_mb NUMERIC,
  last_vacuum TIMESTAMP WITH TIME ZONE,
  last_autovacuum TIMESTAMP WITH TIME ZONE
) AS $$
  SELECT
    schemaname || '.' || relname,
    n_live_tup,
    round((pg_total_relation_size(schemaname || '.' || relname) / 1048576.0)::NUMERIC, 2),
    last_vacuum,
    last_autovacuum
  FROM pg_stat_user_tables
  WHERE schemaname = 'security'
  ORDER BY n_live_tup DESC;
$$ LANGUAGE sql;

-- ==================== TRACK FINAL MIGRATION ====================

INSERT INTO security.schema_metadata (version, migration_name, description)
VALUES (
  '1.7.0',
  '008_cleanup_functions_and_triggers',
  'Add maintenance functions and triggers for security schema'
) ON CONFLICT (version) DO NOTHING;

-- ==================== FINAL VERIFICATION ====================

-- Verify RLS is enabled on all tables
/*
SELECT
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE schemaname = 'security'
ORDER BY tablename;

-- All should show rowsecurity = true
*/

-- Show schema version
/*
SELECT security.get_schema_version();
-- Should show: 1.7.0
*/

-- Show all migrations applied
/*
SELECT * FROM security.list_migrations();
*/

COMMIT;
