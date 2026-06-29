

# MODULE 1 — AUTH FACILITIES: MASTER IMPLEMENTATION & AUDIT
**Fufaji Store — Phase 1 (Foundation), Module 1 of 17**
Prepared: 2026-06-19 · Status: Current-state audit against live codebase (not assumptions)

> Every claim below was verified by reading the actual files in `C:\Projects\fufaji-online-business` — `lib/services/auth_service.dart`, `lib/providers/auth_provider.dart`, `lib/services/{owner_auth_service,employee_auth_service,session_service,device_security_service,mfa_service,security_event_service,trusted_device_service,account_linking_service}.dart`, `lib/utils/app_router.dart`, `firestore.rules`, `functions/index.js`, and `supabase/migrations/001_core_schema.sql`. Where the actual stack differs from the assumed stack (Flutter/Firebase/RDS/Bedrock), the real architecture is reported, not the assumption.

---

## 0. Real Stack vs. Assumed Stack (read this first)

| Layer | Assumed in original brief | Actual in codebase |
|---|---|---|
| Frontend | Flutter | ✅ Confirmed — Flutter/Dart, Provider state mgmt, GoRouter |
| Primary auth provider | Firebase Auth | ✅ Confirmed — phone OTP, email/password, Google, Apple |
| Realtime DB | Firestore | ✅ Confirmed — system of record for `users`, `owners`, `employees`, `active_sessions`, `pre_authorized_users`, `security_events` |
| Relational DB | "AWS RDS PostgreSQL" | ⚠️ Actually **Supabase Postgres** (`supabase/migrations/`), with `pgbouncer` for pooling. Separate AWS RDS migration scripts (`migrate_rds.js`, `verify_rds.js`) exist but appear to be a parallel/future migration path, not the live system. Treat "RDS" in this document as "the SQL mirror," currently Supabase. |
| Cache | Redis | ⚠️ Not found in any auth code path read. No Redis client wired into auth/session services — sessions are Firestore-only. |
| Payments | Razorpay | ✅ Confirmed elsewhere in repo (and **no Stripe** — consistent with standing project rule). |
| AI | AWS Bedrock | ⚠️ Not present in any file touched for this audit. Out of scope for Module 1; flag for the AI Engine module (Phase 4). |

This matters for the rest of the document: every Database Schema and Integration section below is written against what is **actually deployed**, with the originally-assumed RDS/Redis treated as a target architecture, called out explicitly where it diverges.

---

## 1. Business Requirements

Fufaji's authentication system must serve **7 distinct actor types**, each with different trust levels and different login UX expectations:

1. **Guest** — anonymous browsing, no account, soft wall before checkout/orders/wallet.
2. **Customer** — phone OTP or Google/Apple sign-in, lightweight, mobile-first.
3. **Employee** — pre-provisioned by the Owner, Google/Apple sign-in only, UID-bound on first use, instantly revocable.
4. **Owner / Shop Owner** — highest-trust role, device-approval workflow, PIN + biometric second factor, MFA-eligible.
5. **Admin / SuperAdmin** — elevated operational role, same hardened path as Owner.
6. **Rider / Delivery Agent** — field workforce, needs fast login + always-on session for delivery duty.
7. **Supplier** — external party, narrower scope, portal-style access (Phase 5 — not yet built; see §9 gaps).

Core business rules the system must enforce end-to-end:
- A customer must never be able to act as staff, and staff must never silently lose role on a token refresh.
- An Owner's account is the single highest-value credential in the app (controls inventory, payouts, employee access) — it must require **both** something-you-know (PIN/password) and device trust before granting dashboard access, and must support immediate kill-switch (revoke device, revoke session, deactivate employee) propagating in real time, not on next login.
- Guests must be able to browse the full catalog with zero account, but must be blocked the moment money or personal data is involved (checkout, wallet, orders, addresses).
- Every authentication and authorization decision must be attributable after the fact (audit log), because Owner/Admin actions touch inventory and money.

