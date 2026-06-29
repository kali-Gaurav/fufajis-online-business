/// ============================================================================
/// FUFAJI AUTHENTICATION COMPLETE REQUEST/RESPONSE LOGIC
/// ============================================================================
///
/// This file documents all authentication flows with complete request/response
/// format, validation logic, backend steps, database operations, and error
/// handling. This serves as the definitive specification for the auth system.
///
/// Architecture:
/// - Firebase Auth: User credentials (email/password, phone, Google)
/// - PostgreSQL: User profiles, role management, audit logs
/// - Firestore: Real-time user data, device sessions
/// - Redis: OTP storage, token blacklist, rate limiting
/// - JWT: Custom tokens for API authentication
///
/// ============================================================================
library;

// ignore_for_file: unused_element, empty_function_body

/// ============================================================================
/// SECTION 1: EMAIL/PASSWORD SIGNUP
/// ============================================================================
///
/// REQUEST: POST /auth/signup-email
///
/// REQUEST FORMAT:
/// {
///   "email": "user@example.com",
///   "password": "SecurePass123!",
///   "fullName": "John Doe",
///   "phone": "+919876543210"
/// }
///
/// VALIDATION LOGIC:
/// 1. Email Validation:
///    - Must match regex: /^[^\s@]+@[^\s@]+\.[^\s@]+$/
///    - Cannot be empty
///    - Must be <= 254 characters (RFC 5321)
///    - Check not already registered in Firebase Auth
///    - Check not already registered in PostgreSQL users table
///
/// 2. Password Validation:
///    - Minimum 8 characters
///    - At least 1 uppercase letter (A-Z)
///    - At least 1 lowercase letter (a-z)
///    - At least 1 number (0-9)
///    - At least 1 special character (!@#$%^&*)
///    - Cannot contain email address
///    - Cannot be commonly used password (check against blacklist)
///
/// 3. Full Name Validation:
///    - Not empty, not just whitespace
///    - 2-100 characters
///    - Contains only letters, spaces, hyphens
///
/// 4. Phone Validation:
///    - E.164 format (+country_code + digits)
///    - Minimum 10 digits after country code
///    - Maximum 15 digits total
///    - Country code must be valid
///
/// ERROR RESPONSES:
/// - 400 Bad Request: {
///     "success": false,
///     "errors": {
///       "email": "Invalid email format",
///       "password": "Password must contain uppercase, lowercase, number, and special character",
///       "phone": "Invalid phone format. Use E.164 format (e.g., +919876543210)"
///     }
///   }
/// - 409 Conflict: {
///     "success": false,
///     "code": "EMAIL_ALREADY_REGISTERED",
///     "message": "Email already registered. Please login or use recovery.",
///     "recoveryOptions": ["password_reset", "login"]
///   }
///
/// BACKEND LOGIC STEPS:
///
/// Step 1: Validate All Fields
///   - Validate email format with regex
///   - Validate password strength (length, chars, complexity)
///   - Validate fullName (non-empty, proper characters)
///   - Validate phone format (E.164)
///   - If any validation fails: return 400 with specific error messages
///
/// Step 2: Check Email Not in Use
///   - Query Firebase Auth: lookup user by email
///     - If found: return 409 Conflict (email exists in Firebase)
///   - Query PostgreSQL: SELECT * FROM users WHERE email = $1
///     - If found: return 409 Conflict (email exists in DB)
///   - Query Firestore: users collection, search by email
///     - If found: return 409 Conflict (email exists in Firestore)
///
/// Step 3: Create Firebase Auth User
///   - Call Firebase Admin SDK:
///     auth.createUser({
///       email: email,
///       password: password,
///       emailVerified: false,
///       disabled: false
///     })
///   - Catch errors:
///     - If email-already-exists: return 409 (race condition)
///     - If invalid-password: return 400 (shouldn't happen, already validated)
///     - If other error: return 500 (log error)
///   - Extract Firebase UID from response
///
/// Step 4: Create PostgreSQL User Record
///   - INSERT INTO users (
///       id,                    // Firebase UID
///       email,
///       phone,
///       full_name,
///       role,                  // 'customer'
///       account_type,          // 'individual'
///       status,                // 'active'
///       email_verified,        // false
///       phone_verified,        // false
///       created_at,            // NOW()
///       updated_at,            // NOW()
///       last_login_at,         // null
///       profile_image_url,     // null
///       bio,                   // null
///       preferences            // JSON empty object
///     ) VALUES (...)
///   - Catch errors:
///     - If unique constraint on email/phone: return 409 (race condition)
///     - If other DB error: rollback Firebase user, return 500
///
/// Step 5: Create Firestore User Document
///   - Create document: users/{uid} with:
///     {
///       "email": email,
///       "phone": phone,
///       "fullName": fullName,
///       "role": "customer",
///       "status": "active",
///       "emailVerified": false,
///       "phoneVerified": false,
///       "createdAt": FieldValue.serverTimestamp(),
///       "updatedAt": FieldValue.serverTimestamp(),
///       "preferences": {
///         "notifications": true,
///         "marketing_emails": false
///       }
///     }
///   - Enable real-time sync for user data
///   - Create users/{uid}/settings subcollection
///   - Create users/{uid}/devices subcollection (empty initially)
///
/// Step 6: Send Verification Email
///   - Generate email verification link via Firebase:
///     link = await auth.generateEmailVerificationLink(email)
///   - Or create custom verification token:
///     - Generate 32-char random token
///     - Store in PostgreSQL: email_verification_tokens table
///       - token (indexed), user_id, email, created_at, expires_at (24h)
///     - Build verification link: /verify-email?token=xxxxx
///   - Send email via Sendgrid/AWS SES:
///     - Subject: "Verify your Fufaji Account"
///     - Template: welcome_verification_email
///     - Include: verification link, expiry time (24 hours)
///     - Handle email send failure gracefully (don't fail signup)
///
/// Step 7: Generate JWT Token
///   - Create JWT with claims:
///     {
///       "alg": "HS256",
///       "typ": "JWT"
///     }
///     {
///       "uid": firebase_uid,
///       "email": email,
///       "role": "customer",
///       "accountType": "individual",
///       "emailVerified": false,
///       "phoneVerified": false,
///       "iat": now_unix_timestamp,
///       "exp": now_unix_timestamp + 86400  // 24 hours
///     }
///   - Sign with SECRET_KEY: HMAC-SHA256
///   - Return token string
///
/// Step 8: Log Security Event
///   - INSERT INTO audit_logs (
///       user_id, event_type, event_name, details, ip_address, user_agent, created_at
///     ) VALUES (uid, 'auth', 'signup_success', {...}, client_ip, user_agent, NOW())
///
/// Step 9: Return Success Response
///
/// SUCCESS RESPONSE (201 Created):
/// {
///   "success": true,
///   "user": {
///     "uid": "firebase-uid-123",
///     "email": "user@example.com",
///     "fullName": "John Doe",
///     "phone": "+919876543210",
///     "role": "customer",
///     "emailVerified": false,
///     "createdAt": "2026-06-28T10:30:00Z"
///   },
///   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
///   "expiresIn": 86400,
///   "message": "Account created successfully! Check your email to verify your account."
/// }
///

