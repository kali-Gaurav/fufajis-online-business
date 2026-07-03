# FUFAJI STORE — MASTER AUDIT & 10-TEAM IMPLEMENTATION PLAN
**Date:** 2026-07-02  
**Status:** RED 🔴 (Security P0s, 4 new P0s, build errors)  
**Readiness:** 28/100 (Security incident not yet contained)

---

## EXECUTIVE SUMMARY

**Current State:**
- ✅ Core e-commerce features ~80% built (auth, cart, checkout, orders, referral, voice ordering, AI analytics)
- ✅ Phase 16 audit completed + 7 critical files deleted (dead code)
- ✅ 15 files fixed in P0 sprint (2026-07-02)
- 🔴 **CRITICAL**: 4 NEW P0s found (wallet, rules, coupons, nav)
- 🔴 **CRITICAL**: Security breach (public repo, live secrets, leaked keys)
- 🟡 Build errors (flutter_local_notifications v22 API mismatch — FIXED)

**Blockers (Must fix before any deploy):**
1. Security incident (secrets rotation + repo lockdown) — **EMERGENCY**
2. Wallet rules + wallet balance logic (prevents checkout)
3. Three delivery services collision (data race)
4. Razorpay webhook secret misconfigured

**Next 48 hours:** Security + P0s. Next 1 week: Full feature completion. Next 2 weeks: Play Store launch.

---

## 🚨 CRITICAL PATH (SECURITY + P0s)

### TIER 1: EMERGENCY (Fix before ANY deploy)

**P0-S1: Security Incident Response** ⚠️  
**Status:** Not Started  
**Impact:** ALL secrets compromised, signing key public, .env in APK  
**Tasks:**
- [ ] T-S1.1: Make GitHub repo PRIVATE (Gaurav dashboard action)
- [ ] T-S1.2: Rotate ALL secrets (Razorpay, Twilio, Gemini, Supabase, AWS, UPSTASH)
- [ ] T-S1.3: Purge git history (git-filter-repo, remove leaked files)
- [ ] T-S1.4: Remove `.env` asset from pubspec.yaml + main.dart (use --dart-define instead)
- [ ] T-S1.5: Regenerate Android signing keystore (current key is public)
- [ ] T-S1.6: Migrate secrets to Firebase Secret Manager + GitHub Secrets
- [ ] T-S1.7: Update functions/ to use `defineSecret()` instead of `functions.config()`
- [ ] T-S1.8: Commit + tag v0.0.1-security-hotfix

**P0-W1: Wallet Rules + Client Write Block**  
**Status:** Partially done (rules added, logic incomplete)  
**Impact:** Wallet-paid checkout broken, quick-add allows free money  
**Tasks:**
- [ ] T-W1.1: Add `.documents('wallet_transactions').allow(['read','create'], if: request.auth.uid == resource.data.uid)` to Firestore rules
- [ ] T-W1.2: Implement server-side wallet credit via Cloud Function `addWalletCredits(uid, amount, reason)` with PAN validation
- [ ] T-W1.3: Change wallet rule: `update: allow only if amount ≤ existing` (decrease-only)
- [ ] T-W1.4: Update `CheckoutProvider.addWalletFunds()` to call Cloud Function instead of direct Firestore
- [ ] T-W1.5: Test: Quick-add → payment required, checkout with wallet works, client cannot write

**P0-W2: Percentage Coupons Zero-Capping**  
**Status:** Fixed (code verified)  
**Impact:** Discount % applied but clamped to ₹0  
**Verification:**
- [ ] T-W2.1: Test coupon "SAVE20" (20% off ₹500 = ₹100) — verify ₹100 deducted, not ₹0
- [ ] T-W2.2: Verify `maximumDiscountAmount` fallback in `CouponService.applyCoupon()`

**P0-D1: Delivery Service Collision**  
**Status:** Design phase  
**Impact:** Three services writing to `deliveries/{id}` simultaneously (race condition)  
**Tasks:**
- [ ] T-D1.1: Audit `GpsTrackingService`, `DeliveryAssignmentService`, `DeliveryDetailScreen` writes to deliveries/{id}
- [ ] T-D1.2: Consolidate into single `DeliveryStateService` (source of truth)
- [ ] T-D1.3: Use Firestore transaction for all deliveries/{id} mutations
- [ ] T-D1.4: Remove duplicate logic from `order_status_engine` + `order_workflow_engine`
- [ ] T-D1.5: Test: Concurrent location updates + order state changes don't corrupt delivery doc

**P0-PAY1: Razorpay Webhook Secret Mismatch**  
**Status:** Config error identified  
**Impact:** Webhook signature verification fails, order status not updated  
**Tasks:**
- [ ] T-PAY1.1: Verify current key_secret vs webhook_secret in Razorpay dashboard (not .runtimeconfig.json)
- [ ] T-PAY1.2: Update `functions/.runtimeconfig.json` with correct values
- [ ] T-PAY1.3: Test: Create order → Razorpay → webhook fires → order marked paid

---

## TEAM 1: 📋 PRODUCT MANAGER — Feature Audit + Gap Analysis

**Deliverable:** Complete feature inventory, missing features, prioritized task list

### Feature Completeness Audit

