# MODULE 2 — PRODUCT MANAGEMENT: MASTER IMPLEMENTATION + AUDIT

**Status:** Audit complete, grounded in live code reads (not assumptions).
**Real stack confirmed:** Firestore (`products` collection) is the primary store; Supabase Postgres is a best-effort dual-write target; a second, separate Postgres path (`RDSDatabaseService` + `change_requests`/`bulk_operations` tables) exists in parallel for the approval workflow. No AWS RDS literally; no Redis touched by product writes.

---

## 1. Business Requirements

Fufaji Store owners/employees must be able to create, price, stock, categorize, and merchandise products across one or more branches, with: bilingual (EN/HI) category taxonomy; per-branch stock and shelf-location tracking; competitor-price-aware and cost-aware pricing; time-boxed "lightning deals"; group-buy eligibility; a "farm story" provenance layer (farmer name/image/harvest date/organic certification) for local/sourced goods; low-stock alerting with sales-velocity-based reorder recommendations; a customer review/rating system with owner replies and moderation; and a bulk CSV import path for catalog seeding. Every price or stock change that affects customer-facing data must be auditable and, per standing project policy, **bulk changes must go through an approval workflow before they touch `products`.**

## 2. User Workflow

- **Owner/Admin (single product):** Add Product screen → fill fields → `ProductService.addProduct` → direct Firestore write → live on storefront immediately (no review step).
- **Owner/Admin (bulk CSV import):** `products_management.dart` bulk-upload dialog → parse CSV rows client-side → build `ProductModel` list → `ProductService.batchAddProducts` → **direct, unreviewed, unaudited** batched Firestore writes, live immediately.
- **Owner/Admin (proposed price change):** `proposePriceChange` → `price_change_proposals` doc (`status: pending`) → owner reviews in a pending-changes UI → `approvePriceChange` (transaction: apply to product + mark approved) or `rejectPriceChange`.
- **Owner/Employee (bulk field edit via Query Builder):** Build a filter (e.g., "category = Vegetables AND stock < 10") → `InventoryChangeRequestService.createBulkRequest`/`createChangeRequest` → `inventory_change_requests` doc (`status: pending`) → owner reviews in Approval Queue screen → `approveRequest` (batched Firestore update + best-effort Supabase dual-write + audit log) or `rejectRequest`.
- **Owner (separate Postgres-side approval path):** `ApprovalWorkflowService.getPendingRequests`/`approveRequest`/`approveBulkOperation` operate against `change_requests`/`bulk_operations` tables in Postgres via raw SQL — a structurally similar but **entirely separate** approval system from the Firestore one above, with no evidence the two are unified or that either calls the other.
- **System (automated):** any `updateProduct` call that lowers `stockQuantity` below `minimumStock` triggers `createLowStockAlert` → velocity calc → severity scoring → `low_stock_alerts` doc + local notification.
- **Customer:** views products read-only (`allow read: if true` in rules); submits reviews via `addProductReview` (atomic rating-average transaction).

## 3. UI Screens

- `lib/screens/owner/products_management.dart` — primary owner CRUD + bulk CSV import dialog (the read excerpt at lines 1500–1578 is the CSV-row-to-`ProductModel` parser feeding `batchAddProducts`).
- `lib/screens/owner/inventory_approval_queue_screen.dart` — review/approve/reject UI for `inventory_change_requests` (Firestore path).
- Price-change pending/history UI implied by `getPendingPriceChangesStream`/`getPriceChangesHistoryStream` (consumer screen not yet located/read — flagged as a gap below).
- Low-stock alerts UI implied by `getLowStockAlertsStream`/`dismissLowStockAlert` (consumer screen not yet located/read).
- No category-management screen or image-upload UI was located in this audit pass beyond the generic `StorageService.uploadImage` helper — category data appears to be enum-driven (`ProductCategory`) rather than backed by a managed `categories` Firestore collection (only one unrelated hit for the literal string `categories` in `firestore_seed_service.dart`, i.e. seed data, not a live admin screen).

## 4. Backend Architecture

Three independent write paths converge on the same `products` collection, with no shared gate:

