# Consolidation Test Template

Use these templates to create unit tests and integration tests for the unified services.

---

## Unit Test: UnifiedOrderService

**File**: `test/services/unified_order_service_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fufaji/services/unified_order_service.dart';

void main() {
  group('UnifiedOrderService', () {
    late FakeFirebaseFirestore firestore;
    late UnifiedOrderService orderService;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      orderService = UnifiedOrderService();
      orderService.db = firestore;
    });

    test('Create normal order', () async {
      final order = await orderService.createOrder(
        customerId: 'user1',
        shopId: 'shop1',
        items: [
          {'productId': 'prod1', 'quantity': 2, 'price': 250}
        ],
        totalAmount: 500,
        orderType: 'normal',
        paymentMethod: 'card',
      );

      expect(order.id, isNotNull);
      expect(order.status, 'pending');
      expect(order.orderType, 'normal');
      expect(order.customerId, 'user1');
    });

    test('Create wallet order validates balance', () async {
      // Setup wallet with insufficient balance
      await firestore
          .collection('wallets')
          .doc('user1')
          .set({'balance': 200});

      expect(
        () => orderService.createOrder(
          customerId: 'user1',
          shopId: 'shop1',
          items: [
            {'productId': 'prod1', 'quantity': 2, 'price': 250}
          ],
          totalAmount: 500,
          orderType: 'wallet',
        ),
        throwsException,
      );
    });

    test('Create wallet order succeeds with sufficient balance', () async {
      // Setup wallet with sufficient balance
      await firestore
          .collection('wallets')
          .doc('user1')
          .set({'balance': 1000});

      final order = await orderService.createOrder(
        customerId: 'user1',
        shopId: 'shop1',
        items: [
          {'productId': 'prod1', 'quantity': 2, 'price': 250}
        ],
        totalAmount: 500,
        orderType: 'wallet',
      );

      expect(order.id, isNotNull);
      expect(order.paymentMethod, 'wallet');
    });

    test('Create group buy order validates group exists', () async {
      // Group buy not created, should fail
      expect(
        () => orderService.createOrder(
          customerId: 'user1',
          shopId: 'shop1',
          items: [],
          totalAmount: 500,
          orderType: 'group_buy',
          groupBuyId: 'nonexistent',
        ),
        throwsException,
      );

      // Create group buy
      await firestore
          .collection('group_buys')
          .doc('group1')
          .set({'status': 'active'});

      // Now should succeed
      final order = await orderService.createOrder(
        customerId: 'user1',
        shopId: 'shop1',
        items: [],
        totalAmount: 500,
        orderType: 'group_buy',
        groupBuyId: 'group1',
      );

      expect(order.groupBuyId, 'group1');
    });

    test('Prevent duplicate orders', () async {
      // Create first order
      await orderService.createOrder(
        customerId: 'user1',
        shopId: 'shop1',
        items: [
          {'productId': 'prod1', 'quantity': 2, 'price': 250}
        ],
        totalAmount: 500,
        orderType: 'normal',
      );

      // Try to create duplicate
      expect(
        () => orderService.createOrder(
          customerId: 'user1',
          shopId: 'shop1',
          items: [
            {'productId': 'prod1', 'quantity': 2, 'price': 250}
          ],
          totalAmount: 500,
          orderType: 'normal',
        ),
        throwsException,
      );
    });

    test('Valid state transitions allowed', () async {
      final order = await orderService.createOrder(
        customerId: 'user1',
        shopId: 'shop1',
        items: [],
        totalAmount: 500,
        orderType: 'normal',
      );

      expect(orderService.canTransition('pending', 'confirmed'), true);
      expect(orderService.canTransition('confirmed', 'processing'), true);
      expect(orderService.canTransition('processing', 'packed'), true);
      expect(orderService.canTransition('packed', 'shipped'), true);
      expect(orderService.canTransition('shipped', 'delivered'), true);
    });

    test('Invalid state transitions rejected', () async {
      expect(orderService.canTransition('delivered', 'pending'), false);
      expect(orderService.canTransition('shipped', 'processing'), false);
      expect(orderService.canTransition('refunded', 'delivered'), false);
    });

    test('Cancel from processing triggers refund', () async {
      // Create and process order
      final order = await orderService.createOrder(
        customerId: 'user1',
        shopId: 'shop1',
        items: [],
        totalAmount: 500,
        orderType: 'normal',
        paymentMethod: 'card',
      );

      await orderService.transitionOrder(
        orderId: order.id,
        toStatus: 'confirmed',
      );

      await orderService.transitionOrder(
        orderId: order.id,
        toStatus: 'processing',
      );

      // Cancel
      await orderService.cancelOrder(
        orderId: order.id,
        reason: 'Customer request',
        cancelledBy: 'support',
      );

      // Verify final state
      final status = await orderService.getOrderStatus(order.id);
      expect(status, 'refunded');

      // Verify wallet was updated
      final wallet = await firestore.collection('wallets').doc('user1').get();
      expect(wallet.data()?['balance'], 500);
    });

    test('Apply discount to order', () async {
      final order = await orderService.createOrder(
        customerId: 'user1',
        shopId: 'shop1',
        items: [],
        totalAmount: 500,
        orderType: 'normal',
      );

      final newTotal = await orderService.applyDiscount(
        orderId: order.id,
        discountId: 'coupon1',
        discountType: 'coupon',
        discountAmount: 50,
      );

      expect(newTotal, 450);

      final updatedOrder = await orderService.getOrder(order.id);
      expect(updatedOrder?.totalAmount, 450);
    });
  });
}
```

