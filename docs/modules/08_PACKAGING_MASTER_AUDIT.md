# Module 8: Packaging Facilities — Master Implementation + Audit

Part of the 17-module Fufaji Store facility audit series. Status: **audit complete, no fixes applied yet.** "Packaging" has no literal filename convention in the codebase (zero `*packag*` matches in `lib/` or `functions/src/`) — the functionality is built under "packing"/"fulfillment" naming, across 64 grep-matched files. Findings confirmed by reading live code: `lib/services/packing_service.dart` (702 lines, full read), `lib/providers/fulfillment_provider.dart` (454 lines, full read), `lib/utils/app_router.dart`, `lib/screens/owner/packing_terminal_screen.dart`, `lib/screens/owner/packing_dashboard_screen.dart`, `lib/screens/owner/order_packing_screen.dart`, `lib/screens/employee/order_packing_screen.dart`, `lib/screens/employee/packing_screen.dart`, `lib/models/order_model.dart`, `lib/services/inventory_ledger_service.dart`, plus call-site greps across `lib/screens/employee/employee_dashboard.dart`, `order_queue_screen.dart`, `employee_home_screen.dart`, `unified_scanner_hub.dart`, `task_priority_screen.dart`.

## 1. Business Requirements

After an order is confirmed and paid, an employee must physically pick, weigh, and pack the items, optionally flag damaged/out-of-stock items, and hand off a "ready for pickup/dispatch" order to delivery. Owners need visibility into packing progress, timing, and quality. No written requirements doc exists — reverse-engineered from code.

## 2. User Workflow

**Three independent, live workflows exist for the same real-world task**, reachable from different entry points depending on which screen an employee or owner happens to use:

