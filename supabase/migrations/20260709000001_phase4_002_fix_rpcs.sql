-- Fixes type mismatches (TEXT vs UUID) for user_id in login completion
-- and provides public wrappers for security functions since the security schema is not exposed to PostgREST.

CREATE OR REPLACE FUNCTION security.rpc_complete_login_success(
    p_user_id TEXT,
    p_email TEXT,
    p_role TEXT,
    p_session_data JSONB,
    p_correlation_id TEXT,
    p_idempotency_key UUID
) RETURNS VOID AS $$
DECLARE
    v_current_version INTEGER;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext(p_user_id));

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


CREATE OR REPLACE FUNCTION public.rpc_complete_login_success(
    p_user_id TEXT,
    p_email TEXT,
    p_role TEXT,
    p_session_data JSONB,
    p_correlation_id TEXT,
    p_idempotency_key UUID
) RETURNS VOID AS $$
BEGIN
    PERFORM security.rpc_complete_login_success(
        p_user_id, p_email, p_role, p_session_data, p_correlation_id, p_idempotency_key
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'security', 'public';


CREATE OR REPLACE FUNCTION public.rpc_insert_audit_log(
    p_event_type TEXT,
    p_status TEXT,
    p_user_id TEXT,
    p_reason TEXT,
    p_metadata JSONB,
    p_email TEXT DEFAULT NULL,
    p_role TEXT DEFAULT NULL,
    p_ip_address TEXT DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_app_version TEXT DEFAULT NULL,
    p_platform TEXT DEFAULT NULL,
    p_actor_id TEXT DEFAULT NULL,
    p_actor_role TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO security.audit_logs (
        event_type, status, user_id, reason, metadata, email, role,
        ip_address, user_agent, device_id, app_version, platform, actor_id, actor_role
    ) VALUES (
        p_event_type, p_status, p_user_id, p_reason, p_metadata, p_email, p_role,
        p_ip_address, p_user_agent, p_device_id, p_app_version, p_platform, p_actor_id, p_actor_role
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'security', 'public';

-- Drop the old UUID overloads to prevent ambiguous function call errors
DROP FUNCTION IF EXISTS security.rpc_complete_login_success(uuid, text, text, jsonb, text, uuid);
DROP FUNCTION IF EXISTS public.rpc_complete_login_success(uuid, text, text, jsonb, text, uuid);