1. **`ProductService`** (`lib/services/product_service.dart`) — direct CRUD singleton. `addProduct`, `batchAddProducts`, `updateProduct`, `deleteProduct` all write straight to Firestore. `updateProduct` opportunistically audit-logs two field types (`stockQuantity`, `price`) and triggers low-stock alerting; nothing else does.
2. **`InventoryChangeRequestService`** (Firestore, `inventory_change_requests` collection) — the intended approval gate for bulk/single field edits originating from the "Bulk Inventory Query Builder." On `approveRequest`, batches Firestore updates (450/batch), best-effort dual-writes mapped columns to Supabase, marks the request approved, and writes a full audit trail via `AuditService`.
3. **`ApprovalWorkflowService`** (Postgres/RDS, `change_requests`/`bulk_operations` tables) — a second, structurally parallel approval system operating entirely in SQL against `inventory`/`products`/`inventory_events` tables, with no visible link to (1) or (2).

None of the three call into each other. `ProductService.addProduct`/`batchAddProducts` are never invoked by either approval service — they are called directly from UI (`products_management.dart`, and a mock-data seeding call in `product_provider.dart`).

## 5. Database Schema

- **Firestore `products/{id}`** — ~50 fields per `ProductModel`: identity/pricing (`price`, `originalPrice`, `costPrice`, `discountPercentage`), `ProductUnitOption[]` for per-unit variants, `CompetitorPrice[]`, stock (`stockQuantity`, `minimumStock`, `branchStock: Map<branchId,int>`), shelf metadata (`branchLocations: Map<branchId, {zone,aisle,shelf,bin}>`, `shelfPhotoUrl`, `shelfPhotoUpdatedAt`), merchandising flags (`isFeatured`, `isOnSale`, `isNewArrival`, `isTrending`, lightning-deal window fields, `isGroupBuyEligible`), provenance (`village`, `origin`, `farmerName`, `farmerImage`, `harvestDate`, `isOrganicCertified`), and review aggregates (`rating`, `reviewCount`).
- **Firestore `price_change_proposals/{id}`** — `status` (`pending`/`approved`/`rejected`), proposed new price, target product id.
- **Firestore `inventory_change_requests/{id}`** — matches `InventoryChangeRequestModel`: `type`, `status`, `filterDescription`, `note`, `changes: InventoryFieldChange[]` (`productId`, `field`, `oldValue`, `newValue`), requester/reviewer metadata.
- **Firestore `low_stock_alerts/{id}`** — severity, `daysUntilStockout`, `recommendedReorderQuantity`, `isDismissed`.
- **Postgres `products`/`inventory`/`change_requests`/`bulk_operations`/`inventory_events`** — the parallel relational schema driving `ApprovalWorkflowService`; column-level shape not fully audited this pass (only the SQL call sites were read, not a migration file confirming exact columns).
- **Supabase `products`** — partial mirror, updated only for the 8 columns in `_kSupabaseColumnForField` (`stock`, `price`, `original_price`, `cost_price`, `is_available`, `name`, `category`, `minimum_stock`, `discount_percentage`); any other field changed via the Firestore approval path silently never reaches Supabase.

## 6. Service Layer

- `ProductService` — see Backend Architecture. Notable correct patterns: `addProductReview` and `markReviewAsHelpful` use Firestore transactions/atomic increments correctly, avoiding race conditions on the rolling rating average.
- `InventoryChangeRequestService` — correct approval-gate pattern with audit logging on both create and approve/reject.
- `ApprovalWorkflowService` — **contains a SQL-injection-shaped bug**: in `approveRequest`, the `entityType == 'inventory'` branch builds `UPDATE inventory SET $updates WHERE inventory_id = $1` where `updates` is built via `proposedChange.keys.map((k) => '$k = ${proposedChange[k]}').join(', ')` — **raw value interpolation, no parameterization, no quoting**. The `entityType == 'product'` branch a few lines below does this correctly with `$1, $2...` placeholders, and even carries a comment acknowledging the risk ("dynamic updates in SQL need careful sanitization") — but that same care was not applied to the `inventory` branch directly above it. `approveBulkOperation` also builds a dynamic `UPDATE ... FROM ... WHERE` with a separately-constructed `whereSql`/`setClause`, which is parameterized for values but interpolates raw column/table names (`targetField`, `targetTable`) — acceptable only if `targetField` is constrained to a fixed allowlist, which is not visibly enforced in this method.
- `InventoryLedgerService.recordInventoryEvent` is called from `ApprovalWorkflowService` on inventory approval but not from `InventoryChangeRequestService` on product-field approval — meaning the two approval systems write to two different audit destinations (`AuditService.logAction` vs. `InventoryLedgerService.recordInventoryEvent`), so a complete change history requires consulting both.

