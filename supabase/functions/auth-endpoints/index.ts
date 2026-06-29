// Auth Edge Functions - All 9 auth endpoints
import { createServerClient } from "npm:@supabase/supabase-js";
import { crypto } from "https://deno.land/std@0.208.0/crypto/mod.ts";

interface FunctionRequest extends Request {
  supabase?: ReturnType<typeof createServerClient>;
  userId?: string;
  body?: Record<string, any>;
}

interface AuthResponse {
  success: boolean;
  data?: any;
  error?: string;
  code?: string;
}

// ============================================================================
// CORE MIDDLEWARE & UTILITIES
// ============================================================================

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

async function initializeRequest(req: Request): Promise<FunctionRequest> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = Deno.env.get("SUPABASE_SECRET_KEY");

  if (!supabaseUrl || !supabaseKey) {
    throw new Error("Missing Supabase credentials");
  }

  const authHeader = req.headers.get("Authorization") || "";
  const token = authHeader.replace("Bearer ", "");

  const supabase = createServerClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authHeader } },
  });

  let userId: string | undefined;
  if (token) {
    const { data, error } = await supabase.auth.getUser(token);
    if (!error && data.user) {
      userId = data.user.id;
    }
  }

  const functionReq: FunctionRequest = Object.assign(req, {
    supabase,
    userId,
  });

  if (req.method !== "GET" && req.method !== "HEAD") {
    try {
      functionReq.body = await req.clone().json();
    } catch {
      functionReq.body = {};
    }
  }

  return functionReq;
}

function successResponse(data: any, status = 200): Response {
  return new Response(
    JSON.stringify({ success: true, data }),
    { status, headers: { "Content-Type": "application/json", ...corsHeaders() } }
  );
}

function errorResponse(
  error: string,
  code: string,
  status = 400
): Response {
  return new Response(
    JSON.stringify({ success: false, error, code }),
    { status, headers: { "Content-Type": "application/json", ...corsHeaders() } }
  );
}

// ============================================================================
// VALIDATION UTILITIES
// ============================================================================

function validateEmail(email: string): boolean {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(email);
}

