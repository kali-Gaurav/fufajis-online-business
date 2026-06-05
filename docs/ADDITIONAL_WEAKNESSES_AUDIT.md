# Additional Weaknesses Audit Report

This document records the **40+ additional weaknesses** discovered in the codebase, classified by severity and category, as requested by the user.

---

## 🔴 CRITICAL SECURITY VULNERABILITIES

### 1. Storage Rules - Dangerously Permissive
- **Problem**: Allows all authenticated users to read/write any file in Firebase Storage.
  ```firestore security rules
  rules_version = '2';
  service firebase.storage {
    match /b/{bucket}/o {
      match /{allPaths=**} {
        allow read, write: if request.auth != null;
      }
    }
  }
  ```
- **Risk**: No path-based restrictions, no role validation, and no file type/size restrictions. Exposes all user data, product images, and invoices to any logged-in user.
- **Remediation**: Partition storage paths (e.g., `/users/{userId}/...`, `/products/...`), restrict file types, enforce file size limits, and apply role-based access check functions.

### 2. Pre-Authorized Users Collection Issues
- **Problem**: In `firestore.rules` (Line 78):
  ```firestore security rules
  allow get: if true;
  ```
- **Risk**: Anyone (even unauthenticated users) can read any pre-authorized user document containing sensitive phone numbers or email addresses, resulting in data exposure and privacy violations.
- **Remediation**: Restrict `get` to only authenticated users during signup or restrict it to matching phone numbers/emails rather than allowing public access.

### 3. Firestore Rules - Missing Validations on Products
- **Problem**: In `firestore.rules` (Lines 91-93):
  ```firestore security rules
  products allow read: if true;
  ```
- **Risk**: No geofence validation for reading products. Exposes pricing and stock numbers globally to competitors.
- **Remediation**: Require users to specify a location and only allow reading products from branches within the geofenced service area.

---

## 🟠 HIGH-PRIORITY FUNCTIONAL ISSUES (FIRESTORE RULES)

### 4. Role String Format Vulnerability
- **Problem**: In `firestore.rules` (Lines 10-27), roles are compared using hardcoded string literals:
  ```firestore security rules
  get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'UserRole.shopOwner'
  ```
- **Risk**: Typos in string literals can break permission logic. No fallback for missing role field exists.
- **Remediation**: Use strict enum validation or clear string constants, and write a fallback case for empty/missing roles.

### 5. Geofence Calculation Inaccuracy
- **Problem**: In `firestore.rules` (Lines 40-49), approximate lat/lng formulas are used:
  ```firestore security rules
  let latDelta = config.maxDeliveryRadiusKm * 0.009; // ~1km = 0.009 degrees
  let lngDelta = config.maxDeliveryRadiusKm * 0.011; // adjusted for longitude
  ```
- **Risk**: Accuracy varies greatly by latitude (fails near poles/equator). No validation is performed for null config values.
- **Remediation**: Use high-precision geo-bounding box calculations or move the geofencing calculation backend-side to a Cloud Function using coordinate distance formulas.

### 6. Order Terminal State Checking
- **Problem**: In `firestore.rules` (Lines 31-34), order terminal state is checked using manual string comparisons:
  ```firestore security rules
  function isOrderTerminal(orderData) {
    return orderData.status == 'OrderStatus.delivered' || orderData.status == 'OrderStatus.cancelled';
  }
  ```
- **Risk**: No verification that the status is a valid enum string. String comparisons are vulnerable to case mismatch or typos. Intermediate terminal states like `refunding` or `disputed` are missing.
- **Remediation**: Validate statuses against an allowed list of enum values, and expand terminal state checks to include refund/dispute terminal statuses.

### 7. Nested Path Access Vulnerability
- **Problem**: In `firestore.rules` (Line 141):
  ```firestore security rules
  allow read: if isSignedIn() && request.auth.uid == get(/databases/$(database)/documents/orders/$(orderId)).data.customerId;
  ```
- **Risk**: Deep queries using `get()` inside rules can cause race conditions or performance hits under high write load.
- **Remediation**: Structure client requests to query only resource states already containing authorization info, or pass verification metadata.

---

## 🟡 CODE QUALITY ISSUES (FLUTTER APP)

