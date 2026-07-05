# MODULE 1: AUTHENTICATION & ACCESS CONTROL — DEEP AUDIT

**Module Risk Level:** 🔴 **CRITICAL** (Recently refactored: Google sign-in removal, operational creds, approval flows)

**Audit Date:** 2026-07-05
**Scope:** Complete authentication, authorization, session management, and RBAC across Flutter + Backend + Database + Firebase

---

## MODULE SUMMARY

| Aspect | Status | Risk | Notes |
|--------|--------|------|-------|
| Customer Authentication | ✅ Implemented | 🟡 Medium | Firebase + custom backends, mixed ownership |
| Operational Users (Owner/Admin/Employee/Delivery) | ⚠️ Partial | 🔴 Critical | Recently refactored, multiple auth paths, unclear enforcement |
| Session Management | ⚠️ Partial | 🔴 Critical | SessionService exists but wiring unclear |
| RBAC/Permissions | ⚠️ Partial | 🔴 Critical | Role checks scattered, inconsistent |
| MFA | ✅ Implemented | 🟡 Medium | MFAService exists, but optional flows |
| Device Security | ✅ Implemented | 🟡 Medium | TrustedDeviceService, biometric support |
| Firestore Security Rules | ⚠️ Partial | 🔴 Critical | RLS policies unclear, need verification |

---

## CRITICAL GAPS FOUND

### GAP 1: **DUAL AUTH SYSTEMS (Firebase vs Backend)** 🔴 P0

**Issue:** Two parallel authentication systems with unclear separation

**Current:**
- **Firebase Auth:** Handles customer login via phone/email/Google
- **Backend Custom Auth:** Handles operational users (owner, admin, employee, delivery) with ID + PIN/password
- **Problem:** Different users use different auth systems, creating confusion

**Flutter Structure:**
```dart
lib/services/auth_service.dart           ← Main auth orchestrator?
lib/services/firebase_phone_auth_service.dart  ← Firebase path
lib/services/owner_auth_service.dart     ← Owner-specific path
lib/services/employee_auth_service.dart  ← Employee-specific path
lib/services/complete_auth_flow_logic.dart ← Mixed logic?
```

**Backend Structure:**
```javascript
backend/src/auth.js                ← Main auth middleware
backend/src/routes/auth.js         ← Auth endpoints
lib/services/customer_state.dart   ← State tracking (UNCLEAR)
```

**Questions:**
1. Is there ONE auth service or multiple?
2. When an operational user logs in, which backend endpoint is called?
3. How is session state synced between Flutter + Backend?
4. Who owns token refresh?

**Risk:**
- Auth requests could go to wrong endpoint
- Session could be created in Firebase but not backend
- Permissions enforced in one place but not another

**Fix Needed:**
1. **Document the auth flow for EACH user type:**
   - Customer login flow
   - Owner login flow
   - Admin login flow
   - Employee login flow
   - Delivery agent login flow

2. **Unified auth module:**
   ```
   AuthService (main orchestrator)
   ├── CustomerAuthService (Firebase)
   ├── OperationalUserAuthService (Backend)
   ├── SessionManager (handles tokens)
   └── PermissionManager (RBAC)
   ```

---

### GAP 2: **MISSING TOKEN MANAGEMENT FOR OPERATIONAL USERS** 🔴 P0

**Issue:**
- Firebase handles customer tokens (Firebase Auth tokens)
- Operational users need custom tokens from backend
- **Question:** How are custom tokens generated and refreshed?

**Location:** 
- `auth.js` and `routes/auth.js` (backend)
- `AuthProvider` (Flutter) has `_currentSessionId` but unclear if it's a token

**Missing:**
- No visible token generation logic for operational users
- No token refresh endpoint
- No token expiration handling
- Session lifecycle unclear

**CLAUDE.md says:**
> "Operational users must use Login ID + Password/PIN. Backend verification. Custom token session."

