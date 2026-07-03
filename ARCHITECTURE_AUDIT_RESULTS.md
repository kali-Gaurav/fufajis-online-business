# Architecture Audit Results — July 2, 2026

## Executive Summary

**Status:** CRITICAL ARCHITECTURAL DEBT

Fufaji has Firestore-first writes across 50+ files. Sync direction is backwards. This threatens data integrity for payments, inventory, and orders.

**Recommendation:** Execute Option C (Controlled Hybrid Migration) over 4 sprints.

---

# Deliverable 1: Backend Route Audit

## Current State

**File:** `backend/src/routes/admin.js`

**Routes found:**
```javascript
line 16:  router.post('/roles/set', ...)           // Set user role
line 62:  router.post('/claims/sync', ...)        // Sync claims
line 112: router.post('/claims/sync-user', ...)   // Sync claims for user
```

**Assessment:** ❌ **CRITICAL GAP**

What exists:
- ✅ Role management
- ✅ Claims sync

What's MISSING (needed for Phase 1):
- ❌ Products CRUD (GET, POST, PUT, DELETE)
- ❌ Inventory adjust (POST)
- ❌ Inventory reserve/release
- ❌ Orders management
- ❌ Order packing
- ❌ Payment processing
- ❌ Refund processing

**Implication:** We must build backend APIs from scratch for P0 domains.

---

# Deliverable 2: Dangerous Write Audit

## P0 Files with Direct Firestore Writes

### File 1: `packing_terminal_screen.dart` (HIGH RISK)

**Line 666:**
```dart
await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
  'status': 'OrderStatus.packed',
  'packingTimeSeconds': _packingTimer?.elapsed.inSeconds ?? 0,
  'packedWeights': finalWeights,
  ...
});
```

**Problem:** Employee packs order → Directly updates order status in Firestore
- ❌ No inventory lock
- ❌ No transaction
- ❌ No audit log
- ❌ Race condition: 2 employees pack same order

**Impact:** CRITICAL — Can oversell inventory

---

### File 2: `refund_processing_screen.dart` (CRITICAL RISK)

**Line 481:**
```dart
await FirebaseFirestore.instance.collection('refund_requests').doc(current.id).update({
  'bankAccountHolderName': details['name'],
  'bankAccountNumber': details['account'],
  'bankIfsc': details['ifsc'],
});
```

**Line 510:**
```dart
await FirebaseFirestore.instance.collection('refund_requests').doc(current.id).update({
  'payoutId': data['payoutId'],
});
```

**Line 532:**
```dart
await FirebaseFirestore.instance.collection('refund_requests').doc(current.id).update({
  'payoutId': ref,
});
```

**Problem:** Refund status updates directly to Firestore
- ❌ Owner modifies refund state without backend validation
- ❌ Payouts initiated without settlement verification
- ❌ No payment gateway confirmation
- ❌ 3 separate writes (not atomic)

**Impact:** CRITICAL — Can cause financial loss, refund fraud

---

### File 3: `razorpay_service.dart` (CRITICAL RISK)

**Line 192:**
```dart
await _firestore.collection('orders').doc(orderId).update({
  'paymentStatus': 'paid',
  'paymentId': paymentId,
  'status': 'OrderStatus.confirmed',
  ...
});
```

**Line 207:**
```dart
await _firestore.collection('orders').doc(orderId).update({
  'paymentStatus': 'failed',
  'updatedAt': FieldValue.serverTimestamp(),
});
```

**Problem:** Payment status updated directly by client
- ❌ No Razorpay webhook verification
- ❌ Client can mark any order as paid
- ❌ No reconciliation
- ❌ No audit trail

**Impact:** CRITICAL — Direct payment fraud risk

---

## Risk Summary

| File | Writes | Risk | Impact |
|------|--------|------|--------|
| packing_terminal_screen | 1 | Inventory oversell | ₹ + Stock |
| refund_processing_screen | 3 | Payment fraud | ₹₹₹ |
| razorpay_service | 2 | Payment fraud | ₹₹₹ |
| **Total P0** | **6** | **CRITICAL** | **Business-breaking** |

These 3 files alone could cause:
- Negative inventory
- Unauthorized refunds
- Payment fraud

---

# Deliverable 3: Architecture Freeze Rule

## EFFECTIVE IMMEDIATELY

### Policy: No New Direct Firestore Writes for Critical Data

**FROZEN DOMAINS:**
```
❌ products
❌ inventory  
❌ orders
❌ payments
❌ refunds
❌ settlements
```

**ALLOWED (Firestore-native only):**
```
✅ chat
✅ live location tracking
✅ notifications
✅ presence/ephemeral
✅ temporary queues
```

---

## Enforcement Rule

**For every PR touching critical domains:**

1. **Code review checklist:**
   - [ ] No `FirebaseFirestore.instance.collection('products')`
   - [ ] No `FirebaseFirestore.instance.collection('inventory')`
   - [ ] No `FirebaseFirestore.instance.collection('orders')`
   - [ ] No `.update(...)` on order/inventory/payment docs
   - [ ] All writes go through API service

2. **If violation found:**
   - PR blocked
   - Rewrite required
   - Route through backend API

---

## Migration Path (4 Sprints)

### Sprint 1: Core Commerce APIs
- Build backend routes for products, inventory, orders, payments
- Refactor packing_terminal_screen
- Refactor refund_processing_screen
- Fix razorpay_service

### Sprint 2: Owner + Employee Screens
- Refactor employee_management_screen
- Refactor shop_settings_screen
- Refactor cod_limit_management_screen

### Sprint 3: Services Cleanup
- Migrate 35+ service files
- Remove direct Firestore writes

### Sprint 4: Cleanup + Validation
- Remove old sync assumptions
- Finalize Firestore → PostgreSQL one-way mirror
- Validation pass

---

## New Architecture (After Migration)

```
Client Request
  ↓
API Route (backend)
  ↓
PostgreSQL Transaction (with locks)
  ↓
Firestore Write (after success)
  ↓
Cloud Function (redundant sync)
  ↓
✅ Strong consistency
✅ Audit trail
✅ Transaction safety
✅ Fraud prevention
```

---

## Sign-Off

This audit identifies the exact scope and risk of the current architecture.

**Decision:** Proceed with Option C (Controlled Hybrid Migration).

**Timeline:** 4 sprints starting Week 1.

**Owner:** Architecture team.
