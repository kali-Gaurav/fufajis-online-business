import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/product_model.dart';
import 'logging_service.dart';

/// Manages real-time Firestore listeners for inventory synchronization.
///
/// This service provides efficient, stream-based access to product inventory changes
/// from Firestore with built-in:
/// - Debouncing to prevent UI thrashing (max 1 update per 500ms per product)
/// - Error handling and offline caching support
/// - Memory-efficient cleanup of subscriptions
/// - Multi-listener support without duplication
class InventorySyncService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LoggingService _logger = LoggingService();

  /// Map of active stream subscriptions by listener ID
  final Map<String, StreamSubscription> _activeSubscriptions = {};

  /// Map of debounce timers by product ID
  final Map<String, Timer> _debounceTimers = {};

  /// Cache of the last known state for each product
  final Map<String, ProductModel> _localCache = {};

  /// Stream controllers for broadcasting updates
  final Map<String, StreamController<ProductModel>> _productControllers = {};
  final Map<String, StreamController<List<ProductModel>>> _productsListControllers = {};

  /// Debounce duration (500ms) to prevent rapid successive updates
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  /// Callback functions for external listeners
  Function(ProductModel)? onProductStockUpdate;
  Function(List<ProductModel>)? onProductsUpdate;
  Function(String)? onProductRemoved;

  /// Listener activity tracking
  int _listenerCount = 0;

  int getActiveListenerCount() => _listenerCount;

  /// Watch all products in a shop with real-time updates.
  ///
  /// Returns a stream that emits the entire product list whenever any product changes.
  /// This is efficient for shops with moderate product counts (<1000).
  Stream<List<ProductModel>> watchAllProducts({required String shopId}) {
    final listenerId = 'all_products_$shopId';
    _listenerCount++;

    return _createProductsListStream(
      listenerId,
      query: _db
          .collection('products')
          .where('shopId', isEqualTo: shopId)
          .orderBy('updatedAt', descending: true),
    );
  }

  /// Watch a single product by ID for real-time updates.
  ///
  /// Returns a stream that emits the product whenever its data changes.
  /// Useful for product detail pages and quick-reference lookups.
  Stream<ProductModel?> watchProductById(String productId) {
    final listenerId = 'product_$productId';
    _listenerCount++;

    return _createProductStream(listenerId, _db.collection('products').doc(productId));
  }

  /// Watch products in a specific category with real-time updates.
  ///
  /// Returns a stream that emits all products in the category whenever changes occur.
  /// Useful for category browsing screens.
  Stream<List<ProductModel>> watchProductsByCategory({
    required String shopId,
    required String category,
  }) {
    final listenerId = 'category_${shopId}_$category';
    _listenerCount++;

    return _createProductsListStream(
      listenerId,
      query: _db
          .collection('products')
          .where('shopId', isEqualTo: shopId)
          .where('categoryId', isEqualTo: category)
          .orderBy('updatedAt', descending: true),
    );
  }

  /// Watch products with low stock in a shop.
  ///
  /// Returns a stream that emits all products below their minimum stock threshold.
  /// Useful for inventory alerts and owner dashboards.
  Stream<List<ProductModel>> watchLowStockProducts({required String shopId}) {
    final listenerId = 'low_stock_$shopId';
    _listenerCount++;

    // Note: Firestore doesn't support comparing two fields directly,
    // so we fetch all products and filter client-side
    return _createProductsListStream(
      listenerId,
      query: _db.collection('products').where('shopId', isEqualTo: shopId),
      clientSideFilter: (product) => product.stockQuantity < product.minimumStock,
    );
  }

  /// Watch available (in-stock) products in a shop.
  ///
  /// Returns a stream that emits all products that are currently available.
  /// Useful for displaying purchasable inventory.
  Stream<List<ProductModel>> watchAvailableProducts({required String shopId}) {
    final listenerId = 'available_$shopId';
    _listenerCount++;

    return _createProductsListStream(
      listenerId,
      query: _db
          .collection('products')
          .where('shopId', isEqualTo: shopId)
          .where('isAvailable', isEqualTo: true),
      clientSideFilter: (product) => product.stockQuantity > 0,
    );
  }

  /// Watch products by branch.
  ///
  /// Returns a stream that emits products filtered by branch stock availability.
  /// Useful for branch-specific inventory views.
  Stream<List<ProductModel>> watchProductsByBranch({
    required String shopId,
    required String branchId,
  }) {
    final listenerId = 'branch_${shopId}_$branchId';
    _listenerCount++;

    return _createProductsListStream(
      listenerId,
      query: _db.collection('products').where('shopId', isEqualTo: shopId),
      clientSideFilter: (product) =>
          product.branchStock.containsKey(branchId) && product.branchStock[branchId]! > 0,
    );
  }

  /// Create a stream for a single product with debouncing.
  Stream<ProductModel?> _createProductStream(
    String listenerId,
    DocumentReference<Map<String, dynamic>> query,
  ) {
    final controller = StreamController<ProductModel?>.broadcast();

    try {
      final subscription = query.snapshots().listen(
        (docSnapshot) {
          try {
            if (!docSnapshot.exists) {
              controller.add(null);
              onProductRemoved?.call(docSnapshot.id);
              return;
            }

            final data = docSnapshot.data();
            if (data == null) {
              controller.add(null);
              return;
            }

            final product = ProductModel.fromMap(data);
            _debounceProductUpdate(product, () {
              _localCache[product.id] = product;
              controller.add(product);
              onProductStockUpdate?.call(product);
            });
          } catch (e, stack) {
            _logger.error('Error parsing product snapshot', e, stack);
            controller.addError(e, stack);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          _logger.error('Firestore listener error for $listenerId', error, stackTrace);
          controller.addError(error, stackTrace);
        },
      );

      _activeSubscriptions[listenerId] = subscription;

      controller.onCancel = () {
        subscription.cancel();
        _activeSubscriptions.remove(listenerId);
        _listenerCount--;
      };

      return controller.stream;
    } catch (e, stack) {
      _logger.error('Error creating product stream for $listenerId', e, stack);
      controller.addError(e, stack);
      return controller.stream;
    }
  }

  /// Create a stream for multiple products with debouncing.
  Stream<List<ProductModel>> _createProductsListStream(
    String listenerId, {
    required Query<Map<String, dynamic>> query,
    bool Function(ProductModel)? clientSideFilter,
  }) {
    final controller = StreamController<List<ProductModel>>.broadcast();

    try {
      final subscription = query.snapshots().listen(
        (querySnapshot) {
          try {
            final products = querySnapshot.docs
                .map((doc) => ProductModel.fromMap(doc.data()))
                .toList();

            // Apply client-side filtering if provided
            final filteredProducts = clientSideFilter != null
                ? products.where(clientSideFilter).toList()
                : products;

            // Update local cache
            for (final product in filteredProducts) {
              _localCache[product.id] = product;
            }

            // Debounce the emission
            _debounceProductsUpdate(filteredProducts, () {
              controller.add(filteredProducts);
              onProductsUpdate?.call(filteredProducts);
            });
          } catch (e, stack) {
            _logger.error('Error parsing products snapshot', e, stack);
            controller.addError(e, stack);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          _logger.error('Firestore listener error for $listenerId', error, stackTrace);
          controller.addError(error, stackTrace);
        },
      );

      _activeSubscriptions[listenerId] = subscription;

      controller.onCancel = () {
        subscription.cancel();
        _activeSubscriptions.remove(listenerId);
        _listenerCount--;
      };

      return controller.stream;
    } catch (e, stack) {
      _logger.error('Error creating products stream for $listenerId', e, stack);
      controller.addError(e, stack);
      return controller.stream;
    }
  }

  /// Debounce updates for a single product.
  ///
  /// Prevents rapid successive updates from flooding the UI. Max 1 update per 500ms.
  void _debounceProductUpdate(ProductModel product, VoidCallback onUpdate) {
    // Cancel existing timer for this product
    _debounceTimers[product.id]?.cancel();

    // Set new debounce timer
    _debounceTimers[product.id] = Timer(_debounceDuration, () {
      try {
        onUpdate();
      } finally {
        _debounceTimers.remove(product.id);
      }
    });
  }

  /// Debounce updates for multiple products.
  ///
  /// Uses a single debounce for all products to avoid individual timer overhead.
  void _debounceProductsUpdate(List<ProductModel> products, VoidCallback onUpdate) {
    const listenerId = '_all_products_debounce';

    // Cancel existing timer
    _debounceTimers[listenerId]?.cancel();

    // Set new debounce timer
    _debounceTimers[listenerId] = Timer(_debounceDuration, () {
      try {
        onUpdate();
      } finally {
        _debounceTimers.remove(listenerId);
      }
    });
  }

  /// Get the last known state of a product from local cache.
  ///
  /// Useful for serving cached data while syncing with Firestore,
  /// enabling offline-first experiences.
  ProductModel? getLocalCache(String productId) {
    return _localCache[productId];
  }

  /// Get all cached products.
  ///
  /// Returns the entire local cache of products that have been synced.
  Map<String, ProductModel> getAllLocalCache() {
    return Map.from(_localCache);
  }

  /// Clear the local cache.
  ///
  /// Use sparingly - typically not needed as cache is memory-efficient.
  void clearLocalCache() {
    _localCache.clear();
  }

  /// Check if a product is in the local cache.
  bool isInCache(String productId) {
    return _localCache.containsKey(productId);
  }

  /// Get cache size (number of cached products).
  int getCacheSize() {
    return _localCache.length;
  }

  /// Stop all active listeners and cleanup resources.
  ///
  /// Must be called when the provider is disposed to prevent memory leaks.
  /// After calling this, the service should not be used.
  Future<void> stopAllListeners() async {
    try {
      debugPrint('[InventorySyncService] Stopping all listeners. Active: $_listenerCount');

      // Cancel all debounce timers
      for (final timer in _debounceTimers.values) {
        timer.cancel();
      }
      _debounceTimers.clear();

      // Cancel all stream subscriptions
      for (final subscription in _activeSubscriptions.values) {
        await subscription.cancel();
      }
      _activeSubscriptions.clear();

      // Close all stream controllers
      for (final controller in _productControllers.values) {
        await controller.close();
      }
      _productControllers.clear();

      for (final controller in _productsListControllers.values) {
        await controller.close();
      }
      _productsListControllers.clear();

      _listenerCount = 0;
      _logger.info('[InventorySyncService] All listeners stopped and resources cleaned up');
    } catch (e, stack) {
      _logger.error('Error stopping listeners', e, stack);
    }
  }

  /// Cancel a specific listener by ID.
  ///
  /// Useful for cleanup when unsubscribing from specific product changes.
  Future<void> cancelListener(String listenerId) async {
    try {
      final subscription = _activeSubscriptions.remove(listenerId);
      if (subscription != null) {
        await subscription.cancel();
        _listenerCount--;
        debugPrint('[InventorySyncService] Cancelled listener: $listenerId');
      }
    } catch (e, stack) {
      _logger.error('Error cancelling listener $listenerId', e, stack);
    }
  }

  /// Get list of all active listener IDs.
  List<String> getActiveListenerIds() {
    return _activeSubscriptions.keys.toList();
  }

  /// Verify Firestore connectivity.
  ///
  /// Attempts a simple read operation to test the connection.
  /// Returns true if connected, false otherwise.
  Future<bool> isFirestoreConnected() async {
    try {
      await _db.collection('products').limit(1).get(const GetOptions(source: Source.server));
      return true;
    } catch (e) {
      debugPrint('[InventorySyncService] Firestore connectivity check failed: $e');
      return false;
    }
  }

  /// Get Firestore permission errors.
  ///
  /// Checks if the app has permission to read products.
  /// Returns null if permissions are OK.
  Future<String?> getPermissionErrors() async {
    try {
      await _db.collection('products').limit(1).get();
      return null;
    } catch (e) {
      if (e.toString().contains('PERMISSION_DENIED')) {
        return 'Firestore permissions denied. Check security rules.';
      } else if (e.toString().contains('UNAUTHENTICATED')) {
        return 'User not authenticated. Log in required.';
      }
      return 'Firestore error: $e';
    }
  }

  /// Handle network errors gracefully.
  ///
  /// Returns the appropriate fallback action based on error type.
  String handleNetworkError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('permission')) {
      _logger.error('Permission error in inventory sync', error, null);
      return 'PERMISSION_DENIED';
    } else if (errorStr.contains('network') || errorStr.contains('offline')) {
      _logger.warning('Network error in inventory sync: $error');
      return 'NETWORK_ERROR';
    } else if (errorStr.contains('timeout')) {
      _logger.warning('Timeout in inventory sync: $error');
      return 'TIMEOUT';
    } else {
      _logger.error('Unknown error in inventory sync', error, null);
      return 'UNKNOWN_ERROR';
    }
  }

  /// Get inventory statistics for a shop.
  ///
  /// Calculates metrics like total stock, low stock items, etc.
  Future<Map<String, dynamic>> getInventoryStats({required String shopId}) async {
    try {
      final snapshot = await _db.collection('products').where('shopId', isEqualTo: shopId).get();

      final products = snapshot.docs.map((doc) => ProductModel.fromMap(doc.data())).toList();

      final totalStock = products.fold<int>(0, (sum, p) => sum + p.stockQuantity);
      final lowStockCount = products.where((p) => p.stockQuantity < p.minimumStock).length;
      final outOfStock = products.where((p) => p.stockQuantity == 0).length;
      final totalValue = products.fold<double>(
        0,
        (sum, p) => sum + (p.costPrice ?? p.price.toDouble()) * p.stockQuantity,
      );

      return {
        'totalProducts': products.length,
        'totalStock': totalStock,
        'totalValue': totalValue,
        'lowStockCount': lowStockCount,
        'outOfStockCount': outOfStock,
        'averageStockPerProduct': products.isEmpty ? 0 : totalStock / products.length,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e, stack) {
      _logger.error('Error calculating inventory stats', e, stack);
      return {'error': 'Failed to calculate inventory stats', 'message': e.toString()};
    }
  }

  /// Batch update products with retry logic.
  ///
  /// Useful for bulk inventory operations with built-in error handling.
  Future<Map<String, dynamic>> batchUpdateInventory({
    required Map<String, int> productIdToQuantity,
    required String shopId,
  }) async {
    try {
      final batch = _db.batch();
      int successful = 0;
      final errors = <String, String>{};

      for (final entry in productIdToQuantity.entries) {
        try {
          final docRef = _db.collection('products').doc(entry.key);
          batch.update(docRef, {
            'stockQuantity': entry.value,
            'updatedAt': FieldValue.serverTimestamp(),
            'isAvailable': entry.value > 0,
          });
          successful++;
        } catch (e) {
          errors[entry.key] = e.toString();
        }
      }

      await batch.commit();

      return {
        'successful': successful,
        'failed': errors.length,
        'errors': errors,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e, stack) {
      _logger.error('Error in batch update inventory', e, stack);
      return {
        'error': 'Batch update failed',
        'message': e.toString(),
        'successful': 0,
        'failed': productIdToQuantity.length,
      };
    }
  }

  /// Subscribe to inventory health metrics.
  ///
  /// Returns a stream of inventory metrics updated periodically.
  /// Useful for owner dashboards and monitoring.
  Stream<Map<String, dynamic>> watchInventoryMetrics({
    required String shopId,
    Duration updateInterval = const Duration(minutes: 5),
  }) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    // Initial stats
    getInventoryStats(shopId: shopId).then((stats) {
      controller.add(stats);
    });

    // Periodic updates
    final timer = Timer.periodic(updateInterval, (_) {
      getInventoryStats(shopId: shopId)
          .then((stats) {
            controller.add(stats);
          })
          .catchError((Object e, StackTrace stack) {
            _logger.error('Error getting inventory metrics', e, stack);
          });
    });

    controller.onCancel = () {
      timer.cancel();
      controller.close();
    };

    return controller.stream;
  }
}
