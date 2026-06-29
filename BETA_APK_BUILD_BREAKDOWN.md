# 🤖 Fufaji Store — Beta APK Build Breakdown
**AI Team Lead Analysis** | Goal: Production-ready beta APK with all working functionalities and secured secrets | Date: 2026-06-25

---

## Executive Summary

**Current State:** 10-module master audit completed (Jun 2026); 5 highest-risk live bugs fixed; **28 remaining P0/P1 gaps** unfixed; **CRITICAL: secrets breach incident** (public repo, leaked keys in APK, signing key exposed).

**For Beta APK:**
- ✅ **4/5 core modules partially working** (Auth, Products, Cart/Checkout, Payment)
- ⚠️ **Security/Secrets require immediate incident response before ANY build**
- ❌ **Multiple P0 live bugs** still active (SQL injection, missing rules, competing engines)
- 📦 **Build config exists** but needs secrets rotation before release

**Build Readiness Score: 28/100** (per 2026-06-21 audit). Must fix CRITICAL + P0 sections before beta.

---

## 🚨 CRITICAL: Secrets Incident Response (DO THIS FIRST)

### Why This Is Blocking
- **Live secrets leaked on GitHub** (`functions/.runtimeconfig.json`, setup scripts, `.env` asset in APK)
- **Android signing key exposed** (`keystore_base64.txt` public)
- **Every shipped APK contains secrets** (Supabase, Razorpay, Gemini API keys)
- **Must complete before building release APK**

### Module A: Emergency Lockdown (Immediate)
**Owner action required — manual dashboard steps:**

| Task | Owner | Status | Impact |
|------|-------|--------|--------|
| Make GitHub repo **private** | Gaurav | 🔴 Required | Stops new clones with secrets |
| Rotate ALL secrets (Razorpay, Twilio, Supabase, Gemini) | Gaurav | 🔴 Required | Invalidates exposed keys |
| Purge git history (`git-filter-repo`) | Gaurav | ⚠️ High | Removes leaked commits from history |
| Regenerate Android signing key | Gaurav | 🔴 Required | New APKs can't be forged |
| Revoke old Firebase API keys | Gaurav | 🔴 Required | Blocks unauthorized API calls |