## 2. User Workflow

**Guest → Customer flow**
1. App opens to Splash → role not yet known → `GuestProvider.enterGuestMode()` (local-only, no Firebase Anonymous Auth — this was a deliberate fix; anonymous Firebase users were previously able to place orders without verification, which was treated as a critical security flaw and removed).
2. Guest browses home, search, product detail, "snap-to-shop" freely (`isGuestAllowed` paths in the router).
3. Guest taps anything in `isVerificationRequired` (orders, wallet, addresses, checkout, order detail/track/dispute) → redirected to `/auth/verify-wall?returnPath=...&reason=...` with the original path preserved so they land back where they were after verifying.
4. Customer signs in via phone OTP (Firebase Phone Auth) or Google/Apple. New customers with no name on file are forced to `/profile-creation` before anything else, even if logged in.
5. Phone-OTP customers who haven't finished verification are still gated from `isVerificationRequired` paths even though `isLoggedIn` is already true (`!user.isVerified` check) — login and verification are tracked as two separate booleans, not one.

**Owner / Employee flow** (handled by the *separate* `AuthService`, not `AuthProvider` — see §3 for why this matters)
1. Google or Apple sign-in only (no password/OTP path for this flow).
2. On success, app immediately calls the `syncUserClaims` Cloud Function, which looks the signed-in email up in Firestore `owners`/`employees`, and writes Firebase **custom claims** (`role`, `employeeRole`, `isActive`) onto that user's auth account.
3. Client force-refreshes the ID token (`getIdTokenResult(true)`) to pull the new claims down.
4. If `role` claim is `owner` → `OwnerAuthService.verifyOwnerAccess` cross-checks the `owners` Firestore doc still exists for that email.
5. If `role` claim is `employee` → `EmployeeAuthService.verifyEmployeeAccess` checks the `employees` doc, **binds the signed-in UID to the employee record on first login** (`uid` field was previously null), and requires `uid == auth.uid && email matches && isActive == true`.
6. Either path then calls `SessionService.createSession()`, which creates an `active_sessions` Firestore doc and starts a real-time listener — if that document is ever deactivated remotely (admin revoke, or a 4th concurrent login bumping the oldest session), the client is force-signed-out within the lifetime of the snapshot listener.
7. If the claim is missing, or the Firestore role doc no longer exists, or the employee is inactive → full sign-out + `unauthorized`/`error` result; nothing partial is left signed in.

**Owner device & PIN sub-flow** (separate again — `OwnerAuthService`, state machine: `firstLogin` / `dailyLogin` / `newDevicePending` / `unauthorized`)
1. `getOwnerLoginState` checks the device ID (from `DeviceSecurityService`) against the `approvedDevices` array on the owner's Firestore doc.
2. Empty array → `firstLogin`: owner sets a PIN (hashed with PBKDF2-HMAC-SHA256, 10,000 iterations, random salt, format `pbkdf2$10000$<saltHex>$<hashHex>`) and optionally enables biometrics; device is registered as approved in the same step.
3. Matching, approved device → `dailyLogin`: PIN/biometric only, no re-approval needed.
4. Unrecognized device → `newDevicePending`: owner is held at a pending state until an already-approved device (or the owner via another channel) calls `approveDevice`.
5. Router enforces this independently of the Owner/Employee sign-in flow above: `app_router.dart`'s `redirect` forces *any* shopOwner/admin/owner/superAdmin user to `/security-pin` whenever `authProvider.isPinRequired` or `authProvider.isDeviceVerificationRequired` is true, regardless of which path they signed in through.

**Logout / session end**
- `AuthService.signOut()` stops the session listener, marks the `active_sessions` doc `isActive:false` via `revokeSession` (which also writes an `AuditService` entry naming who revoked whose session on which device), then signs out of Google and Firebase.
- Remote revocation (admin kills a session, or the session-limit logic auto-revokes the oldest of >3 concurrent sessions) reaches the device through the same Firestore listener used for normal logout — there is one revocation code path, not two.

