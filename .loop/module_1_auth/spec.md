# MODULE 1 AUTH — COMPLETE SPEC

**Slug:** module_1_auth
**Scope:** Authentication & Access Control (Flutter app + Backend + Database + Firebase)
**Status:** SPEC PHASE

---

## PROBLEM & GOAL

Fufaji's authentication system has **critical gaps** that block production deployment:

1. **Dual auth systems** — Firebase handles customers, but operational users (owner/admin/employee/delivery) have NO clear login flow
2. **Missing operational user tokens** — No JWT generation/refresh for non-Firebase users
3. **Unprotected routes** — Many backend endpoints lack role-based access control
4. **Unverified Firestore RLS** — Collection-level security rules may leak data
5. **Unclear account linking** — Privilege escalation risk (customer linking to owner account)

**Goal:** Implement a **complete, secure auth system** supporting 5 user types (customer, owner, admin, employee, delivery) with proper token management, RBAC, and data isolation.

---

## CRITICAL SPEC REFINEMENTS (From Parallel Reviews)

### 1. API SCHEMA: POST /auth/operational-login

```json
{
  "endpoint": "POST /auth/operational-login",
  "description": "Login for operational users (owner, admin, employee, delivery agent)",
  "request": {
    "login_id": "string (email, phone, or staff ID) — required",
    "pin": "string (4-8 digits) — required",
    "role": "string enum (owner|admin|employee|delivery) — optional (derived from login_id if not provided)"
  },
  "response_success": {
    "status": 200,
    "body": {
      "success": true,
      "token": "JWT string (7d expiry)",
      "refreshToken": "JWT string (30d expiry)",
      "user": {
        "id": "uuid",
        "name": "string",
        "phone": "string",
        "email": "string",
        "role": "owner|admin|employee|delivery",
        "shop_id": "string",
        "createdAt": "ISO 8601 timestamp"
      },
      "permissions": ["array of permission strings, e.g., 'view_orders', 'manage_staff'"],
      "expiresIn": 3600
    }
  },
  "response_error": {
    "status": 401,
    "body": {
      "success": false,
      "error": "invalid_credentials | user_not_found | account_locked | rate_limited",
      "message": "Login ID or PIN incorrect"
    }
  },
  "rate_limiting": "5 failed attempts per 15 minutes → lock account for 15 minutes",
  "security": {
    "query": "Parameterized query (prevent SQL injection)",
    "pin_comparison": "Use bcrypt.compare() for constant-time comparison",
    "audit": "Log attempt (success/failure) to security_events table with IP address, user agent"
  }
}
```

### 2. DATABASE MIGRATIONS: Staff + Token Blacklist Tables

```sql
-- ═══════════════════════════════════════════════════════════════════════
-- STAFF TABLE (Operational Users: Owner, Admin, Employee, Delivery)
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS staff (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id TEXT NOT NULL,
  login_id TEXT NOT NULL UNIQUE,              -- Email, phone, or custom ID (per-shop unique)
  pin_hash TEXT NOT NULL,                     -- Bcrypt hash (NOT plaintext)
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'employee', 'delivery')),
  phone TEXT NOT NULL UNIQUE,                 -- For account linking validation
  email TEXT,
  name TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  failed_login_count INT DEFAULT 0,           -- For lockout tracking
  locked_until TIMESTAMP NULL,                -- Account locked until this time
  last_login TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  
  -- Constraints
  UNIQUE(shop_id, login_id),                  -- Unique login_id per shop
  CONSTRAINT staff_phone_check CHECK (phone ~ '^\+?[1-9]\d{1,14}$')  -- E.164 format
);

CREATE INDEX idx_staff_shop_id ON staff(shop_id);
CREATE INDEX idx_staff_login_id ON staff(login_id);
CREATE INDEX idx_staff_phone ON staff(phone);
CREATE INDEX idx_staff_role ON staff(role);
CREATE INDEX idx_staff_is_active ON staff(is_active) WHERE is_active = true;
CREATE INDEX idx_staff_locked_until ON staff(locked_until) WHERE locked_until IS NOT NULL;

-- ═══════════════════════════════════════════════════════════════════════
-- TOKEN BLACKLIST TABLE (Revoked Tokens)
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS token_blacklist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,             -- Hash of JWT (NOT plaintext token)
  reason TEXT CHECK (reason IN ('logout', 'password_change', 'security_event', 'admin_revoke')),
  expires_at TIMESTAMP NOT NULL,               -- Token expires; blacklist entry cleaned up after this
  created_at TIMESTAMP DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT token_blacklist_expiry CHECK (expires_at > created_at)
);

CREATE INDEX idx_token_blacklist_user_id ON token_blacklist(user_id);
CREATE INDEX idx_token_blacklist_expires_at ON token_blacklist(expires_at);
CREATE INDEX idx_token_blacklist_token_hash ON token_blacklist(token_hash);

-- Cleanup: Periodically delete expired entries (or use TTL if supported by Supabase)
-- DELETE FROM token_blacklist WHERE expires_at < NOW();

-- ═══════════════════════════════════════════════════════════════════════
-- OPTIONAL: SESSIONS TABLE (If choosing stateful session design)
-- ═══════════════════════════════════════════════════════════════════════
-- Only create if spec chooses stateful sessions (see Session Design Decision section)

-- CREATE TABLE IF NOT EXISTS sessions (
--   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
--   user_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
--   token_hash TEXT NOT NULL UNIQUE,
--   ip_address INET,
--   user_agent TEXT,
--   device_id TEXT,
--   created_at TIMESTAMP DEFAULT NOW(),
--   expires_at TIMESTAMP NOT NULL,
--   revoked_at TIMESTAMP,
--   CONSTRAINT session_expiry CHECK (expires_at > created_at)
-- );
```

