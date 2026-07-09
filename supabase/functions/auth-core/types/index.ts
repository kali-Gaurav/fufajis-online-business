export interface LoginRequest {
  email: string;
  password: string;
  device_id?: string;
  device_name?: string;
  ip_address: string;
  user_agent: string;
  app_version?: string;
  platform?: 'ios' | 'android' | 'web';
}

export interface LoginResponse {
  success: boolean;
  user_id?: string;
  email?: string;
  role?: string;
  token?: string;
  refresh_token?: string;
  requires_password_change?: boolean;
  message: string;
  error_code?: string;
}

export interface AuthenticatedContext {
  user_id: string;
  role: string;
  correlation_id: string;
  idempotency_key: string;
}

export interface PasswordSetupRequest {
  user_id: string;
  password: string;
}

export interface PasswordChangeRequest {
  current_password: string;
  new_password: string;
}

export interface SessionValidationRequest {
  token: string;
  device_id?: string;
}

export interface RateLimitInfo {
  user_id: string;
  failed_attempts: number;
  is_locked: boolean;
  locked_until?: string;
  requires_admin_approval: boolean;
  message: string;
}
