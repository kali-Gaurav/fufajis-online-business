# Module 7: Payment Facilities — Master Implementation + Audit

Part of the 17-module Fufaji Store facility audit series. Status: **2 new P0s found this module; prior payment-specific audit (`PAYMENT_AUDIT_REPORT.md`, 2026-06-19) already fixed 5 P0s + 5 P1s in the Razorpay/webhook/wallet-atomicity stack — those are not re-litigated here, only referenced.** New findings confirmed by reading live code: `lib/providers/wallet_provider.dart`, `lib/screens/customer/checkout_screen.dart` (lines 600-800), `lib/services/stripe_service.dart`, `lib/models/payment_method.dart`, `lib/services/payment_method_validator.dart`, `lib/services/payment_router_service.dart`, `functions/src/payments/processCashbackTrigger.ts`, plus the existing `PAYMENT_AUDIT_REPORT.md`.

## 1. Business Requirements

Customers pay via Razorpay (UPI/cards/net banking), in-app wallet balance, or Cash on Delivery. Owners need accurate, atomic money movement: no debit without a corresponding order, no order without corresponding stock deduction, and a reconciled ledger against Razorpay settlements. No written requirements doc exists — reverse-engineered from code and from `PAYMENT_AUDIT_REPORT.md`.

## 2. User Workflow

Three payment methods branch inside `checkout_screen.dart`'s single "place order" handler: **Razorpay/UPI** → `RazorpayService.createOrder` (Cloud Function `createRazorpayOrder`) → Razorpay checkout UI → `verifyRazorpayPayment` CF (HMAC verify) → `orderProvider.createOrder(order)`. **COD** → `orderProvider.createOrder(codOrder)` directly, cashback deferred to delivery via `cashback_triggers`. **Wallet** → `walletProvider.payWithWalletAndCreateOrder(...)` — a self-contained Firestore transaction that does NOT call `orderProvider.createOrder` at all (see finding 1).

## 3. UI Screens

- `checkout_screen.dart` — payment method selector, place-order button, all 3 flows.
- `payment_method_selector.dart` / `payment_method_step.dart` — method picker widget; **includes a "Stripe" option** (see finding 2).
- `payment_verification_dialog.dart` — Razorpay verification spinner/result.
- `payment_success_animation.dart` — confirmation animation.
- `owner/payment_analytics_screen.dart` — owner-side payment dashboard.

## 4. Backend Architecture

Razorpay path: `RazorpayService` (client) ↔ 3 Cloud Functions (`createRazorpayOrder`, `verifyRazorpayPayment`, `razorpayWebhook`), already hardened per `PAYMENT_AUDIT_REPORT.md`. Wallet path: `WalletProvider` only — no Cloud Function involvement, no shared code with `OrderService`/`OrderProvider` at all. COD path: thin, goes through the same `OrderProvider.createOrder` as Razorpay. `PaymentRouterService.decideRoute` exists to choose a gateway (intended to fall back to Stripe if Razorpay is unconfigured per its own code comments) but never actually references `StripeService` — confirmed via grep, zero matches for "Stripe" in `payment_router_service.dart`.

## 5. Database Schema

`orders/{id}.paymentStatus` values seen across the codebase: `'paid'`, `'wallet_paid'`, `'pending'` (COD) — no single enum/constant defines the full set in one place. `payments/{id}` ledger (Razorpay only — wallet debits are NOT mirrored into this ledger, only into `users/{id}/wallet_transactions`, a parallel and structurally different record). `payment_retry_queue`, `payment_retry_counters`, `payment_reconciliation_log`, `payment_orphans`, `webhook_logs` — all Razorpay-specific, per `PAYMENT_AUDIT_REPORT.md`; none of this infrastructure (retry, reconciliation, orphan handling) exists for wallet payments, which have no failure-recovery path at all beyond the transaction's own atomicity.

## 6. Service Layer

`RazorpayService`, `PaymentRouterService`, `PaymentRecoveryService`, `PaymentVerificationService`, `UpiPaymentService`, `PaymentMethodValidator` — six client-side services for the Razorpay/UPI side, already audited. `WalletProvider.payWithWalletAndCreateOrder` (`lib/providers/wallet_provider.dart:223-283`) — confirmed this module: builds its own `runTransaction` that (a) reads `users/{userId}.walletBalance`, (b) decrements it, (c) `transaction.set(orderRef, {...orderData, paymentStatus:'wallet_paid', ...})` writing the **entire order document from scratch**, (d) writes a wallet-transaction record. **It contains no call to `OrderService`, no stock/`branchStock` deduction of any kind, and no coupon/discount field population beyond whatever was already baked into the `orderData` map passed in from `checkout_screen.dart`.**