### 8. Multiple Firebase Initializations
- **Location**: `lib/main.dart` (Lines 69, 100)
- **Problem**: `Firebase.initializeApp()` is called twice: once in `_initializeSecurity()` and again in `_initializeApp()`.
- **Risk**: Can lead to race conditions, memory leaks, and app instability.
- **Remediation**: Consolidate into a single initialization block.

### 9. Unhandled Exception in `_initializeSecurity()`
- **Location**: `lib/main.dart` (Line 82)
- **Problem**: If App Check fails, it catches the error and silently continues:
  ```dart
  } catch (e) {
    debugPrint('[Security] App Check initialization skipped: $e');
  }
  ```
- **Risk**: App continues to run in insecure mode when App Check is broken.
- **Remediation**: Implement a safe fallback, warning, or block user interaction for sensitive operations when App Check fails.

### 10. Hardcoded Environment Variables
- **Location**: `lib/main.dart` (Line 57)
- **Problem**: `SENTRY_DSN` is loaded with an empty default fallback.
- **Risk**: Errors are not tracked in production if config is omitted.
- **Remediation**: Enforce checks that raise warnings/errors if required variables like `SENTRY_DSN` are missing in production.

### 11. Missing Provider Dependencies Validation
- **Location**: `lib/main.dart` (Lines 148-168)
- **Problem**: Over 15 providers are initialized without validations, potentially leaking memory or crashing if dependencies fail to resolve.
- **Remediation**: Add error boundaries and lifecycle checks on stream/change providers.

### 12. Deprecated API Usage
- **Location**: `lib/main.dart` (Lines 74-77)
- **Problem**: Uses `ignore: deprecated_member_use` for AndroidProvider and AppleProvider.
- **Risk**: Deprecated options will break in future Firebase SDK upgrades.
- **Remediation**: Replace with up-to-date providers (`PlayIntegrity` and `DeviceCheck` classes).

### 13. Performance: Multiple Provider Calls
- **Location**: `lib/product_card.dart` (Lines 32-33)
- **Problem**: Calls `Provider.of()` without `listen: false` within the build method, causing the entire card to rebuild whenever the location or shop configurations change.
- **Remediation**: Switch to `context.read()` or utilize `Consumer` / `Selector` widgets to scope rebuilds.

### 14. Race Condition in Branch Selection
- **Location**: `lib/product_card.dart` (Lines 36-48)
- **Problem**: If `selectedAddress` or `nearest` is null, the fallback is a hardcoded primary branch string.
- **Risk**: Unhandled null addresses can cause rendering errors or incorrect stock allocations.
- **Remediation**: Implement loading and error boundaries to prevent null values during location updates.

### 15. Image Caching Not Optimized
- **Location**: `lib/product_card.dart` (Lines 83-97)
- **Problem**: `CachedNetworkImage` doesn't define custom cache parameters or custom headers, which could result in showing stale images or exceeding cache storage.
- **Remediation**: Add max age, cache key control, and proper sizing constraints.

### 16. Accessibility Issues
- **Location**: `lib/product_card.dart`
- **Problem**: Missing semantic labels for prices/discounts, hardcoded non-responsive font sizes, and emojis used without matching descriptions.
- **Remediation**: Wrap text in `Semantics` widgets and use dynamic scaling text widgets.

### 17. Conditional Widget Tree / Complex Ternaries
- **Location**: `lib/product_card.dart` (Lines 241-277, 313-330)
- **Problem**: Nesting complex ternaries and deep widget structures inside the `build()` method impacts performance and readability.
- **Remediation**: Extract parts of the stack/row widgets to smaller, focused widgets.

### 18. Missing Error Handling in URL Launching
- **Location**: `lib/product_card.dart` (Lines 687-694)
- **Problem**: Lauching map links fails silently without feedback if Google Maps/browser is missing.
- **Remediation**: Wrap launch code in try/catch and show a SnackBar notification on failure.

---

## 🔴 BACKEND ISSUES (functions/)

### 19. `node_modules` Stored in Git Repository
- **Problem**: Bloated repository size (15MB of node modules committed).
- **Risk**: High disk usage, slow cloning times, security vulnerabilities are frozen in repo, and potential version mismatches.
- **Remediation**: Remove `functions/node_modules` from git index (`git rm -r --cached`), commit change, and add it to `.gitignore`.