| Feature | Status | Priority | Notes |
|---------|--------|----------|-------|
| **Customer Portal** | | | |
| Product Catalog | ✅ 95% | Done | 200+ products, Hindi/EN names, images, stock |
| Search + Filters | ✅ 95% | Done | Text, category, price range, stock |
| Voice Search | ✅ 90% | Done | Hinglish parser + Gemini boost (offline works) |
| Product Detail | ✅ 95% | Done | Images, price, stock, reviews, related products |
| Customer Reviews | ✅ 80% | HIGH | Screen exists, add/edit/delete flow needs UX review |
| Wishlist | ✅ 85% | MEDIUM | Routed, CRUD works, but empty-state UX missing |
| **Cart & Checkout** | | | |
| Add to Cart | ✅ 95% | Done | Quantity +/-, real-time stock validation |
| Cart Persistence | ✅ 90% | Done | AsyncStorage + Firestore sync (Guest + auth) |
| GST Calculation | ✅ 95% | Done | 18% on all items, separate line in summary |
| Address Management | ✅ 85% | HIGH | Add/edit/delete, but geolocation validation missing |
| Checkout Payment | ⚠️ 60% | **P0** | Razorpay UPI working, Wallet broken (rules), no Stripe |
| Order Confirmation | ✅ 95% | Done | Email, FCM, SMS via OrderProvider |
| **Wallet** | | | |
| View Balance | ✅ 95% | Done | Real-time Firestore stream |
| Add Funds | ⚠️ 40% | **P0** | Payment broken, quick-add allows free money |
| Redeem Referral | ✅ 95% | Done | ₹50 auto-redeemed on first order |
| Transaction History | ✅ 85% | MEDIUM | Listed, but no export/filter |
| **Payments** | | | |
| Razorpay UPI | ✅ 85% | Done | Live, webhook updates orders |
| Razorpay Card | ✅ 85% | Done | 3D Secure works |
| Razorpay Netbanking | ✅ 85% | Done | Live |
| Wallet Payment | ⚠️ 20% | **P0** | Broken due to Firestore rules |
| COD | ✅ 85% | HIGH | Implemented, risk limits not enforced |
| Stripe (UPI) | ❌ 0% | DROPPED | Removed from codebase (redundant with Razorpay) |
| **Orders & Fulfillment** | | | |
| Order History | ✅ 95% | Done | Search, filter by status, reorder button |
| Order Detail | ✅ 90% | Done | Status timeline, tracking, cancellation, returns |
| Cancellation | ✅ 95% | Done | Fee schedule (0%/5%/10%/15%), instant refund |
| Return (7-day) | ✅ 85% | HIGH | Initiated from order detail, but RMA flow incomplete |
| Partial Fulfillment | ✅ 85% | MEDIUM | Service exists, not wired to packing terminal |
| Failed Delivery | ✅ 85% | MEDIUM | Escalation screen, but rider UX needs refinement |
| **Notifications** | | | |
| FCM Push | ✅ 95% | Done | Order status, promos, system messages |
| SMS (Twilio) | ✅ 85% | HIGH | OTP works, broadcast not implemented |
| Email | ❌ 0% | **P1** | No email service (SendGrid in pubspec but not wired) |
| In-App Bell | ✅ 85% | MEDIUM | Icon shows count, list incomplete |
| **Referral & Loyalty** | | | |
| Refer & Earn | ✅ 95% | Done | ₹50/referral, stats, share, redeem |
| Rewards Dashboard | ✅ 80% | HIGH | Exists, but gamification points missing |
| Membership Tiers | ✅ 85% | MEDIUM | Gold/Platinum, benefits not enforced |
| **Owner Portal** | | | |
| Dashboard | ✅ 90% | Done | KPIs, quick actions, alerts |
| Analytics + Reports | ✅ 85% | HIGH | Business Analyst AI, charts, anomaly detection |
| Order Management | ✅ 90% | Done | List, detail, packing terminal, fulfillment |
| Inventory | ✅ 85% | HIGH | Stock levels, low-stock alerts, restock orders |
| Customer Segmentation | ✅ 85% | MEDIUM | VIP/At-Risk/Win-Back via SmartAnalyticsService |
| Staff Management | ✅ 75% | MEDIUM | Add/edit/permissions, but role enforcement gaps |
| **Rider Portal** | | | |
| Active Deliveries | ✅ 85% | Done | Map, GPS tracking, ETA, customer chat |
| History | ✅ 80% | MEDIUM | Trips grouped by day, earnings summary |
| Navigation | ✅ 85% | Done | Google Maps, route optimization (basic) |
| Earnings | ✅ 85% | HIGH | Per-trip breakdown, weekly/monthly summary |
| Document Upload | ✅ 75% | MEDIUM | DL/PAN, but verification workflow missing |
| **Admin Portal** | | | |
| User Management | ✅ 80% | HIGH | List, role assignment, but audit trail missing |
| Refunds & Disputes | ✅ 75% | HIGH | Dashboard, but auto-settlement not implemented |
| Payout Management | ✅ 75% | HIGH | Payouts to riders/suppliers, but reconciliation missing |
| **Support & Chat** | | | |
| Live Chat | ✅ 90% | Done | FCM, history, file upload, typing indicator |
| Support Tickets | ✅ 80% | MEDIUM | Create/track, but SLA tracking missing |
| Chatbot (Gemini) | ✅ 70% | MEDIUM | Responds to FAQs, but context retention low |
| FAQ/Help | ✅ 75% | MEDIUM | Static content only, no AI search |

### Missing Features (Gap List)

**TIER 1: MUST-HAVE (pre-launch)**
- [ ] T-PM1.1: Email notification service (SendGrid integration)
- [ ] T-PM1.2: SMS broadcast (Twilio integration for promos/campaigns)
- [ ] T-PM1.3: COD risk limits enforcement (order amount, customer history)
- [ ] T-PM1.4: Return RMA workflow (approval, shipping label, refund)
- [ ] T-PM1.5: Payout auto-settlement (riders, suppliers — weekly batches)
- [ ] T-PM1.6: Customer signup flow (phone OTP, address, first purchase)

**TIER 2: HIGH PRIORITY**
- [ ] T-PM2.1: Gamification points (loyalty tier badges, unlock rewards)
- [ ] T-PM2.2: Inventory restock alerts (owner + supplier emails)
- [ ] T-PM2.3: Delivery SLA dashboard (on-time %, breach tracking)
- [ ] T-PM2.4: Churn prediction (SmartAnalyticsService depth)
- [ ] T-PM2.5: Subscription products (auto-refill groceries, dad subscriptions)
- [ ] T-PM2.6: Gift cards (buy, redeem, balance tracking)

**TIER 3: NICE-TO-HAVE**
- [ ] T-PM3.1: Social features (friend lists, group orders, split bill)
- [ ] T-PM3.2: Supplier portal (catalog upload, demand forecasting)
- [ ] T-PM3.3: Live streams (product launches, founder Q&A)
- [ ] T-PM3.4: Marketplace mode (multi-vendor, ratings per vendor)

### Prioritized Task List for Implementation
**Phase A (Next 48h - P0s):** T-S1.* (Security), T-W1.* (Wallet rules), T-W2.* (Coupons), T-D1.* (Delivery), T-PAY1.* (Razorpay)  
**Phase B (Next 1 week):** T-PM1.* (Email, SMS, COD, RMA, Payout, Signup)  
**Phase C (Next 2 weeks):** T-PM2.* (Analytics depth, Inventory, Subscriptions)  
**Phase D (Post-launch):** T-PM3.* (Social, Marketplace)

---

## TEAM 2: 🎨 UI/UX DESIGNER — Design System Audit + Missing Screens

**Deliverable:** Design token audit, component library gaps, missing screen mockups, a11y checklist

### Design System Inventory

**Color Palette** ✅ Defined
```json
{
  "primary": "#1A5276",      // Trustworthy blue
  "accent": "#E67E22",        // Warm orange
  "success": "#27AE60",       // Green
  "danger": "#E74C3C",        // Red
  "warning": "#F39C12",       // Orange
  "background": "#FDFEFE",
  "surface": "#ECF0F1",
  "text_primary": "#1C2833",
  "text_secondary": "#5D6D7B",
  "divider": "#BDC3C7",
  "overlay_dark": "rgba(0,0,0,0.5)"
}
```

**Typography** ✅ Defined
- Font: Noto Sans (supports Devanagari)
- H1: 32px / 40px (bold, brand hero)
- H2: 24px / 32px (bold, section titles)
- Body: 16px / 24px (regular, content)
- Caption: 12px / 16px (regular, helpers)
- Button: 16px / 24px (bold, CTAs)

**Spacing Scale** ✅ Defined
- xs: 4px
- sm: 8px
- md: 16px
- lg: 24px
- xl: 32px
- 2xl: 48px

**Components** (Status)

| Component | Status | Notes |
|-----------|--------|-------|
| Button | ✅ 95% | Primary, secondary, outline; small/medium/large |
| Input | ✅ 90% | Text, email, phone, OTP; error states |
| Card | ✅ 95% | Product card, order card, info card |
| Badge | ✅ 90% | Status, tag, discount, stock |
| Bottom Nav | ✅ 95% | 5-tab (Home, Search, Cart, Orders, Profile) |
| Drawer | ✅ 90% | Filters, menu, address picker |
| Dialog | ✅ 85% | Confirm, alert, input dialog |
| Toast | ✅ 85% | Success, error, info, warning |
| Pagination | ⚠️ 60% | List pagination, but infinite scroll preferred |
| Date Picker | ⚠️ 70% | Birthday, order date filters |
| Rating | ✅ 90% | Stars 1-5, half-stars, count display |
| Progress | ✅ 85% | Linear (delivery, upload), circular (loading) |
| Tabs | ✅ 90% | Home tabs, order filters, owner dashboards |
| Accordion | ⚠️ 70% | FAQ, order details expansion |
| Slider | ⚠️ 60% | Price filter (low-high), quantity selector |

### Missing Screens / UX Gaps

