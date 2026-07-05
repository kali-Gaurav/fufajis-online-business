# MODULE 1 AUTH — PARALLEL REVIEWS SUMMARY

**Review Date:** 2026-07-05
**Review Method:** 5 parallel specialist agents (Security, Backend, Flutter, Database, Firestore)
**Spec Reviewed:** `.loop/module_1_auth/spec.md`
**Status:** SPEC REQUIRES REFINEMENT before implementation can proceed

---

## EXECUTIVE SUMMARY

Parallel review **confirms spec is architecturally sound but operationally underspecified**. All 5 review angles identified **overlapping blockers:**

### BLOCKING ISSUES (Must fix BEFORE coding)

| Category | Blocker | Impact | Severity |
|----------|---------|--------|----------|
| **Backend** | POST /auth/operational-login API schema not defined | Cannot implement endpoint without guessing request/response format | 🔴 CRITICAL |
| **Backend** | Staff table schema not defined | Cannot write login query; operational user login impossible | 🔴 CRITICAL |
| **Backend** | Session management strategy undefined (single vs multi-device) | Cannot implement logout correctly; affects token validity checks | 🔴 CRITICAL |
| **Database** | `staff` table MISSING | Nowhere to store operational user credentials | 🔴 CRITICAL |
| **Database** | `token_blacklist` table MISSING | Cannot revoke tokens; logout ineffective | 🔴 CRITICAL |
| **Flutter** | Auth service uses Firebase Cloud Functions (VIOLATES CLAUDE.md §0) | Architecture inconsistency; increased cost; must use Render/Edge Functions | 🔴 CRITICAL |
| **Flutter** | 401 token refresh interceptor NOT IMPLEMENTED | Token refresh won't auto-trigger; 401 errors won't retry | 🔴 CRITICAL |
| **Security** | Firestore RLS rules syntax NOT PROVIDED (only high-level list) | Cannot verify data boundaries; rules missing/incomplete in codebase | 🔴 CRITICAL |
| **Security** | Token signing secret rotation policy UNDEFINED | No key rotation plan; leaked secret = indefinite token forgery | 🔴 CRITICAL |
| **Security** | login_id + PIN validation lacks injection protection spec | SQL injection risk in login query not addressed | 🟡 HIGH |

---

## REVIEW RESULTS BY ANGLE

### 1️⃣ SECURITY REVIEW — Token Handling, Privilege Escalation, Data Isolation

**Status:** ⚠️ CONDITIONAL APPROVAL

**Strengths (3):**
- ✅ Dual token architecture correct (Firebase vs custom JWT)
- ✅ Token expiration defined (7d access, 30d refresh)
- ✅ Firestore as read-only cache (no client-side mutations)

**Critical Gaps:**
1. **Token Secret Rotation Policy Missing** — Where is JWT secret stored? Rotation cadence? Key versioning in JWT header? Must spec before coding.
2. **login_id + PIN Validation Not Hardened** — Must use parameterized queries + constant-time PIN comparison (bcrypt.compare, not ==)
3. **Token Blacklist 24h Window Too Short** — After logout, token valid for 24h if stolen. For payment ops, should be immediate revocation + 1h grace.
4. **Rate Limiting (5 per 15min) Incomplete** — No lockout clause. Account should lock for 15min after 5 failures, not just reject 6th attempt.
5. **Firestore RLS Rules Not Specified** — Spec lists collections but provides NO rule syntax. Cannot verify data leakage prevention.
6. **No Session Revocation Endpoint** — Spec has `revokeToken()` function but no `/auth/logout` endpoint. How do users logout from all devices?
7. **MFA Enforcement Missing for Owner/Admin** — Deferred to P1, but owners handle financial ops. Should be P0.
8. **Audit Log Immutability Not Guaranteed** — No DELETE restrictions on security_events table. Insider can clear logs post-hack.

