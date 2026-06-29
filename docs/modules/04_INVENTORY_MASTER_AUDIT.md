# Module 4: Inventory Facilities — Master Implementation + Audit

**Status:** Audit complete. Findings confirmed by reading live code. No code changes made in this pass.
**Date:** 2026-06-19
**Files read in full:** `lib/repositories/inventory_repository.dart` (218 lines), `lib/services/inventory_ledger_service.dart` (139 lines), `lib/services/inventory_sync_service.dart` (591 lines), `lib/models/inventory_model.dart` (94 lines), `lib/services/order_status_engine.dart` (targeted sections), `lib/services/pos/inventory_service_fixed.dart`, `functions/src/inventory/deductInventoryAtomic.ts` (targeted sections), `INVENTORY_RACE_CONDITION_FIX.md` (targeted sections)
**Files spot-checked:** `lib/services/inventory_automation_service.dart`, `lib/services/inventory_query_service.dart`, `lib/services/inventory_alert_service.dart`, `lib/services/product_service.dart` (grepped for `inventory` collection writes — none found)
**Cross-cutting greps run:** `class.*Inventory|class.*Stock` (31 files surfaced), `collection('inventory')` (1 file: `inventory_repository.dart` only), `InventoryRepository()` (1 call site: `order_status_engine.dart`), `InventoryServiceFixed()`/`deductInventorySafe`/`deductInventoryAtomic` (0 call sites in `lib/` outside the orphaned service's own file)

---

## 1. Business Requirements

Inventory must answer one question correctly, at all times, under concurrent load: "how many units of this product can I sell right now?" That number has to survive simultaneous orders without going negative, has to move correctly through the physical lifecycle of a unit (available → reserved at checkout → committed at packing → released back on cancellation → optionally quarantined for QC → optionally written off as damaged), and has to be auditable — every change should be traceable to a cause. Given the standing project rule that bulk stock changes must go through an approval gate, the system also needs exactly one place where "the current stock number" lives, so that gate has something single and authoritative to govern.

## 2. User Workflow

There is no single inventory workflow in this codebase — there are **three, built independently, touching different data, with only one actually wired into the live order path**:

**Workflow A — Order-lifecycle reservation (live, wired):** Customer checks out → `OrderStatusEngine` calls `InventoryRepository.reserveInventory` (available→reserved) → order is packed → `commitInventory` (reserved→committed) → order is cancelled at any point → `restoreInventory` (back to available, from either reserved or committed) → optional `qcInventory`/`markDamaged` for quality holds. This is a genuinely well-built Firestore-transaction state machine. It operates entirely on a Firestore collection named `inventory`, keyed `{productId}_{branchId}`.

**Workflow B — Direct legacy stock field (live, wired, completely separate):** Scanner-driven physical events (Module 3: `receiveInventory`, `reportDamage`, `processReturn`, `receiveTransfer`) and owner-driven bulk edits (`InventorySyncService.batchUpdateInventory`) write directly to `products.stockQuantity` via `FieldValue.increment`/batch `.update`. This is what customer-facing screens, low-stock alerts, and `InventoryAutomationService`'s reorder logic actually read.

**Workflow C — Approval-gated ledger (built, partially wired, disconnected from A and B):** `InventoryLedgerService` writes to Postgres `inventory_events`/`change_requests`/`bulk_operations`, explicitly designed (per its own header comment) to "prevent direct modification of inventory stock." It's consumed by `ApprovalWorkflowService` (Module 2), `packing_service.dart`, and the owner's bulk-query screen — but never reads or writes anything in Workflow A's `inventory` collection or Workflow B's `products.stockQuantity`.

A fourth, fully-built mechanism — pessimistic-lock Cloud Function deduction via `InventoryServiceFixed.deductInventorySafe` — exists, is documented as "Implementation Complete," and is **never called from anywhere in the order-creation path** (see Section 10).

## 3. UI Screens

- `inventory_screen.dart`, `inventory_audit_screen.dart` (owner + employee variants), `inventory_alerts_screen.dart`, `bulk_inventory_query_screen.dart` / `inventory_bulk_query_screen.dart`, `inventory_approval_queue_screen.dart`, `barcode_inventory_screen.dart`, `inventory_receiving_screen.dart` (owner + employee variants), `inventory_transfer_screen.dart` — all of these read/write `products.stockQuantity` (Workflow B) or the Postgres ledger (Workflow C). None of them read or write the `inventory` collection (Workflow A).
- `low_stock_alerts_card.dart`, `inventory_automation_widget.dart` — dashboard widgets driven by `InventoryAutomationService`, which reads `products.stockQuantity` exclusively.
- No screen anywhere in the app displays `availableStock`/`reservedStock`/`committedStock`/`qcStock`/`damagedStock` (the `inventory` collection's actual fields) to any owner or employee. The state machine that runs on every single order is, today, completely invisible in the UI.

## 4. Backend Architecture

- `InventoryRepository` — the only code in the entire codebase that touches the `inventory` Firestore collection (confirmed via exhaustive grep). Implements `getInventory`, `reserveInventory`, `commitInventory`, `restoreInventory` (with a `fromState` parameter handling the "cancelled after packing" edge case correctly), `qcInventory`, `markDamaged`. Every mutating method runs inside `_firestore.runTransaction`, re-reads current state inside the transaction, validates, and writes a parallel record to `inventory_movements`. This is the best-engineered single piece of code found across all four modules audited so far.
- `OrderStatusEngine` — the only caller of `InventoryRepository` (confirmed via grep: one call site). Invokes `reserveInventory`/`commitInventory`/`restoreInventory`/`qcInventory` at the appropriate order-status transitions. Never touches `products.stockQuantity`.
- `InventorySyncService` — a real-time listener/cache/dashboard-stats layer over `products.stockQuantity`: `watchInventoryMetrics`, `watchLowStockProducts` (client-side filtered, since Firestore can't compare two fields server-side), `watchAvailableProducts`, `watchProductsByBranch` (reads yet another stock representation: a `branchStock` map field directly on the product document). Also exposes `batchUpdateInventory`, a direct ungated bulk write to `products.stockQuantity`.
- `InventoryAutomationService` — reads `products.stockQuantity` for every active product, computes demand velocity, reorder point, and EOQ, and writes alerts to `inventory_alerts`. Entirely independent of both `InventoryRepository` and `InventoryLedgerService`.
- `InventoryLedgerService` — Postgres-side (`RDSDatabaseService`/RDS) approval-gate and event ledger: `submitChangeRequest`, `submitBulkOperation`, `recordInventoryEvent`, `getProductLedger`. Writes to `change_requests`/`bulk_operations` — the same two tables already implicated in Module 2's `ApprovalWorkflowService` finding (including that service's P0 SQL-injection bug in its `entityType == 'inventory'` branch). Two independent service classes write change requests for inventory into the same Postgres tables with no apparent coordination between them.
- `InventoryServiceFixed` + Cloud Function `deductInventoryAtomic` — a fifth, fully-built mechanism: pessimistic locking via a `product_locks` Firestore collection, guarding a transactional deduction of `products.stockQuantity`. Self-documented ("PRIMARY method for deducting stock during order creation") and backed by `INVENTORY_RACE_CONDITION_FIX.md` (status: "Implementation Complete," severity: "CRITICAL — Blocks all subsequent phases") and a dedicated stress test (`test/stress_test_inventory_race_condition.dart`). Confirmed via grep: zero call sites anywhere in `lib/` outside its own file. Built to fix a real, correctly-diagnosed bug, then never wired in.

## 5. Database Schema

- `products.stockQuantity` (Firestore field, int) — legacy/primary customer-facing stock number. Also `products.branchStock` (map, per-branch override, read by `watchProductsByBranch`). Mutated by: `EmployeeScannerService` (Module 3), `InventorySyncService.batchUpdateInventory`, and (if it were ever wired in) the `deductInventoryAtomic` Cloud Function.
- `inventory/{productId}_{branchId}` (Firestore collection) — `availableStock`, `reservedStock`, `committedStock`, `qcStock`, `damagedStock`, `minimumStock`, `updatedAt`. Mutated exclusively by `InventoryRepository`, called exclusively by `OrderStatusEngine`. **No code anywhere creates a document in this collection** — `reserveInventory`/`commitInventory`/`markDamaged` all `transaction.update()` an existing doc and explicitly throw `Exception('Product ... not found in inventory.')` if the doc doesn't exist (see Section 10).
- `inventory_movements` (Firestore collection) — immutable ledger written by every `InventoryRepository` transition (`RESERVATION`/`COMMITMENT`/`RELEASE`/`QC_MOVE`/`DAMAGE`).
- `inventory_alerts`, `shops/{shopId}/inventory_alerts` — two differently-scoped alert collections written by `InventoryAutomationService` (top-level, keyed by productId) and `InventoryAlertService` (shop-scoped) respectively — a sixth minor fragmentation, lower stakes than the stock-quantity split but still duplicated effort.
- `inventory_events`, `change_requests`, `bulk_operations` (Postgres/RDS tables) — written by `InventoryLedgerService`; `change_requests`/`bulk_operations` shared with Module 2's `ApprovalWorkflowService`.
- `product_locks` (Firestore collection) — used only by the orphaned `deductInventoryAtomic` Cloud Function.

## 6. Service Layer

Five independent service-layer stacks exist for "change the stock number," with two different Firestore collections, one map field, one Postgres ledger, and one orphaned Cloud-Function-backed lock mechanism — none of which call each other or reconcile with each other at write time. The single read-time bridge that exists is a one-way fallback: `InventoryModel.fromMap` reads `availableStock` and, if absent, falls back to reading the (irrelevant, differently-scoped) `stockQuantity` key from the same map — a patch that only matters if both fields happen to be present on the same document, which they structurally never are since they live in different collections.

## 7. Integration Points

- Firestore: `products`, `inventory`, `inventory_movements`, `inventory_alerts`, `shops/{shopId}/inventory_alerts`, `shops/{shopId}/products/.../sales_history`, `product_locks`, `orders`.
- Postgres/RDS: `inventory_events`, `change_requests`, `bulk_operations` via `RDSDatabaseService`.
- Cloud Functions: `deductInventoryAtomic` (built, unused).
- Notification integration: `InventoryAutomationService` pushes FCM alerts to the owner on threshold breach; `InventoryAlertService` (shop-scoped variant) sends its own notifications via `NotificationService`.
- Downstream consumers of "current stock": customer-facing product screens and `InventoryAutomationService`'s reorder math read `products.stockQuantity` only; `OrderStatusEngine`'s reservation logic reads `inventory` collection only. These two consumer sets are reading two different numbers that are never synchronized.

## 8. Automation

- **EOQ-based reorder suggestions:** `InventoryAutomationService` computes demand velocity over a 30-day window and an Economic Order Quantity, attaching a `suggestedOrderQty` to every alert — a genuinely useful, well-built feature, undermined only by reading a stock number (`products.stockQuantity`) that the live order flow never decrements.
- **Multi-tier alerting:** LOW → CRITICAL → OUT_OF_STOCK thresholds with FCM push, plus separate expiry-proximity checks (14-day/3-day warnings).
- **Auto-restoration on cancellation:** `InventoryRepository.restoreInventory`'s `fromState` parameter correctly handles releasing stock back to available whether the order was cancelled before or after packing — a correct, non-obvious piece of business logic.
- **None of the automation above is aware of the other stock-tracking surfaces** — an out-of-stock alert can fire based on `products.stockQuantity` while the `inventory` collection (if it were populated) shows healthy `availableStock`, or vice versa.

## 9. Security

- `InventoryRepository`'s transactions are well-formed: every mutation re-reads inside the transaction (no stale-read race), validates before writing, and never allows a state field to go negative (explicit `>= 0` clamps in `commitInventory`/`restoreInventory`/`qcInventory`/`markDamaged`).
- `InventorySyncService.batchUpdateInventory` is an ungated direct bulk write to `products.stockQuantity` with no approval-request creation and no call into `InventoryLedgerService` — the same standing-rule violation already flagged in Module 2 (CSV bulk import) and Module 3 (`EmployeeScannerService`'s direct increments), now confirmed a third and fourth time in this module alone (`batchUpdateInventory` plus the never-wired `deductInventoryAtomic`, which at least has authentication checks).
- `deductInventoryAtomic` (the orphaned Cloud Function) is actually the most defensively-written stock mutator in the codebase: requires `context.auth`, validates all three inputs, uses an explicit 30-second lock timeout to avoid permanent deadlock. It was simply never connected to anything.
- No authorization check exists anywhere gating who can call `InventoryRepository.reserveInventory`/`commitInventory`/etc. directly (they're only ever called from `OrderStatusEngine`, which is itself presumably gated upstream by order-ownership checks not audited in this module).

## 10. Failure Cases

- **P0 — `inventory` collection documents are never created, anywhere, by any code path.** Exhaustive grep for `collection('inventory')` across `lib/` returns exactly one match: `InventoryRepository`'s own collection reference. No `.set()` call against this collection exists anywhere in the codebase — not in `ProductService.addProduct`, not in any receiving/onboarding screen, not anywhere. `reserveInventory` explicitly throws `Exception('Product ${item.productName} not found in inventory.')` when the doc doesn't exist (line 32-34 of `inventory_repository.dart`). **Concretely: for any product that was added through the app's normal product-creation flow and never had an `inventory/{productId}_{branchId}` document manually seeded outside the app, the very first real checkout attempt for that product will throw inside `OrderStatusEngine`'s reservation step.** This is the most severe, concrete, evidence-backed finding across all four modules audited so far — worse than Module 2's SQL injection, because it is plausibly already failing in production on every order for every product that wasn't manually seeded.
- **P0 — Two competing, mutually-unaware mechanisms both claim to be the order-time stock authority.** `OrderStatusEngine` → `InventoryRepository` (Firestore transactions on the `inventory` collection) is the one actually wired in. `InventoryServiceFixed.deductInventorySafe` → Cloud Function `deductInventoryAtomic` (pessimistic lock on `product_locks`, deduction from `products.stockQuantity`) is explicitly self-documented as "the PRIMARY method for deducting stock during order creation" and backed by a dedicated fix-doc marked "Implementation Complete... CRITICAL — Blocks all subsequent phases," yet has zero call sites anywhere in the order-creation path. The race-condition bug this was built to fix (`INVENTORY_RACE_CONDITION_FIX.md`: two concurrent orders both reading stock=5, both deducting, landing on -1) is **not actually fixed in the live path**, because the live path never calls the fix — it calls `InventoryRepository` instead, which has its own correct (transactional) concurrency safety for the `inventory` collection, but does nothing to protect `products.stockQuantity`, which is still mutated unprotected elsewhere (Module 3's scanner increments, `batchUpdateInventory`).
- **P1 — Customer-facing and alerting surfaces read a number the order flow never updates.** `products.stockQuantity` is what `InventoryAutomationService`, `InventorySyncService.watchLowStockProducts/watchAvailableProducts`, and presumably product-detail/listing screens display and reason about. `OrderStatusEngine` never decrements it. A product can show "12 in stock" indefinitely while every unit has actually been reserved/committed against the `inventory` collection (assuming P0 above is somehow resolved and that collection is populated) — stock displayed to customers and used for reorder math is structurally disconnected from real order activity.
- **P1 — Two independent Postgres-writing services for the same change-request tables.** `InventoryLedgerService.submitChangeRequest`/`submitBulkOperation` and Module 2's `ApprovalWorkflowService` both write to `change_requests`/`bulk_operations` with no shared code, raising the same SQL-injection exposure already flagged in Module 2 to a second, parallel code path that has not itself been read in this audit pass and should be checked for the same vulnerability before either is trusted.
- **P2 — Duplicate alert collections.** `inventory_alerts` (top-level, `InventoryAutomationService`) and `shops/{shopId}/inventory_alerts` (shop-scoped, `InventoryAlertService`) appear to serve the same purpose with no apparent deduplication or single source of truth for "is this product currently in an alert state."

## 11. Testing

`test/stress_test_inventory_race_condition.dart` exists and specifically targets the orphaned `deductInventoryAtomic` path — a good test, testing dead code. No test exists covering `InventoryRepository`'s transaction logic (the actually-live path), no test exists asserting that an `inventory` collection document exists for every active product, and no test exists asserting that `products.stockQuantity` and the `inventory` collection's `availableStock` ever agree with each other. A single integration test that creates a product through the normal app flow and then attempts to check out one unit of it would have caught the P0 finding above immediately.

## 12. Production Readiness

**Not production-ready.** The core order-reservation path is built on a Firestore collection that nothing in the codebase populates, meaning the well-engineered `InventoryRepository` state machine is plausibly non-functional today for any product not manually seeded outside the app. A real, correctly-diagnosed, "CRITICAL — blocks all subsequent phases" race-condition fix was built and then never connected. Customer-facing stock display is structurally disconnected from order-driven stock movement. This module needs implementation work, not just hardening, before it can be called functional, let alone production-ready.

---

## Final Output Format

### Current State Audit
Five independent stock-tracking/mutation surfaces coexist: (1) `products.stockQuantity` + `branchStock` map — legacy, customer-facing, mutated by scanner events and ungated bulk updates; (2) the `inventory` Firestore collection — a well-built reserve/commit/restore/QC/damage state machine, wired into the live order-status flow via `OrderStatusEngine`, but never populated by any product-creation or receiving code path; (3) `inventory_movements` — an immutable ledger paired with (2); (4) `inventory_events`/`change_requests`/`bulk_operations` in Postgres via `InventoryLedgerService` — an approval-gate system explicitly built to prevent direct stock modification, sharing tables with (and apparently unaware of) Module 2's `ApprovalWorkflowService`; (5) a pessimistic-lock Cloud Function (`deductInventoryAtomic`) plus Dart wrapper (`InventoryServiceFixed`) — fully built, documented as the primary order-time deduction mechanism, and never called from anywhere.

### Missing Components
1. No code creates an `inventory/{productId}_{branchId}` document for any product — the live order-reservation path has no data to operate on for products created through the normal app flow.
2. `deductInventoryAtomic`/`InventoryServiceFixed` — a built, tested, documented race-condition fix — is not called from `OrderStatusEngine` or anywhere else; the bug it fixes is live everywhere `products.stockQuantity` is mutated outside a Firestore transaction.
3. No reconciliation between `products.stockQuantity` and the `inventory` collection's `availableStock` — they can diverge arbitrarily with no detection.
4. No UI surface displays the `inventory` collection's actual state (`availableStock`/`reservedStock`/`committedStock`/`qcStock`/`damagedStock`) to any owner or employee.
5. `InventorySyncService.batchUpdateInventory` is an ungated direct bulk write, violating the standing approval-gate rule for a fourth confirmed time across the audit series.
6. Two independent Postgres writers (`InventoryLedgerService`, `ApprovalWorkflowService`) target the same `change_requests`/`bulk_operations` tables with no shared validation layer — the second writer has not been checked for Module 2's SQL-injection pattern.
7. Duplicate, non-deduplicated alert collections (`inventory_alerts` vs. `shops/{shopId}/inventory_alerts`).

### Architecture Design
Designate the `inventory` collection + `InventoryRepository` as the single source of truth for sellable stock — it is the best-engineered piece of this module and already correctly wired into the order lifecycle. `products.stockQuantity` should become a derived/cached display field, written only by a single reconciliation path that mirrors `inventory.availableStock`, never mutated independently by scanner events or bulk tools. Retire or repurpose `deductInventoryAtomic`: either delete it (its job is now done by `InventoryRepository`'s own transactions) or, if RDS-side locking is still wanted for a different reason, document why two locking mechanisms coexist. Route `InventorySyncService.batchUpdateInventory` and Module 3's scanner increments through `InventoryLedgerService`'s change-request flow instead of direct writes. Merge the two alert collections into one shop-scoped collection.

### Implementation Plan
1. Add inventory-document creation: when a product is created (`ProductService.addProduct`) or stock is first received (`inventory_receiving_screen.dart` flow), create the corresponding `inventory/{productId}_{branchId}` doc with `availableStock` seeded from the received quantity. This unblocks the entire reservation flow — highest priority, since checkout is plausibly broken today without it.
2. Add a startup/backfill script that creates missing `inventory` docs for all existing products from their current `products.stockQuantity`, so existing inventory isn't lost when item 1 ships.
3. Decide and execute on `deductInventoryAtomic`: delete the Cloud Function, `product_locks` collection usage, and `InventoryServiceFixed`, or repurpose it explicitly and document the decision — do not leave a documented "CRITICAL... Implementation Complete" fix silently unwired.
4. Make `products.stockQuantity` a read-only projection of `inventory.availableStock`, updated only via a single Cloud Function trigger on `inventory` document writes (Firestore triggers, not duplicated client-side logic).
5. Route `InventorySyncService.batchUpdateInventory` through `InventoryLedgerService.submitBulkOperation` instead of a direct batch write.
6. Audit `ApprovalWorkflowService`'s shared-table writes against `InventoryLedgerService`'s for the same SQL-injection class found in Module 2; parameterize both consistently.
7. Merge `inventory_alerts` and `shops/{shopId}/inventory_alerts` into one collection; pick one service (`InventoryAutomationService` or `InventoryAlertService`) as canonical and delete the other or repurpose it for a distinct, non-overlapping use case.
8. Add the integration test described in Section 11 (create product → checkout one unit) to a CI suite so this class of gap fails loudly going forward.

### File-by-file Changes
- `lib/services/product_service.dart` — add `inventory` doc creation in `addProduct`/`batchAddProducts` (step 1).
- `lib/screens/owner/inventory_receiving_screen.dart`, `lib/screens/employee/inventory_receiving_screen.dart` — create/increment the `inventory` doc on receipt, not just `products.stockQuantity` (step 1).
- New one-off backfill script, e.g. `scripts/backfill_inventory_collection.dart` (step 2).
- `functions/src/inventory/deductInventoryAtomic.ts`, `lib/services/pos/inventory_service_fixed.dart`, `test/stress_test_inventory_race_condition.dart` — delete or explicitly repurpose with updated documentation (step 3).
- New Cloud Function trigger, e.g. `functions/src/inventory/syncStockQuantityProjection.ts`, replacing direct `stockQuantity` writes (step 4).
- `lib/services/inventory_sync_service.dart` — remove direct `batch.update` in `batchUpdateInventory`; call `InventoryLedgerService.submitBulkOperation` instead (step 5).
- `lib/services/approval_workflow_service.dart`, `lib/services/inventory_ledger_service.dart` — parameterize all raw SQL (step 6).
- `lib/services/inventory_automation_service.dart`, `lib/services/inventory_alert_service.dart` — consolidate (step 7).
- New test, e.g. `test/integration/checkout_inventory_flow_test.dart` (step 8).

### Production Checklist
- [ ] Every active product has a corresponding `inventory/{productId}_{branchId}` document
- [ ] Checkout for a freshly-created product succeeds without manual data seeding
- [ ] Exactly one mechanism deducts/reserves stock at order time — `deductInventoryAtomic` removed or its coexistence with `InventoryRepository` explicitly documented
- [ ] `products.stockQuantity` is a derived projection, not an independently-mutated field
- [ ] No direct bulk write to `products.stockQuantity` bypasses the approval-gate ledger
- [ ] `ApprovalWorkflowService` and `InventoryLedgerService` both confirmed free of SQL injection on shared tables
- [ ] One canonical low-stock alert collection, not two
- [ ] Integration test covers create-product → checkout → stock-decremented end-to-end