- **Workflow B (order-doc-embedded, the most-wired path):** Owner opens `PackingTerminalScreen` (`/owner/packing-terminal` or `/owner/packing/:orderId`) or an employee opens `OrderPackingScreen` (employee folder; named route `packing`, or direct push from `employee_home_screen.dart`, `unified_scanner_hub.dart`, `task_priority_screen.dart`). These read/write `OrderModel.packingStatus`/`packingProof`/`packingHistory` fields directly on the **top-level** `orders/{orderId}` document, with an approval step (`packingStatus == 'pending_approval'` → owner reviews photo proof in `PackingTerminalScreen._buildReviewPanel` → finalizes via `_finalizePacking`).
- **Workflow A (legacy, also live):** An employee opens `PackingScreen` (employee folder) from `employee_dashboard.dart` or `order_queue_screen.dart` via direct `Navigator.push` (not a named route). This is built entirely on `FulfillmentProvider`, a `ChangeNotifier` that queries/writes the `fulfillment_tasks` Firestore collection (`FulfillmentTask` model, index-based `FulfillmentStatus` enum) — completely independent of Workflow B, and it updates order status by writing to **`shops/{shopId}/orders/{orderId}`** (a different document path than Workflow B's top-level `orders/{orderId}`).
- **Workflow C (newest, fully orphaned):** `PackingService`'s `*V2` methods (`markItemPackedV2`, `completePackingV2`) operate on a third collection, `fulfillment_tasks_v2` (`FulfillmentTaskModel`, string-based status), and are the only packing code that integrates with the Postgres inventory ledger. Grep across every screen file found zero references to `FulfillmentTaskModel` or any `*V2` method — this generation was built but never wired to any UI.

There is also a dead duplicate file: `lib/screens/owner/order_packing_screen.dart` shares its class name with the employee-folder `OrderPackingScreen` but has zero callers anywhere in the codebase (confirmed via grep) — pure orphaned leftover.

## 3. UI Screens

- `owner/packing_terminal_screen.dart` — owner packing UI with live timer, item weights, review/approval panel for photo proof. Router-wired (Workflow B).
- `owner/packing_dashboard_screen.dart` — owner overview list, queries `orders` where `status == OrderStatus.packed.toString()`. Router-wired (Workflow B).
- `employee/order_packing_screen.dart` — employee packing UI, writes `packingStatus`. Router-wired + 3 direct-push call sites (Workflow B).
- `employee/packing_screen.dart` — employee packing UI built on `FulfillmentProvider`. Not router-wired; reached only via direct `Navigator.push` from `employee_dashboard.dart` and `order_queue_screen.dart` (Workflow A).
- `owner/order_packing_screen.dart` — dead duplicate, zero callers.
- `employee/quality_check_screen.dart`, `employee/dispatch_scanner_screen.dart`, `employee/damage_reporting_screen.dart` — adjacent screens implied by `PackingService.getQualityReport`/`FulfillmentStatus.qualityChecked`, not read this module; flagged for a future pass if Workflow A is kept.

## 4. Backend Architecture

No single packing/fulfillment service exists. Three backend implementations coexist inside the same singleton class plus one separate provider: `PackingService` (`lib/services/packing_service.dart`) contains both V1 methods (`assignOrderToEmployee`, `getPickList`, `markItemPacked`, `completePacking`, `rejectTask`, `getQualityReport`, `getAverageDuration`, `getEmployeeStats`) operating on `fulfillment_tasks`/`FulfillmentTask`, and V2 methods (`markItemPackedV2`, `completePackingV2`) operating on `fulfillment_tasks_v2`/`FulfillmentTaskModel`. `FulfillmentProvider` (`lib/providers/fulfillment_provider.dart`) is a third, fully independent implementation that duplicates V1-style logic against the same `fulfillment_tasks` collection via its own direct Firestore calls — it never calls `PackingService` at all. Meanwhile the actual router-wired screens (`PackingTerminalScreen`, `PackingDashboardScreen`, employee `OrderPackingScreen`) bypass all three of the above and write directly to `OrderModel` fields on the order document itself — a fourth, simplest implementation with no dedicated service class at all.

## 5. Database Schema

Three parallel schemas track the same conceptual "is this order packed" state:
- `orders/{id}.packingStatus` (`'pending_approval' | 'approved' | 'rejected'`), `.packingProof` (map: `photoUrl`, `packedBy`, `packedAt`), `.packingHistory`, `.packingStartedAt`/`.packingCompletedAt`, plus the simpler `OrderStatus.packed` enum value and legacy `.isPacked` bool — all on the same `OrderModel`. (Workflow B/D.)
- `fulfillment_tasks/{id}` — `FulfillmentTask` model, index-based `FulfillmentStatus` (`assigned/packing/ready/qualityChecked/completed/rejected`). (Workflow A.)
- `fulfillment_tasks_v2/{id}` — `FulfillmentTaskModel`, string status (`'NEW'/'IN_PROGRESS'/'QUALITY_CHECK'/'COMPLETED'/'REJECTED'`). (Workflow C, orphaned.)
- `package_processing/{id}` — a Firestore mirror written only by `markItemPackedV2`, "for offline support" per its own comment — since Workflow C has no caller, this collection is never populated in practice today.

None of these four schemas reference each other (no shared `orderId`-keyed join logic that reconciles state across them).

## 6. Service Layer

`PackingService` is a `factory`-based singleton holding both V1 and V2 method sets in one class, despite operating on entirely different collections and models — this is an unusual pattern compared to every other module's services, where competing implementations at least lived in separate files. `FulfillmentProvider` independently re-implements V1-equivalent logic (`loadAssignedOrders`/`streamAssignedOrders`, `startPacking`, `markItemPacked`, `verifyItem`, `completePacking`, `startQualityCheck`, `approveQuality`/`rejectQuality`, `loadTodayStats`/`updateDailyStats` for `EmployeeDailyStats` aggregates) against the same `fulfillment_tasks` collection, with no delegation either direction.

## 7. Integration Points

- **Inventory:** `PackingService.markItemPackedV2` is the only packing code that writes to the inventory ledger — via `InventoryLedgerService.recordInventoryEvent`, a direct parameterized Postgres `INSERT INTO inventory_events` with `eventType: 'ITEM_PACKED'`/`'ITEM_DAMAGED'`, `quantityChange` negative (deducts stock again at packing time), `referenceType: 'fulfillment_task'` (a value not in the field's own documented set of `'order'|'bulk_op'|'manual'` — minor doc/schema inconsistency). Because Workflow C is fully orphaned (zero screen callers), this deduction never executes today — but it is a **dormant double-deduction landmine**: per [[project_cart_order_module5_audit_findings]], stock is already deducted once at order creation by the live `OrderService.createOrder` path; if Workflow C is ever wired into a screen without first removing this ledger call, every packed item would have its stock deducted twice. V1/Workflow A/B touch no inventory at all (correctly, since deduction already happened at checkout).
- **Order status, cross-module:** confirmed `OrderModel.fromMap` parses `status` via `OrderStatus.values.firstWhere((e) => e.toString() == map['status'], orElse: () => OrderStatus.pending)` — i.e. it requires the fully-qualified string `'OrderStatus.packed'`, not the bare `'packed'`. Workflow B writes the qualified form (`'OrderStatus.packed'`, confirmed at `packing_terminal_screen.dart:592`) and is consistent with this parser. **Workflow A's `PackingService.completePacking` writes the bare string `'packed'`** (`packing_service.dart:161`) to **`shops/{shopId}/orders/{orderId}`** — a different document path than the top-level `orders/{orderId}` Workflow B uses. Per [[project_cart_order_module5_audit_findings]]'s "4-5 competing order engines" finding, the live, customer-visible order lives at top-level `orders/{id}`; `shops/{shopId}/orders` is not confirmed as a live-synced mirror in any module's findings so far. Net effect: an employee using Workflow A's `PackingScreen` is plausibly writing a bare, non-parseable status string into a Firestore path that may not even reflect the live order — the update would silently fail to round-trip back to `OrderStatus.packed` (falls through to the `orElse: OrderStatus.pending`) even in the best case where the path is correct.
- **Delivery:** `PackingDashboardScreen`/`PackingTerminalScreen`'s `OrderStatus.packed` is presumably the handoff signal delivery/dispatch screens key off of (Module 9 will confirm) — Workflow A's writes, landing in a different path with a non-matching string, would never trigger that handoff.

## 8. Automation

None. No Cloud Function exists for packing/fulfillment (confirmed: zero matches for "packing"/"fulfillment" in `functions/src/`) — no server-side validation that a task assignment is legitimate, no automatic SLA/timeout escalation if an employee abandons a task, no reconciliation job across the three Firestore collections.

## 9. Security

Not assessed in depth this module (no `fulfillment_tasks`/`fulfillment_tasks_v2`/`package_processing` rule check performed yet) — flagged as an open item; given the established pattern of missing rules found in [[project_coupon_module6_audit_findings]] (coupons) and elsewhere, this should be checked before considering Workflow A/C trustworthy even if reconciled with Workflow B.

## 10. Failure Cases

No file-write or RPC failure handling reviewed beyond what's visible in `markItemPackedV2`'s ledger call (try/catch not confirmed — flagged for follow-up). The core failure mode found this module isn't an exception path but a **silent data-integrity failure**: Workflow A's status write is plausibly inert (wrong path, unparseable string) with no error surfaced to the employee, who sees a successful-looking UI completion.

## 11. Testing

No test file references `packing_service`, `fulfillment_provider`, or any of the three Firestore collections (not exhaustively grepped this module, but no test file appeared anywhere in the 64-file content-grep that produced this audit's file list).

## 12. Production Readiness

Not production-ready: two live, UI-reachable workflows (A and B) exist for the identical task of packing an order, writing to two different document paths with two different status-string encodings, with no reconciliation. Whichever screen an employee happens to land on (which appears to depend only on which dashboard/menu entry point they used, not any deliberate role/permission split) determines whether the pack actually registers on the order delivery will see. A third workflow (C) is fully built, ledger-integrated, and orphaned, carrying a dormant double-stock-deduction bug if ever wired in without modification. A fourth, dead duplicate screen file adds maintenance confusion with zero functional risk.

---

## Final Output Format

### Current State Audit
Packing/fulfillment functionality is extensively built — arguably the most over-built single module audited so far (3 backend implementations across 4 Firestore schemas, plus a dead duplicate screen) — but two of the three implementations are simultaneously live and disconnected, meaning the same task can be completed through two systems that don't talk to each other and, in one case, write to a Firestore path/string format the order model can't parse back.

### Missing Components
A single source of truth for "is this order packed" (currently 4: `OrderModel.packingStatus`+`OrderStatus.packed`, `fulfillment_tasks`, `fulfillment_tasks_v2`, the unused `package_processing` mirror); a security-rule check on the fulfillment collections; a decision on whether Workflow A (`FulfillmentProvider`/`PackingScreen`) is being kept, migrated to Workflow B, or deleted; removal or rewiring of Workflow C's ledger call before it is ever connected to a screen; deletion of the dead duplicate `owner/order_packing_screen.dart`.

### Architecture Design
Consolidate on Workflow B (`OrderModel.packingStatus`/`packingProof`/`OrderStatus.packed` directly on the order doc) as the single packing state machine, since it is the most-wired path (3 named routes + 3 direct-push call sites) and already has an owner-approval step. Retire `fulfillment_tasks`/`FulfillmentTask`/`FulfillmentProvider`/`PackingScreen` (Workflow A) and `fulfillment_tasks_v2`/`FulfillmentTaskModel`/the V2 `PackingService` methods (Workflow C) — or, if per-item task-assignment metadata (`assignedToEmployeeId`, pick lists, per-item `qtyPacked`/`qtyDamaged`) genuinely needs to survive, port that *data model* into fields on `OrderModel`/a subcollection keyed by the same top-level `orders/{id}`, rather than keeping a separate collection with its own document identity. If Workflow C's ledger-event-on-pack pattern is wanted going forward, re-derive it from Workflow B's approval step instead, with an explicit, single inventory-deduction point in the whole order lifecycle (matching the Module 5 recommendation to consolidate order engines).

### Implementation Plan
1. **P0 — stop Workflow A from writing unparseable, possibly-misrouted status updates.** Either delete `PackingScreen`/`FulfillmentProvider`'s status-writing path immediately (quickest safe fix, since it's reachable from only 2 call sites: `employee_dashboard.dart:292`, `order_queue_screen.dart:191`) or fix `PackingService.completePacking`/`markItemPacked` to write the qualified `'OrderStatus.packed'` string to the correct top-level `orders/{orderId}` path matching Workflow B.
2. **P0 — decide Workflow A's fate explicitly** (delete vs. migrate `FulfillmentTask`'s task-assignment/pick-list features into Workflow B) rather than leaving two live systems for the same action indefinitely.
3. **P1 — remove or gate `markItemPackedV2`'s inventory ledger write** before Workflow C is ever wired to a screen, to prevent the double-stock-deduction landmine documented in §7.
4. **P1 — delete the dead duplicate `lib/screens/owner/order_packing_screen.dart`.**
5. **P2 — add Firestore security rules for `fulfillment_tasks`, `fulfillment_tasks_v2`, `package_processing`** (or remove the collections per item 2/3, making this moot for the removed ones).
6. **P2 — add minimal test coverage** for whichever workflow is kept, especially the status-string round-trip (`OrderModel.toMap`→Firestore→`OrderModel.fromMap`) that this module found to be fragile.

### File-by-file Changes
- `lib/screens/employee/packing_screen.dart` — delete, or fix to call the consolidated Workflow B path.
- `lib/providers/fulfillment_provider.dart` — delete, or repurpose as a thin notifier over `OrderModel.packingStatus` changes (no independent Firestore writes).
- `lib/services/packing_service.dart` — remove V2 methods' `_ledger.recordInventoryEvent` calls (or the whole V2 method set) until a screen is deliberately wired to them; remove or migrate V1 methods per item 2.
- `lib/models/fulfillment_model.dart`, `lib/models/fulfillment_task_model.dart` — delete if Workflows A/C are retired; otherwise port needed fields onto `OrderModel`.
- `lib/screens/owner/order_packing_screen.dart` — delete (dead duplicate).
- `lib/screens/employee/employee_dashboard.dart` (line 292), `lib/screens/employee/order_queue_screen.dart` (line 191) — repoint navigation from `PackingScreen` to the employee `OrderPackingScreen` (Workflow B).
- `firestore.rules` — add rules for `fulfillment_tasks`/`fulfillment_tasks_v2`/`package_processing` if retained, or remove with the collections.

### Production Checklist
- [ ] Exactly one packing workflow remains reachable from every employee/owner entry point
- [ ] Order status updates from packing always use the qualified `OrderStatus.x` string and the correct top-level `orders/{id}` path
- [ ] No code path double-deducts stock at packing time (checkout-time deduction remains the single source, per Module 5)
- [ ] Dead duplicate screen file removed
- [ ] Security rules exist for any fulfillment collection that is kept
- [ ] At least minimal test coverage on the status-string round-trip

---

See [[project_cart_order_module5_audit_findings]] (order-engine duplication and live-path determination methodology), [[project_payment_module7_audit_findings]] (wallet path skips stock deduction — same family of "live path differs from the well-built path" bug), [[project_inventory_module4_audit_findings]] (orphaned-but-well-built mechanisms, e.g. `deductInventoryAtomic`, same shape as this module's Workflow C), and [[project_coupon_module6_audit_findings]] (missing security rule pattern) for related history.