But code doesn't show WHERE this happens.

**Fix Needed:**
```javascript
// backend/src/auth.js - MUST HAVE:
function generateOperationalUserToken(userId, role) {
  // Create JWT with exp, iat, user_id, role, session_id
  return jwt.sign({...}, BACKEND_SECRET, { expiresIn: '7d' });
}

function verifyOperationalUserToken(token) {
  // Verify JWT
}

function refreshToken(refreshToken) {
  // Generate new token
}
```

**Location:** `backend/src/auth.js` likely has this, but needs verification

---

### GAP 3: **UNCLEAR PERMISSION ENFORCEMENT** 🔴 P0

**Issue:**
- RBAC scanned across multiple files
- No centralized permission check
- Routes may not be protected

**Files with role/permission logic:**
```
lib/providers/auth_provider.dart     ← _currentUser.role?
lib/models/user_model.dart           ← UserRole enum?
backend/src/routes/*.js              ← @requireRole middleware?
backend/src/middleware/validation.js ← authMiddleware?
firebaseRules/orders.json            ← Firebase rules?
```

**Questions:**
1. Who checks if user has permission to GET /orders?
2. Who checks if user can PATCH /orders/:id/status?
3. Who checks if employee can see only THEIR delivery orders?
4. Are all routes protected?

