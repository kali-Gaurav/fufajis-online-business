# Integration Quick Start: Inventory Race Condition Fix

**Purpose**: Integrate the pessimistic locking solution into existing OrderService  
**Time Required**: 30-45 minutes  
**Risk Level**: LOW (Cloud Functions isolated, easy rollback)

---

## Step 1: Deploy Cloud Functions

### 1.1 Install TypeScript Support
```bash
cd functions
npm install
```

### 1.2 Deploy Functions
```bash
firebase deploy --only functions
```

**Verify Success**:
```bash
firebase functions:log
# Should show deployment messages
```

---

## Step 2: Update Firestore Rules

### 2.1 Deploy Security Rules
```bash
firebase deploy --only firestore:rules
```

**Verify Success**:
- Go to Firebase Console → Firestore → Rules
- Confirm rules now include `product_locks`, `inventory_events`, `refund_logs`

---

## Step 3: Update OrderService (Integration Point)

### 3.1 Import New Service
In `lib/services/order_service.dart`, add:

```dart
import 'pos/inventory_service_fixed.dart';
```

### 3.2 Find Stock Deduction Code

Search for this code (around line 312-362):

```dart
// 3. Stock Allocation (Multi-branch aware)
for (var item in orderToProcess.items) {
  final prodRef = _db.collection('products').doc(item.productId);
  final snapshot = await transaction.get(prodRef);
  
  if (snapshot.exists) {
    final data = snapshot.data();
    if (data != null) {
      final Map<dynamic, dynamic> branchStockMap = data['branchStock'] as Map? ?? {};
      final branchId = (updatedOrder.shopId?.isEmpty ?? true) ? 'primary' : updatedOrder.shopId!;
      
      int currentBranchStock = 0;
      if (branchStockMap.containsKey(branchId)) {
        currentBranchStock = (branchStockMap[branchId] ?? 0) as int;
      } else {
        if (branchId == 'primary' || branchStockMap.isEmpty) {
          currentBranchStock = (data['stockQuantity'] ?? 0) as int;
        } else {
          currentBranchStock = 0;
        }
      }

      final int quantityOrdered = item.quantity;
      
      if (currentBranchStock >= quantityOrdered) {
        final newBranchStock = currentBranchStock - quantityOrdered;
        // ... rest of code
      } else {
        throw Exception('Inadequate stock for ${item.productName} at branch...');
      }
    }
  }
}
```

### 3.3 Replace With New Code

Replace the entire "3. Stock Allocation" section with:

```dart
// 3. Stock Allocation (Multi-branch aware, using pessimistic locking)
final inventoryService = InventoryServiceFixed();
final shopId = (updatedOrder.shopId?.isEmpty ?? true) ? 'primary' : updatedOrder.shopId!;

for (var item in orderToProcess.items) {
  try {
    // Use Cloud Function with pessimistic locking
    final deductResult = await inventoryService.deductInventorySafe(
      productId: item.productId,
      quantity: item.quantity,
      orderId: orderToProcess.id,
      shopId: shopId,
    );

    debugPrint(
      '[OrderService] Stock deducted for ${item.productName}: '
      '${deductResult['stockBefore']} → ${deductResult['stockAfter']}'
    );
  } catch (e) {
    debugPrint('[OrderService] Stock deduction error for ${item.productName}: $e');
    throw Exception('Unable to reserve stock for ${item.productName}: $e');
  }
}
```

### 3.4 Keep Transaction Code as-is

**IMPORTANT**: Keep the transaction code that writes the order to Firestore:

```dart
await _db.runTransaction((transaction) async {
  // ... wallet deduction code (unchanged) ...
  
  // ✓ KEEP THIS - writes order itself
  final orderRef = _db.collection('orders').doc(orderToProcess.id);
  transaction.set(orderRef, orderToProcess.toMap());
  
  // ✓ KEEP THIS - writes order_items
  for (var item in orderToProcess.items) {
    final itemId = '${orderToProcess.id}_${item.productId}';
    final itemRef = _db.collection('order_items').doc(itemId);
    transaction.set(itemRef, { ... });
  }
});
```

---

## Step 4: Update Refund Handling

### 4.1 Find Return/Refund Processing Code

Search for code that updates order status to `refunded`.

### 4.2 Replace With New Service

Old code (example):
```dart
// Direct wallet update
final userRef = _firestore.collection('users').doc(customerId);
await userRef.update({
  'walletBalance': FieldValue.increment(refundAmount),
});

// Direct order update
await _firestore.collection('orders').doc(orderId).update({
  'status': 'refunded',
  'refundedAt': FieldValue.serverTimestamp(),
});
```

New code:
```dart
// Use Cloud Function that handles everything atomically
final refundService = RefundServiceFixed();
await refundService.processRefundWithStockRestore(
  orderId: orderId,
  refundAmount: refundAmount,
  reason: 'Return request approved',
);
```

---

## Step 5: Validation Checks

### 5.1 Update Stock Validation

Update the existing `validateStockAvailability` method to use the new service:

```dart
Future<void> validateStockAvailability(List<OrderItem> items, String? shopId) async {
  final inventoryService = InventoryServiceFixed();
  final shopIdVal = (shopId?.isEmpty ?? true) ? 'primary' : shopId!;
  final stockErrors = <String>[];

  for (var item in items) {
    try {
      final availableStock = await inventoryService.getAvailableStock(
        productId: item.productId,
        shopId: shopIdVal,
      );

      if (availableStock < item.quantity) {
        stockErrors.add(
          '${item.productName}: ${availableStock} available, ${item.quantity} requested'
        );
      }
    } catch (e) {
      debugPrint('[OrderService] Stock check error for ${item.productName}: $e');
    }
  }

  if (stockErrors.isNotEmpty) {
    throw Exception('Insufficient stock:\n${stockErrors.join('\n')}');
  }
}
```