## 7. Integration Points

- **Inventory:** confirmed via grep across `functions/src/payments/` that the only Firestore `onCreate` trigger on payment-adjacent collections is `processCashbackTrigger` (fires on `cashback_triggers`, not `orders`). No Cloud Function or client code deducts stock when a wallet-paid order is created. Module 5 documented `OrderService.createOrder` as the sole live stock-deducting path (4 order-creation engines found, only one live) — **wallet payment is a 5th, independently-confirmed path, and it is the only one of the three live customer-facing payment methods (Razorpay, COD, wallet) that skips stock deduction entirely.**
- **Coupons:** `checkout_screen.dart`'s wallet branch (line 774) builds the order doc via `order.copyWith(status: OrderStatus.confirmed).toMap()`, where `order` is the same `OrderModel` instance audited in Module 6 finding 3 — confirmed it carries the same missing `couponCode`/discount-persistence gap, since it's the identical object, just routed through a different write path.
- **Cashback:** correctly deferred to delivery via `cashback_triggers` for COD (per `PAYMENT_AUDIT_REPORT.md` P1-5 fix); wallet path's comment at checkout_screen.dart:777 confirms the same deferred-cashback discipline is followed for wallet orders.

## 8. Automation

`PaymentReconciliationService` (nightly batch, per `PAYMENT_AUDIT_REPORT.md`) reconciles Razorpay settlements against Firestore — has no equivalent for wallet payments, which have no external settlement to reconcile against but also no internal cross-check that `users.walletBalance` decrements sum to `wallet_transactions` debits over time (no ledger-balance audit job found).

## 9. Security

**Confirmed direct violation of the standing "no Stripe" project rule.** `lib/services/stripe_service.dart` (213 lines) is a fully built `StripeService` class — `flutter_stripe` SDK init, PaymentIntent creation, PaymentSheet presentation, server-verification call — explicitly labeled in its own doc comment as "fallback payment gateway (Task #46)... used when `RazorpayService.isConfigured` is false." `PaymentMethod.stripe` is a selectable enum value wired into `payment_method.dart`'s UI option list (`PaymentMethodOption.stripe`, included in `PaymentMethodOption.all`) and switched on in `payment_method_validator.dart`. `pubspec.yaml` and the generated Android plugin registrant both declare the `flutter_stripe` dependency. **However:** `PaymentRouterService.decideRoute` — the only place the file's own comment claims it is invoked from — contains zero references to Stripe, so the service, while fully built and selectable in the UI enum, has no confirmed live call site actually invoking `StripeService.createPaymentIntent` or similar. This is dead-but-present code that violates the rule by existing in the repo at all, regardless of live-wiring status.

## 10. Failure Cases

Wallet payment failure modes: `payWithWalletAndCreateOrder`'s catch-all returns `false` on any exception (insufficient balance, missing user doc, Firestore error) with only a `debugPrint` — no `security_events` write, no retry queue, no orphan tracking, unlike the Razorpay path's already-hardened failure handling. If the transaction's wallet-debit step succeeds but Firestore throws on the order-write step, the entire transaction rolls back atomically (this part is correctly fixed per `PAYMENT_AUDIT_REPORT.md` P1-4) — so no money-loss risk, but also no operator visibility into how often wallet payments fail.

## 11. Testing

No test file references `wallet_provider` or `payWithWalletAndCreateOrder`. The Razorpay stack has a "dedicated stress test" referenced in `PAYMENT_AUDIT_REPORT.md` for the (separately orphaned, per Module 4) `deductInventoryAtomic` mechanism, but nothing covering the actual live wallet-payment-bypasses-stock-deduction path identified here.

## 12. Production Readiness

The Razorpay stack is genuinely production-hardened per the prior dedicated audit (8.7/10 self-scored, P0/P1 clear). This module's two new findings pull the *overall* payment module back down: finding 1 means wallet-paid orders can oversell stock with no deduction at all — worse than any gap previously found in Modules 1-6, since it directly creates negative-inventory/overselling risk on every wallet checkout. Finding 2 is a policy violation independent of severity — the rule was "don't add Stripe," and Stripe is in the codebase, dependency tree, and UI enum today.

---

## Final Output Format

### Current State Audit
Razorpay payments are well-built and already hardened (separate prior audit). Wallet payments are atomic for money movement but completely bypass the inventory system. Stripe code exists in violation of an explicit standing project rule, currently inert but selectable in the payment-method enum.