**Blocking Findings:** YES (3 items)
1. Token secret rotation policy
2. Firestore RLS rule syntax
3. Mandatory MFA for owner/admin (change to P0)

---

### 2️⃣ BACKEND REVIEW — Endpoint Wiring, Service Integration, Middleware

**Status:** ⚠️ CONDITIONAL APPROVAL

**Strengths (4):**
- ✅ `requireRole()` middleware already exists in codebase
- ✅ Token refresh endpoint exists (`POST /auth/refresh`)
- ✅ Token revocation function correctly scoped (backend-only)
- ✅ Separation of concerns (caller enforces permissions, service executes)

**Critical Gaps:**
1. **POST /auth/operational-login Schema Undefined** — Request format? Is role in body or derived? Does response include permissions? Exact field names?
   
2. **Staff Table Schema Not Defined** — What columns needed? login_id type (email/phone/custom)? pin or password? is_active? failed_login_count for lockout?

3. **Logout Endpoint Missing** — Spec has `revokeToken()` function but no endpoint. Is it `/auth/logout`? Body schema? Supports `revokeAll`?

4. **Session Management Strategy Undefined** — Single-session (new login invalidates old) or multi-device (multiple concurrent sessions)? Affects logout + token validity design.

5. **@requireRole Coverage Vastly Underestimated** — Spec says "audit all routes" but actual scope: 31 route files, ~139 endpoints. Estimated 8-12 hours to audit + fix, but spec says nothing about effort/timeline.

6. **AccountLinkingService Integration Point Missing** — When is it called? During login? On signup? What triggers validation?

7. **No Token Blacklist Implementation Specified** — `revokeToken()` mentioned but no implementation details (Redis key format? TTL? Fallback if Redis down?).

8. **Database Queries Not Specified** — Staff table lookup syntax? Idempotency? What happens if same user logs in twice?

**Blocking Findings:** YES (5 items)
1. POST /auth/operational-login request/response schema
2. Staff table schema + query
3. POST /auth/logout endpoint
4. Session design choice (single vs multi-device)
5. @requireRole coverage estimate + prioritized route list

---

### 3️⃣ FLUTTER REVIEW — Auth Provider, Token Storage, Navigation Guards

**Status:** ⚠️ CONDITIONAL APPROVAL

**Strengths (3):**
- ✅ Unified `AuthProvider` class exists (handles all 5 user types)
- ✅ `UserRole` enum fully defined (10 roles available)
- ✅ Multi-layer storage infrastructure (SecureStorage, SharedPreferences, Hive, SQLite)

**Critical Gaps:**
1. **🔴 Firebase Cloud Functions Used in Auth Service** — VIOLATES CLAUDE.md §0 hard rule ("NEVER USE FIREBASE CLOUD FUNCTIONS"). Must switch to Render/Supabase Edge Function backend.

2. **Token Storage Keys Not Standardized** — No constants defined. Firebase vs operational tokens use different keys but no pattern. Will scatter hardcoded strings throughout codebase.

3. **401 Retry Interceptor Not Wired** — Spec mentions "automatically triggered on 401" but `ApiClient` implementation unknown. If missing, token refresh fails silently + user logged out unexpectedly.

4. **Logout Method Incomplete/Missing** — Not visible in readable code. Must clear: SharedPreferences tokens, Firestore session doc, device trust, state, redirect to login.

5. **Navigation Guards Not Implemented** — Spec says "role-based guards in place" but no route protection code visible. High-privilege UI could show to low-privilege users.

6. **Multi-Device Policy Undefined** — Can user be logged in on 2+ devices simultaneously? Logout on device A shouldn't affect device B (or should it?). Design choice not specified.

7. **Token Expiry Check Missing** — No app lifecycle listener checking if token < 5 min to expiry and auto-refreshing.

8. **Google Sign-In Removal Incomplete** — Still imported + used in code, but spec says "customer-only". Operational users could bypass PIN via Google (if enabled).

