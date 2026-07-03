# Sprint 2A: Remove P0 Dangerous Firestore Writes

**Status:** IN PROGRESS
**Timeline:** 1 week
**Priority:** HIGHEST (blocks production rollout)

---

# The 5 P0 Files

## File 1: packing_terminal_screen.dart ✅ REFACTORED

**Status:** ✅ DONE (see packing_terminal_screen_v2.dart)

**Change Summary:**
- Old: `await firestore.collection('orders').doc(order.id).update({...})`
- New: `await api.post('/admin/orders/$orderId/pack', {...})`

**Impact:**
- ✅ No more direct Firestore writes
- ✅ Backend API handles atomic transaction
- ✅ PostgreSQL locks prevent double-packing
- ✅ Inventory validated before consumption

**Lines Changed:** ~50 lines in _packOrder()
**Testing:** Manual test with 2 simultaneous pack requests (should fail one)

---

## File 2: refund_processing_screen.dart ⚠️ TODO

**Location:** `lib/screens/owner/refund_processing_screen.dart`
**Lines:** ~480-540

**Current Dangerous Code:**
```dart
// LINE 481
await FirebaseFirestore.instance.collection('refund_requests').doc(current.id).update({
  'bankAccountHolderName': details['name'],
  'bankAccountNumber': details['account'],
  'bankIfsc': details['ifsc'],
});

// LINE 510
await FirebaseFirestore.instance.collection('refund_requests').doc(current.id).update({
  'payoutId': data['payoutId'],
});

// LINE 532
await FirebaseFirestore.instance.collection('refund_requests').doc(current.id).update({
  'payoutId': ref,
});
```

**Problem:**
- Owner directly updates refund status
- No backend verification
- No payment gateway confirmation
- 3 separate non-atomic writes

**Fix:**
```dart
// REPLACE with:
final result = await api.post(
  '/admin/payments/$orderId/refund',
  {
    'reason': 'customer_requested',
    'bankAccountHolderName': details['name'],
    'bankAccountNumber': details['account'],
    'bankIfsc': details['ifsc'],
    'idempotencyKey': uuid.v4(),
  }
);

// Backend handles:
// 1. Verify payment gateway
// 2. Validate refund amount
// 3. Create atomic transaction
// 4. Audit log everything
```

**Effort:** 30 minutes
**Testing:** Test refund flow + verify audit log

---

## File 3: razorpay_service.dart ⚠️ TODO

**Location:** `lib/services/razorpay_service.dart`
**Lines:** ~192-210

**Current Dangerous Code:**
```dart
// LINE 192
await _firestore.collection('orders').doc(orderId).update({
  'paymentStatus': 'paid',
  'paymentId': paymentId,
  'status': 'OrderStatus.confirmed',
  ...
});

// LINE 207
await _firestore.collection('orders').doc(orderId).update({
  'paymentStatus': 'failed',
  'updatedAt': FieldValue.serverTimestamp(),
});
```

**Problem:**
- Client marks order as paid (FRAUD RISK)
- No Razorpay webhook verification
- No reconciliation with payment gateway
- No audit trail

**Fix:**
```dart
// REPLACE with:
final result = await api.post(
  '/admin/payments/verify',
  {
    'orderId': orderId,
    'razorpay_order_id': response['razorpay_order_id'],
    'razorpay_payment_id': response['razorpay_payment_id'],
    'razorpay_signature': response['razorpay_signature'],
    'expectedAmount': orderAmount,
  }
);

if (result['success']) {
  // Backend verified signature, updated order status
  // Firestore synced eventually
}
```

**Effort:** 20 minutes
**Testing:** Test with valid + invalid signatures, verify backend rejects spoofed payments

---

## File 4: payment_router_service.dart ⚠️ TODO

**Location:** `lib/services/payment_router_service.dart`

**Description:** Likely has payment status updates
**Pattern:** Same as razorpay_service.dart

**Effort:** 20 minutes