## 7. Integration Points

- **AuditService** — used by `InventoryChangeRequestService` (create + approve + reject) and partially by `ProductService.updateProduct` (price/stock only). Not used by `addProduct`, `batchAddProducts`, or `deleteProduct`.
- **NotificationService** — fired from `createLowStockAlert` for local push notifications.
- **InventoryAlertService** — supplies `calculateSalesVelocityWithTrend`, `predictDaysUntilStockout`, `calculateReorderQuantity` consumed by `createLowStockAlert`.
- **SupabaseDatabaseService** — best-effort dual-write target from `InventoryChangeRequestService.approveRequest` only; not invoked from `ProductService` at all, so direct `addProduct`/`updateProduct` writes never reach Supabase.
- **RDSDatabaseService / InventoryQueryService** — consumed only by `ApprovalWorkflowService`, isolated from the Firestore-side services.
- **StorageService.uploadImage** — generic Firebase Storage upload helper; not specific to products, no resize/compress/validation step visible, no product-specific folder convention beyond whatever caller passes as `folder`.

## 8. Automation

- Low-stock alert generation is the only fully automated product-management flow: triggered synchronously inside `updateProduct` whenever `stockQuantity`/`minimumStock` change and the post-update value is below threshold. No scheduled/background job was found that periodically re-scans all products for staleness (e.g., expired lightning deals, expired `isExpired` flags, or stale `shelfPhotoUpdatedAt`) — these appear to be computed properties evaluated on read (`isLightningDealActive`, etc.), not enforced by any cron/cloud function.

## 9. Security

- **Firestore rule for `products/{productId}`: `allow write: if isSignedIn() && isGlobalAdmin();`** — this closes the worst-case "any authenticated user can write products" concern: only owner/admin roles can write at all, via any of the three code paths. This is a real mitigating control that narrows the earlier-suspected gap.
- **Remaining gap is process, not authorization:** because the rule only checks *who*, not *how*, an authorized owner's CSV bulk-import (`batchAddProducts`) or single-field edit (`updateProduct`) still bypasses the review-before-write intent of the approval-workflow services, and bypasses audit logging entirely for `addProduct`/`batchAddProducts`/`deleteProduct`. This is the same "policy exists in one place but not enforced everywhere it should be" pattern already flagged for Auth in Module 1.
- **P0 — SQL injection / malformed-SQL risk** in `ApprovalWorkflowService.approveRequest` (`entityType == 'inventory'` branch), detailed in Section 6. Any value containing a single quote, semicolon, or SQL-meaningful character in a proposed inventory change would either throw or — worse — execute unintended SQL, since values are interpolated as raw Dart string concatenation, not bound parameters.
- **Barcode uniqueness** (`isBarcodeUnique`) is enforced at the application layer only, with no apparent Firestore rule or unique-index equivalent backing it — a race between two near-simultaneous adds with the same barcode is theoretically possible (read-then-write, not a transaction).
- **Image upload** has no visible file-type/size validation before `ref.putFile(file)` — relies entirely on Firebase Storage bucket rules (not audited in this pass) to reject anything unwanted.

## 10. Failure Cases

