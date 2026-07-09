-- 011_fix_rpc_types.sql
-- Fixes type mismatch where user_id was UUID in RPCs but TEXT in tables

-- Drop the old UUID ones first
DROP FUNCTION IF EXISTS security.rpc_complete_password_setup(uuid, uuid, text, text, text, text, uuid);
DROP FUNCTION IF EXISTS security.rpc_complete_password_change(uuid, text, text, text, uuid);
DROP FUNCTION IF EXISTS security.rpc_complete_login_success(uuid, text, text, jsonb, text, uuid);
DROP FUNCTION IF EXISTS security.rpc_complete_login_failed(uuid, integer, timestamptz, boolean, timestamptz, text, uuid);
DROP FUNCTION IF EXISTS public.rpc_complete_password_setup(uuid, uuid, text, text, text, text, uuid);
DROP FUNCTION IF EXISTS public.rpc_complete_password_change(uuid, text, text, text, uuid);
DROP FUNCTION IF EXISTS public.rpc_complete_login_success(uuid, text, text, jsonb, text, uuid);
DROP FUNCTION IF EXISTS public.rpc_complete_login_failed(uuid, integer, timestamptz, boolean, timestamptz, text, uuid);
DROP FUNCTION IF EXISTS public.rpc_get_user_role(uuid);

-- 1. Get User Role
CREATE OR REPLACE FUNCTION public.rpc_get_user_role(p_user_id TEXT)
RETURNS JSONB
SECURITY DEFINER
SET search_path = security, public
LANGUAGE plpgsql
AS $$
DECLARE
    v_role TEXT;
    v_status TEXT;
BEGIN
    SELECT role, status INTO v_role, v_status
    FROM security.privileged_credentials
    WHERE user_id = p_user_id;
    
    IF v_role IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN jsonb_build_object(
        'role', v_role,
        'status', v_status
    );
END;
$$;

