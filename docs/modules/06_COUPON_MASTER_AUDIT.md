# Module 6: Coupon Facilities — Master Implementation + Audit

Part of the 17-module Fufaji Store facility audit series. Status: **audit complete, no fixes applied yet.** Findings below are confirmed by reading live code (`lib/models/coupon.dart`, `lib/providers/cart_provider.dart`, `lib/providers/admin_provider.dart`, `lib/screens/admin/coupon_management_screen.dart`, `lib/screens/customer/checkout_screen.dart`, `lib/services/billing_service.dart`, `lib/models/automation_rule_model.dart`, `lib/screens/owner/automation_rules_screen.dart`, `lib/services/rbac_service.dart`, `firestore.rules`), not assumed.

## 1. Business Requirements

Coupons let the shop run percentage or flat-amount discount promotions, gated by minimum order value, a date-active window, and (by name only — "FIRST20") first-order eligibility. Owners create/delete coupons from an admin screen; customers redeem a code at checkout. There is no requirement document — behavior below is reverse-engineered from code.

## 2. User Workflow

**Owner:** `CouponManagementScreen` → "Add Coupon" dialog → choose name, code, discount type (dropdown: *Percentage* or *Fixed Amount*), value, min order, max discount, dates → `AdminProvider.createCoupon` → `Coupon.toMap()` written to Firestore `coupons` collection. Delete is a direct `doc(couponId).delete()`.

**Customer:** types a code in `cart_screen.dart` or `checkout_screen.dart` → `CartProvider.applyCouponDynamic(code)` → Firestore query `coupons` where `code == X && isActive == true` → if found, validates date window + minimum order in-app → builds a local `Coupon` object → discount applied to `cartProvider.discount`, shown in the cart UI and folded into `BillingService.calculateBill`'s `couponDiscount` param at checkout.

## 3. UI Screens

- `coupon_management_screen.dart` (owner/admin) — grid of active coupons, create dialog, delete.
- `cart_screen.dart` — coupon code text field, "applied" chip showing code + computed discount.
- `checkout_screen.dart` — re-reads `cartProvider.discount` into the bill, no independent coupon UI.
- No customer-facing "available coupons" browse/list screen exists — a customer must already know a code.

## 4. Backend Architecture

No dedicated `CouponService` or `CouponProvider` exists. Logic is split across: `Coupon` model (`lib/models/coupon.dart`, holds `calculateDiscount`), `AdminProvider` (admin CRUD, `lib/providers/admin_provider.dart`), `CartProvider` (customer-side fetch + validate + apply, `lib/providers/cart_provider.dart`), and `BillingService.calculateBill` (folds the already-computed discount into the bill total, `lib/services/billing_service.dart`). All four touch coupon data independently; none calls another.

## 5. Database Schema

Firestore `coupons/{id}`: `code, name, description, discountType ('percentage'|'flat' per the model, but the only UI writes 'percentage'|'fixed'), discountValue, minimumOrderAmount, maximumDiscountAmount, startDate, endDate, isActive`. No `usageLimit`, `perUserLimit`, `usedCount`, or redemption-log collection exists anywhere in the schema. `OrderModel` (`lib/models/order_model.dart`) has only a generic `discount` field — no `couponCode` field — and, confirmed below, that field is never populated from checkout anyway.

## 6. Service Layer

`AdminProvider.fetchCoupons/createCoupon/deleteCoupon` — thin Firestore CRUD wrappers, no validation (no duplicate-code check, no date-range sanity check, no permission check before the Firestore call — see §9). `CartProvider.applyCouponDynamic` — Firestore lookup with in-app date/minimum-order validation, builds its own `Coupon` instance from raw map data rather than calling `Coupon.fromMap`, then falls back to `applyCoupon` (hardcoded SAVE10/FIRST20) on any failure, including a caught exception from a failed Firestore call. `Coupon.calculateDiscount` — pure function, never called by `CartProvider` (`CartProvider.discount` getter calls it once at line 38, confirmed below in finding 1) for the *Firestore-sourced* coupon, since `applyCouponDynamic` constructs its `Coupon` and the getter then calls `calculateDiscount` on it generically regardless of source.

## 7. Integration Points

- **Checkout:** `cartProvider.discount` → `BillingService.calculateBill(couponDiscount: ...)` → folded into `grandTotal`/`totalAmount`. One-way; nothing flows back.
- **Orders:** confirmed below (finding 3) that the resulting `OrderModel` never records the coupon code or discount amount — the only trace of a coupon ever having been used is implicitly baked into `totalAmount`.
- **Marketing automation:** `AutomationActionType.applyCoupon` exists as a configurable action in `automation_rules_screen.dart` (owner can set a discount % on a rule) — confirmed orphaned, see finding 4.
- **RBAC:** `Permission.manageCoupons` exists in `permission_model.dart`/`rbac_service.dart` — confirmed unused by any coupon code path, see finding 5.

## 8. Automation

None functions end-to-end. `autoOptimizeCoupons` (cart-side "Smart Coupon Optimizer") only compares 2 hardcoded codes rather than real Firestore coupons (carried forward from Module 5 finding 5). The marketing-rule `applyCoupon` action (§7) has no execution engine at all.

## 9. Security

No app-level permission check gates `AdminProvider.createCoupon`/`deleteCoupon`, despite `Permission.manageCoupons` existing for exactly this purpose. Enforcement, if any, would have to come from `firestore.rules` — confirmed below (finding 2) that no rule for the `coupons` collection exists there either, and the rules file has no trailing database-wide catch-all, so Firestore's default-deny should apply to all reads/writes against `coupons`.