**Customer Portal**
- [ ] T-UX1.1: Signup flow (phone OTP → name → address → first product discovery)
- [ ] T-UX1.2: Address management (list, add, edit, set default)
- [ ] T-UX1.3: Payment method management (saved Razorpay tokens, stored addresses)
- [ ] T-UX1.4: Subscription management (active subs, pause/cancel, refill schedule)
- [ ] T-UX1.5: Gift card purchase + redemption
- [ ] T-UX1.6: Notifications preferences (push, SMS, email frequency)

**Owner Portal**
- [ ] T-UX2.1: Inventory drill-down (product → variants → stock → reorder)
- [ ] T-UX2.2: Payout settlement (pending → processing → paid, batch details)
- [ ] T-UX2.3: Supplier/Staff role assignment (drag-drop, role templates)
- [ ] T-UX2.4: Campaign builder (email, SMS, push templates + scheduling)
- [ ] T-UX2.5: Churn risk notification (at-risk customer list + win-back CTA)

**Rider Portal**
- [ ] T-UX3.1: Earnings dashboard (daily, weekly, monthly breakdown)
- [ ] T-UX3.2: Document verification status (DL/PAN pending, verified, expired)
- [ ] T-UX3.3: Rating feedback screen (post-delivery, improvement suggestions)

**Admin Portal**
- [ ] T-UX4.1: Dispute resolution (evidence, decision, payout reversal)
- [ ] T-UX4.2: Scheduled payout batches (riders, suppliers, reconciliation)
- [ ] T-UX4.3: System health dashboard (API latency, error rates, Cloud Function status)

### Accessibility Audit

**WCAG 2.1 AA Compliance Checklist**
- [ ] T-A11y1.1: Color contrast ≥ 4.5:1 (text), ≥ 3:1 (large text, UI components)
- [ ] T-A11y1.2: Keyboard navigation (Tab, Enter, Esc on all screens)
- [ ] T-A11y1.3: Screen reader support (Semantics.label on images, buttons, form fields)
- [ ] T-A11y1.4: Touch target size ≥ 48×48 dp (all tappable elements)
- [ ] T-A11y1.5: Text size scalability (up to 200% without loss of function)
- [ ] T-A11y1.6: Motion/animation optional (reduce-motion preference respected)
- [ ] T-A11y1.7: ARIA labels on all dynamic content (loading states, toast notifications)

### Design Handoff Specs
- [ ] T-UX5.1: Component prop documentation (variants, states, edge cases)
- [ ] T-UX5.2: Responsive breakpoints (mobile < 600dp, tablet ≥ 600dp)
- [ ] T-UX5.3: Animation timing (enter: 300ms, exit: 200ms, easing: easeInOutCubic)
- [ ] T-UX5.4: Dark mode support (secondary priority, design tokens duplicated)

---

## TEAM 3: 📱 FRONTEND ARCHITECT — Code Structure Audit + Refactoring Plan

**Deliverable:** Project structure review, dead-code report, dependency graph, refactoring roadmap

### Current Project Structure
```
lib/
  main.dart                          ← 400 lines (main.dart review below)
  providers/
    auth_provider.dart               ← 800 lines (session, MFA, device verification)
    cart_provider.dart               ← 600 lines (guest sync, Firestore persistence)
    checkout_provider.dart           ← 500 lines (GST, address, payment)
    order_provider.dart              ← 700 lines (order creation, status workflows)
    product_provider.dart            ← 400 lines (search, filters, voice search)
    wallet_provider.dart             ← 300 lines (balance, transactions, top-up)
    accessibility_provider.dart      ← 200 lines (text size, high-contrast mode)
    guest_provider.dart              ← 150 lines (guest cart, migration on auth)
    report_provider.dart             ← 200 lines (streams reports from Firestore)
    smart_analytics_provider.dart    ← 250 lines (churn, VIP, forecasting)
  models/
    user_model.dart, order_model.dart, product_model.dart, ... (20 files)
  screens/
    auth/ (6 screens — login, signup, OTP, device verification, PIN, MFA)
    customer/ (15 screens — home, product, cart, checkout, orders, etc.)
    owner/ (12 screens — dashboard, analytics, orders, inventory, payout)
    rider/ (6 screens — active deliveries, history, earnings, navigation)
    admin/ (4 screens — users, disputes, payouts, health)
    common/ (4 screens — onboarding, settings, help, account linking)
  services/
    firebase_service.dart            ← 200 lines (init, auth, Firestore, Storage)
    razorpay_service.dart            ← 250 lines (UPI, card payment)
    notification_service.dart        ← 400 lines (FCM, local notifications, SMS hooks)
    order_workflow_engine.dart       ← 350 lines (order state machine — DUPLICATE, DEAD)
    order_status_engine.dart         ← 350 lines (order state machine — DUPLICATE, DEAD)
    delivery_assignment_service.dart ← 250 lines (assign riders to deliveries)
    gps_tracking_service.dart        ← 300 lines (location updates, offline queue)
    speech_to_text_service.dart      ← 200 lines (mic input, Hinglish parsing)
    referral_service.dart            ← 150 lines (code generation, redeem, payout)
    mfa_service.dart                 ← 200 lines (TOTP, SMS OTP, email OTP)
    security_event_service.dart      ← 250 lines (login, permission changes, sensitive ops)
    audit_service.dart               ← 300 lines (all admin actions logged)
    gemini_service.dart              ← 200 lines (chatbot, Business Analyst, voice parsing)
    smart_analytics_service.dart     ← 300 lines (churn, cohort, forecasting)
    ... (20+ more services)
  utils/
    validators.dart, formatters.dart, string_utils.dart, math_utils.dart
    pricing.dart (GST calc), routes.dart (old, app_router.dart is new)
  constants/
    colors.dart, strings.dart (en/hi), products.dart (20 dad products), app_config.dart
  navigation/
    app_router.dart                  ← 600 lines (GoRouter, 50+ routes)

android/
  app/
    build.gradle                     ← Kotlin Gradle Plugin (deprecated, Flutter migration needed)
    src/main/AndroidManifest.xml     ← 100 lines
    src/main/kotlin/...
  build.gradle, settings.gradle, gradle.properties

functions/ (Cloud Functions)
  src/
    index.ts                         ← 50 lines (exports all functions)
    runtime/
      metrics.ts                     ← 200 lines (daily/weekly stats)
      businessAnalyst.ts             ← 300 lines (Gemini AI narrative)
      scheduledAgentRunner.ts        ← 150 lines (cron jobs)
      chiefOfStaff.ts                ← 200 lines (morning brief)
      paymentWebhook.ts              ← 200 lines (Razorpay webhook)
      orderStatusSync.ts             ← 150 lines (sync order state to RDS)
      deadLetterRetry.ts             ← 150 lines (retry failed Firestore writes)
  .runtimeconfig.json                ← SECRETS (LEAKED, needs rotation)
```

### Code Quality Audit

**Dead Code (VERIFIED fixed by P0 sprint)**
- ✅ Deleted: `services/order_business_logic/`, `services/unified_order_service/`, `services/wallet_order_service/`, `services/consolidated_order_service/`, `services/coupon_discount_service/` + 2 backup files

**Duplicate / Conflicting Logic** (STILL OPEN)
- [ ] T-FE1.1: Merge `order_status_engine.dart` + `order_workflow_engine.dart` into single `OrderStateService`
- [ ] T-FE1.2: Merge `DeliveryAssignmentService` + GPS tracking logic into `DeliveryStateService`
- [ ] T-FE1.3: Remove old `routes.dart` (app_router.dart is canonical)

