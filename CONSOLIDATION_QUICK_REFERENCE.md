# Consolidation Quick Reference

## Service Mapping: Old → New

### Order Services
```
OLD                          NEW
OrderService              → UnifiedOrderService
OrderWorkflowEngine       → UnifiedOrderService
OrderStatusEngine         → UnifiedOrderService
WalletOrderService        → UnifiedOrderService
```

### Packing Services
```
OLD                          NEW
PackingService            → UnifiedPackingService
PackingService v2         → UnifiedPackingService
Orphaned workflow         → UnifiedPackingService
```

### Delivery Services
```
OLD                          NEW
DeliveryWorkflowEngine    → UnifiedDeliveryService
DeliveryLedgerService     → UnifiedDeliveryService
DeliveryTaskService       → UnifiedDeliveryService
```

---

## Import Changes

### OLD
```dart
import 'services/order_service.dart';
import 'services/order_workflow_engine.dart';
import 'services/order_status_engine.dart';
import 'services/packing_service.dart';
import 'services/delivery_workflow_engine.dart';
import 'services/delivery_ledger_service.dart';
import 'services/delivery_task_service.dart';
```

### NEW
```dart
import 'services/unified_order_service.dart';
import 'services/unified_packing_service.dart';
import 'services/unified_delivery_service.dart';
```

---

## Method Reference

### Order Service

| Old | New | Signature Change |
|-----|-----|-----------------|
| `OrderService().createOrder(order)` | `UnifiedOrderService().createOrder(...)` | Now uses named params + `orderType` |
| `OrderWorkflowEngine().transition()` | `UnifiedOrderService().transitionOrder()` | Different name, same logic |
| `OrderStatusEngine().canTransition()` | `UnifiedOrderService().canTransition()` | Same |
| `OrderStatusEngine().isTerminal()` | `UnifiedOrderService().isTerminal()` | Same |

### Packing Service

| Old | New | Signature Change |
|-----|-----|-----------------|
| `PackingService().assignOrderToEmployee()` | `UnifiedPackingService().createFulfillmentTask()` + `.assignToEmployee()` | Two-step process |
| `PackingService().markItemPicked()` | `UnifiedPackingService().markItemPicked()` | Same |
| `PackingService().completePacking()` | `UnifiedPackingService().completePacking()` | Now validates all items verified |

### Delivery Service

| Old | New | Signature Change |
|-----|-----|-----------------|
| `DeliveryTaskService().getRiderOrders()` | `UnifiedDeliveryService().getRiderOrders()` | **FIXED: Now checks correct status** |
| `DeliveryWorkflowEngine().transition()` | `UnifiedDeliveryService().[markPickedUp/markInTransit/etc]()` | Explicit methods |
| `DeliveryLedgerService().log*()` | Built into state transitions | Automatic |

---

## Critical Changes

### 1. Order Creation: Add orderType

**BEFORE**:
```dart
final order = OrderModel(customerId: u, ...);
await OrderService().createOrder(order);
```

**AFTER**:
```dart
await UnifiedOrderService().createOrder(
  customerId: u,
  shopId: s,
  items: [...],
  totalAmount: 500,
  orderType: 'normal', // NEW: 'normal'|'wallet'|'group_buy'|'reorder'
);
```

### 2. Packing: Two-step creation

**BEFORE**:
```dart
final task = await PackingService().assignOrderToEmployee(...);
```

**AFTER**:
```dart
final task = await UnifiedPackingService().createFulfillmentTask(...);
final taskId = task['id'];
await UnifiedPackingService().assignToEmployee(taskId: taskId, ...);
```

### 3. Delivery: P0 BUG FIX - Rider Queries

**BEFORE** (BROKEN - returns empty):
```dart
final orders = await DeliveryTaskService().getRiderOrders(riderId);
// Doesn't work because status mismatch
```

**AFTER** (FIXED - works):
```dart
final orders = await UnifiedDeliveryService().getRiderOrders(riderId);
// Now works! Checks correct status values
```

---

## Status Machine Reference

### Order Status Machine
```
pending → confirmed → processing → packed → shipped → delivered
   ↓
cancelled ← (from any non-terminal state)
   ↓
refunded
```

### Packing Status Machine
```
new → assigned → picking → quality_check → verified → completed
  ↓
rejected (returns to assigned)
```

### Delivery Status Machine
```
assigned → picked_up → in_transit → delivered
  ↓
failed (back to assigned)
```

---

## State Transition Side Effects

### Order Service

| Transition | Side Effects |
|-----------|--------------|
| → processing | Reserve inventory |
| → packed | Deduct inventory |
| → cancelled | Restore inventory, prepare refund |
| → refunded | Add to wallet |

### Packing Service

| Transition | Side Effects |
|-----------|--------------|
| new → assigned | Assign to employee |
| → picking | Begin picking workflow |
| → quality_check | Initiate QC review |
| → verified | Check item verification |
| → completed | **Validate ALL items verified**, update order status |
| → rejected | Clear picked/verified items |

### Delivery Service

