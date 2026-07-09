-- Migration: 20260709000000_phase4_001_redis_rate_limiting.sql
-- Goal: Removes PostgreSQL rate_limits table and updates related RPCs.

-- 1. Drop rpc_complete_login_failed since rate limits are tracked in Redis and audit logging is done via logAudit directly
DROP FUNCTION IF EXISTS security.rpc_complete_login_failed(UUID, INTEGER, TIMESTAMPTZ, BOOLEAN, TIMESTAMPTZ, TEXT, UUID);

-- 2. Update rpc_complete_login_success to remove the rate_limits update
CREATE OR REPLACE FUNCTION security.rpc_complete_login_success(
    p_user_id UUID,
    p_email TEXT,
    p_role TEXT,
    p_session_data JSONB,
    p_correlation_id TEXT,
    p_idempotency_key UUID
) RETURNS VOID AS $$
DECLARE
    v_current_version INTEGER;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext(p_user_id::text));

    -- Session
    INSERT INTO security.privileged_sessions (
        user_id, token_hash, refresh_token_hash, expires_at, 
        ip_address, user_agent, device_id, device_name, app_version, platform, is_active
    ) VALUES (
        p_user_id, 
        p_session_data->>'token_hash', 
        p_session_data->>'refresh_token_hash', 
        (p_session_data->>'expires_at')::timestamptz,
        p_session_data->>'ip_address',
        p_session_data->>'user_agent',
        p_session_data->>'device_id',
        p_session_data->>'device_name',
        p_session_data->>'app_version',
        p_session_data->>'platform',
        TRUE
    );

    -- Rate Limit Reset is now handled in Redis directly by the Edge Function

    -- Audit
    INSERT INTO security.audit_logs (
        event_type, status, user_id, email, role, 
        ip_address, user_agent, device_id, app_version, platform,
        reason, metadata, idempotency_key
    ) VALUES (
        'LOGIN_SUCCESS', 'success', p_user_id, p_email, p_role,
        p_session_data->>'ip_address', p_session_data->>'user_agent', p_session_data->>'device_id', 
        p_session_data->>'app_version', p_session_data->>'platform',
        'login', jsonb_build_object('correlation_id', p_correlation_id), p_idempotency_key
    ) ON CONFLICT (idempotency_key) DO NOTHING;

    -- Update last login
    UPDATE security.privileged_credentials
    SET last_login_at = NOW(),
        version = version + 1
    WHERE user_id = p_user_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- 3. Drop rate_limits table
DROP TABLE IF EXISTS security.rate_limits;