function validatePassword(password: string): { valid: boolean; error?: string } {
  if (password.length < 8) return { valid: false, error: "Password must be at least 8 characters" };
  if (!/[A-Z]/.test(password)) return { valid: false, error: "Password must contain uppercase letter" };
  if (!/[0-9]/.test(password)) return { valid: false, error: "Password must contain number" };
  if (!/[!@#$%^&*]/.test(password)) return { valid: false, error: "Password must contain special character" };
  return { valid: true };
}

function validatePhone(phone: string): boolean {
  const re = /^\+?[1-9]\d{1,14}$/; // E.164 format
  return re.test(phone.replace(/\s/g, ""));
}

function validateUUID(uuid: string): boolean {
  const re = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return re.test(uuid);
}

// ============================================================================
// RATE LIMITING & SECURITY
// ============================================================================

async function checkRateLimit(
  supabase: any,
  key: string,
  limit: number,
  windowSeconds: number
): Promise<{ allowed: boolean; remaining: number }> {
  const now = Math.floor(Date.now() / 1000);
  const windowStart = now - windowSeconds;

  const { data } = await supabase
    .from("rate_limits")
    .select("count, window_start")
    .eq("key", key)
    .single();

  if (!data || data.window_start < windowStart) {
    await supabase.from("rate_limits").upsert({ key, count: 1, window_start: now });
    return { allowed: true, remaining: limit - 1 };
  }

  const remaining = limit - data.count;
  if (data.count >= limit) {
    return { allowed: false, remaining: 0 };
  }

  await supabase
    .from("rate_limits")
    .update({ count: data.count + 1 })
    .eq("key", key);

  return { allowed: true, remaining };
}

// ============================================================================
// REDIS UTILITIES (via Supabase)
// ============================================================================

async function setRedis(
  supabase: any,
  key: string,
  value: string,
  expirySeconds: number
): Promise<void> {
  const expiresAt = new Date(Date.now() + expirySeconds * 1000).toISOString();
  await supabase.from("cache").upsert({
    key,
    value,
    expires_at: expiresAt,
  });
}

async function getRedis(supabase: any, key: string): Promise<string | null> {
  const { data } = await supabase
    .from("cache")
    .select("value")
    .eq("key", key)
    .gt("expires_at", new Date().toISOString())
    .single();

  if (data) {
    await supabase.from("cache").delete().eq("key", key);
    return data.value;
  }
  return null;
}

async function deleteRedis(supabase: any, key: string): Promise<void> {
  await supabase.from("cache").delete().eq("key", key);
}

// ============================================================================
// JWT & CRYPTO
// ============================================================================

async function generateJWT(
  uid: string,
  email: string,
  role: string,
  expiryHours = 24
): Promise<string> {
  const secret = Deno.env.get("JWT_SECRET");
  if (!secret) throw new Error("JWT_SECRET not configured");

  const header = { alg: "HS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    sub: uid,
    email,
    role,
    iat: now,
    exp: now + expiryHours * 3600,
  };

  const headerEncoded = btoa(JSON.stringify(header));
  const payloadEncoded = btoa(JSON.stringify(payload));
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

async function hashPassword(password: string): Promise<string> {
  const enc = new TextEncoder();
  const data = enc.encode(password);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  return btoa(String.fromCharCode(...new Uint8Array(hashBuffer)));
}

// ============================================================================
// EMAIL & SMS HELPERS
// ============================================================================

async function sendOTP(phone: string, otp: string): Promise<boolean> {
  const twilioAccountSid = Deno.env.get("TWILIO_ACCOUNT_SID");
  const twilioAuthToken = Deno.env.get("TWILIO_AUTH_TOKEN");
  const twilioPhoneNumber = Deno.env.get("TWILIO_PHONE_NUMBER");

  if (!twilioAccountSid || !twilioAuthToken || !twilioPhoneNumber) {
    console.error("Twilio not configured");
    return false;
  }

  try {
    const message = `Your Fufaji verification code is: ${otp}. Do not share this code.`;
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
    console.error("SMS send failed:", error);
    return false;
  }
}

async function sendEmail(
  email: string,
  template: string,
  data: Record<string, any>
): Promise<boolean> {
  const sendgridApiKey = Deno.env.get("SENDGRID_API_KEY");
  if (!sendgridApiKey) {
    console.error("SendGrid not configured");
    return false;
  }

  try {
    const templates: Record<string, { subject: string; content: string }> = {
      password_reset: {
        subject: "Reset your Fufaji password",
        content: `Click here to reset: ${data.resetLink}`,
      },
      signup_confirmation: {
        subject: "Welcome to Fufaji!",
        content: `Thank you for signing up. Your account is ready.`,
      },
      login_notification: {
        subject: "New login to your Fufaji account",
        content: `You logged in at ${data.timestamp}`,
      },
      refund_confirmed: {
        subject: "Your refund has been processed",
        content: `Refund amount: ${data.amount}. Check your wallet.`,
      },
    };

    const tmpl = templates[template];
    if (!tmpl) return false;

    const response = await fetch("https://api.sendgrid.com/v3/mail/send", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${sendgridApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        personalizations: [{ to: [{ email }] }],
        from: { email: "noreply@fufaji.com", name: "Fufaji" },
        subject: tmpl.subject,
        content: [{ type: "text/plain", value: tmpl.content }],
      }),
    });

    return response.ok;
  } catch (error) {
    console.error("Email send failed:", error);
    return false;
  }
}

// ============================================================================
// 1. POST /auth/signup-email
// ============================================================================

async function signupEmail(req: FunctionRequest): Promise<Response> {
  const supabase = req.supabase!;
  const { email, password, phone, name } = req.body || {};

  // Validate input
  if (!email || !validateEmail(email)) {
    return errorResponse("Invalid email", "INVALID_EMAIL");
  }
  if (!password) {
    return errorResponse("Password required", "MISSING_PASSWORD");
  }

  const passValidation = validatePassword(password);
  if (!passValidation.valid) {
    return errorResponse(passValidation.error!, "WEAK_PASSWORD");
  }

  if (!phone || !validatePhone(phone)) {
    return errorResponse("Invalid phone", "INVALID_PHONE");
  }

  try {
    // Rate limit: 5 signups per hour per IP
    const clientIp = req.headers.get("x-forwarded-for") || "unknown";
    const rateLimit = await checkRateLimit(supabase, `signup:${clientIp}`, 5, 3600);
    if (!rateLimit.allowed) {
      return errorResponse("Rate limit exceeded", "RATE_LIMITED", 429);
    }

    // Check if user already exists
    const { data: existingUser } = await supabase
      .from("users")
      .select("id")
      .eq("email", email.toLowerCase())
      .single();

    if (existingUser) {
      return errorResponse("Email already registered", "EMAIL_EXISTS", 409);
    }

    // Hash password
    const hashedPassword = await hashPassword(password);

    // Create user in PostgreSQL
    const { data: newUser, error: dbError } = await supabase
      .from("users")
      .insert({
        email: email.toLowerCase(),
        phone: phone.replace(/\s/g, ""),
        name: name || "User",
        password_hash: hashedPassword,
        role: "customer",
        status: "active",
        email_verified: false,
        phone_verified: false,
        created_at: new Date().toISOString(),
      })
      .select("id, email, role")
      .single();

    if (dbError) {
      console.error("User creation error:", dbError);
      return errorResponse("Failed to create user", "DB_ERROR", 500);
    }

    // Create user in Firestore (async, non-blocking)
    const firebaseUrl = Deno.env.get("FIREBASE_URL");
    if (firebaseUrl) {
      fetch(`${firebaseUrl}/users/${newUser.id}`, {
        method: "SET",
        headers: { Authorization: `Bearer ${Deno.env.get("FIREBASE_SECRET")}` },
        body: JSON.stringify({
          uid: newUser.id,
          email: newUser.email,
          phone: phone.replace(/\s/g, ""),
          name: name || "User",
          role: "customer",
          createdAt: new Date().toISOString(),
        }),
      }).catch(e => console.error("Firestore sync error:", e));
    }

    // Generate JWT
    const jwtToken = await generateJWT(newUser.id, newUser.email, newUser.role);

    // Send welcome email (async)
    sendEmail(email, "signup_confirmation", {}).catch(e =>
      console.error("Email send error:", e)
    );

    return successResponse({
      user: {
        id: newUser.id,
        email: newUser.email,
        phone: phone.replace(/\s/g, ""),
        name: name || "User",
        role: newUser.role,
      },
      token: jwtToken,
    }, 201);
  } catch (error) {
    console.error("Signup error:", error);
    return errorResponse("Signup failed", "SIGNUP_ERROR", 500);
  }
}

// ============================================================================
// 2. POST /auth/login-email
// ============================================================================

async function loginEmail(req: FunctionRequest): Promise<Response> {
  const supabase = req.supabase!;
  const { email, password } = req.body || {};

  if (!email || !validateEmail(email)) {
    return errorResponse("Invalid email", "INVALID_EMAIL");
  }
  if (!password) {
    return errorResponse("Password required", "MISSING_PASSWORD");
  }

  try {
    // Rate limit: 10 login attempts per hour per IP
    const clientIp = req.headers.get("x-forwarded-for") || "unknown";
    const rateLimit = await checkRateLimit(supabase, `login:${clientIp}`, 10, 3600);
    if (!rateLimit.allowed) {
      return errorResponse("Too many login attempts", "RATE_LIMITED", 429);
    }

    // Get user
    const { data: user, error: dbError } = await supabase
      .from("users")
      .select("id, email, password_hash, role, status, phone")
      .eq("email", email.toLowerCase())
      .single();

    if (dbError || !user) {
      return errorResponse("Invalid credentials", "INVALID_CREDENTIALS", 401);
    }

    if (user.status !== "active") {
      return errorResponse("Account suspended", "ACCOUNT_SUSPENDED", 403);
    }

    // Verify password
    const hashedPassword = await hashPassword(password);
    if (user.password_hash !== hashedPassword) {
      return errorResponse("Invalid credentials", "INVALID_CREDENTIALS", 401);
    }

    // Generate JWT
    const jwtToken = await generateJWT(user.id, user.email, user.role);

    // Log login
    await supabase.from("login_logs").insert({
      user_id: user.id,
      ip: clientIp,
      timestamp: new Date().toISOString(),
    }).catch(e => console.error("Login log error:", e));

    // Send login notification email (async)
    sendEmail(email, "login_notification", { timestamp: new Date().toISOString() }).catch(e =>
      console.error("Email send error:", e)
    );

    return successResponse({
      user: {
        id: user.id,
        email: user.email,
        phone: user.phone,
        role: user.role,
      },
      token: jwtToken,
    });
  } catch (error) {
    console.error("Login error:", error);
    return errorResponse("Login failed", "LOGIN_ERROR", 500);
  }
}

// ============================================================================
// 3. POST /auth/phone-otp/request
// ============================================================================

async function phoneOtpRequest(req: FunctionRequest): Promise<Response> {
  const supabase = req.supabase!;
  const { phone } = req.body || {};

  if (!phone || !validatePhone(phone)) {
    return errorResponse("Invalid phone", "INVALID_PHONE");
  }

  try {
    // Rate limit: 3 OTP requests per hour per phone
    const rateLimit = await checkRateLimit(supabase, `otp:${phone}`, 3, 3600);
    if (!rateLimit.allowed) {
      return errorResponse("Too many OTP requests", "RATE_LIMITED", 429);
    }

    // Generate 6-digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    // Store in Redis (5 min expiry)
    await setRedis(supabase, `otp:${phone}`, otp, 300);

    // Send SMS
    const smsSent = await sendOTP(phone, otp);
    if (!smsSent) {
      return errorResponse("Failed to send OTP", "SMS_FAILED", 500);
    }

    return successResponse({
      message: "OTP sent successfully",
      phone: phone.replace(/\d(?=\d{4})/g, "*"), // Mask phone number
    });
  } catch (error) {
    console.error("OTP request error:", error);
    return errorResponse("OTP request failed", "OTP_ERROR", 500);
  }
}

// ============================================================================
// 4. POST /auth/phone-otp/verify
// ============================================================================

async function phoneOtpVerify(req: FunctionRequest): Promise<Response> {
  const supabase = req.supabase!;
  const { phone, otp, name } = req.body || {};

  if (!phone || !validatePhone(phone)) {
    return errorResponse("Invalid phone", "INVALID_PHONE");
  }
  if (!otp) {
    return errorResponse("OTP required", "MISSING_OTP");
  }

  try {
    // Get OTP from Redis
    const storedOtp = await getRedis(supabase, `otp:${phone}`);
    if (!storedOtp || storedOtp !== otp) {
      return errorResponse("Invalid or expired OTP", "INVALID_OTP", 401);
    }

    const normalizedPhone = phone.replace(/\s/g, "");

    // Check if user exists
    let { data: user } = await supabase
      .from("users")
      .select("id, email, role")
      .eq("phone", normalizedPhone)
      .single();

    // Create new user if not exists
    if (!user) {
      // Generate temp email
      const tempEmail = `phone_${normalizedPhone}@fufaji.temp`;
      const { data: newUser, error: dbError } = await supabase
        .from("users")
        .insert({
          email: tempEmail,
          phone: normalizedPhone,
          name: name || "User",
          role: "customer",
          status: "active",
          email_verified: false,
          phone_verified: true,
          created_at: new Date().toISOString(),
        })
        .select("id, email, role")
        .single();

      if (dbError) {
        console.error("User creation error:", dbError);
        return errorResponse("Failed to create user", "DB_ERROR", 500);
      }

      user = newUser;
    } else {
      // Update existing user
      await supabase
        .from("users")
        .update({ phone_verified: true })
        .eq("id", user.id);
    }

    // Sync to Firestore (async)
    const firebaseUrl = Deno.env.get("FIREBASE_URL");
    if (firebaseUrl) {
      fetch(`${firebaseUrl}/users/${user.id}`, {
        method: "SET",
        headers: { Authorization: `Bearer ${Deno.env.get("FIREBASE_SECRET")}` },
        body: JSON.stringify({
          uid: user.id,
          phone: normalizedPhone,
          phoneVerified: true,
        }),
      }).catch(e => console.error("Firestore sync error:", e));
    }

    // Generate JWT
    const jwtToken = await generateJWT(user.id, user.email, user.role);

    return successResponse({
      user: {
        id: user.id,
        email: user.email,
        phone: normalizedPhone,
        role: user.role,
      },
      token: jwtToken,
    });
  } catch (error) {
    console.error("OTP verify error:", error);
    return errorResponse("OTP verification failed", "OTP_ERROR", 500);
  }
}

// ============================================================================
// 5. POST /auth/google-signin
// ============================================================================

async function googleSignin(req: FunctionRequest): Promise<Response> {
  const supabase = req.supabase!;
  const { idToken } = req.body || {};

  if (!idToken) {
    return errorResponse("Google ID token required", "MISSING_TOKEN");
  }

  try {
    // Verify Google token (via Firebase)
    const firebaseUrl = Deno.env.get("FIREBASE_URL");
    const firebaseSecret = Deno.env.get("FIREBASE_SECRET");

    if (!firebaseUrl || !firebaseSecret) {
      return errorResponse("Firebase not configured", "CONFIG_ERROR", 500);
    }

    const verifyResponse = await fetch(`${firebaseUrl}/verifyIdToken`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${firebaseSecret}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ idToken }),
    });

    if (!verifyResponse.ok) {
      return errorResponse("Invalid Google token", "INVALID_TOKEN", 401);
    }

    const { uid, email, name, picture } = await verifyResponse.json();

    if (!email) {
      return errorResponse("Email required from Google account", "MISSING_EMAIL", 400);
    }

    // Check if user exists
    let { data: user } = await supabase
      .from("users")
      .select("id, email, role")
      .eq("email", email.toLowerCase())
      .single();

    // Create user if not exists
    if (!user) {
      const { data: newUser, error: dbError } = await supabase
        .from("users")
        .insert({
          email: email.toLowerCase(),
          name: name || "User",
          google_uid: uid,
          google_picture: picture,
          role: "customer",
          status: "active",
          email_verified: true,
          phone_verified: false,
          created_at: new Date().toISOString(),
        })
        .select("id, email, role")
        .single();

      if (dbError) {
        console.error("User creation error:", dbError);
        return errorResponse("Failed to create user", "DB_ERROR", 500);
      }

      user = newUser;
    } else {
      // Link Google account to existing user
      await supabase
        .from("users")
        .update({ google_uid: uid, google_picture: picture })
        .eq("id", user.id);
    }

    // Sync to Firestore (async)
    if (firebaseUrl) {
      fetch(`${firebaseUrl}/users/${user.id}`, {
        method: "SET",
        headers: { Authorization: `Bearer ${firebaseSecret}` },
        body: JSON.stringify({
          uid: user.id,
          email: email.toLowerCase(),
          name,
          picture,
          googleUid: uid,
        }),
      }).catch(e => console.error("Firestore sync error:", e));
    }

    // Generate JWT
    const jwtToken = await generateJWT(user.id, user.email, user.role);

    return successResponse({
      user: {
        id: user.id,
        email: user.email,
        name,
        role: user.role,
      },
      token: jwtToken,
    });
  } catch (error) {
    console.error("Google signin error:", error);
    return errorResponse("Google signin failed", "SIGNIN_ERROR", 500);
  }
}

