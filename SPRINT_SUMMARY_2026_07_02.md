# Sprint Summary — 2026-07-02 (Full-App P0 Fix Sprint)

Role: architect + auditor + engineer across the whole app, money-flow first
(ORDER + PAYMENT + INVENTORY). Every finding below was re-verified against
current code before fixing — several audit items turned out to be already
fixed, and two brand-new P0s were found during verification.

## Files changed

| File | Change |
|---|---|
| `lib/models/coupon.dart` | 'fixed'→'flat' normalization; cap≤0 means no-cap (was zeroing ALL percentage coupons); flat discount capped at subtotal |
| `lib/screens/customer/checkout_screen.dart` | Orders now persist `discount`, `couponCode`, `couponDiscount` |
| `lib/services/cancellation_fee_service.dart` | Stock restored on cancellation, atomic with idempotency ledger (branchStock model mirrored from OrderService) |
| `lib/utils/app_router.dart` | Routes: `/owner/refunds`, `/owner/settlements`, `/owner/settlement-reports` |
| `lib/screens/owner/owner_dashboard.dart` | Nav entries for the 3 finance screens; fixed NavigationRail misalignment (taps past 'Retention' opened wrong screens); fixed dead 'COD Settlements' drawer link |
| `firestore.rules` | Added missing `users/{uid}/wallet_transactions` rule (was default-deny → wallet checkout/top-up/refund credits all failed) |
| `lib/providers/wallet_provider.dart` | `addMoney` now requires a Razorpay `paymentId`; idempotent credit |
| `lib/screens/customer/wallet_screen.dart` | Top-up requires real Razorpay payment (was: free money buttons) |
| `db_migrations_002_role_constraint_fix.sql` | **NEW** — Postgres users.role constraint now matches all 12 Dart roles (run it!) |
| `lib/services/employee_scanner_service.dart` | `_ensureActiveStaff()` auth gate on receiveInventory + reportDamage |
| `lib/providers/delivery_provider.dart` | markDeliveryFailed writes valid status + `deliveryFailed` flag (was invalid 'failedDelivery' → parsed as 'pending') |
| `lib/services/delivery_last_mile_service.dart` | failDelivery same fix (was invalid 'READY') |
| `lib/screens/owner/failed_delivery_escalation_screen.dart` | Queries `deliveryFailed` flag (was querying a never-written status, permanently empty); escalation acts directly; cancel routes through fee/refund/stock-restore path with fee waived |
| `lib/services/order_service.dart` | OTP brute-force lockout: 5 attempts, 15-min lock, atomic transaction |
| `lib/models/order_model.dart` | 7-day return window on `canReturn` |

## Deleted (zero importers, verified)
`order_business_logic.dart`, `unified_order_service.dart`, `wallet_order_service.dart`,
`consolidated_order_service.dart`, `coupon_discount_service.dart`,
`order_service.dart.backup`, `settlements_management.dart~`

## New P0s discovered this sprint
1. **Free wallet money**: quick-add buttons credited spendable balance with no payment. FIXED.
2. **wallet_transactions default-deny**: the subcollection the app actually writes had no rule — wallet-paid checkout, top-ups, and refund credits all fail with these rules deployed. FIXED.
3. **Percentage coupons zeroed**: missing `maximumDiscountAmount` defaulted the cap to ₹0. FIXED.
4. **NavigationRail misrouting**: two missing rail entries shifted all owner rail taps after 'Retention'. FIXED.

## What Gaurav must do (deployment)
1. `firebase deploy --only firestore:rules` (from your Windows terminal — never git/deploy from the sandbox).
2. Run `db_migrations_002_role_constraint_fix.sql` against Postgres/RDS.
3. Rebuild + test APK: wallet-paid order, coupon apply ('Fixed Amount' AND a percentage coupon with no max), cancel an order and confirm stock comes back, fail a delivery and check the escalation screen shows it, wallet top-up (should open Razorpay).
4. Commit from Windows terminal (sandbox git-writes corrupt the index).

## Top remaining priorities
1. **P0-W1**: move wallet credits server-side, then tighten `walletBalance` rule to decrease-only for owners.
2. **P0-9.2**: consolidate 3 delivery services around `DeliveryService` as sole `deliveries/{id}` writer.
3. Coupon usage limits (P1-6.4), price-change bypass (P1-2.3), remaining P1/P2 backlog in `docs/MASTER_GAP_BACKLOG.md`.
4. Secrets rotation per `INFRA_CONFIG_SECRETS_AUDIT.md` — still the single most urgent non-code item.