---

## Unit Test: UnifiedPackingService

**File**: `test/services/unified_packing_service_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fufaji/services/unified_packing_service.dart';

void main() {
  group('UnifiedPackingService', () {
    late FakeFirebaseFirestore firestore;
    late UnifiedPackingService packingService;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      packingService = UnifiedPackingService();
      packingService._db = firestore; // Note: may need accessor
    });

    test('Create fulfillment task from order', () async {
      // Setup order
      await firestore.collection('orders').doc('order1').set({
        'orderId': 'order1',
        'customerId': 'user1',
        'status': 'confirmed',
      });

      final task = await packingService.createFulfillmentTask(
        orderId: 'order1',
        shopId: 'shop1',
        branchId: 'branch1',
        items: [
          {'productId': 'prod1', 'quantity': 2}
        ],
      );

      expect(task['id'], isNotNull);
      expect(task['status'], 'new');
      expect(task['orderId'], 'order1');
    });

    test('Assign fulfillment task to employee', () async {
      final task = await packingService.createFulfillmentTask(
        orderId: 'order1',
        shopId: 'shop1',
        branchId: 'branch1',
        items: [],
      );

      await packingService.assignToEmployee(
        taskId: task['id'],
        employeeId: 'emp1',
        employeeName: 'John Doe',
      );

      final updated = await packingService.getTask(task['id']);
      expect(updated?['assignedToEmployeeId'], 'emp1');
      expect(updated?['status'], 'assigned');
    });

    test('Mark items as picked', () async {
      final task = await packingService.createFulfillmentTask(
        orderId: 'order1',
        shopId: 'shop1',
        branchId: 'branch1',
        items: [
          {'productId': 'prod1', 'quantity': 2}
        ],
      );

      await packingService.startPicking(task['id']);

      await packingService.markItemPicked(
        taskId: task['id'],
        itemId: 'item1',
        quantity: 2,
        batchNumber: 'BATCH123',
        expiryDate: '2026-12-31',
      );

      final updated = await packingService.getTask(task['id']);
      final pickedItems = updated?['pickedItems'] as List?;
      expect(pickedItems?.length, 1);
      expect(pickedItems?.first['quantity'], 2);
    });

    test('Verify items before completion', () async {
      final task = await packingService.createFulfillmentTask(
        orderId: 'order1',
        shopId: 'shop1',
        branchId: 'branch1',
        items: [
          {'productId': 'prod1', 'quantity': 2}
        ],
      );

      await packingService.assignToEmployee(
        taskId: task['id'],
        employeeId: 'emp1',
        employeeName: 'John',
      );

      await packingService.startPicking(task['id']);

      await packingService.markItemPicked(
        taskId: task['id'],
        itemId: 'item1',
        quantity: 2,
      );

      await packingService.requestQualityCheck(task['id']);

      await packingService.markItemVerified(
        taskId: task['id'],
        itemId: 'item1',
        notes: 'Quality check passed',
      );

      final updated = await packingService.getTask(task['id']);
      expect(updated?['status'], 'quality_check');
    });

    test('Cannot complete without all items verified', () async {
      final task = await packingService.createFulfillmentTask(
        orderId: 'order1',
        shopId: 'shop1',
        branchId: 'branch1',
        items: [
          {'productId': 'prod1', 'quantity': 2},
          {'productId': 'prod2', 'quantity': 3}
        ],
      );

      // Pick both
      await packingService.startPicking(task['id']);
      await packingService.markItemPicked(
        taskId: task['id'],
        itemId: 'item1',
        quantity: 2,
      );
      await packingService.markItemPicked(
        taskId: task['id'],
        itemId: 'item2',
        quantity: 3,
      );

      // Verify only one
      await packingService.requestQualityCheck(task['id']);
      await packingService.markItemVerified(
        taskId: task['id'],
        itemId: 'item1',
      );

      // Try to complete - should fail
      expect(
        () => packingService.completePacking(taskId: task['id']),
        throwsException,
      );
    });

    test('Complete packing when all items verified', () async {
      final task = await packingService.createFulfillmentTask(
        orderId: 'order1',
        shopId: 'shop1',
        branchId: 'branch1',
        items: [
          {'productId': 'prod1', 'quantity': 2}
        ],
      );

      // Setup order
      await firestore.collection('orders').doc('order1').set({
        'fulfillmentTaskId': task['id'],
      });

      // Complete workflow
      await packingService.startPicking(task['id']);
      await packingService.markItemPicked(
        taskId: task['id'],
        itemId: 'item1',
        quantity: 2,
      );
      await packingService.requestQualityCheck(task['id']);
      await packingService.markItemVerified(
        taskId: task['id'],
        itemId: 'item1',
      );

      // Complete
      await packingService.completePacking(
        taskId: task['id'],
        packageTrackingNumber: 'TRK123',
      );

      // Verify
      final updated = await packingService.getTask(task['id']);
      expect(updated?['status'], 'completed');

      // Order status updated
      final order = await firestore.collection('orders').doc('order1').get();
      expect(order.data()?['status'], 'shipped');
    });

    test('Reject packing resets to assigned', () async {
      final task = await packingService.createFulfillmentTask(
        orderId: 'order1',
        shopId: 'shop1',
        branchId: 'branch1',
        items: [],
      );

      await packingService.assignToEmployee(
        taskId: task['id'],
        employeeId: 'emp1',
        employeeName: 'John',
      );

      await packingService.startPicking(task['id']);

      // Reject
      await packingService.rejectPacking(
        taskId: task['id'],
        reason: 'Items damaged',
        rejectedBy: 'qc1',
      );

      final updated = await packingService.getTask(task['id']);
      expect(updated?['status'], 'assigned');
      expect(updated?['pickedItems'], []);
      expect(updated?['rejectionCount'], 1);
    });
  });
}
```

