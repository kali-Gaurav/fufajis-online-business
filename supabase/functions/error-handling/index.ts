// Shared Error Handling, Validation & Utilities for All Edge Functions
import { createServerClient } from "npm:@supabase/supabase-js";
import { crypto } from "https://deno.land/std@0.208.0/crypto/mod.ts";

// ============================================================================
// ERROR HANDLER MIDDLEWARE
// ============================================================================

export interface ErrorLog {
  message: string;
  code: string;
  status: number;
  timestamp: string;
  context?: Record<string, any>;
}

export function createErrorHandler(errorLogs: ErrorLog[] = []) {
  return function handleError(
    error: unknown,
    context: Record<string, any> = {}
  ): { status: number; body: Record<string, any>; log: ErrorLog } {
    let status = 500;
    let message = "Internal server error";
    let code = "INTERNAL_ERROR";

    if (error instanceof Error) {
      // Known errors
      if (error.message.includes("validation")) {
        status = 400;
        code = "VALIDATION_ERROR";
        message = error.message;
      } else if (error.message.includes("unauthorized")) {
        status = 401;
        code = "UNAUTHORIZED";
        message = "Unauthorized";
      } else if (error.message.includes("forbidden")) {
        status = 403;
        code = "FORBIDDEN";
        message = "Forbidden";
      } else if (error.message.includes("not found")) {
        status = 404;
        code = "NOT_FOUND";
        message = "Resource not found";
      } else if (error.message.includes("rate limit")) {
        status = 429;
        code = "RATE_LIMITED";
        message = "Too many requests";
      } else if (error.message.includes("duplicate")) {
        status = 409;
        code = "CONFLICT";
        message = "Duplicate resource";
      } else {
        message = error.message;
      }
    }

    const errorLog: ErrorLog = {
      message,
      code,
      status,
      timestamp: new Date().toISOString(),
      context,
    };

    errorLogs.push(errorLog);
    logToSentry(errorLog, error);

    return {
      status,
      body: { success: false, error: message, code },
      log: errorLog,
    };
  };
}

async function logToSentry(log: ErrorLog, error: unknown): Promise<void> {
  const sentryDsn = Deno.env.get("SENTRY_DSN");
  if (!sentryDsn) return;

  try {
    const dsn = new URL(sentryDsn);
    const projectId = dsn.pathname.split("/").pop();

    await fetch(`https://sentry.io/api/${projectId}/store/`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Sentry-Auth": `DSN ${sentryDsn}`,
      },
      body: JSON.stringify({
        message: log.message,
        level: log.status >= 500 ? "error" : "warning",
        tags: { code: log.code, status: log.status },
        contexts: { custom: log.context },
        exception: {
          values: [
            {
              type: log.code,
              value: log.message,
            },
          ],
        },
      }),
    }).catch(e => console.error("Sentry log error:", e));
  } catch (e) {
    console.error("Sentry error:", e);
  }
}

// ============================================================================
// VALIDATION UTILITIES
// ============================================================================

export function validateEmail(email: string): { valid: boolean; error?: string } {
  if (!email) return { valid: false, error: "Email is required" };
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!re.test(email)) return { valid: false, error: "Invalid email format" };
  if (email.length > 254) return { valid: false, error: "Email too long" };
  return { valid: true };
}

export function validatePassword(password: string): { valid: boolean; error?: string } {
  if (!password) return { valid: false, error: "Password is required" };
  if (password.length < 8) return { valid: false, error: "Password must be at least 8 characters" };
  if (!/[A-Z]/.test(password)) return { valid: false, error: "Password must contain uppercase letter" };
  if (!/[a-z]/.test(password)) return { valid: false, error: "Password must contain lowercase letter" };
  if (!/[0-9]/.test(password)) return { valid: false, error: "Password must contain number" };
  if (!/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)) {
    return { valid: false, error: "Password must contain special character" };
  }
  return { valid: true };
}

export function validatePhone(phone: string): { valid: boolean; error?: string } {
  if (!phone) return { valid: false, error: "Phone is required" };
  // E.164 format: +1-999-999-9999 or +919999999999
  const re = /^\+?[1-9]\d{1,14}$/;
  const normalized = phone.replace(/[\s\-()]/g, "");
  if (!re.test(normalized)) return { valid: false, error: "Invalid phone format" };
  return { valid: true };
}

export function validateUUID(uuid: string): { valid: boolean; error?: string } {
  if (!uuid) return { valid: false, error: "UUID is required" };
  const re = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!re.test(uuid)) return { valid: false, error: "Invalid UUID format" };
  return { valid: true };
}

