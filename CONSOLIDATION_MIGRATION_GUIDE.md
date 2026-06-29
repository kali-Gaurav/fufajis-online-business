# Consolidation Migration Guide

**Timeline**: 6 days  
**Complexity**: Moderate (systematic import updates)  
**Risk**: Low (gradual migration, parallel systems)

---

## PHASE 1: UNDERSTANDING THE CHANGES (Day 1)

### What Changed

| Old | New | Status |
|-----|-----|--------|
| OrderService | UnifiedOrderService | ✅ Created |
| OrderWorkflowEngine | UnifiedOrderService | ✅ Merged |
| OrderStatusEngine | UnifiedOrderService | ✅ Merged |
| WalletOrderService | UnifiedOrderService | ✅ Merged |
| PackingService | UnifiedPackingService | ✅ Created |
| PackingService v2 | UnifiedPackingService | ✅ Merged |
| DeliveryWorkflowEngine | UnifiedDeliveryService | ✅ Created |
| DeliveryLedgerService | UnifiedDeliveryService | ✅ Merged |
| DeliveryTaskService | UnifiedDeliveryService | ✅ Merged |

### New Files Location
```
lib/services/
├── unified_order_service.dart       (NEW)
├── unified_packing_service.dart     (NEW)
├── unified_delivery_service.dart    (NEW)
├── order_service.dart               (OLD - remove later)
├── order_workflow_engine.dart       (OLD - remove later)
├── order_status_engine.dart         (OLD - remove later)
├── packing_service.dart             (OLD - remove later)
└── delivery_workflow_engine.dart    (OLD - remove later)
```

---

## PHASE 2: FIND ALL IMPORTS (Day 1-2)

### Step 1: Search for Old Service Imports

Run these searches to find all usages:

```bash
# Find all OrderService imports
grep -r "import.*order_service.dart" lib/

# Find all OrderWorkflowEngine imports
grep -r "OrderWorkflowEngine" lib/

# Find all OrderStatusEngine imports
grep -r "OrderStatusEngine" lib/

# Find all PackingService imports
grep -r "packing_service.dart" lib/

# Find all DeliveryWorkflowEngine imports
grep -r "DeliveryWorkflowEngine" lib/

# Find all DeliveryLedgerService imports
grep -r "DeliveryLedgerService" lib/

# Find all DeliveryTaskService imports
grep -r "DeliveryTaskService" lib/
```

### Step 2: Document Files to Update

Create a checklist of all files that need updates. Categories:

**A. Route Handlers**
- Order creation routes
- Order status update routes
- Packing workflow routes
- Delivery workflow routes

**B. Provider/State Management**
- OrderProvider
- PakkingProvider
- DeliveryProvider

**C. UI Screens**
- Order creation screen
- Order tracking screen
- Packing app screens
- Rider delivery screens

**D. Business Logic Services**
- PaymentService (uses OrderService)
- InventoryService (uses OrderService)
- NotificationService (observes order/delivery status)

**E. Tests**
- All test files importing old services

---

## PHASE 3: PREPARE FOR MIGRATION (Day 2)

### Strategy: Parallel Systems

**DON'T** remove old services immediately. Instead:

1. Keep old services running
2. Create route layer that switches between old/new
3. Gradually migrate routes to new services
4. Monitor for issues
5. Remove old services after 2 weeks of stability

### Create Migration Wrapper (Optional)

`lib/services/migration_service.dart`:
```dart
/// Temporary wrapper to switch between old and new services
/// Set USE_UNIFIED_SERVICES = true to enable new services
class ServiceMigration {
  static const bool USE_UNIFIED_SERVICES = false; // Toggle here
  
  static dynamic getOrderService() {
    if (USE_UNIFIED_SERVICES) {
      return UnifiedOrderService();
    } else {
      return OrderService();
    }
  }
  
  // Similar for packing, delivery...
}
```