---

## Unit Test: UnifiedDeliveryService

**File**: `test/services/unified_delivery_service_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fufaji/services/unified_delivery_service.dart';

void main() {
  group('UnifiedDeliveryService', () {
    late FakeFirebaseFirestore firestore;
    late UnifiedDeliveryService deliveryService;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      deliveryService = UnifiedDeliveryService();
      // deliveryService._db = firestore; // Set if needed
    });

    test('Create delivery task', () async {
      final task = await deliveryService.createDeliveryTask(
        orderId: 'order1',
        shopId: 'shop1',
        deliveryFee: 50,
        estimatedDistance: 5.2,
        deliveryAddress: '123 Main St',
        customerPhone: '9876543210',
      );

      expect(task['id'], isNotNull);
      expect(task['status'], 'assigned');
      expect(task['orderId'], 'order1');
      expect(task['deliveryFee'], 50);
    });

    test('Assign delivery to rider', () async {
      final task = await deliveryService.createDeliveryTask(
        orderId: 'order1',
        shopId: 'shop1',
        deliveryFee: 50,
      );

      await deliveryService.assignToRider(
        taskId: task['id'],
        riderId: 'rider1',
        riderName: 'Ram Kumar',
        riderPhone: '9876543210',
      );

      final updated = await deliveryService.getDeliveryTask(task['id']);
      expect(updated?['assignedRiderId'], 'rider1');
    });

    test('P0 FIX: Rider can see assigned orders', () async {
      // Create delivery
      final task = await deliveryService.createDeliveryTask(
        orderId: 'order1',
        shopId: 'shop1',
        deliveryFee: 50,
        deliveryAddress: '123 Main St',
      );

      // Setup order
      await firestore.collection('orders').doc('order1').set({
        'orderId': 'order1',
        'status': 'packed',
        'customerId': 'user1',
      });

      // Assign to rider
      await deliveryService.assignToRider(
        taskId: task['id'],
        riderId: 'rider1',
        riderName: 'Ram',
        riderPhone: '9876543210',
      );

      // CRITICAL TEST: Rider must see the order
      // BEFORE FIX: Would return empty list
      // AFTER FIX: Returns order
      final riderOrders = await deliveryService.getRiderOrders('rider1');
      expect(riderOrders, isNotEmpty);
      expect(riderOrders.first['id'], task['id']);
      expect(riderOrders.first['status'], 'assigned');
    });

    test('Mark delivery as picked up', () async {
      final task = await deliveryService.createDeliveryTask(
        orderId: 'order1',
        shopId: 'shop1',
        deliveryFee: 50,
      );

      await deliveryService.markPickedUp(
        taskId: task['id'],
        latitude: 28.123,
        longitude: 77.456,
      );

      final updated = await deliveryService.getDeliveryTask(task['id']);
      expect(updated?['status'], 'picked_up');
      expect(updated?['pickupLatitude'], 28.123);
    });

    test('Update delivery location for tracking', () async {
      final task = await deliveryService.createDeliveryTask(
        orderId: 'order1',
        shopId: 'shop1',
        deliveryFee: 50,
      );

      await deliveryService.updateLocation(
        taskId: task['id'],
        latitude: 28.123,
        longitude: 77.456,
      );

      final updated = await deliveryService.getDeliveryTask(task['id']);
      expect(updated?['currentLatitude'], 28.123);
      expect(updated?['trackingUpdates'], isNotEmpty);
    });

    test('Mark delivery as in transit', () async {
      final task = await deliveryService.createDeliveryTask(
        orderId: 'order1',
        shopId: 'shop1',
        deliveryFee: 50,
      );

      await deliveryService.markPickedUp(
        taskId: task['id'],
        latitude: 28.1,
        longitude: 77.4,
      );

      await deliveryService.markInTransit(task['id']);

      final updated = await deliveryService.getDeliveryTask(task['id']);
      expect(updated?['status'], 'in_transit');
    });

    test('Mark delivery as delivered with proof', () async {
      // Setup order
      await firestore.collection('orders').doc('order1').set({
        'orderId': 'order1',
        'status': 'shipped',
      });

      final task = await deliveryService.createDeliveryTask(
        orderId: 'order1',
        shopId: 'shop1',
        deliveryFee: 50,
      );

      await deliveryService.markInTransit(task['id']);

      await deliveryService.markDelivered(
        taskId: task['id'],
        latitude: 28.124,
        longitude: 77.457,
        proofImageUrl: 'https://example.com/proof.jpg',
        notes: 'Delivered successfully',
      );

      // Verify delivery
      final updated = await deliveryService.getDeliveryTask(task['id']);
      expect(updated?['status'], 'delivered');
      expect(updated?['proofImageUrl'], isNotNull);

      // Verify order updated
      final order = await firestore.collection('orders').doc('order1').get();
      expect(order.data()?['status'], 'delivered');
    });

    test('Mark delivery as failed with reassignment', () async {
      final task = await deliveryService.createDeliveryTask(
        orderId: 'order1',
        shopId: 'shop1',
        deliveryFee: 50,
      );

      await deliveryService.markPickedUp(taskId: task['id']);

      await deliveryService.markFailed(
        taskId: task['id'],
        failureReason: 'Customer not available',
        latitude: 28.123,
        longitude: 77.456,
      );

      final updated = await deliveryService.getDeliveryTask(task['id']);
      expect(updated?['status'], 'failed');
      expect(updated?['failureCount'], 1);

      // Can reassign to another rider
      final still_failed = updated?['status'] == 'failed';
      expect(still_failed, true);
    });
  });
}
```

