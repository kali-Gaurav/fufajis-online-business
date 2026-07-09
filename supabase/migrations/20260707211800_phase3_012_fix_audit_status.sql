CREATE OR REPLACE FUNCTION security.rpc_complete_login_failed(
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
    UPDATE security.rate_limits
    SET failed_attempts = p_new_attempts,
        locked_until = p_locked_until,
        requires_admin_approval = p_requires_approval,
        window_attempt_count = window_attempt_count + 1,
        window_start_at = p_window_start,
        updated_at = NOW()
    WHERE user_id = p_user_id::UUID;

    INSERT INTO security.audit_logs (event_type, status, user_id, reason, metadata, idempotency_key)
    VALUES (
        'LOGIN_FAILED', 'failed', p_user_id, 'invalid_credentials',
        jsonb_build_object('failed_attempts', p_new_attempts, 'locked_until', p_locked_until, 'correlation_id', p_correlation_id),
        p_idempotency_key
    ) ON CONFLICT (idempotency_key) DO NOTHING;
END;
$$;