**Package Bloat**
- [ ] T-FE2.1: Remove unused packages (audit pubspec.yaml for unused imports)
- [ ] T-FE2.2: Pin versions (use `pub outdated`, update to latest stable)
- [ ] T-FE2.3: Check APK size (target < 50MB, currently unknown)

**Architecture Improvements**
- [ ] T-FE3.1: Move all Business Logic to `domain/` layer (clean architecture)
- [ ] T-FE3.2: Extract Firestore queries into repositories
- [ ] T-FE3.3: Add integration tests (flows: auth → cart → checkout)
- [ ] T-FE3.4: Standardize error handling (Result<T, Exception> instead of try-catch)

### Dependency Map (Critical Path)
```
main.dart
  ├─ AuthProvider → TrustedDeviceService, MfaService, AuditService, SecurityEventService
  ├─ CartProvider → ProductProvider, WalletProvider, CouponService, PricingUtils
  ├─ CheckoutProvider → RazorpayService, AddressService, OrderProvider
  ├─ OrderProvider → OrderStatusEngine (DUPLICATE), OrderWorkflowEngine (DUPLICATE), DeliveryAssignmentService
  ├─ ProductProvider → GeminiService (voice parsing), SmartAnalyticsService
  ├─ NotificationService → FCM, LocalNotifications, RDS sync
  └─ ReportProvider → SmartAnalyticsService, GeminiService (AI narratives)
```

### Refactoring Roadmap

**Phase 1 (Week 1):**
- Merge order engines, delivery services (reduce duplication)
- Remove unused packages, pin versions
- Update Kotlin Gradle Plugin (Flutter migration)

**Phase 2 (Week 2):**
- Extract domain layer (business logic)
- Add repository pattern (Firestore abstraction)
- Add integration tests

**Phase 3 (Week 3):**
- Standardize error handling (Result<T>)
- Add state machine logging/debugging
- Performance optimization (lazy loading, caching)

---

## TEAM 4: 🔥 FIREBASE ENGINEER — Backend Audit + Security Rules Overhaul

**Deliverable:** Firestore schema review, security rules complete audit, index requirements, seed data

### Firestore Schema Audit

**Collections Inventory**

| Collection | Docs | Schema Status | Security | Notes |
|------------|------|---------------|----------|-------|
| `users` | ~500 | ✅ v3 | ⚠️ Partial | Role RBAC, phone verified, device trusted |
| `products` | ~200 | ✅ v2 | ✅ Public read | 18% GST embedded, Hindi aliases |
| `orders` | ~1k | ✅ v2 | ⚠️ Needs review | Status enum, delivery link, timeline |
| `deliveries` | ~500 | ✅ v2 | ⚠️ Race condition | 3 services writing (not atomic) |
| `cart` | ~500 | ✅ v2 | ✅ User-only | Guest cart in AsyncStorage |
| `wallet` | ~500 | ✅ v2 | 🔴 BROKEN | No `wallet_transactions` rules |
| `coupons` | ~50 | ✅ v2 | ✅ Public read | Fixed zero-cap bug in code |
| `users/{uid}/approved_devices` | ~50 | ✅ v1 | ✅ User-only | Device trust after OTP |
| `users/{uid}/mfa_settings` | ~50 | ✅ v1 | ✅ User-only | TOTP backup codes |
| `users/{uid}/security_events` | ~200/user | ✅ v1 | ✅ User-only | Login, permission changes |
| `audit_log` | ~5k | ✅ v1 | ✅ Admin-only | All sensitive actions |
| `referrals` | ~100 | ✅ v1 | ✅ User-only | Ref code, redemption flag |
| `reports` | ~50 | ✅ v1 | ✅ Owner-only | Business Analyst narratives |
| `agent_runs` | ~200 | ✅ v1 | ✅ Owner-only | Gemini call history, KPIs |
| `dead_letter_queue` | ~20 | ✅ v1 | ✅ Admin-only | RDS sync failures, retried |

### Security Rules Audit

**Current State: 70% Complete**

✅ **Implemented:**
- Role-based access (customer, owner, rider, admin, supplier, staff)
- `users/{uid}/approved_devices` user-only read/create
- `products` public read, admin-only write
- `audit_log` admin-only read/write
- `orders/{docId}` user can read if `uid` in `participants`, owner can read all
- OTP throttling (5 attempts / 15 min, stored in user doc)

🔴 **Missing / Broken:**
- [ ] T-FB1.1: Add `users/{uid}/wallet_transactions` rules (user can create/read own)
- [ ] T-FB1.2: Restrict wallet balance write (decrease-only via Cloud Function)
- [ ] T-FB1.3: Add `deliveries/{docId}` write atomicity (Firestore transactions)
- [ ] T-FB1.4: Add `reports` read rule (owner + staff with report role)
- [ ] T-FB1.5: Add `coupons` campaign tracking (owner can create/edit, customer can read active)

### Rules Template (Ready to Deploy)

```yaml
# Firebase Security Rules (firestore.rules)
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    # Helper functions
    function isAuth() { return request.auth != null; }
    function isOwner(uid) { return request.auth.uid == uid; }
    function isAdmin() { return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin'; }
    function isOwnerOrAdmin() { return request.auth.token.role == 'owner' || isAdmin(); }
    
    # /users collection
    match /users/{document=**} {
      allow read: if isAuth() && (isOwner(document) || isAdmin());
      allow create: if isAuth() && isOwner(document) && request.resource.data.role in ['customer', 'owner', 'rider'];
      allow update: if isOwner(document) && !resource.data.role.differs(request.resource.data.role);
      allow delete: if false;
    }
    
    # /products collection (public read)
    match /products/{productId} {
      allow read: if true;
      allow write: if isAdmin();
    }
    
    # /orders collection (user can read own orders, owner can read all)
    match /orders/{orderId} {
      allow read: if isAuth() && (
        request.auth.uid in resource.data.participants ||
        isOwnerOrAdmin()
      );
      allow create: if isAuth();
      allow update: if isOwnerOrAdmin() || (isOwner(resource.data.uid) && resource.data.status in ['placed', 'confirmed']);
    }
    
    # /wallet & wallet_transactions (user-only, decrease-only for balance)
    match /users/{uid}/wallet_transactions/{txnId} {
      allow read, create: if isOwner(uid);
      allow update, delete: if false;
    }
    match /users/{uid} {
      allow update: if isOwner(uid) && (
        !request.resource.data.walletBalance.differs(resource.data.walletBalance) ||
        request.resource.data.walletBalance < resource.data.walletBalance
      );
    }
    
    # /approved_devices (user can manage own devices)
    match /users/{uid}/approved_devices/{deviceId} {
      allow read, create: if isOwner(uid);
      allow update: if isOwner(uid) && request.resource.data.approved == false; // Can only un-approve
      allow delete: if false; // Keep audit trail
    }
    
    # /audit_log (admin-only)
    match /audit_log/{logId} {
      allow read: if isAdmin();
      allow write: if false; // Written only by Cloud Functions
    }
    
    # /reports (owner/staff can read, admins write)
    match /reports/{reportId} {
      allow read: if isAuth() && (
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['owner', 'admin'] ||
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.staffRole == 'analytics'
      );
      allow write: if isAdmin();
    }
  }
}
```

### Firestore Indexes Required

- [ ] T-FB2.1: Create composite index on `orders` (uid, status, createdAt DESC)
- [ ] T-FB2.2: Create composite index on `orders` (ownerId, status, updatedAt DESC)
- [ ] T-FB2.3: Create composite index on `products` (category, price ASC, stock DESC)
- [ ] T-FB2.4: Create composite index on `users` (role, createdAt DESC)
- [ ] T-FB2.5: Create composite index on `audit_log` (uid, timestamp DESC)