**Effort:** ~2 hours (dashboard actions + CLI commands documented in repo's `INFRA_CONFIG_SECRETS_AUDIT.md`)

---

### Module B: Secret Migration (Developer Effort)

#### Task B1: Remove `.env` Asset from APK ⭐ P0
**Files:** `pubspec.yaml`, `lib/main.dart`

```dart
// CURRENT (insecure — leaks to APK)
assets:
  - .env    ← DELETE THIS LINE
dotenv.load(fileName: ".env");  // lib/main.dart:69

// FIXED
// No .env asset; secrets come from --dart-define only
```

**What's at stake:** Currently every APK built from this repo ships all secrets (Supabase S3 key, Upstash Redis token, Gemini API key).

**Implementation:**
1. Delete `.env` from `pubspec.yaml` (2 lines)
2. Delete `dotenv.load()` from `lib/main.dart`
3. Replace with env vars injected via `--dart-define` (see Task B3)
4. Test on internal build that secrets don't appear in binary

---

#### Task B2: Migrate `functions/` to Firebase Secret Manager ⭐ P0
**Files:** `functions/index.js`, `firebase.json`, `.firebaserc`

**Current state:** Uses deprecated `functions.config()` + plain `.runtimeconfig.json` (leaked on GitHub).

**Target state:** Firebase Secret Manager + GitHub Actions inject at deploy time.

```javascript
// CURRENT (UNSAFE)
const razorpaySecret = functions.config().razorpay.key_secret;

// FIXED (Firebase Secrets)
const razorpaySecret = await admin.firestore()
  .collection('_secrets')
  .doc('razorpay_key_secret')
  .get()
  .then(d => d.data().value);
// OR use defineSecret() + functions.runWith() (newer)
```

**Steps:**
1. Create Firebase Secret Manager secrets for: `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `WHATSAPP_TOKEN`, `SUPABASE_*`, `UPSTASH_*`, `GEMINI_*`, Stripe, SendGrid
2. Update `functions/index.js` to read from Secret Manager instead of `functions.config()`
3. Delete `.runtimeconfig.json` from repo (add to `.gitignore`)
4. Update `firebase.json` to skip runtimeconfig for Cloud Functions
5. Test locally with `firebase functions:config:set` (temporary, not committed)

**Effort:** 6–8 hours (refactor all function handlers, test each)

---

#### Task B3: Inject Public Secrets via `--dart-define` ⭐ P0
**Files:** `lib/main.dart`, build configs

Public values (API endpoints, app IDs, analytics keys) are safe to commit. Only these should appear in APK:
- Firebase project ID, API key (public)
- Sentry DSN (public)
- Analytics tracking IDs
- Feature flag endpoints

**Implementation:**

```dart
// lib/main.dart — read from Dart define
const String firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

// Build: flutter build apk --dart-define=FIREBASE_PROJECT_ID=fufaji-prod
```

**Secrets to keep OUT of code:**
- ❌ `SUPABASE_S3_ACCESS_KEY` / `SECRET`
- ❌ `UPSTASH_REDIS_REST_TOKEN`
- ❌ `GEMINI_API_KEY`
- ❌ Razorpay keys
- ❌ Twilio keys
- ❌ Stripe/SendGrid keys

If app needs a secret at runtime (e.g., to call Razorpay directly), fetch it from a secured backend endpoint instead. Don't ship secrets in the APK.

**Effort:** 4–5 hours

---

## 🔐 P0 Security Gaps (Auth Module)

### Task P0-Auth-1: Fix Role Self-Write Vulnerability ⭐⭐ CRITICAL
**File:** `firestore.rules`  
**Finding:** Customer can self-write `role: 'shopOwner'` onto their own user doc

```firestore
// CURRENT (VULNERABLE)
match /users/{userId} {
  allow update: if isOwningUser(userId);  // No field-level lock!
}

// FIXED
match /users/{userId} {
  allow update: if isOwningUser(userId) && 
    request.resource.data.role == resource.data.role;  // Lock role
}

// Better: move role updates to admin-only
match /users/{userId} {
  allow read: if isSignedIn();
  allow update: if isOwningUser(userId) && 
    getUpdatedFields().hasOnly(['address', 'phone', 'displayName']);  // Whitelist safe fields only
}
match /admin/userRoles/{userId} {
  allow write: if isGlobalAdmin();  // Role changes go here
}
```

**Impact:** Anyone logged in can elevate themselves to `shopOwner` → bypass all owner-only UI/backend checks.

**Effort:** 2 hours (rule fix + test with customer + shopOwner logins)

---

### Task P0-Auth-2: Add Missing Firestore Rules (5 collections) ⭐
**Files:** `firestore.rules`  
**Collections with zero rules:** `active_sessions`, `owners`, `employees`, `pre_authorized_users`

```firestore
// ADD TO firestore.rules

match /active_sessions/{userId} {
  allow read, write: if isOwningUser(userId) || isGlobalAdmin();
}

match /owners/{ownerId} {
  allow read: if isOwningUser(ownerId) || isGlobalAdmin();
  allow update: if isOwningUser(ownerId) && 
    getUpdatedFields().hasOnly(['deviceCount', 'lastLoginAt']);  // Lock sensitive fields
  allow create, delete: if isGlobalAdmin();
}

match /employees/{employeeId} {
  allow read: if isGlobalAdmin() || isOwningUser(employeeId);
  allow write: if isGlobalAdmin();
}

match /pre_authorized_users/{email} {
  allow read: if isGlobalAdmin();
  allow write: if isGlobalAdmin();
}
```

**Effort:** 3 hours (write + test each rule)

---

### Task P0-Auth-3: Align Postgres Role Enum ⭐
**File:** `supabase/migrations/001_core_schema.sql` (or your latest migration)  
**Finding:** Check constraint only accepts 7 of 12 roles in live Dart enum

```sql
-- CURRENT (INCOMPLETE)
ALTER TABLE users
  ADD CONSTRAINT role_check 
  CHECK (role IN ('customer', 'employee', 'rider', 'dispatcher', 'branchManager', 'owner', 'superAdmin'));

-- FIXED (ADD MISSING)
ALTER TABLE users
  ADD CONSTRAINT role_check 
  CHECK (role IN (
    'customer', 'shopOwner', 'admin', 'deliveryAgent', 'supplier', 'franchiseOwner',  -- Missing 6
    'employee', 'rider', 'dispatcher', 'branchManager', 'owner', 'superAdmin'        -- Original 7
  ));
```

**Where it breaks:** Any user created with one of the 5 missing roles fails to sync to Postgres → dual-write failures, inconsistent state.

**Effort:** 2 hours (write migration, test each role creation path)

---

## ⚠️ P0 Live Bugs (From Module Audits)

### Task P0-Biz-1: SQL Injection in Approval Workflow ⭐⭐ CRITICAL
**File:** `lib/services/product/approval_workflow_service.dart`  
**Finding:** (From Module 2 audit) Raw Postgres query vulnerable to injection

**Effort:** 4 hours (find query, refactor to parameterized, test)

---

### Task P0-Biz-2: Wallet Payment Skips Stock Deduction (DONE ✅)
**Status:** Fixed 2026-06-20  
**What was:** `WalletProvider.payWithWalletAndCreateOrder` created orders without stock deduction  
**Fix:** Route through unified `OrderService.createOrder` with `walletAmountUsed` flag

---

### Task P0-Biz-3: Cancellation Zero-Refund Bug (DONE ✅)
**Status:** Fixed 2026-06-20  
**What was:** Early-stage (0%-fee) cancellations got zero refund due to missing gate check  
**Fix:** Removed the `if (feeResult.fee > 0)` guard that was blocking refund processing

---

### Task P0-Biz-4: Rider Order Query Mismatch (DONE ✅)
**Status:** Fixed 2026-06-20  
**What was:** Rider queries used bare `'packed'` but packing writes `'OrderStatus.packed'`  
**Fix:** Qualified 3 listener queries + defensive string qualification in update methods

---

### Task P0-Biz-5: Packing Workflow Split (Live Bug — Not Yet Fixed) ⭐
**Files:** Multiple packing/packaging services  
**Finding:** (From Module 8 audit) 2 parallel disconnected packing workflows write different Firestore paths and status formats. Only one is live, other is orphaned. A third has a dormant double-stock-deduction bug.

**Impact:** Customers can bypass packing; orders may never reach delivery; or stock deducted twice.

**Effort:** 6 hours (read both workflows, pick canonical one, consolidate, test)

---

### Task P0-Biz-6: Delivery Rules Gap (DONE ✅, partially)
**Status:** Fixed 2026-06-20 (rules added), but field names inferred not verified  
**Remaining:** Confirm actual field names in `DeliveryService`/`FleetService` match the inferred rule paths

**Effort:** 2 hours (read code, spot-check rules)

---

## P1 Gaps (High Priority, Not Blocking Beta)

| # | Module | Issue | Effort | Impact |
|---|--------|-------|--------|--------|
| P1-1 | Auth | Dual auth source (custom claims vs pre_authorized_users) — no shared source of truth | 4h | Confusion during role changes |
| P1-2 | Auth | TOTP secret stored plaintext in Firestore | 3h | Compromised secrets = account takeover |
| P1-3 | Auth | PIN lockout tracked client-side only (resettable) | 2h | Brute-force vulnerability |
| P1-4 | Auth | 2 device-trust models (`owners.approvedDevices` vs `users/{uid}/devices`) | 5h | Inconsistent device bans |
| P1-5 | Product | (Module 2 — TBD details, many competing paths) | TBD | Product mutations can race/corrupt |
| P1-6 | Inventory | Firestore doc creation mismatch for checkout reservation | 3h | Reservations fail at payment time |
| P1-7 | Coupon | 'fixed' vs 'flat' bug zeros discounts | 2h | Revenue loss |
| P1-8 | Payment | Stripe violation + wrong webhook secret | 6h | Payments fail, can't refund |
| P1-9 | Packaging | Orphaned workflow with dormant double-deduction | 4h | Stock corruption risk |
| P1-10 | Delivery | Rider status strings not qualified everywhere | 2h | Orders stuck in transit |

**Recommendation:** Fix P0s first. For beta, consider P1-2, P1-3 (auth security holes). Defer P1-5 through P1-10 to post-beta or Phase 2.

---

## ✅ Already Fixed (2026-06-20)
1. Wallet payment stock deduction
2. Cancellation zero-refund
3. Rider order query mismatch
4. Missing `coupons` Firestore rule
5. Missing delivery* collection rules (partial validation pending)

---

## 🏗️ Build & Deployment Tasks

### Task Build-1: Configure APK Release Build ⭐
**File:** `android/app/build.gradle`

**Checklist:**
- [ ] Release signing key rotated (new `.jks` file, old one destroyed)
- [ ] No hardcoded secrets in `build.gradle`
- [ ] Minify enabled for release (`minifyEnabled true`)
- [ ] Obfuscation rules set up
- [ ] Version code incremented (e.g., 1.0.0 → 1.0.1)
- [ ] Build variant set to `release`

**Effort:** 2 hours

---

### Task Build-2: GitHub Actions CI/CD for APK Build ⭐
**Files:** `.github/workflows/release.yml` (create if missing)

**Must include:**
1. Secrets stored in GitHub Secrets (not in repo)
2. Firebase Secret Manager fallback for runtime secrets
3. APK signed with new release key
4. Size check (< 50MB)
5. Automated upload to Play Store (or release page)

```yaml
# .github/workflows/release.yml
name: Build & Release APK

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter build apk --release \
          --dart-define=FIREBASE_PROJECT_ID=${{ secrets.FIREBASE_PROJECT_ID }} \
          --dart-define=SENTRY_DSN=${{ secrets.SENTRY_DSN }}
      - name: Upload to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_STORE_SERVICE_ACCOUNT }}
          packageName: com.fufajis.online
          releaseFiles: build/app/outputs/flutter-apk/app-release.apk
          track: beta
