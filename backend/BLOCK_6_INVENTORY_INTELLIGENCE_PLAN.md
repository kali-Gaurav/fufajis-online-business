# BLOCK 6: INVENTORY INTELLIGENCE VALIDATION
**Stock Management, Locking, Alerts & Reorder Automation**

**Timeline:** ~90 minutes (parallel execution)  
**Start:** After seeding Batches 1-2-3  
**Target Score:** 100% (all tests pass)

---

## OVERVIEW

Fufaji's inventory system must prevent overselling, track stock accurately, and trigger alerts when items run low. This block validates the complete stock lifecycle.

---

## CORE FUNCTIONS TO TEST

### 1. Stock Quantity Accuracy (Supabase ↔ Firestore)
**Purpose:** Ensure stock is synced correctly between source (Supabase) and cache (Firestore)

**Setup:**
```sql
-- In Supabase, verify initial stock for top 10 products
SELECT product_id, SUM(quantity) as total_stock 
FROM catalog_variants 
GROUP BY product_id 
LIMIT 10;
```

**Test 6.1: Initial Stock Sync**
```
Action:   Create order for 1 unit of "Parle-G Biscuits" (SNK_001_150G)
Expected: Firestore stock decreases from 500 → 499
Timeline: <2 seconds
Result:   ✅ / ❌
```

---

### 2. Stock Locking (Prevent Overselling)
**Purpose:** When customer adds item to cart, lock quantity so it can't be sold twice

**Test 6.2: Lock on Add-to-Cart**
```
Scenario:
  Customer A adds 100 units to cart (but we only have 50 total)
  
Expected Behavior:
  Case 1 (Soft Lock): Cart shows 100, but at checkout shows "only 50 available"
  Case 2 (Hard Lock): Add-to-cart blocked at 50 units

Implementation: 
  → Use Firestore transaction to lock inventory
  → Max 30s lock duration
  → Unlock on cancel or checkout timeout
  
Result: ✅ / ❌
```

**Test 6.3: Concurrent Orders Don't Oversell**
```
Scenario:
  Stock = 10 units for "Milk 1L" (BEV_001_1L)
  Customer A orders 8 units (locked, pending payment)
  Customer B tries to order 5 units (should fail: only 2 left)

Expected:
  Customer A: ✅ Order succeeds (payment processed)
  Customer B: ❌ "Only 2 units available"
  
Database Result:
  Final stock = 2 (8 sold to A, none to B)
  
Result: ✅ / ❌
```

---

### 3. Stock Restoration (Cancel/Refund)
**Purpose:** When order is cancelled or refunded, release reserved stock back

**Test 6.4: Restore on Order Cancel**
```
Setup:
  Initial: Maggi Noodles (PAK_001_75G) stock = 500
  Order 1: Customer purchases 50 units (locked)
  Stock now = 450

Action:
  Customer cancels Order 1

Expected:
  Stock restored → 500 (fully)
  Refund processed
  System log shows restore event
  
Timeline: <5 seconds
Result: ✅ / ❌
```

**Test 6.5: Partial Refund**
```
Scenario:
  Order for 5 units, customer returns 2 units

Expected:
  Stock increase by 2
  Refund = (item_price × 2) - return_fee
  Order status = "partially_returned"
  
Result: ✅ / ❌
```

---

### 4. Low-Stock Alerts
**Purpose:** Notify store admin when stock drops below threshold

**Test 6.6: Alert Triggers at Threshold**
```
Setup:
  Product: Colgate Toothpaste (PER_001_75G)
  Initial stock: 100 units
  Low-stock threshold: 20 units (20%)

Scenario:
  Customer orders 81 units
  Stock = 19 (below threshold)

Expected:
  Alert generated in Firestore: alerts/PER_001_75G
  Alert contains: product_id, current_stock, threshold, timestamp
  Admin receives notification (email/SMS/dashboard)
  
Result: ✅ / ❌
```

**Test 6.7: Alert Clears When Restocked**
```
Scenario:
  Alert is active (stock = 19)
  New purchase order received: +50 units
  Stock = 69 (above threshold)

Expected:
  Alert resolved (marked as cleared)
  Admin notification: "Colgate Toothpaste back in stock"
  
Result: ✅ / ❌
```

---

### 5. Reorder Engine (Auto-Generate PO)
**Purpose:** When stock falls below minimum, auto-generate purchase order for restocking

**Test 6.8: Reorder Triggers**
```
Setup:
  Product: Coca-Cola (BEV_001_250ML)
  Min stock: 50 units
  Reorder quantity: 200 units
  Current stock: 150

Scenario:
  Customer orders 105 units
  Stock = 45 (below min)

Expected:
  PO generated automatically:
  {
    "po_id": "PO_20260704_001",
    "product_id": "BEV_001_250ML",
    "quantity": 200,
    "status": "pending",
    "supplier_id": "SUPPLIER_001",
    "created_at": "2026-07-04T16:30:00Z"
  }
  
  Admin notification: "PO created for Coca-Cola"
  
Result: ✅ / ❌
```

**Test 6.9: Reorder Consolidation**
```
Scenario:
  Multiple products low on stock in same supplier
  - Parle-G: needs 200 units
  - Lay's: needs 150 units
  - Kurkure: needs 100 units (different supplier)

Expected:
  PO 1 (Supplier A): Parle-G + Lay's combined
  PO 2 (Supplier B): Kurkure alone
  
System avoids fragmented POs
Result: ✅ / ❌
```

