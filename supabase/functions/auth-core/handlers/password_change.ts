import { createClient } from 'npm:@supabase/supabase-js';
import { AuthenticatedContext, PasswordChangeRequest } from '../types/index.ts';
import { isValidPassword } from '../utils/validation.ts';
import { verifyPassword, hashPassword, generateToken } from '../services/password.ts';
import { callRpcWithRetry } from '../utils/db.ts';

export async function handlePasswordChange(
  supabase: ReturnType<typeof createClient>,
  authContext: AuthenticatedContext,
  req: PasswordChangeRequest
): Promise<{ success: boolean; message: string; error_code?: string }> {
  // First, verify current password and check history
  // Note: We still do some reads here because verifying the password requires the salt.
  let credential;
  try {
    credential = await callRpcWithRetry(
      supabase,
      'rpc_get_credential_by_user_id',
      { p_user_id: authContext.user_id }
    );
  } catch (credError) {
    return { success: false, message: 'Invalid request or unauthorized', error_code: 'UNAUTHORIZED' };
  }

  if (!credential) {
    return { success: false, message: 'Invalid request or unauthorized', error_code: 'UNAUTHORIZED' };
  }

  const currentValid = await verifyPassword(
    req.current_password,
    credential.password_hash,
    credential.password_salt
  );

  if (!currentValid) {
    return { success: false, message: 'Current password is incorrect', error_code: 'INVALID_CURRENT_PASSWORD' };
  }

  if (!isValidPassword(req.new_password)) {
    return { success: false, message: 'New password does not meet security requirements', error_code: 'WEAK_PASSWORD' };
  }

  const { data: history } = await callRpcWithRetry(
    supabase,
    'rpc_get_password_history',
    { p_user_id: authContext.user_id, p_limit: 5 }
  );

  if (history) {
    const newHash = await hashPassword(req.new_password, credential.password_salt);
    const isReused = history.some(h => h.password_hash === newHash);

    if (isReused) {
      return { success: false, message: 'Cannot reuse a recent password', error_code: 'PASSWORD_REUSED' };
    }
  }

  const newSalt = generateToken().substring(0, 16);
  const newHash = await hashPassword(req.new_password, newSalt);

  try {
    await callRpcWithRetry(supabase, 'rpc_complete_password_change', {
      p_user_id: authContext.user_id,
      p_new_hash: newHash,
      p_new_salt: newSalt,
      p_correlation_id: authContext.correlation_id,
      p_idempotency_key: authContext.idempotency_key
    });
  } catch (error: any) {
    console.error('RPC Error:', error);
    if (error.message?.includes('CONCURRENT_UPDATE_DETECTED') || error.message?.includes('USER_NOT_FOUND')) {
      return { success: false, message: 'User not found or concurrent update occurred', error_code: 'CHANGE_FAILED' };
    }
    throw error;
  }

  return { success: true, message: 'Password changed successfully' };
}
