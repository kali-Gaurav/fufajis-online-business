# Module 3: Scanner Facilities — Master Implementation + Audit

**Status:** Audit complete. Findings confirmed by reading live code. No code changes made in this pass.
**Date:** 2026-06-19
**Files read in full:** `lib/services/scanner_service.dart` (506 lines), `lib/services/employee_scanner_service.dart` (1206 lines), `lib/screens/employee/unified_scanner_hub.dart` (937 lines)
**Files spot-checked:** `lib/screens/employee/returns_screen.dart`, `lib/screens/employee/damage_reporting_screen.dart`, `lib/services/smart_scan_service.dart`, `lib/screens/employee/employee_home_screen.dart`, `lib/utils/app_router.dart`

---

## 1. Business Requirements

The scanner is the primary input device for almost every physical-world action in the shop: receiving stock from suppliers, packing and dispatching orders, confirming delivery, auditing shelf stock, processing returns/damage, taking attendance, and accepting UPI payments. It must work reliably offline-tolerant (camera-only, no network dependency for the scan itself), must restrict each scan mode to the roles that should use it, and must leave an audit trail of who scanned what, when, and why — because scan events trigger real stock and money movements downstream.

## 2. User Workflow

Two distinct workflows exist in production, and they are not the same workflow:

**Workflow A — Scanner Hub (generic, mode-driven):** Employee/owner opens "Scanner Hub" → picks one of the role-visible mode tiles (`ScanMode.forRole(role)`) → camera opens in that mode → barcode detected → audit log written → result routed to the matching destination screen (or a bottom sheet for product-lookup/payment).

**Workflow B — Dedicated screens (purpose-built, scan-embedded):** Employee opens "Returns" or "Report Damage" directly from the employee home menu or a named route (optionally pre-filled with a barcode via deep link) → the screen has its own embedded scan-and-lookup via a second, separate service (`SmartScanService`) → employee fills a small form (quantity, condition/damage type, reason) → submits → `EmployeeScannerService.processReturn` / `reportDamage` executes.

These two workflows were built independently and do not call into each other (see Section 9/10).

## 3. UI Screens

- `unified_scanner_hub.dart` — mode picker grid + live camera view, role-filtered via `ScanMode.forRole(role)`. Routes 10 of 12 defined modes correctly; 2 are dead ends (see below).
- `order_packing_screen.dart`, `dispatch_scanner_screen.dart`, `delivery_pod_scanner_screen.dart`, `inventory_receiving_screen.dart`, `inventory_audit_screen.dart`, `shelf_refill_screen.dart`, `customer_membership_scanner_screen.dart`, `attendance_screen.dart` — destination screens, correctly reached from the Hub with metadata (`orderId`, `parcelId`, `barcode`, `customerId`, `attendanceId`) passed through.
- `returns_screen.dart`, `damage_reporting_screen.dart` — self-contained, **not** reachable from the Hub; reached only via `employee_home_screen.dart` menu items and `app_router.dart` named routes (the damage route accepts a `barcode` query param for deep-linking).
- Product-lookup and Payment-QR results render as bottom sheets inline in the Hub rather than pushing a new screen — reasonable UX choice, no issue found.

## 4. Backend Architecture

- `ScannerService` — stateless-per-instance camera wrapper (`MobileScannerController`) + pure parsing function `parseScanAction(code)` that classifies a raw barcode string into one of 11 `ScanAction` types by string-prefix matching (`ORDER-`, `DISPATCH-`, `PARCEL-`, `TRANSFER-`, `AUDIT-`, `RETURN-`, `DAMAGE-`, `RIDER-`, `ATTENDANCE-`, `SHELF-`, `MEMBER-`, `upi:`, else `productScan`). Also owns `writeScanLog` (Firestore audit write) and exposes 12 `ScanModeConfig` entries via `ScanMode.all`/`ScanMode.forRole`/`ScanMode.find`.
- `EmployeeScannerService` — the actual business-logic layer triggered after routing: inventory receiving, order packing verification, delivery assignment + OTP proof-of-delivery, inventory audit recording, damage reporting (+ automatic supplier-return generation), attendance with GPS-variance detection and a manager-alert fallback chain, cash collection, returns processing, inventory transfer (with a real authorization check), and shelf refill triggers.
- `SmartScanService` — a **second**, independent scan-support service used only by `ReturnsScreen`/`DamageReportingScreen`: looks up a product by barcode, also opportunistically matches against open purchase orders and against the current order's line items. Does not share code, models, or the `scan_logs` audit trail with `ScannerService`.

