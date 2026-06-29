# Master Gap & Fix Backlog — Modules 1-10

Consolidated from the 17-module audit series (`docs/modules/01_*.md` through `10_*.md`). Every item below was confirmed by reading live code/rules, not inferred. None are fixed yet. Grouped by module, priority-tagged. A recurring architecture smell shows up in every module: the same business operation is implemented 2-5 times in parallel, usually with only one version actually wired to a live screen.

## Module 1 — Auth
- **P0-1.1** `firestore.rules` `users/{userId}` update rule has no field lock — a customer can self-write `role: 'owner'` onto their own doc. Add a guard so `role` can't change except via admin write.
- **P0-1.2** No Firestore rules for `active_sessions`, `owners`, `employees`, `pre_authorized_users`. Add explicit scoped rules; verify against deployed rules, not just the file.
- **P0-1.3** Postgres `users.role` check constraint missing `shopOwner, admin, deliveryAgent, supplier, franchiseOwner` — dual-write fails for those roles. Migrate the constraint.

## Module 2 — Product Management
- **P0-2.1** SQL injection in `approval_workflow_service.dart` `approveRequest()`, `entityType == 'inventory'` branch — raw value interpolation into `UPDATE inventory SET $updates`. Parameterize like the `product` branch right below it does.
- **P0-2.2** Three independent product/inventory write paths (`ProductService` direct writes, `InventoryChangeRequestService` Firestore approval gate, `ApprovalWorkflowService` Postgres approval gate) don't call each other. CSV bulk import (`products_management.dart`) calls `ProductService.batchAddProducts` directly, bypassing both approval systems — violates the standing "bulk changes must go through approval" rule. Route bulk import through one approval gate.
- **P1-2.3** `ProductService.updateProduct`'s generic field-map update can change `price` directly, bypassing the dedicated `price_change_proposals` approval flow that exists for exactly this.

## Module 3 — Scanner
- **P0-3.1** `ScanMode.returnItem`/`damageItem` are selectable Hub tiles for owner/employee but have no case in `_routeAction` — both dead-end to "Unknown Code" even though the underlying service methods work fine via a different screen. Add the two missing switch cases (lowest-risk fix in this module — screens already exist).
- **P1-3.2** `ScanMode.riderScan` is parsed but has no Hub tile and no `_routeAction` case — fully orphaned. Wire it or delete it.
- **P1-3.3** Stock-mutating scanner methods (`receiveInventory`, `reportDamage`, `processReturn`) have no authorization check, unlike `receiveTransfer`'s correctly-built one. Copy that pattern.

## Module 4 — Inventory
- **P1-4.1** (downgraded per Module 5 correction — affects only the dead `OrderStatusEngine` path, not live checkout) `InventoryRepository.reserveInventory` throws if `inventory/{productId}_{branchId}` doesn't exist; nothing ever creates that doc. Add upsert-on-create plus a backfill script — needed before this subsystem could ever be safely revived.
- **P1-4.2** `InventoryServiceFixed.deductInventorySafe`/Cloud Function `deductInventoryAtomic` (pessimistic-lock race-condition fix, self-documented "CRITICAL... Implementation Complete") has zero callers. Decide: wire it into the live stock-deduction path, or delete it.
- **P1-4.3** `InventorySyncService.batchUpdateInventory` is a 4th ungated bulk-write path directly to `products` — same violation as 2.2, fix together.
- **P2-4.4** Duplicate, unreconciled low-stock alerting (`InventoryAutomationService` vs `InventoryAlertService`) — merge.

## Module 5 — Cart / Order Placement
- **P0-5.1** Four competing order-creation engines exist; only `OrderService.createOrder` is live. The dead `OrderBusinessLogic`/`OrderStatusEngine` engine has better primitives (OTP lockout, wallet refund-on-cancel, return-window check). Decide once: port those 3 primitives into `OrderService` and delete the dead engine, or migrate live screens onto the dead engine. Don't leave both.
- **P1-5.2** Live OTP delivery verification (`OrderService.verifyAndDeliverOrder`) has no brute-force lockout, unlike the dead engine's version.
- **P2-5.3** `CartProvider.autoOptimizeCoupons` only checks 2 hardcoded codes, not real Firestore coupons.

## Module 6 — Coupons
- **P0-6.1** **FIXED 2026-06-20**: `coupons` Firestore collection had no security rule at all. Added `match /coupons/{couponId} { allow read: if isSignedIn(); allow write: if isSignedIn() && isGlobalAdmin(); }`. Still need to verify in a live build that `CartProvider.applyCouponDynamic` now reaches real coupons instead of its hardcoded fallback.
- **P0-6.2** Discount-type vocabulary mismatch: model only recognizes `'percentage'`/`'flat'`, but the only creation UI saves `'fixed'` — every "Fixed Amount" coupon computes ₹0 discount. Reconcile the vocabulary; backfill any already-written `'fixed'` coupons.
- **P1-6.3** Orders never record which coupon was used or how much it discounted — no `couponCode` field on `OrderModel`. Add it, persist it in `OrderService.createOrder`.
- **P1-6.4** No usage-limit/redemption-tracking schema (`usageLimit`, `perUserLimit`, `usedCount`) — "FIRST20" can be reused without limit.

