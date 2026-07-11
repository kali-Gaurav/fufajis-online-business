import 'package:fufaji/models/inventory_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fufaji/utils/analytics_performance.dart';
import 'dart:developer' as developer;

/// Core inventory management service
/// Source of truth: PostgreSQL via Supabase
/// Real-time cache: Firestore
class InventoryService {
  static final InventoryService _instance = InventoryService._internal();

  factory InventoryService() {
    return _instance;
  }

  InventoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPrefix = 'inventory';

  // Get current stock level for a product
  Future<StockLevel?> getStockLevel(String productId) async {
    try {
      developer.log('Fetching stock level for product: $productId');

      final cached = AnalyticsPerformance.getCachedValue<StockLevel>('stock_$productId');
      if (cached != null) {
        developer.log('Cache hit for stock_$productId');
        return cached;
      }

      final doc = await _firestore
          .collection('$_collectionPrefix/stock_levels/products')
          .doc(productId)
          .get();

      if (!doc.exists) {
        developer.log('Stock level not found for product: $productId');
        return null;
      }

      final stock = StockLevel.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id});
      AnalyticsPerformance.setCachedValue('stock_$productId', stock, Duration(minutes: 2));

      return stock;
    } catch (e) {
      developer.log('Error fetching stock level: $e', error: e);
      rethrow;
    }
  }

  // Get stock levels for multiple products
  Future<List<StockLevel>> getStockLevels(List<String> productIds) async {
    try {
      developer.log('Fetching stock levels for ${productIds.length} products');

      final snapshot = await _firestore
          .collection('$_collectionPrefix/stock_levels/products')
          .where(FieldPath.documentId, whereIn: productIds)
          .get();

      final levels = snapshot.docs
          .map((doc) => StockLevel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      return levels;
    } catch (e) {
      developer.log('Error fetching multiple stock levels: $e', error: e);
      rethrow;
    }
  }

  // Stream real-time stock level changes
  Stream<StockLevel?> streamStockLevel(String productId) {
    developer.log('Starting stream for stock level: $productId');

    return _firestore
        .collection('$_collectionPrefix/stock_levels/products')
        .doc(productId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return StockLevel.fromJson({...snapshot.data()!, 'id': snapshot.id});
        })
        .handleError((e) {
          developer.log('Stream error for stock level: $e', error: e);
        });
  }

  // Reserve stock for an order
  Future<bool> reserveStock(String productId, int quantity) async {
    try {
      developer.log('Reserving $quantity units of product $productId');

      final stockRef = _firestore
          .collection('$_collectionPrefix/stock_levels/products')
          .doc(productId);

      final result = await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(stockRef);

        if (!snapshot.exists) {
          throw Exception('Product stock not found');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final available = data['available_quantity'] as int? ?? 0;
        final reserved = data['reserved_quantity'] as int? ?? 0;

        if (available < quantity) {
          throw Exception('Insufficient stock available');
        }

        transaction.update(stockRef, {
          'available_quantity': available - quantity,
          'reserved_quantity': reserved + quantity,
          'updated_at': FieldValue.serverTimestamp(),
        });

        return true;
      });

      developer.log('Successfully reserved stock for product $productId');
      _clearStockCache(productId);
      return result;
    } catch (e) {
      developer.log('Error reserving stock: $e', error: e);
      rethrow;
    }
  }

  // Release reserved stock (e.g., order cancelled)
  Future<void> releaseReservation(String productId, int quantity) async {
    try {
      developer.log('Releasing $quantity units of product $productId');

      final stockRef = _firestore
          .collection('$_collectionPrefix/stock_levels/products')
          .doc(productId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(stockRef);

        if (!snapshot.exists) {
          throw Exception('Product stock not found');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final available = data['available_quantity'] as int? ?? 0;
        final reserved = data['reserved_quantity'] as int? ?? 0;

        transaction.update(stockRef, {
          'available_quantity': available + quantity,
          'reserved_quantity': (reserved - quantity).clamp(0, reserved),
          'updated_at': FieldValue.serverTimestamp(),
        });
      });

      developer.log('Successfully released reservation for product $productId');
      _clearStockCache(productId);
    } catch (e) {
      developer.log('Error releasing reservation: $e', error: e);
      rethrow;
    }
  }

  // Confirm stock sale (reserved -> sold)
  Future<void> confirmStockSale(String productId, int quantity) async {
    try {
      developer.log('Confirming sale of $quantity units of product $productId');

      final stockRef = _firestore
          .collection('$_collectionPrefix/stock_levels/products')
          .doc(productId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(stockRef);

        if (!snapshot.exists) {
          throw Exception('Product stock not found');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final reserved = data['reserved_quantity'] as int? ?? 0;

        if (reserved < quantity) {
          throw Exception('Insufficient reserved stock');
        }

        transaction.update(stockRef, {
          'reserved_quantity': reserved - quantity,
          'updated_at': FieldValue.serverTimestamp(),
        });
      });

      developer.log('Successfully confirmed stock sale for product $productId');
      _clearStockCache(productId);
    } catch (e) {
      developer.log('Error confirming stock sale: $e', error: e);
      rethrow;
    }
  }

  // Get stock movement history
  Future<List<StockMovement>> getMovementHistory(String productId, {int limit = 50}) async {
    try {
      developer.log('Fetching movement history for product $productId (limit: $limit)');

      final snapshot = await _firestore
          .collection('$_collectionPrefix/movements')
          .where('product_id', isEqualTo: productId)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      final movements = snapshot.docs
          .map((doc) => StockMovement.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      return movements;
    } catch (e) {
      developer.log('Error fetching movement history: $e', error: e);
      rethrow;
    }
  }

  // Stream reorder suggestions
  Stream<List<ReorderSuggestion>> streamReorderSuggestions() {
    developer.log('Starting stream for reorder suggestions');

    return _firestore
        .collection('$_collectionPrefix/reorder_suggestions')
        .where('needs_reorder', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ReorderSuggestion.fromJson({...doc.data(), 'id': doc.id}))
              .toList();
        })
        .handleError((e) {
          developer.log('Stream error for reorder suggestions: $e', error: e);
        });
  }

  // Get reorder suggestions
  Future<List<ReorderSuggestion>> getReorderSuggestions() async {
    try {
      developer.log('Fetching reorder suggestions');

      final cached = AnalyticsPerformance.getCachedValue<List<ReorderSuggestion>>('reorder_suggestions');
      if (cached != null) {
        developer.log('Cache hit for reorder suggestions');
        return cached;
      }

      final snapshot = await _firestore
          .collection('$_collectionPrefix/reorder_suggestions')
          .where('needs_reorder', isEqualTo: true)
          .orderBy('current_stock', descending: false)
          .get();

      final suggestions = snapshot.docs
          .map((doc) => ReorderSuggestion.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      AnalyticsPerformance.setCachedValue(
        'reorder_suggestions',
        suggestions,
        Duration(hours: 1),
      );

      return suggestions;
    } catch (e) {
      developer.log('Error fetching reorder suggestions: $e', error: e);
      rethrow;
    }
  }

  // Get expiry alerts
  Future<List<ExpiryAlert>> getExpiryAlerts({int daysThreshold = 30}) async {
    try {
      developer.log('Fetching expiry alerts (threshold: $daysThreshold days)');

      final snapshot = await _firestore
          .collection('$_collectionPrefix/expiry_alerts')
          .where('days_until_expiry', isLessThan: daysThreshold)
          .orderBy('days_until_expiry', descending: false)
          .get();

      final alerts = snapshot.docs
          .map((doc) => ExpiryAlert.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      return alerts;
    } catch (e) {
      developer.log('Error fetching expiry alerts: $e', error: e);
      rethrow;
    }
  }

  // Stream expiry alerts (real-time)
  Stream<List<ExpiryAlert>> streamExpiryAlerts({int daysThreshold = 30}) {
    developer.log('Starting stream for expiry alerts');

    return _firestore
        .collection('$_collectionPrefix/expiry_alerts')
        .where('days_until_expiry', isLessThan: daysThreshold)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ExpiryAlert.fromJson({...doc.data(), 'id': doc.id}))
              .toList();
        })
        .handleError((e) {
          developer.log('Stream error for expiry alerts: $e', error: e);
        });
  }

  // Get inventory metrics
  Future<InventoryMetrics?> getInventoryMetrics() async {
    try {
      developer.log('Fetching inventory metrics');

      final cached = AnalyticsPerformance.getCachedValue<InventoryMetrics>('inventory_metrics');
      if (cached != null) {
        developer.log('Cache hit for inventory metrics');
        return cached;
      }

      final doc = await _firestore
          .collection('$_collectionPrefix/metrics')
          .doc('current')
          .get();

      if (!doc.exists) {
        developer.log('Inventory metrics not found');
        return null;
      }

      final metrics = InventoryMetrics.fromJson({...doc.data() as Map<String, dynamic>});
      AnalyticsPerformance.setCachedValue('inventory_metrics', metrics, Duration(minutes: 5));

      return metrics;
    } catch (e) {
      developer.log('Error fetching inventory metrics: $e', error: e);
      rethrow;
    }
  }

  // Stream inventory metrics (real-time)
  Stream<InventoryMetrics?> streamInventoryMetrics() {
    developer.log('Starting stream for inventory metrics');

    return _firestore
        .collection('$_collectionPrefix/metrics')
        .doc('current')
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return InventoryMetrics.fromJson({...snapshot.data()!});
        })
        .handleError((e) {
          developer.log('Stream error for inventory metrics: $e', error: e);
        });
  }

  // Get low stock items
  Future<List<StockLevel>> getLowStockItems() async {
    try {
      developer.log('Fetching low stock items');

      final snapshot = await _firestore
          .collection('$_collectionPrefix/stock_levels/products')
          .where('available_quantity', isLessThan: 10)
          .orderBy('available_quantity', descending: false)
          .get();

      final items = snapshot.docs
          .map((doc) => StockLevel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      return items;
    } catch (e) {
      developer.log('Error fetching low stock items: $e', error: e);
      rethrow;
    }
  }

  // Get suppliers
  Future<List<Supplier>> getSuppliers() async {
    try {
      developer.log('Fetching suppliers');

      final cached = AnalyticsPerformance.getCachedValue<List<Supplier>>('suppliers');
      if (cached != null) {
        developer.log('Cache hit for suppliers');
        return cached;
      }

      final snapshot = await _firestore
          .collection('$_collectionPrefix/suppliers')
          .where('active', isEqualTo: true)
          .orderBy('rating', descending: true)
          .get();

      final suppliers = snapshot.docs
          .map((doc) => Supplier.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      AnalyticsPerformance.setCachedValue('suppliers', suppliers, Duration(hours: 4));

      return suppliers;
    } catch (e) {
      developer.log('Error fetching suppliers: $e', error: e);
      rethrow;
    }
  }

  // Get purchase orders
  Future<List<PurchaseOrder>> getPurchaseOrders({String? status}) async {
    try {
      developer.log('Fetching purchase orders' + (status != null ? ' (status: $status)' : ''));

      var query = _firestore.collection('$_collectionPrefix/purchase_orders').orderBy('created_at', descending: true);

      if (status != null) {
        query = query.where('status', isEqualTo: status) as Query<Map<String, dynamic>>;
      }

      final snapshot = await query.get();

      final orders = snapshot.docs
          .map((doc) => PurchaseOrder.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      return orders;
    } catch (e) {
      developer.log('Error fetching purchase orders: $e', error: e);
      rethrow;
    }
  }

  // Get a single purchase order with items
  Future<PurchaseOrder?> getPurchaseOrder(String poId) async {
    try {
      developer.log('Fetching purchase order: $poId');

      final doc = await _firestore
          .collection('$_collectionPrefix/purchase_orders')
          .doc(poId)
          .get();

      if (!doc.exists) return null;

      return PurchaseOrder.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      developer.log('Error fetching purchase order: $e', error: e);
      rethrow;
    }
  }

  // Health check - verify Firestore and cache connectivity
  Future<bool> healthCheck() async {
    try {
      developer.log('Running inventory service health check');

      await _firestore.collection('$_collectionPrefix/health').doc('check').get();
      return true;
    } catch (e) {
      developer.log('Health check failed: $e', error: e);
      return false;
    }
  }

  // Clear stock cache for a product
  void _clearStockCache(String productId) {
    AnalyticsPerformance.clearCacheKey('stock_$productId');
  }

  // Clear all inventory caches
  void clearAllCaches() {
    developer.log('Clearing all inventory caches');
    AnalyticsPerformance.clearCacheKey('inventory_metrics');
    AnalyticsPerformance.clearCacheKey('reorder_suggestions');
    AnalyticsPerformance.clearCacheKey('suppliers');
  }
}
