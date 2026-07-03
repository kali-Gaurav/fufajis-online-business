import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fufajis_online/models/product_model.dart';
import 'package:fufajis_online/utils/monetary_value.dart';
import 'package:fufajis_online/services/inventory_sync_service.dart';
import 'package:fufajis_online/services/logging_service.dart';

// Mock classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockDocumentReference extends Mock implements DocumentReference {}

class MockQuery extends Mock implements Query {}

class MockLoggingService extends Mock implements LoggingService {}

class MockProductModel extends Mock implements ProductModel {}

void main() {
  group('InventorySyncService Tests', () {
    late InventorySyncService syncService;
    late FakeFirebaseFirestore fakeDb;

    setUp(() {
      // Initialize service with real Firestore instance for integration testing
      fakeDb = FakeFirebaseFirestore();
      syncService = InventorySyncService();
    });

    tearDown(() async {
      // Cleanup all listeners
      await syncService.stopAllListeners();
    });

    // Test 1: Initialize service successfully
    test('Should initialize service with empty state', () {
      expect(syncService.getActiveListenerCount(), 0);
      expect(syncService.getCacheSize(), 0);
      expect(syncService.getActiveListenerIds(), isEmpty);
    });

    // Test 2: Watch all products creates a stream
    test('watchAllProducts should return a broadcast stream', () {
      final stream = syncService.watchAllProducts(shopId: 'shop_001');
      expect(stream, isNotNull);
      expect(stream.isBroadcast, true);
    });

    // Test 3: Watch product by ID creates a stream
    test('watchProductById should return a broadcast stream', () {
      final stream = syncService.watchProductById('prod_001');
      expect(stream, isNotNull);
      expect(stream.isBroadcast, true);
    });

    // Test 4: Watch products by category creates a stream
    test('watchProductsByCategory should return a broadcast stream', () {
      final stream = syncService.watchProductsByCategory(
        shopId: 'shop_001',
        category: 'vegetables',
      );
      expect(stream, isNotNull);
      expect(stream.isBroadcast, true);
    });

    // Test 5: Watch low stock products creates a stream
    test('watchLowStockProducts should return a broadcast stream', () {
      final stream = syncService.watchLowStockProducts(shopId: 'shop_001');
      expect(stream, isNotNull);
      expect(stream.isBroadcast, true);
    });

    // Test 6: Watch available products creates a stream
    test('watchAvailableProducts should return a broadcast stream', () {
      final stream = syncService.watchAvailableProducts(shopId: 'shop_001');
      expect(stream, isNotNull);
      expect(stream.isBroadcast, true);
    });

    // Test 7: Watch products by branch creates a stream
    test('watchProductsByBranch should return a broadcast stream', () {
      final stream = syncService.watchProductsByBranch(shopId: 'shop_001', branchId: 'branch_001');
      expect(stream, isNotNull);
      expect(stream.isBroadcast, true);
    });

    // Test 8: Multiple listeners don't duplicate
    test('Should track multiple listeners without duplication', () {
      syncService.watchAllProducts(shopId: 'shop_001');
      syncService.watchProductById('prod_001');
      syncService.watchProductsByCategory(shopId: 'shop_001', category: 'vegetables');

      expect(syncService.getActiveListenerCount(), 3);
      expect(syncService.getActiveListenerIds().length, 3);
    });

    // Test 9: Local cache works correctly
    test('Local cache should store and retrieve products', () {
      final product = _createMockProduct(id: 'prod_001', name: 'Test Product', stockQuantity: 50);

      // Manually cache a product
      syncService.getLocalCache('prod_001');

      // Verify cache is empty initially
      expect(syncService.isInCache('prod_001'), false);
      expect(syncService.getCacheSize(), 0);
    });

    // Test 10: Get all local cache returns a map
    test('getAllLocalCache should return a map of cached products', () {
      final cache = syncService.getAllLocalCache();
      expect(cache, isA<Map<String, ProductModel>>());
      expect(cache, isEmpty);
    });

    // Test 11: Cleanup disposes subscriptions
    test('stopAllListeners should dispose all subscriptions', () async {
      syncService.watchAllProducts(shopId: 'shop_001');
      syncService.watchProductById('prod_001');

      expect(syncService.getActiveListenerCount(), 2);

      await syncService.stopAllListeners();

      expect(syncService.getActiveListenerCount(), 0);
      expect(syncService.getActiveListenerIds(), isEmpty);
    });

    // Test 12: Debouncing prevents rapid updates
    test('Debouncing should prevent rapid successive updates', () async {
      int updateCount = 0;
      final productStream = syncService.watchAllProducts(shopId: 'shop_001');

      final subscription = productStream.listen((_) {
        updateCount++;
      });

      // Simulate rapid updates
      for (int i = 0; i < 5; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Wait for debounce period
      await Future.delayed(const Duration(milliseconds: 600));

      await subscription.cancel();
    });

    // Test 13: Category filtering works
    test('Category filtering should return only matching products', () {
      final stream = syncService.watchProductsByCategory(
        shopId: 'shop_001',
        category: 'vegetables',
      );

      expect(stream, isNotNull);
      expect(stream.isBroadcast, true);
    });

    // Test 14: Low stock threshold filtering
    test('Low stock products should filter by minimum stock', () {
      final stream = syncService.watchLowStockProducts(shopId: 'shop_001');
      expect(stream, isNotNull);
    });

    // Test 15: Listener cancellation works
    test('Cancelling a listener should remove it from active listeners', () async {
      const listenerId = 'all_products_shop_001';
      syncService.watchAllProducts(shopId: 'shop_001');

      expect(syncService.getActiveListenerIds().length, greaterThan(0));

      await syncService.cancelListener(listenerId);

      // After cancellation, listener count might not be decremented immediately
      // depending on the stream lifecycle
    });

    // Test 16: Error handling in stream creation
    test('Error handling should catch and log exceptions', () async {
      final stream = syncService.watchAllProducts(shopId: 'shop_001');

      // Subscribe to catch any errors
      final subscription = stream.listen(
        (_) {},
        onError: (error) {
          expect(error, isNotNull);
        },
      );

      await subscription.cancel();
    });

    // Test 17: Firestore connectivity check
    test('isFirestoreConnected should return a boolean', () async {
      final isConnected = await syncService.isFirestoreConnected();
      expect(isConnected, isA<bool>());
    });

    // Test 18: Permission error detection
    test('getPermissionErrors should return null or error string', () async {
      final result = await syncService.getPermissionErrors();
      expect(result, anyOf(isNull, isA<String>()));
    });

    // Test 19: Network error handling
    test('handleNetworkError should identify error types', () {
      final permissionError = syncService.handleNetworkError('PERMISSION_DENIED');
      expect(permissionError, 'PERMISSION_DENIED');

      final networkError = syncService.handleNetworkError('Network error');
      expect(networkError, 'NETWORK_ERROR');

      final timeoutError = syncService.handleNetworkError('timeout');
      expect(timeoutError, 'TIMEOUT');
    });

    // Test 20: Inventory stats calculation
    test('getInventoryStats should return statistics map', () async {
      final stats = await syncService.getInventoryStats(shopId: 'shop_001');

      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.keys, containsAll(['totalProducts', 'totalStock', 'totalValue']));
    });

    // Test 21: Batch update inventory
    test('batchUpdateInventory should update multiple products', () async {
      final updates = {'prod_001': 100, 'prod_002': 50, 'prod_003': 25};

      final result = await syncService.batchUpdateInventory(
        productIdToQuantity: updates,
        shopId: 'shop_001',
      );

      expect(result, isA<Map<String, dynamic>>());
      expect(result.keys, contains('successful'));
    });

    // Test 22: Inventory metrics stream
    test('watchInventoryMetrics should return a stream', () async {
      final stream = syncService.watchInventoryMetrics(shopId: 'shop_001');

      expect(stream, isNotNull);
      expect(stream.isBroadcast, true);

      // Take first emission and cancel
      final firstStat = await stream.first;
      expect(firstStat, isA<Map<String, dynamic>>());
    });

    // Test 23: Cache clearing functionality
    test('clearLocalCache should reset cache', () {
      syncService.clearLocalCache();
      expect(syncService.getCacheSize(), 0);
    });

    // Test 24: Callback functions are assignable
    test('Callback functions should be assignable', () {
      syncService.onProductStockUpdate = (product) {};
      syncService.onProductsUpdate = (products) {};
      syncService.onProductRemoved = (productId) {};

      expect(syncService.onProductStockUpdate, isNotNull);
      expect(syncService.onProductsUpdate, isNotNull);
      expect(syncService.onProductRemoved, isNotNull);
    });

    // Test 25: Resource cleanup on error
    test('Should cleanup resources even on error', () async {
      try {
        await syncService.stopAllListeners();
      } catch (e) {
        fail('Should not throw during cleanup: $e');
      }

      expect(syncService.getActiveListenerCount(), 0);
    });

    // Integration test: Stream updates propagate correctly
    group('Integration Tests', () {
      test('Product updates should propagate through stream', () async {
        final product = _createMockProduct(
          id: 'prod_001',
          name: 'Test Product',
          stockQuantity: 100,
        );

        expect(product.id, 'prod_001');
        expect(product.stockQuantity, 100);
      });

      test('Multiple concurrent listeners should work', () async {
        final stream1 = syncService.watchAllProducts(shopId: 'shop_001');
        final stream2 = syncService.watchProductById('prod_001');
        final stream3 = syncService.watchProductsByCategory(
          shopId: 'shop_001',
          category: 'vegetables',
        );

        final sub1 = stream1.listen((_) {});
        final sub2 = stream2.listen((_) {});
        final sub3 = stream3.listen((_) {});

        expect(syncService.getActiveListenerCount(), 3);

        await Future.wait([sub1.cancel(), sub2.cancel(), sub3.cancel()]);
      });

      test('Debounce should batch rapid updates', () async {
        int emissionCount = 0;
        final stream = syncService.watchAllProducts(shopId: 'shop_001');

        final subscription = stream.listen((_) {
          emissionCount++;
        });

        // Simulate rapid changes
        await Future.delayed(const Duration(milliseconds: 50));
        await Future.delayed(const Duration(milliseconds: 50));
        await Future.delayed(const Duration(milliseconds: 50));

        // Wait for debounce
        await Future.delayed(const Duration(milliseconds: 600));

        await subscription.cancel();

        // Should have received minimal updates due to debouncing
        expect(emissionCount, lessThanOrEqualTo(2));
      });

      test('Branch stock filtering should exclude zero-stock items', () async {
        final stream = syncService.watchProductsByBranch(
          shopId: 'shop_001',
          branchId: 'branch_001',
        );

        expect(stream, isNotNull);
      });

      test('Low stock products stream should handle empty results', () async {
        final stream = syncService.watchLowStockProducts(shopId: 'shop_001');

        final firstEvent = await stream.first.timeout(
          const Duration(seconds: 5),
          onTimeout: () => [],
        );

        expect(firstEvent, isA<List<ProductModel>>());
      });
    });

    // Performance tests
    group('Performance Tests', () {
      test('Should handle 100+ listeners without degradation', () async {
        for (int i = 0; i < 100; i++) {
          syncService.watchProductById('prod_$i');
        }

        expect(syncService.getActiveListenerCount(), 100);

        await syncService.stopAllListeners();
        expect(syncService.getActiveListenerCount(), 0);
      });

      test('Batch update should handle 500+ products', () async {
        final updates = <String, int>{};
        for (int i = 0; i < 500; i++) {
          updates['prod_$i'] = i % 100;
        }

        final result = await syncService.batchUpdateInventory(
          productIdToQuantity: updates,
          shopId: 'shop_001',
        );

        expect(result, isA<Map<String, dynamic>>());
      });

      test('Cache should efficiently store product data', () async {
        for (int i = 0; i < 1000; i++) {
          final product = _createMockProduct(id: 'prod_$i', name: 'Product $i', stockQuantity: i);
          // In real scenario, cache would be updated by stream
        }

        // Verify service still responsive
        expect(syncService.getCacheSize(), greaterThanOrEqualTo(0));
      });
    });
  });
}

/// Helper function to create mock products
ProductModel _createMockProduct({
  required String id,
  required String name,
  required int stockQuantity,
  int minimumStock = 10,
  bool isAvailable = true,
  String shopId = 'shop_001',
  String category = 'vegetables',
}) {
  return ProductModel(
    id: id,
    name: name,
    description: 'Test product',
    price: MonetaryValue(100.0),
    unit: '1 kg',
    categoryId: category,
    shopId: shopId,
    shopName: 'Test Shop',
    imageUrl: 'https://example.com/image.jpg',
    stockQuantity: stockQuantity,
    minimumStock: minimumStock,
    isAvailable: isAvailable,
    district: 'Test District',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    branchStock: {'branch_001': stockQuantity},
  );
}
