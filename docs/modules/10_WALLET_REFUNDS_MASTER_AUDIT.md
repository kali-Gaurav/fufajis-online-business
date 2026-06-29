# Module 10 — Wallet & Refunds: Master Implementation + Audit

## 1. Business Requirements

The wallet is the app's internal store-credit ledger: customers receive cashback, refunds, reward-point redemptions, and top-ups into it, and can spend the balance at checkout. Refunds are triggered by three business events — order cancellation, owner-approved returns/damage claims, and manual owner adjustments — and must settle via one of four methods: wallet credit, UPI, payment-gateway reversal (Razorpay), or direct bank transfer (RazorpayX payout). Every credit/debit must be atomic, idempotent (no double-pay on retry), auditable, and reconciled against the Postgres/Firestore source of truth.

## 2. User Workflow

- Customer cancels an order pre-dispatch → expects an automatic refund to wallet, net of any cancellation fee shown before confirming.
- Customer requests a return/damage refund → owner reviews, approves, and chooses a payout method (wallet / UPI / gateway / bank).
- Customer pays at checkout using wallet balance → balance is debited atomically with the order being created.
- Customer views wallet balance and transaction history.
- Owner/admin advances a refund through pending → approved → processing → completed (or failed), entering bank/UTR details when needed.

## 3. UI Screens

- `screens/customer/wallet_screen.dart` — balance + actions (router: `/customer/my-wallet`).
- `screens/customer/wallet_history_screen.dart` — transaction list (router: `/customer/wallet`).
- `screens/customer/order_detail_screen.dart` — cancel/return entry point, fee preview dialog.
- `screens/owner/refund_processing_screen.dart` — full refund queue, batch actions, bank-detail/UTR prompts. **Built but unreachable — see §10.**
- `screens/owner/settlements_management.dart`, `settlement_reporting_screen.dart` — also unreachable, no router entry (plus a stray `settlements_management.dart~` backup file left in the source tree).

## 4. Backend Architecture

Six independent subsystems exist for "wallet/refund," with no shared coordination layer:

1. **`WalletService`** (canonical ledger) — atomic `runTransaction`-based `addToWallet`/`deductFromWallet`, idempotency-checked via a deterministic `transactionId` doc.
2. **`WalletProvider`** — UI-facing wrapper. Most methods correctly delegate to `WalletService`, but `payWithWalletAndCreateOrder` (the one checkout actually calls for wallet payments, per Module 7) reimplements the debit transaction inline and skips the idempotency check.
3. **`RefundRequest` / `RefundStatusEngine` / `RefundProcessingScreen`** — `refund_requests` + `refund_audit_logs` collections, full state machine + RBAC, real Razorpay/RazorpayX Cloud Function calls. The architecturally "correct" system. Orphaned from navigation (§10).
4. **`OrderBusinessLogic.cancelOrder` → `_processRefundAsync`** — the actual live auto-refund-on-cancellation path. Writes a `refund_requests` doc directly as already-`completed` (bypassing the engine), credits `WalletService` for the **full** order amount, idempotent via deterministic key. Stock restoration is a `// TODO` — never implemented.
5. **`CancellationFeeService.applyAndRefund`** — calculates a cancellation fee by order status, credits the **net** amount to wallet, logs to `cancellation_fee_ledger`. Called only from `order_detail_screen._cancelOrder()`, unconditionally followed by a call into path #4 — see §10 for the resulting double-refund.
6. **`RefundServiceFixed` + Cloud Function `processRefundWithStockRestore`** — the only subsystem that actually restores stock atomically alongside the wallet credit and order-status update, with its own `refund_logs`/`return_requests`/`inventory_events` collections. **Confirmed dead code — zero callers anywhere in `lib/`.**
7. **`WalletReconciliationService`** — three-level balance reconciliation (per-user, system-wide, gateway-captured-vs-expected). Only `debugPrint`s mismatches; no auto-correction, no scheduled trigger, no caller found anywhere in the codebase. Built, never wired.

## 5. Database Schema

