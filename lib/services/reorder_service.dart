import 'package:fufaji/models/inventory_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fufaji/utils/analytics_performance.dart';
import 'dart:developer' as developer;

/// Reorder management service
/// Handles reorder points, suggestions, and auto-reorder logic
class ReorderService {
  static final ReorderService _instance = ReorderService._internal();

  factory ReorderService() {
    return _instance;
  }

  ReorderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPrefix = 'inventory';

  // Get reorder point configuration for a product
  Future<Map<String, dynamic>?> getReorderPoint(String productId) async {
    try {
      developer.log('Fetching reorder point for product: $productId');

      final doc = await _firestore
          .collection('$_collectionPrefix/reorder_points')
          .where('product_id', isEqualTo: productId)
          .limit(1)
          .get();

      if (doc.docs.isEmpty) {
        return null;
      }

      return doc.docs.first.data();
    } catch (e) {
      developer.log('Error fetching reorder point: $e', error: e);
      rethrow;
    }
  }

  // Set reorder point for a product
  Future<void> setReorderPoint({
    required String productId,
    required int reorderPoint,
    required int reorderQuantity,
    required int leadTimeDays,
    String? preferredSupplierId,
    int? maxStockLevel,
    int? safetyStock,
    bool autoReorder = true,
  }) async {
    try {
      developer.log('Setting reorder point for product: $productId');

      if (reorderPoint <= 0 || reorderQuantity <= 0) {
        throw Exception('Reorder point and quantity must be positive');
      }

      final doc = await _firestore
          .collection('$_collectionPrefix/reorder_points')
          .where('product_id', isEqualTo: productId)
          .limit(1)
          .get();

      final data = {
        'product_id': productId,
        'reorder_point': reorderPoint,
        'reorder_quantity': reorderQuantity,
        'lead_time_days': leadTimeDays,
        'preferred_supplier_id': preferredSupplierId,
        'max_stock_level': maxStockLevel ?? (reorderPoint * 4),
        'safety_stock': safetyStock ?? (reorderPoint ~/ 2),
        'auto_reorder': autoReorder,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (doc.docs.isEmpty) {
        data['created_at'] = FieldValue.serverTimestamp();
        await _firestore
            .collection('$_collectionPrefix/reorder_points')
            .add(data);
      } else {
        await _firestore
            .collection('$_collectionPrefix/reorder_points')
            .doc(doc.docs.first.id)
            .update(data);
      }

      developer.log('Successfully set reorder point for product: $productId');
      _clearReorderCache();
    } catch (e) {
      developer.log('Error setting reorder point: $e', error: e);
      rethrow;
    }
  }

  // Calculate reorder suggestion for a product
  Future<ReorderSuggestion?> calculateReorderSuggestion(
    String productId,
    int currentStock,
    double unitCost,
    String productName,
  ) async {
    try {
      developer.log('Calculating reorder suggestion for product: $productId');

      final reorderConfig = await getReorderPoint(productId);
      if (reorderConfig == null) {
        developer.log('No reorder configuration found for product: $productId');
        return null;
      }

      final reorderPoint = reorderConfig['reorder_point'] as int;
      final reorderQuantity = reorderConfig['reorder_quantity'] as int;
      final leadTimeDays = reorderConfig['lead_time_days'] as int? ?? 2;
      final preferredSupplierId = reorderConfig['preferred_supplier_id'] as String?;
      final autoReorder = reorderConfig['auto_reorder'] as bool? ?? true;

      final needsReorder = currentStock <= reorderPoint;
      final estimatedCost = (reorderQuantity * unitCost).toDouble();

      return ReorderSuggestion(
        productId: productId,
        productName: productName,
        currentStock: currentStock,
        reorderPoint: reorderPoint,
        reorderQuantity: reorderQuantity,
        maxStockLevel: reorderConfig['max_stock_level'] as int? ?? (reorderPoint * 4),
        preferredSupplierId: preferredSupplierId,
        preferredSupplierName: null,
        leadTimeDays: leadTimeDays,
        estimatedCost: estimatedCost,
        autoReorder: autoReorder,
      );
    } catch (e) {
      developer.log('Error calculating reorder suggestion: $e', error: e);
      rethrow;
    }
  }

  // Get all reorder suggestions (cached)
  Future<List<ReorderSuggestion>> getReorderSuggestions() async {
    try {
      developer.log('Fetching all reorder suggestions');

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

      AnalyticsPerformance.setCachedValue('reorder_suggestions', suggestions, Duration(hours: 1));

      return suggestions;
    } catch (e) {
      developer.log('Error fetching reorder suggestions: $e', error: e);
      rethrow;
    }
  }

  // Stream reorder suggestions
  Stream<List<ReorderSuggestion>> streamReorderSuggestions() {
    developer.log('Streaming reorder suggestions');

    return _firestore
        .collection('$_collectionPrefix/reorder_suggestions')
        .where('needs_reorder', isEqualTo: true)
        .orderBy('current_stock', descending: false)
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

  // Trigger auto-reorder if conditions are met
  Future<bool> autoReorderIfNeeded(String productId) async {
    try {
      developer.log('Checking auto-reorder conditions for product: $productId');

      final reorderConfig = await getReorderPoint(productId);
      if (reorderConfig == null) {
        developer.log('No reorder configuration for product: $productId');
        return false;
      }

      final autoReorder = reorderConfig['auto_reorder'] as bool? ?? false;
      if (!autoReorder) {
        developer.log('Auto-reorder disabled for product: $productId');
        return false;
      }

      final stockDoc = await _firestore
          .collection('$_collectionPrefix/stock_levels/products')
          .doc(productId)
          .get();

      if (!stockDoc.exists) {
        developer.log('Stock level not found for product: $productId');
        return false;
      }

      final currentStock = stockDoc['available_quantity'] as int? ?? 0;
      final reorderPoint = reorderConfig['reorder_point'] as int;

      if (currentStock > reorderPoint) {
        developer.log('Stock level above reorder point for product: $productId');
        return false;
      }

      developer.log('Auto-reorder triggered for product: $productId');
      return true;
    } catch (e) {
      developer.log('Error checking auto-reorder conditions: $e', error: e);
      rethrow;
    }
  }

  // Get reorder analytics
  Future<Map<String, dynamic>> getReorderMetrics() async {
    try {
      developer.log('Fetching reorder metrics');

      final snapshot = await _firestore
          .collection('$_collectionPrefix/reorder_suggestions')
          .get();

      int totalSuggestions = 0;
      int needsReorder = 0;
      double totalEstimatedCost = 0;

      for (final doc in snapshot.docs) {
        totalSuggestions++;

        if (doc['needs_reorder'] as bool? ?? false) {
          needsReorder++;
        }

        totalEstimatedCost += doc['estimated_cost'] as num? ?? 0;
      }

      return {
        'total_suggestions': totalSuggestions,
        'needs_reorder': needsReorder,
        'sufficient_stock': totalSuggestions - needsReorder,
        'total_estimated_cost': totalEstimatedCost,
        'average_cost_per_order': needsReorder > 0 ? totalEstimatedCost / needsReorder : 0,
      };
    } catch (e) {
      developer.log('Error fetching reorder metrics: $e', error: e);
      rethrow;
    }
  }

  // Get products by urgency level
  Future<Map<String, List<String>>> getProductsByUrgency() async {
    try {
      developer.log('Fetching products by urgency level');

      final snapshot = await _firestore
          .collection('$_collectionPrefix/reorder_suggestions')
          .orderBy('current_stock', descending: false)
          .get();

      final critical = <String>[];
      final high = <String>[];
      final medium = <String>[];
      final low = <String>[];

      for (final doc in snapshot.docs) {
        final productId = doc.id;
        final currentStock = doc['current_stock'] as int? ?? 0;
        final reorderPoint = doc['reorder_point'] as int? ?? 10;

        if (currentStock == 0) {
          critical.add(productId);
        } else if (currentStock < reorderPoint) {
          high.add(productId);
        } else if (currentStock < (reorderPoint * 2)) {
          medium.add(productId);
        } else {
          low.add(productId);
        }
      }

      return {
        'critical': critical,
        'high': high,
        'medium': medium,
        'low': low,
      };
    } catch (e) {
      developer.log('Error fetching products by urgency: $e', error: e);
      rethrow;
    }
  }

  // Calculate optimal reorder quantity based on demand
  int calculateOptimalReorderQuantity(
    int dailyAverageDemand,
    int leadTimeDays,
    int safetyStock,
  ) {
    developer.log('Calculating optimal reorder quantity');

    const safetyFactor = 1.5;
    final reorderQuantity = (dailyAverageDemand * (leadTimeDays + safetyFactor)).toInt();

    return reorderQuantity.clamp(1, 999999);
  }

  void _clearReorderCache() {
    developer.log('Clearing reorder cache');
    AnalyticsPerformance.clearCacheKey('reorder_suggestions');
  }
}
