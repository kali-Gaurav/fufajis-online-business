# FUFAJI ONLINE BUSINESS
# MASTER FEATURE → FILE → FUNCTION AUDIT MAP

Version: Phase 4 Production Hardening (Flutter Edition)

Purpose:
This document acts as the single source of truth for feature ownership, file ownership, dependencies, workflows, missing implementations, and audit checkpoints for the Fufaji Online Business system.

---

# 1. APPLICATION ENTRY

## main.dart
[main.dart](file:///c:/Projects/fufaji-online-business/lib/main.dart)

### Responsibilities
* Firebase Core & Auth initialization
* Dependency injection (SupaBase, Upstash Redis, Local cache initialization)
* Provider registration (MultiProvider configuration for auth, cart, theme, wallet, delivery, reviews, etc.)
* Custom Theme loading (integrating Fufaji custom colors and typography)
* Localization initialization (AppLocalizations setup)
* Routing configuration using `GoRouter` setup in `AppRouter`

### Audit Checklist
* Handle Firebase initialization failure states gracefully with fallback to local cached database.
* Prevent duplicate provider registrations or unwanted rebuild triggers.
* Profile app startup latency (minimize blocking calls during splash/entry).
* Assure localization file loaders do not crash on missing keys or fallbacks.

---

# 2. ROUTING SYSTEM

## app_router.dart
[app_router.dart](file:///c:/Projects/fufaji-online-business/lib/utils/app_router.dart)

### Responsibilities
* Route definitions for all roles: Customer, Shop Owner, Admin, Delivery Agent, and Employee.
* MultiListenable implementation (`_MultiListenable`) coordinating refreshes across `AuthProvider` and `GuestProvider`.
* Navigation guards protecting role-restricted screens.
* Authentication redirects & verification walls.

### Critical Functions
* `redirect()`
* `_MultiListenable()`
* `router` instance configuration

### Audit Checklist
* Double-auth validation check on deep links leading to restricted paths (e.g., `/owner/dashboard`).
* Route configuration verification to ensure no infinite redirection cycles occur during session expiry.
* Redirection rules for new devices requiring verification pin wall (`/security-pin` & `/auth/verify-wall`).

---

# 3. AUTHENTICATION

## Files
* [auth_service.dart](file:///c:/Projects/fufaji-online-business/lib/services/auth_service.dart)
* [auth_provider.dart](file:///c:/Projects/fufaji-online-business/lib/providers/auth_provider.dart)
* [login_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/login_screen.dart)
* [otp_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/otp_screen.dart)
* [role_select_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/role_select_screen.dart)

### Responsibilities
* Multi-platform authentication handling (Firebase Authentication + Google Sign-In + Supabase fallback).
* Role authorization via custom claims and Firestore matching.
* Session management & remote session revocation logic.
* OTP rate limiting and verification walls.

### Critical Functions
* `signInWithGoogle()`
* `loginWithEmailPassword()`
* `sendOTP()` / `verifyOTP()`
* `checkAndLinkDuplicateAccount()`
* `_checkRoleAuthorization()`
* `logout()`

### Firestore Collections
* `users`
* `pre_authorized_users`
* `sessions`

### Audit Checklist
* Verify token refresh triggers properly sync backend Custom Claims.
* OTP rate limiter vulnerability assessment to prevent SMS spam.
* Ensure Google Sign-In failure falls back to email/password or Supabase OTP smoothly.
* Audit remote session revocation listeners for instantaneous trigger on unauthorized actions.

---

# 4. USER MANAGEMENT

## Files
* [user_service.dart](file:///c:/Projects/fufaji-online-business/lib/services/user_service.dart)
* [profile_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/customer/profile_screen.dart)
* [profile_creation_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/customer/profile_creation_screen.dart)

### Responsibilities
* Saving user details (name, email, phone) to Firestore with Supabase mirroring.
* Pre-authorizing roles (RBAC mapping) for employees, riders, and owners.
* Onboarding setup for new customer registrations.

### Critical Functions
* `createUser()`
* `getUser()`
* `updateUser()`
* `ensureUserDocExists()`
* `authorizeUser()` / `deauthorizeUser()`

### Firestore Collections
* `users`
* `pre_authorized_users`

### Audit Checklist
* Handle input validation carefully (prevent invalid phone formats/emails).
* Confirm transaction atomicity when mirroring users between Firestore and Supabase.
* Secure pre-authorization writes so only authorized administrative users or owner can edit roles.

---

# 5. PRODUCT MANAGEMENT

## Files
* [product_service.dart](file:///c:/Projects/fufaji-online-business/lib/services/product_service.dart)
* [product_provider.dart](file:///c:/Projects/fufaji-online-business/lib/providers/product_provider.dart)
* [products_management.dart](file:///c:/Projects/fufaji-online-business/lib/screens/owner/products_management.dart)
* [add_product_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/owner/add_product_screen.dart)
* [product_moderation_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/admin/product_moderation_screen.dart)

### Responsibilities
* Product catalog listing, addition, batch imports, updating, and deletions.
* Low stock threshold calculation and automated severity alert scoring.
* Admin product approval and moderation dashboard.
* Product review creation and moderation (rating score recalculation).

### Critical Functions
* `getProducts()` / `getProductsStream()`
* `addProduct()`
* `batchAddProducts()`
* `updateProduct()`
* `deleteProduct()`
* `createLowStockAlert()`
* `addProductReview()`

### Firestore Collections
* `products`
* `low_stock_alerts`
* `products/{productId}/reviews`

### Audit Checklist
* Concurrency checks during review creation to avoid wrong average rating calculations.
* Ensure low stock alerts use correct velocity models and don't produce duplicate alert records.
* Barcode redundancy checking when adding or editing products.

---

# 6. PRICE CHANGE APPROVAL SYSTEM

## Files
* [product_service.dart](file:///c:/Projects/fufaji-online-business/lib/services/product_service.dart)
* [pending_price_changes_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/owner/pending_price_changes_screen.dart)

### Responsibilities
* Safe price update proposals by store clerks/staff.
* Owner validation console for review, approval, and rejection of proposals.
* Maintaining logs of price modifications.

### Critical Functions
* `proposePriceChange()`
* `getPendingPriceChangesStream()`
* `approvePriceChange()`
* `rejectPriceChange()`

### Firestore Collections
* `price_changes`

### Audit Checklist
* Ensure strict Firestore rules prevent direct product price writes by clerks without approved price changes.
* Verify double approval attempts are mitigated by transactional locks.
* Audit trail integrity for proposed prices.

---

# 7. SEARCH SYSTEM

## Files
* [search_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/customer/search_screen.dart)
* [ai_search_service.dart](file:///c:/Projects/fufaji-online-business/lib/services/ai_search_service.dart)
* [trie_search_engine.dart](file:///c:/Projects/fufaji-online-business/lib/utils/trie_search_engine.dart)

### Responsibilities
* Client-side autocomplete using a Prefix Trie search engine.
* Hybrid search scoring using Levenshtein distance & prefix indexing.
* Keyword match parsing and NLP searches.

### Critical Functions
* `searchProducts()`
* `insert()` / `searchPrefix()`
* `parseQuery()`

### Audit Checklist
* Performance test of Trie searches with high catalog volumes (10,000+ items).
* Offline capabilities verification when searching cached catalogs.
* Proper synchronization of local search tries with remote updates.

---

# 8. POS SYSTEM & CASH REGISTER

## Files
* [cash_register_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/owner/cash_register_screen.dart)
* [barcode_scanner_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/customer/barcode_scanner_screen.dart)
* [pos_provider.dart](file:///c:/Projects/fufaji-online-business/lib/providers/admin_provider.dart)

### Responsibilities
* Offline/Online POS billing terminals.
* Item catalog addition via camera barcode scanner.
* Quick discounts, cash register validation, and receipts parsing.

### Critical Functions
* `scanBarcode()`
* `processPOSCheckout()`
* `calculateGST()`

### Audit Checklist
* Check scanning reliability and scan-debounce configuration.
* Ensure real-time inventory adjustments trigger immediately upon POS checkout completion.
* Check tablet layout responsiveness for register terminals.

---

# 9. CART SYSTEM

## Files
* [cart_provider.dart](file:///c:/Projects/fufaji-online-business/lib/providers/cart_provider.dart)
* [cart_sync_service.dart](file:///c:/Projects/fufaji-online-business/lib/services/cart_sync_service.dart)
* [cart_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/customer/cart_screen.dart)

### Responsibilities
* Adding/Removing items, updating quantities, and local SQLite/shared preferences persistence.
* Anonymous/Guest cart sync & merge with server cart document on successful verification/login.

### Critical Functions
* `addItem()` / `removeItem()`
* `updateQuantity()`
* `mergeCarts()`
* `syncCartToServer()`

### Firestore Collections
* `carts`

### Audit Checklist
* Race conditions when multiple items are updated in rapid succession.
* Verification of cart price recalculations when product discounts update dynamically.
* Validation of stock availability checks before final cart checkout step.

---

# 10. ORDER MANAGEMENT

## Files
* [order_service.dart](file:///c:/Projects/fufaji-online-business/lib/services/order_service.dart)
* [order_provider.dart](file:///c:/Projects/fufaji-online-business/lib/providers/order_provider.dart)
* [orders_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/customer/orders_screen.dart)
* [orders_management.dart](file:///c:/Projects/fufaji-online-business/lib/screens/owner/orders_management.dart)
* [order_detail_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/customer/order_detail_screen.dart)

### Responsibilities
* Creating orders, assigning delivery agents, status tracking, and order packing states.
* Handling transactional flow (Razorpay integrations, cash, UPI routing).

### Critical Functions
* `createOrder()`
* `updateOrderStatus()`
* `assignDriver()`
* `listenToActiveOrders()`

### Firestore Collections
* `orders`

### Audit Checklist
* Ensure payment confirmation verification relies on backend webhook signatures rather than client callbacks.
* Handle order packing state changes to verify stock item allocations correctly.
* Strict state transitions enforcement (e.g., Paid -> Packing -> Dispatched -> Out for Delivery -> Delivered).

---

# 11. RETURNS & REFUNDS

## Files
* [settlements_management.dart](file:///c:/Projects/fufaji-online-business/lib/screens/owner/settlements_management.dart)
* [order_service.dart](file:///c:/Projects/fufaji-online-business/lib/services/order_service.dart)
* [returns_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/employee/returns_screen.dart)

### Responsibilities
* Processing return requests from customers.
* Refunding order values to wallet or source account.
* Ledger reconciliation of shop settlements.

### Critical Functions
* `requestReturn()`
* `approveReturn()` / `rejectReturn()`
* `reconcileSettlement()`

### Firestore Collections
* `return_requests`
* `settlements`

### Audit Checklist
* Prevent refund amount manipulation via frontend request interception.
* Assure inventory counts increment back only after physical package verification check.
* Check ledger audit trail validation.

---

# 12. DELIVERY SYSTEM

## Files
* [delivery_orders_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/delivery/delivery_orders_screen.dart)
* [live_tracking_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/delivery/live_tracking_screen.dart)
* [delivery_tracking_service.dart](file:///c:/Projects/fufaji-online-business/lib/services/delivery_tracking_service.dart)
* [smart_route_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/delivery/smart_route_screen.dart)

### Responsibilities
* Geo-location polling and updating delivery coordinates.
* Smart delivery routing and delivery clustering calculations.
* Driver assignments, status logs, and rider support portal.

### Critical Functions
* `updateLocation()`
* `calculateRoute()`
* `clusterDeliveries()`

### Firestore Collections
* `delivery_locations`
* `trips`

### Audit Checklist
* High batteries consumption monitoring from continuous geo-polling on rider devices.
* Offline caching of delivery locations if riders lose network connectivity.
* Proper lock handling when multiple delivery drivers try to accept the same order assignment.

---

# 13. EMPLOYEE MODULE

## Files
* [employee_home_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/employee/employee_home_screen.dart)
* [employee_provider.dart](file:///c:/Projects/fufaji-online-business/lib/providers/employee_provider.dart)
* [attendance_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/employee/attendance_screen.dart)
* [task_priority_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/employee/task_priority_screen.dart)

### Responsibilities
* Employee shifts login/attendance tracking.
* Prioritizing tasks (picking, stock refills, expiry checks, packing).
* Shift cash collections reporting.

### Critical Functions
* `clockIn()` / `clockOut()`
* `getPendingTasks()`
* `recordCashCollection()`

### Firestore Collections
* `employee_attendance`
* `employee_tasks`
* `cash_collections`

### Audit Checklist
* Prevent geo-spoofing during attendance check-in.
* Check offline local databases storage in case clerks scan barcode labels without Wi-Fi connectivity.
* Task locks verification when multiple clerks pack orders concurrently.

---

# 14. OWNER DASHBOARD

## Files
* [owner_dashboard.dart](file:///c:/Projects/fufaji-online-business/lib/screens/owner/owner_dashboard.dart)
* [owner_home_page_simplified.dart](file:///c:/Projects/fufaji-online-business/lib/screens/owner/owner_home_page_simplified.dart)

### Responsibilities
* Main management dashboard for metrics analytics.
* Quick shortcuts to product additions, price checks, employee records, settlements, and live tracking.
* Security event audits viewing.

### Critical Functions
* `fetchOwnerSummary()`
* `listenToAnalyticsChange()`

### Audit Checklist
* Confirm metrics do not query entire order histories, causing Firestore read cost spikes.
* Layout responsiveness verification (ensure dashboard is clean on mobile & tablets).
* Verify only authorized `owner` roles can access sub-modules.

---

# 15. ADMIN DASHBOARD

## Files
* [admin_dashboard.dart](file:///c:/Projects/fufaji-online-business/lib/screens/admin/admin_dashboard.dart)

### Responsibilities
* Main global administrator panel.
* User roles configuration, global settings updates, and system integrity logs.

### Critical Functions
* `fetchGlobalMetrics()`
* `moderateUserStatus()`

### Audit Checklist
* Multi-factor verification (MFA) validation check for admin accounts.
* Confirm Firestore rules completely block normal users from accessing Admin endpoints.

---

# 16. COUPON HUB

## Files
* [coupon_management_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/admin/coupon_management_screen.dart)
* [pricing_service.dart](file:///c:/Projects/fufaji-online-business/lib/services/pricing_service.dart)

### Responsibilities
* Creation, validation, and usage tracking of discount coupons.
* Applying discounts dynamically during checkout computation.

### Critical Functions
* `applyCoupon()`
* `validateCouponCode()`

### Firestore Collections
* `coupons`

### Audit Checklist
* Check code constraints validations (e.g., expiry date, minimum order amount, user usage limits).
* Prevent concurrent request exploitation to reuse single-use coupon codes.

---

# 17. NOTIFICATION SYSTEM

## Files
* [notification_service.dart](file:///c:/Projects/fufaji-online-business/lib/services/notification_service.dart)
* [broadcast_notification_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/owner/broadcast_notification_screen.dart)

### Responsibilities
* Local reminders, FCM push alerts, WhatsApp message routing, and broadcast notifications.
* Storing notification preferences.

### Critical Functions
* `sendNotificationToUser()`
* `sendBroadcastNotification()`
* `showLocalNotification()`

### Firestore Collections
* `notifications`
* `broadcast_notifications`

### Audit Checklist
* Verify FCM registration token management is clean (removes invalid/expired tokens).
* Assure push payloads comply with FCM notification delivery formatting requirements.
* Rate limit broadcast distributions to avoid FCM quota exhaustion.

---

# 18. VOICE ASSISTANT

## Files
* [voice_command_service.dart](file:///c:/Projects/fufaji-online-business/lib/services/voice_command_service.dart)
* [voice_command_executor.dart](file:///c:/Projects/fufaji-online-business/lib/services/voice_command_executor.dart)
* [voice_order_screen.dart](file:///c:/Projects/fufaji-online-business/lib/screens/customer/voice_order_screen.dart)

### Responsibilities
* Hinglish speech-to-text parsers parsing user instructions.
* Executing routing commands, product adds, and POS calls via voice prompts.

### Critical Functions
* `processVoiceCommand()`
* `executeAction()`
* `parseHinglishQuery()`

### Audit Checklist
* Handle voice engine transcription failures gracefully (fallback to normal keyboard/search).
* Verify command executors check security context permissions before editing orders.

---

# 19. ANALYTICS

## Files
* [smart_analytics_service.dart](file:///c:/Projects/fufaji-online-business/lib/services/smart_analytics_service.dart)

### Responsibilities
* Reporting aggregated metrics (revenues, sales velocities, trend shifts).
* Calculating average transaction values and conversion funnels.

### Critical Functions
* `aggregateDailyMetrics()`
* `trackUserJourney()`

### Audit Checklist
* Do not save PII (Personally Identifiable Information) in Google Analytics/Firebase logs.
* Ensure heavy analytical queries run asynchronously or are calculated offline (e.g. via Cloud Functions).

---

# 20. FIREBASE STORAGE

## Files
* [storage_service.dart](file:///c:/Projects/fufaji-online-business/lib/services/storage_service.dart)

### Responsibilities
* Handling product image uploads, delivery proofs (POD signatures), and receipt image backups.

### Critical Functions
* `uploadImage()`
* `deleteFile()`

### Storage Buckets
* `gs://fufaji-online-business/products`
* `gs://fufaji-online-business/delivery_proofs`

### Audit Checklist
* Verify Firebase Storage Security Rules restrict write permissions exclusively to authorized roles.
* Cleanup orphaned media when product configurations or proof files update.

---

# 21. FIRESTORE SECURITY

## Files
* [firestore.rules](file:///c:/Projects/fufaji-online-business/firestore.rules)
* [storage.rules](file:///c:/Projects/fufaji-online-business/storage.rules)

### Responsibilities
* Security rules enforcement verifying reader and writer credentials.
* Checking Custom Claims (role authorization, MFA verification status).

### Priority
* **CRITICAL**

### Audit Checklist
* Run Firestore emulator tests verifying read/write permissions.
* Check recursive wildcards for safety.
* Restrict data edits so customers cannot edit price parameters.

---

# 22. CLOUD FUNCTIONS

## Files
* [functions/index.js](file:///c:/Projects/fufaji-online-business/functions/index.js)

### Responsibilities
* Custom claims synchronization (`syncUserClaims`).
* Daily reconciliation check, payment verification logs, and automated notifications execution.

### Priority
* **CRITICAL**

### Audit Checklist
* Cloud Functions execution timeouts monitoring.
* Secure configuration properties management (avoid environment variables leakage).
* Validate payloads for webhook callers.

---

# 23. LOCALIZATION

## Files
* [app_en.arb](file:///c:/Projects/fufaji-online-business/lib/l10n/app_en.arb)
* [app_hi.arb](file:///c:/Projects/fufaji-online-business/lib/l10n/app_hi.arb)

### Responsibilities
* Bilingual UI strings resource repository (English & Hindi formats).

### Priority
* **HIGH**

### Audit Checklist
* Missing string keys sync verification.
* Prevent hardcoded text elements in code UI views.

---

# 24. RESPONSIVE SYSTEM

## Files
* [responsive.dart](file:///c:/Projects/fufaji-online-business/lib/utils/responsive.dart)
* [android_breakpoints.dart](file:///c:/Projects/fufaji-online-business/lib/utils/android_breakpoints.dart)

### Responsibilities
* Window size breakpoint computations.
* Custom dynamic grids structures and layouts.

### Priority
* **HIGH**

### Audit Checklist
* Test UI render integrity on tablets, mobile screens, and folding devices.
* Check layout overflows or overlapping widgets.

---

# 25. REUSABLE COMPONENTS

## Files
* [empty_state_widget.dart](file:///c:/Projects/fufaji-online-business/lib/widgets/common/empty_state_widget.dart)
* [empty_state.dart](file:///c:/Projects/fufaji-online-business/lib/widgets/common/empty_state.dart)
* [error_state.dart](file:///c:/Projects/fufaji-online-business/lib/widgets/common/error_state.dart)

### Responsibilities
* Shared state visualization widgets.

### Audit Checklist
* Theme matching compliance.
* Verify buttons trigger expected recovery states smoothly.

---

# FINAL AUDIT STATUS TABLE

| Module | File Audit | Logic Audit | UI Audit | Firebase Audit | Performance Audit |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Auth** | Pending | Pending | Pending | Pending | Pending |
| **Products** | Pending | Pending | Pending | Pending | Pending |
| **Orders** | Pending | Pending | Pending | Pending | Pending |
| **POS** | Pending | Pending | Pending | Pending | Pending |
| **Delivery** | Pending | Pending | Pending | Pending | Pending |
| **Notifications** | Pending | Pending | Pending | Pending | Pending |
| **Analytics** | Pending | Pending | Pending | Pending | Pending |
| **Security** | Pending | Pending | Pending | Pending | Pending |
