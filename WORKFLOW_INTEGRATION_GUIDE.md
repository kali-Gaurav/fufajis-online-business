# Workflow Integration Guide

Quick reference for using the unified workflows in your app code.

---

## 1. Order Workflow

### Creating an Order
```dart
final orderService = OrderWorkflowService();

final order = await orderService.createOrder(
  customerId: 'cust_123',
  shopId: 'shop_456',
  items: [
    {
      'id': 'item_1',
      'productId': 'prod_abc',
      'productName': 'Milk 1L',
      'quantity': 2,
      'price': 50.0,
    }
  ],
  totalAmount: 100.0,
  deliveryAddress: '123 Main St',
  customerPhone: '+919876543210',
  paymentMethod: 'razorpay',
  deliveryType: 'standard',
);

print('Order created: ${order['orderNumber']}');
```

### After Payment Verification
```dart
await orderService.confirmOrder(
  orderId: order['id'],
  paymentId: 'pay_123abc',
  transactionId: 'txn_456def',
);
// Automatically:
// - Reserves inventory
// - Creates fulfillment task
// - Notifies shop
```

### Workflow Progression
```dart
// Employee picked items
await orderService.markProcessing(orderId);

// Items packed and QC passed
await orderService.markPacked(orderId: orderId, packingTaskId: 'task_123');

// Rider assigned and picked up
await orderService.markShipped(
  orderId: orderId,
  riderId: 'rider_123',
  riderName: 'Raj Kumar',
  riderPhone: '+919999999999',
);

// Rider confirmed delivery
await orderService.markDelivered(orderId);

// Order complete
await orderService.markCompleted(orderId);
```

### Get Order Status
```dart
final order = await orderService.getOrder(orderId);
print('Status: ${order['status']}');
print('Paid: ${order['paymentStatus']}');
print('Rider: ${order['riderName']}');

// Get customer's orders
final orders = await orderService.getCustomerOrders(customerId);

// Get shop's pending orders
final pending = await orderService.getShopOrders(
  shopId,
  statusFilter: 'confirmed',
);
```

---

## 2. Packing Workflow

### Creating Fulfillment Task
```dart
// Created automatically by OrderWorkflowService.confirmOrder()
// OR manually:
final packingService = PackingWorkflowService();

final task = await packingService.createFulfillmentTask(
  orderId: 'order_123',
  shopId: 'shop_456',
  branchId: 'branch_1',
  items: [
    {
      'id': 'item_1',
      'productId': 'prod_abc',
      'productName': 'Milk',
      'quantity': 2,
      'price': 50.0,
    }
  ],
);
```

### Employee Workflow
```dart
// Manager assigns task
await packingService.assignToEmployee(
  taskId: task['id'],
  employeeId: 'emp_123',
  employeeName: 'Rohan',
);

// Employee picks items one by one
await packingService.markItemPicked(
  taskId: task['id'],
  itemId: 'item_1',
  notes: 'Picked from shelf A3',
);
// ... repeat for each item
// Auto-transitions to quality_check when all picked

// Employee requests QC
await packingService.requestQualityCheck(task['id']);
```

### QC Inspector Workflow
```dart
// Get tasks pending QC
final tasks = await packingService.getShopTasks(
  shopId,
  statusFilter: 'quality_check',
);

// Inspect and verify
await packingService.verifyItems(
  taskId: 'task_123',
  verifiedBy: 'qc_emp_456',
  notes: 'All items correct, sealed',
);

// OR reject if issues found
await packingService.rejectPacking(
  taskId: 'task_123',
  rejectionReason: 'Milk bottle cracked',
  rejectedBy: 'qc_emp_456',
);
// Task goes back to 'assigned' state, employee notified
```

### Complete Fulfillment
```dart
// When ready to hand off to delivery
await packingService.markCompleted(taskId);
// Automatically:
// - Marks task complete
// - Updates order to 'packed'
// - Creates delivery task
```

---

## 3. Delivery Workflow

### Creating Delivery Task
```dart
// Created automatically after packing complete
// OR manually:
final deliveryService = DeliveryWorkflowService();

final task = await deliveryService.createDeliveryTask(
  orderId: 'order_123',
  shopId: 'shop_456',
  customerId: 'cust_123',
  deliveryFee: 50.0,
  deliveryAddress: '123 Main St',
  customerPhone: '+919876543210',
  deliveryType: 'standard',
  estimatedDistance: 5.2,
);
```

### Dispatcher Workflow
```dart
// Get pending deliveries
final pending = await deliveryService.getShopDeliveries(
  shopId,
  statusFilter: 'assigned',
);

// Assign to rider using matching algorithm
final riderId = await _matchRider(pending[0]);

await deliveryService.assignToRider(
  taskId: pending[0]['id'],
  riderId: riderId,
  riderName: 'Raj Kumar',
  riderPhone: '+919999999999',
  riderEmail: 'raj@delivery.com',
);
// Rider receives notification with full order details
```

