import { createClient } from 'npm:@supabase/supabase-js';
import { AuthenticatedContext, PasswordSetupRequest } from '../types/index.ts';
import { isValidPassword } from '../utils/validation.ts';
import { generateToken, hashPassword } from '../services/password.ts';
import { callRpcWithRetry } from '../utils/db.ts';

export async function handlePasswordSetup(
  supabase: ReturnType<typeof createClient>,
  authContext: AuthenticatedContext,
  req: PasswordSetupRequest
): Promise<{ success: boolean; message: string; error_code?: string }> {
  // Only admins can setup passwords
  if (!['admin', 'shopOwner'].includes(authContext.role)) {
    return { success: false, message: 'Unauthorized or invalid request', error_code: 'UNAUTHORIZED' };
  }

  if (!isValidPassword(req.password)) {
    return { success: false, message: 'Password does not meet security requirements', error_code: 'WEAK_PASSWORD' };
  }

  const salt = generateToken().substring(0, 16);
  const passwordHash = await hashPassword(req.password, salt);

  try {
    await callRpcWithRetry(supabase, 'rpc_complete_password_setup', {
      p_user_id: req.user_id,
      p_admin_id: authContext.user_id,
      p_hash: passwordHash,
      p_salt: salt,
      p_role: authContext.role,
      p_correlation_id: authContext.correlation_id,
      p_idempotency_key: authContext.idempotency_key
    });
  } catch (error: any) {
    console.error('RPC Error:', error);
    if (error.message?.includes('CONCURRENT_UPDATE_DETECTED') || error.message?.includes('USER_NOT_FOUND')) {
      return { success: false, message: 'User not found or concurrent update occurred', error_code: 'SETUP_FAILED' };
    }
    throw error;
  }

  return { success: true, message: 'Password created successfully' };
}