### Sample Data Seed

```dart
// Top 20 dad-focused products (JSON seed)
[
  {
    "id": "prod_001",
    "name": "पापा का स्पेशल चश्मा",
    "nameEn": "Papa's Reading Glasses",
    "category": "accessories",
    "price": 599,
    "gst": 18,
    "stock": 50,
    "image": "https://...",
    "description": "Lightweight reading glasses with UV protection",
    "hindiAliases": ["चश्मा", "नेत्र चश्मा", "रीडिंग ग्लास"],
    "rating": 4.5,
    "reviews": 120,
    "dadJoke": "Dad joke about glasses..."
  },
  // ... 19 more products
]
```

---

## TEAM 5: 🛒 E-COMMERCE DEVELOPER — Cart, Checkout, Wallet Gaps

**Deliverable:** Cart logic audit, checkout flow fixes, wallet client-write removal, reorder feature

### Cart Flow Audit

**Current State: 95% Complete**

✅ **Working:**
- Add to cart (quantity +/-, real-time stock validation)
- Cart persistence (AsyncStorage + Firestore)
- Guest → Auth migration (on login, guest items merge)
- Quantity increment/decrement (stepper UI)
- Remove item (swipe, delete button)
- Cart count badge (real-time)
- Estimated delivery date
- Stock warnings

⚠️ **Needs Testing:**
- [ ] T-EC1.1: Test cart sync across devices (same user, two sessions)
- [ ] T-EC1.2: Test race condition (remove item while stock updates)

### Checkout Flow Audit

**Current State: 85% Complete**

✅ **Working:**
- Address selection + validation (geolocation check)
- Payment method selection (Razorpay UPI/Card/Netbanking)
- Wallet payment (once rules fixed)
- GST calculation (18% on all items, displayed separately)
- Order summary (items, GST, shipping, total)
- Place order (creates Firestore doc, updates inventory)

🔴 **Broken:**
- [ ] T-EC2.1: Wallet payment (Firestore rules block write — fix in T-W1.1)
- [ ] T-EC2.2: COD payment (implement risk check — order amount limit)

### Wallet Logic

**Current State: 60% (Broken)**

✅ **Implemented:**
- View balance (real-time Firestore stream)
- Transaction history (type, amount, date, balance)
- Referral redeem (auto-credit ₹50 on first order)

🔴 **Broken:**
- [ ] T-W1.1: wallet_transactions rules (add Firestore rule)
- [ ] T-W1.2: wallet balance server-side update (Cloud Function)
- [ ] T-W1.3: Quick-add funds (payment required)

**Fixes:**
```dart
// Cloud Function: addWalletCredits
export const addWalletCredits = functions.https.onCall(async (data, context) => {
  const { uid, amount, reason } = data;
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User not authenticated');
  if (amount <= 0) throw new functions.https.HttpsError('invalid-argument', 'Amount must be > 0');
  
  const db = admin.firestore();
  const batch = db.batch();
  const userRef = db.collection('users').doc(uid);
  const txnRef = userRef.collection('wallet_transactions').doc();
  
  batch.update(userRef, { walletBalance: FieldValue.increment(amount) });
  batch.set(txnRef, {
    type: reason, // 'topup_payment', 'referral_bonus', 'refund'
    amount,
    balance: FieldValue.arrayUnion([amount]), // Will be replaced by server value
    timestamp: FieldValue.serverTimestamp(),
  });
  
  await batch.commit();
  return { success: true, newBalance: amount };
});

// Update CheckoutProvider to call Cloud Function
Future<bool> addWalletFunds(double amount) async {
  try {
    final callable = FirebaseFunctions.instance.httpsCallable('addWalletCredits');
    final result = await callable({'amount': amount, 'reason': 'topup_payment'});
    _walletBalance = result.data['newBalance'].toDouble();
    notifyListeners();
    return true;
  } catch (e) {
    throw Exception('Failed to add funds: $e');
  }
}
```

### Reorder Feature

**Current State: 85%**

✅ **Implemented:**
- "Reorder" button on order detail screen
- Button routes to `/customer/cart` with items pre-populated
- User can modify quantities, address before checkout

### Subscription Products

**Status: 0% (Feature request)**

- [ ] T-EC3.1: Add `subscriptionType` field to Product model (one-time, weekly, monthly)
- [ ] T-EC3.2: Create `SubscriptionService` (manage active subs, pause/cancel)
- [ ] T-EC3.3: Create subscription dashboard screen (active, paused, history)
- [ ] T-EC3.4: Auto-refill logic (weekly/monthly recurring orders)

---

## TEAM 6: 💳 PAYMENT INTEGRATION SPECIALIST — Razorpay Audit + Fixes

**Deliverable:** Razorpay integration audit, webhook verification, test results, COD enforcement

### Razorpay Integration Audit

**Current State: 85% (Webhook broken)**

✅ **Implemented:**
- Create order → Razorpay API → generate order ID
- UPI intent flow (QR code + payment UI)
- Card payment (3D Secure)
- Netbanking
- Webhook listener (receiving events)
- Order status update on payment

🔴 **Broken:**
- [ ] T-PAY2.1: Webhook signature verification (key_secret == webhook_secret, both wrong)
- [ ] T-PAY2.2: Verify keys in Razorpay dashboard (not .runtimeconfig.json)

### Razorpay Setup (Verified)

```
Live Mode (Production):
  - Key ID: razorpay_key_id
  - Key Secret: razorpay_key_secret (NOT webhook_secret)
  - Webhook Secret: razorpay_webhook_secret (different from key_secret)
  - Webhook URL: https://us-central1-fufajis-online.cloudfunctions.net/paymentWebhook
  - Events: payment.authorized, payment.failed, refund.created
  
Test Mode:
  - Can use Razorpay's test cards (4111111111111111)
```

### Webhook Fix

```typescript
// functions/src/runtime/paymentWebhook.ts
export const paymentWebhook = functions.https.onRequest(async (req, res) => {
  const signature = req.headers['x-razorpay-signature'] as string;
  const body = req.rawBody; // Raw body for signature verification
  
  const webhookSecret = functions.config().razorpay.webhook_secret; // From SECRET MANAGER
  const hash = crypto
    .createHmac('sha256', webhookSecret)
    .update(body)
    .digest('hex');
  
  if (hash !== signature) {
    console.error('Invalid signature');
    res.status(401).send('Unauthorized');
    return;
  }
  
  const event = JSON.parse(body);
  const { id: paymentId, entity, status, ...rest } = event.payload[entity];
  
  if (entity === 'payment' && status === 'authorized') {
    await admin.firestore().collection('orders')
      .where('razorpayOrderId', '==', event.payload.payment.order_id)
      .limit(1)
      .get()
      .then(snap => {
        if (!snap.empty) {
          snap.docs[0].ref.update({ paymentStatus: 'completed', updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        }
      });
  }
  
  res.status(200).send('OK');
});
```

### COD Enforcement

**Current State: 0% (Implemented in code, not enforced)**

```dart
// Add to CheckoutProvider.selectPaymentMethod()
if (paymentMethod == 'cod') {
  const codLimit = 5000; // ₹5000 COD limit
  final userCodOrders = await _firestore
    .collection('orders')
    .where('uid', isEqualTo: _auth.currentUser?.uid)
    .where('paymentMethod', isEqualTo: 'cod')
    .where('createdAt', isGreaterThan: DateTime.now().subtract(Duration(days: 30)))
    .get();
  
  final totalCodOrders = userCodOrders.docs.fold(0.0, (sum, doc) => sum + (doc['total'] as num));
  
  if (cartTotal + totalCodOrders > codLimit) {
    throw Exception('COD limit exceeded (₹5000/month). Use UPI or Wallet.');
  }
}
```

