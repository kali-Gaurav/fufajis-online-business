# DEEP AUDIT: ORDERS & FULFILLMENT

Module: Orders, Packing, Delivery, Settlements, Returns
Target: Phase 4 Production Hardening

## 1. DATA INTEGRITY & WORKFLOW

| Checkpoint | Status | Risk | Fix / Note |
| --- | --- | --- | --- |
| Transactional Status Updates | ✅ Pass | Race conditions on concurrent packer updates | Refactored `updateOrderStatus` to use `runTransaction`. |
| Packer Lock Mechanism | ✅ Pass | Multiple employees packing same order | Enforced in `OrderService` logic. |
| Inventory Deduction | ✅ Pass | Stock dipping below zero | Transactional deduction implemented. |
| Settlement Generation | 🟡 Partial | COD cash collected but not verified | `CodSettlementModel` exists but needs better linking to `delivered` status. |
| Return Logic | ✅ Pass | Customer returning only partial order | `ReturnRequest` supports `itemIds` list. |
| Refund Duplication | 🔴 High | Multiple clicks on refund button | Need to disable button or add a `processing` state in `SettlementsManagementScreen`. |

## 2. FIRESTORE STRUCTURE (COLLECTIONS)

| Collection | Correctness | Security | Performance |
| --- | --- | --- | --- |
| `orders` | ✅ | ✅ | Needs index for `customerId` + `createdAt`. |
| `return_requests` | ✅ | ✅ | Standard CRUD. |
| `cod_settlements` | ✅ | ✅ | Scoped to branch. |
| `secure/otp` | ✅ | ✅ | Plain text OTP isolated in secure subcollection. |

## 3. UI / UX & RESPONSIVENESS

| Screen | Issues Found | Device Risk | Recommended Fix |
| --- | --- | --- | --- |
| Packing Dashboard | Horizontal scroll only | Tablet only | Works on Tablet; Mobile needs a single-col list view. |
| Order Detail | Long item names overflow | Small mobile | Use `maxLines` + `TextOverflow.ellipsis`. |
| Settlements | Many columns in table | Overflow | Switch to Card-based view for Mobile (like POS). |

## 4. MISSING LOGIC / STUBS

- [ ] **Rider Cash Limit:** Prevent assigning orders to riders if their un-settled cash exceeds ₹5000.
- [ ] **Auto-Cancel:** Cancel `pending` orders after 60 minutes if store doesn't confirm.
- [ ] **Refund Notification:** Trigger FCM + WhatsApp when refund is `approved`.

## 5. REUSABLE COMPONENTS AUDIT

| Component | Consistency | Theme | Note |
| --- | --- | --- | --- |
| `FjEmptyState` | ✅ | ✅ | Used in Orders & Delivery. |
| `FjErrorState` | ✅ | ✅ | Used in Delivery. |
| `FjButton` | 🟡 | 🟡 | Many screens still use `ElevatedButton` directly. |
| `FjCard` | 🟡 | 🟡 | Many screens still use `Card` or `Container` with shadow. |

---

## PRODUCTION READINESS SCORE: 72%
**Priority for Next Update:**
1. Global search and replace of `ElevatedButton` -> `FjButton`.
2. Implement Rider Cash Limit.
3. Link COD collection to POD flow.
