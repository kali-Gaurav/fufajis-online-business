-- 012_auth_login_rpcs.sql
-- Create RPCs for fetching data from security schema for login and password change

-- 1. Get Credential by Email (used by login.ts)
CREATE OR REPLACE FUNCTION public.rpc_get_credential_by_email(p_email TEXT)
RETURNS JSONB
SECURITY DEFINER
SET search_path = security, public
LANGUAGE plpgsql
AS $$
DECLARE
    v_cred RECORD;
BEGIN
    SELECT user_id, password_hash, password_salt, status, role
    INTO v_cred
    FROM security.privileged_credentials
    WHERE email = p_email;
    
    IF v_cred IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN jsonb_build_object(
        'user_id', v_cred.user_id,
        'password_hash', v_cred.password_hash,
        'password_salt', v_cred.password_salt,
        'status', v_cred.status,
        'role', v_cred.role
    );
END;
$$;

-- 2. Get Credential by User ID (used by password_change.ts)
CREATE OR REPLACE FUNCTION public.rpc_get_credential_by_user_id(p_user_id TEXT)
RETURNS JSONB
SECURITY DEFINER
SET search_path = security, public
LANGUAGE plpgsql
AS $$
DECLARE
    v_cred RECORD;
BEGIN
    SELECT password_hash, password_salt, status, requires_password_change
    INTO v_cred
    FROM security.privileged_credentials
    WHERE user_id = p_user_id;
    
    IF v_cred IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN jsonb_build_object(
        'password_hash', v_cred.password_hash,
        'password_salt', v_cred.password_salt,
        'status', v_cred.status,
        'requires_password_change', v_cred.requires_password_change
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_credential_by_email(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_get_credential_by_email(TEXT) TO service_role;

REVOKE ALL ON FUNCTION public.rpc_get_credential_by_user_id(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_get_credential_by_user_id(TEXT) TO service_role;

NOTIFY pgrst, 'reload schema';
