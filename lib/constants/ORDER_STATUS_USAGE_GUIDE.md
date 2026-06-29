# OrderStatus Enum - Usage Guide

## Quick Reference

### Import
```dart
import '../constants/order_status.dart';
```

### All Valid Statuses
```dart
OrderStatus.pending         // Just created, awaiting payment
OrderStatus.confirmed       // Payment verified
OrderStatus.processing      // Being prepared at shop
OrderStatus.packed          // Ready for delivery
OrderStatus.shipped         // With rider, in transit
OrderStatus.delivered       // Delivered to customer
OrderStatus.cancelled       // Cancelled by customer/shop
OrderStatus.refunded        // Refund processed
```

## Common Operations

### 1. Writing to Firestore
```dart
// CORRECT ✓
await _db.collection('orders').doc(orderId).update({
  'status': OrderStatus.packed.firestoreValue,
});

// WRONG ✗ - Don't use string literals
await _db.collection('orders').doc(orderId).update({
  'status': 'packed',  // BAD!
});
```

### 2. Reading from Firestore
```dart
final orderSnap = await _db.collection('orders').doc(orderId).get();
final statusStr = orderSnap.data()?['status'] as String?;

// Parse to enum (handles all formats automatically)
final status = OrderStatus.fromString(statusStr);

// Now you can use enum methods
if (status.isTerminal) {
  print('Order is in terminal state');
}
```

### 3. Checking if Status is Terminal
```dart
final status = OrderStatus.fromString(orderData['status']);

if (status.isTerminal) {
  // This status is cancelled or refunded
  // No further transitions allowed
  print('Cannot modify orders in terminal state');
}
```

### 4. Validating Status Transitions
```dart
final current = OrderStatus.fromString(currentStatusStr);
final next = OrderStatus.fromString(nextStatusStr);

if (current.canTransitionTo(next)) {
  // Valid transition, proceed
  await transitionOrder(orderId, next);
} else {
  // Invalid transition
  throw Exception('Cannot transition from $current to $next');
}
```

### 5. Getting Valid Next Statuses
```dart
final current = OrderStatus.packed;
final nextStatuses = current.getNextStatuses();
// Returns: {'shipped', 'cancelled'}

for (final next in nextStatuses) {
  print('Can transition to: $next');
}
```

### 6. Getting Human-Readable Labels
```dart
final status = OrderStatus.delivered;
print(status.getLabel());
// Output: "Delivered"

// Great for UI
Text(status.getLabel())
```

### 7. Query Orders by Status
```dart
// CORRECT ✓ - Use enum value
final snap = await _db
  .collection('orders')
  .where('status', isEqualTo: OrderStatus.packed.firestoreValue)
  .get();

// OR with fromString (if status comes from API)
final status = OrderStatus.fromString(apiStatus);
final snap = await _db
  .collection('orders')
  .where('status', isEqualTo: status.firestoreValue)
  .get();
```

### 8. Updating Status History
```dart
final now = DateTime.now();
await _db.collection('orders').doc(orderId).update({
  'status': OrderStatus.packed.firestoreValue,
  'statusHistory': FieldValue.arrayUnion([
    {
      'status': OrderStatus.packed.firestoreValue,  // ← Use enum
      'timestamp': Timestamp.fromDate(now),
      'changedBy': userId,
      'reason': 'packing_completed',
    }
  ])
});
```

## Edge Cases & Migration

### Parsing Legacy Status Strings
The enum automatically handles all old formats:

```dart
// All of these parse correctly:
OrderStatus.fromString('pending')                    // ✓ new format
OrderStatus.fromString('OrderStatus.pending')        // ✓ legacy format
OrderStatus.fromString('outForDelivery')             // ✓ maps to 'shipped'
OrderStatus.fromString('preparing')                  // ✓ maps to 'processing'
OrderStatus.fromString('completed')                  // ✓ maps to 'delivered'
OrderStatus.fromString(null)                         // ✓ defaults to 'pending'
OrderStatus.fromString('')                           // ✓ defaults to 'pending'
```

### Comparing Statuses
```dart
// Correct way - compare enum values
final status = OrderStatus.fromString(statusStr);
if (status == OrderStatus.delivered) {
  // Order is delivered
}

// WRONG - don't compare strings
if (statusStr == 'delivered') {  // BAD! What if it's 'OrderStatus.delivered'?
  // This might not work with legacy data
}
```

### Finding Orders in Multiple Statuses
```dart
// Get all orders that are ready for delivery
final snap = await _db
  .collection('orders')
  .where('status', whereIn: [
    OrderStatus.packed.firestoreValue,
    OrderStatus.shipped.firestoreValue,
  ])
  .get();

// Loop through results
for (final doc in snap.docs) {
  final status = OrderStatus.fromString(doc.data()['status']);
  print('Order ${doc.id} is in status: ${status.getLabel()}');
}
```

## Service Integration Examples