Future<SignupResponse> signupWithEmail({
  required String email,
  required String password,
  required String fullName,
  required String phone,
}) async {
  // VALIDATION LAYER
  // Validate email format
  // Validate password strength (length, chars, complexity)
  // Validate fullName (non-empty, 2-100 chars, proper characters)
  // Validate phone format (E.164)
  // If any validation fails: throw ValidationException with field errors

  // DUPLICATE CHECK
  // Check email not in Firebase Auth
  // Check email not in PostgreSQL users table
  // Check email not in Firestore
  // If found: throw ConflictException

  // FIREBASE USER CREATION
  // Create Firebase Auth user with email/password
  // Extract UID
  // If fails: rethrow Firebase exception (map to 400/500)

  // POSTGRESQL USER CREATION
  // INSERT into users table with all profile data
  // If fails: rollback Firebase, rethrow DB exception

  // FIRESTORE USER CREATION
  // Create users/{uid} document in Firestore
  // Create users/{uid}/settings subcollection
  // If fails: log error but don't fail (PostgreSQL is source of truth)

  // SEND VERIFICATION EMAIL
  // Generate verification token
  // Store in email_verification_tokens table
  // Send verification email via Sendgrid
  // If email send fails: log but continue (user can request new email)

  // GENERATE JWT TOKEN
  // Create custom JWT with user claims
  // Sign with SECRET_KEY

  // LOG SECURITY EVENT
  // INSERT audit log: signup_success

  // RETURN SUCCESS RESPONSE
  return SignupResponse(
    success: true,
    user: UserData(
      uid: 'firebase-uid-123',
      email: email,
      fullName: fullName,
      phone: phone,
      role: 'customer',
      emailVerified: false,
      createdAt: DateTime.now(),
    ),
    token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
    expiresIn: 86400,
    message: 'Account created successfully! Check your email to verify your account.',
  );
}

/// ============================================================================
/// SECTION 2: EMAIL/PASSWORD LOGIN
/// ============================================================================
///
/// REQUEST: POST /auth/login-email
///
/// REQUEST FORMAT:
/// {
///   "email": "user@example.com",
///   "password": "SecurePass123!"
/// }
///
/// VALIDATION LOGIC:
/// 1. Email: Must be valid format
/// 2. Password: Not empty, not null
/// 3. Both required fields present
///
/// ERROR RESPONSES:
/// - 400 Bad Request: {
///     "success": false,
///     "errors": {
///       "email": "Email is required",
///       "password": "Password is required"
///     }
///   }
/// - 401 Unauthorized: {
///     "success": false,
///     "code": "INVALID_CREDENTIALS",
///     "message": "Invalid email or password",
///     "attempts": 1  // Track failed attempts
///   }
/// - 403 Forbidden: {
///     "success": false,
///     "code": "ACCOUNT_SUSPENDED",
///     "message": "Your account has been suspended. Contact support.",
///     "contactEmail": "support@fufaji.com"
///   }
/// - 429 Too Many Requests: {
///     "success": false,
///     "code": "TOO_MANY_ATTEMPTS",
///     "message": "Too many login attempts. Try again in 15 minutes.",
///     "retryAfter": 900
///   }
///
/// BACKEND LOGIC STEPS:
///
/// Step 1: Validate Input
///   - Check email not empty and valid format
///   - Check password not empty
///   - If validation fails: return 400
///
/// Step 2: Rate Limiting Check
///   - Get from Redis: "login_attempts:email@example.com"
///   - If exists and count >= 5:
///     - return 429 Too Many Requests
///     - Include retryAfter: expiry time in Redis
///   - Increment attempt counter
///   - Set expiry: 15 minutes from now
///
/// Step 3: Verify Email Exists in Firebase
///   - Call Firebase Admin SDK: auth.getUserByEmail(email)
///   - If error (user-not-found):
///     - Increment failed attempts in Redis
///     - return 401 "Invalid email or password" (don't reveal which)
///   - Extract Firebase UID from response
///
/// Step 4: Authenticate with Firebase
///   - Use Firebase REST API or Admin SDK to verify password
///   - Or use: signInWithEmailAndPassword(email, password) via client SDK
///   - If password wrong:
///     - Increment failed attempts
///     - return 401 "Invalid email or password"
///   - Get Firebase ID token (if using REST API)
///
/// Step 5: Fetch User from PostgreSQL
///   - Query: SELECT * FROM users WHERE id = $1
///   - If not found:
///     - This is data integrity error (Firebase user exists but no DB record)
///     - Log error, return 500
///   - Extract user data: role, status, email_verified, phone_verified
///
/// Step 6: Check User Status
///   - If status = 'suspended':
///     - Log security event: login_attempted_suspended
///     - return 403 "Account suspended"
///   - If status = 'deleted':
///     - return 401 "User not found"
///   - If status != 'active':
///     - return 403 "Account not active"
///
/// Step 7: Check Email Verification (Optional Based on Policy)
///   - If email_verified = false AND policy requires verification:
///     - return 403 "Please verify your email first"
///     - Include resend verification link option
///   - Otherwise: continue (allow login without email verification)
///
/// Step 8: Clear Failed Attempts
///   - Delete from Redis: "login_attempts:email@example.com"
///
/// Step 9: Create Custom JWT Token
///   - Build JWT payload:
///     {
///       "uid": firebase_uid,
///       "email": email,
///       "role": user.role,
///       "accountType": "customer",
///       "emailVerified": user.email_verified,
///       "phoneVerified": user.phone_verified,
///       "iat": now_unix_timestamp,
///       "exp": now_unix_timestamp + 86400
///     }
///   - Sign with SECRET_KEY: HMAC-SHA256
///
/// Step 10: Update Last Login
///   - UPDATE users SET last_login_at = NOW() WHERE id = $1
///
/// Step 11: Log Security Event
///   - INSERT INTO audit_logs:
///     event_type: 'auth'
///     event_name: 'login_success'
///     user_id: uid
///     ip_address: client_ip
///     user_agent: client_user_agent
///
/// Step 12: Return Success Response
///
/// SUCCESS RESPONSE (200 OK):
/// {
///   "success": true,
///   "user": {
///     "uid": "firebase-uid-123",
///     "email": "user@example.com",
///     "fullName": "John Doe",
///     "role": "customer",
///     "status": "active",
///     "emailVerified": true,
///     "phoneVerified": false
///   },
///   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
///   "expiresIn": 86400
/// }
///

Future<LoginResponse> loginWithEmail({
  required String email,
  required String password,
  String? clientIp,
  String? userAgent,
}) async {
  // VALIDATION
  // Check email not empty and valid format
  // Check password not empty
  // If invalid: throw ValidationException

  // RATE LIMITING
  // Check Redis: login_attempts:{email}
  // If attempts >= 5: return 429 Too Many Requests
  // Increment attempt counter, set 15-min expiry

  // VERIFY EMAIL EXISTS IN FIREBASE
  // Call Firebase Admin SDK: getUserByEmail(email)
  // If not found: increment attempts, return 401

  // AUTHENTICATE WITH FIREBASE
  // Verify password (Firebase REST API or Admin SDK)
  // If password wrong: increment attempts, return 401

  // FETCH USER FROM POSTGRESQL
  // Query: SELECT * FROM users WHERE id = firebase_uid
  // Extract user data: role, status, email_verified

  // CHECK USER STATUS
  // If status = 'suspended': return 403 "Account suspended"
  // If status = 'deleted': return 401 "User not found"
  // If status != 'active': return 403

  // CHECK EMAIL VERIFICATION (if required)
  // If policy requires email verified and not verified:
  //   return 403 with option to resend verification

  // CLEAR FAILED ATTEMPTS
  // Delete Redis: login_attempts:{email}

  // CREATE CUSTOM JWT TOKEN
  // Build JWT payload with user claims
  // Sign with SECRET_KEY

  // UPDATE LAST LOGIN
  // UPDATE users SET last_login_at = NOW() WHERE id = uid

  // LOG SECURITY EVENT
  // INSERT audit_logs: login_success

  // RETURN SUCCESS RESPONSE
  return LoginResponse(
    success: true,
    user: UserData(
      uid: 'firebase-uid-123',
      email: email,
      role: 'customer',
      status: 'active',
      emailVerified: true,
      phoneVerified: false,
    ),
    token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
    expiresIn: 86400,
  );
}