## 3. UI Screens — Audit

Screens confirmed present and wired into the router: Splash, Login, OTP entry, Role-select, Profile-creation, Security-PIN, Verify-wall (`/auth/verify-wall`), TOTP setup, MFA verification.

**Gaps found:**
- **No dedicated "Session Expired" screen.** The router treats expired/revoked sessions the same as "never logged in" — user is bounced to `/login` with no explanation of *why* they were logged out (PIN timeout vs. remote revoke vs. natural expiry all look identical to the user). This is a real UX gap, not just a missing nice-to-have: a revoked-by-owner employee and a customer who simply timed out get the same blank re-login screen.
- **No "Unauthorized" screen distinct from `/login`.** `AuthService.signInWithGoogle/Apple` returns `AuthResultStatus.unauthorized` with a message, but there's no evidence of a dedicated route that displays that message persistently — it likely surfaces as a transient snackbar/toast on the login screen, which is easy to miss.
- **New-device-pending state has no visible holding screen** distinct from the PIN screen — `newDevicePending` is a state value returned by `OwnerAuthService`, but the router only special-cases `isPinRequired`/`isDeviceVerificationRequired`, both of which route to the *same* `/security-pin` path. An owner stuck in `newDevicePending` may see a confusing PIN prompt rather than a clear "waiting for device approval" message.

## 4. Backend Architecture

Two parallel, not-fully-unified backend authorization paths exist today:

**Path A — Claims-based (Owner/Employee only), via `AuthService`:**
```
Google/Apple Sign-In (Firebase Auth)
   → Cloud Function `syncUserClaims` (looks up owners/employees in Firestore, calls admin.auth().setCustomUserClaims)
   → Client force-refreshes ID token to read {role, employeeRole, isActive} claims
   → OwnerAuthService.verifyOwnerAccess / EmployeeAuthService.verifyEmployeeAccess (Firestore re-check)
   → SessionService.createSession (Firestore active_sessions)
```

**Path B — Allowlist-based (everyone, via the app-wide `AuthProvider`):**
```
Phone OTP / Email+Password / Google / Apple / Guest (Firebase Auth + GuestProvider)
   → AuthProvider._checkRoleAuthorization checks a separate `pre_authorized_users` Firestore
     collection (keyed by sanitized email: '@'/'.' → '_') to pre-provision owner/employee role
     for first-time Google/Apple sign-ins THROUGH THIS PROVIDER
   → MFA challenge if enabled (MfaService — email OTP or TOTP)
   → Router-level RBAC (GoRouter `redirect` in app_router.dart) for screen access
```

**This is a real architectural risk, not a stylistic note.** Two independently-maintained mechanisms (`syncUserClaims` custom claims vs. `pre_authorized_users` Firestore allowlist) can grant the *same* role to the *same* email through two different sign-in entry points, with no evidence either path checks the other's source of truth. A change made by adding someone to `owners`/`employees` (for Path A) will not automatically appear in `pre_authorized_users` (for Path B), and vice versa — meaning the answer to "can this person sign in as Owner?" depends on which `signInWithGoogle()` implementation they happen to hit. **Recommendation: consolidate to one authorization source** (custom claims, refreshed via `syncUserClaims`, checked everywhere) and delete the parallel `pre_authorized_users` allowlist, or vice versa.

**RBAC enforcement point:** there is exactly one place client-side route access is decided — the `redirect:` callback in `lib/utils/app_router.dart` (no separate `route_guard.dart`/`role_guard.dart` files, contrary to the originally assumed file layout). It is a single ~120-line function, evaluated on every navigation, and currently handles: open-paths, guest-allowed paths, verification-required paths, PIN/device-verification forcing for Owner/Admin, forced profile completion, unverified-customer gating, onboarding redirect, and per-role dashboard-root enforcement. Centralization is a strength (one place to audit); its size and the number of responsibilities it now carries is a maintainability risk (one regression here affects every role).