### Rider Workflow
```dart
// Get my assigned deliveries
final myDeliveries = await deliveryService.getRiderDeliveries(riderId);

// Pick up from shop
await deliveryService.markPickedUp(
  taskId: 'delivery_123',
  riderId: riderId,
  latitude: 28.7041,
  longitude: 77.1025,
);
// Order status automatically becomes 'shipped'

// Send location updates as you travel
_locationService.onLocationChange.listen((location) {
  await deliveryService.updateLocation(
    taskId: 'delivery_123',
    latitude: location.latitude,
    longitude: location.longitude,
    riderId: riderId,
  );
});
// Auto-transitions to 'in_transit'
// Customer sees real-time tracking

// Deliver to customer
await deliveryService.markDelivered(
  taskId: 'delivery_123',
  riderId: riderId,
  latitude: 28.7041,
  longitude: 77.1025,
  customerSignature: 'signature_base64',
  notes: 'Delivered to door',
);
// Automatically:
// - Updates order to 'delivered'
// - Awards loyalty points
// - Notifies customer to rate
```

### Failure Handling
```dart
// If delivery failed
await deliveryService.markFailed(
  taskId: 'delivery_123',
  failureReason: 'Customer not home',
  riderId: riderId,
  latitude: 28.7041,
  longitude: 77.1025,
);
// Dispatcher notified, can reassign to another rider
// Failure logged with attempt number
```

### Tracking
```dart
// Get delivery task
final task = await deliveryService.getTask(taskId);
print('Status: ${task['status']}');
print('Rider: ${task['assignedRiderName']}');

// Stream real-time tracking
deliveryService.trackDelivery(taskId).listen((task) {
  print('Location: ${task['currentLocation']}');
  print('Status: ${task['status']}');
});

// Get full tracking history
final history = await deliveryService.getTrackingHistory(taskId);
history.forEach((update) {
  print('${update['status']} at ${update['timestamp']}');
  print('Lat: ${update['lat']}, Lng: ${update['lng']}');
});
```

---

## 4. Loyalty Workflow

### Auto-Initialization
```dart
// Loyalty account created automatically on first order
// OR manually:
final loyaltyService = LoyaltyWorkflowService();
await loyaltyService.initializeAccount('cust_123');
```

### Award Points
```dart
// Automatically awarded after delivery
final points = await loyaltyService.awardPointsForPurchase(
  userId: 'cust_123',
  purchaseAmount: 500.0, // ₹500
  orderId: 'order_123',
);
// Points = (500 / 10) * tier_multiplier
// Bronze: 50 points
// Silver: 62.5 points (1.25x)
// Gold: 75 points (1.5x)
```

### Redeem Points
```dart
// Customer redeems 100 points for ₹100
await loyaltyService.redeemPoints(
  userId: 'cust_123',
  points: 100,
  reason: 'discount_on_order',
);
// ₹100 added to wallet automatically
```

### Referral Bonus
```dart
// After referred user places first order
await loyaltyService.processReferralBonus(
  referrerId: 'cust_123',
  referredUserId: 'cust_456',
);
// Both get: ₹25 + 250 points
```

### Check Tier
```dart
final account = await loyaltyService.getAccount('cust_123');
print('Tier: ${account['currentTier']}'); // bronze, silver, gold
print('Balance: ${account['balance']} points');
print('Lifetime: ${account['lifetime']} points');

// Watch for tier upgrades
loyaltyService.watchAccount('cust_123').listen((account) {
  print('Current tier: ${account['currentTier']}');
});
```

### Leaderboard
```dart
final topUsers = await loyaltyService.getLeaderboard(limit: 20);
topUsers.forEach((user) {
  print('${user['userId']}: ${user['lifetime']} lifetime points');
});
```

---

## 5. Returns Workflow

### Request Return
```dart
final returnsService = ReturnsWorkflowService();

final returnReq = await returnsService.requestReturn(
  orderId: 'order_123',
  customerId: 'cust_123',
  reason: 'Defective product',
  description: 'Bottle leaking',
  photoUrls: ['photo1.jpg', 'photo2.jpg'],
);
// Validated: order delivered, within 7 days, no existing return
```

### Shop Owner Reviews
```dart
// Get pending returns
final pending = await returnsService.getShopReturns(
  shopId,
  statusFilter: 'requested',
);

// Option A: Approve return
await returnsService.approveReturn(
  returnId: 'ret_123',
  refundAmount: 50.0,
  approvedBy: 'owner_123',
  notes: 'Bottle replaced',
);
// Automatically:
// - Refunds to customer wallet
// - Restores inventory
// - Marks order as refunded

// Option B: Reject return
await returnsService.rejectReturn(
  returnId: 'ret_123',
  rejectionReason: 'Not our responsibility - used product',
  rejectedBy: 'owner_123',
);
// Customer notified, no refund
```

### Mark as Received
```dart
// After goods physically received
await returnsService.markCompleted(
  returnId: 'ret_123',
  receivedBy: 'warehouse_emp_456',
  notes: 'Bottle condition verified',
);
```