---

### 6. Multi-Warehouse Sync (If Applicable)
**Purpose:** Ensure stock is accurate across multiple warehouses

**Test 6.10: Warehouse Sync**
```
Setup (if multi-warehouse):
  Warehouse A: Delhi (100 units of Milk)
  Warehouse B: Mumbai (50 units of Milk)
  Central inventory: 150 units

Scenario:
  Order in Mumbai (10 units)

Expected:
  Warehouse B: 40 units
  Central: 140 units
  Both synced within <3 seconds
  
Result: ✅ / ❌
```

---

## QA CHECKLIST

### Pre-Test Validation
- [ ] Seeded 165 products to Supabase
- [ ] Supabase → Firestore sync verified (445 records)
- [ ] Initial stock counts verified (spot check 10 products)
- [ ] Firestore indexes active (queries <100ms)
- [ ] Test environment ready (no production interference)

### Test Execution
- [ ] Test 6.1: Stock Sync — PASS / FAIL
- [ ] Test 6.2: Add-to-Cart Lock — PASS / FAIL
- [ ] Test 6.3: Concurrent Order Prevention — PASS / FAIL
- [ ] Test 6.4: Restore on Cancel — PASS / FAIL
- [ ] Test 6.5: Partial Refund — PASS / FAIL
- [ ] Test 6.6: Alert Triggers — PASS / FAIL
- [ ] Test 6.7: Alert Clears — PASS / FAIL
- [ ] Test 6.8: Reorder Triggers — PASS / FAIL
- [ ] Test 6.9: Reorder Consolidation — PASS / FAIL
- [ ] Test 6.10: Multi-Warehouse Sync — PASS / FAIL (if applicable)

### Post-Test Analysis
- [ ] All 10 tests passed (or document failures)
- [ ] Stock counts final verified (spot check 10 products)
- [ ] Audit logs reviewed (all operations logged)
- [ ] Performance metrics collected (avg latency)
- [ ] Security review (no unauthorized access)

---

## SUCCESS CRITERIA

### Target: 100% Pass Rate
```
✅ 10/10 tests passing = PROCEED TO BLOCKS 7-8
⚠️  8-9/10 tests passing = MINOR ISSUES (fixable)
❌ <8/10 tests passing = CRITICAL ISSUE (investigate)
```

### Performance Targets
- Stock lookup: <100ms
- Order creation: <500ms
- Alert generation: <2s
- Reorder creation: <5s

### Data Integrity Targets
- No orphaned stock (all items accounted for)
- No double-sells (concurrent order safety)
- 100% audit trail (all operations logged)

---

## IMPLEMENTATION CODE SNIPPETS

### Service: InventoryService.dart
```dart
/// Stock locking with timeout
Future<bool> lockStock(String variantId, int quantity, {Duration? timeout}) async {
  timeout ??= Duration(seconds: 30);
  final lockRef = FirebaseFirestore.instance
      .collection('inventory_locks')
      .doc('$variantId-${DateTime.now().millisecondsSinceEpoch}');
  
  await lockRef.set({
    'variant_id': variantId,
    'quantity_locked': quantity,
    'locked_at': Timestamp.now(),
    'expires_at': Timestamp.fromDate(DateTime.now().add(timeout)),
    'user_id': getCurrentUserId(),
  });
  
  return true;
}

/// Release lock on cancel
Future<void> releaseStock(String variantId, int quantity) async {
  final variantRef = FirebaseFirestore.instance
      .collection('catalog_variants')
      .doc(variantId);
  
  await variantRef.update({
    'stock': FieldValue.increment(quantity),
  });
}

/// Check low-stock threshold
Future<void> checkLowStockAlert(String variantId, int currentStock, int threshold) async {
  if (currentStock < threshold) {
    await FirebaseFirestore.instance.collection('alerts').add({
      'type': 'low_stock',
      'variant_id': variantId,
      'current_stock': currentStock,
      'threshold': threshold,
      'created_at': Timestamp.now(),
      'status': 'active',
    });
  }
}

/// Auto-generate PO
Future<void> triggerReorder(String productId, int reorderQty) async {
  await FirebaseFirestore.instance.collection('purchase_orders').add({
    'product_id': productId,
    'quantity': reorderQty,
    'status': 'pending',
    'created_at': Timestamp.now(),
  });
}
```

---

## ROLLBACK PLAN

If critical inventory issues found:
```
1. Pause all new orders (set maintenance mode)
2. Restore database from backup (Supabase: T-1 hour)
3. Audit all stock changes (identify discrepancies)
4. Fix inventory counts manually
5. Re-test all scenarios
6. Resume orders once cleared
```

---

## PASS/FAIL SUMMARY

```
BLOCK 6 RESULT:
┌──────────────────────────────────────┐
│ Tests Passed:      /10               │
│ Tests Failed:      /10               │
│ Critical Issues:   0/0 ✅            │
│ Status:            PASS/FAIL         │
│ Final Score:       /100              │
└──────────────────────────────────────┘
```

---

## NEXT STEPS

- If PASS: Proceed to Block 7 (Payment QA)
- If FAIL: Debug and retry before Block 8

**Timeline:** 90 minutes to complete all tests
**Parallel Execution:** Runs alongside Block 7 & 8
