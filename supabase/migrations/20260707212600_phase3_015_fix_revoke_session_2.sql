CREATE OR REPLACE FUNCTION security.rpc_complete_password_change(
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
DECLARE
    v_current_version INTEGER;
BEGIN
    SELECT version INTO v_current_version
    FROM security.privileged_credentials
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_current_version IS NULL THEN
        RAISE EXCEPTION 'USER_NOT_FOUND';
    END IF;

    UPDATE security.privileged_credentials
    SET password_hash = p_new_hash,
        password_salt = p_new_salt,
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
    SET is_active = FALSE
    WHERE user_id = p_user_id AND is_active = TRUE;

    INSERT INTO security.audit_logs (event_type, status, user_id, reason, metadata, idempotency_key)
    VALUES ('PASSWORD_CHANGED', 'success', p_user_id, 'user_change', jsonb_build_object('correlation_id', p_correlation_id), p_idempotency_key)
    ON CONFLICT (idempotency_key) DO NOTHING;

    PERFORM security.emit_security_event('PASSWORD_CHANGED', jsonb_build_object('user_id', p_user_id));
END;
$$;