/// ============================================================================
/// SECTION 3: PHONE NUMBER LOGIN (OTP FLOW)
/// ============================================================================
///
/// PART A: REQUEST OTP
///
/// REQUEST: POST /auth/phone-otp/request
///
/// REQUEST FORMAT:
/// {
///   "phone": "+919876543210",
///   "countryCode": "IN"
/// }
///
/// VALIDATION LOGIC:
/// 1. Phone Format:
///    - E.164 format: +{country_code}{digits}
///    - 10-15 digits total
///    - Valid country code
///    - Not empty
///
/// 2. Country Code:
///    - Supported in policy (check allowlist)
///    - Matches country code in phone
///
/// 3. Rate Limiting:
///    - Max 3 OTP requests per hour per phone
///    - Max 10 OTP requests per day per IP
///    - Store in Redis with TTL
///
/// ERROR RESPONSES:
/// - 400 Bad Request: {
///     "success": false,
///     "errors": {
///       "phone": "Invalid phone format. Use E.164 (e.g., +919876543210)",
///       "countryCode": "Country code not supported"
///     }
///   }
/// - 429 Too Many Requests: {
///     "success": false,
///     "code": "RATE_LIMITED",
///     "message": "Too many OTP requests. Try again in 1 hour.",
///     "retryAfter": 3600
///   }
///
/// BACKEND LOGIC STEPS:
///
/// Step 1: Validate Phone Format
///   - Check matches E.164 regex: /^\+[1-9]\d{1,14}$/
///   - Extract country code from phone (first 1-3 digits after +)
///   - If countryCode param provided: verify matches phone
///   - If validation fails: return 400
///
/// Step 2: Check Phone Service Support
///   - Query config table: supported_countries
///   - If country not supported: return 400 with supported list
///
/// Step 3: Rate Limit Check (Per Phone)
///   - Query Redis: "otp_requests:phone:{phone}"
///   - Format: list of {timestamp, status} entries
///   - Count requests in last 60 minutes
///   - If count >= 3:
///     - return 429 with retryAfter = (oldest_request + 1 hour - now)
///   - Add new entry: {timestamp: now, status: 'pending'}
///   - Set Redis expiry: 1 hour
///
/// Step 4: Rate Limit Check (Per IP)
///   - Query Redis: "otp_requests:ip:{client_ip}"
///   - Count requests in last 24 hours
///   - If count >= 10:
///     - return 429 with retryAfter = 86400
///
/// Step 5: Check if Phone Already Registered
///   - Query PostgreSQL: SELECT id, status FROM users WHERE phone = $1
///   - If found:
///     - Extract user_id and status
///     - If status = 'suspended': log and continue (can still request OTP for security reasons)
///   - If not found:
///     - Phone is new user
///
/// Step 6: Generate OTP
///   - Generate 6-digit random number (000000-999999)
///   - Avoid patterns: 000000, 111111, 222222, etc.
///   - OTP validity: 5 minutes
///
/// Step 7: Store OTP in Redis
///   - Key: "otp:{phone}"
///   - Value: {
///       "otp": "123456",
///       "attempts": 0,
///       "max_attempts": 5,
///       "created_at": unix_timestamp,
///       "expires_at": unix_timestamp + 300
///     }
///   - TTL: 300 seconds (5 minutes)
///   - If key exists: overwrite (allow new OTP request before expiry)
///
/// Step 8: Send OTP via SMS
///   - Use Twilio or AWS SNS
///   - SMS Template: "Your Fufaji verification code is: 123456. Valid for 5 minutes."
///   - Track SMS send in PostgreSQL:
///     INSERT INTO otp_logs (phone, otp_type, sent_at, delivery_status, sms_provider)
///   - If SMS send fails:
///     - Log error with phone number (masked)
///     - Return 500 "Failed to send OTP, try again"
///     - Delete OTP from Redis
///
/// Step 9: Log Request Event
///   - INSERT INTO audit_logs: event='otp_requested'
///
/// SUCCESS RESPONSE (200 OK):
/// {
///   "success": true,
///   "message": "OTP sent to your phone",
///   "expiresIn": 300,
///   "phoneHashed": "9***3210",
///   "requestId": "req_7Oy8OMjw3bqn"  // For verification pairing
/// }
///

Future<OtpRequestResponse> requestPhoneOtp({
  required String phone,
  required String countryCode,
  String? clientIp,
}) async {
  // VALIDATE PHONE FORMAT
  // Check E.164 format
  // Extract country code from phone
  // Verify matches countryCode parameter
  // If invalid: throw ValidationException

  // CHECK COUNTRY SUPPORT
  // Query config table for supported countries
  // If not supported: return 400 with supported list

  // RATE LIMIT CHECK (Per Phone)
  // Query Redis: otp_requests:phone:{phone}
  // Count requests in last 60 minutes
  // If count >= 3: return 429 with retryAfter

  // RATE LIMIT CHECK (Per IP)
  // Query Redis: otp_requests:ip:{client_ip}
  // Count requests in last 24 hours
  // If count >= 10: return 429

  // CHECK IF PHONE REGISTERED
  // Query: SELECT id, status FROM users WHERE phone = $1
  // Extract user_id if found

  // GENERATE OTP
  // Generate 6-digit random (avoid patterns)

  // STORE OTP IN REDIS
  // Key: otp:{phone}
  // Value: {otp, attempts: 0, max_attempts: 5, expires_at}
  // TTL: 300 seconds

  // SEND SMS
  // Call Twilio/SNS API
  // Log send in otp_logs table
  // If fails: delete OTP from Redis, return 500

  // LOG AUDIT EVENT
  // INSERT audit_logs: otp_requested

  // RETURN SUCCESS RESPONSE
  return OtpRequestResponse(
    success: true,
    message: 'OTP sent to your phone',
    expiresIn: 300,
    phoneHashed: '9***3210',
    requestId: 'req_7Oy8OMjw3bqn',
  );
}