### Get Return Status
```dart
final returnReq = await returnsService.getReturn('ret_123');
print('Status: ${returnReq['status']}');
print('Refund: ₹${returnReq['refundAmount']}');

// Get customer's returns
final myReturns = await returnsService.getCustomerReturns('cust_123');

// Get shop statistics
final stats = await returnsService.getReturnStats(shopId);
print('Returns: ${stats['total']}');
print('Approved: ${stats['approved']}');
print('Rejected: ${stats['rejected']}');
print('Total refunded: ₹${stats['totalRefundAmount']}');
```

---

## 6. Error Handling

All services throw exceptions with clear messages:

```dart
try {
  await orderService.confirmOrder(orderId: 'invalid');
} catch (e) {
  if (e.toString().contains('Order not found')) {
    // Handle missing order
  } else if (e.toString().contains('Cannot confirm')) {
    // Handle invalid state transition
  } else {
    // Handle other errors
  }
}
```

---

## 7. State Validation

Check state transitions before showing UI:

```dart
final order = await orderService.getOrder(orderId);
final status = order['status'];

// Can only cancel before delivered
if (orderService.canTransition(status, 'cancelled')) {
  showCancelButton();
}

// Can only rate after delivered
if (status == 'delivered') {
  showRatingPrompt();
}

// Terminal statuses (no more changes)
if (orderService.isTerminal(status)) {
  showOrderComplete();
}
```

---

## 8. Real-Time Updates

All workflows support streaming:

```dart
// Watch order status changes
orderService.getOrder(orderId); // Call once to get initial state

// Watch delivery tracking
deliveryService.trackDelivery(taskId).listen((task) {
  updateMapWithLocation(task['currentLocation']);
});

// Watch loyalty tier changes
loyaltyService.watchAccount(userId).listen((account) {
  if (account['currentTier'] != previousTier) {
    showTierUpgradeAnimation();
  }
});

// Watch returns status
returnsService.watchShopReturns(shopId).listen((returns) {
  updateReturnsCount(returns.length);
});
```

---

## 9. Audit & Logging

All operations are automatically logged:

```dart
// Audit logs created automatically
// View them:
final logs = await _auditService.getLogs(
  orderId: 'order_123',
  limit: 100,
);

logs.forEach((log) {
  print('${log['timestamp']}: ${log['event']} by ${log['changedBy']}');
  print('Details: ${log['details']}');
});
```

---

## 10. Example: Complete User Journey

```dart
// 1. Customer creates order
final order = await orderService.createOrder(
  customerId: userId,
  shopId: shopId,
  items: cartItems,
  totalAmount: total,
);

// 2. Customer pays
final payment = await paymentService.processPayment(
  orderId: order['id'],
  amount: total,
);

// 3. Order confirmed
await orderService.confirmOrder(
  orderId: order['id'],
  paymentId: payment['id'],
);
// Fulfillment task created automatically

// 4. Employee packs
await packingService.assignToEmployee(taskId, empId);
cartItems.forEach((item) {
  await packingService.markItemPicked(taskId, item['id']);
});
await packingService.requestQualityCheck(taskId);

// 5. QC verifies
await packingService.verifyItems(taskId, qcId);

// 6. Packing complete
await packingService.markCompleted(taskId);
// Order marked as packed, delivery task created

// 7. Dispatcher assigns rider
await deliveryService.assignToRider(deliveryTaskId, riderId);

// 8. Rider delivers
await deliveryService.markPickedUp(deliveryTaskId, riderId);
// Real-time location updates...
await deliveryService.markDelivered(deliveryTaskId, riderId);
// Order marked delivered, loyalty points awarded

// 9. Customer rates order
// (App handles rating UI)

// 10. Optional: Customer requests return
if (defectFound) {
  await returnsService.requestReturn(
    orderId: order['id'],
    customerId: userId,
    reason: 'Defective',
    photoUrls: photos,
  );
  // Shop approves and refunds
}

print('Journey complete!');
```

---

## Quick Reference

| Service | Key Methods |
|---------|------------|
| **OrderWorkflowService** | createOrder, confirmOrder, markPacked, markShipped, markDelivered, cancelOrder |
| **PackingWorkflowService** | createFulfillmentTask, assignToEmployee, markItemPicked, verifyItems, rejectPacking, markCompleted |
| **DeliveryWorkflowService** | createDeliveryTask, assignToRider, markPickedUp, updateLocation, markDelivered, markFailed, getRiderDeliveries |
| **LoyaltyWorkflowService** | awardPointsForPurchase, redeemPoints, processReferralBonus, getAccount, getLeaderboard |
| **ReturnsWorkflowService** | requestReturn, approveReturn, rejectReturn, markCompleted, getReturnStats |

---

## Dependencies

All services depend on:
- `cloud_firestore` - Database
- `flutter/foundation` - debugPrint
- Plus the supporting services:
  - `NotificationService` - SMS/push notifications
  - `AuditService` - Event logging
  - `WalletService` - Balance management
  - `InventoryLedgerService` - Stock tracking

Make sure these are initialized in your main.dart before using workflows.