### Missing Components
Stock deduction inside (or immediately following) `WalletProvider.payWithWalletAndCreateOrder`'s transaction; a wallet-payment failure/retry observability path equivalent to the Razorpay one; a unified `paymentStatus` enum/constants file (currently free-text strings duplicated across call sites); removal of all Stripe code per standing project rule.

### Architecture Design
Route wallet payments through the same `OrderService.createOrder` stock-deduction transaction that Razorpay/COD already use, with the wallet debit added as an additional atomic step inside that same transaction (or via a two-phase pattern: reserve stock first via `OrderService`, then debit wallet, matching the existing atomicity guarantee without duplicating the order-creation logic in `WalletProvider`). Delete `StripeService`, `PaymentMethod.stripe`, the `flutter_stripe` dependency, and `AppConfig.stripePublishableKey`/`isStripeConfigured` outright — Razorpay is the sole approved gateway per standing project rules, so no fallback gateway is needed; if a fallback is genuinely desired, it must not be Stripe.

### Implementation Plan
1. **P0 — fix wallet payment's missing stock deduction.** Either (a) refactor `WalletProvider.payWithWalletAndCreateOrder` to call into `OrderService.createOrder`'s transaction logic for the stock-deduction portion before/within its own transaction, or (b) merge wallet-as-a-payment-method into `OrderService.createOrder` itself (preferred — keeps one order-creation engine, consistent with the Module 5 recommendation to consolidate rather than add more competing engines) so wallet becomes just another `paymentMethod` value handled inside the existing live path instead of a parallel one.
2. **P0 — remove all Stripe code per the standing "no Stripe" rule.** Delete `lib/services/stripe_service.dart`, the `stripe`/`PaymentMethodOption.stripe` enum entries in `payment_method.dart`, the Stripe `case` branches in `payment_method_validator.dart`, the `flutter_stripe` dependency from `pubspec.yaml`, and `AppConfig.stripePublishableKey`/`isStripeConfigured`. Confirm no UI screen still renders the Stripe option after removal (re-grep `PaymentMethodOption.all`/`.allOnline` etc.).
3. **P1 — mirror wallet debits into the `payments` ledger** alongside `wallet_transactions`, so owner-side payment analytics/reconciliation cover all payment methods, not just Razorpay.
4. **P1 — add basic failure observability to wallet payments** (a `security_events` or dedicated `wallet_payment_failures` write on the catch-all in `payWithWalletAndCreateOrder`), matching the rigor already present in the Razorpay path.
5. **P2 — finish the already-identified `PAYMENT_AUDIT_REPORT.md` P2/P3 items** (`payment.authorized` webhook handler, max-retry cap, refund ledger entries, `_handlePaymentError` order-marking, idempotency keys, orphan alerting, correlation IDs, wallet provider list) — unchanged by this module's findings, still open.
6. **P2 — define a single `PaymentStatus`-style constant set** covering `'paid'`/`'wallet_paid'`/`'pending'`/etc., replacing scattered free-text strings.

### File-by-file Changes
- `lib/providers/wallet_provider.dart` — add stock-deduction step to `payWithWalletAndCreateOrder`, or deprecate the method entirely in favor of routing through `OrderService.createOrder`.
- `lib/screens/customer/checkout_screen.dart` — update the wallet branch (lines 760-792) to call the consolidated order-creation path instead of `walletProvider.payWithWalletAndCreateOrder` directly.
- `lib/services/stripe_service.dart` — delete.
- `lib/models/payment_method.dart` — remove `stripe` enum value and `PaymentMethodOption.stripe`.
- `lib/services/payment_method_validator.dart` — remove `case PaymentMethod.stripe` branches.
- `lib/services/payment_router_service.dart` — remove any remaining fallback-routing logic that assumed a Stripe option (confirm none currently references it, but check after the enum change for exhaustiveness-switch compile errors).
- `lib/config/app_config.dart` — remove `stripePublishableKey`/`isStripeConfigured`.
- `pubspec.yaml` — remove `flutter_stripe` dependency.
- `lib/services/order_service.dart` — extend to accept a `walletPayment` mode that performs the wallet debit transactionally alongside existing stock deduction.

### Production Checklist
- [ ] Wallet-paid orders deduct stock atomically, same guarantee as Razorpay/COD
- [ ] No Stripe code, dependency, or UI option remains anywhere in the repo
- [ ] Wallet debits appear in the `payments` ledger, not only `wallet_transactions`
- [ ] Wallet payment failures are observable (logged/alertable), not just `debugPrint`
- [ ] Single source of truth for `paymentStatus` string values
- [ ] Outstanding `PAYMENT_AUDIT_REPORT.md` P2/P3 items tracked and scheduled