### 3. SESSION DESIGN DECISION: STATELESS (Recommended)

**Chosen Design:** Stateless JWT + Redis Blacklist

```markdown
## Session Management Architecture

We use **stateless JWT with Redis blacklist** for operational users:

### Token Validity Check
1. Verify JWT signature (backend secret)
2. Verify token not expired (exp claim)
3. Check if token in Redis blacklist
4. If all pass → token valid; request proceeds

### On Logout
1. POST /auth/logout { revokeAll?: boolean }
2. If revokeAll=false: Add token_hash to Redis blacklist (24h TTL)
3. If revokeAll=true: Add user_id to user_blacklist (overrides any token for that user, 1h TTL)
4. Client clears token from SharedPreferences
5. Return { success: true }

### Why Stateless?
- ✅ Faster (no DB lookup per request)
- ✅ Simpler (no sessions table schema)
- ✅ Scalable (backend-independent; works with multiple backend instances)
- ✅ Mobile-friendly (no session affinity needed)

### Design Implications
- User CAN have multiple simultaneous sessions (phone + tablet + desktop)
- logout() affects only current token
- logout-all (revokeAll=true) affects all tokens for user
- Token refresh (POST /auth/operational-refresh) returns new token pair
```

### 4. TOKEN SECRET ROTATION POLICY

```markdown
## JWT Signing Secret Management

### Storage
- **Environment Variable:** OPERATIONAL_JWT_SECRET
- **Backup Secret:** OPERATIONAL_JWT_SECRET_OLD (for key rotation gracefully)
- **Version:** Include JWT header `kid: v1` field for key version tracking

### Rotation Schedule
- Rotate every **90 days** (quarterly)
- During rotation:
  1. Generate new secret
  2. Keep old secret in OPERATIONAL_JWT_SECRET_OLD for 24 hours
  3. Tokens signed with new secret only (forward)
  4. Accept tokens signed with either secret (backward compat for 24h)
  5. After 24h, only accept tokens with new secret

### Key Format
- All secrets stored as **base64-encoded 256-bit random values** (32 bytes)
- Example: `base64(crypto.randomBytes(32))`

### Implementation
```javascript
// backend/src/auth.js
const JWT_SECRET_CURRENT = process.env.OPERATIONAL_JWT_SECRET;  // Current key
const JWT_SECRET_OLD = process.env.OPERATIONAL_JWT_SECRET_OLD;  // Old key (for rotation grace period)

function signToken(payload) {
  return jwt.sign(payload, JWT_SECRET_CURRENT, {
    expiresIn: '7d',
    algorithm: 'HS256',
    header: { kid: 'v1' }  // Key version
  });
}