```

**Effort:** 4 hours

---

### Task Build-3: Play Store Beta Listing ⭐
**Where:** Google Play Console > Fufaji Store > Beta Testing

**Checklist:**
- [ ] Hindi + English app name, description
- [ ] 6 screenshots (1080×1920, showing Auth → Product → Cart → Checkout → Order Confirmation)
- [ ] Privacy policy URL (required)
- [ ] Content rating (India IAMAI-specific if available)
- [ ] Target API level ≥ 34 (current: 35+)
- [ ] Beta tester group created (max 100 for alpha, more for beta)
- [ ] Release notes in Hindi + English

**Effort:** 3 hours

---

### Task Build-4: APK Size & Binary Scan ⭐
**Command:**
```bash
flutter build apk --release --analyze-size
# Check for > 50MB and flag suspicious dependencies
```

**Common issues:**
- Large image assets (compress or use WebP)
- Unnecessary dependencies
- Unobfuscated code

**Effort:** 2 hours (if issues found, 4–6 hours to fix)

---

## 🧪 Testing & QA Gates

### Task QA-1: Manual Smoke Tests ⭐
**Must-pass flows before beta release:**

| Flow | Steps | Expected | Status |
|------|-------|----------|--------|
| **Login** | Phone → OTP → Home | Lands on home, user verified | 🔴 TBD |
| **Browse Products** | Home → tap product → view details | Product loads, images show, price correct, "Add to Cart" available | 🔴 TBD |
| **Cart** | Add item → cart count badge shows → tap cart → see item | Cart persists, quantity adjustable, GST shown separately | 🔴 TBD |
| **Checkout** | Cart → "Checkout" → enter address → choose payment → complete | Order created, payment verified, confirmation screen shows | 🔴 TBD |
| **Order History** | Home → Orders → tap order → see status & items | Order details accurate, delivery tracking (if applicable) | 🔴 TBD |
| **Logout** | Settings → Logout | Session revoked, forced back to login | 🔴 TBD |
| **Offline Behavior** | Turn off WiFi → add to cart → turn on WiFi → sync | Cart syncs, no data loss | 🔴 TBD |

**Effort:** 4 hours (once per beta release)

---

### Task QA-2: Automated Unit + Integration Tests ⭐
**Files:** `test/` folder

**Targets:**
- Auth: login, role-based access control
- Cart: add/remove, GST calculation
- Checkout: address validation, payment state machine
- Orders: creation, status transitions

**Tool:** `flutter test`  
**Target coverage:** >70% on core services

**Effort:** 8 hours (if tests don't exist; 2 hours if framework in place)

---

### Task QA-3: Security Scan (OWASP Top 10 Mobile) ⭐
**Tools:**
- `flutter pub global activate owasp_dependency_check`
- Manual code review for common Flutter vulnerabilities (insecure WebViews, hardcoded URLs, plaintext storage)

**Checklist:**
- [ ] No secrets in code or assets
- [ ] HTTPS enforced for all API calls
- [ ] Certificate pinning considered for Firebase
- [ ] Local storage encrypted (use `flutter_secure_storage`)
- [ ] No unverified intents to external apps
- [ ] Input validation on all forms

**Effort:** 4 hours

---

## 📋 Final Checklist for Beta APK

```
SECURITY & SECRETS
[ ] Repo made private (GitHub)
[ ] All secrets rotated (Razorpay, Twilio, Supabase, Gemini, Stripe)
[ ] Git history purged of leaked secrets (git-filter-repo)
[ ] Android signing key regenerated
[ ] .env file removed from pubspec.yaml + lib/main.dart
[ ] Firebase Secret Manager populated
[ ] --dart-define used for public values only
[ ] No hardcoded secrets in any Dart/Java/Kotlin file

