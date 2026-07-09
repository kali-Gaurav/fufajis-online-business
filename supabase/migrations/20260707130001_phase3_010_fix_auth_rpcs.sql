-- 010_fix_auth_rpcs.sql
-- Exposes internal security RPCs and tables to the Edge Function (service_role only) via the public schema.

DROP FUNCTION IF EXISTS public.rpc_complete_password_setup(uuid, text, text, text, text, text, text);
DROP FUNCTION IF EXISTS public.rpc_complete_password_change(uuid, text, text, text, text);
DROP FUNCTION IF EXISTS public.rpc_complete_login_success(uuid, text, text, text, text);
DROP FUNCTION IF EXISTS public.rpc_complete_login_failed(uuid, integer, timestamptz, boolean, timestamptz, text, text);


-- 1. Get User Role (For Edge Function JWT middleware)
CREATE OR REPLACE FUNCTION public.rpc_get_user_role(p_user_id UUID)
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

-- 2. Wrappers for the Auth RPCs
CREATE OR REPLACE FUNCTION public.rpc_complete_password_setup(
    p_user_id UUID,
    p_admin_id UUID,
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
    p_user_id UUID,
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
    p_user_id UUID,
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
    p_user_id UUID,
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

-- 3. Security (Restrict to service_role)
REVOKE ALL ON FUNCTION public.rpc_get_user_role(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_get_user_role(UUID) TO service_role;

REVOKE ALL ON FUNCTION public.rpc_complete_password_setup(UUID, UUID, TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_complete_password_setup(UUID, UUID, TEXT, TEXT, TEXT, TEXT, UUID) TO service_role;

REVOKE ALL ON FUNCTION public.rpc_complete_password_change(UUID, TEXT, TEXT, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_complete_password_change(UUID, TEXT, TEXT, TEXT, UUID) TO service_role;

REVOKE ALL ON FUNCTION public.rpc_complete_login_success(UUID, TEXT, TEXT, JSONB, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_complete_login_success(UUID, TEXT, TEXT, JSONB, TEXT, UUID) TO service_role;

REVOKE ALL ON FUNCTION public.rpc_complete_login_failed(UUID, INTEGER, TIMESTAMPTZ, BOOLEAN, TIMESTAMPTZ, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_complete_login_failed(UUID, INTEGER, TIMESTAMPTZ, BOOLEAN, TIMESTAMPTZ, TEXT, UUID) TO service_role;