## 5. Database Schema

- `shops/{shopId}/scan_logs/{logId}` — Firestore audit trail written by `ScannerService.writeScanLog`: shopId, branchId, employeeId, employeeName, employeeRole, action type, code, timestamp. Write is **not guaranteed** (see Section 10).
- `inventory_audit_logs` — receive/audit/damage events, read back by `reportDamage` to find a matching prior "receive" record (used for the auto-supplier-return rule).
- `supplier_returns/{returnId}` — auto-created by `reportDamage` when a damage report matches a receive log from the same supplier within 7 days; `status: pending_credit`.
- `products.stockQuantity` — mutated directly via `FieldValue.increment(...)` by `receiveInventory`, `reportDamage`, `processReturn`, `receiveTransfer`. No approval-workflow gating on these writes (see Section 9 — this is intentional, not the same gap as Module 2).
- No dedicated schema exists for the Hub's `scan_logs` vs. whatever (if anything) `SmartScanService`-driven screens log — they appear to log only through `EmployeeScannerService`'s own writes, with no equivalent of `writeScanLog` called from that path.

## 6. Service Layer

`ScannerService` (parse + audit) → `EmployeeScannerService` (execute) is the intended pipeline for Hub-driven scans. `SmartScanService` (lookup) → `EmployeeScannerService` (execute) is the actual pipeline for Returns/Damage, bypassing `ScannerService` entirely. Both pipelines converge on the same `EmployeeScannerService`, so the business-logic layer itself is unified — only the front door differs.

## 7. Integration Points

- Firestore: `scan_logs`, `inventory_audit_logs`, `supplier_returns`, `products`, `shops/{shopId}/branches`, `users`.
- WhatsApp (via existing notification integration): GPS-variance attendance alerts, cascading through manager → assistant manager → branch contact → escalation phone → hardcoded fallback number.
- Camera/`mobile_scanner` package: hardware integration point, single controller instance per Hub session, disposed on screen exit.
- UPI deep link parsing (`upi://pay?...`) for the Payment QR mode — read-only verification today, no live payment-gateway call from the scanner path itself.

## 8. Automation

- **Auto supplier-return generation:** `reportDamage` automatically creates a `supplier_returns` record when a matching receive log (same product, same supplier, within 7 days) exists — a genuinely useful, previously-undocumented business rule with no manual step required.
- **GPS-variance attendance escalation:** automatically computes distance variance from expected location and walks a fallback chain of WhatsApp recipients until one is notified.
- **Audit logging:** intended to be automatic on every Hub scan via `writeScanLog`, but see Section 10 for its failure mode.

## 9. Security

- **Role-based mode visibility works correctly:** `ScanMode.forRole(role)` filters the Hub's tile grid by the `roles` list on each `ScanModeConfig` — a customer-facing role never sees employee-only tiles, and `deliveryPOD` is restricted to `delivery` only.
- **Positive finding — `receiveTransfer` authorization check is done right:** it independently verifies the caller is `owner`/`superAdmin`, or the specific branch's `managerId`/`assistantManagerId`, before allowing a transfer to be signed off, throwing `Exception('Unauthorized: ...')` otherwise. This is a good pattern other mutation methods in this service should be brought up to (most of them — `receiveInventory`, `reportDamage`, `processReturn` — currently trust the caller's role without an equivalent server-side-shaped check).
- **Direct `stockQuantity` increments with no approval gate** in `receiveInventory`, `reportDamage`, `processReturn`, `receiveTransfer`: this is architecturally different from Module 2's CSV-bulk-import finding — these are physical-event-driven, one-item-at-a-time mutations tied to a real-world action (a person physically receiving/returning/damaging stock), not arbitrary bulk edits. Requiring an approval-request detour for "I just received this box" would add friction without a matching risk reduction. Recommendation: keep these ungated, but tighten authorization (apply the `receiveTransfer` pattern) and ensure every one of them writes a durable audit record (most already do via `inventory_audit_logs` — confirm `processReturn` does too).
- **Hardcoded phone number code smell:** `_notifyManagerGpsVariance`'s fallback chain ends in a literal `'919876543210'` default for `WHATSAPP_OPERATIONS_PHONE` if no env var is configured. Should fail loudly (log + skip) instead of silently texting a placeholder number in production.