// ============================================================================
// 6. POST /auth/logout
// ============================================================================

async function logout(req: FunctionRequest): Promise<Response> {
  if (!req.userId) {
    return errorResponse("Unauthorized", "UNAUTHORIZED", 401);
  }

  const supabase = req.supabase!;

  try {
    // Extract and blacklist token
    const authHeader = req.headers.get("Authorization") || "";
    const token = authHeader.replace("Bearer ", "");

    if (token) {
      // Calculate token expiry (default 24 hours)
      const expirySeconds = 24 * 3600;
      await setRedis(supabase, `blacklist:${token}`, "true", expirySeconds);
    }

    // Log logout
    await supabase.from("login_logs").insert({
      user_id: req.userId,
      ip: req.headers.get("x-forwarded-for") || "unknown",
      action: "logout",
      timestamp: new Date().toISOString(),
    }).catch(e => console.error("Logout log error:", e));

    return successResponse({ message: "Logged out successfully" });
  } catch (error) {
    console.error("Logout error:", error);
    return errorResponse("Logout failed", "LOGOUT_ERROR", 500);
  }
}

// ============================================================================
// 7. POST /auth/password-reset/request
// ============================================================================

async function passwordResetRequest(req: FunctionRequest): Promise<Response> {
  const supabase = req.supabase!;
  const { email } = req.body || {};

  if (!email || !validateEmail(email)) {
    return errorResponse("Invalid email", "INVALID_EMAIL");
  }

  try {
    // Rate limit: 3 reset requests per hour per email
    const rateLimit = await checkRateLimit(supabase, `reset:${email}`, 3, 3600);
    if (!rateLimit.allowed) {
      return errorResponse("Too many reset requests", "RATE_LIMITED", 429);
    }

    // Check if user exists
    const { data: user } = await supabase
      .from("users")
      .select("id")
      .eq("email", email.toLowerCase())
      .single();

    if (!user) {
      // Don't reveal if email exists (security)
      return successResponse({ message: "If email exists, reset link sent" });
    }

    // Generate 32-char reset token
    const resetToken = Array.from(crypto.getRandomValues(new Uint8Array(32)))
      .map(b => b.toString(16).padStart(2, "0"))
      .join("");

    // Store in Redis (30 min expiry)
    await setRedis(supabase, `reset:${resetToken}`, user.id, 1800);

    // Send reset email
    const resetLink = `${Deno.env.get("APP_URL")}/auth/reset-password?token=${resetToken}`;
    await sendEmail(email, "password_reset", { resetLink });

    return successResponse({ message: "Reset email sent" });
  } catch (error) {
    console.error("Password reset request error:", error);
    return errorResponse("Reset request failed", "RESET_ERROR", 500);
  }
}