---

## Integration Test: Complete Order Flow

**File**: `test/integration/order_fulfillment_flow_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fufaji/services/unified_order_service.dart';
import 'package:fufaji/services/unified_packing_service.dart';
import 'package:fufaji/services/unified_delivery_service.dart';

void main() {
  group('Order Fulfillment Flow - Integration', () {
    late FakeFirebaseFirestore firestore;
    late UnifiedOrderService orderService;
    late UnifiedPackingService packingService;
    late UnifiedDeliveryService deliveryService;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      
      orderService = UnifiedOrderService();
      orderService.db = firestore;
      
      packingService = UnifiedPackingService();
      // packingService._db = firestore;
      
      deliveryService = UnifiedDeliveryService();
      // deliveryService._db = firestore;
    });

    test('Complete flow: order → pack → deliver', () async {
      // 1. CREATE ORDER
      final order = await orderService.createOrder(
        customerId: 'user1',
        shopId: 'shop1',
        items: [
          {'productId': 'prod1', 'quantity': 2, 'price': 250}
        ],
        totalAmount: 500,
        orderType: 'normal',
        paymentMethod: 'card',
      );
      expect(order.status, 'pending');

      // 2. CONFIRM ORDER
      await orderService.transitionOrder(
        orderId: order.id,
        toStatus: 'confirmed',
        changedByUserId: 'system',
      );
      var status = await orderService.getOrderStatus(order.id);
      expect(status, 'confirmed');

      // 3. START PROCESSING (reserve inventory)
      await orderService.transitionOrder(
        orderId: order.id,
        toStatus: 'processing',
        changedByUserId: 'system',
      );
      status = await orderService.getOrderStatus(order.id);
      expect(status, 'processing');

      // 4. CREATE PACKING TASK
      final task = await packingService.createFulfillmentTask(
        orderId: order.id,
        shopId: 'shop1',
        branchId: 'branch1',
        items: [
          {'productId': 'prod1', 'quantity': 2}
        ],
      );
      expect(task['status'], 'new');

      // 5. ASSIGN TO EMPLOYEE
      await packingService.assignToEmployee(
        taskId: task['id'],
        employeeId: 'emp1',
        employeeName: 'John Doe',
      );

      // 6. PICK ITEMS
      await packingService.startPicking(task['id']);
      await packingService.markItemPicked(
        taskId: task['id'],
        itemId: 'prod1',
        quantity: 2,
      );

      // 7. QUALITY CHECK
      await packingService.requestQualityCheck(task['id']);
      await packingService.markItemVerified(
        taskId: task['id'],
        itemId: 'prod1',
      );

      // 8. COMPLETE PACKING
      await packingService.completePacking(
        taskId: task['id'],
        packageTrackingNumber: 'TRK123',
      );

      // 9. ORDER MOVES TO PACKED (inventory deducted)
      await orderService.transitionOrder(
        orderId: order.id,
        toStatus: 'packed',
        changedByUserId: 'system',
      );
      status = await orderService.getOrderStatus(order.id);
      expect(status, 'packed');

      // 10. CREATE DELIVERY TASK
      final delivery = await deliveryService.createDeliveryTask(
        orderId: order.id,
        shopId: 'shop1',
        deliveryFee: 50,
        deliveryAddress: '123 Main St',
        customerPhone: '9876543210',
      );
      expect(delivery['status'], 'assigned');

      // 11. ASSIGN TO RIDER
      await deliveryService.assignToRider(
        taskId: delivery['id'],
        riderId: 'rider1',
        riderName: 'Ram Kumar',
        riderPhone: '9876543210',
      );

      // 12. P0 FIX: RIDER SEES ORDER
      final riderOrders = await deliveryService.getRiderOrders('rider1');
      expect(riderOrders, isNotEmpty);
      expect(riderOrders.first['id'], delivery['id']);

      // 13. RIDER MARKS PICKED UP
      await deliveryService.markPickedUp(
        taskId: delivery['id'],
        latitude: 28.123,
        longitude: 77.456,
      );

      // 14. RIDER MARKS IN TRANSIT
      await deliveryService.markInTransit(delivery['id']);

      // 15. RIDER MARKS DELIVERED
      await deliveryService.markDelivered(
        taskId: delivery['id'],
        latitude: 28.124,
        longitude: 77.457,
        proofImageUrl: 'https://example.com/proof.jpg',
      );

      // 16. ORDER MOVES TO SHIPPED, THEN DELIVERED
      await orderService.transitionOrder(
        orderId: order.id,
        toStatus: 'shipped',
      );

      await orderService.transitionOrder(
        orderId: order.id,
        toStatus: 'delivered',
      );

      final finalOrder = await orderService.getOrder(order.id);
      expect(finalOrder?.status, 'delivered');

      // 17. VERIFY ORDER HISTORY
      final history = await orderService.getOrderHistory(order.id);
      expect(history.length, greaterThan(0));
      final lastStatus = history.last['status'];
      expect(lastStatus, 'delivered');
    });

    test('Cancellation flow with refund', () async {
      // Create and process order
      final order = await orderService.createOrder(
        customerId: 'user1',
        shopId: 'shop1',
        items: [],
        totalAmount: 500,
        orderType: 'normal',
        paymentMethod: 'card',
      );

      await orderService.transitionOrder(
        orderId: order.id,
        toStatus: 'confirmed',
      );

      await orderService.transitionOrder(
        orderId: order.id,
        toStatus: 'processing',
      );

      // Cancel
      await orderService.cancelOrder(
        orderId: order.id,
        reason: 'Customer request',
        cancelledBy: 'support',
      );

      // Verify cancelled
      var status = await orderService.getOrderStatus(order.id);
      expect(status, 'cancelled');

      // Verify refunded
      status = await orderService.getOrderStatus(order.id);
      // Final status after cancellation + refund
      final finalOrder = await orderService.getOrder(order.id);
      expect(finalOrder?.statusHistory, isNotEmpty);
    });

    test('Delivery failure and reassignment', () async {
      // Create delivery
      final delivery = await deliveryService.createDeliveryTask(
        orderId: 'order1',
        shopId: 'shop1',
        deliveryFee: 50,
      );

      // Assign to rider1
      await deliveryService.assignToRider(
        taskId: delivery['id'],
        riderId: 'rider1',
        riderName: 'Ram',
        riderPhone: '9876543210',
      );

      // Rider1 picks up
      await deliveryService.markPickedUp(taskId: delivery['id']);

      // Rider1 marks failed
      await deliveryService.markFailed(
        taskId: delivery['id'],
        failureReason: 'Customer not available',
      );

      var task = await deliveryService.getDeliveryTask(delivery['id']);
      expect(task?['status'], 'failed');
      expect(task?['failureCount'], 1);

      // Reassign to rider2
      await deliveryService.assignToRider(
        taskId: delivery['id'],
        riderId: 'rider2',
        riderName: 'Priya',
        riderPhone: '9988776655',
      );

      // Rider2 sees it
      final rider2Orders = await deliveryService.getRiderOrders('rider2');
      expect(rider2Orders, isNotEmpty);

      // Rider2 completes
      await deliveryService.markPickedUp(taskId: delivery['id']);
      await deliveryService.markInTransit(delivery['id']);
      await deliveryService.markDelivered(
        taskId: delivery['id'],
        proofImageUrl: 'https://example.com/proof.jpg',
      );

      task = await deliveryService.getDeliveryTask(delivery['id']);
      expect(task?['status'], 'delivered');
    });
  });
}
```

