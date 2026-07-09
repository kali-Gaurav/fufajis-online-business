-- 013_password_history_rpc.sql
CREATE OR REPLACE FUNCTION public.rpc_get_password_history(p_user_id TEXT, p_limit INTEGER DEFAULT 5)
RETURNS TABLE (password_hash TEXT)
SECURITY DEFINER
SET search_path = security, public
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT ph.password_hash
    FROM security.password_history ph
    WHERE ph.user_id = p_user_id
    ORDER BY ph.created_at DESC
    LIMIT p_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_password_history(TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_get_password_history(TEXT, INTEGER) TO service_role;

NOTIFY pgrst, 'reload schema';