// ============================================================================
// 8. POST /auth/password-reset/verify
// ============================================================================

async function passwordResetVerify(req: FunctionRequest): Promise<Response> {
  const supabase = req.supabase!;
  const { token, newPassword } = req.body || {};

  if (!token) {
    return errorResponse("Reset token required", "MISSING_TOKEN");
  }
  if (!newPassword) {
    return errorResponse("New password required", "MISSING_PASSWORD");
  }

  const passValidation = validatePassword(newPassword);
  if (!passValidation.valid) {
    return errorResponse(passValidation.error!, "WEAK_PASSWORD");
  }

  try {
    // Get user ID from token
    const userId = await getRedis(supabase, `reset:${token}`);
    if (!userId) {
      return errorResponse("Invalid or expired reset token", "INVALID_TOKEN", 401);
    }

    // Hash new password
    const hashedPassword = await hashPassword(newPassword);

    // Update password
    const { error: dbError } = await supabase
      .from("users")
      .update({ password_hash: hashedPassword })
      .eq("id", userId);

    if (dbError) {
      console.error("Password update error:", dbError);
      return errorResponse("Failed to update password", "DB_ERROR", 500);
    }

    // Invalidate all existing tokens for this user
    await deleteRedis(supabase, `refresh:${userId}`);

    // Get user email for notification
    const { data: user } = await supabase
      .from("users")
      .select("email")
      .eq("id", userId)
      .single();

    if (user) {
      // Send confirmation email (async)
      sendEmail(user.email, "password_reset_confirmation", {}).catch(e =>
        console.error("Email send error:", e)
      );
    }

    return successResponse({ message: "Password reset successfully" });
  } catch (error) {
    console.error("Password reset verify error:", error);
    return errorResponse("Password reset failed", "RESET_ERROR", 500);
  }
}

