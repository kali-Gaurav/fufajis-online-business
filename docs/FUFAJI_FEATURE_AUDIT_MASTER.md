# FUFAJI ONLINE BUSINESS
# MASTER FEATURE → FILE → FUNCTION AUDIT MAP

Version: Phase 4 Production Hardening

Purpose:
This document acts as the single source of truth for feature ownership, file ownership, dependencies, workflows, missing implementations, and audit checkpoints.

---

# 1. APPLICATION ENTRY

## main.dart

Responsibilities
* Firebase initialization
* Dependency injection
* Provider registration
* Theme loading
* Localization initialization
* Routing initialization

Audit Checklist
* Firebase initialization failures
* Duplicate provider registration
* App startup latency
* Theme loading consistency
* Localization loading

---

# 2. ROUTING SYSTEM

## app_router.dart

Responsibilities
* Route definitions
* Route guards
* Deep linking
* Authentication redirects

Key Functions
* redirect()
* routeGuard()
* buildRoutes()

Audit Checklist
* Broken routes
* Unauthorized access
* Infinite redirects
* Deep-link failures

---

# 3. AUTHENTICATION

Files
* auth_service.dart
* auth_provider.dart
* login_screen.dart
* signup_screen.dart

Responsibilities
* Login
* Signup
* Logout
* OTP
* Session handling

Critical Functions
* signIn()
* signUp()
* logout()
* verifyOtp()

Firestore
* users

Audit
* Session expiry
* Role escalation
* Password reset
* Token refresh

---

# 4. USER MANAGEMENT

Files
* user_provider.dart
* user_service.dart
* profile_screen.dart

Responsibilities
* User profile
* Address management
* Preferences
* Role information

Critical Functions
* updateProfile()
* updateAddress()
* getUser()

Audit
* Data validation
* Null handling
* Image upload failures

---

# 5. PRODUCT MANAGEMENT

Files
* product_service.dart
* product_provider.dart
* product_screen.dart
* add_product_screen.dart
* product_moderation_screen.dart

Responsibilities
* Product creation
* Product updates
* Product deletion
* Product moderation
* Barcode management

Critical Functions
* createProduct()
* updateProduct()
* deleteProduct()
* approveProduct()
* rejectProduct()

Collections
* products
* product_changes
* product_reviews

Audit
* Duplicate products
* Inventory sync
* Missing images
* Barcode conflicts

---

# 6. PRICE CHANGE APPROVAL SYSTEM

Files
* pending_price_changes_screen.dart
* product_service.dart

Responsibilities
* Proposed price updates
* Approval workflow
* Bulk approval

Critical Functions
* getPendingPriceChanges()
* approvePriceChange()
* rejectPriceChange()
* approveAllChanges()

Collections
* pending_price_changes

Audit
* Concurrent approvals
* Duplicate approval
* Audit trail integrity

---

# 7. SEARCH SYSTEM

Files
* search_screen.dart
* search_service.dart

Responsibilities
* Product search
* Category search
* Barcode search

Functions
* searchProducts()
* scanBarcode()

Audit
* Slow search
* Empty results
* Barcode mismatch

---

# 8. POS SYSTEM

Files
* cash_register_screen.dart
* barcode_scanner_screen.dart
* pos_provider.dart

Responsibilities
* Billing
* Checkout
* Barcode scan
* Discount application

Functions
* addToCart()
* checkout()
* applyCoupon()
* scanBarcode()

Audit
* Mobile responsiveness
* Cart synchronization
* Tax calculation
* Duplicate scans

---

# 9. CART SYSTEM

Files
* cart_provider.dart
* cart_screen.dart

Responsibilities
* Cart management
* Quantity updates

Functions
* addItem()
* removeItem()
* updateQuantity()

Audit
* Inventory mismatch
* Price mismatch

---

# 10. ORDER MANAGEMENT

Files
* order_service.dart
* orders_screen.dart
* order_details_screen.dart

Responsibilities
* Order lifecycle

Functions
* createOrder()
* cancelOrder()
* updateStatus()

Collections
* orders

Audit
* Status transitions
* Duplicate orders
* Payment mismatch

---

# 11. RETURNS & REFUNDS

Files
* settlements_management_screen.dart
* order_service.dart