## 10. Failure Cases

`applyCouponDynamic`'s catch-all swallows *any* Firestore exception — including a permission-denied error — and silently falls back to the 2 hardcoded codes, logging only a debug print. A customer typing a real, valid promotional code would see "invalid coupon" behavior (silently becomes a no-op unless the code happens to be SAVE10/FIRST20) with no diagnostic surfaced to the user or to any error-tracking system.

## 11. Testing

No test file references `coupon` anywhere in the repo (grep across `lib/` found only the model, the two providers, the management/cart/checkout screens, and the unrelated `campaign_model.dart`/`automation_rule_model.dart`). Zero unit coverage on `Coupon.calculateDiscount`, zero integration coverage on the Firestore round-trip.

## 12. Production Readiness

Not production-ready: the discount-type vocabulary mismatch (finding 1) means half of all coupons an owner can create silently apply ₹0 discount; the missing security rule (finding 2) likely blocks the feature entirely today, masked by a fallback that was designed for "offline/demo," not for "the collection has no access rule"; and finding 3 means even a working coupon leaves no audit trail on the order.

---

## Final Output Format

### Current State Audit
A coupon feature exists end-to-end at the UI level (create, list, delete, apply, see discount) but has never been verified to actually move money correctly in production, because no test exists and the one component that would prove it (the `coupons` Firestore rule) is missing.

### Missing Components
`CouponService`/`CouponProvider` (currently split across 4 uncoordinated places); a `coupons` Firestore security rule; an `OrderModel.couponCode` field and the write path to populate it; usage-limit/redemption-tracking schema and enforcement; an execution engine for `AutomationActionType.applyCoupon`; any test coverage.

### Architecture Design
Consolidate into a single `CouponService` exposing `validateAndApply(code, subtotal, customerId)` (used by both `CartProvider` and any future automation executor) and `create/update/delete` (used by `AdminProvider`, gated by `Permission.manageCoupons`). Standardize on one discount-type vocabulary end-to-end. Add `couponCode` + `couponDiscountAmount` to `OrderModel`, written by `OrderService.createOrder`. Add a `coupons/{id}.usedCount` + a `coupon_redemptions/{orderId}` ledger doc, incremented transactionally inside `OrderService.createOrder` alongside the existing stock-deduction transaction (same module/file already doing transactional writes — natural integration point per Module 5's findings).

### Implementation Plan
1. **P0 — add the missing `firestore.rules` entry for `coupons`** (read: any signed-in user; write: `isGlobalAdmin()` only, matching the `manageCoupons` permission's intent). Deploy and re-verify `applyCouponDynamic` actually reaches Firestore rather than silently falling back.
2. **P0 — fix the discount-type mismatch.** Either change the admin dialog's dropdown value from `'fixed'` to `'flat'`, or change `Coupon.calculateDiscount`'s check from `'flat'` to also accept `'fixed'`. Audit any existing `coupons` documents already written with `'fixed'` and backfill.
3. **P1 — add `couponCode`/`couponDiscountAmount` to `OrderModel`** and wire `checkout_screen.dart`'s `OrderModel(...)` construction (currently missing a `discount:`/coupon field entirely) to populate them from `billing.discount` and `cartProvider.appliedCoupon?.code`.
4. **P1 — add a permission check** (`Permission.manageCoupons` via `rbac_service.dart`) to `AdminProvider.createCoupon`/`deleteCoupon` before the Firestore call, not just relying on the rules file.
5. **P2 — add usage-limit schema + transactional increment** in `OrderService.createOrder`, including a per-customer check for codes like `FIRST20` that claim first-order-only eligibility but currently enforce nothing.
6. **P2 — delete or wire `AutomationActionType.applyCoupon`** — currently configurable in the owner UI with zero execution engine.
7. **P3 — replace `autoOptimizeCoupons`'s hardcoded 2-code comparison** with a real query over active Firestore coupons (carried from Module 5 finding 5).

### File-by-file Changes
- `firestore.rules` — add `match /coupons/{couponId}` block.
- `lib/models/coupon.dart` — reconcile `'flat'`/`'fixed'`; add `usedCount`/`usageLimit`/`perUserLimit` fields.
- `lib/screens/admin/coupon_management_screen.dart` — fix dropdown value or rely on the model fix.
- `lib/providers/admin_provider.dart` — add permission check in `createCoupon`/`deleteCoupon`.
- `lib/models/order_model.dart` — add `couponCode`, `couponDiscountAmount` fields + map serialization.
- `lib/screens/customer/checkout_screen.dart` — pass new fields into `OrderModel(...)`.
- `lib/services/order_service.dart` — transactional usage-count increment + redemption ledger write inside `createOrder`.
- `lib/providers/cart_provider.dart` — surface real errors instead of silently swallowing them in `applyCouponDynamic`; replace `autoOptimizeCoupons`'s static list.
- New: `lib/services/coupon_service.dart` consolidating validate/apply/create/delete; new `coupon_redemptions` collection.

### Production Checklist
- [ ] `coupons` Firestore rule deployed and verified (no silent fallback masking permission-denied)
- [ ] Single discount-type vocabulary used by model, admin UI, and any seed/migration data
- [ ] Orders persist `couponCode` + discount amount
- [ ] Coupon create/delete gated by `Permission.manageCoupons` in app code, not rules-only
- [ ] Usage-limit / first-order enforcement backed by real data, not just a coupon's display name
- [ ] `AutomationActionType.applyCoupon` either wired to a real executor or removed from the UI
- [ ] At least minimal unit tests on `calculateDiscount` and an integration test on `applyCouponDynamic`