### Payment Test Checklist

- [ ] T-PAY3.1: Fix webhook secret in Razorpay dashboard
- [ ] T-PAY3.2: Test UPI payment (use Razorpay test app or QR code)
- [ ] T-PAY3.3: Test card payment (4111111111111111, any future date, any CVV)
- [ ] T-PAY3.4: Test COD order (limit check, order marked for cash pickup)
- [ ] T-PAY3.5: Test refund (cancel order → Razorpay → refund processed)
- [ ] T-PAY3.6: Verify webhook fires (order status updated in Firestore)

### Stripe Removal (VERIFIED)

- ✅ Stripe code deleted from codebase (commit 9b9d650)
- Razorpay is sufficient for India (UPI primary)

---

## TEAM 7: 🧪 QA ENGINEER — Test Coverage Audit + Missing Tests

**Deliverable:** Test suite inventory, coverage report, missing test cases, CI/CD setup

### Test Suite Inventory

**Unit Tests**
- `test/services/pricing_test.dart` ✅ (GST calc)
- `test/services/referral_service_test.dart` ✅ (code generation)
- `test/utils/validators_test.dart` ✅ (phone, email, OTP)
- `test/models/order_model_test.dart` ⚠️ (incomplete)

**Widget Tests**
- `test/widgets/product_card_test.dart` ✅
- `test/widgets/cart_badge_test.dart` ✅
- `test/screens/home_screen_test.dart` ⚠️ (needs data mocking)

**Integration Tests**
- `test/flows/checkout_flow_test.dart` ❌ (missing)
- `test/flows/referral_flow_test.dart` ❌ (missing)

**Cloud Function Tests**
- `functions/__tests__/paymentWebhook.test.ts` ✅
- `functions/__tests__/businessAnalyst.test.ts` ⚠️ (Gemini mocking incomplete)

### Coverage Report

```
services/pricing.dart              95%
services/referral_service.dart     85%
utils/validators.dart              90%
models/                            60%
screens/customer/                  40%
screens/owner/                     30%
providers/                         50%
```

**Target: 80% overall, 90% on critical paths (auth, payment, order)**

### Missing Tests (P1)

- [ ] T-QA1.1: Checkout flow end-to-end (add cart → address → payment → order created)
- [ ] T-QA1.2: Wallet payment flow (add funds → use in checkout)
- [ ] T-QA1.3: Referral redemption (first order triggers payout)
- [ ] T-QA1.4: Order cancellation (fee applied, refund processed)
- [ ] T-QA1.5: Delivery assignment (order → rider → GPS tracking)
- [ ] T-QA1.6: Voice order parsing (Hinglish text → cart items)

### CI/CD Pipeline

```yaml
# .github/workflows/test.yml
name: Test & Build

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      - run: flutter pub get
      - run: flutter test --coverage
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
  
  build:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build apk --release
      - name: Upload APK
        uses: actions/upload-artifact@v3
        with:
          name: app-release.apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

---

## TEAM 8: 🔒 SECURITY ENGINEER — CRITICAL AUDIT + RECOVERY PLAN

**Deliverable:** Full security audit report, vulnerability fixes, incident response runbook

### 🚨 SECURITY INCIDENT SUMMARY (2026-06-21)

**Severity: CRITICAL (Red)**  
**Readiness Score: 28/100**  
**Status: Active Breach (Secrets Compromised)**

### Vulnerabilities Identified

| ID | Vulnerability | Severity | Status | Fix |
|----|---|---|---|---|
| S1 | Public GitHub repo with live secrets | 🔴 CRITICAL | OPEN | Make private, rotate all, purge history |
| S2 | .env asset in APK (leaks credentials) | 🔴 CRITICAL | OPEN | Remove from pubspec, use --dart-define |
| S3 | Signing key public (keystore_base64.txt) | 🔴 CRITICAL | OPEN | Regenerate keystore, revoke old key |
| S4 | Razorpay key_secret == webhook_secret | 🔴 CRITICAL | OPEN | Fix in Razorpay dashboard |
| S5 | functions.config() (deprecated) | 🟠 HIGH | OPEN | Migrate to Firebase Secret Manager |
| S6 | OTP rate limiting (5/15min, low) | 🟠 HIGH | DONE | Implemented 5×15min throttle |
| S7 | Firestore rules incomplete | 🟠 HIGH | PARTIAL | Add wallet rules, delivery atomicity |
| S8 | No HTTPS certificate pinning | 🟡 MEDIUM | N/A | Low priority for Android |
| S9 | No ProGuard obfuscation | 🟡 MEDIUM | PENDING | Enable for release build |
| S10 | Analytics data unencrypted (Firestore) | 🟡 MEDIUM | N/A | Firestore encryption at rest (default) |

### EMERGENCY LOCKDOWN (Phase 1 — 24 hours)

**Action: Make repo private + rotate secrets**

```bash
# 1. GitHub Dashboard (Gaurav must do)
# Settings → Danger Zone → Change repository visibility → Private

# 2. Rotate Razorpay keys (Razorpay Dashboard)
# Razorpay → Settings → API Keys → Regenerate Key ID & Secret

# 3. Rotate Twilio credentials (Twilio Console)
# Account → Auth Tokens → Create New Auth Token → Delete old

# 4. Rotate Gemini API key (Google Cloud Console)
# APIs & Services → Credentials → Delete old key, create new

# 5. Rotate Supabase API key (Supabase Dashboard)
# Project Settings → API → Regenerate

# 6. Rotate AWS credentials (IAM Console)
# Users → <user> → Security Credentials → Create new access key

# 7. Rotate Upstash Redis token (Upstash Console)
# Databases → <db> → Details → Rotate auth token

# 8. Rotate GitHub secrets (.github/settings)
# Secrets and variables → Update all with new credentials

# 9. Purge git history (DANGEROUS, requires force-push)
git filter-repo --invert-paths --path 'functions/.runtimeconfig.json'
git filter-repo --invert-paths --path 'scripts/setup_functions_config.bat'
git filter-repo --invert-paths --path 'keystore_base64.txt'
git filter-repo --invert-paths --path '.env'
git push --force-with-lease

# 10. Remove .env asset from pubspec.yaml
# Delete lines: "  - .env" (lines 6 & 145)
```

### SECRET MIGRATION (Phase 2 — Firebase Secret Manager)

```bash
# 1. Create Firebase Secrets (Firebase Console → Secret Manager)
firebase secrets:set RAZORPAY_KEY_SECRET
firebase secrets:set RAZORPAY_WEBHOOK_SECRET
firebase secrets:set TWILIO_ACCOUNT_SID
firebase secrets:set TWILIO_AUTH_TOKEN
firebase secrets:set GEMINI_API_KEY
firebase secrets:set SUPABASE_S3_ACCESS_KEY
firebase secrets:set SUPABASE_S3_SECRET_KEY
firebase secrets:set UPSTASH_REDIS_TOKEN
firebase secrets:set AWS_ACCESS_KEY_ID
firebase secrets:set AWS_SECRET_ACCESS_KEY

# 2. Grant Cloud Functions access to secrets
gcloud projects add-iam-policy-binding fufajis-online \
  --member=serviceAccount:fufajis-online@appspot.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor

# 3. Update functions/src/index.ts
import { defineSecret } from 'firebase-functions/params';