Then use: `final orderService = ServiceMigration.getOrderService();`

**Benefit**: Can toggle all services on/off with single constant.

---

## PHASE 4: UPDATE IMPORTS (Day 2-4)

### Pattern: Import Replacement

**OLD**:
```dart
import 'services/order_service.dart';
import 'services/order_workflow_engine.dart';

final orderService = OrderService();
final workflow = OrderWorkflowEngine();
```

**NEW**:
```dart
import 'services/unified_order_service.dart';

final orderService = UnifiedOrderService();
```

### Checklist: Order Service Migration

**Files to update**:
- [ ] `lib/routes/order_routes.dart` - Order creation, update routes
- [ ] `lib/providers/order_provider.dart` - State management
- [ ] `lib/screens/order_creation_screen.dart` - UI screen
- [ ] `lib/screens/order_tracking_screen.dart` - Order status display
- [ ] `lib/services/payment_service.dart` - Uses OrderService
- [ ] `lib/services/notification_service.dart` - Observes order status
- [ ] `test/services/order_service_test.dart` - Unit tests
- [ ] `test/integration/order_flow_test.dart` - Integration tests

**Code changes**:

From:
```dart
import 'services/order_service.dart';
import 'services/order_workflow_engine.dart';
import 'services/order_status_engine.dart';
import 'services/wallet_order_service.dart';
```

To:
```dart
import 'services/unified_order_service.dart';
```

From:
```dart
final orderService = OrderService();
final workflow = OrderWorkflowEngine();
final statusEngine = OrderStatusEngine();
```

To:
```dart
final orderService = UnifiedOrderService();
```

### Checklist: Packing Service Migration

**Files to update**:
- [ ] `lib/routes/packing_routes.dart` - Packing workflow routes
- [ ] `lib/providers/packing_provider.dart` - State management
- [ ] `lib/screens/packing_app/pick_list_screen.dart` - Picking workflow
- [ ] `lib/screens/packing_app/qc_screen.dart` - Quality check
- [ ] `lib/services/inventory_service.dart` - Uses packing status
- [ ] `test/services/packing_service_test.dart` - Unit tests
- [ ] `test/integration/fulfillment_flow_test.dart` - Integration tests

From:
```dart
import 'services/packing_service.dart';
import 'services/packing_service_v2.dart';
```

To:
```dart
import 'services/unified_packing_service.dart';
```

From:
```dart
final packing = PackingService();
final packingV2 = PackingServiceV2();
```

To:
```dart
final packing = UnifiedPackingService();
```

### Checklist: Delivery Service Migration

**Files to update**:
- [ ] `lib/routes/delivery_routes.dart` - Delivery workflow routes
- [ ] `lib/providers/delivery_provider.dart` - State management
- [ ] `lib/screens/rider_app/rider_orders_screen.dart` - **CRITICAL** - Rider order list
- [ ] `lib/screens/rider_app/delivery_map_screen.dart` - Real-time map
- [ ] `lib/services/location_service.dart` - Uses delivery tracking
- [ ] `lib/services/notification_service.dart` - Observes delivery status
- [ ] `test/services/delivery_service_test.dart` - Unit tests
- [ ] `test/integration/delivery_flow_test.dart` - Integration tests

**SPECIAL NOTE**: Rider orders screen must use `getRiderOrders()` from UnifiedDeliveryService to get P0 fix.

From:
```dart
import 'services/delivery_workflow_engine.dart';
import 'services/delivery_ledger_service.dart';
import 'services/delivery_task_service.dart';
```

To:
```dart
import 'services/unified_delivery_service.dart';
```

From:
```dart
final workflow = DeliveryWorkflowEngine();
final ledger = DeliveryLedgerService();
final tasks = DeliveryTaskService();
```

To:
```dart
final delivery = UnifiedDeliveryService();
```

---

## PHASE 5: UPDATE METHOD CALLS (Day 3-4)

