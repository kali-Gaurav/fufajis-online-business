import { createClient } from 'npm:@supabase/supabase-js';

export async function logAudit(
  supabase: ReturnType<typeof createClient>,
  eventType: string,
  status: 'success' | 'failed' | 'blocked',
  userId: string,
  reason: string,
  metadata?: Record<string, any>,
  requestInfo?: {
    email?: string;
    role?: string;
    ip_address?: string;
    user_agent?: string;
    device_id?: string;
    app_version?: string;
    platform?: string;
    actor_id?: string;
    actor_role?: string;
    correlation_id?: string;
  }
): Promise<void> {
  await supabase.rpc('rpc_insert_audit_log', {
    p_event_type: eventType,
    p_status: status,
    p_user_id: userId,
    p_reason: reason,
    p_metadata: { ...metadata, correlation_id: requestInfo?.correlation_id },
    p_email: requestInfo?.email,
    p_role: requestInfo?.role,
    p_ip_address: requestInfo?.ip_address,
    p_user_agent: requestInfo?.user_agent,
    p_device_id: requestInfo?.device_id,
    p_app_version: requestInfo?.app_version,
    p_platform: requestInfo?.platform,
    p_actor_id: requestInfo?.actor_id,
    p_actor_role: requestInfo?.actor_role,
  });
}