/// ============================================================================
///
/// PART B: VERIFY OTP
///
/// REQUEST: POST /auth/phone-otp/verify
///
/// REQUEST FORMAT:
/// {
///   "phone": "+919876543210",
///   "otp": "123456",
///   "requestId": "req_7Oy8OMjw3bqn"
/// }
///
/// VALIDATION LOGIC:
/// 1. Phone: Valid E.164 format
/// 2. OTP: Exactly 6 digits
/// 3. Phone and OTP not empty
/// 4. Request ID matches (prevent abuse)
///
/// ERROR RESPONSES:
/// - 400 Bad Request: {
///     "success": false,
///     "errors": {
///       "otp": "OTP must be 6 digits"
///     }
///   }
/// - 401 Unauthorized: {
///     "success": false,
///     "code": "INVALID_OTP",
///     "message": "Invalid OTP. Please try again.",
///     "attempts": 2,
///     "attemptsRemaining": 3
///   }
/// - 429 Too Many Requests: {
///     "success": false,
///     "code": "TOO_MANY_ATTEMPTS",
///     "message": "Too many failed attempts. Request new OTP.",
///     "attemptsRemaining": 0
///   }
/// - 410 Gone: {
///     "success": false,
///     "code": "OTP_EXPIRED",
///     "message": "OTP expired. Request a new one.",
///     "action": "request_new_otp"
///   }
///
/// BACKEND LOGIC STEPS:
///
/// Step 1: Validate Input
///   - Phone: valid E.164 format
///   - OTP: exactly 6 digits, matches /^\d{6}$/
///   - RequestId: not empty
///   - If invalid: return 400
///
/// Step 2: Retrieve OTP from Redis
///   - Key: "otp:{phone}"
///   - If key doesn't exist:
///     - return 410 "OTP expired"
///   - Extract OTP data: otp, attempts, max_attempts, expires_at
///
/// Step 3: Check OTP Expiry
///   - If current_time > expires_at:
///     - Delete OTP from Redis
///     - return 410 "OTP expired"
///
/// Step 4: Check Attempt Limit
///   - If attempts >= max_attempts:
///     - Delete OTP from Redis
///     - return 429 "Too many attempts, request new OTP"
///
/// Step 5: Compare OTP
///   - Compare submitted_otp with stored_otp (constant-time comparison)
///   - If not equal:
///     - Increment attempts in Redis
///     - Return 401 with attemptsRemaining = max_attempts - attempts
///     - If this was last attempt: delete OTP on next request
///
/// Step 6: OTP Valid - Get or Create User
///   - Query PostgreSQL: SELECT * FROM users WHERE phone = $1
///   - If user exists:
///     - Extract user_id, email, role, status
///     - isNewUser = false
///   - If user doesn't exist:
///     - This is new phone signup
///     - isNewUser = true
///     - Will create user in next steps
///
/// Step 7: Authenticate with Firebase
///   - If user exists:
///     - Get Firebase user by UID (from PostgreSQL)
///     - If Firebase user exists: use it
///     - If Firebase user doesn't exist: data integrity error, create it
///   - If new user:
///     - Create Firebase Auth user with phone:
///       auth.createUser({
///         phoneNumber: phone,
///         disabled: false
///       })
///     - Extract Firebase UID
///
/// Step 8: Create User in PostgreSQL (if new)
///   - INSERT INTO users (
///       id,                    // Firebase UID
///       phone,
///       email,                 // null for phone-only signup
///       full_name,             // null initially
///       role,                  // 'customer'
///       status,                // 'active'
///       phone_verified,        // true
///       email_verified,        // false
///       created_at,
///       signup_method          // 'phone_otp'
///     ) VALUES (...)
///
/// Step 9: Create Firestore Document (if new)
///   - Create users/{uid} doc:
///     {
///       "phone": phone,
///       "role": "customer",
///       "phoneVerified": true,
///       "createdAt": FieldValue.serverTimestamp(),
///       "signupMethod": "phone_otp"
///     }
///
/// Step 10: Clear OTP
///   - Delete Redis key: "otp:{phone}"
///
/// Step 11: Create Custom JWT Token
///   - Build payload:
///     {
///       "uid": firebase_uid,
///       "phone": phone,
///       "email": user.email || null,
///       "role": user.role,
///       "phoneVerified": true,
///       "emailVerified": user.email_verified || false,
///       "iat": now_unix,
///       "exp": now_unix + 86400
///     }
///   - Sign with SECRET_KEY
///
/// Step 12: Update Last Login
///   - UPDATE users SET last_login_at = NOW() WHERE id = $1
///
/// Step 13: Log Security Event
///   - INSERT INTO audit_logs: event='phone_otp_verified'
///
/// SUCCESS RESPONSE (200 OK):
/// {
///   "success": true,
///   "user": {
///     "uid": "firebase-uid-456",
///     "phone": "+919876543210",
///     "email": null,
///     "role": "customer",
///     "phoneVerified": true,
///     "emailVerified": false
///   },
///   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
///   "expiresIn": 86400,
///   "isNewUser": true,
///   "message": "Login successful! Complete your profile to get started."
/// }
///

Future<OtpVerifyResponse> verifyPhoneOtp({
  required String phone,
  required String otp,
  required String requestId,
  String? clientIp,
}) async {
  // VALIDATE INPUT
  // Check phone is valid E.164 format
  // Check otp is exactly 6 digits
  // Check requestId not empty
  // If invalid: throw ValidationException

  // RETRIEVE OTP FROM REDIS
  // Key: otp:{phone}
  // If not found: return 410 "OTP expired"

  // CHECK EXPIRY
  // Compare current_time with expires_at
  // If expired: delete OTP, return 410

  // CHECK ATTEMPT LIMIT
  // If attempts >= max_attempts: delete OTP, return 429

  // COMPARE OTP (CONSTANT-TIME COMPARISON)
  // If not equal: increment attempts, return 401 with attemptsRemaining

  // GET OR CREATE USER
  // Query: SELECT * FROM users WHERE phone = $1
  // If found: isNewUser = false
  // If not found: isNewUser = true

  // AUTHENTICATE WITH FIREBASE
  // If user exists: get Firebase user by UID
  // If new user: create Firebase Auth user with phone

  // CREATE USER IN POSTGRESQL (if new)
  // INSERT into users table with phone-otp signup method

  // CREATE FIRESTORE DOCUMENT (if new)
  // Create users/{uid} with phone signup info

  // CLEAR OTP
  // Delete Redis: otp:{phone}

  // CREATE CUSTOM JWT TOKEN
  // Build payload with phone and email info
  // Sign with SECRET_KEY

  // UPDATE LAST LOGIN
  // UPDATE users SET last_login_at = NOW() WHERE id = uid

  // LOG AUDIT EVENT
  // INSERT audit_logs: phone_otp_verified

  // RETURN SUCCESS RESPONSE
  return OtpVerifyResponse(
    success: true,
    user: UserData(
      uid: 'firebase-uid-456',
      phone: phone,
      role: 'customer',
      phoneVerified: true,
      emailVerified: false,
    ),
    token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
    expiresIn: 86400,
    isNewUser: true,
    message: 'Login successful! Complete your profile to get started.',
  );
}