- `users/{uid}.walletBalance` — single numeric field, source of truth for spendable balance.
- `users/{uid}/wallet_transactions/{txnId}` — ledger entries; `type` serialized via `enum.toString()` (qualified, e.g. `WalletTransactionType.refund`).
- `refund_requests/{id}` — `RefundRequest` docs (status machine: pending/approved/processing/completed/failed; `refundMethod`: wallet/upi/gateway/bank).
- `refund_audit_logs` — written by `RefundStatusEngine.transitionRefundStatus` only.
- `refund_logs`, `return_requests`, `inventory_events` — written only by the dead `processRefundWithStockRestore` Cloud Function / `RefundServiceFixed`.
- `cancellation_fee_ledger` — written by `CancellationFeeService`, cross-referenced by nothing else.

## 6. Service Layer

`WalletService` is well-built and should be the single point of truth, but three other code paths (`WalletProvider.payWithWalletAndCreateOrder`, `OrderBusinessLogic._processRefundAsync`, the dead Cloud Function) independently re-implement wallet ledger writes instead of calling it, and `CancellationFeeService` calls `addToWallet` without a deterministic `transactionId`, removing idempotency protection on that path specifically.

## 7. Integration Points

- Razorpay (gateway refund), RazorpayX (bank payout) — both live, called from `RefundProcessingScreen._transitionRefund`, but that screen is unreachable (§10), so neither integration is currently exercised by any user.
- Cloud Functions: `initiateRazorpayRefund`, `initiateBankTransferRefund` (called from the orphaned screen), `processRefundWithStockRestore` (called from dead `RefundServiceFixed`).

## 8. Automation

None of the refund automation actually runs end-to-end in production today: the one Cloud Function that does the "right" thing (stock + wallet + status + audit, atomically) has no caller; the screen that would let an owner run the RazorpayX/Razorpay automation has no route.

## 9. Security

`firestore.rules` covers the top-level `wallet_transactions` collection (read: own/admin, write: false, comment: "Must be done via atomic Cloud Function or Admin SDK") and `refund_requests` (read: own/admin, create: own, update: admin-only — correct). **No rules exist for `refund_audit_logs`, `refund_logs`, `return_requests`, `inventory_events`, or `cancellation_fee_ledger`** — consistent with the gap pattern already documented in Modules 6 and 9.

**That `wallet_transactions` lockdown is bypassed in practice.** Every live write — `WalletService`, `WalletProvider.refundOrder/payWithWallet/addMoney/payWithWalletAndCreateOrder` — writes to `users/{userId}/wallet_transactions/{txnId}`, a **subcollection** under `users`, not the protected top-level collection the rule targets. That subcollection falls under the catch-all `match /users/{userId}/{document=**} { allow read, write: if isOwningUser(userId) || isGlobalAdmin(); }` (line 63-65), which grants the owning client full write access. Worse, the parent `users/{userId}` document itself allows `update: if isOwningUser(userId) || isGlobalAdmin()` with no field-level restriction — a client can call `users.doc(myUid).update({walletBalance: 999999})` directly from the SDK, bypassing `WalletService` entirely. This is the same root-cause rule shape as the "role self-write" P0 already documented in [[project_auth_module1_audit_findings]] (Module 1), recurring here for the financial balance field.

## 10. Failure Cases — Confirmed Findings

**P0 — Client can write its own wallet balance directly, bypassing every service.** Per §9: the `users/{userId}` document's permissive `update` rule plus the `users/{userId}/{document=**}` catch-all mean a modified/malicious client can set `walletBalance` to any value and forge `wallet_transactions` subcollection entries via the Firestore SDK directly — no Cloud Function, no idempotency check, no audit trail. The top-level `wallet_transactions` rule that claims to lock this down protects a collection path nothing in the app actually uses.