AUTH & FIRESTORE RULES
[ ] Role self-write vulnerability patched (rule locks role field)
[ ] active_sessions, owners, employees, pre_authorized_users rules added
[ ] Postgres role enum aligned with Dart enum
[ ] All rules tested with Firebase Emulator Suite

LIVE BUGS
[ ] SQL injection in approval_workflow_service.dart patched
[ ] Packing workflow consolidation complete
[ ] Delivery field names verified against DeliveryService

BUILD & APK
[ ] Release signing key configured
[ ] APK minified & obfuscated
[ ] APK size < 50MB
[ ] GitHub Actions CI/CD workflow in place
[ ] Version bumped (1.0.0 → 1.0.1 or higher)

TESTING
[ ] Manual smoke tests passed (all 7 flows)
[ ] Unit test coverage >70%
[ ] OWASP Mobile Top 10 scan clean

PLAY STORE
[ ] Beta listing created (Hindi + English)
[ ] Screenshots + privacy policy added
[ ] Release notes written
[ ] Target API level ≥ 34
[ ] Beta tester group ready

DEPLOYMENT
[ ] Final build created & signed
[ ] APK uploaded to beta track
[ ] Beta testers invited (or internal QA)
[ ] Rollout schedule defined (5% → 25% → 100%)
```

---

## 📊 Task Breakdown by Priority & Effort

### 🔴 CRITICAL (Do First)
| Task | Effort | Owner | Blocker |
|------|--------|-------|---------|
| Make repo private | 0.5h | Gaurav | Yes (security) |
| Rotate all secrets | 1h | Gaurav | Yes (security) |
| Remove `.env` asset from APK | 4h | Dev | Yes (security) |
| Migrate Cloud Functions to Secret Manager | 8h | Dev | Yes (security) |
| Fix role self-write vulnerability | 2h | Dev | Yes (security) |
| Add Firestore rules for 5 collections | 3h | Dev | Yes (security) |

**Total CRITICAL effort: ~4 days** (with Gaurav's manual actions in parallel)

---

### 🟠 P0 (Beta-Blocker)
| Task | Effort | Owner | Note |
|------|--------|-------|------|
| SQL injection patch | 4h | Dev | Code review required |
| Packing workflow consolidation | 6h | Dev | Affects order flow |
| Align Postgres role enum | 2h | Dev | Dual-write failures if not fixed |
| Delivery field validation | 2h | Dev | Verify against code |

**Total P0 effort: ~3 days**

---

### 🟡 Build & QA
| Task | Effort | Owner | Parallel |
|------|--------|-------|----------|
| APK build config | 2h | Dev | Can run in parallel |
| GitHub Actions CI/CD | 4h | Dev | Can run in parallel |
| Smoke tests (manual) | 4h | QA | Blocks release sign-off |
| Unit tests | 8h | Dev | Can be parallel |
| Security scan | 4h | Security | Must pass before release |

**Total effort: ~5 days**

---

### 🟢 Polish (Post-Beta)
| Task | Effort | Owner |
|------|--------|-------|
| P1 auth fixes (4 items) | 10h | Dev |
| P1 product/inventory/coupon fixes | 12h | Dev |
| P1 payment/delivery fixes | 8h | Dev |

---

## 🎯 Recommended Execution Order

```
Week 1 (CRITICAL + P0):
  Day 1: Repo lockdown + secrets rotation (Gaurav) + Task B1 (.env removal)
  Day 2: Task B2 (Secret Manager migration) + B3 (dart-define)
  Day 3: Task P0-Auth-1 (role rule) + P0-Auth-2 (5 rules) + P0-Auth-3 (Postgres)
  Day 4: Task P0-Biz-1 (SQL injection) + P0-Biz-5 (packing workflow)
  Day 5: Validation + QA handoff