**Risk:**
- Unauthorized access to endpoints
- Data leakage (employee sees other employees' data)
- Customer sees admin data

**Fix Needed:**
1. Audit every route in `backend/src/routes/*.js` for:
   - Is authMiddleware present?
   - Does it check role?
   - Is it enforcing data boundaries (e.g., customer sees only their orders)?

2. Create @requireRole decorator:
   ```javascript
   router.get('/orders', @requireRole(['customer']), (req, res) => { ... });
   router.patch('/orders/:id/status', @requireRole(['owner', 'admin']), (req, res) => { ... });
   ```

3. Verify Firestore RLS policies match backend RBAC

---

### GAP 4: **GOOGLE SIGN-IN REMOVAL INCOMPLETE** 🔴 P0

**Issue:**
- CLAUDE.md says: "Google Sign-In (customer only)" — but was this removed?
- Code still imports GoogleSignIn (auth_provider.dart line 9)
- `_googleSignIn.instance` created (line 42)
- Unclear if it's used or dead code

**Location:**
```dart
lib/providers/auth_provider.dart line 9
lib/providers/auth_provider.dart line 42
lib/services/firebase_phone_auth_service.dart ← Might reference Google
```

**Questions:**
1. Is Google login still an auth path?
2. If removed, why is GoogleSignIn imported?
3. Are there screens still showing "Sign in with Google" button?

**Risk:**
- Dead code (tech debt)
- OR working code that violates design (Google allowed when it shouldn't be)

**Fix Needed:**
1. Search for `signInWithGoogle` — if found, it's still used
2. If still used: Verify it's only customers, not operational users
3. If not used: Remove GoogleSignIn dependency

---

### GAP 5: **NO CLEAR ROLE DEFINITION** 🟡 P1

**Issue:**
UserModel likely has a `role` field, but what are valid values?

**Location:** `lib/models/user_model.dart` (NOT READ YET)

**Expected roles:**
- customer
- owner
- admin
- employee
- delivery_agent

**Questions:**
1. Are these enum-defined or strings?
2. Can a user have multiple roles?
3. Are role transitions audited?

**Risk:**
- Unclear permissions
- Role validation missing
- Privilege escalation possible

**Fix Needed:**
```dart
enum UserRole {
  customer,
  owner,
  admin,
  employee,
  delivery_agent,
}

// Permissions map:
const ROLE_PERMISSIONS = {
  UserRole.customer: ['view_orders', 'create_order', 'cancel_order'],
  UserRole.owner: ['view_all_orders', 'manage_staff', 'manage_products'],
  // ...
};
```

---

### GAP 6: **SESSION INVALIDATION / LOGOUT INCOMPLETE** 🟡 P1

**Issue:**
- SessionService exists but unclear what it does
- When user logs out: is session revoked in Firestore?
- Are tokens blacklisted?
- Can a logout cause login to fail if same device logs back in?

**Location:**
```
lib/services/session_service.dart    ← UNKNOWN
backend/src/routes/auth.js           ← logout endpoint?
lib/providers/auth_provider.dart      ← logout() method?
```

**Questions:**
1. Does logout revoke all tokens?
2. Does logout clear Firestore user session doc?
3. Can attacker use expired token?

**Risk:**
- User's old token still valid after logout
- Session not properly cleared
- Device still "trusted" after logout

**Fix Needed:**
1. Verify logout clears:
   - Local token (SharedPreferences)
   - Firestore session doc
   - Backend session store (if any)
   - Device trust list (if needed)

2. Implement token blacklist for 24h after logout

---

### GAP 7: **MFA FLOW CLARITY** 🟡 P1

**Issue:**
- MFAService exists
- AuthProvider has `_isMfaStepRequired` flag
- But unclear when MFA is required

**Questions:**
1. Is MFA required or optional?
2. For which user types?
3. What are MFA methods (OTP, TOTP, biometric)?
4. If MFA fails, what happens?

**Risk:**
- MFA bypassed
- MFA step skipped in some flows

**Fix Needed:**
1. Define MFA policy:
   ```
   Owner: REQUIRED (MFA)
   Admin: REQUIRED (MFA)
   Employee: OPTIONAL (MFA)
   Delivery Agent: OPTIONAL (MFA)
   Customer: OPTIONAL (MFA)
   ```

2. Enforce in login flow:
   ```javascript
   if (user.role === 'owner' || user.role === 'admin') {
     return { status: 'mfa_required', mfaToken: '...' };
   }
   ```

---

### GAP 8: **ACCOUNT LINKING CLARITY** 🟡 P1

**Issue:**
- AccountLinkingService exists
- But unclear what it does
- Can one phone link to multiple accounts?
- Can customer account link to operational account?

**Risk:**
- Privilege escalation (customer links to owner account)
- Duplicate accounts
- Account takeover

**Fix Needed:**
1. Define account linking rules:
   - One phone = one customer account ONLY
   - One phone = one operational account (owner/admin/employee) ONLY
   - Cannot link customer + operational accounts

2. Implement validation:
   ```javascript
   async linkAccount(phone, accountType) {
     const existingCustomer = await getCustomerByPhone(phone);
     const existingOperational = await getOperationalUserByPhone(phone);
     
     if (existingCustomer && accountType === 'customer') {
       throw 'Phone already linked to customer account';
     }
     // ...
   }
   ```

---

### GAP 9: **DEVICE SECURITY / TRUSTED DEVICE UNCLEAR** 🟡 P1

**Issue:**
- TrustedDeviceService exists
- But unclear what "trusted" means
- Can user mark any device as trusted?
- Does trusted device skip MFA?

**Questions:**
1. Is biometric login allowed on untrusted devices?
2. Can device be untrusted by server?
3. Is device ID spoofable?

**Risk:**
- Weak device binding
- Attacker marks device trusted
- Biometric bypassed

**Fix Needed:**
1. Define device trust:
   ```
   - Device fingerprint = Hardware ID + OS + App version
   - Can be marked trusted ONLY after MFA
   - Server can revoke trust
   - Trust expires after 30 days
   ```

2. Implement:
   ```dart
   bool canSkipMfa(device) {
     return device.isTrusted && !device.isExpired() && device.isFingerprintValid();
   }
   ```

---

### GAP 10: **FIRESTORE RLS RULES UNVERIFIED** 🔴 P0

**Issue:**
- Firestore used as read cache (per CLAUDE.md)
- RLS rules must enforce data boundaries
- But no audit of actual rules

**Questions:**
1. Can customer see other customer's orders in Firestore?
2. Can employee see other employee's deliveries?
3. Are rules enforced on all collections?

**Risk:**
- Data leakage
- Unauthorized reads
- Privacy violation

**Fix Needed:**
1. Audit `firebaseRules/*.json`:
   - orders: Can only see if customerId === auth.uid
   - deliveries: Can only see if deliveryAgent === auth.uid
   - products: Public read
   - wallets: Private read/write

---

## MISSING WORKFLOWS

### Missing 1: **Password Reset Flow**
- No obvious password reset for operational users
- Firebase handles customer reset, but operational users?

### Missing 2: **Password Strength Validation**
- No visible password requirements
- Should enforce: 8+ chars, uppercase, number, symbol

### Missing 3: **Failed Login Attempt Lockout**
- No protection against brute force
- Should lockout after 5 failed attempts for 15 min

### Missing 4: **Session Timeout**
- No idle session timeout
- Operational user should timeout after 30 min of inactivity

### Missing 5: **Audit Logging of Auth Events**
- Security events should be logged
- Who logged in when, from where, success/fail

---

## PERMISSION MATRIX (TO BE DEFINED)

```
Action                          Customer  Owner  Admin  Employee  Delivery
=====================================================================
View own orders                  ✅        ✅     ✅     ❌        ❌
View all orders                  ❌        ✅     ✅     ❌        ❌
Create order                     ✅        ❌     ❌     ❌        ❌
Cancel order                     ✅        ✅     ✅     ❌        ❌
Update order status              ❌        ✅     ✅     ❌        ❌
Manage products                  ❌        ✅     ✅     ❌        ❌
Manage inventory                 ❌        ✅     ✅     ✅        ❌
View delivery routes             ❌        ✅     ✅     ❌        ✅
Update delivery status           ❌        ❌     ❌     ❌        ✅
View staff                       ❌        ✅     ✅     ❌        ❌
Manage staff                     ❌        ✅     ❌     ❌        ❌
View reports                     ❌        ✅     ✅     ❌        ❌
```

---

## IMPLEMENTATION PRIORITY FOR MODULE 1

### P0 (BLOCKING)
1. **Unified auth flow** — Clear path for each user type
2. **Token management** — Generation, refresh, expiration
3. **Permission enforcement** — All routes protected with @requireRole
4. **Firestore RLS audit** — Verify data boundaries
5. **Account linking rules** — Prevent privilege escalation

### P1 (CORE)
6. **Role definitions** — Enum + permissions matrix
7. **Session invalidation** — Proper logout cleanup
8. **MFA policy** — Define when required
9. **Device trust policy** — Define rules
10. **Audit logging** — Log all auth events

### P2 (HARDENING)
11. Failed login lockout
12. Password strength validation
13. Session timeout
14. Password reset flow

---

## FILES TO AUDIT (NEXT STEPS)

**MUST READ:**
- `lib/models/user_model.dart` — Role definition
- `lib/services/session_service.dart` — Session handling
- `lib/services/auth_service.dart` — Main orchestrator
- `backend/src/auth.js` — Token generation
- `backend/src/routes/auth.js` — Auth endpoints
- `firebaseRules/orders.json` — RLS policies

**THEN AUDIT:**
- All routes in `backend/src/routes/*.js` for @requireRole
- All Firestore read queries in Flutter for proper filtering

---

## IMMEDIATE ACTION ITEMS

1. **Create unified auth documentation** — Flow diagram for each user type
2. **Implement @requireRole middleware** — Protect all routes
3. **Define and enforce permission matrix** — RBAC system
4. **Audit + fix Firestore RLS rules** — Data boundaries
5. **Implement audit logging** — Track auth events

---

**NEXT MODULE:** Product & Inventory Engine (after auth fixes are implemented)

**END MODULE 1 AUDIT**