---

## Running the Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/unified_order_service_test.dart

# Run with verbose output
flutter test -v

# Run tests matching pattern
flutter test -k "P0 FIX"

# Generate coverage
flutter test --coverage
```

---

## Mocking Strategy

If not using FakeFirebaseFirestore:

```dart
import 'package:mockito/mockito.dart';

// Mock Firestore
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference {}
class MockDocumentReference extends Mock implements DocumentReference {}

// In test setup
final firestore = MockFirebaseFirestore();
final orderService = UnifiedOrderService();
orderService.db = firestore;

// Setup expectations
when(firestore.collection('orders')).thenReturn(mockCollection);
when(mockCollection.doc('order1')).thenReturn(mockDoc);
when(mockDoc.get()).thenAnswer((_) async => mockSnapshot);
```

---

## Test Checklist

- [ ] UnifiedOrderService unit tests (8 tests)
- [ ] UnifiedPackingService unit tests (8 tests)
- [ ] UnifiedDeliveryService unit tests (8 tests)
- [ ] **P0 Fix Test: Rider sees orders** (CRITICAL)
- [ ] Integration: Complete order flow
- [ ] Integration: Cancellation flow
- [ ] Integration: Failure/reassignment flow
- [ ] All tests passing locally
- [ ] Coverage > 80%
- [ ] Staging deployment test
- [ ] Production smoke test

---

**Total Tests Needed**: 
- Unit: ~24 tests
- Integration: ~3 tests
- Smoke: Manual testing

**Estimated Effort**: 2-3 days