## 5. Database Schema — Current State

**Firestore (live, primary):**
- `users/{uid}` — profile, `role` (stored as either bare enum value or `'UserRole.xxx'` string — see §9), `mfaEnabled`, `mfaMethod`, `mfaTotpSecret`, `mfaBackupCodes` (SHA-256 hashed), `mfaOtpHash`/`mfaOtpGeneratedAt` (cleared after use), subcollections `wallet/{walletId}`, `devices/{deviceId}` (via `TrustedDeviceService` — `deviceId`, `deviceName`, `trusted`, `lastLogin`, `addedAt`).
- `owners/{docId}` — `email`, `approvedDevices: [{deviceId, deviceName, approved}]`, `pinHash`, `biometricEnabled`, `mfaEnabled`.
- `employees/{docId}` — `email`, `uid` (bound on first login), `employeeId`, `isActive`, role detail.
- `active_sessions/{sessionId}` — `sessionId`, `userId`, `deviceId`, `deviceName`, `loginTime`, `lastSeen`, `isActive`, `revokedAt`, `revokeReason`.
- `pre_authorized_users/{sanitizedEmail}` — allowlist for Path B role pre-provisioning.
- `security_events/{eventId}` — `event` (enum name), `userId`, `email`, `deviceId`, `deviceName`, `metadata`, `timestamp`. 20 distinct event types tracked (failedLogin, failedPin, pinLockout, biometricFailure, newDevice, deviceRevoked, sessionRevoked, rootDetected, loginSuccess, suspiciousActivity, otpFailure, otpLockout, reauthentication{Success,Failed}, pinReset{Requested,Success,Failed}, mfa{Enabled,Disabled,ChallengeSent,ChallengeSuccess,ChallengeFailed}).
- `audit_logs/{id}` — generic business audit trail (`AuditService`), includes auth-relevant `adminAction` entries like session revocation, dual-written to the Postgres mirror per migration comments.

**Postgres/Supabase (relational mirror, `supabase/migrations/001_core_schema.sql`):**
- `users` table — mirrors Firestore `users` for relational joins/analytics. **Role column is `text not null default 'customer' check (role in ('customer','employee','rider','dispatcher','branchManager','owner','superAdmin'))`.**
- Generic `audit_logs` table (dual-written from `AuditService`).
- **No dedicated `sessions`, `device_trust`, `login_logs`, `security_logs`, `user_roles`, or `auth_audit_logs` tables exist in Postgres.** All session, device-trust, and security-event data lives in Firestore only.

**Confirmed schema defect (not hypothetical):** the Postgres `role` check constraint allows only `customer, employee, rider, dispatcher, branchManager, owner, superAdmin` — **it has no entries for `shopOwner`, `admin`, `deliveryAgent`, `supplier`, `franchiseOwner`**, all of which exist in the live Dart `UserRole` enum (`lib/models/user_model.dart`: `customer, shopOwner, deliveryAgent, admin, employee, owner, superAdmin, rider, dispatcher, branchManager, supplier, franchiseOwner`). Any dual-write of a user with one of those five roles to the Postgres `users` table will fail the check constraint. This is a **P0 data-integrity bug** waiting to surface the first time a `shopOwner`, `admin`, `deliveryAgent`, `supplier`, or `franchiseOwner` user's profile is synced to Postgres.

## 6. Service Layer — As Built