// ============================================================================
// 9. POST /auth/refresh-token
// ============================================================================

async function refreshToken(req: FunctionRequest): Promise<Response> {
  const supabase = req.supabase!;
  const { token: refreshToken } = req.body || {};

  if (!refreshToken) {
    return errorResponse("Refresh token required", "MISSING_TOKEN");
  }

  try {
    // Check if token is blacklisted
    const blacklisted = await getRedis(supabase, `blacklist:${refreshToken}`);
    if (blacklisted) {
      return errorResponse("Token has been revoked", "TOKEN_REVOKED", 401);
    }

    // Decode token (allow expired)
    const parts = refreshToken.split(".");
    if (parts.length !== 3) {
      return errorResponse("Invalid token format", "INVALID_TOKEN", 401);
    }

    const payload = JSON.parse(atob(parts[1]));

    // Check user status
    const { data: user, error: dbError } = await supabase
      .from("users")
      .select("id, email, role, status")
      .eq("id", payload.sub)
      .single();

    if (dbError || !user || user.status !== "active") {
      return errorResponse("User not found or inactive", "USER_NOT_FOUND", 401);
    }

    // Generate new JWT
    const newToken = await generateJWT(user.id, user.email, user.role);

    return successResponse({
      token: newToken,
      expiresIn: 24 * 3600,
    });
  } catch (error) {
    console.error("Refresh token error:", error);
    return errorResponse("Token refresh failed", "REFRESH_ERROR", 500);
  }
}