---

## File 5: order_status_engine.dart ⚠️ TODO

**Location:** `lib/services/order_status_engine.dart`

**Description:** Likely updates order status on state transitions
**Pattern:** Similar to packing_terminal_screen

**Effort:** 30 minutes

---

# Refactoring Template

For each file:

### Step 1: Identify all firestore writes
```bash
grep -n "firestore\|Firestore" lib/services/payment_router_service.dart
```

### Step 2: Find the API endpoint in backend
```bash
# E.g., for payment:
grep -n "router.post" backend/src/routes/payments_v3.js
```

### Step 3: Replace write with API call
```dart
// OLD (DANGEROUS)
await firestore.collection('X').update({...});

// NEW (SAFE)
await api.post('/admin/X/action', {...});
```

### Step 4: Update AdminApiService if needed
If endpoint doesn't exist, add it to `lib/services/admin_api_service.dart`

### Step 5: Test
```bash
# Unit test
flutter test test/services/payment_router_service_test.dart

# Manual test
# Run app, trigger flow, verify:
# - No Firestore direct writes in logs
# - API call succeeds
# - Backend audit log created
```

---

# Testing Checklist (Per File)

## Packing Terminal ✅
- [x] Refactored to use API
- [ ] Manual: 1 employee packs → success
- [ ] Manual: 2 employees pack same item simultaneously → 1 succeeds, 1 fails
- [ ] Verify PostgreSQL inventory deducted atomically
- [ ] Verify audit log created

## Refund Processing
- [ ] Refactored to use API
- [ ] Manual: Admin initiates refund → success
- [ ] Manual: 2 admins refund same order simultaneously → idempotency works
- [ ] Verify backend validates refund amount
- [ ] Verify audit log shows who/what/when

## Razorpay Service
- [ ] Refactored to use API
- [ ] Manual: Valid signature → order marked paid ✓
- [ ] Manual: Invalid signature → order stays pending ✓
- [ ] Manual: Missing signature → rejected ✓
- [ ] Verify no client-side payment status updates possible

## Payment Router Service
- [ ] Refactored to use API
- [ ] Manual: Payment state transition → API handles
- [ ] Verify audit trail complete

## Order Status Engine
- [ ] Refactored to use API
- [ ] Manual: Status transitions work correctly
- [ ] Verify transactional consistency

---

# Rollback Risks (Minimal)

If something breaks:
```dart
// Just revert to old code path
// Old code still works during migration period
```

Feature flag will handle gradual rollout.

---

# Success Criteria

✅ All 5 files refactored
✅ Zero direct Firestore writes from these 5 files
✅ All APIs used instead
✅ All tests pass
✅ Manual testing confirms behavior unchanged

After this:
- Packing is atomic
- Refunds are verified
- Payments are fraud-proof
- Orders are transactional

---

# Timeline

| File | Effort | Day |
|------|--------|-----|
| packing_terminal_screen | 30 min | 1 |
| refund_processing_screen | 30 min | 1 |
| razorpay_service | 20 min | 2 |
| payment_router_service | 20 min | 2 |
| order_status_engine | 30 min | 2 |
| Testing | 2 hours | 3-4 |
| **Total** | **6 hours** | **~1 day** |

---

# Reference: API Endpoints

```
POST /admin/orders/:id/pack
  → Atomically pack order + consume inventory

POST /admin/payments/verify
  → Verify Razorpay signature + mark paid

POST /admin/payments/:id/refund
  → Initiate refund (idempotent)

POST /inventory/adjust
  → Adjust stock atomically

POST /inventory/reserve
  → Reserve for pending order
```

All documented in BACKEND_COMMERCE_ENGINE_BUILD.md

---

# After Sprint 2A

Fufaji will have:
- ✅ Zero production overselling risk
- ✅ Zero payment fraud risk
- ✅ Zero double-packing risk
- ✅ 100% transactional safety

Ready for Production Rollout.