/// ============================================================================
/// SECTION 4: GOOGLE SIGN-IN
/// ============================================================================
///
/// REQUEST: POST /auth/google-signin
///
/// REQUEST FORMAT:
/// {
///   "googleIdToken": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjEifQ...",
///   "deviceId": "device-uuid-123"
/// }
///
/// VALIDATION LOGIC:
/// 1. Google ID Token: Valid JWT format
/// 2. Device ID: Valid UUID format
/// 3. Token not already used (replay attack prevention)
///
/// ERROR RESPONSES:
/// - 400 Bad Request: {
///     "success": false,
///     "errors": {
///       "googleIdToken": "Invalid token format"
///     }
///   }
/// - 401 Unauthorized: {
///     "success": false,
///     "code": "INVALID_GOOGLE_TOKEN",
///     "message": "Google token is invalid or expired. Please try again."
///   }
///
/// BACKEND LOGIC STEPS:
///
/// Step 1: Validate Token Format
///   - Check if googleIdToken is valid JWT format
///   - Count dots: should have 2 dots (3 parts separated by dots)
///   - Validate base64 encoding of each part
///   - If invalid: return 400
///
/// Step 2: Verify Google Signature
///   - Decode JWT (don't verify yet)
///   - Fetch Google public keys from:
///     https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com
///   - Find key by kid in JWT header
///   - Verify signature with public key using RS256
///   - If signature invalid: return 401 "Invalid token"
///
/// Step 3: Validate Token Claims
///   - Check "iss" claim: must be "https://accounts.google.com" or "https://securetoken.google.com"
///   - Check "aud" claim: must match your Google Client ID
///   - Check "iat" (issued at): not in future
///   - Check "exp" (expiration): must be >= now (token still valid)
///   - If token older than 1 hour: return 401 "Token expired"
///   - If claims invalid: return 401
///
/// Step 4: Check for Replay Attacks
///   - Store token hash in Redis:
///     Key: "used_google_tokens:{token_hash}"
///     Value: {timestamp, user_id}
///     TTL: 3600 seconds (1 hour, matches token expiry)
///   - If key already exists: return 401 "Token already used"
///
/// Step 5: Extract User Data from Token
///   - Token payload contains:
///     {
///       "sub": "google-user-id-123",      // Google user ID
///       "email": "user@gmail.com",
///       "email_verified": true,
///       "name": "John Doe",
///       "picture": "https://lh3.googleusercontent.com/...",
///       "given_name": "John",
///       "family_name": "Doe",
///       "iat": 1687951234,
///       "exp": 1687951234 + 3600
///     }
///   - Extract all fields
///
/// Step 6: Check if Email Already Registered
///   - Query PostgreSQL: SELECT * FROM users WHERE email = $1
///   - If found:
///     - Check if user.google_id matches token.sub (linking existing account)
///     - If google_id exists: user already linked Google, proceed to login
///     - If google_id is null: first time linking Google to existing email account
///       - Ask user confirmation before linking
///       - Or: auto-link if emails match exactly
///
/// Step 7: Get or Create Firebase User
///   - If email account exists in Firebase:
///     - Get Firebase UID
///   - If email account doesn't exist in Firebase:
///     - Create Firebase Auth user with email + Google credential:
///       auth.createUser({
///         email: email,
///         displayName: name,
///         photoUrl: picture,
///         disabled: false
///       })
///   - Extract Firebase UID
///
/// Step 8: Link Google Credential (if new)
///   - Use Firebase Admin SDK to link Google credential to user:
///     admin.auth().updateUser(uid, {
///       customClaims: {
///         googleId: token.sub
///       }
///     })
///   - Or store in PostgreSQL: UPDATE users SET google_id = $1
///
/// Step 9: Create/Update User in PostgreSQL
///   - If user exists:
///     - UPDATE users SET:
///       - google_id = token.sub (if null)
///       - email_verified = true (from token)
///       - profile_image_url = picture (if not already set)
///       - updated_at = NOW()
///   - If new user:
///     - INSERT INTO users (
///         id,                   // Firebase UID
///         email,
///         full_name,            // from name
///         profile_image_url,    // from picture
///         google_id,            // from sub
///         role,                 // 'customer'
///         status,               // 'active'
///         email_verified,       // true (Google verifies)
///         signup_method,        // 'google'
///         created_at
///       ) VALUES (...)
///
/// Step 10: Create/Update Firestore Document
///   - If new user:
///     - Create users/{uid}:
///       {
///         "email": email,
///         "fullName": name,
///         "avatar": picture,
///         "googleId": sub,
///         "role": "customer",
///         "emailVerified": true,
///         "createdAt": FieldValue.serverTimestamp(),
///         "signupMethod": "google"
///       }
///   - If existing user:
///     - Update users/{uid}:
///       - Last login timestamp
///       - Avatar if new picture
///
/// Step 11: Store Device Trust (Optional)
///   - Insert into user_devices table:
///     - user_id, device_id, device_name
///     - trusted = false (user can approve later)
///     - last_seen = NOW()
///   - This enables "trusted devices" feature later
///
/// Step 12: Create Custom JWT Token
///   - Build payload:
///     {
///       "uid": firebase_uid,
///       "email": email,
///       "name": name,
///       "googleId": sub,
///       "role": "customer",
///       "emailVerified": true,
///       "iat": now_unix,
///       "exp": now_unix + 86400
///     }
///   - Sign with SECRET_KEY
///
/// Step 13: Update Last Login
///   - UPDATE users SET last_login_at = NOW() WHERE id = $1
///
/// Step 14: Log Security Event
///   - INSERT INTO audit_logs: event='google_signin'
///
/// SUCCESS RESPONSE (200 OK):
/// {
///   "success": true,
///   "user": {
///     "uid": "firebase-uid-789",
///     "email": "user@gmail.com",
///     "fullName": "John Doe",
///     "avatar": "https://lh3.googleusercontent.com/...",
///     "role": "customer",
///     "emailVerified": true
///   },
///   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
///   "expiresIn": 86400,
///   "isNewUser": true
/// }
///

Future<GoogleSigninResponse> signInWithGoogle({
  required String googleIdToken,
  required String deviceId,
  String? clientIp,
}) async {
  // VALIDATE TOKEN FORMAT
  // Check JWT structure (3 base64 parts separated by dots)
  // Validate base64 encoding
  // If invalid: return 400

  // VERIFY GOOGLE SIGNATURE
  // Fetch Google public keys from Google API
  // Find key by kid in JWT header
  // Verify signature with RS256 algorithm
  // If invalid: return 401

  // VALIDATE TOKEN CLAIMS
  // Check iss: must be Google
  // Check aud: must match your Google Client ID
  // Check iat: not in future
  // Check exp: must be >= now
  // If token older than 1 hour: return 401
  // If claims invalid: return 401

  // CHECK FOR REPLAY ATTACKS
  // Hash token (SHA256)
  // Check Redis: used_google_tokens:{token_hash}
  // If exists: return 401 "Token already used"
  // Store hash in Redis with 1-hour TTL

  // EXTRACT USER DATA FROM TOKEN
  // Decode JWT payload
  // Extract: sub (Google ID), email, name, picture, email_verified

  // CHECK EMAIL NOT ALREADY REGISTERED
  // Query: SELECT * FROM users WHERE email = $1
  // If found:
  //   - Check if google_id matches (already linked)
  //   - If yes: proceed to login
  //   - If no: return 409 or ask for confirmation

  // GET OR CREATE FIREBASE USER
  // If email exists in Firebase: get UID
  // If not exists: create Firebase user with email + Google credential

  // LINK GOOGLE CREDENTIAL
  // Update Firebase: link Google credential to user
  // Store in PostgreSQL: google_id

  // CREATE/UPDATE POSTGRESQL USER
  // If new: INSERT into users table with Google signup info
  // If existing: UPDATE last_login, google_id if null

  // CREATE/UPDATE FIRESTORE DOCUMENT
  // If new: create users/{uid} with Google signup data
  // If existing: update avatar, last login

  // STORE DEVICE TRUST
  // INSERT into user_devices table
  // device_id, device_name, trusted = false

  // CREATE CUSTOM JWT TOKEN
  // Build payload with user claims
  // Sign with SECRET_KEY

  // UPDATE LAST LOGIN
  // UPDATE users SET last_login_at = NOW()

  // LOG AUDIT EVENT
  // INSERT audit_logs: google_signin

  // RETURN SUCCESS RESPONSE
  return GoogleSigninResponse(
    success: true,
    user: UserData(
      uid: 'firebase-uid-789',
      email: 'user@gmail.com',
      fullName: 'John Doe',
      role: 'customer',
      emailVerified: true,
    ),
    token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
    expiresIn: 86400,
    isNewUser: true,
  );
}

/// ============================================================================
/// SECTION 5: LOGOUT
/// ============================================================================
///
/// REQUEST: POST /auth/logout
///
/// REQUEST FORMAT:
/// {
///   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
/// }
///
/// Note: Token passed for security audit (optional, can be extracted from header)
///
/// VALIDATION LOGIC:
/// - JWT token valid (signature, expiry, claims)
/// - Token not already blacklisted
///
/// ERROR RESPONSES:
/// - 401 Unauthorized: {
///     "success": false,
///     "code": "INVALID_TOKEN",
///     "message": "Invalid or expired token"
///   }
///
/// BACKEND LOGIC STEPS:
///
/// Step 1: Verify JWT Token
///   - Extract token from Authorization header or request body
///   - Verify signature with SECRET_KEY
///   - If signature invalid: return 401
///   - Ignore expiry check for logout (allow logout with expired token)
///
/// Step 2: Extract Token Claims
///   - Decode JWT (already verified)
///   - Extract: uid, exp (expiration time), iat (issued at)
///   - If claims missing: return 401
///
/// Step 3: Add Token to Blacklist
///   - Hash token: SHA256(token)
///   - Store in Redis:
///     Key: "blacklist:token_{hash}"
///     Value: {uid, iat, exp, logout_at}
///     TTL: exp - now (token expires automatically when no longer valid)
///   - This prevents token reuse for already-expired tokens
///   - For tokens expiring in future: keep in blacklist until natural expiry
///
/// Step 4: Invalidate All User Sessions (Optional - AGGRESSIVE)
///   - If implementing "logout all devices" feature:
///     - Query: SELECT * FROM user_devices WHERE user_id = $1
///     - For each device: mark as inactive
///     - Or: set all device tokens to blacklist
///     - This forces re-login on all devices
///
/// Step 5: Clear Active Sessions
///   - Query Firestore: users/{uid}/devices subcollection
///   - Delete all device sessions for this user
///   - Or: mark all as inactive
///
/// Step 6: Delete User Cache
///   - If using Redis/Memcached for user data:
///     - Delete: "user:{uid}:data"
///     - Delete: "user:{uid}:permissions"
///     - Delete: "user:{uid}:roles"
///
/// Step 7: Remove Push Notification Tokens
///   - Query: SELECT * FROM device_tokens WHERE user_id = $1
///   - Delete all device FCM tokens
///   - Or: mark as logged out (don't send notifications)
///
/// Step 8: Log Security Event
///   - INSERT INTO audit_logs:
///     - event_type: 'auth'
///     - event_name: 'logout'
///     - user_id: uid
///     - ip_address: client_ip
///     - details: {device_id, logout_reason}
///     - created_at: NOW()
///
/// Step 9: Update Last Activity
///   - UPDATE users SET last_activity_at = NOW() WHERE id = $1
///
/// SUCCESS RESPONSE (200 OK):
/// {
///   "success": true,
///   "message": "Logged out successfully"
/// }
///