export const razorpayKeySecret = defineSecret('RAZORPAY_KEY_SECRET');
export const razorpayWebhookSecret = defineSecret('RAZORPAY_WEBHOOK_SECRET');

// In function:
export const paymentWebhook = functions.https.onRequest(
  {
    secrets: [razorpayWebhookSecret],
  },
  async (req, res) => {
    const webhookSecret = razorpayWebhookSecret.value();
    // ... use webhookSecret
  }
);

# 4. Redeploy functions
firebase deploy --only functions
```

### CODE HARDENING (Phase 3)

- [ ] T-S2.1: Add ProGuard obfuscation to `android/app/build.gradle` (release builds)
- [ ] T-S2.2: Add HTTPS certificate pinning (Dio interceptor)
- [ ] T-S2.3: Sanitize all user inputs (prevent injection attacks)
- [ ] T-S2.4: Add brute-force protection to login (Firebase App Check)
- [ ] T-S2.5: Encrypt sensitive data at rest (Hive encryption)
- [ ] T-S2.6: Add security event logging (DeviceSecurityService)

### Security Checklist (Pre-Launch)

- [ ] Repository is PRIVATE ✅
- [ ] All secrets rotated ✅
- [ ] Git history cleaned ✅
- [ ] .env asset removed ✅
- [ ] Signing key regenerated ✅
- [ ] Firestore rules deployed ✅
- [ ] Cloud Functions use defineSecret() ✅
- [ ] No console.log(secrets) in code ✅
- [ ] ProGuard enabled (release) ✅
- [ ] OWASP Top 10 checklist passed ✅

---

## TEAM 9: 📦 DEVOPS ENGINEER — APK Build + Play Store Readiness

**Deliverable:** EAS build config, version management, Play Store listing, APK size optimization

### Build Configuration

```yaml
# eas.json
{
  "build": {
    "preview": {
      "android": {
        "buildType": "apk"
      }
    },
    "preview2": {
      "android": {
        "gradleCommand": ":app:assembleRelease"
      }
    },
    "preview3": {
      "builds": {
        "android": {
          "buildType": "apk"
        }
      }
    },
    "production": {
      "android": {
        "buildType": "app-bundle"
      }
    }
  }
}
```

### Versioning

```dart
// pubspec.yaml
version: 1.0.0+1  // semver+build number

// app.json
{
  "expo": {
    "name": "Fufaji Store",
    "slug": "fufaji-store",
    "version": "1.0.0",
    "orientation": "portrait",
    "icon": "./assets/icon.png",
    "splash": {
      "image": "./assets/splash.png",
      "resizeMode": "contain",
      "backgroundColor": "#1A5276"
    },
    "android": {
      "versionCode": 1,
      "package": "com.fufaji.online",
      "permissions": ["INTERNET", "ACCESS_FINE_LOCATION", "CAMERA", "READ_EXTERNAL_STORAGE"]
    }
  }
}
```

### Play Store Assets

**Required:**
- 1024×1024 app icon (PNG)
- Feature graphic 1024×500 (PNG)
- 6 screenshots 1080×1920 (PNG/JPEG)
- Short description (80 chars): "Dad-focused grocery & essentials delivery"
- Full description (4000 chars): [See below]
- Privacy policy URL: https://fufaji.app/privacy
- Terms URL: https://fufaji.app/terms

**Listing Template**

```
Title (50 chars):
Fufaji Store - Dad's Online Grocery

Short Description (80 chars):
Dad-focused grocery & essentials delivery in India

Full Description (4000 chars):
Welcome to Fufaji Store, the grocery delivery app designed for the modern Indian dad!

✨ Features:
• 200+ dad-approved products (groceries, essentials, gifts)
• Voice ordering (Hinglish support — just say what you want!)
• Real-time tracking with GPS
• Multiple payment options (UPI, Cards, Netbanking, Wallet)
• Referral rewards (₹50 per friend)
• 24/7 support with AI assistant

🛒 How it works:
1. Sign up with phone number
2. Browse products or use voice search
3. Add to cart & checkout
4. Pay via Razorpay (UPI recommended)
5. Track delivery in real-time
6. Rate & review

👨‍🍳 Why Dads Love Fufaji:
• Curated for daily essentials
• Simple, no-fuss interface
• Hindi & English support
• Quick delivery (2-4 hours)
• Best prices guaranteed

🎁 Special Features:
• Refer friends, earn ₹50 per referral
• Subscription discounts on staples
• Father's Day special products
• Gift wrapping for occasions

📱 Requirements:
• Android 8.0+
• 50MB storage
• Internet connection

❓ Support:
In-app chat, email, or call 1800-FUFAJI-1

Privacy & Security:
We never share your data. Your location is used only for delivery.
Payment info is encrypted & handled by Razorpay.

---

Rating & Review:
⭐ Loved the app? Please rate & review!
📧 Feedback: support@fufaji.app

Fufaji Store © 2026. All rights reserved.
```

### APK Size Optimization

- [ ] T-DEV1.1: Remove unused Android resources (gradlew :app:bundleRelease --analytic)
- [ ] T-DEV1.2: Enable R8 minification (build.gradle: minifyEnabled true)
- [ ] T-DEV1.3: Prune unused dependencies (pubspec.yaml audit)
- [ ] T-DEV1.4: Use WebP images (PNG → WebP conversion)
- [ ] T-DEV1.5: Split APK by ABI (reduce from ~60MB to ~30MB per variant)

**Target: < 50MB uncompressed**

### CI/CD Deployment

```yaml
# .github/workflows/deploy.yml
name: Deploy to Play Store

on:
  push:
    tags:
      - v*

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter build apk --release
      - name: Upload to Play Console
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJson: ${{ secrets.PLAY_STORE_SA_JSON }}
          packageName: com.fufaji.online
          releaseFiles: build/app/outputs/flutter-apk/app-release.apk
          track: internal
          status: inProgress
```

### Play Store Setup Checklist

- [ ] T-DEV2.1: Create Google Play Developer account ($25 one-time)
- [ ] T-DEV2.2: Create app on Play Console (com.fufaji.online)
- [ ] T-DEV2.3: Upload assets (icon, screenshots, descriptions)
- [ ] T-DEV2.4: Set up app signing (Play Console manages keystore)
- [ ] T-DEV2.5: Create Service Account JSON (GitHub Secrets)
- [ ] T-DEV2.6: Submit for review (internal → beta → production track)
- [ ] T-DEV2.7: Verify app policies (privacy, content rating, target audience)

### Release Checklist

Before every APK release:
- [ ] Version bump (pubspec.yaml + app.json)
- [ ] Changelog update (`CHANGELOG.md`)
- [ ] Git tag (`git tag v1.0.0`)
- [ ] Build APK locally (test on device)
- [ ] Push tag to trigger CI/CD
- [ ] Monitor Play Store submission status

---

## TEAM 10: 🤖 TEAM LEAD — FINAL ORCHESTRATION + MASTER TASK LIST

**Deliverable:** Consolidated task list (200+ items), execution roadmap, dependency map, final verification

### Master Task List by Priority

#### CRITICAL PATH (Phase 0 — MUST FIX BEFORE ANYTHING)

**Emergency Security (24 hours)**
```
S1. Make GitHub repo private (Gaurav dashboard) [BLOCKER]
S2. Rotate ALL secrets (24 keys) [BLOCKER]
S3. Purge git history [BLOCKER]
S4. Remove .env from pubspec + main.dart [BLOCKER]
S5. Regenerate Android signing keystore [BLOCKER]
```

**P0 Bugs (72 hours)**
```
W1. Fix wallet_transactions Firestore rules [BLOCKER for checkout]
W1b. Implement server-side wallet credit Cloud Function [BLOCKER]
W2. Verify percentage coupon zero-cap fix [QUICK VERIFY]
D1. Merge delivery services (GPS + assignment) [RACE CONDITION]
PAY1. Fix Razorpay webhook secret [BROKEN WEBHOOKS]
```

#### PHASE A: Core Features (Week 1)

```
PM1.1-1.6: Email, SMS, COD, RMA, Payout, Signup features
FB1.1-1.5: Complete Firestore rules deployment
FE1.1-1.3: Merge duplicate order/delivery logic
QA1.1-1.6: Add critical integration tests
S2.1-2.6: Security hardening (ProGuard, sanitization, logging)
PAY3.1-3.6: Razorpay webhook testing
```

#### PHASE B: UX & Analytics (Week 2)

```
UX1.1-1.6: Missing customer screens (signup, address, subscriptions)
UX2.1-2.5: Owner portal screens (inventory, payout, campaigns)
PM2.1-2.6: Gamification, inventory alerts, SLA tracking
```

#### PHASE C: Play Store Launch (Week 3)

```
DEV1.1-1.5: APK size optimization
DEV2.1-2.7: Play Store setup & submission
QA Coverage: 80% test coverage verification
Final audit: Security, performance, UX polish
```

### Execution Roadmap

```
Day 1 (2026-07-03):
  08:00 — Audit started (this document)
  09:00 — Emergency lockdown begin (S1-S5)
  12:00 — All secrets rotated
  15:00 — Repo private, git history cleaned
  18:00 — Code: wallet rules, Razorpay fix merged