**Blocking Findings:** YES (1 hard blocker + 4 critical gaps)
1. 🔴 **HARD BLOCKER:** Firebase Cloud Functions — must switch to backend endpoint
2. Token storage constants definition
3. 401 interceptor wiring
4. Logout complete implementation
5. Navigation guards implementation

---

### 4️⃣ DATABASE REVIEW — Schema, RLS Policies, Audit Tables

**Status:** 🔴 **BLOCKING**

**Strengths (2):**
- ✅ Audit tables complete (`audit_logs`, `security_events`, `change_logs`, `api_call_logs`, `anomaly_logs`)
- ✅ RLS policies properly restrict audit tables to owner/admin only
- ✅ Indexes well-designed (correlation_id, user_id, action, created_at)

**Critical Gaps (BLOCKING):**
1. **🔴 `staff` Table MISSING** — No table for storing operational user credentials. Cannot implement `/auth/operational-login` without it.
   - Must define schema: id, shop_id, login_id, pin_hash, role, phone, email, name, is_active, failed_login_count, locked_until, last_login, created_at
   - Must add unique constraints: shop_id + login_id, phone (for account linking)
   - Must add check constraint: role IN ('owner', 'admin', 'employee', 'delivery')

2. **🔴 `token_blacklist` Table MISSING** — No storage for revoked tokens. Logout won't work; tokens remain valid indefinitely.
   - Must define schema: id, user_id, token_hash, reason, expires_at, created_at
   - Must add indexes: user_id, expires_at

3. **⚠️ `sessions` Table Uncertain** — Spec mentions "backend session tracking" but table doesn't exist. Design choice needed: stateless JWT + Redis blacklist OR stateful sessions table?

4. **⚠️ `failed_login_count` Column Missing** — No way to track failed attempts; cannot enforce 5-attempt lockout per 15 min.

5. **⚠️ `locked_until` Column Missing** — No way to implement account lockout after 5 failures.

6. **⚠️ Role Enum Constraint Missing** — `audit_logs.user_role` has no CHECK constraint. Should enforce: `role IN ('customer', 'owner', 'admin', 'employee', 'delivery')`

7. **⚠️ Audit Log Immutability Not Enforced** — No DELETE restriction on `security_events`. Insider could clear logs after breaching account.

**Blocking Findings:** YES (2 critical + 3 important)
- **CANNOT IMPLEMENT** operational user login without `staff` table
- **CANNOT IMPLEMENT** token revocation without `token_blacklist` table
- **CANNOT IMPLEMENT** lockout without failed_login_count + locked_until columns

---

### 5️⃣ FIRESTORE REVIEW — Collection Structure, RLS Rules, Data Boundaries

**Status:** ✅ **APPROVAL** (No changes needed)

**Strengths (5):**
- ✅ All critical collections have RLS rules
- ✅ Data boundaries enforced correctly:
  - orders: customer sees own only (customerId == auth.uid)
  - deliveries: rider/dispatcher scoped, staff can see all
  - products: public read, admin write
  - wallets: customer sees own, admin sees all
- ✅ Write restrictions enforced: client writes blocked for critical collections (orders, payments, inventory)
- ✅ Service role bypass: Edge Functions/backend can write (isServiceAuth claim)
- ✅ Immutable collections: delivery_proofs, auth_logs set `allow delete: if false`
- ✅ 7 helper functions for role checking (isOwner, isAdmin, isEmployee, isRider, isDispatcher, isBranchManager, isStaff)

**No Critical Gaps Found.**

**Verification Needed (P1):**
- Run Firestore rules simulator to verify:
  - Unauthenticated cannot read orders
  - Customer A cannot read Customer B's orders
  - Employee cannot escalate to admin

**Status:** Ready for deployment. No blockers.

---

## SUMMARY TABLE: BLOCKER STATUS BY CATEGORY

