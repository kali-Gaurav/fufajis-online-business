import { createClient } from 'npm:@supabase/supabase-js';
import { Redis } from 'npm:@upstash/redis';
import { LoginRequest, LoginResponse } from '../types/index.ts';
import { isValidEmail } from '../utils/validation.ts';
import { checkRateLimit, recordFailedAttempt, resetRateLimit } from '../services/rate_limit.ts';
import { verifyPassword, generateToken, hashToken } from '../services/password.ts';
import { callRpcWithRetry } from '../utils/db.ts';

export async function handleLogin(
  supabase: ReturnType<typeof createClient>,
  redis: Redis,
  req: LoginRequest,
  correlationId: string,
  idempotencyKey: string
): Promise<LoginResponse> {
  if (!isValidEmail(req.email)) {
    return { success: false, message: 'Invalid email format', error_code: 'INVALID_EMAIL' };
  }

  const rateInfo = await checkRateLimit(redis, supabase, req.email);

  if (rateInfo.is_locked) {
    return {
      success: false,
      message: 'Account locked due to too many failed attempts',
      error_code: 'ACCOUNT_LOCKED'
    };
  }

  if (rateInfo.requires_admin_approval) {
    return {
      success: false,
      message: 'Account requires admin approval to unlock',
      error_code: 'ADMIN_APPROVAL_REQUIRED'
    };
  }

  let credential;
  try {
    credential = await callRpcWithRetry(
      supabase,
      'rpc_get_credential_by_email',
      { p_email: req.email }
    );
  } catch (credError: any) {
    if (rateInfo.user_id) {
      await recordFailedAttemptLog(supabase, redis, rateInfo, correlationId, idempotencyKey);
    }
    return { success: false, message: 'Invalid credentials', error_code: 'INVALID_CREDENTIALS', debug: { reason: 'db_error' } };
  }

  if (!credential) {
    if (rateInfo.user_id) {
      await recordFailedAttemptLog(supabase, redis, rateInfo, correlationId, idempotencyKey);
    }
    return { success: false, message: 'Invalid credentials', error_code: 'INVALID_CREDENTIALS', debug: { reason: 'not_found' } };
  }

  if (credential.status !== 'active') {
    return {
      success: false,
      message: `Credential status: ${credential.status}`,
      error_code: `CREDENTIAL_${credential.status.toUpperCase()}`
    };
  }

  const passwordValid = await verifyPassword(
    req.password,
    credential.password_hash,
    credential.password_salt
  );

  if (!passwordValid) {
    await recordFailedAttemptLog(supabase, redis, rateInfo, correlationId, idempotencyKey);
    return { success: false, message: 'Invalid credentials', error_code: 'INVALID_CREDENTIALS', debug: { reason: 'password_invalid' } };
  }

  // Clear rate limits upon successful login
  await resetRateLimit(redis, credential.user_id);

  const token = generateToken();
  const tokenHash = await hashToken(token);
  const refreshToken = generateToken();
  const refreshTokenHash = await hashToken(refreshToken);

  const sessionData = {
    token_hash: tokenHash,
    refresh_token_hash: refreshTokenHash,
    expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    ip_address: req.ip_address,
    user_agent: req.user_agent,
    device_id: req.device_id,
    device_name: req.device_name,
    app_version: req.app_version,
    platform: req.platform
  };

  try {
    await callRpcWithRetry(
      supabase,
      'rpc_complete_login_success',
      {
        p_user_id: credential.user_id,
        p_email: req.email,
        p_role: credential.role,
        p_session_data: sessionData,
        p_correlation_id: correlationId,
        p_idempotency_key: idempotencyKey
      }
    );
  } catch (error) {
    console.error('RPC Error:', error);
    throw error;
  }

  return {
    success: true,
    user_id: credential.user_id,
    email: credential.email,
    role: credential.role,
    token,
    refresh_token: refreshToken,
    requires_password_change: credential.requires_password_change,
    message: 'Login successful'
  };
}

import { logAudit } from '../services/audit.ts';

async function recordFailedAttemptLog(
  supabase: ReturnType<typeof createClient>,
  redis: Redis,
  rateInfo: any,
  correlationId: string,
  idempotencyKey: string
) {
  // Update redis tracking
  await recordFailedAttempt(redis, rateInfo.user_id);
  
  // Insert audit log
  await logAudit(
    supabase,
    'LOGIN_FAILED',
    'blocked',
    rateInfo.user_id,
    { reason: 'invalid_credentials' },
    { correlation_id: correlationId, idempotency_key: idempotencyKey }
  );
}
