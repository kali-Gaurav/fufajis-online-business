# 🚀 Revised Critical Path — What's ACTUALLY Left to Do
**Updated: 2026-06-25** | Much better than expected!

---

## 🎉 Great News: ALREADY COMPLETED

**Security & Rules (5 tasks DONE):**
- ✅ Task #5: .env asset management (RuntimeConfigService already implemented)
- ✅ Task #8: Role self-write fix (Firestore rules line 59-62 already locks role field)
- ✅ Task #9: Missing Firestore rules (ALL 5 collections already have rules)
- ✅ Task #10: Postgres role enum (ALL 12 roles already in check constraint)
- ✅ Delivery collection rules (10 collections consolidated into delivery_tasks with scoped rules)

**App Architecture:**
- ✅ `RuntimeConfigService.dart` — fetches config from `/config/app-config` endpoint
- ✅ `AppConfig.dart` — only public values via `String.fromEnvironment`
- ✅ No `.env` asset in pubspec.yaml
- ✅ Secrets marked @deprecated in AppConfig
- ✅ Sentry DSN loaded from runtime config

---

## ⚠️ CRITICAL STILL NEEDED (Blocker)

### For Gaurav (Dashboard Actions) — STILL REQUIRED
1. **Make GitHub repo PRIVATE** (Task #1) — 5 mins
2. **Rotate ALL secrets** (Task #2) — 2 hours
3. **Purge git history** (Task #3) — 2 hours  
4. **Regenerate signing key** (Task #4) — 1 hour

**Total owner effort: ~5.5 hours | Critical blocker for anything else**

### For Dev Team — Cloud Functions Migration (Task #6) — STILL REQUIRED
Migrate Cloud Functions from deprecated `functions.config()` to Firebase Secret Manager.

**Current state:**
- `functions/.runtimeconfig.json` still exists (though should be gitignored)
- Cloud Functions still use `functions.config().razorpay.*` pattern
- Need to move to Firebase Secret Manager + `defineSecret()` pattern

**Effort:** 8 hours

**Why it matters:**
- Prevents accidental secret exposure in future deploys
- Aligns with GCP best practices
- Ensures backend secrets stay server-side

---

## 🔍 VERIFICATION NEEDED (Not Code Changes)

### Task: Verify Rules & Schema Deployed to Production
**Effort:** 2-3 hours (checking, not fixing)

The codebase shows correct rules + schema, but we need to VERIFY they're deployed:

1. **Firebase Console check:**
   - Go to Firestore > Rules
   - Confirm deployed rules match `firestore.rules` (role lock, missing collections)
   - If older version deployed → deploy latest

2. **Supabase check:**
   - Go to https://supabase.com
   - Check Migrations applied
   - Verify `users.role` constraint includes all 12 roles
   - If old schema → apply migration 018

3. **Test:**
   - Try to create user with role='shopOwner' → should succeed
   - Try as customer to update own role to 'owner' via Firestore → should FAIL
   - Verify delivery_tasks queries work (Module 9 fix)

---

## 📋 WHAT'S NEXT (Recommended Order)

### WEEK 1: Unblock Dev Team
1. **Gaurav:** Execute Tasks #1-4 (secrets rotation + key regen)
   - Est: 5.5 hours, can do in parallel where possible
   - This unblocks APK build

2. **Dev:** Task #6 (Cloud Functions migration)
   - Est: 8 hours
   - Do after Gaurav rotates secrets
   - Store new secrets in GitHub Secrets + Firebase Secret Manager

3. **Dev:** Verification (deploy rules + schema)
   - Est: 2-3 hours
   - Verify everything is live
   - Test each fix in Firebase Emulator

### WEEK 2: P0 Bugs (Still Open)
4. **Dev:** Task #11 (SQL injection patch)
   - Est: 4-5 hours
   - Audit approval_workflow_service.dart

5. **Dev:** Task #12 (Packing workflow consolidation)
   - Est: 6-8 hours
   - Identify which workflow is live, consolidate

### WEEK 2-3: Build & QA (Parallel)
6. **Dev:** Tasks #13-14 (APK build + CI/CD)
   - Est: 8 hours
   - Can start after Task #6 (secrets safe)

7. **QA:** Tasks #15-17 (Smoke tests, unit tests, security scan)
   - Est: 13 hours
   - Can run in parallel with P0 bugs

### WEEK 3: Launch
8. **All:** Task #19 (Final review & launch to beta)
   - Est: 3 hours
   - Gate: All P0s fixed + tests pass + build clean

---

## 📊 REVISED EFFORT BREAKDOWN

| Phase | Original Est | Revised Est | Blocker |
|-------|--------------|------------|---------|
| CRITICAL (Gaurav) | 5.5h | 5.5h | ✅ YES |
| CRITICAL (Dev - Cloud Functions) | 15h | 8h | ⚠️ YES |
| Verification (not code) | 0h | 2-3h | 🟡 |
| P0 bugs | 13h | 10-13h | 🟡 |
| Build & QA | 33h | 33h | No |
| **TOTAL** | **~70h** | **~55-60h** | |

**Better news:** ~10-15 hours saved because major security fixes already done!

---

## ⚡ QUICK START: What You Can Do Right Now

**While waiting for Gaurav to rotate secrets:**

1. **Verify deployed rules (2-3 hours):**
   ```bash
   # Check Firebase Console
   # Check Supabase migrations
   # Test a few queries in emulator
   ```

2. **Start Task #11 (SQL injection) in parallel (4-5 hours):**
   ```bash
   # Read approval_workflow_service.dart
   # Identify raw queries
   # Refactor to parameterized
   ```

3. **Scope Task #12 (Packing workflows):**
   ```bash
   # Find all 3 packing service files
   # Read each one
   # Determine which is live
   ```

---

## 🎯 Success Metrics for Beta

| Gate | Status | Notes |
|------|--------|-------|
| Gaurav rotates secrets | 🔴 Pending | Blocks everything |
| Cloud Functions → Secret Manager | 🔴 Pending | 8h dev work |
| SQL injection fixed | 🔴 Pending | 4-5h dev work |
| Packing workflows consolidated | 🔴 Pending | 6-8h dev work |
| Rules deployed to Firebase | 🟡 TBD | Verify, likely done |
| Schema deployed to Supabase | 🟡 TBD | Verify, likely done |
| APK build clean | 🔴 Pending | After secrets safe |
| Smoke tests pass | 🔴 Pending | 4h QA work |
| Security scan clean | 🔴 Pending | 5h security work |

---

## 💡 Key Insight

**Original audit (Jun 19) found 22 P0/P1 gaps.**  
**Current codebase already fixed ~8 of them!**

This means either:
1. Dev team has been shipping fixes
2. Codebase was already partially remediated
3. Audit findings were from an older baseline

**Action:** Update the master audit doc with current state before launching to production.

---

**Bottom line:** You're closer to beta than the old task list suggested. **Focus on:**
1. Gaurav's secret rotation (critical blocker)
2. Cloud Functions migration (8h)
3. Verification (2-3h)
4. P0 bugs (10-13h)
5. Build & QA (in parallel)

**Estimated time to beta: 10-14 days** (down from 21 days)