| Category | Blockers | Status |
|----------|----------|--------|
| **Security** | 3 critical (secret rotation, RLS syntax, MFA policy) | ⚠️ Conditional |
| **Backend** | 5 critical (API schema, staff schema, logout endpoint, session design, @requireRole scope) | 🔴 Blocking |
| **Flutter** | 5 critical (Cloud Functions violation, token storage, interceptor, logout, nav guards) | 🔴 Blocking |
| **Database** | 2 critical (staff table, token_blacklist table) + 3 important | 🔴 **BLOCKING** |
| **Firestore** | 0 | ✅ Approved |

---

## DECISION POINT: PROCEED TO IMPLEMENTATION OR REFINE SPEC FIRST?

### OPTION A: Refine Spec (Recommended) — 2-3 hours
- Define POST /auth/operational-login request/response schema (JSON)
- Define staff + token_blacklist + sessions table schemas (SQL)
- Choose session design (single vs multi-device)
- Add token secret rotation policy
- Add Firestore RLS rule syntax (not just high-level list)
- Clarify logout endpoint + revokeAll behavior
- Fix Flutter Cloud Functions violation → use Render backend
- Estimate @requireRole coverage (139 endpoints, 8-12 hours work)
- Elevate owner/admin MFA to P0

**Benefit:** Implementation becomes straightforward; no guesswork; faster coding
**Risk:** 2-3 hour delay before code starts

### OPTION B: Implement with Known Gaps — Risk High
- Proceed to implementation with blockers documented
- Spec becomes "living document" updated during coding
- Likely will need multiple code review ↔ refactor cycles
- Frontend/backend integration will break mid-way when schemas clash

**Benefit:** Faster time to first code
**Risk:** High rework, thrashing review cycles, integration failures

---

## RECOMMENDATIONS

**Immediate Next Steps (Choose One):**

### 👉 **RECOMMENDED: Go back to SPEC PHASE (30 min refinement)**

1. Add API schema section:
   ```json
   POST /auth/operational-login
   Request: { login_id: string, pin: string, role?: string }
   Response: { token: JWT, refreshToken: JWT, user: {...}, permissions: [...], expiresIn: 3600 }
   ```

2. Add database migrations section (SQL CREATE TABLE for staff + token_blacklist)

3. Add Flutter fixes section:
   - Remove Firebase Cloud Functions call
   - Use POST /auth/operational-login to Render backend instead
   - Define token storage constants (FIREBASE_TOKEN_KEY, OPERATIONAL_TOKEN_KEY)

4. Add Firestore rules syntax section:
   ```
   // orders
   allow read: if resource.data.customerId == request.auth.uid || isOwnerOrAdmin();
   // deliveries
   allow read: if resource.data.deliveryAgentId == request.auth.uid || isOwnerOrAdmin();
   ```

5. Choose session design and document

6. Add token secret rotation policy

**Estimated Effort:** 30 minutes of spec refinement
**Benefit:** Implementation will be smooth, no mid-code surprises

### OR: Skip to Implementation (If urgent)
- Document all blockers in code as TODO comments
- Prepare for 2-3 review ↔ fix cycles
- Plan 3-4 days instead of 2 days due to integration rework

---

## FINAL STATUS

**Spec Approval:** ⚠️ **CONDITIONAL**

**Green Light Conditions:**
- ✅ Firestore rules (approved as-is)
- ⚠️ Security, Backend, Flutter (conditional on fixes)
- 🔴 Database (blocking - tables must be created)

**Recommendation:** **Spend 30 min refining spec** to define the 5 critical items above, then proceed to implementation with confidence. Parallel reviews have identified all the major gaps; addressing them upfront prevents costly rework cycles.

---

**Created:** 2026-07-05 16:30  
**Reviewed By:** 5 specialist agents (Security, Backend, Flutter, Database, Firestore)  
**Status:** Ready for user decision (proceed to spec refinement or jump to implementation)