| Service | Responsibility | Notes |
|---|---|---|
| `AuthService` (lib/services) | Owner/Employee Google+Apple sign-in, claims sync, session bootstrap | Separate `ChangeNotifier` from the main provider — see §4 risk |
| `AuthProvider` (lib/providers) | App-wide auth: phone OTP, email/password, Google, Apple (stub), guest mode, MFA orchestration, device trust, PIN, account linking, session, audit | The de facto "main" auth surface most screens bind to |
| `OwnerAuthService` | Owner lookup, device-approval state machine, PIN setup/hash storage, device register/approve/rename/remove | Static methods, no DI — fine for current scale |
| `EmployeeAuthService` | Employee lookup + UID binding, real-time active-status stream | `streamEmployeeStatus` is the mechanism that makes deactivation near-instant |
| `SessionService` | Session create/heartbeat/listen/revoke, concurrent-session limit (3), 30-min inactivity timeout | Singleton; heartbeat is a 5-min `Timer.periodic`, not push-based |
| `DeviceSecurityService` | Device ID/name, PIN hashing (PBKDF2-HMAC-SHA256, legacy SHA-256 fallback), local PIN storage, lockout status | PIN rate-limiting/lockout state is tracked **locally on-device** (see §8 risk) |
| `TrustedDeviceService` | A *second*, independent device-trust model under `users/{uid}/devices` | Overlaps conceptually with `owners.approvedDevices` — two device-trust data shapes for two different roles, not unified |
| `MfaService` | Email-OTP 2FA + TOTP (authenticator app) setup/verify, backup codes | TOTP secret stored in Firestore in plaintext (`mfaTotpSecret` field) — see §8 |
| `AccountLinkingService` | Merges duplicate accounts matched by phone or email across UIDs | Run on detection, not preventatively at signup |
| `SecurityEventService` | Append-only security event log + monitoring stream + `recentFailedPins` counter | Fire-and-forget by design (never throws) — correct for a logging service |
| `AuditService` | Cross-cutting business audit trail, dual-written Firestore+Postgres | Used by `SessionService.revokeSession` for accountability |

## 7. Integration Points

- **Auth → Orders:** `firestore.rules` ties order create to `isCustomer() && request.resource.data.customerId == request.auth.uid`; order read/update for staff is gated by `isBranchMatch` against the requester's own `branchId` from their `users` doc — i.e., authorization for orders is *derived live* from the same `users` doc auth controls, so any bug in `users` doc integrity (see §9) cascades into order access.
- **Auth → Inventory:** same pattern — `inventory/{inventoryId}` read/write requires `isGlobalAdmin()` or branch-matched `isBranchManager`/`isEmployee`. Consistent with the standing project rule that bulk inventory writes must go through the `inventory_change_requests` approval flow rather than direct writes — that flow's `approveRequest` action should itself be wrapped in `AuditService` (worth confirming when Module 4 — Inventory — is audited).
- **Auth → Payments:** not directly read in this pass; flagged for the Payment Facilities module (Phase 2) to confirm Razorpay webhook handlers validate caller identity independently of client-supplied auth state (server-side signature verification, not just "user is logged in").
- **Auth → Delivery:** Rider/dispatcher roles exist in the role model and in Firestore rules (`isRider`, `isDispatcher`) but no rider-specific auth service (equivalent to `OwnerAuthService`/`EmployeeAuthService`) was found — riders appear to authenticate through the generic `AuthProvider` path with role-based routing only. Worth a closer look in the Delivery Facilities module for whether riders need the same device-trust rigor as Owner/Employee.
- **Auth → Analytics/Audit:** `AuditService` and `SecurityEventService` are the two channels other modules should write into for anything auth-adjacent; both are dual-target (Firestore + Postgres for `AuditService`) or Firestore-only (`SecurityEventService`).

## 8. Automation

- `syncUserClaims` Cloud Function is the only automated/server-side piece of the auth system; it runs on-demand (called by the client right after sign-in), not on a schedule or trigger.
- Session enforcement (`_enforceSessionLimit`, inactivity timeout) is **client-driven, not server-enforced** — `isSessionExpired` is a pure function checked by whichever client happens to read it; there is no Cloud Function or scheduled job that sweeps `active_sessions` server-side and force-expires stale sessions. A device that goes offline mid-session leaves a `isActive:true` session doc indefinitely until something else (another login hitting the limit, or an admin) touches it.
- No automated alerting was found wired to `SecurityEventService` (e.g., no Cloud Function trigger on `security_events` writes that pages an admin on `rootDetected` or a burst of `failedLogin`/`suspiciousActivity` events). The data is captured; nothing currently acts on it automatically.

