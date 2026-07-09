CREATE OR REPLACE FUNCTION security.rpc_revoke_all_user_sessions(
    p_user_id TEXT
) RETURNS VOID
SECURITY DEFINER
SET search_path = security, public
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE security.privileged_sessions
    SET is_active = FALSE
    WHERE user_id = p_user_id;
END;
$$;