---

## Step 6: Testing

### 6.1 Unit Test

```dart
test('Deduct inventory safely', () async {
  final service = InventoryServiceFixed();
  
  final result = await service.deductInventorySafe(
    productId: 'prod_123',
    quantity: 5,
    orderId: 'order_456',
    shopId: 'primary',
  );
  
  expect(result['success'], true);
  expect(result['stockAfter'], lessThan(result['stockBefore']));
});
```

### 6.2 Integration Test (Concurrent Orders)

```dart
test('Handle 10 concurrent orders for stock of 5', () async {
  final service = InventoryServiceFixed();
  
  // Try to deduct from stock of 5, 10 times concurrently
  final futures = List.generate(10, (i) {
    return service.deductInventorySafe(
      productId: 'prod_lowstock',
      quantity: 1,
      orderId: 'order_$i',
      shopId: 'primary',
    ).catchError((_) => null); // Capture errors
  });
  
  final results = await Future.wait(futures, eagerError: false);
  final successful = results.where((r) => r != null).length;
  
  expect(successful, 5); // Only 5 should succeed
});
```

### 6.3 Manual Test

1. Open app as Customer A
2. Add item with stock=5 to cart
3. In another window, open as Customer B
4. Add same item (quantity=3) to cart
5. Both customers start checkout at same time
6. **Expected**: One succeeds, one gets "Out of stock" error
7. **Verify**: Final stock = 2 (not negative)

---

## Step 7: Monitoring

### 7.1 Set Up Alerts

In Firebase Console → Firestore:

**Alert 1**: Lock Contention
```
Collection: inventory_events
Query: type == 'stock_deduction'
Alert: If >10 per minute
```

**Alert 2**: Negative Stock
```
Collection: products
Query: stockQuantity < 0
Alert: Immediate (indicates failure)
```

### 7.2 Dashboard Query

Monitor stock accuracy:
```sql
SELECT 
  COUNT(*) as total_deductions,
  SUM(quantity) as total_units_deducted
FROM inventory_events
WHERE type = 'stock_deduction'
  AND DATE(timestamp) = CURRENT_DATE()
```

---

## Step 8: Rollback Plan (If Needed)

### If Issues Detected:

1. **Disable Cloud Functions** (Firebase Console → Cloud Functions)
   - Click each function → More options → Delete (or just disable)

2. **Revert Firestore Rules**
   ```bash
   # Restore from backup
   firebase deploy --only firestore:rules
   ```

3. **Revert OrderService Code**
   ```bash
   git checkout lib/services/order_service.dart
   ```

4. **Root Cause Analysis**
   - Check logs: `firebase functions:log`
   - Check Firestore: `inventory_events` collection
   - Review error messages

---

## Deployment Workflow

### Development
```bash
# 1. Test locally with emulator
firebase emulators:start --only functions,firestore

# 2. Run unit tests
flutter test

# 3. Manual testing
```

### Staging
```bash
# Deploy to staging project
firebase deploy --project fufaji-staging
```

### Production
```bash
# 1. Create backup (Firebase Console → Backups)
# 2. Deploy functions
firebase deploy --only functions --project fufaji-production

# 3. Deploy rules
firebase deploy --only firestore:rules --project fufaji-production

# 4. Update app code
# 5. Push new app version

# 6. Monitor for 24 hours
firebase functions:log --project fufaji-production
```

---

## Success Criteria

✓ Cloud Functions deployed without errors  
✓ Firestore rules updated with new collections  
✓ OrderService updated to use new inventory service  
✓ Refund service updated to restore stock  
✓ 10 concurrent orders on 5-stock product: 5 succeed, 5 fail  
✓ Final stock = expected value (not negative)  
✓ Refunded orders restore stock correctly  
✓ No errors in Firebase logs for 24 hours  

---

## Common Issues & Fixes

### Issue: "Function not found" error
**Cause**: Cloud Functions not deployed  
**Fix**: Run `firebase deploy --only functions`

### Issue: "Permission denied" on lock operations
**Cause**: Security rules blocking writes  
**Fix**: Verify rules allow Cloud Functions (they auto-allow)

### Issue: Locks timing out
**Cause**: Slow database queries  
**Fix**: Check Cloud Functions logs for performance issues

### Issue: Stock becomes negative
**Cause**: Old code path still running  
**Fix**: Verify OrderService completely migrated

---

## Timeline Estimate

| Step | Time | Status |
|------|------|--------|
| 1. Deploy Cloud Functions | 5 min | |
| 2. Deploy Firestore Rules | 2 min | |
| 3. Update OrderService | 15 min | |
| 4. Update Refund Service | 10 min | |
| 5. Testing | 20 min | |
| 6. Monitoring Setup | 5 min | |
| **Total** | **57 min** | |

---

## Support

- **Questions**: Check `INVENTORY_RACE_CONDITION_FIX.md`
- **Issues**: Review `firebase functions:log`
- **Rollback**: Follow "Rollback Plan" section above

---

**Next Step**: Proceed to Phase 8 (Receipt & Invoice System Audit) once this integration is complete and verified.