### Order Service Method Mapping

| Old Service | Old Method | New Service | New Method | Changes |
|------------|-----------|------------|-----------|---------|
| OrderService | createOrder() | UnifiedOrderService | createOrder() | Add `orderType` param |
| OrderWorkflowEngine | transition() | UnifiedOrderService | transitionOrder() | Different signature |
| OrderStatusEngine | canTransition() | UnifiedOrderService | canTransition() | Same |
| OrderStatusEngine | getOrderStatus() | UnifiedOrderService | getOrderStatus() | Same |
| OrderService | cancelOrder() | UnifiedOrderService | cancelOrder() | Same |
| OrderService | getOrderHistory() | UnifiedOrderService | getOrderHistory() | Same |

### Example: Order Creation

**OLD**:
```dart
final order = OrderModel(
  customerId: userId,
  shopId: shopId,
  items: cartItems,
  totalAmount: 500,
  // ...
);
await OrderService().createOrder(order);
```

**NEW**:
```dart
await UnifiedOrderService().createOrder(
  customerId: userId,
  shopId: shopId,
  items: cartItems.map((item) => item.toMap()).toList(),
  totalAmount: 500,
  orderType: 'normal', // 'normal', 'wallet', 'group_buy', 'reorder'
  paymentMethod: 'card',
  // ...
);
```

### Example: Wallet Order

**OLD** (was embedded in payment router):
```dart
// Payment router handled wallet orders separately
await PaymentRouterService().handleWalletPayment(userId, amount);
```

**NEW** (unified):
```dart
await UnifiedOrderService().createOrder(
  customerId: userId,
  shopId: shopId,
  items: cartItems,
  totalAmount: amount,
  orderType: 'wallet', // NEW: explicit wallet order type
  paymentMethod: 'wallet',
);
```

### Example: Packing Workflow

**OLD**:
```dart
// Assign task
final task = await PackingService().assignOrderToEmployee(
  orderId, employeeId, employeeName, shopId, branchId, items
);

// Mark picked
await PackingService().markItemPicked(taskId, itemId, quantity);

// Complete
await PackingService().completePacking(taskId);
```

**NEW**:
```dart
// Create task
final task = await UnifiedPackingService().createFulfillmentTask(
  orderId: orderId,
  shopId: shopId,
  branchId: branchId,
  items: items,
);
final taskId = task['id'];

// Assign to employee
await UnifiedPackingService().assignToEmployee(
  taskId: taskId,
  employeeId: employeeId,
  employeeName: employeeName,
);

// Picking workflow
await UnifiedPackingService().startPicking(taskId);
await UnifiedPackingService().markItemPicked(
  taskId: taskId,
  itemId: itemId,
  quantity: quantity,
);

// Quality check
await UnifiedPackingService().requestQualityCheck(taskId);
await UnifiedPackingService().markItemVerified(
  taskId: taskId,
  itemId: itemId,
);

// Complete (validates all items verified)
await UnifiedPackingService().completePacking(
  taskId: taskId,
  packageTrackingNumber: trackingNum,
);
```

### Example: Delivery - P0 FIX