export function validateDeliveryAddress(
  address: Record<string, any>
): { valid: boolean; error?: string } {
  if (!address) return { valid: false, error: "Address is required" };
  if (address.latitude === undefined || address.latitude === null) {
    return { valid: false, error: "Latitude is required" };
  }
  if (address.longitude === undefined || address.longitude === null) {
    return { valid: false, error: "Longitude is required" };
  }

  const lat = Number(address.latitude);
  const lng = Number(address.longitude);

  if (isNaN(lat) || lat < -90 || lat > 90) {
    return { valid: false, error: "Invalid latitude" };
  }
  if (isNaN(lng) || lng < -180 || lng > 180) {
    return { valid: false, error: "Invalid longitude" };
  }

  if (!address.street || address.street.trim().length === 0) {
    return { valid: false, error: "Street address is required" };
  }
  if (!address.city || address.city.trim().length === 0) {
    return { valid: false, error: "City is required" };
  }
  if (!address.zipCode || address.zipCode.trim().length === 0) {
    return { valid: false, error: "Zip code is required" };
  }

  return { valid: true };
}

export function validateCurrencyAmount(amount: number): { valid: boolean; error?: string } {
  if (typeof amount !== "number" || isNaN(amount)) {
    return { valid: false, error: "Amount must be a number" };
  }
  if (amount <= 0) {
    return { valid: false, error: "Amount must be greater than 0" };
  }
  if (amount > 10000000) {
    return { valid: false, error: "Amount exceeds maximum limit" };
  }
  return { valid: true };
}

// ============================================================================
// DATABASE HELPERS
// ============================================================================

export async function getSupabaseClient(): Promise<ReturnType<typeof createServerClient>> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = Deno.env.get("SUPABASE_SECRET_KEY");

  if (!supabaseUrl || !supabaseKey) {
    throw new Error("Missing Supabase credentials");
  }

  return createServerClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
  });
}

export async function getServiceRoleClient(): Promise<ReturnType<typeof createServerClient>> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseServiceKey) {
    throw new Error("Missing Supabase service credentials");
  }

  return createServerClient(supabaseUrl, supabaseServiceKey, {
    auth: { persistSession: false },
  });
}

export async function executeTransaction(
  supabase: ReturnType<typeof createServerClient>,
  queries: Array<{ table: string; method: string; data: Record<string, any> }>
): Promise<boolean> {
  try {
    for (const query of queries) {
      let q = (supabase as any).from(query.table);
      q = q[query.method](query.data);
      const { error } = await q;
      if (error) {
        console.error(`Transaction error in ${query.table}:`, error);
        return false;
      }
    }
    return true;
  } catch (error) {
    console.error("Transaction execution error:", error);
    return false;
  }
}

// ============================================================================
// IDEMPOTENCY
// ============================================================================

export async function checkIdempotency(
  supabase: ReturnType<typeof createServerClient>,
  key: string,
  value: string
): Promise<{ exists: boolean; result?: any }> {
  try {
    const { data } = await supabase
      .from("idempotency_keys")
      .select("result")
      .eq("key", key)
      .eq("value", value)
      .single();

    if (data) {
      return { exists: true, result: data.result };
    }
    return { exists: false };
  } catch (error) {
    console.error("Idempotency check error:", error);
    return { exists: false };
  }
}

export async function storeIdempotencyResult(
  supabase: ReturnType<typeof createServerClient>,
  key: string,
  value: string,
  result: any,
  expirySeconds = 86400
): Promise<boolean> {
  try {
    const expiresAt = new Date(Date.now() + expirySeconds * 1000).toISOString();
    await supabase.from("idempotency_keys").insert({
      key,
      value,
      result: JSON.stringify(result),
      expires_at: expiresAt,
    });
    return true;
  } catch (error) {
    console.error("Idempotency store error:", error);
    return false;
  }
}

// ============================================================================
// SIGNATURE VERIFICATION
// ============================================================================

export async function verifyHMAC(
  message: string,
  signature: string,
  secret: string,
  algorithm: "SHA-256" | "SHA-1" = "SHA-256"
): Promise<boolean> {
  try {
    const enc = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw",
      enc.encode(secret),
      { name: "HMAC", hash: algorithm },
      false,
      ["sign"]
    );

    const computedSignature = await crypto.subtle.sign("HMAC", key, enc.encode(message));
    const computedSignatureHex = Array.from(new Uint8Array(computedSignature))
      .map(b => b.toString(16).padStart(2, "0"))
      .join("");

    return timingSafeCompare(computedSignatureHex, signature);
  } catch (error) {
    console.error("HMAC verification error:", error);
    return false;
  }
}

