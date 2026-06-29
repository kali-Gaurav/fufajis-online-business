# Module 9: Delivery Facilities — Master Implementation + Audit

Part of the 17-module Fufaji Store facility audit series. Status: **audit complete, no fixes applied yet.** Findings confirmed by reading live code: `lib/models/delivery_model.dart` (593 lines), `lib/services/delivery_service.dart` (819 lines), `lib/services/delivery_task_service.dart` (161 lines), `lib/services/fleet_service.dart`, `lib/services/delivery_last_mile_service.dart`, `lib/providers/delivery_provider.dart` (655 lines), `lib/providers/delivery_last_mile_provider.dart` (341 lines), `lib/utils/app_router.dart`, `firestore.rules`, plus targeted greps across `delivery_verification_service.dart`, `delivery_tracking_service.dart`, `delivery_intelligence_service.dart`, `business_analytics_service.dart`, `order_business_logic.dart`, `loyalty_membership_service.dart`.

## 1. Business Requirements

Once an order is packed, a delivery agent (rider) must be assigned, travel to the customer, verify identity (OTP/photo/signature), and mark the order delivered or failed — with live location tracking, earnings calculation, and rating capture along the way. Owners need rider assignment visibility, SLA monitoring, and failure escalation. No written requirements doc exists — reverse-engineered from code.

## 2. User Workflow

**At least three independent, partially-overlapping delivery systems exist, two of which write to the identical `deliveries` Firestore collection with incompatible status formats:**