## 9. Security — Findings (ranked)

**P0 — Critical**

1. **Possible client-writable role escalation.** `firestore.rules`: `match /users/{userId} { allow update: if isSignedIn() && (isOwningUser(userId) || isGlobalAdmin()); }` has **no field-level restriction**. Because a signed-in customer satisfies `isOwningUser(userId)` for their own doc, this rule as written permits that customer's client to `update` their own `users/{uid}` document with **any field, including `role`**. Combined with `hasRole()` reading `role` straight off this same document, a malicious client could in principle write `role: 'owner'` to their own profile and have every subsequent rule check (`isOwner()`, `isGlobalAdmin()`, etc.) treat them as an owner. **This needs an immediate fix** — either a `request.resource.data.role == resource.data.role` constraint on the general update rule, or splitting `role` into a separate document/path that only `isGlobalAdmin()` can write, before this module is considered production-safe.
2. **No Firestore security rules found for `active_sessions`, `owners`, `employees`, or `pre_authorized_users`.** Firestore denies by default when no rule matches a path, and the only catch-all rules present are nested under `users/{userId}/{document=**}` (lines 63 and 94 of `firestore.rules`), which do not cover these top-level collections. Practically this means one of two things is true in production today, and both are bad: either (a) these collections are currently **unreadable/unwritable from the client**, which would mean `SessionService.createSession/revokeSession/streamActiveSessions`, `OwnerAuthService`, `EmployeeAuthService`, and the `pre_authorized_users` check in `AuthProvider` are **silently failing or throwing** every time they run from client code, or (b) rules deployed to the live project differ from this file and are more permissive than what's in source control, which is its own audit risk (rules drift). Either way this must be resolved before sign-off: deploy explicit rules for all four collections, scoped tightly (e.g., `active_sessions`: a user may read/write only docs where `resource.data.userId == request.auth.uid`, admins may read/write any).
3. **Postgres role check-constraint mismatch** (see §5) will hard-fail dual-writes for 5 of 12 roles — a data-integrity issue that becomes a security issue the moment anything (reporting, admin tooling) trusts the Postgres `users` table as complete.

**P1 — Important**