Future<LogoutResponse> logout({
  required String token,
  String? clientIp,
}) async {
  // VERIFY JWT TOKEN
  // Extract token from Authorization header
  // Verify signature with SECRET_KEY
  // Ignore expiry for logout
  // If signature invalid: return 401

  // EXTRACT TOKEN CLAIMS
  // Decode JWT (already verified)
  // Extract: uid, exp, iat
  // If claims missing: return 401

  // ADD TOKEN TO BLACKLIST
  // Hash token: SHA256(token)
  // Store in Redis:
  //   Key: blacklist:token_{hash}
  //   Value: {uid, iat, exp, logout_at: now}
  //   TTL: exp - now

  // INVALIDATE ALL SESSIONS (optional aggressive logout)
  // Query: SELECT * FROM user_devices WHERE user_id = uid
  // Mark all as inactive
  // Or add all device tokens to blacklist

  // CLEAR ACTIVE SESSIONS
  // Query Firestore: users/{uid}/devices
  // Delete or mark inactive

  // DELETE USER CACHE
  // Delete from Redis: user:{uid}:data
  // Delete from Redis: user:{uid}:permissions

  // REMOVE PUSH NOTIFICATION TOKENS
  // Query: SELECT * FROM device_tokens WHERE user_id = uid
  // Delete all FCM tokens

  // LOG SECURITY EVENT
  // INSERT audit_logs: logout event

  // UPDATE LAST ACTIVITY
  // UPDATE users SET last_activity_at = NOW()

  // RETURN SUCCESS RESPONSE
  return LogoutResponse(
    success: true,
    message: 'Logged out successfully',
  );
}

/// ============================================================================
/// SECTION 6: PASSWORD RESET REQUEST
/// ============================================================================
///
/// REQUEST: POST /auth/password-reset/request
///
/// REQUEST FORMAT:
/// {
///   "email": "user@example.com"
/// }
///
/// VALIDATION LOGIC:
/// - Email format valid
/// - Email is not empty
///
/// Note: Do NOT reveal whether email is registered (prevents email enumeration)
/// Always return 200 OK regardless of whether email exists
///
/// ERROR RESPONSES:
/// - 400 Bad Request: {
///     "success": false,
///     "errors": {
///       "email": "Invalid email format"
///     }
///   }
/// - 429 Too Many Requests: {
///     "success": false,
///     "code": "RATE_LIMITED",
///     "message": "Too many password reset requests. Try again in 1 hour.",
///     "retryAfter": 3600
///   }
///
/// BACKEND LOGIC STEPS:
///
/// Step 1: Validate Email Format
///   - Check matches email regex: /^[^\s@]+@[^\s@]+\.[^\s@]+$/
///   - Check <= 254 characters
///   - If invalid: return 400 (okay to reveal invalid format)
///
/// Step 2: Rate Limit Per Email
///   - Query Redis: "password_reset_requests:{email}"
///   - If exists and count >= 3 in last hour:
///     - return 429 "Too many requests, try again in 1 hour"
///   - Increment counter
///   - Set TTL: 1 hour
///
/// Step 3: Rate Limit Per IP
///   - Query Redis: "password_reset_requests:ip:{client_ip}"
///   - If count >= 10 in last hour:
///     - return 429 "Too many requests from your IP"
///
/// Step 4: Check Email Exists (Silently)
///   - Query PostgreSQL: SELECT id FROM users WHERE email = $1
///   - If not found:
///     - Log event: "password_reset_requested_unregistered_email"
///     - Continue to step 9 (return same response as if email exists)
///   - If found:
///     - Extract user_id
///     - Continue to step 5
///
/// Step 5: Generate Reset Token
///   - Generate 32-char random string using crypto:
///     - Use random bytes (256 bits)
///     - Encode as hex or base64url
///     - Must be cryptographically secure (not predictable)
///   - Token examples: "a7f2e8d9c1b4e6f3a2d5c8e1b4f7a9c2"
///   - Validity: 30 minutes (1800 seconds)
///
/// Step 6: Store Reset Token in Redis
///   - Key: "password_reset:{email}"
///   - Value: {
///       "token": "a7f2e8d9c1b4e6f3a2d5c8e1b4f7a9c2",
///       "user_id": user_id,
///       "email": email,
///       "attempts": 0,
///       "max_attempts": 5,
///       "created_at": unix_timestamp,
///       "expires_at": unix_timestamp + 1800
///     }
///   - TTL: 1800 seconds (30 minutes)
///
/// Step 7: Also Store Token Hash in PostgreSQL (for audit trail)
///   - Hash token: SHA256(token)
///   - INSERT INTO password_reset_tokens (
///       user_id, email, token_hash, expires_at, created_at
///     ) VALUES (user_id, email, hash, NOW() + 30min, NOW())
///   - Keep for audit trail (can query later)
///
/// Step 8: Send Password Reset Email
///   - Use Sendgrid/AWS SES
///   - Email template: password_reset_email
///   - Subject: "Reset Your Fufaji Password"
///   - Body includes:
///     - Reset link: https://yourapp.com/reset?token=a7f2e8d9c1b4e6f3a2d5c8e1b4f7a9c2
///     - Expiry: "This link expires in 30 minutes"
///     - Security notice: "If you didn't request this, ignore it"
///     - Support link: "Contact support if you have issues"
///   - If email send fails:
///     - Log error (don't fail request)
///     - Return 200 anyway (user will retry if email not received)
///     - Note: User can request new reset link
///
/// Step 9: Log Request Event
///   - INSERT INTO audit_logs (
///       user_id (null if unregistered email),
///       event_type: 'auth',
///       event_name: 'password_reset_requested',
///       details: {email_masked: "u***@e****.com"},
///       ip_address,
///       user_agent
///     )
///
/// SUCCESS RESPONSE (200 OK) - ALWAYS:
/// {
///   "success": true,
///   "message": "Check your email for password reset instructions.",
///   "note": "If you don't receive the email, check your spam folder."
/// }
///
/// Note: Same response whether email exists or not (security best practice)
///