Day 2 (2026-07-04):
  09:00 — Deploy Firebase rules
  11:00 — Test checkout flow (wallet)
  14:00 — Merge delivery services (D1)
  17:00 — Run full test suite, coverage report
  19:00 — Security hardening (ProGuard, sanitization)

Day 3 (2026-07-05):
  09:00 — Implement email/SMS services
  14:00 — Implement COD limits, RMA workflow
  18:00 — Test all P1 checkout flows

Week 2 (2026-07-08):
  — Build missing customer screens
  — Build missing owner screens
  — Depth analytics (churn, cohort, forecasting)
  — Subscription product support

Week 3 (2026-07-15):
  — APK size optimization
  — Play Store assets + listing
  — Final security audit
  — Submit to Play Store internal track

Week 4 (2026-07-22):
  — Beta track (external testers)
  — Collect feedback, fix issues
  — Production submission
```

### Dependency Matrix

```
S1-S5 (Security)
  ↓
W1, W1b, D1, PAY1 (P0 bugs)
  ↓
PM1.* (Core features)
  ↓
FB1.* (Firestore completion)
  ↓
QA1.* (Test coverage)
  ↓
S2.* (Hardening)
  ↓
UX1.*, UX2.* (Polish)
  ↓
DEV1.*, DEV2.* (Launch)
```

### Risk Assessment

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|-----------|
| Secrets still compromised (incomplete rotation) | CRITICAL | LOW | Checklist-driven, peer-verified |
| Wallet payment still broken | HIGH | MEDIUM | Cloud Function testing, manual QA |
| Delivery race condition persists | HIGH | MEDIUM | Atomic Firestore transactions |
| Razorpay webhook never fires | MEDIUM | LOW | Signature verification test |
| Play Store rejection (content policy) | MEDIUM | LOW | Legal review of copy, privacy policy |
| APK > 50MB (too large) | LOW | MEDIUM | WebP conversion, lib pruning |
| Insufficient test coverage | MEDIUM | HIGH | Daily coverage reports, CI gate |

### Team Coordination

- **Product Manager** (Gaurav) — Task approval, feature prioritization, decisions
- **10 AI Roles** — Execute assigned tasks in parallel where possible
- **Daily Standup** — 3pm IST (async update if unavailable)
- **Blocker Resolution** — Immediate escalation
- **Quality Gate** — All tasks must have passing tests before merge

### Final Verification Checklist (Pre-Launch)

```
✅ FUFAJI STORE — FINAL LAUNCH CHECKLIST
==========================================

SECURITY (Phase 0):
[ ] Repo is PRIVATE
[ ] All secrets rotated (24 keys)
[ ] Git history purged
[ ] .env asset removed
[ ] Signing key regenerated
[ ] Secret Manager configured
[ ] Firestore rules deployed
[ ] Cloud Functions using defineSecret()
[ ] No hardcoded secrets in code

P0 BUGS (Phase 0):
[ ] Wallet payment working (rules + CF)
[ ] Percentage coupons correct
[ ] Delivery services merged
[ ] Razorpay webhook verified
[ ] Navigation Rail routing correct

CORE FEATURES (Phase A):
[ ] Email service (SendGrid)
[ ] SMS broadcast (Twilio)
[ ] COD limits enforced
[ ] RMA workflow complete
[ ] Payout auto-settlement
[ ] Signup flow polished
[ ] All P1 screens implemented

TESTING (Phase B):
[ ] Unit test coverage ≥ 90%
[ ] Integration tests pass (checkout, referral, order)
[ ] E2E tests pass (full customer journey)
[ ] Performance tests pass (< 3s page load)
[ ] Security tests pass (OWASP)

PLAY STORE (Phase C):
[ ] APK size < 50MB
[ ] Play Console setup complete
[ ] Assets uploaded (icon, screenshots)
[ ] Listing approved by legal
[ ] Privacy policy published
[ ] Internal track submission passes
[ ] Beta testers recruited
[ ] Production track approved

FINAL:
[ ] No critical bugs in beta
[ ] Crash rate < 0.1%
[ ] User feedback positive
[ ] All metrics green (performance, security)
[ ] Team sign-off on readiness
[ ] LAUNCH 🚀
```

---

## EXECUTION TIMELINE

| Phase | Duration | Tasks | Owner | Gate |
|-------|----------|-------|-------|------|
| 0 (Security) | 1 day | S1-S5 | Gaurav + Team | All merged & deployed |
| A (P0s + Core) | 3 days | W1*, D1, PAY1, PM1.*, FB1.*, S2.* | Team | QA Pass |
| B (UX + Analytics) | 7 days | UX1.*, UX2.*, PM2.* | Team | Coverage ≥ 80% |
| C (Launch) | 7 days | DEV1.*, DEV2.*, Final Audit | Team | Play Store Approved |

**Total: ~3 weeks to production launch**

---

## 📊 KEY METRICS (Success Criteria)

- **Security:** 0 critical vulnerabilities (Phase 0 gate)
- **Availability:** 99.5% uptime (Firebase SLA)
- **Performance:** Page load < 3s, API response < 500ms
- **Quality:** Test coverage ≥ 80%, crash rate < 0.1%
- **User Satisfaction:** 4.5+ star rating (Play Store)
- **Business:** ₹100K GMV in first month, 10K DAU in Month 3

---

## NEXT IMMEDIATE ACTIONS (TODAY)

1. ✅ Read this document (done)
2. ⏳ **Gaurav: Make repo private** (GitHub dashboard)
3. ⏳ **Gaurav: Start secret rotation** (Razorpay, Twilio, Gemini, Supabase, AWS, Upstash)
4. ⏳ **Claude: Implement S1-S5 code fixes**
5. ⏳ **Claude: Implement W1, D1, PAY1 P0 fixes**
6. ⏳ **Both: Daily standup at 3pm IST**

---

**Document Owner:** Team Lead (AI)  
**Last Updated:** 2026-07-02  
**Status:** ACTIVE — Ready for execution  
**Readiness:** 28/100 → Target 95/100 in 21 days