- CSV bulk import: row-level try/catch already exists (`errors.add('Row ${i+1}: $e')`), but a `batchAddProducts` chunk failure mid-way (e.g., chunk 2 of 50-row batches throws) leaves earlier chunks committed and later chunks not — no rollback, no partial-success reconciliation reported back to the user beyond the generic `'Batch Write Failed: $e'` string, which doesn't say which chunk/rows succeeded.
- `approveAllPriceChanges` loops `approvePriceChange` per id without an outer transaction — if the loop throws partway through a large batch, some price changes are applied and marked approved while later ones are not, with no resumable cursor or reported partial state.
- `ApprovalWorkflowService.approveRequest`: if the dynamic SQL in the `inventory` branch throws due to a malformed value (see P0 above), the request is never marked approved — the proposer sees a stuck "pending" request with no specific error surfaced (caught generically, returns `false`).
- `Supabase` dual-write in `InventoryChangeRequestService.approveRequest` is wrapped in its own try/catch per product and merely `debugPrint`s on failure — Firestore (source of truth for the app) and Supabase can silently diverge with no retry queue or alerting (contrast with the `dead_letter_rds_sync` collection seen in `firestore.rules`, which suggests a dead-letter pattern exists elsewhere in the app but is not wired into this particular dual-write call).

## 11. Testing