### In UnifiedOrderService
```dart
Future<void> transitionOrder({
  required String orderId,
  required String toStatus,
  String? changedByUserId,
  String? reason,
}) async {
  final orderSnap = await _db.collection('orders').doc(orderId).get();
  final orderData = orderSnap.data() as Map<String, dynamic>;
  final currentStatus = orderData['status'] as String;

  // Parse using enum
  final currentStatusEnum = OrderStatus.fromString(currentStatus);
  final nextStatusEnum = OrderStatus.fromString(toStatus);

  // Validate transition
  if (!currentStatusEnum.canTransitionTo(nextStatusEnum)) {
    throw Exception('Invalid transition: $currentStatus → $toStatus');
  }

  // Write using enum
  await _db.collection('orders').doc(orderId).update({
    'status': nextStatusEnum.firestoreValue,
    'updatedAt': Timestamp.fromDate(DateTime.now()),
  });
}
```

### In DeliveryWorkflowService
```dart
Future<void> markDelivered({
  required String taskId,
  String? riderId,
}) async {
  final taskSnap = await _db.collection('delivery_tasks').doc(taskId).get();
  final taskData = taskSnap.data() as Map<String, dynamic>;
  final orderId = taskData['orderId'] as String;

  // Update delivery task
  await _db.collection('delivery_tasks').doc(taskId).update({
    'status': 'delivered',
    'deliveredAt': Timestamp.fromDate(DateTime.now()),
  });

  // Update order - use enum!
  await _db.collection('orders').doc(orderId).update({
    'status': OrderStatus.delivered.firestoreValue,
    'deliveredAt': Timestamp.fromDate(DateTime.now()),
  });
}
```

### In PackingWorkflowService
```dart
Future<void> markCompleted(String taskId) async {
  final taskSnap = await _db.collection('fulfillment_tasks').doc(taskId).get();
  final taskData = taskSnap.data() as Map<String, dynamic>;
  final orderId = taskData['orderId'] as String;

  // Complete task
  await _db.collection('fulfillment_tasks').doc(taskId).update({
    'status': PackingWorkflowStatus.completed.name,
  });

  // Update order - use enum!
  await _db.collection('orders').doc(orderId).update({
    'status': OrderStatus.packed.firestoreValue,
    'packedAt': Timestamp.fromDate(DateTime.now()),
  });
}
```

## Testing

### Unit Test Example
```dart
void testOrderStatusTransitions() {
  // Test valid transitions
  expect(
    OrderStatus.pending.canTransitionTo(OrderStatus.confirmed),
    isTrue,
  );

  // Test invalid transitions
  expect(
    OrderStatus.cancelled.canTransitionTo(OrderStatus.processing),
    isFalse,
  );

  // Test terminal states
  expect(OrderStatus.refunded.isTerminal, isTrue);
  expect(OrderStatus.processing.isTerminal, isFalse);

  // Test parsing legacy formats
  expect(
    OrderStatus.fromString('OrderStatus.packed'),
    equals(OrderStatus.packed),
  );
}
```

### Integration Test Example
```dart
void testRiderCanSeeDeliveries() {
  // Create order
  final order = createOrder(status: OrderStatus.pending);
  
  // Transition through states
  order.transition(OrderStatus.confirmed);
  order.transition(OrderStatus.processing);
  order.transition(OrderStatus.packed);  // ← Packing complete
  
  // Create delivery task
  final deliveryTask = createDeliveryTask(order);
  expect(deliveryTask.status, equals('assigned'));
  
  // Assign to rider
  deliveryTask.assignToRider('rider_123');
  
  // Rider should see the order
  final riderOrders = getRiderOrders('rider_123');
  expect(riderOrders.length, greaterThan(0));
  
  // Order status should be consistent
  expect(
    riderOrders.first['order']['status'],
    equals(OrderStatus.packed.firestoreValue),
  );
}
```

## Common Mistakes to Avoid

### ❌ DON'T: Use string literals
```dart
await db.collection('orders').update({'status': 'packed'});
```
**Why**: Inconsistent with other services, hard to refactor

### ✓ DO: Use enum values
```dart
await db.collection('orders').update({
  'status': OrderStatus.packed.firestoreValue
});
```

### ❌ DON'T: Compare status strings directly
```dart
if (order['status'] == 'packed') { }
```
**Why**: Breaks with legacy format 'OrderStatus.packed'

### ✓ DO: Parse and compare enums
```dart
final status = OrderStatus.fromString(order['status']);
if (status == OrderStatus.packed) { }
```

### ❌ DON'T: Use enum.name directly for Firestore
```dart
'status': OrderStatus.packed.name,  // Wrong! Returns 'packed' (correct by coincidence)
```
**Why**: Some enums have different name (pending_approval) vs value (pending)

### ✓ DO: Use enum.firestoreValue
```dart
'status': OrderStatus.packed.firestoreValue,  // Always correct
```

## Migration from Old Code

### Before
```dart
// Old code using string literals scattered everywhere
if (order['status'] == 'OrderStatus.packed') { }
await db.update({'status': 'preparing'});
for (var status in ['pending', 'confirmed', 'processing']) { }
```

### After
```dart
// New code using enum consistently
final status = OrderStatus.fromString(order['status']);
if (status == OrderStatus.packed) { }

await db.update({'status': OrderStatus.processing.firestoreValue});

for (var status in [
  OrderStatus.pending,
  OrderStatus.confirmed,
  OrderStatus.processing,
]) { }
```

## Support & Questions

For issues or questions about OrderStatus usage:
1. Check this guide first
2. Look at examples in service files
3. Review the enum definition in `lib/constants/order_status.dart`
4. Ask the team in #backend channel