function verifyToken(token) {
  try {
    return jwt.verify(token, JWT_SECRET_CURRENT, { algorithms: ['HS256'] });
  } catch (err) {
    // Try old secret (grace period for rotation)
    try {
      return jwt.verify(token, JWT_SECRET_OLD, { algorithms: ['HS256'] });
    } catch (err2) {
      throw new Error('Invalid or expired token');
    }
  }
}
```

### Emergency Rotation (If Secret Leaked)
1. Generate new secret immediately
2. Set OPERATIONAL_JWT_SECRET to new value
3. Invalidate all operational user tokens: 
   ```sql
   INSERT INTO token_blacklist (user_id, token_hash, reason, expires_at)
   SELECT id, '*', 'emergency_rotation', NOW() + INTERVAL '1 day'
   FROM staff WHERE role IN ('owner', 'admin', 'employee', 'delivery');
   ```
4. Force all operational users to re-login
5. Update Render/Supabase environment variables
```

### 5. FIRESTORE RLS RULES SPECIFICATION

```javascript
// firestore.rules (excerpts with detailed syntax)

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ═══════════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isOwner(shop_id) {
      return isSignedIn() && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'owner' && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.shop_id == shop_id;
    }
    
    function isAdmin(shop_id) {
      return isSignedIn() && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin' && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.shop_id == shop_id;
    }
    
    function isEmployee(shop_id) {
      return isSignedIn() && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'employee' && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.shop_id == shop_id;
    }
    
    function isCustomer() {
      return isSignedIn() && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'customer';
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // ORDERS COLLECTION
    // ═══════════════════════════════════════════════════════════════════════
    match /orders/{orderId} {
      // Customer sees only own orders
      allow read: if isSignedIn() && (
        resource.data.customerId == request.auth.uid ||  // Customer sees own
        isOwner(resource.data.shop_id) ||                // Owner sees all
        isAdmin(resource.data.shop_id)                   // Admin sees all
      );
      
      // Only backend can write (no client writes)
      allow write: if false;
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // DELIVERIES COLLECTION
    // ═══════════════════════════════════════════════════════════════════════
    match /deliveries/{deliveryId} {
      // Delivery agent sees own deliveries; owner/admin see all
      allow read: if isSignedIn() && (
        resource.data.deliveryAgentId == request.auth.uid ||  // Rider sees own
        isOwner(resource.data.shop_id) ||                       // Owner sees all
        isAdmin(resource.data.shop_id)                          // Admin sees all
      );
      
      // Delivery agent can update only own delivery (status, location)
      allow update: if isSignedIn() && request.auth.uid == resource.data.deliveryAgentId && request.resource.data.deliveryAgentId == resource.data.deliveryAgentId;
      
      // No client deletes
      allow delete: if false;
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // PRODUCTS COLLECTION
    // ═══════════════════════════════════════════════════════════════════════
    match /products/{productId} {
      // Public read (everyone can see products)
      allow read: if true;
      
      // Only owner/admin can write
      allow write: if isSignedIn() && (isOwner(resource.data.shop_id) || isAdmin(resource.data.shop_id));
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // WALLETS COLLECTION
    // ═══════════════════════════════════════════════════════════════════════
    match /wallets/{walletId} {
      // Customer sees own wallet; owner/admin see all
      allow read: if isSignedIn() && (
        resource.data.customerId == request.auth.uid ||  // Customer sees own
        isOwner(resource.data.shop_id) ||                 // Owner sees all
        isAdmin(resource.data.shop_id)                    // Admin sees all
      );
      
      // No client writes (backend writes only)
      allow write: if false;
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // USERS COLLECTION
    // ═══════════════════════════════════════════════════════════════════════
    match /users/{userId} {
      // User sees own doc; owner/admin can see all (for staff management)
      allow read: if isSignedIn() && (
        request.auth.uid == userId ||  // User sees own
        isOwner(resource.data.shop_id) ||  // Owner sees all users
        isAdmin(resource.data.shop_id)     // Admin sees all users
      );
      
      // User can update own doc; owner/admin can update any
      allow write: if isSignedIn() && (
        (request.auth.uid == userId && request.resource.data.role == resource.data.role) ||  // User can't escalate own role
        isOwner(resource.data.shop_id) ||  // Owner can edit any user
        isAdmin(resource.data.shop_id)     // Admin can edit any user
      );
    }
  }
}
```