No product-management-specific test file was located in this audit pass (the only test-named file seen anywhere in `lib/services` during this module's greps was `order_repository_test.dart` and `profit_service_test_data.dart`, both unrelated to products). Recommended minimum coverage before production sign-off: (a) `batchAddProducts` chunk-failure/partial-commit behavior, (b) the SQL-injection-shaped `approveRequest` inventory branch with adversarial/edge-case proposed values, (c) `addProductReview`'s transactional rating-average math under concurrent submissions, (d) barcode-uniqueness race condition, (e) low-stock alert severity-threshold boundaries.

## 12. Production Readiness

Not production-ready as-is for the specific guarantee the user has standing as policy ("bulk changes must go through approval, never direct to `products`"): that guarantee is true only for changes originating from the Inventory Query Builder UI, not for CSV bulk import or any direct `ProductService.updateProduct`/`addProduct` call site. The SQL-injection-shaped bug in `ApprovalWorkflowService` is a hard blocker regardless of the approval-flow question. The two parallel approval systems (Firestore-based vs. Postgres-based) should be reconciled into one before launch, or explicitly documented as serving different entity types with no overlap — currently undocumented and ambiguous from the code alone.

---

## FINAL OUTPUT FORMAT

### A. Current State Audit

Three Firestore/Postgres write paths exist for product/inventory data with inconsistent gating: `ProductService` (direct, partially audited), `InventoryChangeRequestService` (Firestore approval-gated, fully audited), `ApprovalWorkflowService` (Postgres approval-gated, fully audited but with a SQL-injection-shaped flaw). Firestore security rules correctly restrict all `products` writes to global-admin roles, which mitigates unauthorized access but does not enforce the review-before-write *process* the project's standing policy requires. A correctly-built transactional price-proposal system (`price_change_proposals`) coexists with — and can be bypassed by — `updateProduct`'s direct price-write branch.

### B. Missing Components

1. A single unified bulk-change gate that all UI surfaces (CSV import, single-product edit, query-builder bulk edit) are required to route through — currently three surfaces, three different levels of audit/review.
2. Parameterized SQL in `ApprovalWorkflowService.approveRequest`'s `inventory` branch (P0).
3. A consumer UI/screen for `getPendingPriceChangesStream`/`getPriceChangesHistoryStream` (not located — may exist under an unread file, or may be a genuine gap).
4. A managed `categories` Firestore collection + admin screen, if categories are meant to be owner-editable rather than fixed to the `ProductCategory` enum (currently enum-driven; `CategoryModel.fromMap`/`toMap` exist but no live collection read site was found beyond seed data).
5. Reconciliation/alerting for Firestore↔Supabase dual-write divergence on `InventoryChangeRequestService.approveRequest` (currently silent `debugPrint`-only failure).
6. Atomicity for `approveAllPriceChanges` (currently a non-transactional loop).
7. Audit logging on `ProductService.addProduct`, `batchAddProducts`, `deleteProduct` (currently only `updateProduct`'s price/stock branches are logged).
8. Image validation (type/size) before upload in `StorageService.uploadImage`.

### C. Architecture Design

Recommend collapsing to a single approval entry point: all product/inventory mutations — single or bulk, from any UI surface — construct an `InventoryChangeRequestModel`-shaped request (extending its `type`/`changes` model to also cover `create` operations for CSV import, not just `fieldUpdate`/`stockAdjustment`/etc.) and route through `InventoryChangeRequestService`. Retire or clearly scope `ApprovalWorkflowService` to a distinct, non-overlapping use case (e.g., if it's meant for a future Postgres-of-record migration, document that explicitly; otherwise fix its SQL injection and unify it with the Firestore path via a shared interface). Auto-approve low-risk single-item owner edits if desired for UX speed, but still write through the same audited path rather than a separate direct-write method, so there is exactly one place where "did this touch `products`" is logged.

### D. Implementation Plan

1. Fix the SQL injection in `ApprovalWorkflowService.approveRequest` (parameterize the `inventory` branch) — do this first, independent of anything else, since it's a standalone correctness/security bug.
2. Extend `InventoryChangeRequestModel`/`InventoryChangeType` to support a `create` (bulk-add) type carrying full `ProductModel` payloads, not just field diffs.
3. Rewrite the CSV bulk-import flow in `products_management.dart` to call `InventoryChangeRequestService.createChangeRequest` (or a new `createBulkCreateRequest` helper) instead of `ProductService.batchAddProducts` directly.
4. Add audit logging to `ProductService.addProduct`/`deleteProduct` (mirror the pattern already used in `updateProduct`), as a stopgap for any direct-write call site that isn't yet migrated to the approval path.
5. Decide and document the relationship between `ApprovalWorkflowService`/Postgres and `InventoryChangeRequestService`/Firestore — either retire one or formally scope them to non-overlapping entity types.
6. Wire `approveAllPriceChanges` into a single Firestore transaction (or batched writes with an explicit rollback/resume cursor) instead of a bare loop.
7. Add a retry/dead-letter path for the Supabase dual-write failure case in `InventoryChangeRequestService.approveRequest`, consistent with the `dead_letter_rds_sync` pattern already used elsewhere in the app.

### E. File-by-file Changes

- `lib/services/approval_workflow_service.dart` — parameterize the `inventory` UPDATE in `approveRequest`; allowlist `targetField`/`targetTable` in `approveBulkOperation` before string-interpolating them into SQL.
- `lib/services/product_service.dart` — add `AuditService.logAction` calls to `addProduct`, `batchAddProducts` (per-chunk or per-batch summary), and `deleteProduct`; consider deprecating `batchAddProducts` as a public direct-write entry point once step 3 of the Implementation Plan lands.
- `lib/screens/owner/products_management.dart` — replace the direct `productService.batchAddProducts(bulkItems)` call (line ~1555) with a call into the (extended) `InventoryChangeRequestService`, and update the success/status messaging to reflect "submitted for approval" rather than "uploaded."
- `lib/models/inventory_change_request_model.dart` — add a `create` variant to `InventoryChangeType` and a payload field capable of carrying full new-product data, not just `InventoryFieldChange` diffs against existing products.
- `lib/services/inventory_change_request_service.dart` — add a retry/dead-letter write (or at minimum a Firestore-logged failure record) when the Supabase dual-write in `approveRequest` throws, instead of `debugPrint`-only.
- `lib/services/product_service.dart` (`approveAllPriceChanges`) — wrap in `runTransaction`/batched-with-resume logic instead of a bare per-id loop.

### F. Production Checklist

- [ ] SQL injection in `ApprovalWorkflowService.approveRequest` fixed and covered by a test with adversarial input
- [ ] All product-mutating UI surfaces (single edit, CSV bulk import, query-builder bulk edit) route through one approval-gated service
- [ ] Audit log entries exist for every `products` write, not just price/stock via `updateProduct`
- [ ] Firestore↔Supabase divergence on dual-write failure is retried or surfaced, not silently dropped
- [ ] `approveAllPriceChanges` is atomic or safely resumable
- [ ] Relationship between the Firestore-based and Postgres-based approval systems is documented or one is retired
- [ ] Barcode-uniqueness check is race-safe (transaction or server-side enforcement)
- [ ] Image upload validates file type/size before storage write