4. **Dual authorization sources** (`syncUserClaims` custom claims vs. `pre_authorized_users` allowlist) for the same role decision, with no shared source of truth (see §4). Risk of privilege drift between the two sign-in code paths.
5. **TOTP secret stored in plaintext** in Firestore (`mfaTotpSecret` field on `users/{uid}`) rather than encrypted at rest or in a server-only location. Anyone able to read that document (including the user's own client, by design) can read the raw secret. Backup codes are correctly hashed (SHA-256); the TOTP secret should be treated with the same care, ideally moved server-side (Cloud Function-mediated verify, never sent to the client after initial QR display).
6. **PIN lockout state is tracked locally on-device** (`DeviceSecurityService.LockoutStatus`), not server-side. A brute-force attempt against the PIN can be defeated by clearing local app storage/secure storage or reinstalling the app, since the lockout counter resets with it. The actual PIN hash comparison may also be happening client-side if `pinHash` is fetched to the client for comparison rather than verified via a callable function — worth confirming directly in the next pass, but the lockout counter's locality is confirmed and is itself a gap regardless.
7. **Two independent device-trust data models** (`owners.approvedDevices` array vs. `users/{uid}/devices` subcollection via `TrustedDeviceService`) with no apparent reconciliation. An Owner revoked via one mechanism may still appear trusted via the other if both are ever checked inconsistently across the codebase.

**P2 — Enhancements**

8. No automated session sweep (see §8) — stale `isActive:true` sessions accumulate.
9. No automated alerting on security events.
10. `role` field observed stored as both bare value and `'UserRole.xxx'`-prefixed string (the `hasRole()` helper explicitly checks both forms: `data.role == roleName || data.role == ('UserRole.' + roleName)`) — this is a sign of an inconsistent serialization format somewhere upstream that the rules layer is compensating for rather than fixing at the source.

## 10. Failure Cases

| Case | Current behavior | Gap |
|---|---|---|
| Invalid/expired Firebase ID token | Firebase SDK auto-refreshes; `getIdTokenResult(true)` force-refresh used at claims-sync time | None observed — standard Firebase behavior |
| Blocked/deactivated employee | `streamEmployeeStatus` real-time listener catches `isActive:false` quickly | Confirmed working as designed |
| Revoked owner device | `removeDevice` strips the device from `approvedDevices`; next `getOwnerLoginState` check returns `newDevicePending`/`unauthorized` | Works, but no push-style immediate kick of an *already-open* session on that device — revocation is checked on next state evaluation, not pushed live the way session revocation is |
| Session mismatch / remote revoke | `listenToSession` Firestore listener triggers `onRevoked` callback, signs out immediately | Works well — this is the strongest failure-handling path in the system |
| Duplicate login across devices (4th concurrent session) | Oldest session auto-revoked via `_enforceSessionLimit` | The user on the now-revoked oldest device gets bounced with the same generic re-login screen as any other logout — no "you were signed out because you logged in elsewhere" messaging (ties to the missing Session Expired screen, §3) |
| MFA OTP exhausted attempts | `_otpService.isLocked` returns true, `MfaResult` communicates lockout, `SecurityEventService` logs `otpLockout` | Works as designed |
| Role doc deleted out from under an active session (e.g., owner removed from `owners` collection mid-session) | No evidence of a listener on the `owners`/`employees` doc itself during an active session — only the *employee* status is streamed; an owner whose `owners` doc is deleted mid-session likely stays authorized client-side until next full re-auth | Gap — should mirror `streamEmployeeStatus` for owners too |

## 11. Testing — Recommended Plan

- **Unit:** `DeviceSecurityService` PIN hashing (PBKDF2 determinism, salt uniqueness, legacy-hash fallback path), `MfaService._verifyTOTP` window tolerance (-1/0/+1 interval), `_otpService` lockout threshold math, `SessionService._enforceSessionLimit` boundary at exactly `maxConcurrentSessions`.
- **Integration:** full Google-sign-in → `syncUserClaims` → claims-refresh → Firestore-role-doc-check round trip for both Owner and Employee, including the negative case (claims set but Firestore doc missing/inactive → must still end in clean sign-out, not a half-authenticated state).
- **Security:** attempt a client-side write of `role` to another user's `users/{uid}` doc (must be denied) **and** to one's own doc (currently likely succeeds — this is the test that proves Finding P0-1 above); attempt direct client reads/writes to `active_sessions`, `owners`, `employees`, `pre_authorized_users` as an unprivileged user (should all be denied once rules are added per P0-2); attempt PIN brute-force after clearing local secure storage mid-attempt (should still be rate-limited if lockout is moved server-side).
- **Load:** concurrent session creation under the 3-session cap from multiple devices simultaneously (race condition risk in `_enforceSessionLimit`'s read-then-batch-write pattern — two simultaneous logins could both read "2 active sessions" and both proceed, briefly exceeding the cap before the next check).

## 12. Production Readiness

**P0 (blocking, must fix before this module can be called production-ready):**
- Lock down `users/{userId}` update rule so `role` (and any other privilege-bearing field) cannot be client-written by the doc owner.
- Add explicit Firestore rules for `active_sessions`, `owners`, `employees`, `pre_authorized_users` — confirm against the *deployed* rules (not just this file) that there's no drift.
- Fix the Postgres `role` check constraint to include all 12 `UserRole` values, or document why 5 of them are intentionally excluded from the relational mirror.

**P1 (should fix soon):**
- Pick one authorization source of truth (custom claims or `pre_authorized_users`) and retire the other.
- Move TOTP secret handling and PIN-lockout state server-side.
- Add an `owners`/`employees`-doc listener for live sessions (mirroring `streamEmployeeStatus`) so mid-session revocation of an Owner behaves like mid-session revocation of an Employee.

**P2 (improvements):**
- Scheduled Cloud Function to sweep and expire stale `active_sessions`.
- Alerting on `security_events` (rootDetected, suspiciousActivity, lockout bursts).
- Normalize the `role` field's stored format so `hasRole()` doesn't need to check two string shapes.
- Dedicated "Session Expired" and "Unauthorized" screens with reason-specific messaging.
- Unify the two device-trust data models.

---

## Final Output Summary

**Current State Audit:** Auth is substantially built — 7 roles, 4 login methods, MFA (email+TOTP), device trust (two parallel models), session management with concurrent-session limiting and real-time revocation, owner PIN+device-approval state machine, account linking, and two audit/logging channels. This is a mature, mostly-working system, not a skeleton.

**Missing Components:** Postgres tables for sessions/device-trust/login-logs/security-logs/auth-audit-logs (currently Firestore-only); server-side session sweep automation; security-event alerting; unified device-trust model; unified role-authorization source; dedicated Session-Expired/Unauthorized UI states; rider-specific auth hardening equivalent to Owner/Employee.

**Architecture Design:** Keep the dual-collection Firestore model (`owners`/`employees`/`users`) but consolidate the *authorization decision* to a single source (custom claims, refreshed consistently from both sign-in entry points); keep `AuthProvider` as the single app-wide auth surface and fold `AuthService`'s Owner/Employee logic into it (or keep them separate but have both call the same underlying authorization check) to remove the dual-path risk in §4.

**Implementation Plan (priority order):**
1. Patch the `users` Firestore rule (role field lock) — P0, can ship same day.
2. Add the four missing collection rule blocks — P0, requires careful scoping per collection, test against both legitimate and adversarial access patterns before deploy.
3. Fix the Postgres role constraint — P0, single migration.
4. Consolidate authorization source — P1, larger refactor, needs a migration plan for existing `pre_authorized_users` entries into custom-claims provisioning (or the reverse).
5. Server-side PIN lockout + TOTP secret handling — P1.
6. Remaining P2 items as capacity allows.

**File-by-file Changes Needed:**
- `firestore.rules` — add rules for `active_sessions`, `owners`, `employees`, `pre_authorized_users`; tighten `users/{userId}` update rule.
- `supabase/migrations/` — new migration altering the `users.role` check constraint.
- `lib/providers/auth_provider.dart` / `lib/services/auth_service.dart` — converge on one authorization source; add an owner-doc live listener alongside the existing employee one.
- `lib/services/mfa_service.dart` — move TOTP secret storage/verification server-side (new Cloud Function) instead of a Firestore field read by the client.
- `lib/services/device_security_service.dart` — move PIN lockout counter server-side or to a tamper-resistant store.
- New: a `/session-expired` and `/unauthorized` route + screen, wired into `app_router.dart`'s redirect logic with a reason parameter (the pattern already exists for `/auth/verify-wall?reason=...` — reuse it).

**Production Checklist:**
- [ ] `users` role field locked against self-write
- [ ] Rules deployed for all 4 currently-unprotected collections, verified against live project (not just source file)
- [ ] Postgres role constraint matches Dart `UserRole` enum exactly
- [ ] Single authorization source of truth, both sign-in paths converged
- [ ] TOTP secret + PIN lockout moved server-side
- [ ] Owner-doc live revocation listener added
- [ ] Session-Expired / Unauthorized screens shipped
- [ ] Stale-session sweep automation running
- [ ] Security-event alerting wired up
- [ ] Full unit/integration/security/load test plan (§11) executed and passing

---

**Next:** Module 2 — Product Management Master Prompt.