Future<PasswordResetRequestResponse> requestPasswordReset({
  required String email,
  String? clientIp,
}) async {
  // VALIDATE EMAIL FORMAT
  // Check matches regex
  // Check <= 254 characters
  // If invalid: return 400

  // RATE LIMIT (Per Email)
  // Query Redis: password_reset_requests:{email}
  // If count >= 3 in last hour: return 429

  // RATE LIMIT (Per IP)
  // Query Redis: password_reset_requests:ip:{client_ip}
  // If count >= 10 in last hour: return 429

  // CHECK EMAIL EXISTS (Silently)
  // Query: SELECT id FROM users WHERE email = $1
  // Extract user_id if found (but don't reveal if not found)

  // GENERATE RESET TOKEN
  // Generate 32-char random cryptographic string
  // Validity: 30 minutes

  // STORE RESET TOKEN IN REDIS
  // Key: password_reset:{email}
  // Value: {token, user_id, attempts: 0, max_attempts: 5, expires_at}
  // TTL: 1800 seconds

  // STORE TOKEN HASH IN POSTGRESQL
  // INSERT into password_reset_tokens table
  // For audit trail

  // SEND RESET EMAIL
  // Use Sendgrid/AWS SES
  // Include reset link with token
  // Include expiry time (30 minutes)
  // If send fails: log but continue (return success anyway)

  // LOG AUDIT EVENT
  // INSERT audit_logs: password_reset_requested

  // RETURN SUCCESS (ALWAYS)
  // Same response whether email exists or not
  return PasswordResetRequestResponse(
    success: true,
    message: 'Check your email for password reset instructions.',
    note: 'If you don\'t receive the email, check your spam folder.',
  );
}

/// ============================================================================
/// SECTION 7: PASSWORD RESET VERIFY
/// ============================================================================
///
/// REQUEST: POST /auth/password-reset/verify
///
/// REQUEST FORMAT:
/// {
///   "token": "a7f2e8d9c1b4e6f3a2d5c8e1b4f7a9c2",
///   "newPassword": "NewSecurePass123!"
/// }
///
/// VALIDATION LOGIC:
/// 1. Token: Valid format, not empty, valid hex string
/// 2. New Password: Meets strength requirements (same as signup)
///
/// ERROR RESPONSES:
/// - 400 Bad Request: {
///     "success": false,
///     "errors": {
///       "token": "Invalid token format",
///       "newPassword": "Password must be at least 8 characters"
///     }
///   }
/// - 401 Unauthorized: {
///     "success": false,
///     "code": "INVALID_TOKEN",
///     "message": "Invalid password reset token"
///   }
/// - 410 Gone: {
///     "success": false,
///     "code": "TOKEN_EXPIRED",
///     "message": "Password reset link has expired. Request a new one."
///   }
/// - 429 Too Many Requests: {
///     "success": false,
///     "code": "TOO_MANY_ATTEMPTS",
///     "message": "Too many failed attempts. Request a new reset link."
///   }
///
/// BACKEND LOGIC STEPS:
///
/// Step 1: Validate Token Format
///   - Check token is not empty
///   - Check is valid hex string (32 chars, 0-9a-f)
///   - If invalid: return 400
///
/// Step 2: Validate New Password
///   - Same validation as signup:
///     - Minimum 8 characters
///     - At least 1 uppercase, 1 lowercase, 1 number, 1 special char
///     - Not commonly used password
///     - Not same as email
///   - If invalid: return 400 with specific errors
///
/// Step 3: Lookup Token in Redis
///   - Query Redis: "password_reset:{email}" (hmm, we need email from token)
///   - Problem: we don't know email from token
///   - Solution 1: Store in Redis: "reset_token:{token_hex}" -> {email, user_id}
///     - Query: "reset_token:{token}"
///     - Get email + user_id
///   - Solution 2: Have client send email + token
///     - Query: "password_reset:{email}"
///     - Compare token field
///   - Use Solution 1 for better UX (client only sends token)
///
/// Step 4: Check Token Validity
///   - If token not found in Redis:
///     - return 410 "Token expired or invalid"
///   - If expired (current_time > expires_at):
///     - Delete from Redis
///     - return 410 "Token expired"
///
/// Step 5: Check Attempt Limit
///   - If attempts >= max_attempts:
///     - Delete token from Redis
///     - return 429 "Too many attempts, request new reset link"
///
/// Step 6: Compare Password with Current
///   - Query PostgreSQL: SELECT password_hash FROM users WHERE id = user_id
///   - If new password same as current:
///     - return 400 "New password must be different from current"
///   - Check if new password is commonly used old password:
///     - Query password_history table for this user
///     - Prevent reusing last 5 passwords (optional security)
///
/// Step 7: Update Firebase Auth Password
///   - Use Firebase Admin SDK:
///     admin.auth().updateUser(uid, {
///       password: newPassword
///     })
///   - Or: Use Firebase REST API password reset endpoint
///   - If fails: return 500 (log error)
///
/// Step 8: Hash New Password
///   - Use bcrypt: hash(newPassword, rounds=12)
///   - Store hash (don't store plaintext)
///
/// Step 9: Update PostgreSQL User
///   - UPDATE users SET
///       password_hash = $1,          // bcrypt hash
///       password_changed_at = NOW(),
///       password_reset_at = NOW()
///     WHERE id = $2
///   - Also insert into password_history for audit:
///     INSERT INTO password_history (user_id, old_password_hash, changed_at)
///       VALUES (user_id, old_password_hash, NOW())
///
/// Step 10: Delete Reset Token
///   - DELETE from Redis: "reset_token:{token}"
///   - Also delete from PostgreSQL: DELETE FROM password_reset_tokens WHERE token_hash = $1
///
/// Step 11: Invalidate All Existing Tokens
///   - Get all active JWT tokens for this user:
///     - Query: SELECT * FROM jwt_tokens WHERE user_id = $1 AND valid = true
///     - Or: Add all user's current tokens to blacklist
///   - For each token:
///     - Add to Redis blacklist with token expiry as TTL
///   - This forces user to re-login with new password
///   - Send notification: "Password changed, please re-login"
///
/// Step 12: Clear User Cache
///   - Delete from Redis: "user:{user_id}:*"
///   - This ensures next login gets fresh data
///
/// Step 13: Log Security Event
///   - INSERT INTO audit_logs:
///     - user_id
///     - event_type: 'auth'
///     - event_name: 'password_reset_verified'
///     - details: {ip_address, user_agent}
///     - created_at: NOW()
///
/// Step 14: Send Confirmation Email
///   - Use Sendgrid/AWS SES
///   - Subject: "Your Fufaji Password Has Been Changed"
///   - Body:
///     - "Your password was successfully reset"
///     - "You'll need to log in again with your new password"
///     - "If you didn't make this change, contact support immediately"
///     - Support link
///
/// SUCCESS RESPONSE (200 OK):
/// {
///   "success": true,
///   "message": "Password updated successfully. Please log in with your new password."
/// }
///

Future<PasswordResetVerifyResponse> verifyPasswordReset({
  required String token,
  required String newPassword,
}) async {
  // VALIDATE TOKEN FORMAT
  // Check not empty
  // Check is valid hex string (32 chars)
  // If invalid: return 400

  // VALIDATE NEW PASSWORD
  // Check strength requirements
  // Check != email
  // Check not commonly used
  // If invalid: return 400

  // LOOKUP TOKEN IN REDIS
  // Query: "reset_token:{token}"
  // Get email + user_id
  // If not found: return 410 "Token expired or invalid"

  // CHECK TOKEN VALIDITY
  // If expired: delete from Redis, return 410

  // CHECK ATTEMPT LIMIT
  // If attempts >= max_attempts: delete token, return 429

  // COMPARE WITH CURRENT PASSWORD
  // Query: SELECT password_hash FROM users WHERE id = user_id
  // If new password same as current: return 400
  // Check password_history to prevent reuse

  // UPDATE FIREBASE PASSWORD
  // Call Firebase Admin SDK
  // If fails: return 500

  // HASH NEW PASSWORD
  // Use bcrypt with 12 rounds

  // UPDATE POSTGRESQL USER
  // UPDATE users SET password_hash, password_changed_at, password_reset_at
  // INSERT into password_history

  // DELETE RESET TOKEN
  // Delete from Redis: reset_token:{token}
  // Delete from PostgreSQL password_reset_tokens table

  // INVALIDATE ALL EXISTING TOKENS
  // Add all user's current tokens to blacklist
  // Force re-login on all devices

  // CLEAR USER CACHE
  // Delete from Redis: user:{user_id}:*

  // LOG SECURITY EVENT
  // INSERT audit_logs: password_reset_verified

  // SEND CONFIRMATION EMAIL
  // Use Sendgrid/AWS SES
  // Include warning about re-login needed

  // RETURN SUCCESS RESPONSE
  return PasswordResetVerifyResponse(
    success: true,
    message: 'Password updated successfully. Please log in with your new password.',
  );
}