export async function verifyFirebaseToken(token: string): Promise<{ valid: boolean; uid?: string }> {
  const firebaseUrl = Deno.env.get("FIREBASE_URL");
  const firebaseSecret = Deno.env.get("FIREBASE_SECRET");

  if (!firebaseUrl || !firebaseSecret) {
    return { valid: false };
  }

  try {
    const response = await fetch(`${firebaseUrl}/verifyIdToken`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${firebaseSecret}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ idToken: token }),
    });

    if (!response.ok) return { valid: false };

    const { uid } = await response.json();
    return { valid: true, uid };
  } catch (error) {
    console.error("Firebase token verification error:", error);
    return { valid: false };
  }
}

export async function verifyGoogleToken(
  token: string
): Promise<{ valid: boolean; email?: string; name?: string; picture?: string }> {
  const firebaseUrl = Deno.env.get("FIREBASE_URL");
  const firebaseSecret = Deno.env.get("FIREBASE_SECRET");

  if (!firebaseUrl || !firebaseSecret) {
    return { valid: false };
  }

  try {
    const response = await fetch(`${firebaseUrl}/verifyGoogleIdToken`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${firebaseSecret}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ idToken: token }),
    });

    if (!response.ok) return { valid: false };

    const { email, name, picture } = await response.json();
    return { valid: true, email, name, picture };
  } catch (error) {
    console.error("Google token verification error:", error);
    return { valid: false };
  }
}

function timingSafeCompare(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}

// ============================================================================
// RATE LIMITING
// ============================================================================

export async function checkRateLimit(
  supabase: ReturnType<typeof createServerClient>,
  key: string,
  limit: number,
  windowSeconds: number
): Promise<{ allowed: boolean; remaining: number; resetTime?: number }> {
  try {
    const now = Math.floor(Date.now() / 1000);
    const windowStart = now - windowSeconds;

    const { data } = await supabase
      .from("rate_limits")
      .select("count, window_start")
      .eq("key", key)
      .single();

    if (!data || data.window_start < windowStart) {
      // New window
      await supabase.from("rate_limits").upsert({
        key,
        count: 1,
        window_start: now,
      });
      return { allowed: true, remaining: limit - 1 };
    }

    if (data.count >= limit) {
      return {
        allowed: false,
        remaining: 0,
        resetTime: data.window_start + windowSeconds,
      };
    }

    // Increment count
    await supabase
      .from("rate_limits")
      .update({ count: data.count + 1 })
      .eq("key", key);

    return { allowed: true, remaining: limit - data.count - 1 };
  } catch (error) {
    console.error("Rate limit check error:", error);
    return { allowed: true, remaining: -1 }; // Fail open
  }
}

export async function incrementRateLimit(
  supabase: ReturnType<typeof createServerClient>,
  key: string
): Promise<boolean> {
  try {
    const { data } = await supabase
      .from("rate_limits")
      .select("count")
      .eq("key", key)
      .single();

    if (data) {
      await supabase
        .from("rate_limits")
        .update({ count: data.count + 1 })
        .eq("key", key);
    } else {
      await supabase.from("rate_limits").insert({
        key,
        count: 1,
        window_start: Math.floor(Date.now() / 1000),
      });
    }
    return true;
  } catch (error) {
    console.error("Rate limit increment error:", error);
    return false;
  }
}

// ============================================================================
// CRYPTO UTILITIES
// ============================================================================

export async function hashPassword(password: string): Promise<string> {
  const enc = new TextEncoder();
  const data = enc.encode(password);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  return btoa(String.fromCharCode(...new Uint8Array(hashBuffer)));
}

