# ✅ Verification Checklist — Production Deployment Status
**Date:** 2026-06-25 | **Purpose:** Confirm all P0 fixes are live before beta launch

---

## 🔥 Firebase Rules Deployment

### Check #1: Role Self-Write Protection (P0 Security Fix)
**Location:** Firebase Console → Firestore → Rules  
**What to look for:** Lines 59-62 in deployed rules

```firestore
allow update: if isSignedIn() && (
  (isOwningUser(userId) && request.resource.data.role == resource.data.role) ||
  isGlobalAdmin()
);
```

**Status:** 
- [ ] Found in deployed rules
- [ ] Matches source code exactly
- [ ] Tested in emulator (see Task #23)

**If NOT found:**
```bash
firebase deploy --only firestore:rules
```

---

### Check #2: Missing Collection Rules (P0 Security Fix)
**Collections that should have rules:**

#### active_sessions (Lines 95-109)
```firestore
match /active_sessions/{sessionId} {
  allow read: if isSignedIn() && (isGlobalAdmin() || resource.data.userId == request.auth.uid);
  allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
  allow update/delete: ...
}
```
- [ ] Rules present in deployed version
- [ ] Read/write scoped to user or admin

#### owners (Lines 85-88)
```firestore
match /owners/{ownerId} {
  allow read: if isSignedIn() && isGlobalAdmin();
  allow write: if false;  // Admin SDK only
}
```
- [ ] Rules present
- [ ] Write blocked for client

#### employees (Lines 90-93)
```firestore
match /employees/{employeeId} {
  allow read: if isSignedIn() && (isGlobalAdmin() || ...);
  allow write: if isSignedIn() && isGlobalAdmin();
}
```
- [ ] Rules present
- [ ] Write admin-only

#### pre_authorized_users (Lines 111-114)
```firestore
match /pre_authorized_users/{phoneOrEmail} {
  allow read: if isSignedIn() && isGlobalAdmin();
  allow write: if isSignedIn() && isGlobalAdmin();
}
```
- [ ] Rules present
- [ ] Admin-only access

**If ANY collection is missing rules:**
```bash
firebase deploy --only firestore:rules
```

---

### Check #3: Delivery Collections Consolidation (P0 + Module 9 Fix)
**Status:** Should see consolidated delivery_tasks, deprecate old delivery_* collections

#### delivery_tasks (Lines 309-324 in source)
```firestore
match /delivery_tasks/{taskId} {
  allow read: if isSignedIn() && (
    isGlobalAdmin() ||
    (isDispatcher() && isBranchMatch(resource.data.branchId)) ||
    resource.data.riderId == request.auth.uid ||
    resource.data.customerId == request.auth.uid
  );
  allow create/update: ...
}
```
- [ ] Rules present (canonical collection)
- [ ] Read/write properly scoped

#### Deprecated delivery_* collections (Lines 329-413)
Should see rules like:
```firestore
match /delivery_agents/{agentId} {
  allow read: if ...;
  allow write: if false;  // DEPRECATED
}
```
- [ ] Old collections have read-only rules (write blocked)
- [ ] Comments mark them as DEPRECATED
- [ ] delivery_tasks is canonical

**If old collections have WRITE permissions:**
```bash
firebase deploy --only firestore:rules
```

---

## 🛢️ Postgres Schema Deployment

### Check #4: User Role Constraint (P0 Security Fix)
**Location:** Supabase Console → SQL Editor  
**Query to run:**
```sql
SELECT constraint_name, constraint_definition 
FROM information_schema.table_constraints 
WHERE table_name = 'users' AND constraint_type = 'CHECK';
```

**Expected output:** Constraint includes all 12 roles
```sql
CHECK (role IN ('customer','employee','rider','dispatcher','branchManager','owner','superAdmin','admin','shopOwner','deliveryAgent','supplier','franchiseOwner'))
```

**Verify each role:**
- [ ] customer ✅
- [ ] employee ✅
- [ ] rider ✅
- [ ] dispatcher ✅
- [ ] branchManager ✅
- [ ] owner ✅
- [ ] superAdmin ✅
- [ ] admin ✅ (added)
- [ ] shopOwner ✅ (added)
- [ ] deliveryAgent ✅ (added)
- [ ] supplier ✅ (added)
- [ ] franchiseOwner ✅ (added)

**If constraint is OLD (missing 5 roles):**
```sql
-- Option 1: Manual fix
ALTER TABLE users DROP CONSTRAINT role_check;
ALTER TABLE users ADD CONSTRAINT role_check 
  CHECK (role IN ('customer','employee','rider','dispatcher','branchManager','owner','superAdmin','admin','shopOwner','deliveryAgent','supplier','franchiseOwner'));

-- Option 2: Run latest migration
-- (Check Supabase Migrations tab and apply migration 018 if not applied)
```

**Test:**
```sql
-- This should FAIL before fix, SUCCEED after fix
INSERT INTO users (firebase_uid, role) VALUES ('test-shopowner', 'shopOwner');
-- Should work without constraint violation
```
- [ ] Test succeeds (constraint accepts shopOwner)
- [ ] Other roles still work (customer, admin, etc.)

---

## 🧪 Emulator Testing (Local Validation)

### Check #5: Role Self-Write Protection Test
**Setup:**
```bash
cd C:\Projects\fufaji-online-business
firebase emulators:start --only firestore
```

**Test 1: Customer cannot elevate to owner**
```
User: uid=test-user, role=customer
Action: Update own doc, set role=owner
Expected: PERMISSION_DENIED ❌
```
- [ ] Test fails as expected (rule blocks it) ✅

**Test 2: Customer can keep role unchanged**
```
User: uid=test-user, role=customer
Action: Update own doc, set role=customer (no change)
Expected: SUCCESS ✅
```
- [ ] Test succeeds (rule allows no-op) ✅

**Test 3: Admin can update any user**
```
User: uid=admin-user (has admin claim)
Action: Update other user's role
Expected: SUCCESS ✅
```
- [ ] Test succeeds ✅

### Check #6: Missing Collection Rules Test
**Test 4: Regular user cannot create active_sessions**
```
User: uid=test-user (not admin)
Action: Create active_sessions/{sessionId}
Expected: PERMISSION_DENIED ❌
```
- [ ] Test fails (rule blocks) ✅

**Test 5: User can read own active_sessions**
```
User: uid=test-user
Action: Read active_sessions/{own-uid}
Expected: SUCCESS ✅
```
- [ ] Test succeeds ✅

**Test 6: Only admin can write to owners**
```
User: uid=test-user (not admin)
Action: Write to owners/{ownerId}
Expected: PERMISSION_DENIED ❌
```
- [ ] Test fails (rule blocks) ✅

---

## 🎯 Summary Checklist

| Item | Check | Status | Evidence |
|------|-------|--------|----------|
| Role lock deployed | #1 | 🔴 TBD | Firebase Console rules |
| active_sessions rule | #2a | 🔴 TBD | Firebase Console |
| owners rule | #2b | 🔴 TBD | Firebase Console |
| employees rule | #2c | 🔴 TBD | Firebase Console |
| pre_authorized_users rule | #2d | 🔴 TBD | Firebase Console |
| delivery_tasks canonical | #3 | 🔴 TBD | Firebase Console |
| delivery_* deprecated | #3 | 🔴 TBD | Firebase Console |
| Postgres role constraint | #4 | 🔴 TBD | Supabase SQL Editor |
| Role lock emulator test | #5 | 🔴 TBD | Firebase Emulator |
| Missing rules emulator test | #6 | 🔴 TBD | Firebase Emulator |

---

## 🚨 If Anything Fails

**Deploy rules:**
```bash
cd C:\Projects\fufaji-online-business
firebase deploy --only firestore:rules
# Wait for "✔ Deploy complete!"
```

**Apply Postgres migration:**
- Go to Supabase Console
- Migrations tab
- Apply migration 018_complete_schema_fix.sql (or manually run ALTER TABLE)

**Re-run verification:**
- Repeat checks above
- All should pass before beta launch

---

## ✅ Sign-Off

**When all checks pass:**
- [ ] Firebase rules deployment verified
- [ ] Postgres schema deployment verified
- [ ] Emulator tests pass
- [ ] Ready for beta launch

**Next steps:** Start Task #6 (Cloud Functions migration) once Gaurav rotates secrets.

---

**Verification started:** 2026-06-25  
**Expected completion:** Within 3 hours  
**Blockers:** None (can run in parallel with secret rotation)