Week 2 (Build + Release):
  Day 1: Task Build-1 (signing) + Build-2 (CI/CD)
  Day 2: Task QA-1 (smoke tests) + QA-2 (unit tests) + QA-3 (security scan)
  Day 3: APK build + Play Store setup
  Day 4: Final review + beta launch
```

---

## 📞 Questions for Gaurav

1. **Secrets Rotation Priority:** Can you rotate secrets (Razorpay, Twilio, Supabase, Gemini) this week? This unblocks the APK build.
2. **Packing Workflow:** Which packing service is the canonical "live" one? (Module 8 audit found 3 competing workflows.)
3. **Stripe Decision:** Keep Stripe or remove it? (It violates your "no-Stripe" rule per earlier audit.)
4. **Beta Scope:** For beta, should we defer P1-5 through P1-10, or fix some (e.g., P1-2 auth PIN lockout)?
5. **Testing:** Do you have a beta tester group ready, or should we set up internal QA?

---

## 📄 Related Documents in Repo
- `INFRA_CONFIG_SECRETS_AUDIT.md` — Full secrets audit + recovery runbook
- `docs/MASTER_GAP_BACKLOG.md` — All 22 P0/P1 gaps from 10-module audit
- `docs/modules/01_AUTH_MASTER_AUDIT.md` through `10_*` — Detailed per-module findings

---

**Generated:** 2026-06-25 | **Team Lead:** 🤖 Claude | **Status:** Ready for execution planning