---

## SCOPE

### In Scope (Will Implement)

**Backend:**
- ✅ `POST /auth/operational-login` — Login endpoint for owner/admin/employee/delivery users (API schema defined above)
- ✅ `POST /auth/operational-refresh` — Token refresh endpoint for custom JWT
- ✅ `POST /auth/logout` — Logout endpoint with optional revokeAll parameter
- ✅ JWT token generation, refresh, revocation for operational users
- ✅ Token blacklist (Redis or token_blacklist table) for revocation
- ✅ `@requireRole()` middleware audit + addition to all unprotected routes (estimated 80-120 endpoints)
- ✅ Rate limiting: 5 failed login attempts per 15 minutes → lock account for 15 minutes
- ✅ Account linking validation rules

**Flutter:**
- ✅ **🔴 FIX CRITICAL:** Remove Firebase Cloud Functions from `auth_service.dart` (VIOLATES CLAUDE.md §0 hard rule)
  - Current: Calls `FirebaseFunctions.instance.httpsCallable('verifyStaffCredentials')`
  - Change to: `POST /auth/operational-login` to Render/Supabase Edge Function backend
- ✅ Auth provider refactor: unified auth for all 5 user types (customer + owner/admin/employee/delivery)
- ✅ Token storage constants (FIREBASE_TOKEN_KEY, OPERATIONAL_TOKEN_KEY, OPERATIONAL_REFRESH_TOKEN_KEY)
- ✅ Token storage (SharedPreferences) + refresh logic for both Firebase tokens + custom JWT
- ✅ 401 interceptor: Auto-retry failed requests with refreshed token
- ✅ Session lifecycle management (login → logout with cleanup)
- ✅ Logout cleanup: Clear tokens, Firestore session doc, device trust, state, redirect
- ✅ Role-based navigation guards: `canAccessRoute(routeName, role)` utility + routing config

**Database:**
- ✅ Audit tables (audit_logs, security_events) for auth tracking
- ✅ Staff credentials table for operational user auth
- ✅ Session table for backend session tracking

**Firebase:**
- ✅ Firestore RLS rules audit + fix for all collections
- ✅ Verify data boundaries (customer sees only own orders, employee sees own deliveries)
- ✅ Remove dead Google Sign-In code if unused

### Out of Scope (P1/P2)

- ❌ Advanced MFA (TOTP, biometric deep integration) — P1
- ❌ Advanced device trust management — P1
- ❌ Password reset flow for operational users — P1
- ❌ Failed login attempt lockout — P2
- ❌ Session timeout idle detection — P2
- ❌ Password strength validation — P2

---

## EXIT CRITERIA (MUST ALL PASS)

### 1. Auth Flows Complete ✅
- [ ] `backend/docs/AUTH_FLOWS.md` exists and documents 5 complete flows (customer, owner, admin, employee, delivery)
- [ ] Each flow shows: request → backend validation → token generation → response
- [ ] Each flow includes error handling (invalid creds, user not found, etc.)

### 2. Operational User Login Implemented ✅
- [ ] `POST /auth/operational-login` endpoint exists in `backend/src/routes/auth.js`
- [ ] Accepts `{ login_id, pin/password, role }` and returns `{ token, user, permissions }`
- [ ] Verifies credentials against staff table in Supabase PostgreSQL
- [ ] Generates custom JWT (NOT Firebase) with exp, iat, user_id, role
- [ ] Rate limiting: max 5 login attempts per 15 minutes per user
- [ ] Audit logs login attempt (success/failure) to security_events table

### 3. Token Management for Operational Users ✅
- [ ] `backend/src/auth.js` exports token generation functions:
  - `generateOperationalUserToken(userId, role)` — creates JWT
  - `verifyOperationalUserToken(token)` — validates JWT
  - `refreshToken(oldToken)` — issues new token pair
  - `revokeToken(token)` — adds to 24h blacklist
- [ ] All functions tested (unit tests pass)
- [ ] Integration with `/auth/operational-login` endpoint