## 10. Failure Cases

- **P0 — Confirmed dead-end UI path:** `ScanMode.returnItem` (`'return_item'`) and `ScanMode.damageItem` (`'damage_item'`) are both present in `ScanMode.all` with `roles: ['owner', 'employee']`, so they **do appear** as selectable tiles in the Scanner Hub for both roles. But `UnifiedScannerHub._buildForcedAction` and `_routeAction` have no `case` for either mode — both fall through to default handling, and `_routeAction`'s default calls `_showUnknownCodeSheet(action.code)`. Concretely: an employee taps "Return Item" or "Damage Item" in the Hub, scans a barcode, and sees a literal "Unknown Code" sheet with no path forward — even though `EmployeeScannerService.processReturn`/`reportDamage` are fully implemented and reachable from the unrelated `ReturnsScreen`/`DamageReportingScreen`. This is a real, user-facing dead end, not a hypothetical.
- **P1 — Orphaned mode:** `ScanMode.riderScan` (`'rider_scan'`) is defined as a constant and has a working `ScanAction.riderScan` factory (triggered by `RIDER-` prefixed codes), but has **no corresponding entry in `ScanMode.all`**. It can never be selected as a tile (no role list to match against) and, if a `RIDER-` code is ever scanned during another active mode, `_routeAction` has no case for it either — same "Unknown Code" dead end. Either finish wiring it (likely intended for a rider hand-off/verification flow) or remove the dead code paths.
- **Silent audit-log failure:** `ScannerService.writeScanLog` wraps its Firestore write in a try/catch with an explicit comment ("Never let audit log failure break the primary workflow") and swallows the error completely — no retry, no dead-letter, no visible warning to the employee or to any monitoring system. The primary workflow correctly continues, but a scan that should have been audited silently isn't, with zero trace it happened.
- **Two non-unified scan-input subsystems:** `ScannerService` (Hub) and `SmartScanService` (Returns/Damage screens) duplicate "look up a product by barcode" logic independently, with different matching strategies (PO-matching and order-line-matching in `SmartScanService` have no equivalent in `ScannerService`). This is the same "policy/logic exists in more than one place, inconsistently" pattern already flagged in Module 2 ([[project_product_module2_audit_findings]]) and in Module 1 — now confirmed a third time, in Scanner Facilities.

## 11. Testing

No automated tests found covering `parseScanAction`'s 11-way prefix routing, the Hub's mode-to-screen routing table, or `EmployeeScannerService`'s stock-mutation methods. Given the prefix-matching is pure and side-effect-free, it is the cheapest, highest-value place to start: a table-driven unit test asserting every `ScanMode.all` entry has a corresponding `_routeAction` case would have caught both P0/P1 findings above mechanically, before manual audit was needed.

## 12. Production Readiness

Not production-ready for the Return/Damage-via-Hub path (confirmed dead end) or the Rider-scan path (confirmed orphaned). The dedicated Returns/Damage screens and the other 10 Hub modes are functionally solid. Audit-trail reliability (silent failure) and the hardcoded phone fallback should be fixed before this is called hardened.

---

## Final Output Format