**OLD** (broken - riders couldn't see orders):
```dart
// This query returned NO results because status mismatch
final orders = await DeliveryTaskService().getRiderOrders(riderId);
// Problem: status was 'packed' but query looked for 'assigned'
```

**NEW** (fixed - riders see all deliveries):
```dart
// This query WORKS - checks correct status values
final orders = await UnifiedDeliveryService().getRiderOrders(riderId);
// Fixed: checks status IN ['assigned', 'picked_up', 'in_transit']
// Riders now see deliveries assigned to them
```

---

## PHASE 6: TESTING (Day 4-5)

### Unit Test Updates

**OLD**:
```dart
import 'package:fufaji/services/order_service.dart';

void main() {
  test('OrderService creates order', () async {
    final service = OrderService();
    final order = await service.createOrder(orderData);
    expect(order.id, isNotNull);
  });
}
```

**NEW**:
```dart
import 'package:fufaji/services/unified_order_service.dart';

void main() {
  test('UnifiedOrderService creates normal order', () async {
    final service = UnifiedOrderService();
    final order = await service.createOrder(
      customerId: 'user1',
      shopId: 'shop1',
      items: [...],
      totalAmount: 500,
      orderType: 'normal',
    );
    expect(order.id, isNotNull);
  });

  test('UnifiedOrderService creates wallet order', () async {
    final service = UnifiedOrderService();
    await service.createOrder(
      customerId: 'user1',
      shopId: 'shop1',
      items: [...],
      totalAmount: 500,
      orderType: 'wallet',
    );
    // Validates wallet balance
  });

  test('UnifiedOrderService rejects invalid transition', () async {
    final service = UnifiedOrderService();
    expect(service.canTransition('delivered', 'confirmed'), false);
  });
}
```

### Integration Test: Full Order Flow

```dart
test('Complete order flow: creation → packing → delivery', () async {
  final orderSvc = UnifiedOrderService();
  final packingSvc = UnifiedPackingService();
  final deliverySvc = UnifiedDeliveryService();

  // 1. Create order
  final order = await orderSvc.createOrder(
    customerId: 'user1',
    shopId: 'shop1',
    items: itemsList,
    totalAmount: 500,
    orderType: 'normal',
  );
  expect(order.status, 'pending');

  // 2. Confirm order
  await orderSvc.transitionOrder(
    orderId: order.id,
    toStatus: 'confirmed',
  );

  // 3. Create fulfillment task
  final task = await packingSvc.createFulfillmentTask(
    orderId: order.id,
    shopId: 'shop1',
    branchId: 'branch1',
    items: itemsList,
  );

  // 4. Employee picks items
  await packingSvc.assignToEmployee(
    taskId: task['id'],
    employeeId: 'emp1',
    employeeName: 'John',
  );
  await packingSvc.startPicking(task['id']);
  await packingSvc.markItemPicked(
    taskId: task['id'],
    itemId: 'item1',
    quantity: 2,
  );

  // 5. QC verification
  await packingSvc.requestQualityCheck(task['id']);
  await packingSvc.markItemVerified(
    taskId: task['id'],
    itemId: 'item1',
  );

  // 6. Complete packing
  await packingSvc.completePacking(
    taskId: task['id'],
    packageTrackingNumber: 'TRK123',
  );

  // 7. Create delivery task
  final delivery = await deliverySvc.createDeliveryTask(
    orderId: order.id,
    shopId: 'shop1',
    deliveryFee: 50,
  );

  // 8. Assign to rider
  await deliverySvc.assignToRider(
    taskId: delivery['id'],
    riderId: 'rider1',
    riderName: 'Ram',
    riderPhone: '9876543210',
  );

  // 9. P0 FIX: Rider can now see the order
  final riderOrders = await deliverySvc.getRiderOrders('rider1');
  expect(riderOrders.length, greaterThan(0));
  expect(riderOrders[0]['id'], delivery['id']);

  // 10. Rider marks picked up
  await deliverySvc.markPickedUp(
    taskId: delivery['id'],
    latitude: 28.123,
    longitude: 77.456,
  );

  // 11. Rider marks in transit
  await deliverySvc.markInTransit(delivery['id']);

  // 12. Rider marks delivered
  await deliverySvc.markDelivered(
    taskId: delivery['id'],
    latitude: 28.124,
    longitude: 77.457,
    proofImageUrl: 'https://...',
  );

  // 13. Verify final order status
  final finalOrder = await orderSvc.getOrder(order.id);
  expect(finalOrder?.status, 'delivered');
});
```

### Test: P0 Bug Fix

```dart
test('P0 FIX: Rider queries return orders with correct status', () async {
  final deliverySvc = UnifiedDeliveryService();
  
  // Create delivery task with status 'assigned'
  // (from packed order status in packing service)
  final task = await deliverySvc.createDeliveryTask(
    orderId: 'order1',
    shopId: 'shop1',
    deliveryFee: 50,
  );
  
  // Assign to rider
  await deliverySvc.assignToRider(
    taskId: task['id'],
    riderId: 'rider1',
    riderName: 'Ram',
    riderPhone: '9876543210',
  );
  
  // CRITICAL: Rider MUST see the order
  // Before fix: Would return empty list (status mismatch)
  // After fix: Returns order correctly
  final riderOrders = await deliverySvc.getRiderOrders('rider1');
  expect(riderOrders, isNotEmpty);
  expect(riderOrders.first['id'], task['id']);
  expect(riderOrders.first['status'], anyOf(['assigned', 'picked_up', 'in_transit']));
});
```

---

## PHASE 7: DEPLOYMENT (Day 5-6)

### Step 1: Staging Deployment

```bash
# 1. Deploy new unified services to staging
flutter pub get
flutter analyze  # Check for errors
flutter test     # Run all tests

# 2. Deploy to staging Firebase
firebase deploy --only functions:staging

# 3. Point staging app to staging Firebase
# Update lib/config/app_config.dart
```

### Step 2: Smoke Test on Staging

**Checklist**:
- [ ] Create order (normal type)
- [ ] Create order (wallet type)
- [ ] Create order (group buy type)
- [ ] Create order (reorder type)
- [ ] Transition order through all statuses
- [ ] Cancel order and verify refund
- [ ] Create packing task
- [ ] Complete packing with full item verification
- [ ] Create delivery task
- [ ] Assign to rider
- [ ] **Rider sees order in their list** (P0 fix test)
- [ ] Update delivery location
- [ ] Mark delivered
- [ ] Verify order final status

### Step 3: Production Deployment

```bash
# 1. Create git tag
git tag -a v2.0.0-consolidation -m "Phase 4: Service consolidation"
git push origin v2.0.0-consolidation

# 2. Deploy to production
firebase deploy --only functions

# 3. Update mobile app (if any changes)
flutter build apk --release
# Upload to Play Store

# 4. Monitor for errors (24 hours)
# Check Firebase logs for exceptions
# Verify no delivery orders missing
```

### Step 4: Monitoring

**First 24 hours**:
- Order creation success rate (target: >99.5%)
- Packing task completion (no stuck orders)
- Delivery completion rate (target: >98%)
- Rider order visibility (critical for P0 fix)

**Tools**:
- Firebase Console → Firestore → Query metrics
- Cloud Functions → Logs
- Sentry/Crash Reporting

---

## PHASE 8: CLEANUP (Week 2)

### After 2 Weeks of Stable Operation

**Step 1**: Delete old service files
```bash
rm lib/services/order_service.dart
rm lib/services/order_workflow_engine.dart
rm lib/services/order_status_engine.dart
rm lib/services/packing_service.dart
rm lib/services/packing_service_v2.dart
rm lib/services/delivery_workflow_engine.dart
rm lib/services/delivery_ledger_service.dart
rm lib/services/delivery_task_service.dart
```

**Step 2**: Remove old test files
```bash
# Remove old test files that imported deleted services
rm test/services/order_service_test.dart
rm test/services/packing_service_test.dart
rm test/services/delivery_workflow_engine_test.dart
# etc.
```

**Step 3**: Clean up Firestore

```dart
// Delete orphaned delivery collections
// (can be done via Firebase Console or script)
FirebaseFirestore.instance
  .collection('delivery_tracking')
  .deleteCollection();
// Repeat for other 9 orphaned collections
```

**Step 4**: Update documentation
```bash
# Update README.md, API docs, architecture diagram
git commit -am "Clean up old services after consolidation"
```

---

## MIGRATION CHECKLIST

### Part A: Preparation
- [ ] Read consolidation report
- [ ] Understand new unified services
- [ ] Review P0 bug fix in delivery service
- [ ] Set up test environment

### Part B: Code Updates (Day 2-4)
- [ ] Update all route handlers
- [ ] Update all providers/state management
- [ ] Update all UI screens
- [ ] Update all service imports
- [ ] Update all test files
- [ ] Update all integration tests

### Part C: Testing (Day 4-5)
- [ ] Run all unit tests
- [ ] Run all integration tests
- [ ] Manual smoke test on staging
- [ ] Verify P0 fix (rider order visibility)
- [ ] Test all 4 order types
- [ ] Test cancellation and refund flow

### Part D: Deployment (Day 5-6)
- [ ] Deploy to staging
- [ ] Run smoke tests
- [ ] Monitor for errors
- [ ] Deploy to production
- [ ] Monitor for 24 hours

### Part E: Cleanup (Week 2)
- [ ] Delete old service files
- [ ] Delete old test files
- [ ] Clean up Firestore orphaned collections
- [ ] Update documentation
- [ ] Commit cleanup changes

---

## ROLLBACK PROCEDURE

If critical issues found:

```bash
# 1. IMMEDIATE: Revert app version
git revert HEAD

# 2. Point app to old services
# Update imports back to old services

# 3. Deploy rollback
firebase deploy

# 4. Monitor for stability (1 hour)

# 5. Root cause analysis
# What went wrong?
# How to fix?

# 6. Fix and redeploy
# After fix validated on staging
```

**Keep old services** for at least 2 weeks to ensure stability.

---

## COMMON ISSUES & SOLUTIONS

### Issue 1: "Method not found" errors

**Symptom**: `OrderService.transition()` not found

**Cause**: Code still trying to use old service name

**Solution**: Check file imports, update to `UnifiedOrderService()`

### Issue 2: Rider can't see orders

**Symptom**: Rider app shows "No deliveries"

**Cause**: P0 bug fix not applied or rider not assigned correctly

**Solution**: 
- Verify using `UnifiedDeliveryService.getRiderOrders()`
- Check delivery_tasks collection has correct status
- Verify rider ID is stored in `assignedRiderId` field

### Issue 3: Packing incomplete before shipping

**Symptom**: Partial orders shipped, customers missing items

**Cause**: `completePacking()` validation not working

**Solution**:
- Verify all items are marked verified before completion
- Check `verifiedItems` count == `items` count
- Add logging to debug

### Issue 4: Double refunds issued

**Symptom**: Customer receives refund twice

**Cause**: Old refund logic + new refund logic both running

**Solution**:
- Verify only one service is active
- Check Firebase logs for duplicate transactions
- Clear stale refund requests from queue

---

## SUPPORT

If you need help:

1. Check this guide's troubleshooting section
2. Review consolidation report for architecture
3. Check unified service documentation (inline comments)
4. Run debug tests to isolate issue
5. Check Firebase logs for stack traces

---

## SUCCESS CRITERIA

✅ All imports updated to unified services  
✅ All tests pass (unit + integration)  
✅ Staging deployment successful  
✅ P0 fix verified (riders see orders)  
✅ Production deployment successful  
✅ Zero order data loss  
✅ All delivery orders completed  
✅ No regression in packing workflow  
✅ Wallet orders working  
✅ Refunds processing correctly  

---

## TIMELINE SUMMARY

- **Day 1**: Understand changes, find imports
- **Day 2**: Prepare migration strategy, update imports
- **Day 3**: Finish import updates, begin testing
- **Day 4**: Complete testing, prepare staging
- **Day 5**: Deploy to staging, monitor, fix issues
- **Day 6**: Deploy to production, 24-hour monitoring
- **Week 2**: Monitor stability, cleanup old services

**Total**: 6 days + 1 week monitoring