### 4. Permission Enforcement (@requireRole) ✅
- [ ] All routes in `backend/src/routes/*.js` use `requireRole()` middleware where needed
- [ ] Checklist completed: routes audited, missing @requireRole added
- [ ] Data boundary enforcement verified (e.g., customer gets only own orders)
- [ ] Tests pass for authorized + unauthorized access per endpoint

### 5. Firestore RLS Rules Verified ✅
- [ ] `firebaseRules/*.json` (or firestore.rules) audited
- [ ] Every collection has RLS enabled with proper rules:
  - **orders**: customer sees only own, owner/admin see all
  - **deliveries**: delivery agent sees own, owner/admin see all
  - **products**: public read, owner/admin write
  - **wallets**: customer sees own, owner/admin see all
- [ ] Write rules restrict to backend service role
- [ ] Rules tested in Firestore rules simulator

### 6. Account Linking Rules Enforced ✅
- [ ] `AccountLinkingService` validates:
  - One phone = one customer account only
  - One phone = one operational account only
  - Cannot link customer + operational to same phone
  - Role changes require approval
- [ ] Linked to `/auth/operational-login` and account linking UI
- [ ] Tests pass (duplicate account rejection, privilege escalation blocked)

### 7. Flutter Auth Provider Refactored ✅
- [ ] `lib/providers/auth_provider.dart` unified for all 5 user types
- [ ] Token storage in SharedPreferences works for custom JWT + Firebase
- [ ] Token refresh automatically triggered on 401 responses
- [ ] Logout properly clears tokens, Firestore session, device trust
- [ ] Role-based navigation guards in place (customer vs operational)

### 8. Audit Logging in Place ✅
- [ ] All auth events logged to `security_events` table:
  - Login success/failure, role, IP, user agent
  - Token refresh, revocation
  - Unauthorized access attempts
  - Account linking attempts
- [ ] Logs readable only by owner/admin (RLS applied)

### 9. Code Review Passed ✅
- [ ] Fresh-eyes review identifies zero blocking security findings
- [ ] All nits documented + resolved or accepted

### 10. Tests Pass ✅
- [ ] `backend/tests/auth.test.js` — all token tests pass
- [ ] `backend/tests/authorization.test.js` — all RBAC tests pass
- [ ] `backend/tests/firestore-rules.test.js` — all RLS tests pass
- [ ] `backend/tests/account-linking.test.js` — all linking tests pass
- [ ] No new test failures introduced

---

## IMPLEMENTATION PRIORITY

### P0 (BLOCKING) — Must complete
1. Operational user login endpoint + token generation
2. @requireRole middleware audit + fix on all routes
3. Firestore RLS rules verification + fixes
4. Account linking validation

### P1 (CORE) — Should complete
5. Flutter auth provider refactor
6. Audit logging for auth events
7. Token refresh/revocation

### P2 (POLISH) — If time permits
8. Auth documentation (flows, permission matrix)

---

## VERIFICATION PLAN

**Mode:** Static + Tests
- Run backend test suite (`npm test`) — all tests pass
- Run Firestore rules simulator — all RLS rules validated
- Code review from 5 angles: security, backend, flutter, database, firestore
- Verify exit criteria 1–10 with evidence (test output, code snippets, rule dumps)

---

## FILES EXPECTED TO CHANGE

| File | Type | Changes |
|------|------|---------|
| `backend/src/routes/auth.js` | modify | Add `/auth/operational-login` endpoint, token refresh logic |
| `backend/src/auth.js` | modify | Add token generation, verification, revocation functions |
| `backend/src/middleware/authorization.js` | modify/create | @requireRole middleware (if not exists) |
| `backend/src/routes/orders.js` | modify | Add @requireRole to all order endpoints |
| `backend/src/routes/checkout-routes.js` | modify | Add @requireRole to checkout endpoints |
| `backend/src/routes/delivery.js` | modify | Add @requireRole to delivery endpoints |
| `backend/src/routes/*.js` | modify | Audit all routes, add missing @requireRole |
| `firebaseRules/*.json` | modify | Audit + fix RLS rules for all collections |
| `lib/providers/auth_provider.dart` | modify | Refactor for all 5 user types |
| `lib/services/auth_service.dart` | modify | Add operational user login flow |
| `lib/services/AccountLinkingService.dart` | create | Implement account linking validation |
| `backend/src/services/AccountLinkingService.js` | create | Backend account linking validation |
| `backend/tests/auth.test.js` | create | Token generation, refresh, revocation tests |
| `backend/tests/authorization.test.js` | create | @requireRole middleware tests |
| `backend/tests/firestore-rules.test.js` | create | RLS rules validation tests |
| `backend/tests/account-linking.test.js` | create | Account linking validation tests |
| `backend/docs/AUTH_FLOWS.md` | create | Auth flows for all 5 user types |
| `backend/docs/PERMISSION_MATRIX.md` | create | RBAC matrix (who can do what) |