## Module 7 — Payment
- **P0-7.1** **FIXED 2026-06-20**: Wallet-paid orders (`WalletProvider.payWithWalletAndCreateOrder`) never deducted stock. Fixed by changing `checkout_screen.dart`'s wallet-payment branch to call `OrderProvider.createOrder` (→ `OrderService.createOrder`) with `walletAmountUsed` set to the full total, instead of the separate `payWithWalletAndCreateOrder` path — gets stock deduction + wallet debit atomically via the same canonical transaction every other payment method uses.
- **P0-7.2** `StripeService` (213 lines), `PaymentMethod.stripe` enum value, validator branches, and `flutter_stripe` pubspec dependency all exist — direct violation of the standing no-Stripe rule. Delete all of it; confirm no UI still renders a Stripe option afterward.
- **P1-7.3** Wallet payment failures are only `debugPrint`d — no `security_events` write, no retry queue, no mirroring into the shared `payments` ledger.

## Module 8 — Packaging
- **P0-8.1** Two live, UI-reachable packing workflows write to different Firestore paths with incompatible status formats (qualified `'OrderStatus.packed'` on top-level `orders/{id}` vs bare `'packed'` on `shops/{shopId}/orders/{id}`). Decide Workflow A's fate: delete it, or fix its writes to match Workflow B's path+format. Highest-impact fix in this module.
- **P0-8.2** A third, fully-built "V2" fulfillment workflow double-deducts stock if ever wired up (it calls `InventoryLedgerService.recordInventoryEvent` on top of the deduction `OrderService.createOrder` already did). Strip the ledger call or delete the V2 path before anyone connects a screen to it.
- **P2-8.3** Dead duplicate screen file `lib/screens/owner/order_packing_screen.dart` — delete.

## Module 9 — Delivery
- **P0-9.1** **FIXED 2026-06-20**: `DeliveryProvider`'s rider order queries used bare status strings against the qualified form live packing writes — fixed the 3 listener queries, `acceptOrder`'s write, and made `updateDeliveryStatus` defensively qualify bare input. `markDeliveryFailed` still writes an unparseable `'failedDelivery'` (not a valid `OrderStatus` enum value at all) — needs a model change, not fixed.
- **P0-9.2** Three services (`DeliveryService`, `DeliveryLastMileService`, `FleetService`) write conflicting document shapes to the same `deliveries/{id}` docs, and `FleetService` itself mixes bare/qualified status strings internally. Consolidate around `DeliveryService` as sole writer.
- **P0-9.3** **FIXED 2026-06-20**: added scoped rules for all 10 `delivery*` collections (deliveries, delivery_agents, delivery_assignments, delivery_otp, delivery_locations, delivery_tracking, delivery_events, delivery_exceptions, delivery_sla_rules, delivery_slots) in `firestore.rules`. Schema fields (riderId/customerId/branchId on each doc) were inferred from naming convention, not all confirmed against actual writes — re-verify field names against `DeliveryService`/`FleetService`/`DeliveryLastMileService` before relying on this in production.
- **P1-9.4** Dual uncoordinated order assignment (rider self-accept vs. automatic nearest-agent dispatch) can both fire on the same order with no lock.
- **P2-9.5** Offline status-update queue is a non-functional stub (`debugPrint` only) — updates made while offline are silently lost.

## Module 10 — Wallet & Refunds
- **P0-10.1** Client can self-write its own `walletBalance` directly via a permissive `users/{userId}` update rule plus a `users/{userId}/{document=**}` catch-all — the top-level `wallet_transactions` rule that claims to lock this down protects a path nothing in the app uses. Restrict field-level updates on `users/{userId}` and add a real rule for the actual subcollection path.
- **P0-10.2** ~~Double-refund~~ **CORRECTED + FIXED 2026-06-20**: was misdiagnosed — `OrderProvider.cancelOrder` actually calls `OrderService.updateOrderStatus` (no refund logic), not the dead `OrderBusinessLogic`. Real bug: `order_detail_screen._cancelOrder()` only called `CancellationFeeService.applyAndRefund()` when `fee > 0`, so zero-fee (early) cancellations got NO refund at all. Fixed by removing the `if (feeResult.fee > 0)` gate.
- **P0-10.3** Stock never restored on order cancellation (`// TODO` stub). Port the working logic from the dead `processRefundWithStockRestore` Cloud Function.
- **P0-10.4** `RefundProcessingScreen` (728 lines, real Razorpay/RazorpayX integration) has zero router entries or navigation call sites anywhere — no owner can ever reach it. Same for `settlements_management.dart`/`settlement_reporting_screen.dart`. Wire them into `app_router.dart`.
- **P1-10.5** `RefundStatusEngine.transitionRefundStatus` never actually credits the wallet for `RefundMethod.wallet` refunds, even once the screen above is reachable.
- **P1-10.6** `WalletProvider.payWithWalletAndCreateOrder` reimplements debit logic inline with no idempotency pre-check — retry risk.

## Cross-cutting patterns to fix once, not per-module
- **Status-string serialization**: some writers use bare enum names (`'packed'`), others use qualified `toString()` (`'OrderStatus.packed'`); parsers generally expect the qualified form. Confirmed broken on at least 3 collections (orders/packing, orders/delivery, orders/refund). Worth a single sweep + lint rule rather than fixing one call site at a time.
- **Missing Firestore rules**: confirmed entirely absent for `coupons`, 10 `delivery*` collections, `refund_audit_logs`/`refund_logs`/`return_requests`/`inventory_events`/`cancellation_fee_ledger`, `active_sessions`/`owners`/`employees`/`pre_authorized_users`. Worth one consolidated rules-file pass.
- **Bulk-write-bypasses-approval**: confirmed at 4 independent sites (CSV product import, scanner stock increments, `InventorySyncService.batchUpdateInventory`, and implicitly anywhere `ProductService` is called directly). One policy fix (route everything through `InventoryChangeRequestService`) closes all 4.
- **"N competing engines, 1 live" pattern**: order creation (5 engines), packing (3 workflows), refunds (6 subsystems), delivery (5 paths). Each needs its own one-time consolidation decision; there's no single fix that closes all of these.