**P0 — CORRECTED 2026-06-20: not a double-refund — early cancellations got NO refund at all.** Original finding above was wrong: it assumed `orderProvider.cancelOrder()` calls `OrderBusinessLogic._processRefundAsync`, but `OrderProvider.cancelOrder` (`lib/providers/order_provider.dart:552`) actually calls `OrderService.updateOrderStatus(orderId, 'cancelled')`, which only flips the status field — no refund logic at all, confirmed by reading the live method. `OrderBusinessLogic` has zero live callers (per [[project_cart_order_module5_audit_findings]]), so it never ran a second refund. The real bug: `order_detail_screen._cancelOrder()` only called `CancellationFeeService.applyAndRefund()` `if (feeResult.fee > 0)` — but `applyAndRefund` already correctly handles the `fee == 0` case (refunds the full amount, skips the ledger entry) and is idempotent via a deterministic `cancellation_fee_${orderId}` ledger-doc check (the "no idempotency key" claim below was also wrong). Net effect: cancellations during `pending`/`confirmed` (the 0%-fee tier, the most common case) received **zero refund**, not a double one. **Fixed 2026-06-20**: removed the `if (feeResult.fee > 0)` gate so `applyAndRefund` runs for every cancellation.

**P0 — Stock never restored on cancellation.** `OrderBusinessLogic.cancelOrder` has a literal `// TODO: Implement inventory restoration in repository` where stock restoration should happen. Every cancellation refunds money but permanently loses the reserved/deducted stock. The one subsystem that does restore stock correctly (`processRefundWithStockRestore`) is dead code (next finding).

**P0 — The architecturally correct refund system is fully orphaned.** `RefundProcessingScreen` (728 lines, real Razorpay/RazorpayX integration, RBAC, audit logging) has zero references in `app_router.dart` and zero direct `Navigator`/`MaterialPageRoute` pushes anywhere in `lib/` — confirmed via repo-wide grep. No owner or admin can ever reach it. `settlements_management.dart` and `settlement_reporting_screen.dart` are likewise unrouted (plus a stray `.dart~` backup file should be deleted from source control).

**P1 — Wallet-method refunds never move money even if reachable.** `RefundStatusEngine.transitionRefundStatus` only updates the `refund_requests` status field and writes an audit log; it never calls any wallet-credit logic for `RefundMethod.wallet`. Even if the screen were wired into the router, advancing a wallet refund to "completed" would not actually credit the customer.

**P1 — Duplicated, non-idempotent wallet-debit logic in checkout.** `WalletProvider.payWithWalletAndCreateOrder` (the live checkout wallet-payment path per Module 7) re-implements the debit transaction inline instead of calling `WalletService.deductFromWallet`, and performs no pre-check for an existing transaction document — a retried call can double-deduct.

**P2 — Dead Cloud Function has a latent serialization bug.** `processRefundWithStockRestore.ts` writes `status: 'refunded'` (bare string) to the order doc, but `OrderModel`/`StatusHistoryEntry.fromMap` matches against `OrderStatus.values.firstWhere((e) => e.toString() == map['status'])` — the **qualified** form (`'OrderStatus.refunded'`). If this function is ever wired up as-is, the order's status would silently fail to parse as refunded. Latent only because the function currently has no caller.

**P2 — Reconciliation tooling built but inert.** `WalletReconciliationService` computes three levels of balance mismatch but only logs them and has no caller (no admin screen, no scheduled Cloud Function) — drift between `walletBalance` and the transaction ledger would never be surfaced today.

## 11. Testing

No automated tests cover any of the six wallet/refund code paths. Given the confirmed double-refund bug, a transaction-level integration test asserting "one cancellation → exactly one wallet credit, for the net amount" should be the first test written.

## 12. Production Readiness

Not production-ready for any flow that involves a cancellation fee (active money-loss bug) or stock restoration (permanent stock leak on every cancellation). The refund system an owner would actually use to process returns/damage claims with real payment-method routing is unreachable from the UI.

---

## Final Output Format

