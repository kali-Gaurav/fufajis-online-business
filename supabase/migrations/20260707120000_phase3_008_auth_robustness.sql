-- Migration: 20260707120000_phase3_008_auth_robustness.sql
-- Goal: Adds optimistic concurrency, idempotency constraints, strict CHECKs, and transactional RPCs for auth-core.

-- 1. Optimistic Concurrency and Constraints
ALTER TABLE security.privileged_credentials 
ADD COLUMN version INTEGER DEFAULT 1 NOT NULL;

ALTER TABLE security.privileged_sessions
ADD COLUMN version INTEGER DEFAULT 1 NOT NULL;

-- 2. Idempotency Keys and Event Queue Prep
ALTER TABLE security.audit_logs
ADD COLUMN idempotency_key UUID UNIQUE;

CREATE TABLE security.security_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    processed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE security.security_events ENABLE ROW LEVEL SECURITY;

-- Additional Strict Checks
ALTER TABLE security.rate_limits
ADD CONSTRAINT chk_rate_limits_failed_attempts CHECK (failed_attempts >= 0),
ADD CONSTRAINT chk_rate_limits_locked_until CHECK (locked_until > now() OR locked_until IS NULL);

ALTER TABLE security.privileged_sessions
ADD CONSTRAINT chk_session_expiry CHECK (expires_at > created_at);


-- 3. Stored Procedures (RPCs)

-- Helper to emit security event
CREATE OR REPLACE FUNCTION security.emit_security_event(p_event_type TEXT, p_payload JSONB)
RETURNS VOID AS $$
BEGIN
    INSERT INTO security.security_events (event_type, payload) VALUES (p_event_type, p_payload);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';


-- RPC: Complete Password Setup
CREATE OR REPLACE FUNCTION security.rpc_complete_password_setup(
    p_user_id UUID,
    p_admin_id UUID,
    p_hash TEXT,
    p_salt TEXT,
    p_role TEXT,
    p_correlation_id TEXT,
    p_idempotency_key UUID
) RETURNS VOID AS $$
DECLARE
    v_current_version INTEGER;
BEGIN
    -- Advisory Lock to prevent concurrent setups for the same user
    PERFORM pg_advisory_xact_lock(hashtext(p_user_id::text));

    -- Optimistic Concurrency check
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


-- RPC: Complete Password Change
CREATE OR REPLACE FUNCTION security.rpc_complete_password_change(
    p_user_id UUID,
    p_new_hash TEXT,
    p_new_salt TEXT,
    p_correlation_id TEXT,
    p_idempotency_key UUID
) RETURNS VOID AS $$
DECLARE
    v_current_version INTEGER;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext(p_user_id::text));

    SELECT version INTO v_current_version 
    FROM security.privileged_credentials WHERE user_id = p_user_id;

    IF v_current_version IS NULL THEN
        RAISE EXCEPTION 'USER_NOT_FOUND';
    END IF;

    -- Update credential
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

    -- History
    INSERT INTO security.password_history (user_id, password_hash, changed_by, reason)
    VALUES (p_user_id, p_new_hash, 'self', 'manual');

    -- Session Invalidation
    UPDATE security.privileged_sessions
    SET is_active = FALSE,
        revoked_at = NOW(),
        version = version + 1
    WHERE user_id = p_user_id AND is_active = TRUE;

    -- Audit
    INSERT INTO security.audit_logs (event_type, status, user_id, reason, metadata, idempotency_key)
    VALUES ('PASSWORD_CHANGED', 'success', p_user_id, 'user_change', jsonb_build_object('correlation_id', p_correlation_id), p_idempotency_key)
    ON CONFLICT (idempotency_key) DO NOTHING;

    PERFORM security.emit_security_event('PASSWORD_CHANGED', jsonb_build_object('user_id', p_user_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';


-- RPC: Complete Login Success
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

    -- Rate Limit Reset
    UPDATE security.rate_limits
    SET failed_attempts = 0,
        last_successful_attempt_at = NOW(),
        cooldown_until = NULL,
        window_attempt_count = 0,
        window_start_at = NOW(),
        updated_at = NOW()
    WHERE user_id = p_user_id;

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


-- RPC: Complete Login Failed
CREATE OR REPLACE FUNCTION security.rpc_complete_login_failed(
    p_user_id UUID,
    p_new_attempts INTEGER,
    p_locked_until TIMESTAMPTZ,
    p_requires_approval BOOLEAN,
    p_window_start TIMESTAMPTZ,
    p_correlation_id TEXT,
    p_idempotency_key UUID
) RETURNS VOID AS $$
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext(p_user_id::text));

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
        'LOGIN_FAILED', 'blocked', p_user_id, 'failed_attempt_' || p_new_attempts::text,
        jsonb_build_object(
            'attempt_number', p_new_attempts,
            'correlation_id', p_correlation_id
        ),
        p_idempotency_key
    ) ON CONFLICT (idempotency_key) DO NOTHING;

    IF p_locked_until > NOW() THEN
        PERFORM security.emit_security_event('ACCOUNT_LOCKED', jsonb_build_object('user_id', p_user_id));
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