// ============================================================================
// ROUTE HANDLER
// ============================================================================

async function handleRequest(req: Request): Promise<Response> {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders() });
  }

  try {
    const functionReq = await initializeRequest(req);
    const url = new URL(req.url);
    const path = url.pathname;

    // Route to appropriate handler
    if (path === "/auth/signup-email" && req.method === "POST") {
      return await signupEmail(functionReq);
    } else if (path === "/auth/login-email" && req.method === "POST") {
      return await loginEmail(functionReq);
    } else if (path === "/auth/phone-otp/request" && req.method === "POST") {
      return await phoneOtpRequest(functionReq);
    } else if (path === "/auth/phone-otp/verify" && req.method === "POST") {
      return await phoneOtpVerify(functionReq);
    } else if (path === "/auth/google-signin" && req.method === "POST") {
      return await googleSignin(functionReq);
    } else if (path === "/auth/logout" && req.method === "POST") {
      return await logout(functionReq);
    } else if (path === "/auth/password-reset/request" && req.method === "POST") {
      return await passwordResetRequest(functionReq);
    } else if (path === "/auth/password-reset/verify" && req.method === "POST") {
      return await passwordResetVerify(functionReq);
    } else if (path === "/auth/refresh-token" && req.method === "POST") {
      return await refreshToken(functionReq);
    } else {
      return errorResponse("Endpoint not found", "NOT_FOUND", 404);
    }
  } catch (error) {
    console.error("Request error:", error);
    return errorResponse("Internal server error", "INTERNAL_ERROR", 500);
  }
}

export default handleRequest;