export async function generateRandomToken(length = 32): Promise<string> {
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  return Array.from(bytes)
    .map(b => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function generateJWT(
  payload: Record<string, any>,
  expirySeconds = 86400
): Promise<string> {
  const secret = Deno.env.get("JWT_SECRET");
  if (!secret) throw new Error("JWT_SECRET not configured");

  const header = { alg: "HS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const jwtPayload = {
    ...payload,
    iat: now,
    exp: now + expirySeconds,
  };

  const headerEncoded = btoa(JSON.stringify(header));
  const payloadEncoded = btoa(JSON.stringify(jwtPayload));
  const message = `${headerEncoded}.${payloadEncoded}`;

  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign("HMAC", key, enc.encode(message));
  const signatureEncoded = btoa(String.fromCharCode(...new Uint8Array(signature)));

  return `${message}.${signatureEncoded}`;
}

export function decodeJWT(token: string): { payload?: Record<string, any>; error?: string } {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return { error: "Invalid token format" };

    const payload = JSON.parse(atob(parts[1]));
    const now = Math.floor(Date.now() / 1000);

    if (payload.exp && payload.exp < now) {
      return { error: "Token expired" };
    }

    return { payload };
  } catch (error) {
    return { error: "Failed to decode token" };
  }
}

// ============================================================================
// NOTIFICATION HELPERS
// ============================================================================

export async function sendPushNotification(
  supabase: ReturnType<typeof createServerClient>,
  userId: string,
  title: string,
  body: string,
  data?: Record<string, any>
): Promise<boolean> {
  try {
    await supabase.from("notifications").insert({
      user_id: userId,
      title,
      body,
      data: data || {},
      read: false,
      created_at: new Date().toISOString(),
    });
    return true;
  } catch (error) {
    console.error("Push notification error:", error);
    return false;
  }
}

export async function sendEmail(
  email: string,
  subject: string,
  template: string,
  data?: Record<string, any>
): Promise<boolean> {
  const sendgridApiKey = Deno.env.get("SENDGRID_API_KEY");
  if (!sendgridApiKey) {
    console.error("SendGrid not configured");
    return false;
  }

  try {
    const response = await fetch("https://api.sendgrid.com/v3/mail/send", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${sendgridApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        personalizations: [{ to: [{ email }] }],
        from: { email: "noreply@fufaji.com", name: "Fufaji" },
        subject,
        content: [{ type: "text/html", value: buildEmailContent(template, data) }],
      }),
    });

    return response.ok;
  } catch (error) {
    console.error("Email send error:", error);
    return false;
  }
}

export async function sendSMS(phone: string, message: string): Promise<boolean> {
  const twilioAccountSid = Deno.env.get("TWILIO_ACCOUNT_SID");
  const twilioAuthToken = Deno.env.get("TWILIO_AUTH_TOKEN");
  const twilioPhoneNumber = Deno.env.get("TWILIO_PHONE_NUMBER");

  if (!twilioAccountSid || !twilioAuthToken || !twilioPhoneNumber) {
    console.error("Twilio not configured");
    return false;
  }

  try {
    const body = new URLSearchParams({
      From: twilioPhoneNumber,
      To: phone,
      Body: message,
    });

    const auth = btoa(`${twilioAccountSid}:${twilioAuthToken}`);
    const response = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${twilioAccountSid}/Messages.json`,
      {
        method: "POST",
        headers: {
          Authorization: `Basic ${auth}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: body.toString(),
      }
    );

    return response.ok;
  } catch (error) {
    console.error("SMS send error:", error);
    return false;
  }
}

function buildEmailContent(template: string, data?: Record<string, any>): string {
  const templates: Record<string, (data?: Record<string, any>) => string> = {
    password_reset: (d) =>
      `<p>Click <a href="${d?.resetLink}">here</a> to reset your password.</p>`,
    order_confirmation: (d) =>
      `<p>Your order #${d?.orderId} has been confirmed. Total: ${d?.total}</p>`,
    payment_success: (d) =>
      `<p>Payment of ${d?.amount} received for order #${d?.orderId}.</p>`,
    refund_processed: (d) =>
      `<p>Refund of ${d?.amount} has been processed and added to your wallet.</p>`,
  };

  const content = templates[template]?.(data) || template;
  return `<html><body>${content}</body></html>`;
}

// ============================================================================
// LOGGING
// ============================================================================

export interface AuditLog {
  userId: string;
  action: string;
  resource: string;
  changes?: Record<string, any>;
  timestamp: string;
  ipAddress?: string;
}

export async function logAudit(
  supabase: ReturnType<typeof createServerClient>,
  log: Omit<AuditLog, "timestamp">
): Promise<boolean> {
  try {
    await supabase.from("audit_logs").insert({
      ...log,
      timestamp: new Date().toISOString(),
    });
    return true;
  } catch (error) {
    console.error("Audit log error:", error);
    return false;
  }
}

// ============================================================================
// RESPONSE BUILDERS
// ============================================================================

export function buildSuccessResponse(data: any, status = 200): Response {
  return new Response(
    JSON.stringify({ success: true, data }),
    {
      status,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    }
  );
}

export function buildErrorResponse(
  error: string,
  code: string,
  status = 400
): Response {
  return new Response(
    JSON.stringify({ success: false, error, code }),
    {
      status,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    }
  );
}

// ============================================================================
// ENVIRONMENT VARIABLES
// ============================================================================

export function getRequiredEnv(...keys: string[]): Record<string, string> {
  const env: Record<string, string> = {};
  for (const key of keys) {
    const value = Deno.env.get(key);
    if (!value) throw new Error(`Missing required environment variable: ${key}`);
    env[key] = value;
  }
  return env;
}

export function getOptionalEnv(...keys: string[]): Record<string, string | undefined> {
  const env: Record<string, string | undefined> = {};
  for (const key of keys) {
    env[key] = Deno.env.get(key);
  }
  return env;
}


