# MODULE 1 — P0 IMPLEMENTATION PLAN

**Status:** Starting Implementation
**Target:** Complete P0 blocks for Module 1 Auth
**Timeline:** ASAP (blocks all other modules)

---

## P0 BLOCK 1: UNIFIED AUTH FLOW DOCUMENTATION

**Priority:** 🔴 **CRITICAL** — All upstream auth decisions depend on this

**Task:** Create complete auth flow documentation for EACH user type

**Deliverable:** `backend/docs/AUTH_FLOWS.md`

**Content:**
```
## Customer Login Flow
1. Flutter: POST /auth/customer-login { phone, password }
2. Backend: Verify phone + password against customers table
3. Generate Firebase Auth token (or custom JWT)
4. Return { token, user, shop_id }
5. Flutter: Store token in SharedPreferences
6. Firebase Firestore: Auto-sync user doc

## Owner/Admin Login Flow
1. Flutter: POST /auth/operational-login { login_id, pin, role }
2. Backend: Verify login_id + pin against staff table
3. Verify role matches
4. Generate custom JWT (NOT Firebase)
5. Return { token, user, permissions }
6. Flutter: Store token in SharedPreferences
7. Backend: Create session in security_events table

## Employee Login Flow
[Similar to Owner/Admin]

## Delivery Agent Login Flow
[Similar to Owner/Admin]
```

**Files to Create/Modify:**
- [ ] Create `backend/docs/AUTH_FLOWS.md` — Complete flow for all 5 user types
- [ ] Create `backend/docs/TOKEN_MANAGEMENT.md` — Token generation, refresh, validation
- [ ] Create `backend/docs/PERMISSION_MATRIX.md` — RBAC matrix

**Blocked by:** None
**Blocks:** P0-2, P0-3, P0-4, P0-5

---

## P0 BLOCK 2: TOKEN MANAGEMENT FOR OPERATIONAL USERS

**Priority:** 🔴 **CRITICAL** — Without this, operational users can't log in

**Task:** Implement token generation, refresh, validation for operational users (Owner/Admin/Employee/Delivery)

**Location:** `backend/src/auth.js`

**Current State:** Unknown (file not read yet, likely exists)

**Must Implement:**
```javascript
// 1. generateOperationalUserToken(userId, role)
//    - Create JWT with { user_id, role, session_id, exp, iat }
//    - Sign with BACKEND_SECRET (NOT Firebase secret)
//    - Return token + refresh_token

// 2. verifyOperationalUserToken(token)
//    - Verify JWT signature
//    - Check not expired
//    - Return decoded payload

// 3. refreshToken(refreshToken)
//    - Validate refresh token in database
//    - Issue new access token
//    - Return new token pair

// 4. revokeToken(token, reason)
//    - Add token to blacklist (Redis or database)
//    - 24h expiration for blacklist entry
//    - Log in security_events
```

**Integration Points:**
- Called from `/auth/operational-login` endpoint
- Called from all protected routes via authMiddleware
- Called from `/auth/logout`

**Test Requirements:**
- Token generation works
- Token refresh works
- Expired tokens rejected
- Revoked tokens rejected
- Token contains all required claims

---

## P0 BLOCK 3: PERMISSION ENFORCEMENT (@requireRole MIDDLEWARE)

**Priority:** 🔴 **CRITICAL** — Routes unprotected = data leakage

**Task:** Audit all routes in `backend/src/routes/*.js` and add @requireRole protection

**Current State:** Unknown (middleware likely exists but inconsistently applied)

**Must Implement:**
```javascript
// backend/src/middleware/authorization.js

function requireRole(...allowedRoles) {
  return (req, res, next) => {
    const userRole = req.user?.role;
    
    if (!userRole || !allowedRoles.includes(userRole)) {
      return res.status(403).json({
        error: 'Forbidden',
        reason: `This action requires one of: ${allowedRoles.join(', ')}`
      });
    }
    
    next();
  };
}

// Usage:
router.get('/orders', requireRole('customer', 'owner', 'admin'), getOrders);
router.post('/orders/:id/cancel', requireRole('customer'), cancelOrder);
router.patch('/orders/:id/status', requireRole('owner', 'admin'), updateOrderStatus);
```

**Routes to Audit:**
- `backend/src/routes/orders.js` — 15+ routes
- `backend/src/routes/checkout-routes.js` — 8+ routes
- `backend/src/routes/delivery.js` — 10+ routes
- `backend/src/routes/admin.js` — 20+ routes
- `backend/src/routes/payments.js` — 5+ routes
- All other routes

**Checklist:**
- [ ] Every public route has requireRole middleware
- [ ] Role checks match PERMISSION_MATRIX
- [ ] Data boundary enforcement (customer sees only own orders, employee sees own deliveries)
- [ ] Tests pass for authorized + unauthorized access