- **System 1 — `DeliveryProvider` + raw `OrderModel` fields (the router-wired rider UI's primary path).** `DeliveryDashboard` (ShellRoute, `/delivery`) wraps `DeliveryOrdersScreen` (`/delivery`, `/delivery/orders`) and `DeliveryEarningsScreen` (`/delivery/earnings`). The rider browses available orders, self-accepts (`acceptOrder`), marks picked up, verifies OTP via `OrderService.verifyAndDeliverOrder`, or marks failed — all by reading/writing fields directly on the top-level `orders/{id}` document (`deliveryAgentId`, `status`, `failureReason`, live lat/lng).
- **System 2 — `DeliveryService` + `deliveries`/`DeliveryTask` (OTP + proof-of-delivery engine, also reachable through `DeliveryProvider`).** The same `DeliveryProvider` also exposes a second, parallel method set (`loadTodayDeliveryTasks`, `startDeliveryTask`, `verifyDeliveryOTP`, `uploadDeliveryProof`, `completeDeliveryTask`, `rateDeliveryTask`) that delegates to `DeliveryService`, which operates on a *different* collection (`deliveries`) and model (`DeliveryTask`/`DeliveryStatus`), plus side collections `delivery_agents`, `delivery_assignments`, `delivery_otp`, `delivery_locations`. Separately, `DeliveryService.assignDeliveryAgent` (Haversine nearest-agent matching) is called only from `FleetService` (`fleet_service.dart:519`), not from `DeliveryProvider` — so automatic dispatch and rider self-accept are two uncoordinated ways the same order's `deliveryAgentId` can be set.
- **System 3 — `DeliveryLastMileProvider` + `DeliveryLastMileService` + `DeliveryTaskModel` (last-mile/OTP variant, also writes to the `deliveries` collection).** Backs `delivery_proof_screen.dart`, `delivery_detail_last_mile_screen.dart`, `rider_tasks_screen.dart` — none of which appeared in the named-route list grepped from `app_router.dart`, so this system's screens are either direct-push-only from elsewhere or unwired; not confirmed live this module.
- **System 4 — `DeliveryTaskService` + `delivery_tasks`/`DeliveryTaskModel`/`DeliveryTaskStatus` (separate task + customer-timeline engine).** A fourth, fully independent model/collection pair with its own customer-facing event timeline (`customer_delivery_events`) and exception log (`delivery_exceptions`). `order_business_logic.dart:413` also writes to `delivery_tasks`, so this system has at least one confirmed order-side caller — unlike Module 8's fully-orphaned V2 path, this one is partially integrated, but no rider-facing screen reading `delivery_tasks` was found this module.
- **System 5 — `FleetService` (`deliveries` collection again, third writer on the same documents).** Confirmed separately maintained dispatch/fleet logic with its own status vocabulary (`'assigned'`, `'accepted'`, `'arrived'`, `'active'`, `'completed'`) written as bare strings, plus three lines (`259`, `304`, `456`) that write the qualified `'OrderStatus.x'` form instead — an internal split within a single file, now confirmed to land on the exact same `deliveries/{id}` documents that Systems 2 and 3 also write, with three different field/status shapes colliding on one document.

## 3. UI Screens

- `delivery/delivery_dashboard.dart` — ShellRoute wrapper for all `/delivery/*` routes; uses `DeliveryProvider`. Router-wired.
- `delivery/delivery_orders_screen.dart`, `delivery/delivery_earnings_screen.dart`, `delivery/trip_route_sheet.dart`, `delivery/smart_route_screen.dart`, `delivery/delivery_reschedule_screen.dart` — router-wired, System 1/2 via `DeliveryProvider`.
- `rider/rider_map_screen.dart`, `rider/rider_route_history_screen.dart` — router-wired (`/rider/map`, `/rider/history`).
- `employee/delivery_screen.dart`, `employee/dispatch_scanner_screen.dart`, `employee/delivery_pod_scanner_screen.dart` — router-wired under the employee shell, parcel/dispatch scanning.
- `owner/rider_management_screen.dart`, `owner/delivery_zones_screen.dart`, `owner/delivery_sla_dashboard_screen.dart`, `owner/failed_delivery_escalation_screen.dart` — owner-side oversight, router-wired.
- `customer/delivery_tracking_screen.dart` — router-wired customer-facing live tracking.
- `delivery_proof_screen.dart`, `delivery_detail_last_mile_screen.dart`, `rider_tasks_screen.dart` — use `DeliveryLastMileProvider` (System 3); not found in the router's named-route list this module — wiring status unconfirmed, flagged for follow-up.

## 4. Backend Architecture

No single delivery service exists. `DeliveryProvider` itself straddles two systems (raw `orders` fields, and a delegated `DeliveryService`/`deliveries` task engine). `DeliveryService` additionally contains an agent-matching subsystem (`assignDeliveryAgent`/`findNearestAvailableAgent`, Haversine-based) called only from `FleetService`, not from `DeliveryProvider` — meaning the class itself bundles two generations of dispatch logic, similar to `PackingService`'s V1/V2 split found in Module 8. `FleetService` is a fully separate, independently-evolved dispatch/fleet-management implementation that also writes directly to the `deliveries` collection. `DeliveryLastMileService`/`DeliveryLastMileProvider` is a fourth, independent stack writing to the same `deliveries` collection via `.toJson()`. `DeliveryTaskService` is a fifth, fully independent stack on a different collection (`delivery_tasks`) with its own enum (`DeliveryTaskStatus`), serialization convention (`.value` getter, neither bare string nor `.toString()`), and side systems (customer event timeline, exception log). None of these five call each other.

## 5. Database Schema

- `orders/{id}` — `deliveryAgentId`, `deliveryAgentName`, `deliveryAgentPhone`, `status` (bare strings `'outForDelivery'`/`'packed'`/`'delivered'`/`'failedDelivery'` written by `DeliveryProvider`, vs. the qualified `'OrderStatus.x'` form required by `OrderModel.fromMap`'s parser and written by Workflow B packing per [[project_packaging_module8_audit_findings]]). System 1.
- `deliveries/{id}` — written by **three different services** with **three different shapes**: `DeliveryService` (`DeliveryTask.toMap()`, status always `DeliveryStatus.x.toString()` — internally consistent), `FleetService` (raw maps, status as bare strings for most writes but qualified `'OrderStatus.x'` strings at three specific lines — internally inconsistent within the same file), `DeliveryLastMileService` (`DeliveryTaskModel.toJson()` — a third shape entirely). Side collections: `delivery_agents`, `delivery_assignments`, `delivery_otp`, `delivery_locations`, `delivery_tracking`, `delivery_events`, `delivery_sla_rules`, `delivery_slots`, `agent_daily_stats`.
- `delivery_tasks/{id}` — `DeliveryTaskModel`/`DeliveryTaskStatus` (snake_case values: `assigned`/`accepted`/`picked_up`/`out_for_delivery`/`delivered`/`failed`/`rejected`/`returned`), written by `DeliveryTaskService` and (separately) `order_business_logic.dart`. Side collections: `customer_delivery_events`, `delivery_exceptions`.
- `delivery_batches/{id}` — referenced by security rules; not traced to a specific service this module.

**No reconciliation exists between `orders.status`, any of the three `deliveries` writers' status fields, or `delivery_tasks.status`.** This is a sharper instance of Module 8's "policy/logic exists in more than one place" pattern: that module found disconnected *collections*; this module additionally found three *independent writers silently colliding on the same documents* in `deliveries`.

## 6. Service Layer

`DeliveryProvider`, `DeliveryService`, `FleetService`, `DeliveryLastMileService`, `DeliveryLastMileProvider`, `DeliveryTaskService` — six classes, five independent data-access paths, zero cross-calls between the dispatch/status-writing cores. Supporting services not fully read this module but confirmed to exist and touch delivery data: `delivery_verification_service.dart` (writes `delivery_events`), `delivery_tracking_service.dart` (reads `deliveries` for background location work), `delivery_intelligence_service.dart` (reads `delivery_sla_rules`), `delivery_workflow_engine.dart`, `delivery_clustering_service.dart`, `delivery_ledger_service.dart`, `route_optimization_service.dart`, `rider_payout_service.dart`, `delivery_charge_calculator.dart` (two copies: `services/` and `services/operations/`) — not individually audited; flagged for a follow-up pass if/when consolidation work begins.

## 7. Integration Points

- **Packing → Delivery handoff:** `DeliveryProvider._listenToAvailableOrders` queries `orders` `where('status', isEqualTo: 'packed')` (bare string). Per [[project_packaging_module8_audit_findings]], the live packing path (Workflow B) writes the qualified `'OrderStatus.packed'`. **A bare-string Firestore equality filter can never match a qualified-string field value** — so this query is structurally incapable of returning the orders packing just produced. The same bare-vs-qualified mismatch repeats in `_listenToAssignedOrders` (`whereIn: ['outForDelivery', 'packed']`) and `_listenToCompletedOrders` (`isEqualTo: 'delivered'`). This is a concrete, high-confidence P0: the rider's "available orders to pick up," "my assigned orders," and "completed orders" lists are plausibly always empty in production, independent of any other finding in this module.
- **Dual, uncoordinated assignment:** `DeliveryProvider.acceptOrder` (rider self-accept, writes bare `'outForDelivery'` to `orders.status`) and `FleetService`/`DeliveryService.assignDeliveryAgent` (automatic nearest-agent dispatch, writes qualified `'OrderStatus.outForDelivery'` to `orders.status` plus agent/assignment bookkeeping) can both fire on the same order with no mutual check — first-writer-wins with no lock, and the two writers don't even agree on the order doc's status string format.
- **Inventory/Packing:** no inventory interaction at delivery time (correct — deduction already happened at order creation per Module 5/7 findings); packing handoff is the only upstream dependency, and it's broken per the bullet above.
- **Wallet/Refunds (Module 10, upcoming):** `markDeliveryFailed`/`failDelivery` set order/delivery failure state but neither path was confirmed to trigger any refund or wallet-credit flow — flagged for cross-check when Module 10 is audited.

## 8. Automation

No Cloud Function involvement confirmed for any of the five delivery systems (not exhaustively grepped this module, but none surfaced across the read files). `DeliveryTaskService.logException` is the only auto-transition logic found: it moves a task to `DeliveryTaskStatus.failed` when the logged exception type is `customer_unreachable`, `vehicle_breakdown`, or `wrong_address` — but this lives only in System 4 (`delivery_tasks`), which has no confirmed rider-facing UI, so this automation likely never fires from a live screen today.

## 9. Security

**Confirmed gap, larger blast radius than Module 6's coupon finding.** `firestore.rules` has explicit rules only for `delivery_tasks` (line 156) and `delivery_batches` (line 170). **No rule exists for `deliveries`, `delivery_agents`, `delivery_assignments`, `delivery_otp`, `delivery_locations`, `delivery_tracking`, `delivery_events`, `delivery_exceptions`, `delivery_sla_rules`, or `delivery_slots`** — ten collections, under Firestore's default-deny model, that should fail every read/write today unless a broader catch-all rule exists elsewhere in the file (not found in this module's read). This is more severe than Module 6's missing-rule finding because the unprotected set includes `delivery_otp` (delivery-confirmation OTP codes) and `delivery_locations`/`delivery_tracking` (live customer/rider GPS data) — if any client-side fallback or cached-rule behavior is masking this in practice, that itself needs verification; if not, the entire `deliveries`-collection-based systems (2, 3, 5) are plausibly non-functional in production, independent of the status-string bugs above.

## 10. Failure Cases

`DeliveryTaskService.updateTaskStatus` wraps its batch commit in try/catch; on failure it calls `_queueOfflineStatusUpdate`, which is a **non-functional stub** — only a `debugPrint`, with a comment describing an intended Hive/SharedPreferences-backed offline queue and background sync that was never implemented. Any status update that fails while a rider is offline is silently lost today, not queued. `DeliveryProvider`'s methods catch exceptions into `_errorMessage` (surfaced to UI) but do not distinguish "permission-denied because the security rule is missing" from any other failure, so the security gap in §9 would likely present to the rider as a generic, unexplained error rather than a clear signal of what's broken.

## 11. Testing

No test file references `delivery_service`, `delivery_provider`, `delivery_task_service`, `fleet_service`, or `delivery_last_mile_service` (not exhaustively grepped, but none surfaced across this module's reads).

## 12. Production Readiness

Not production-ready. Two issues alone are likely sufficient to make delivery non-functional today regardless of any other finding: (1) the missing security rules on ten `delivery*` collections, and (2) the bare-vs-qualified status-string mismatch between `DeliveryProvider`'s order queries and the live packing write format. On top of that, three independent services write conflicting shapes to the identical `deliveries/{id}` documents, a fourth fully independent task/collection pair exists with at least one real caller (`order_business_logic.dart`) but no confirmed UI, and a fifth provider/service pair's screens aren't confirmed router-wired at all.

---

## Final Output Format

### Current State Audit
Delivery functionality is extensively built (five independent service/provider stacks) but shows the most severe live-breakage risk of any module audited so far: a missing-security-rule gap covering ten collections, and a status-string format mismatch that plausibly empties the rider's core order lists, are both independently capable of making the feature non-functional in production today.

### Missing Components
Firestore security rules for `deliveries`, `delivery_agents`, `delivery_assignments`, `delivery_otp`, `delivery_locations`, `delivery_tracking`, `delivery_events`, `delivery_exceptions`, `delivery_sla_rules`, `delivery_slots`; a single source of truth for order/delivery status strings (qualified `OrderStatus.x` everywhere, matching `OrderModel.fromMap`'s parser); a single assignment mechanism (retire either rider self-accept or auto-dispatch, or add a transactional claim-check so both can't race); a real offline-status-update queue (replacing `DeliveryTaskService`'s stub); a decision on which of the five delivery stacks is canonical.

### Architecture Design
Consolidate around `DeliveryService`/`deliveries`/`DeliveryTask` as the single delivery data model — it is the most complete (OTP, proof-of-delivery, stats, ratings) and the only one already internally consistent on status-string format. Fix `DeliveryProvider`'s raw-`orders`-field methods (`acceptOrder`, `updateDeliveryStatus`, `markPickedUp`, `markDeliveryFailed`, and the three `_listenTo*` queries) to use the qualified `OrderStatus.x` string consistently, or migrate them to call into `DeliveryService` instead of writing `orders` fields directly. Retire `FleetService`'s direct writes to `deliveries` (or rewrite them to match `DeliveryTask.toMap()`'s shape) and `DeliveryLastMileService`'s parallel `.toJson()` writes to the same collection — three writers on one collection is the core architectural defect this module found. Fold `DeliveryTaskService`/`delivery_tasks`'s customer-timeline and exception-logging features into the consolidated model if they're wanted, rather than keeping a sixth parallel schema.

### Implementation Plan
1. **P0 — add Firestore security rules for all ten unprotected `delivery*` collections.** Until this is fixed, no other delivery finding can be confirmed as a behavior bug vs. a rule-blocked no-op — verify rule deployment before doing the status-string fix below, since the rule fix may itself change what's actually reachable.
2. **P0 — FIXED 2026-06-20** (partially): `_listenToAvailableOrders`/`_listenToAssignedOrders`/`_listenToCompletedOrders` now query the qualified `'OrderStatus.x'` form; `acceptOrder` now writes the qualified form; `updateDeliveryStatus` now defensively qualifies any bare status string passed to it (covers `markPickedUp`). **Not fixed**: `markDeliveryFailed` still writes a bare `'failedDelivery'` status — left as-is because `OrderStatus` has no `failedDelivery` enum value at all, so qualifying the string wouldn't make it parseable either; that needs a model change (add the enum value) before it can be fixed properly, tracked separately. Also still open: rules deployment (#1 above, now done — see [[project_delivery_module9_audit_findings]]) and the three-way `deliveries/{id}` writer collision (#3 below) are unaffected by this fix and remain open.
3. **P0 — eliminate the three-way writer collision on `deliveries/{id}`.** Pick one service (recommend `DeliveryService`) as the sole writer; remove or redirect `FleetService`'s and `DeliveryLastMileService`'s direct writes to that collection.
4. **P1 — resolve the dual-assignment race** between rider self-accept (`DeliveryProvider.acceptOrder`) and auto-dispatch (`FleetService`→`DeliveryService.assignDeliveryAgent`) with a single transactional claim (e.g., a Firestore transaction that only succeeds if `deliveryAgentId` is still null).
5. **P1 — implement a real offline-status-update queue** (Hive/SharedPreferences-backed, with background sync) to replace `DeliveryTaskService._queueOfflineStatusUpdate`'s stub, or remove the queuing comment/illusion of resilience if `delivery_tasks` is being retired per item 3's consolidation.
6. **P2 — confirm router-wiring status of System 3's screens** (`delivery_proof_screen.dart`, `delivery_detail_last_mile_screen.dart`, `rider_tasks_screen.dart`) and either wire them properly or retire `DeliveryLastMileProvider`/`DeliveryLastMileService`.
7. **P2 — audit the remaining unread delivery services** (`delivery_workflow_engine`, `delivery_clustering_service`, `delivery_ledger_service`, `route_optimization_service`, `rider_payout_service`, both `delivery_charge_calculator` copies) for further duplication before the consolidation in item 3 is finalized.

### File-by-file Changes
- `firestore.rules` — add `match` blocks for the ten unprotected `delivery*` collections.
- `lib/providers/delivery_provider.dart` — rewrite status writes/queries to use qualified `OrderStatus.x` strings; consider delegating raw-`orders` methods into `DeliveryService` instead of direct Firestore calls.
- `lib/services/fleet_service.dart` — remove or correct direct `deliveries` writes (lines with bare-string statuses: 125, 275, 287, 311, 365, 449, 500); reconcile with `DeliveryService`/`DeliveryTask`'s shape if kept.
- `lib/services/delivery_last_mile_service.dart`, `lib/providers/delivery_last_mile_provider.dart` — retire in favor of `DeliveryService`, or confirm distinct purpose and move off the shared `deliveries` collection onto its own.
- `lib/services/delivery_task_service.dart` — implement a real offline queue in `_queueOfflineStatusUpdate`, or fold into the consolidated model per item 3.
- `lib/services/order_business_logic.dart` (line 413) — repoint to the consolidated delivery-task write path once one is chosen.

### Production Checklist
- [ ] Security rules exist for every `delivery*` collection currently unprotected
- [ ] All order/delivery status writes use the qualified `OrderStatus.x`/`DeliveryStatus.x` string form, matching their respective model parsers
- [ ] Rider "available/assigned/completed orders" queries return real data against the live packing write format (manually verified, not just code-reviewed)
- [ ] Exactly one service is the writer of record for the `deliveries` collection
- [ ] Order assignment (self-accept vs. auto-dispatch) cannot race onto the same order
- [ ] Offline status updates are actually queued and synced, not silently dropped

---

See [[project_packaging_module8_audit_findings]] (packing→delivery handoff bug, same bare/qualified status-string family), [[project_payment_module7_audit_findings]], [[project_coupon_module6_audit_findings]] (missing-security-rule pattern, now confirmed at larger scale here), [[project_cart_order_module5_audit_findings]], [[project_inventory_module4_audit_findings]], [[project_scanner_module3_audit_findings]], [[project_product_module2_audit_findings]], [[project_auth_module1_audit_findings]], and [[project_phase16_audit_backlog]] for related history.