### Current State Audit
Two independently-built scanning subsystems exist: the general-purpose `ScannerService` + `UnifiedScannerHub` (12 modes defined, 10 correctly wired to destination screens) and the special-purpose `SmartScanService` powering `ReturnsScreen`/`DamageReportingScreen` directly. Both converge on the same `EmployeeScannerService` business-logic layer, which is itself solid: 9 well-implemented workflow areas, one genuinely good authorization pattern (`receiveTransfer`), and one genuinely useful automation (auto supplier-return on damage).

### Missing Components
1. `UnifiedScannerHub` has no route for `ScanMode.returnItem` or `ScanMode.damageItem` despite both being selectable tiles — dead end to "Unknown Code."
2. `ScanMode.riderScan` is defined and parsed but never registered in `ScanMode.all` — unreachable as a tile, and unroutable if ever produced.
3. No retry/dead-letter for failed `scan_logs` audit writes.
4. No authorization check on `receiveInventory`, `reportDamage`, `processReturn` comparable to `receiveTransfer`'s.
5. No automated test coverage asserting every defined `ScanMode` has a live route.

### Architecture Design
Keep `EmployeeScannerService` as the single business-logic layer (already true). Either (a) fold `SmartScanService`'s product/PO/order-line matching into `ScannerService` so there is one scan-input layer with two entry surfaces (Hub tiles + deep-linked dedicated screens), or (b) explicitly document them as intentionally separate and add the missing Hub routes so at minimum the Hub itself has no dead ends. Add the two missing `_routeAction`/`_buildForcedAction` cases (route to `ReturnsScreen(barcode: ...)` / `DamageReportingScreen(barcode: ...)`, reusing the existing constructors which already accept a barcode). Either wire `riderScan` to a real screen or delete the dead constant/factory/branch.

### Implementation Plan
1. Add `case ScanMode.returnItem` and `case ScanMode.damageItem` to `_routeAction`, pushing `ReturnsScreen`/`DamageReportingScreen` with the scanned barcode — closes the P0 dead end with minimal change, reusing screens that already work.
2. Add matching cases to `_buildForcedAction` so forced-mode scans produce the right `ScanAction` instead of falling through to generic `parseScanAction`.
3. Decide and resolve `riderScan`: either add a `ScanModeConfig` entry + route, or remove the dead `ScanAction.riderScan` factory, the `RIDER-` prefix branch, and the constant.
4. Replace `writeScanLog`'s silent catch with the app's existing dead-letter pattern (already used for Supabase sync failures elsewhere — reuse it here).
5. Add a `_isAuthorizedFor(action)` helper modeled on `receiveTransfer`'s check and apply it to `receiveInventory`, `reportDamage`, `processReturn`.
6. Replace the hardcoded `'919876543200'`-style fallback phone with a hard failure (log + skip notification) when `WHATSAPP_OPERATIONS_PHONE` is unset.
7. Add a unit test that diffs `ScanMode.all` against `_routeAction`'s handled cases so this class of gap is caught automatically going forward.

### File-by-file Changes
- `lib/screens/employee/unified_scanner_hub.dart` — add 2 routing cases in `_routeAction`, 2 in `_buildForcedAction` (steps 1–2); decide and apply step 3's `riderScan` resolution.
- `lib/services/scanner_service.dart` — dead-letter the `writeScanLog` catch block (step 4); resolve or remove `riderScan` constant/factory (step 3).
- `lib/services/employee_scanner_service.dart` — add authorization checks to 3 methods (step 5); fix hardcoded phone fallback (step 6).
- New test file, e.g. `test/services/scanner_routing_test.dart` (step 7).

### Production Checklist
- [ ] Return/Damage scan-mode tiles route to a working screen, not "Unknown Code"
- [ ] `riderScan` either fully wired or fully removed — no orphaned mode left in the codebase
- [ ] Scan audit log failures are retried/dead-lettered, not silently dropped
- [ ] Stock-mutating scan methods have authorization checks consistent with `receiveTransfer`
- [ ] No hardcoded contact numbers in any notification fallback path
- [ ] Automated test asserts every `ScanMode` has a live UI route
