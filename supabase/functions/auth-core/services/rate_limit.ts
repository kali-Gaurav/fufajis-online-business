import { createClient } from 'npm:@supabase/supabase-js';
import { Redis } from 'npm:@upstash/redis';
import { RateLimitInfo } from '../types/index.ts';
import { callRpcWithRetry } from '../utils/db.ts';

const ATTEMPT_WINDOW_SECONDS = 60 * 60; // 1 hour

export async function checkRateLimit(
  redis: Redis,
  supabase: ReturnType<typeof createClient>,
  email: string
): Promise<RateLimitInfo> {
  // First get the user ID for this email
  let cred;
  try {
    cred = await callRpcWithRetry(supabase, 'rpc_get_credential_by_email', { p_email: email });
  } catch (error) {
    // Ignore db errors here
  }

  if (!cred || !cred.user_id) {
    return {
      user_id: '',
      failed_attempts: 0,
      is_locked: false,
      requires_admin_approval: false,
      message: 'User not found'
    };
  }

  const userId = cred.user_id;
  const attemptsKey = `auth:rate_limit:${userId}:attempts`;
  const lockedKey = `auth:rate_limit:${userId}:locked`;
  const adminLockKey = `auth:rate_limit:${userId}:admin_lock`;

  // Check locks
  const [isLocked, adminLock, attemptsStr] = await Promise.all([
    redis.get(lockedKey),
    redis.get(adminLockKey),
    redis.get(attemptsKey)
  ]);

  if (adminLock) {
    return {
      user_id: userId,
      failed_attempts: parseInt(String(attemptsStr || '0'), 10),
      is_locked: true,
      requires_admin_approval: true,
      message: 'Account requires admin approval to unlock'
    };
  }

  if (isLocked) {
    return {
      user_id: userId,
      failed_attempts: parseInt(String(attemptsStr || '0'), 10),
      is_locked: true,
      requires_admin_approval: false,
      message: 'Account locked due to too many failed attempts'
    };
  }

  return {
    user_id: userId,
    failed_attempts: parseInt(String(attemptsStr || '0'), 10),
    is_locked: false,
    requires_admin_approval: false,
    message: 'OK'
  };
}

export async function recordFailedAttempt(
  redis: Redis,
  userId: string
): Promise<void> {
  const attemptsKey = `auth:rate_limit:${userId}:attempts`;
  const lockedKey = `auth:rate_limit:${userId}:locked`;
  const adminLockKey = `auth:rate_limit:${userId}:admin_lock`;

  // Increment attempts and get the new value
  // Note: if the key doesn't exist, incr sets it to 1
  const newAttempts = await redis.incr(attemptsKey);
  
  // Only set expiry if this is the first attempt in the window
  if (newAttempts === 1) {
    await redis.expire(attemptsKey, ATTEMPT_WINDOW_SECONDS);
  }

  if (newAttempts >= 7) {
    // Permanent lock until admin intervenes (or 24 hours just in case)
    await redis.setex(adminLockKey, 24 * 60 * 60, '1');
  } else if (newAttempts === 6) {
    // Lock for 15 minutes
    await redis.setex(lockedKey, 15 * 60, '1');
  } else if (newAttempts === 3) {
    // Lock for 5 minutes
    await redis.setex(lockedKey, 5 * 60, '1');
  }
}

export async function resetRateLimit(
  redis: Redis,
  userId: string
): Promise<void> {
  const attemptsKey = `auth:rate_limit:${userId}:attempts`;
  const lockedKey = `auth:rate_limit:${userId}:locked`;
  const adminLockKey = `auth:rate_limit:${userId}:admin_lock`;
  
  await redis.del(attemptsKey, lockedKey, adminLockKey);
}
