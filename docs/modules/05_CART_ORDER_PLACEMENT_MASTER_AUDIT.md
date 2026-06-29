# Module 5: Cart / Order Placement — Master Implementation + Audit

**Status:** Audit complete. Findings confirmed by reading live code. No code changes made in this pass.
**Date:** 2026-06-19
**Files read in full:** `lib/providers/cart_provider.dart` (614 lines), `lib/services/order_service.dart` (719 lines), `lib/services/order_business_logic.dart` (675 lines)
**Files spot-checked:** `lib/services/order_workflow_engine.dart`, `lib/repositories/order_repository.dart`, `lib/services/cart_sync_service.dart`, call sites across `lib/screens/`, `lib/providers/order_provider.dart`, `lib/providers/delivery_provider.dart`

---

## 1. Business Requirements

Cart and order placement is the revenue-critical path: a customer builds a cart (with variants, coupons, wallet credit, tips, delivery-type selection), checks out, and the system must atomically validate stock, deduct it, charge/record payment, and persist a durable order record — across shop-open-hours, delivery-radius, slot-capacity, and duplicate-submission checks — before any subsequent packing/delivery workflow can begin.

## 2. User Workflow

Customer adds items to cart (`CartProvider.addToCart`, variant-aware) → optionally applies a coupon (`applyCouponDynamic`, Firestore-backed with a hardcoded-2-code fallback) → optionally uses wallet credit/tip → selects delivery type/slot → taps checkout in `checkout_screen.dart` or `fast_checkout_screen.dart` → screen calls `orderProvider.createOrder(...)` → `OrderProvider` delegates to `OrderService().createOrder(order)` → Firestore transaction validates+deducts stock, writes the order, releases idempotency lock → cart is cleared → customer sees confirmation, order enters `pending`/`confirmed` lifecycle tracked entirely inside `OrderService` (`updateOrderStatus`, `approvePacking`, `verifyAndDeliverOrder`).

## 3. UI Screens

- `checkout_screen.dart` (lines 649, 666, 688, 742) and `fast_checkout_screen.dart` (lines 121, 135) — the only two customer-facing entry points into order creation. Both call `orderProvider.createOrder(...)`, never `OrderService()`/`OrderBusinessLogic()`/`OrderStatusEngine()` directly.
- `orders_management.dart` (owner), `packing_dashboard_screen.dart`, `packing_terminal_screen.dart` — call `OrderService().updateOrderStatus` / `.approvePacking` / `.rejectPacking` directly for post-creation lifecycle.
- `delivery_orders_screen.dart`, `delivery_detail_screen.dart` — call `verifyAndDeliverOrder` (via `OrderProvider`/`DeliveryProvider`, both of which delegate to `OrderService`).
- `delivery_reschedule_screen.dart`, `failed_delivery_escalation_screen.dart` — the only two screens that use the third, separate `OrderWorkflowEngine` (Supabase-backed) instead of `OrderService`.

## 4. Backend Architecture — **the central finding of this module**

There are **four independent, non-coordinated order-creation/stock-deduction implementations** in this codebase. Only one is reachable from any customer-facing or staff-facing screen; the other three are fully or partially orphaned:

1. **`OrderService.createOrder`** (`lib/services/order_service.dart`) — **CONFIRMED LIVE.** Singleton, called by `OrderProvider` (lines 191, 649), which is called by `checkout_screen.dart` and `fast_checkout_screen.dart` (the only two checkout UIs) and replayed by `offline_sync_service.dart`'s queue. Runs its own Firestore transaction: validates shop hours/geofence/slot capacity, deducts `products.branchStock`/`stockQuantity` directly, debits wallet via an event-sourced ledger, writes the order doc. Also owns `updateOrderStatus` (its own `_validTransitions` map), `approvePacking`/`rejectPacking`, and `verifyAndDeliverOrder` (OTP + 50m geofence) — i.e. it is a complete, self-contained, end-to-end order lifecycle engine, confirmed wired to every real lifecycle screen found (owner orders management, packing dashboard/terminal, delivery screens, fleet service).
2. **`OrderBusinessLogic` + `OrderStatusEngine` + `OrderRepository.createOrderWithInventoryUpdate` + `InventoryRepository`** (`lib/services/order_business_logic.dart`, `order_status_engine.dart`, `lib/repositories/order_repository.dart`, `lib/repositories/inventory_repository.dart`) — **CONFIRMED FULLY ORPHANED.** Exhaustive grep for `OrderBusinessLogic()` and `OrderStatusEngine()` across all of `lib/` found exactly two non-self referrers: `order_business_logic.dart`'s own instantiation of `OrderStatusEngine`, and `order_repository_test.dart` (a test file). Zero screens, providers, or other services call `OrderBusinessLogic()` anywhere. This is a **second, more sophisticated order-lifecycle engine that is never invoked in production**: it has proper status-engine-validated transitions (`transitionWithSideEffects`), a real refund-to-wallet flow on cancellation, OTP-verified delivery with 5-attempt lockout + `SecurityEventService` logging, and a 30-day return-window check on `initiateReturn` — all features absent or less rigorous in the live `OrderService` path (e.g. `OrderService.createOrder` has no equivalent "5-attempt OTP lockout + security event" on its own OTP verification flow inside `verifyAndDeliverOrder`/`updateOrderStatus`, and its cancellation path does not appear to auto-refund to wallet the way `OrderBusinessLogic.cancelOrder`'s `_processRefundAsync` does).
3. **`InventoryRepository.reserveInventory`/`commitInventory`/`restoreInventory`/`qcInventory`** — previously flagged in Module 4 as "confirmed live, called from `order_status_engine.dart:46`." **This finding must be corrected**: `OrderStatusEngine` itself has no live caller outside the orphaned `OrderBusinessLogic` (see #2). This means the Module 4 P0 ("every checkout for a non-seeded product should throw because no code creates `inventory/{productId}_{branchId}` docs") is **real as a code-correctness bug inside an orphaned subsystem, but does not currently block live checkout**, because the live checkout path (`OrderService.createOrder`) never calls `InventoryRepository` at all — it deducts `products.branchStock` directly instead. The severity reclassifies from "production-breaking checkout blocker" to "a fully-built, well-designed inventory state machine that nothing in production exercises" — arguably still high severity (the better-designed system is dead, the live system bypasses it), but not an active outage risk today.
4. **`OrderWorkflowEngine`** (`lib/services/order_workflow_engine.dart`) — **CONFIRMED PARTIALLY LIVE**, but only for edge cases: `delivery_reschedule_screen.dart`, `failed_delivery_escalation_screen.dart`, `partial_fulfillment_service.dart`. Operates against **Supabase/Postgres** (`SupabaseDatabaseService.updateOrderStatus`, `orders.order_status`), with its own status vocabulary (`preparing`, `ready_for_pickup`, `partially_fulfilled`, `on_hold`, `return_initiated` — none of which match `OrderService`'s Firestore `OrderStatus` enum values `processing`/`packed`/`outForDelivery`). It auto-syncs stock decrement at `preparing` and auto-generates a GST invoice at `delivered` — both real, useful automations — but operates on a **different datastore and a different status field** than the live Firestore order created by `OrderService.createOrder`. Whether these three screens are reading/writing the *same* order records as the Firestore-side lifecycle, or a parallel Postgres mirror that the main order flow never populates, was not resolved this pass and is a strong candidate for the highest-priority follow-up (see Section 10).

**Net picture:** one fully-wired, "good enough," self-contained engine (`OrderService`) handles 100% of live order creation and most lifecycle transitions; one more rigorous, better-designed but completely unused engine (`OrderBusinessLogic`/`OrderStatusEngine`) sits beside it; one inventory state-machine (`InventoryRepository`) is wired only to the unused engine; and one Postgres-backed engine (`OrderWorkflowEngine`) handles only three specific edge-case screens against what may be an entirely separate data surface.

## 5. Database Schema

- `orders/{orderId}` (Firestore) — written by `OrderService.createOrder`/`OrderRepository.createOrder` (same collection, two different writers — only `OrderService`'s writer is reachable live). Fields include `status`, `packingStatus`, `statusHistory`, `packingHistory`, `parcelId`, hashed delivery OTP at top level + plaintext OTP in `orders/{id}/secure/otp` subcollection, `orders/{id}/cashCollection/log` for COD.
- `orders.order_status` (Postgres/Supabase) — written/read by `OrderWorkflowEngine`/`SupabaseDatabaseService`, paired with an `order_status_history` table. Unclear if this mirrors or duplicates the Firestore `orders` collection (see Section 10).
- `products/{productId}.branchStock`/`stockQuantity` — the actual live stock-deduction target, mutated transactionally inside `OrderService.createOrder`.
- `inventory/{productId}_{branchId}` (Firestore) — the target of the orphaned `InventoryRepository` path; per Module 4, no code anywhere creates these docs.
- `wallet_transactions/txn_wallet_debit_{orderId}` — idempotent wallet-debit record written inside `OrderService.createOrder`'s transaction.
- `refund_requests/{ref_orderId}` — written only by the orphaned `OrderBusinessLogic._processRefundAsync`; the live `OrderService` cancellation path (`updateOrderStatus(..., 'cancelled')`) has no equivalent refund-request/wallet-credit step visible in the code read this pass — worth confirming in the Wallet & Refunds module (#10) whether cancellation-triggered refunds happen anywhere on the live path at all.
- Cart: `SharedPreferences` (local) + Firestore (cloud, via `CartSyncService`, collection not fully confirmed this pass — referenced as a per-user cart document/subcollection), merged on login by `CartProvider.mergeCartOnLogin`.

## 6. Service Layer

`CartProvider` (state) → `CartSyncService` (persistence) is a clean, single-path design — no fragmentation found here, unlike every previous module. `OrderProvider` (thin UI-facing wrapper) → `OrderService` (the actual engine) is also clean for the live path. The fragmentation is entirely at the "which engine" layer (Section 4), not within either engine's own internals.

## 7. Integration Points

- Firestore: `orders`, `products`, `wallet_transactions`, `users`, `counters`, `delivery_tasks`.
- Postgres/Supabase: `orders`, `order_status_history` (via `OrderWorkflowEngine`/`SupabaseDatabaseService`) — integration boundary with the Firestore side not confirmed.
- `ShopConfigService` — operating hours, geofence (`isWithinDeliveryArea`), nearest-branch assignment, all checked inside `OrderService.createOrder` before the transaction runs.
- `HyperlocalExpansionService`, `SmartKitchenService` — fire-and-forget post-order analytics, best-effort.
- `NotificationService`, `WhatsAppNotificationService` — order-confirmation notification/invoice, best-effort (errors caught and logged only).
- `RazorpayService` (via `OrderProvider.createOrder` at separate lines 263/339) — a **same-named-method, different-purpose** collision worth flagging again: `orderProvider`'s own `createOrder` (the Fufaji order) and `_razorpayService.createOrder` (a Razorpay payment-order object) are two different operations sharing a method name one layer apart — easy to misread in a diff or stack trace.

## 8. Automation

- Idempotency: in-memory `_activeCheckouts` lock + a 5-minute same-customer/same-amount/same-item-count Firestore duplicate check inside `OrderService.createOrder` — a solid, pragmatic double-guard against double-submission/double-tap checkout.
- Branch auto-assignment via nearest-branch geofence lookup.
- Delivery-slot capacity auto-enforcement (`isDeliverySlotAvailable`).
- `OrderWorkflowEngine`'s auto-stock-sync-at-`preparing` and auto-GST-invoice-at-`delivered` are real automations, but scoped to the Postgres side and the three edge-case screens that use it.

## 9. Security

- Delivery OTP: hashed (SHA-256) on the main `orders` doc, plaintext only in a separate `secure` subcollection — reasonable separation. `OrderService.verifyAndDeliverOrder` additionally requires the rider be within 50m of the delivery address. However, **`OrderService`'s OTP check has no attempt-count lockout or `SecurityEventService` logging**, unlike the orphaned `OrderBusinessLogic.markDelivered`, which locks out after 5 failed attempts and logs an `otpLockout`/`otpFailure` security event. The live path is missing a brute-force guard the dead path already solved.
- `_activeCheckouts` lock is in-memory only (`static final Set<String>`) — does not survive app/process restart and is not shared across server instances if `OrderService` ever runs in more than one backend process; the 5-minute Firestore duplicate check is the real cross-instance guard, and is sufficient for a single-Firestore-project deployment, but the in-memory lock should not be relied on alone.
- Wallet debit inside `createOrder`'s transaction is correctly event-sourced (sequence number + idempotent transaction doc) — good pattern, consistent with how a financial ledger should be written.

## 10. Failure Cases

- **P0 — Two complete order-lifecycle engines exist; the better-designed one is dead code.** `OrderBusinessLogic`/`OrderStatusEngine` (proper status validation, wallet refund on cancel, OTP lockout + security logging, return-window enforcement) has zero live callers. Either migrate the live path onto this engine's better-designed primitives, or delete the dead code so it stops looking like the intended architecture to the next person who reads it (exactly the trap this audit nearly fell into, having flagged `InventoryRepository` as "live" in Module 4 based on `OrderStatusEngine` being its caller, without checking whether `OrderStatusEngine` itself was reachable).
- **P0 — Unclear whether `OrderWorkflowEngine`'s Postgres `orders` table is the same logical order as the Firestore `orders` doc, or a disconnected parallel record.** If disconnected, `delivery_reschedule_screen.dart` and `failed_delivery_escalation_screen.dart` are operating on stale/non-existent data for any order actually created via `OrderService.createOrder` (Firestore-only). This needs a direct answer before Module 9 (Delivery Facilities) can be audited correctly, since both screens live in the delivery domain.
- **P1 — Live OTP delivery verification has no brute-force lockout**, unlike the dead `OrderBusinessLogic.markDelivered`. A malicious or careless rider can attempt unlimited OTP guesses against `OrderService.verifyAndDeliverOrder`/`updateOrderStatus`.
- **P1 — No confirmed refund-to-wallet on live cancellation path.** `OrderService.updateOrderStatus(..., 'cancelled')` only validates the transition and writes status/history; the wallet-credit refund logic exists only in the orphaned `OrderBusinessLogic._processRefundAsync`. If true, every live order cancellation today leaves the customer's wallet un-refunded unless a separate, not-yet-found mechanism handles it — to be confirmed in the Wallet & Refunds module audit (#10), flagged here as a likely upstream cause.
- **P2 — `CartProvider.autoOptimizeCoupons` only compares two hardcoded codes** (`SAVE10`/`FIRST20`), not real Firestore coupons, despite `applyCouponDynamic` already supporting real Firestore-backed coupons. Inconsistent: a customer's best *available* coupon may never be suggested if it isn't one of the two hardcoded ones.
- **P2 — `migrateGuestCart` seeds placeholder `stockQuantity: 999`/`shopName: ''`** for migrated guest-cart items, described in a comment as "refreshed on next load" — not verified whether any code actually performs that refresh; if not, a guest-to-account cart migration could silently carry stale/fake stock numbers into checkout until the next full cart reload.
- **P2 (recurring pattern, 5th confirmed instance)** — "policy/logic exists in more than one place, not coordinated," same smell as every prior module ([[project_inventory_module4_audit_findings]], [[project_scanner_module3_audit_findings]], [[project_product_module2_audit_findings]], [[project_auth_module1_audit_findings]]) — here manifesting as competing *engines* rather than competing write paths to the same data.

## 11. Testing

`order_repository_test.dart` exercises `OrderStatusEngine` — i.e. the one piece of test coverage found in this module covers the **orphaned** engine, not the live `OrderService.createOrder`/`updateOrderStatus` path. No test coverage found for the idempotency lock, the stock-deduction transaction, the coupon/wallet/tip total calculation in `CartProvider`, or `verifyAndDeliverOrder`'s OTP/geofence check.

## 12. Production Readiness

The live path (`OrderService` + `OrderProvider` + `CartProvider`/`CartSyncService`) is functionally solid for the common case: it has real idempotency guards, real operating-hours/geofence/slot checks, and a correctly-transactional stock deduction. It is not production-hardened against OTP brute-forcing, and the cancellation→refund linkage is unconfirmed and likely missing. The existence of a more rigorous, fully-built alternate engine sitting completely unused is the single most important structural fact about this module — it represents wasted, possibly more-correct engineering effort that should inform the implementation plan rather than be re-discovered as a surprise later.

---

## Final Output Format

### Current State Audit
One live, self-contained order engine (`OrderService`) handles all real checkout and most lifecycle transitions, wired correctly to both checkout screens and all staff/delivery screens found. A second, more rigorous engine (`OrderBusinessLogic`/`OrderStatusEngine`/`InventoryRepository`) is fully built but has zero live callers. A third engine (`OrderWorkflowEngine`, Postgres-backed) is wired to exactly three edge-case screens, against a data surface whose relationship to the live Firestore orders is unconfirmed. Cart management itself (`CartProvider`/`CartSyncService`) is clean and single-path — the only module so far with no fragmentation in its own primary subsystem.

### Missing Components
1. Brute-force lockout + security-event logging on `OrderService`'s live OTP delivery verification (exists only in the dead engine).
2. Confirmed wallet-refund-on-cancellation in the live path (exists only in the dead engine's `_processRefundAsync`).
3. Resolution of whether `OrderWorkflowEngine`'s Postgres `orders` table is the same order as the Firestore one, or disconnected.
4. Real Firestore-coupon comparison inside `autoOptimizeCoupons` (currently hardcoded to 2 codes).
5. Confirmation that `migrateGuestCart`'s placeholder `stockQuantity: 999` is actually refreshed before checkout, or removal of the placeholder in favor of an immediate re-fetch.
6. A decision on `OrderBusinessLogic`/`OrderStatusEngine`/`InventoryRepository`/`OrderRepository.createOrderWithInventoryUpdate`: migrate to it, or delete it. Leaving a more-correct unused engine beside the live one is itself the risk.

### Architecture Design
Treat `OrderService` as the system of record going forward (it is the one with real screen wiring) and port the dead engine's three genuinely better primitives into it: (a) OTP attempt-lockout + `SecurityEventService` logging inside `verifyAndDeliverOrder`, (b) wallet-refund-on-cancel inside `updateOrderStatus(..., 'cancelled')`, (c) the 30-day return-window check inside `createReturnRequest`. Once ported, delete `OrderBusinessLogic`, `OrderStatusEngine`, `OrderRepository.createOrderWithInventoryUpdate`, and (pending Module 4's own resolution) `InventoryRepository` if nothing else is found to need it — don't leave the more-correct implementation as permanent dead code. Separately, resolve `OrderWorkflowEngine`'s Postgres-vs-Firestore relationship before touching Module 9 (Delivery); if it is genuinely a separate parallel system, either retire it in favor of Firestore-side equivalents for reschedule/escalation/partial-fulfillment, or build the missing Firestore↔Postgres order sync explicitly.

### Implementation Plan
1. Add attempt-count lockout + `SecurityEventService.logEvent(otpFailure/otpLockout)` to `OrderService`'s delivery-OTP verification, copying the exact pattern already proven in `OrderBusinessLogic.markDelivered`.
2. Add a wallet-refund step to `OrderService.updateOrderStatus` when transitioning to `cancelled`, copying `OrderBusinessLogic._processRefundAsync`'s idempotent refund-request + `WalletService().addToWallet` pattern.
3. Trace `SupabaseDatabaseService`/`OrderWorkflowEngine`'s `orders` table writes back to their origin — confirm whether anything populates it from the same checkout flow, or whether `delivery_reschedule_screen.dart`/`failed_delivery_escalation_screen.dart` are reading orphaned data.
4. Replace `autoOptimizeCoupons`'s hardcoded 2-code comparison with a real Firestore `coupons` query, reusing `applyCouponDynamic`'s existing lookup logic.
5. Verify/fix `migrateGuestCart`'s placeholder stock refresh; if unconfirmed, force an immediate stock re-fetch right after migration instead of deferring to "next load."
6. Once 1–2 are ported and confirmed working, delete `order_business_logic.dart`, the unused parts of `order_status_engine.dart`, `OrderRepository.createOrderWithInventoryUpdate`, and coordinate with the Module 4 backlog item on `InventoryRepository`'s fate.
7. Add test coverage for `OrderService.createOrder`'s idempotency lock, stock-deduction transaction, and `CartProvider`'s total/discount calculation — currently the only existing test (`order_repository_test.dart`) covers the engine being recommended for deletion.

### File-by-file Changes
- `lib/services/order_service.dart` — add OTP lockout/logging (step 1), wallet refund on cancel (step 2).
- `lib/providers/cart_provider.dart` — replace hardcoded coupon comparison in `autoOptimizeCoupons` (step 4); fix/confirm `migrateGuestCart` stock refresh (step 5).
- `lib/services/order_business_logic.dart`, `lib/services/order_status_engine.dart`, `lib/repositories/order_repository.dart`, `lib/repositories/inventory_repository.dart` — delete once steps 1–2 are ported and verified (step 6), pending Module 4 reconciliation.
- `lib/services/order_workflow_engine.dart`, `lib/services/supabase_database_service.dart` — investigate Postgres/Firestore relationship (step 3); fix or retire based on findings.
- New/extended test files for `OrderService.createOrder` and `CartProvider` (step 7).

### Production Checklist
- [ ] Live delivery-OTP verification has brute-force lockout + security logging
- [ ] Live order cancellation triggers a confirmed wallet refund
- [ ] `OrderWorkflowEngine`'s Postgres order data is confirmed in-sync with (or explicitly separate from and justified vs.) the live Firestore order
- [ ] No dead order-lifecycle engine left more correct than the live one without an explicit decision recorded
- [ ] Coupon auto-optimization compares real available coupons, not 2 hardcoded codes
- [ ] Guest-cart migration's placeholder stock values are refreshed before checkout, not deferred indefinitely
- [ ] Automated tests cover the live checkout transaction, not only the engine being recommended for deletion