| Transition | Side Effects |
|-----------|--------------|
| → assigned | Assign to rider |
| → picked_up | Update location |
| → in_transit | Start delivery tracking |
| → delivered | Update order status |
| → failed | Log failure, allow reassignment |

---

## Common Code Patterns

### Pattern 1: Simple Order Creation

**OLD**:
```dart
final order = OrderModel(
  customerId: userId,
  shopId: shopId,
  items: cartItems,
  totalAmount: 500,
);
await OrderService().createOrder(order);
```

**NEW**:
```dart
await UnifiedOrderService().createOrder(
  customerId: userId,
  shopId: shopId,
  items: cartItems,
  totalAmount: 500,
  orderType: 'normal',
);
```

### Pattern 2: Wallet Order

**OLD** (NOT UNIFIED):
```dart
// Scattered across PaymentRouterService
await PaymentRouterService().handleWalletPayment(userId, amount);
```

**NEW** (UNIFIED):
```dart
await UnifiedOrderService().createOrder(
  customerId: userId,
  shopId: shopId,
  items: cartItems,
  totalAmount: amount,
  orderType: 'wallet',
);
```

### Pattern 3: Order Status Transition

**OLD**:
```dart
final workflow = OrderWorkflowEngine();
if (workflow.canTransition(currentStatus, newStatus)) {
  await workflow.transition(
    orderId: orderId,
    fromStatus: currentStatus,
    toStatus: newStatus,
  );
}
```

**NEW**:
```dart
final service = UnifiedOrderService();
if (service.canTransition(currentStatus, newStatus)) {
  await service.transitionOrder(
    orderId: orderId,
    toStatus: newStatus,
  );
}
```

### Pattern 4: Packing Workflow

**OLD**:
```dart
final task = await PackingService().assignOrderToEmployee(orderId, ...);
await PackingService().markItemPicked(task.id, itemId, qty);
await PackingService().completePacking(task.id);
```

**NEW**:
```dart
final packing = UnifiedPackingService();

final task = await packing.createFulfillmentTask(orderId: orderId, ...);
const taskId = task['id'];

await packing.assignToEmployee(taskId: taskId, employeeId: emp, ...);
await packing.startPicking(taskId);
await packing.markItemPicked(taskId: taskId, itemId: item, quantity: qty);
await packing.requestQualityCheck(taskId);
await packing.markItemVerified(taskId: taskId, itemId: item);
await packing.completePacking(taskId: taskId); // VALIDATES all items verified
```

### Pattern 5: Rider Orders - P0 FIX

**OLD** (BROKEN):
```dart
final orders = await DeliveryTaskService().getRiderOrders(riderId);
// Returns empty because of status mismatch
// Riders see "No deliveries"
```

**NEW** (FIXED):
```dart
final orders = await UnifiedDeliveryService().getRiderOrders(riderId);
// Returns orders correctly
// Riders see their assignments
```

### Pattern 6: Delivery Workflow

**OLD**:
```dart
final workflow = DeliveryWorkflowEngine();
await workflow.transition(
  trackingId: deliveryId,
  fromStatus: 'assigned',
  toStatus: 'picked_up',
);
```

**NEW**:
```dart
final delivery = UnifiedDeliveryService();
await delivery.markPickedUp(
  taskId: deliveryId,
  latitude: lat,
  longitude: lon,
);
```

---

## Testing Checklist

### Unit Tests

- [ ] Order creation (all 4 types)
- [ ] Order transitions (valid)
- [ ] Order invalid transitions (rejected)
- [ ] Packing workflow
- [ ] Packing validation (all items verified before completion)
- [ ] Delivery workflow
- [ ] **P0 fix: Rider sees orders** ← CRITICAL

### Integration Tests

- [ ] Complete order flow: create → confirm → pack → deliver
- [ ] Cancellation flow: cancel → refund
- [ ] Failure flow: delivery failed → reassign → deliver
- [ ] Wallet order: create → confirm → deliver → refund to wallet

### Manual Smoke Tests (on staging)

- [ ] Create normal order
- [ ] Create wallet order
- [ ] Confirm order
- [ ] Create packing task
- [ ] Pick items
- [ ] Verify items
- [ ] Complete packing
- [ ] Create delivery task
- [ ] Assign to rider
- [ ] **Rider can see order** ← P0 FIX TEST
- [ ] Mark picked up
- [ ] Mark delivered
- [ ] Verify order complete

---

## Error Messages Reference

### Order Service

| Error | Cause | Fix |
|-------|-------|-----|
| "Your order is already being placed" | Duplicate checkout | Wait or refresh |
| "Duplicate order detected" | Same amount within 5 min | Check order history |
| "Insufficient wallet balance" | Wallet order but low balance | Top up wallet |
| "Invalid transition: X → Y" | Invalid status flow | Check order status |

### Packing Service

| Error | Cause | Fix |
|-------|-------|-----|
| "Cannot complete: N items not verified" | Missing QC approval | Verify all items |
| "Task not found" | Invalid task ID | Check task ID |
| "Invalid transition" | Wrong workflow step | Follow correct sequence |