### 20. Hidden Custom Functions Content
- **Problem**: Imports from node_modules; custom deployment configurations not fully documented.
- **Remediation**: Clear packaging of custom logic files, structured directories, and standard dependency locks.

---

## 🟠 STORAGE RULES - COMPLETE REDESIGN NEEDED

### 21. Permissive Auth Write Access
- **Problem**: Any signed-in user can overwrite and delete any file in Firebase Storage.
- **Remediation**: Structure folder-based access:
  - Users path: `/users/{userId}/...`
  - Invoices path: `/invoices/{userId}/...`
  - Products path (Public read, write restricted to Admin): `/products/{productId}/...`

---

## 📊 ARCHITECTURE & SCALABILITY ISSUES

### 22. Firestore Queries Not Indexed
- **Problem**: Multiple filters used in orders and products collections without composite indexes.
- **Risk**: Queries will fail in production when data scale increases.
- **Remediation**: Generate and store a `firestore.indexes.json` configuration file with needed indexes.

### 23. Missing Rate Limiting
- **Problem**: No Cloud Function quotas, DDoS protection, or backend throttling.
- **Risk**: Financial exposure due to spam calls on API.
- **Remediation**: Apply function billing caps, API rate limit headers, and App Check verification checks.

### 24. No Request Validation on Cloud Functions
- **Problem**: Functions take raw maps and do not validate types or content size constraints.
- **Risk**: SQL/NoSQL injection and server crashes.
- **Remediation**: Use libraries like `Joi` or standard JSON schema validators for all inputs.

### 25. Error Responses Not Standardized
- **Problem**: Function returns raw errors, potentially leaking stack traces to client logs.
- **Remediation**: Standardize error types using `functions.https.HttpsError` with production-safe error codes.

---

## 🎯 FEATURE/BUSINESS LOGIC GAPS

### 26. Immutable Wallet Transactions
- **Problem**: Inability to fix double-charging or reverse transactions.
- **Remediation**: Introduce a secure transaction reversal process with digital audit trails.

### 27. Return Requests Not Enforced
- **Problem**: Shop owner can edit request state without following validation workflows.
- **Remediation**: Implement strict state transitions (Pending -> Approved/Rejected -> Refunded).

### 28. Group Buying Pools Unsafe
- **Problem**: Member lists can be updated by any participant without consent.
- **Remediation**: Validate changes via backend Cloud Functions enforcing member consensus.

### 29. Khata Transactions Vulnerable
- **Problem**: No log detailing who added/edited transactions. Decimal precision errors on balances.
- **Remediation**: Use integers (paise/cents) for transactions, and append audit subcollections for edits.

---

## 🔧 DEPENDENCY & COMPATIBILITY ISSUES

### 30. Overridden Dependencies
- **Problem**: Forced override of `record_platform_interface`.
- **Risk**: Unstable updates can crash recording features.
- **Remediation**: Resolve the dependency tree, update `record` library to a compatible release.

### 31. Missing Transitive Dependency Pins
- **Problem**: `intl: any` and other packages use floating versioning.
- **Risk**: Automatic updates can introduce breaking API changes.
- **Remediation**: Lock packages to verified compatible semantic versions.

### 32. Package State Redundancy
- **Problem**: Both `provider` and `riverpod` are included.
- **Risk**: Unused code bloat, split logic design patterns.
- **Remediation**: Plan consolidation onto one primary state management library (or clean boundaries).

---

## 📱 UI/UX WEAKNESSES

### 33. No Skeleton Loading State
- **Problem**: Relying only on generic shimmer for all placeholders instead of targeted layouts.
- **Remediation**: Design skeleton templates matching the exact structure of product/order cards.

### 34. Pagination Not Visible
- **Problem**: Infinite scroll leaves users confused about how much content is left.
- **Remediation**: Add footer status states (e.g., "Showing 20 of 150 items" or retry buttons).

### 35. No Image Reloading Fallback
- **Problem**: Broken network images freeze in the error state.
- **Remediation**: Add a retry button to fetch resources again when connection recovers.

### 36. Missing Loading State on Checkout & Cart Actions
- **Problem**: Cart buttons do not display spinners, opening paths to double-taps.
- **Remediation**: Implement visual lockouts and debounce on tap events.