---

## P0 BLOCK 4: FIRESTORE RLS RULES AUDIT & FIX

**Priority:** 🔴 **CRITICAL** — Without proper RLS, data visible to unauthorized users

**Task:** Verify/audit all Firestore RLS rules match backend RBAC

**Location:** `firebaseRules/*.json` (path unknown, likely firestore.rules or firebaseConfig/)

**Must Verify For Each Collection:**

**orders collection:**
```
allow read: if request.auth.uid == resource.data.customerId
           || (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['owner', 'admin'])
           || (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'employee' && <packing-rules>)
allow write: if false  // Only backend writes to orders
```

**deliveries collection:**
```
allow read: if request.auth.uid == resource.data.deliveryAgentId
           || (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['owner', 'admin'])
allow write: if request.auth.uid == resource.data.deliveryAgentId  // Self-update delivery status
```

**products collection:**
```
allow read: if true  // Public read
allow write: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['owner', 'admin']
```

**wallets collection:**
```
allow read: if request.auth.uid == resource.data.customerId
           || (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['owner', 'admin'])
allow write: if false  // Only backend writes to wallets
```

**Checklist:**
- [ ] Every collection has RLS enabled
- [ ] Rules match backend PERMISSION_MATRIX
- [ ] Write rules restrict to backend service role only
- [ ] Read rules enforce data boundaries
- [ ] Test scenarios pass (authorized + unauthorized)

---

## P0 BLOCK 5: ACCOUNT LINKING RULES

**Priority:** 🔴 **CRITICAL** — Prevents privilege escalation

**Task:** Define and enforce account linking validation

**Location:** `backend/src/services/AccountLinkingService.js` (or new location if doesn't exist)

**Must Implement:**
```javascript
class AccountLinkingService {
  async validateCanLink(phone, newAccountType, existingRole) {
    // Rule 1: One phone = one customer account ONLY
    const existingCustomer = await db.customers.findByPhone(phone);
    if (existingCustomer && newAccountType === 'customer') {
      throw new Error('Phone already linked to customer account');
    }

    // Rule 2: One phone = one operational account ONLY
    const existingOperational = await db.staff.findByPhone(phone);
    if (existingOperational && newAccountType !== 'customer') {
      throw new Error('Phone already linked to operational account');
    }

    // Rule 3: Cannot link customer + operational accounts
    if (existingCustomer && newAccountType !== 'customer') {
      throw new Error('Cannot link operational account to phone with customer account');
    }

    // Rule 4: Role changes require approval (for operational users)
    if (existingOperational && existingOperational.role !== newAccountType) {
      // Auto-reject or require owner approval
      throw new Error('Role change requires owner approval');
    }

    return true;
  }
}
```

**Integration Points:**
- Called from `/auth/operational-login` on first login
- Called from account linking UI (if user tries to link accounts)

**Checklist:**
- [ ] Phone validation works
- [ ] Cannot create duplicate customer accounts
- [ ] Cannot create duplicate operational accounts
- [ ] Cannot link customer + operational to same phone
- [ ] Role changes require approval
- [ ] Audit logs all linking attempts

---

## IMPLEMENTATION ORDER

1. **P0-1:** Create auth flow documentation (FASTEST, unblocks understanding)
2. **P0-2:** Implement token management (CORE, enables operational login)
3. **P0-3:** Audit + add @requireRole middleware (FASTEST IMPACT, prevents data leaks)
4. **P0-4:** Audit + fix Firestore RLS rules (CRITICAL, complements backend auth)
5. **P0-5:** Implement account linking validation (SECURITY, prevents privilege escalation)

---

## TESTING STRATEGY

**For each P0, create test file:**
- `backend/tests/auth.test.js` — Token generation, validation, refresh
- `backend/tests/authorization.test.js` — @requireRole middleware
- `backend/tests/firestore-rules.test.js` — Firestore RLS validation
- `backend/tests/account-linking.test.js` — Account linking rules

**Run before deployment:**
```bash
npm test backend/tests/auth.test.js
npm test backend/tests/authorization.test.js
npm test backend/tests/firestore-rules.test.js
npm test backend/tests/account-linking.test.js
```

---

## NEXT STEPS

1. Read `backend/src/auth.js` and `backend/src/routes/auth.js` (understand current state)
2. Read `lib/models/user_model.dart` (understand role definitions)
3. Create `backend/docs/AUTH_FLOWS.md` (document complete flows)
4. Implement P0-2 (token management)
5. Implement P0-3 (permission enforcement)
6. Implement P0-4 (Firestore RLS audit)
7. Implement P0-5 (account linking)

---

**END P0 IMPLEMENTATION PLAN**

Next: Begin reading critical files to understand current state, then execute P0 fixes in order.