**1. Current State Audit:** Six parallel wallet/refund subsystems confirmed (`WalletService`+`WalletProvider`, `RefundStatusEngine`+`RefundProcessingScreen`, `OrderBusinessLogic._processRefundAsync`, `CancellationFeeService`, `RefundServiceFixed`+Cloud Function, `WalletReconciliationService`), only the first plus a contradictory pair (#4+#5) actually run in production.

**2. Missing Components:** a Firestore rule that actually restricts `users/{userId}/wallet_transactions/{txnId}` and excludes `walletBalance` from client-writable fields on `users/{userId}`; stock restoration on cancellation; wallet-credit step inside `RefundStatusEngine.transitionRefundStatus`; router entries for `RefundProcessingScreen`/`settlements_management`/`settlement_reporting_screen`; Firestore rules for `refund_audit_logs`/`refund_logs`/`return_requests`/`inventory_events`/`cancellation_fee_ledger`; a scheduled caller for `WalletReconciliationService`.

**3. Architecture Design:** Move all wallet balance/ledger writes server-side only — either route every credit/debit through a Cloud Function (mirroring the already-built but dead `processRefundWithStockRestore` pattern) or add a `firestore.rules` restriction (e.g. `request.resource.data.diff(resource.data).affectedKeys().hasOnly([...])` excluding `walletBalance`) so the client SDK can never self-write balance or ledger docs. Consolidate on `WalletService` as the only application-layer writer; route every refund (auto-cancellation, owner-approved return, manual adjustment) through `RefundStatusEngine` as the single state machine, with a `completed`-transition hook that performs the actual payout (wallet credit / gateway call / bank payout) atomically with the status write; retire `CancellationFeeService`'s independent wallet write and have it only compute the fee, handing the net amount to the engine; retire or revive `RefundServiceFixed`'s stock-restoration logic by merging it into the engine's wallet-method completion hook instead of leaving it as a disconnected Cloud Function.

**4. Implementation Plan:** (1) close the client-side wallet self-write hole — restrict `users/{userId}` updates to exclude `walletBalance`/`role` and lock down the `wallet_transactions` subcollection path actually used in code; (2) ~~stop the double-credit~~ **done 2026-06-20** — removed the `if (feeResult.fee > 0)` gate in `order_detail_screen._cancelOrder()` so zero-fee cancellations actually get refunded; (3) implement stock restoration on cancellation (the dead `processRefundWithStockRestore.ts` already has working logic to port — note: it restores stock but is not itself the refund-credit path, since that's now confirmed to be `CancellationFeeService.applyAndRefund`); (4) add a wallet-credit step to `RefundStatusEngine.transitionRefundStatus` for `RefundMethod.wallet` on transition to `completed`; (5) wire `RefundProcessingScreen` into `app_router.dart` under the owner section; (6) fix the bare/qualified status-string bug in the Cloud Function if it's kept; (7) add missing Firestore rules; (8) wire `WalletReconciliationService` into a scheduled Cloud Function with alerting.

**5. File-by-file Changes:** `firestore.rules` (restrict `users/{userId}` field-level updates to exclude `walletBalance`, add a real rule for the `wallet_transactions` subcollection path, add missing collection rules for `refund_audit_logs`/`refund_logs`/`return_requests`/`inventory_events`/`cancellation_fee_ledger`), `lib/services/order_business_logic.dart` (implement stock restoration, remove duplicate refund trigger or make `CancellationFeeService` the only credit path), `lib/screens/customer/order_detail_screen.dart` (remove the unconditional second `cancelOrder()` call when a fee was already applied), `lib/services/refund_status_engine.dart` (add wallet-credit hook), `lib/utils/app_router.dart` (add refund/settlement routes), `functions/src/refunds/processRefundWithStockRestore.ts` (fix status string, or remove if superseded).

**6. Production Checklist:** [ ] client-side wallet-balance self-write hole closed and tested, [x] zero-fee-cancellation no-refund bug fixed 2026-06-20 (was misdiagnosed as a double-refund; corrected and fixed), [ ] stock restoration implemented and tested, [ ] wallet-method refunds verified to actually credit on completion, [ ] `RefundProcessingScreen` reachable and tested by an owner end-to-end including bank/UTR flow, [ ] Firestore rules added for all five unprotected collections, [ ] reconciliation job scheduled with alerting, [ ] stray `settlements_management.dart~` removed from source control.