-- 2. Internal Security RPCs (recreated with TEXT)
CREATE OR REPLACE FUNCTION security.rpc_complete_password_setup(
    p_user_id TEXT,
    p_admin_id TEXT,
    p_hash TEXT,
    p_salt TEXT,
    p_role TEXT,
    p_correlation_id TEXT,
    p_idempotency_key UUID
) RETURNS VOID AS $$
DECLARE
    v_current_version INTEGER;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext(p_user_id));

    SELECT version INTO v_current_version 
    FROM security.privileged_credentials WHERE user_id = p_user_id;

    IF v_current_version IS NULL THEN
        RAISE EXCEPTION 'USER_NOT_FOUND';
    END IF;

    UPDATE security.privileged_credentials
    SET password_hash = p_hash,
        password_salt = p_salt,
        status = 'active',
        last_password_change_at = NOW(),
        requires_password_change = TRUE,
        updated_at = NOW(),
        version = version + 1
    WHERE user_id = p_user_id AND version = v_current_version;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'CONCURRENT_UPDATE_DETECTED';
    END IF;

    INSERT INTO security.audit_logs (event_type, status, user_id, reason, metadata, actor_id, actor_role, idempotency_key)
    VALUES ('PASSWORD_CREATED', 'success', p_user_id, 'admin_setup', jsonb_build_object('correlation_id', p_correlation_id), p_admin_id, p_role, p_idempotency_key)
    ON CONFLICT (idempotency_key) DO NOTHING;

    PERFORM security.emit_security_event('PASSWORD_CREATED', jsonb_build_object('user_id', p_user_id, 'actor_id', p_admin_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';


CREATE OR REPLACE FUNCTION security.rpc_complete_password_change(
    p_user_id TEXT,
    p_new_hash TEXT,
    p_new_salt TEXT,
    p_correlation_id TEXT,
    p_idempotency_key UUID
) RETURNS VOID AS $$
DECLARE
    v_current_version INTEGER;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext(p_user_id));

    SELECT version INTO v_current_version 
    FROM security.privileged_credentials WHERE user_id = p_user_id;

    IF v_current_version IS NULL THEN
        RAISE EXCEPTION 'USER_NOT_FOUND';
    END IF;

    UPDATE security.privileged_credentials
    SET password_hash = p_new_hash,
        password_salt = p_new_salt,
        password_expires_at = NOW() + INTERVAL '90 days',
        last_password_change_at = NOW(),
        requires_password_change = FALSE,
        updated_at = NOW(),
        version = version + 1
    WHERE user_id = p_user_id AND version = v_current_version;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'CONCURRENT_UPDATE_DETECTED';
    END IF;

    INSERT INTO security.password_history (user_id, password_hash, changed_by, reason)
    VALUES (p_user_id, p_new_hash, 'self', 'manual');

    UPDATE security.privileged_sessions
    SET is_active = FALSE,
        revoked_at = NOW(),
        version = version + 1
    WHERE user_id = p_user_id AND is_active = TRUE;

    INSERT INTO security.audit_logs (event_type, status, user_id, reason, metadata, idempotency_key)
    VALUES ('PASSWORD_CHANGED', 'success', p_user_id, 'user_change', jsonb_build_object('correlation_id', p_correlation_id), p_idempotency_key)
    ON CONFLICT (idempotency_key) DO NOTHING;

    PERFORM security.emit_security_event('PASSWORD_CHANGED', jsonb_build_object('user_id', p_user_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';


CREATE OR REPLACE FUNCTION security.rpc_complete_login_success(
    p_user_id TEXT,
    p_email TEXT,
    p_role TEXT,
    p_session_data JSONB,
    p_correlation_id TEXT,
    p_idempotency_key UUID
) RETURNS VOID AS $$
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext(p_user_id));

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

    UPDATE security.rate_limits
    SET failed_attempts = 0,
        last_successful_attempt_at = NOW(),
        cooldown_until = NULL,
        window_attempt_count = 0,
        window_start_at = NOW(),
        updated_at = NOW()
    WHERE user_id = p_user_id;

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

    UPDATE security.privileged_credentials
    SET last_login_at = NOW(),
        version = version + 1
    WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';


CREATE OR REPLACE FUNCTION security.rpc_complete_login_failed(
    p_user_id TEXT,
    p_new_attempts INTEGER,
    p_locked_until TIMESTAMPTZ,
    p_requires_approval BOOLEAN,
    p_window_start TIMESTAMPTZ,
    p_correlation_id TEXT,
    p_idempotency_key UUID
) RETURNS VOID AS $$
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext(p_user_id));

    UPDATE security.rate_limits
    SET failed_attempts = p_new_attempts,
        last_failed_attempt_at = NOW(),
        locked_until = p_locked_until,
        requires_admin_approval = p_requires_approval,
        window_attempt_count = COALESCE(window_attempt_count, 0) + 1,
        window_start_at = p_window_start,
        updated_at = NOW()
    WHERE user_id = p_user_id;

    INSERT INTO security.audit_logs (event_type, status, user_id, reason, metadata, idempotency_key)
    VALUES (
        'LOGIN_FAILED', 'failed', p_user_id, 'invalid_credentials',
        jsonb_build_object('failed_attempts', p_new_attempts, 'locked_until', p_locked_until, 'correlation_id', p_correlation_id),
        p_idempotency_key
    ) ON CONFLICT (idempotency_key) DO NOTHING;

    PERFORM security.emit_security_event('LOGIN_FAILED', jsonb_build_object('user_id', p_user_id, 'attempts', p_new_attempts));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';


-- 3. Public wrappers
CREATE OR REPLACE FUNCTION public.rpc_complete_password_setup(
    p_user_id TEXT,
    p_admin_id TEXT,
    p_hash TEXT,
    p_salt TEXT,
    p_role TEXT,
    p_correlation_id TEXT,
    p_idempotency_key UUID
) RETURNS VOID
SECURITY DEFINER
SET search_path = security, public
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM security.rpc_complete_password_setup(
        p_user_id, p_admin_id, p_hash, p_salt, p_role, p_correlation_id, p_idempotency_key
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_complete_password_change(
    p_user_id TEXT,
    p_new_hash TEXT,
    p_new_salt TEXT,
    p_correlation_id TEXT,
    p_idempotency_key UUID
) RETURNS VOID
SECURITY DEFINER
SET search_path = security, public
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM security.rpc_complete_password_change(
        p_user_id, p_new_hash, p_new_salt, p_correlation_id, p_idempotency_key
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_complete_login_success(
    p_user_id TEXT,
    p_email TEXT,
    p_role TEXT,
    p_session_data JSONB,
    p_correlation_id TEXT,
    p_idempotency_key UUID
) RETURNS VOID
SECURITY DEFINER
SET search_path = security, public
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM security.rpc_complete_login_success(
        p_user_id, p_email, p_role, p_session_data, p_correlation_id, p_idempotency_key
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_complete_login_failed(
    p_user_id TEXT,
    p_new_attempts INTEGER,
    p_locked_until TIMESTAMPTZ,
    p_requires_approval BOOLEAN,
    p_window_start TIMESTAMPTZ,
    p_correlation_id TEXT,
    p_idempotency_key UUID
) RETURNS VOID
SECURITY DEFINER
SET search_path = security, public
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM security.rpc_complete_login_failed(
        p_user_id, p_new_attempts, p_locked_until, p_requires_approval, p_window_start, p_correlation_id, p_idempotency_key
    );
END;
$$;


-- 4. Grants
REVOKE ALL ON FUNCTION public.rpc_get_user_role(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_get_user_role(TEXT) TO service_role;

REVOKE ALL ON FUNCTION public.rpc_complete_password_setup(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_complete_password_setup(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID) TO service_role;

REVOKE ALL ON FUNCTION public.rpc_complete_password_change(TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_complete_password_change(TEXT, TEXT, TEXT, TEXT, UUID) TO service_role;

REVOKE ALL ON FUNCTION public.rpc_complete_login_success(TEXT, TEXT, TEXT, JSONB, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_complete_login_success(TEXT, TEXT, TEXT, JSONB, TEXT, UUID) TO service_role;

REVOKE ALL ON FUNCTION public.rpc_complete_login_failed(TEXT, INTEGER, TIMESTAMPTZ, BOOLEAN, TIMESTAMPTZ, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_complete_login_failed(TEXT, INTEGER, TIMESTAMPTZ, BOOLEAN, TIMESTAMPTZ, TEXT, UUID) TO service_role;

-- Force Schema Cache reload
NOTIFY pgrst, 'reload schema';