/// ============================================================================
/// SECTION 8: REFRESH TOKEN
/// ============================================================================
///
/// REQUEST: POST /auth/refresh-token
///
/// REQUEST FORMAT:
/// {
///   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." (expired or expiring)
/// }
///
/// VALIDATION LOGIC:
/// - Token is valid JWT format (even if expired)
/// - Signature is valid (not tampered)
/// - Token not in blacklist
///
/// Note: Refresh tokens are used to get new access tokens without re-login
/// Allow even if main token is expired
///
/// ERROR RESPONSES:
/// - 400 Bad Request: {
///     "success": false,
///     "errors": {
///       "token": "Invalid token format"
///     }
///   }
/// - 401 Unauthorized: {
///     "success": false,
///     "code": "INVALID_TOKEN",
///     "message": "Invalid or revoked token. Please log in again."
///   }
///
/// BACKEND LOGIC STEPS:
///
/// Step 1: Validate Token Format
///   - Check JWT structure (3 base64 parts)
///   - Decode header + payload
///   - If invalid: return 400
///
/// Step 2: Verify Signature
///   - Extract signature from JWT
///   - Recompute: base64(header) + "." + base64(payload)
///   - HMAC-SHA256(body, SECRET_KEY) should equal signature
///   - Use constant-time comparison
///   - If invalid: return 401 (token tampered)
///
/// Step 3: Extract Token Claims
///   - Decode payload (already verified)
///   - Extract: uid, email, role, iat, exp
///   - Check all required claims present
///   - If missing: return 401
///
/// Step 4: Check Token Not Blacklisted
///   - Hash token: SHA256(token)
///   - Query Redis: "blacklist:token_{hash}"
///   - If exists: return 401 "Token revoked"
///
/// Step 5: Ignore Expiry Check
///   - Don't check if token is expired
///   - Allow refresh even with expired token
///   - This is the point of refresh tokens
///
/// Step 6: Verify User Still Exists
///   - Query PostgreSQL: SELECT * FROM users WHERE id = uid
///   - If not found: return 401 "User not found"
///   - Extract: role, status, email_verified
///
/// Step 7: Check User Status
///   - If status = 'suspended':
///     - return 401 "Account suspended, cannot refresh"
///   - If status = 'deleted':
///     - return 401 "Account not found"
///   - If status != 'active':
///     - return 401
///
/// Step 8: Generate New JWT Token
///   - Create new token with current claims:
///     {
///       "uid": uid,
///       "email": email,
///       "role": role,
///       "accountType": "customer",
///       "iat": now_unix,
///       "exp": now_unix + 86400  // New 24-hour expiry
///     }
///   - Sign with SECRET_KEY
///
/// Step 9: Log Refresh Event (Optional)
///   - INSERT INTO audit_logs:
///     - user_id: uid
///     - event_type: 'auth'
///     - event_name: 'token_refreshed'
///     - ip_address: client_ip
///
/// SUCCESS RESPONSE (200 OK):
/// {
///   "success": true,
///   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
///   "expiresIn": 86400
/// }
///

Future<RefreshTokenResponse> refreshToken({
  required String token,
  String? clientIp,
}) async {
  // VALIDATE TOKEN FORMAT
  // Check JWT structure
  // Decode header + payload
  // If invalid: return 400

  // VERIFY SIGNATURE
  // Extract signature
  // Recompute HMAC-SHA256(body, SECRET_KEY)
  // Compare with constant-time comparison
  // If invalid: return 401

  // EXTRACT TOKEN CLAIMS
  // Decode payload
  // Extract: uid, email, role, iat, exp
  // If missing claims: return 401

  // CHECK TOKEN NOT BLACKLISTED
  // Hash token: SHA256(token)
  // Query Redis: blacklist:token_{hash}
  // If exists: return 401 "Token revoked"

  // IGNORE EXPIRY CHECK
  // Allow refresh even if expired

  // VERIFY USER STILL EXISTS
  // Query: SELECT * FROM users WHERE id = uid
  // If not found: return 401

  // CHECK USER STATUS
  // If status != 'active': return 401

  // GENERATE NEW JWT TOKEN
  // Create new token with same claims but fresh iat/exp
  // exp = now + 86400 (24 hours)
  // Sign with SECRET_KEY

  // LOG REFRESH EVENT (optional)
  // INSERT audit_logs: token_refreshed

  // RETURN SUCCESS RESPONSE
  return RefreshTokenResponse(
    success: true,
    token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
    expiresIn: 86400,
  );
}

/// ============================================================================
/// ============================================================================
/// END OF AUTHENTICATION LOGIC
/// ============================================================================
/// ============================================================================

// Model classes for requests/responses
class SignupResponse {
  final bool success;
  final UserData user;
  final String token;
  final int expiresIn;
  final String message;

  SignupResponse({
    required this.success,
    required this.user,
    required this.token,
    required this.expiresIn,
    required this.message,
  });
}

class LoginResponse {
  final bool success;
  final UserData user;
  final String token;
  final int expiresIn;

  LoginResponse({
    required this.success,
    required this.user,
    required this.token,
    required this.expiresIn,
  });
}

class UserData {
  final String uid;
  final String? email;
  final String? phone;
  final String? fullName;
  final String? avatar;
  final String role;
  final String? status;
  final bool emailVerified;
  final bool phoneVerified;
  final DateTime? createdAt;

  UserData({
    required this.uid,
    this.email,
    this.phone,
    this.fullName,
    this.avatar,
    required this.role,
    this.status,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.createdAt,
  });
}

class OtpRequestResponse {
  final bool success;
  final String message;
  final int expiresIn;
  final String phoneHashed;
  final String requestId;

  OtpRequestResponse({
    required this.success,
    required this.message,
    required this.expiresIn,
    required this.phoneHashed,
    required this.requestId,
  });
}

class OtpVerifyResponse {
  final bool success;
  final UserData user;
  final String token;
  final int expiresIn;
  final bool isNewUser;
  final String message;

  OtpVerifyResponse({
    required this.success,
    required this.user,
    required this.token,
    required this.expiresIn,
    required this.isNewUser,
    required this.message,
  });
}

class GoogleSigninResponse {
  final bool success;
  final UserData user;
  final String token;
  final int expiresIn;
  final bool isNewUser;

  GoogleSigninResponse({
    required this.success,
    required this.user,
    required this.token,
    required this.expiresIn,
    required this.isNewUser,
  });
}

class LogoutResponse {
  final bool success;
  final String message;

  LogoutResponse({
    required this.success,
    required this.message,
  });
}

class PasswordResetRequestResponse {
  final bool success;
  final String message;
  final String note;

  PasswordResetRequestResponse({
    required this.success,
    required this.message,
    required this.note,
  });
}

class PasswordResetVerifyResponse {
  final bool success;
  final String message;

  PasswordResetVerifyResponse({
    required this.success,
    required this.message,
  });
}

class RefreshTokenResponse {
  final bool success;
  final String token;
  final int expiresIn;

  RefreshTokenResponse({
    required this.success,
    required this.token,
    required this.expiresIn,
  });
}
