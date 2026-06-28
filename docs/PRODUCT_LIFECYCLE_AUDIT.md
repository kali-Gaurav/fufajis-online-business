# WORKFLOW AUDIT: PRODUCT LIFECYCLE
Target: 90%+ Production Readiness

## Phase 1: File Discovery
The following files have been identified as part of the Product Lifecycle:

### Core Logic & State
- [ ] `lib/models/product_model.dart` (Data Structure)
- [ ] `lib/services/product_service.dart` (Firestore Operations)
- [ ] `lib/providers/product_provider.dart` (State Management)
- [ ] `lib/services/storage_service.dart` (Image Uploads)
- [ ] `lib/services/global_catalog_service.dart` (Pre-filled product data)

### UI - Owner / Admin
- [ ] `lib/screens/owner/products_management.dart` (Main Catalog UI)
- [ ] `lib/screens/owner/add_product_screen.dart` (Create/Edit Form)
- [ ] `lib/screens/owner/pending_price_changes_screen.dart` (Approval UI)
- [ ] `lib/screens/admin/product_moderation_screen.dart` (Moderation Queue)
- [ ] `lib/widgets/voice_to_stock_dialog.dart` (Voice Entry)

### UI - Infrastructure
- [ ] `lib/screens/customer/barcode_scanner_screen.dart` (Hardware Integration)
- [ ] `lib/services/image_processing_service.dart` (AI Background Removal)

---

## Phase 2: Workflow Status Mapping

### 1. Create Product (Smart Add)
- **UI:** Owner selects product from Global Catalog or enters manually.
- **Validation:** Basic null checks present.
- **Hardware:** Barcode scanner integrated.
- **Images:** Supports multiple images + AI background removal.
- **Gaps:** Barcode duplicate prevention logic needed in Service.

### 2. Update Product
- **UI:** Edit form pre-populated.
- **Logic:** Atomic updates via `ProductService`.
- **Audit:** `AuditService` logs stock and price changes.
- **Gaps:** Search index refresh trigger verification.

### 3. Price Change Approval
- **UI:** Stream-based list for Owner.
- **Logic:** Transactional approval/rejection.
- **Gaps:** Bulk approval currently iterates; needs batch write for performance.

---

## Phase 3: Detailed File Audit (Checklist)

### `product_service.dart`
- [x] All methods implemented
- [ ] Transactional integrity for all writes
- [ ] TODO cleanup
- [ ] Hardcoded values removal

### `product_provider.dart`
- [ ] notifyListeners() optimization (avoid redundant rebuilds)
- [ ] Loading/Error state consistency
- [ ] Pagination logic verification

---

## Phase 4: Firestore & Security Audit
- **Collections:** `products`, `price_changes`, `low_stock_alerts`
- **Rules:**
  - [x] Create/Update restricted to Owner/Admin.
  - [x] Read allowed for all.
  - [ ] Schema validation (ensure mandatory fields like `shopId`).

---

## Phase 5: Android & UI Audit
- [ ] 320dp (Small device) overflow check
- [ ] Keyboard overlap in `AddProductScreen`
- [ ] Image aspect ratio consistency in grid

---

## Phase 6: Missing Feature Detection
1. **Barcode Duplicate Prevention:** Prevent adding two products with the same barcode in one shop.
2. **Bulk Upload Progress:** Visual feedback for large CSV imports.
3. **Category Management:** UI for Owners to add custom categories.

---

## Phase 7: Production Readiness Score
| Area | Score |
| --- | --- |
| UI Consistency | 65% |
| Logic & Integrity | 80% |
| Firebase Security | 90% |
| Performance | 75% |
| Android Compatibility | 70% |
| **Overall Score** | **75%** |