### 37. Missing Inline Form Input Validations
- **Problem**: Input errors show only on submit, creating bad UX.
- **Remediation**: Add reactive, real-time validators on form inputs (text fields).

---

## 🏗️ DATA MODEL ISSUES

### 38. Fragmented Stock Calculations
- **Problem**: `stockQuantity` is duplicated across product levels and branch levels.
- **Risk**: Inconsistencies and race conditions.
- **Remediation**: Force branch-level inventories to be the source of truth, computed automatically.

### 39. Missing Transaction Atomicity
- **Problem**: Multiple Firestore writes run in sequence without using batch or transactional updates.
- **Risk**: Partial updates leave database corrupted.
- **Remediation**: Use `WriteBatch` or `runTransaction` for multi-document modifications.

### 40. Missing Data Validations
- **Problem**: No min/max range checks on pricing/text lengths.
- **Remediation**: Add database rules and model-level assertions on input bounds.

### 41. Address Model Not Validated
- **Problem**: Latitude/longitude fields can be null, causing geofence rules to fail.
- **Remediation**: Assert required location coordinates in models and schema validators.

---

## 📡 OFFLINE & SYNC ISSUES

### 42. Offline Queue Status Hidden
- **Problem**: Background queue processes data silently.
- **Risk**: Users might close the app before sync, losing changes.
- **Remediation**: Display a sync queue indicator widget in the UI.

### 43. Cache Expiry Rules Missing
- **Problem**: Hive cached items remain indefinitely without TTL.
- **Remediation**: Enforce max-cache limits and TTL checks.

### 44. Offline Conflicts Unhandled
- **Problem**: Concurrent offline edits override each other (last-write-wins).
- **Remediation**: Add timestamp-based conflict checking or prompt merge dialogs.

---

## 🔒 ADDITIONAL SECURITY ISSUES

### 45. Firebase App Check Bypasses Allowed
- **Problem**: Insecure code execution when App Check errors occur.
- **Remediation**: Enforce blocking modes in non-development projects.

### 46. Missing Input Sanitization
- **Problem**: Raw strings accepted for reviews/chats.
- **Risk**: Injection/XSS vulnerability.
- **Remediation**: Strip HTML and escape query tags on input write.

### 47. Auth Rate Limiting Lacking
- **Problem**: No brute-force protection on auth endpoints.
- **Remediation**: Bind CAPTCHA checks or limit OTP generation requests per IP.

### 48. JWT Expiration Handling Missing
- **Problem**: Expired custom tokens lead to silent app lockups.
- **Remediation**: Bind automatic session refresh listeners.

---

## 📊 MONITORING & OBSERVABILITY

### 49. Incomplete Sentry Sampling
- **Problem**: `tracesSampleRate` set to `1.0`.
- **Risk**: Quickly exceeds limits in production.
- **Remediation**: Decrease to `0.2`.

### 50. Incomplete Analytics Pipeline
- **Problem**: Crash events are not bound to user behaviors.
- **Remediation**: Log errors to Sentry + Firebase Analytics.

### 51. Performance Tracing Absent
- **Problem**: Startup recorded, but no operations track slow database transactions.
- **Remediation**: Add custom traces on networking and local storage writes.

### 52. Production Logs Absent
- **Problem**: Debug prints stripped, leaving zero diagnostics in production.
- **Remediation**: Deploy structured logs using a dedicated logger like `lumberdash` or similar.

---

## 🚀 DEPLOYMENT & CI/CD ISSUES

### 53. Unprotected Secrets
- **Problem**: Keys committed in workflows or repos.
- **Remediation**: Migrate keys to GitHub Secrets and Firebase Secret Manager.

### 54. Lack of Staging Project
- **Problem**: Direct deployment to production without pre-production testing.
- **Remediation**: Instantiate a secondary Firebase environment for staging.

### 55. Missing Backups Configuration
- **Problem**: Firestore backup schedules not fully configured or tested.
- **Remediation**: Run backup verification checks.

### 56. Safe Hotpatch (Shorebird) Strategy Absent
- **Problem**: Hotpatches can break matching APIs on older builds.
- **Remediation**: Implement version gating on Shorebird updates.