### Delivery Service

| Error | Cause | Fix |
|-------|-------|-----|
| Empty rider orders list | P0 bug OR not assigned | Verify assignment, check status |
| "Delivery task not found" | Invalid task ID | Check delivery task ID |
| "Invalid transition" | Wrong delivery step | Follow correct sequence |

---

## Firestore Collections Reference

### Orders Collection
```
orders/
├── {orderId}
│   ├── orderId
│   ├── orderNumber
│   ├── customerId
│   ├── shopId
│   ├── status: 'pending'|'confirmed'|'processing'|'packed'|'shipped'|'delivered'|'cancelled'|'refunded'
│   ├── items: [...]
│   ├── totalAmount: 500
│   ├── fulfillmentTaskId: 'task123'
│   ├── deliveryTaskId: 'delivery456'
│   ├── statusHistory: [...]
│   ├── createdAt
│   └── updatedAt
```

### Fulfillment Tasks Collection
```
fulfillment_tasks/
├── {taskId}
│   ├── orderId
│   ├── shopId
│   ├── branchId
│   ├── status: 'new'|'assigned'|'picking'|'quality_check'|'verified'|'completed'|'rejected'
│   ├── items: [...]
│   ├── pickedItems: [...]
│   ├── verifiedItems: [...]
│   ├── assignedToEmployeeId
│   ├── statusHistory: [...]
│   ├── createdAt
│   └── updatedAt
```

### Delivery Tasks Collection
```
delivery_tasks/
├── {taskId}
│   ├── orderId
│   ├── shopId
│   ├── status: 'assigned'|'picked_up'|'in_transit'|'delivered'|'failed'|'cancelled'
│   ├── assignedRiderId
│   ├── assignedRiderName
│   ├── assignedRiderPhone
│   ├── deliveryFee
│   ├── estimatedDistance
│   ├── deliveryAddress
│   ├── trackingUpdates: [{lat, lon, timestamp}]
│   ├── currentLatitude
│   ├── currentLongitude
│   ├── statusHistory: [...]
│   ├── createdAt
│   └── updatedAt
```

---

## API Response Examples

### Create Order Response
```json
{
  "id": "order_abc123",
  "orderNumber": "ORD-1234567890-5678",
  "status": "pending",
  "customerId": "user1",
  "totalAmount": 500,
  "orderType": "normal",
  "items": [...],
  "createdAt": "2026-06-22T10:30:00Z"
}
```

### Get Rider Orders Response
```json
[
  {
    "id": "delivery_xyz789",
    "orderId": "order_abc123",
    "status": "assigned",
    "customerPhone": "9876543210",
    "deliveryAddress": "123 Main St",
    "order": {
      "orderNumber": "ORD-xxx",
      "items": [...],
      "totalAmount": 500
    }
  }
]
```

---

## Debugging Tips

### Problem: Rider sees "No deliveries"
1. Check UnifiedDeliveryService is being used
2. Verify getRiderOrders() query includes all status values
3. Check delivery_tasks collection has correct assignedRiderId
4. Verify status is one of: assigned, picked_up, in_transit
5. Check Firestore rules allow read access

### Problem: Orders not transitioning
1. Check current status valid for desired transition
2. Verify UnifiedOrderService.canTransition() returns true
3. Check Firestore permissions
4. Look for errors in status history

### Problem: Packing can't complete
1. Verify all items are in verifiedItems array
2. Count verifiedItems == items length
3. Check markItemVerified was called for each item
4. Look at rejectionCount (too many rejections?)

---

## Quick Checklist for Migrating a File

### Step 1: Update Imports
- [ ] Remove old service imports
- [ ] Add new unified import

### Step 2: Update Service Instantiation
- [ ] Change service class name
- [ ] Remove multiple service instances (was: 3-4, now: 1)

### Step 3: Update Method Calls
- [ ] Rename methods if needed
- [ ] Update parameter signatures
- [ ] Add missing params (e.g., orderType)
- [ ] Update response handling if changed

### Step 4: Test
- [ ] Run local tests
- [ ] Test in staging
- [ ] Manual smoke test

### Step 5: Verify
- [ ] No import errors
- [ ] No method not found errors
- [ ] No parameter type mismatches
- [ ] All workflows still work

---

## Key Differences Summary

| Aspect | Old | New |
|--------|-----|-----|
| Service count | 10 | 3 |
| Order type | Implicit | Explicit (normal, wallet, group_buy, reorder) |
| Status machine | Scattered | Centralized |
| Rider queries | Broken (P0) | Fixed |
| Inventory handling | Double deduction | Single point |
| Packing validation | Weak | Strong (all items verified required) |
| Collections | 10 orphaned delivery_* | 1 unified delivery_tasks |

---

**For detailed information, see**: 
- CONSOLIDATION_REPORT.md (technical details)
- CONSOLIDATION_MIGRATION_GUIDE.md (step-by-step)
- PHASE4_CONSOLIDATION_SUMMARY.md (project status)

**Created**: 2026-06-22  
**Version**: 1.0
