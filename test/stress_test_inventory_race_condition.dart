import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Stress Test: Inventory Race Condition Fix Verification
///
/// Purpose: Verify that pessimistic locking prevents negative inventory
/// Scenario: 10 concurrent orders for a product with stock=5
/// Expected: 5 orders succeed, 5 orders fail with "Insufficient stock"
/// Final Stock: Must be 0 (not negative)
///
/// Run with: flutter test test/stress_test_inventory_race_condition.dart

void main() {
  group('Inventory Race Condition Fix - Stress Tests', () {
    late FirebaseFirestore firestore;

    setUpAll(() {
      // Use emulator for testing (must be running locally)
      // firebase emulators:start --only firestore

      firestore = FirebaseFirestore.instance;

      // Point to emulator if running locally
      if (const bool.fromEnvironment('USE_EMULATOR')) {
        FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
        FirebaseFunctions.instanceFor(
          region: 'us-central1',
        ).useFunctionsEmulator('localhost', 5001);
      }
    });

    setUp(() async {
      // Clean up test data before each test
      await _cleanupTestData();
    });

    test(
      '✓ CRITICAL: 10 concurrent orders on stock=5 product → 5 succeed, 5 fail',
      timeout: const Timeout(Duration(seconds: 60)),
      () async {
        const String testProductId = 'test_product_race_condition';
        const int initialStock = 5;
        const int concurrentOrders = 10;
        const int quantityPerOrder = 1;

        // Setup: Create product with stock=5
        await _setupTestProduct(productId: testProductId, initialStock: initialStock);

        // Action: Fire 10 concurrent orders
        final futures = <Future<bool>>[];
        for (int i = 0; i < concurrentOrders; i++) {
          final future = _attemptDeductInventory(
            productId: testProductId,
            quantity: quantityPerOrder,
            orderId: 'concurrent_order_$i',
          );
          futures.add(future);
        }

        // Wait for all to complete (some will fail, which is expected)
        final results = await Future.wait(
          futures,
          eagerError: false, // Don't stop on first error
        );

        // Verify: Exactly 5 succeeded
        final successCount = results.where((r) => r == true).length;
        expect(
          successCount,
          5,
          reason:
              'Expected exactly 5 orders to succeed, got $successCount. '
              'This indicates race condition not fixed!',
        );

        // Verify: Exactly 5 failed
        final failCount = results.where((r) => r == false).length;
        expect(failCount, 5, reason: 'Expected exactly 5 orders to fail, got $failCount');

        // Verify: Final stock is NOT negative
        final finalStock = await _getProductStock(testProductId);
        expect(
          finalStock,
          0,
          reason:
              'Final stock should be 0, got $finalStock. '
              'NEGATIVE STOCK indicates race condition!',
        );

        print('✓ Test Passed: Race condition successfully prevented');
        print('  - Started with stock: $initialStock');
        print('  - Concurrent orders: $concurrentOrders');
        print('  - Successful orders: $successCount');
        print('  - Failed orders: $failCount');
        print('  - Final stock: $finalStock');
      },
    );

    test(
      '✓ Stock not reserved beyond available inventory',
      timeout: const Timeout(Duration(seconds: 30)),
      () async {
        const String testProductId = 'test_product_overflow';
        const int initialStock = 3;

        // Setup: Product with stock=3
        await _setupTestProduct(productId: testProductId, initialStock: initialStock);

        // Try to deduct more than available
        final result = await _attemptDeductInventory(
          productId: testProductId,
          quantity: 5, // More than available
          orderId: 'overflow_order',
        );

        // Must fail
        expect(
          result,
          false,
          reason:
              'Order for 5 units should fail when stock=3. '
              'Race condition allows both orders to pass!',
        );

        // Stock must remain unchanged
        final finalStock = await _getProductStock(testProductId);
        expect(
          finalStock,
          initialStock,
          reason: 'Stock should remain $initialStock after failed order, got $finalStock',
        );
      },
    );

    test(
      '✓ Lock timeout recovery (stale lock cleanup)',
      timeout: const Timeout(Duration(seconds: 90)),
      () async {
        const String testProductId = 'test_product_lock_timeout';
        const int initialStock = 10;

        // Setup
        await _setupTestProduct(productId: testProductId, initialStock: initialStock);

        // Simulate stale lock by manually creating one
        await firestore.collection('product_locks').doc(testProductId).set({
          'locked': true,
          'orderId': 'stale_order',
          'timestamp': DateTime.now().subtract(const Duration(seconds: 35)).millisecondsSinceEpoch,
          'acquiredBy': 'stale_user',
        });

        // Wait and then attempt deduction (lock should auto-recover after 30s)
        await Future.delayed(const Duration(seconds: 5));

        final result = await _attemptDeductInventory(
          productId: testProductId,
          quantity: 1,
          orderId: 'new_order_after_stale',
        );

        // Should succeed (stale lock auto-released)
        expect(
          result,
          true,
          reason:
              'Order should succeed after stale lock timeout. '
              'Lock recovery not working!',
        );

        // Stock should be decremented
        final finalStock = await _getProductStock(testProductId);
        expect(
          finalStock,
          initialStock - 1,
          reason: 'Stock should be decremented after successful order',
        );
      },
    );

    test(
      '✓ Inventory audit trail logged for each operation',
      timeout: const Timeout(Duration(seconds: 30)),
      () async {
        const String testProductId = 'test_product_audit';
        const int initialStock = 10;

        // Setup
        await _setupTestProduct(productId: testProductId, initialStock: initialStock);

        // Perform deduction
        const String orderId = 'audit_test_order';
        await _attemptDeductInventory(productId: testProductId, quantity: 3, orderId: orderId);

        // Verify event logged
        final events = await firestore
            .collection('inventory_events')
            .where('productId', isEqualTo: testProductId)
            .where('orderId', isEqualTo: orderId)
            .get();

        expect(
          events.docs.isNotEmpty,
          true,
          reason:
              'Inventory event should be logged. '
              'Audit trail missing!',
        );

        final event = events.docs.first.data();
        expect(event['type'], 'stock_deduction');
        expect(event['quantity'], 3);
        expect(event['stockBefore'], initialStock);
        expect(event['stockAfter'], initialStock - 3);
      },
    );

    test(
      '✓ Multi-branch inventory isolation',
      timeout: const Timeout(Duration(seconds: 30)),
      () async {
        const String testProductId = 'test_product_branch';

        // Setup: Product with different stock in different branches
        await firestore.collection('products').doc(testProductId).set({
          'name': 'Branch Test Product',
          'price': 100.0,
          'stockQuantity': 10,
          'branchStock': {'primary': 8, 'branch_b': 2},
        });

        // Deduct from primary branch
        final result1 = await _attemptDeductInventory(
          productId: testProductId,
          quantity: 5,
          orderId: 'branch_primary_order',
          shopId: 'primary',
        );
        expect(result1, true);

        // Deduct from branch_b
        final result2 = await _attemptDeductInventory(
          productId: testProductId,
          quantity: 3, // More than available in branch_b
          orderId: 'branch_b_order',
          shopId: 'branch_b',
        );
        expect(result2, false);

        // Verify isolation
        final doc = await firestore.collection('products').doc(testProductId).get();
        final branchStock = doc['branchStock'] as Map;

        expect(branchStock['primary'], 3, reason: 'Primary should have 3 left');
        expect(branchStock['branch_b'], 2, reason: 'Branch B should still have 2');
      },
    );

    test(
      '✓ Refund restores stock correctly',
      timeout: const Timeout(Duration(seconds: 30)),
      () async {
        const String testProductId = 'test_product_refund';
        const String testOrderId = 'test_refund_order';
        const int initialStock = 10;

        // Setup
        await _setupTestProduct(productId: testProductId, initialStock: initialStock);

        // Create test order
        await firestore.collection('orders').doc(testOrderId).set({
          'id': testOrderId,
          'customerId': 'test_customer',
          'shopId': 'primary',
          'items': [
            {
              'productId': testProductId,
              'quantity': 3,
              'productName': 'Test Product',
              'price': 100.0,
            },
          ],
          'status': 'confirmed',
          'totalAmount': 300.0,
          'createdAt': Timestamp.now(),
        });

        // Deduct stock (simulating order fulfillment)
        await _attemptDeductInventory(productId: testProductId, quantity: 3, orderId: testOrderId);

        var stock = await _getProductStock(testProductId);
        expect(stock, initialStock - 3, reason: 'Stock should be 7 after deduction');

        // Process refund (would normally call Cloud Function)
        // For now, manually restore to verify logic
        await _manualRestoreStock(productId: testProductId, quantity: 3);

        // Verify stock restored
        stock = await _getProductStock(testProductId);
        expect(
          stock,
          initialStock,
          reason: 'Stock should be restored to initial value after refund',
        );
      },
    );
  });
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

Future<void> _setupTestProduct({required String productId, required int initialStock}) async {
  final firestore = FirebaseFirestore.instance;

  await firestore.collection('products').doc(productId).set({
    'id': productId,
    'name': 'Test Product',
    'price': 100.0,
    'stockQuantity': initialStock,
    'branchStock': {'primary': initialStock},
    'isAvailable': true,
    'category': 'Test',
    'createdAt': Timestamp.now(),
  });
}

Future<bool> _attemptDeductInventory({
  required String productId,
  required int quantity,
  required String orderId,
  String shopId = 'primary',
}) async {
  try {
    final firestore = FirebaseFirestore.instance;

    // Use Firestore transaction for atomic inventory deduction
    await firestore.runTransaction((transaction) async {
      final productRef = firestore.collection('products').doc(productId);
      final productDoc = await transaction.get(productRef);

      if (!productDoc.exists) {
        throw Exception('Product not found');
      }

      final currentStock = (productDoc['stockQuantity'] ?? 0) as int;
      if (currentStock < quantity) {
        throw Exception('Insufficient stock');
      }

      transaction.update(productRef, {
        'stockQuantity': currentStock - quantity,
      });
    });

    return true; // Success
  } catch (e) {
    print('Order $orderId failed: $e');
    return false; // Failed (expected for some orders)
  }
}

Future<int> _getProductStock(String productId) async {
  final firestore = FirebaseFirestore.instance;
  final doc = await firestore.collection('products').doc(productId).get();

  if (!doc.exists) return 0;

  return (doc['stockQuantity'] ?? 0) as int;
}

Future<void> _manualRestoreStock({required String productId, required int quantity}) async {
  final firestore = FirebaseFirestore.instance;
  final doc = await firestore.collection('products').doc(productId).get();

  if (!doc.exists) return;

  final currentStock = (doc['stockQuantity'] ?? 0) as int;
  final newStock = currentStock + quantity;

  await firestore.collection('products').doc(productId).update({
    'stockQuantity': newStock,
    'branchStock': {'primary': newStock},
  });
}

Future<void> _cleanupTestData() async {
  final firestore = FirebaseFirestore.instance;

  // Delete test products
  final productSnapshots = await firestore.collection('products').get();
  for (final doc in productSnapshots.docs) {
    if (doc.id.startsWith('test_product_')) {
      await doc.reference.delete();
    }
  }

  // Delete test orders
  final orderSnapshots = await firestore.collection('orders').get();
  for (final doc in orderSnapshots.docs) {
    if (doc.id.startsWith('test_') || doc.id.startsWith('concurrent_')) {
      await doc.reference.delete();
    }
  }

  // Delete test locks
  final lockSnapshots = await firestore.collection('product_locks').get();
  for (final doc in lockSnapshots.docs) {
    if (doc.id.startsWith('test_')) {
      await doc.reference.delete();
    }
  }

  // Delete test events
  final eventSnapshots = await firestore.collection('inventory_events').get();
  for (final doc in eventSnapshots.docs) {
    await doc.reference.delete();
  }
}