---

## CRITICAL IMPLEMENTATION NOTES

### Authentication Architecture (Per CLAUDE.md)
- ✅ **Source of Truth:** Supabase PostgreSQL for all user data
- ✅ **Token Type for Customers:** Firebase Auth tokens (existing)
- ✅ **Token Type for Operational Users:** Custom JWT signed with backend secret (new)
- ✅ **Firestore Role:** Read-only cache layer ONLY; all business logic writes go through backend → PostgreSQL → Firestore sync
- ✅ **No Firebase Cloud Functions:** Hard rule from CLAUDE.md §0. All operational user auth must go through Render/Supabase Edge Functions backend.
- ✅ **Idempotency:** All auth operations must be idempotent (repeated calls = same result; no double-loginattempts recorded, etc.)

### Data Flow
```
Flutter App
  → POST /auth/operational-login (Render backend)
  → Backend verifies credentials against PostgreSQL staff table
  → Backend generates JWT token + refresh token
  → Backend logs to security_events table
  → Returns tokens + user data to Flutter
  → Flutter stores tokens in SharedPreferences
  → Firestore eventually syncs user doc (async via outbox pattern)
```

### Token Lifecycle
```
Access Token (7d expiry):
- Used for API requests (Authorization: Bearer <token>)
- Auto-refresh on 401 response (Flutter interceptor)
- Added to blacklist on logout (24h TTL)

Refresh Token (30d expiry):
- Used to get new access token via POST /auth/operational-refresh
- Stored securely in SharedPreferences
- Discarded on logout

Token Blacklist:
- Redis key: `token_blacklist:${token_hash}` (TTL = token exp - now)
- Checked on every request: if in blacklist → 401 Unauthorized
- On logout: add current token to blacklist
- On logout-all: add user_id to user-level blacklist (overrides all tokens for 1h)
```

### Multi-Device Behavior (Stateless Design)
- User CAN be logged in on multiple devices simultaneously (phone + tablet + desktop)
- Each device has its own token pair
- logout() on device A → revokes only device A's token; device B still logged in
- logout-all via /auth/logout { revokeAll: true } → revokes all tokens for user

### Rate Limiting
- Failed login attempts tracked in staff.failed_login_count
- After 5 failures in 15 min: staff.locked_until = NOW() + 15 min
- POST /auth/operational-login returns 429 if account locked
- Lock auto-clears after 15 min OR can be manually cleared by admin

### Security Guarantees
- PIN stored as bcrypt hash (never plaintext)
- Login query uses parameterized statements (prevent SQL injection)
- PIN comparison uses bcrypt.compare() (constant-time, prevent timing attack)
- JWT tokens are stateless (faster than session lookup)
- Token secret rotated every 90 days (with 24h grace period for old secret)
- Emergency rotation: invalidate all operational user tokens immediately
- All auth events logged to security_events table (immutable via RLS)

### No Offline Auth
- Per CLAUDE.md §4: Offline not allowed for critical operations
- Operational user login REQUIRES active backend connection
- If backend unreachable, user must wait or retry
- No cached credentials for offline login (security risk)

---

## PARALLEL REVIEW ANGLES

This spec will be reviewed from 5 perspectives:

1. **Security** — Token handling, privilege escalation, injection risks, RLS gaps
2. **Backend** — Endpoint wiring, service integration, rate limiting, session mgmt
3. **Flutter** — Auth provider state, token storage, navigation guards, error handling
4. **Database** — Schema integrity, RLS policy syntax, audit table completeness
5. **Firestore** — Collection structure, RLS rules, read boundaries, write restrictions

---

**END SPEC**

Status: Ready for approval + parallel review