Functions
* approveReturnRequest()
* rejectReturnRequest()

Collections
* refund_requests (Note: actually return_requests in Firestore)

Audit
* Refund duplication
* Settlement mismatch

---

# 12. DELIVERY SYSTEM

Files
* delivery_orders_screen.dart
* delivery_tracking_screen.dart

Responsibilities
* Delivery assignment
* Tracking
* Completion

Functions
* assignDelivery()
* updateLocation()
* completeDelivery()

Audit
* Tracking accuracy
* Assignment duplication

---

# 13. EMPLOYEE MODULE

Files
* employee_home_screen.dart
* employee_provider.dart

Responsibilities
* Employee tasks
* Order handling

Audit
* Offline mode
* Sync failures

---

# 14. OWNER DASHBOARD

Files
* owner_dashboard.dart

Responsibilities
* KPI monitoring
* Analytics
* Approvals

Audit
* KPI accuracy
* Data freshness

---

# 15. ADMIN DASHBOARD

Files
* admin_dashboard.dart

Responsibilities
* Global management
* User moderation

Audit
* Access permissions
* Dashboard performance

---

# 16. COUPON HUB

Files
* coupon_management_screen.dart
* coupon_service.dart

Functions
* createCoupon()
* validateCoupon()
* applyCoupon()

Collections
* coupons

Audit
* Expiry handling
* Abuse prevention

---

# 17. NOTIFICATION SYSTEM

Files
* notification_service.dart
* broadcast_notification_screen.dart

Functions
* sendNotification()
* sendBroadcastNotification()

Collections
* broadcast_notifications

Audit
* Delivery failures
* Duplicate notifications

---

# 18. VOICE ASSISTANT

Files
* voice_command_service.dart
* voice_command_executor.dart

Functions
* processCommand()
* getHelp()
* executeCommand()

Audit
* Missing command handlers
* Invalid command execution

---

# 19. ANALYTICS

Files
* smart_analytics_service.dart

Responsibilities
* Revenue analytics
* Product analytics
* Sales analytics

Audit
* Hardcoded calculations
* Data source validation

---

# 20. FIREBASE STORAGE

Files
* storage_service.dart

Responsibilities
* Product images
* User images
* Employee uploads

Audit
* Permission denied
* Failed uploads
* Orphaned files

---

# 21. FIRESTORE SECURITY

Files
* firestore.rules

Audit
* Owner permissions
* Admin permissions
* Employee permissions
* Customer permissions

Priority
CRITICAL

---

# 22. CLOUD FUNCTIONS

Files
* functions/index.js

Responsibilities
* Broadcast notifications
* Automation tasks
* Scheduled jobs

Audit
* Retry mechanism
* Error handling
* Logging

Priority
CRITICAL

---

# 23. LOCALIZATION

Files
* app_en.arb
* app_hi.arb

Audit
* Hardcoded strings
* Missing translations

Priority
HIGH

---

# 24. RESPONSIVE SYSTEM

Files
* responsive.dart

Functions
* kpiColumns()
* posColumns()

Audit
* Tablet layouts
* Mobile layouts
* Overflow issues

Priority
HIGH

---

# 25. REUSABLE COMPONENTS

Files
* fj_empty_state.dart
* fj_error_state.dart
* fj_button.dart
* fj_card.dart

Audit
* Usage consistency
* Accessibility
* Theme support

---

# FINAL AUDIT STATUS TABLE

| Module        | File Audit | Logic Audit | UI Audit | Firebase Audit | Performance Audit |
| ------------- | ---------- | ----------- | -------- | -------------- | ----------------- |
| Auth          | Pending    | Pending     | Pending  | Pending        | Pending           |
| Products      | Pending    | Pending     | Pending  | Pending        | Pending           |
| Orders        | Pending    | Pending     | Pending  | Pending        | Pending           |
| POS           | Pending    | Pending     | Pending  | Pending        | Pending           |
| Delivery      | Pending    | Pending     | Pending  | Pending        | Pending           |
| Notifications | Pending    | Pending     | Pending  | Pending        | Pending           |
| Analytics     | Pending    | Pending     | Pending  | Pending        | Pending           |
| Security      | Pending    | Pending     | Pending  | Pending        | Pending           |
