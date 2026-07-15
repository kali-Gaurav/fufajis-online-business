import 'package:fufajis_online/models/inventory_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fufajis_online/utils/analytics_performance.dart';
import 'dart:developer' as developer;

/// Stock adjustment and correction service
/// Handles manual inventory adjustments with approval workflow
class StockAdjustmentService {
  static final StockAdjustmentService _instance = StockAdjustmentService._internal();

  factory StockAdjustmentService() {
    return _instance;
  }

  StockAdjustmentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPrefix = 'inventory';

  // Create a stock adjustment request
  Future<String> adjustStock({
    required String productId,
    required String productName,
    required String adjustmentType,
    required int quantity,
    required String reason,
    required String? batchNumber,
    required String createdBy,
  }) async {
    try {
      developer.log('Creating stock adjustment: $productId ($adjustmentType) qty: $quantity');

      if (quantity <= 0) {
        throw Exception('Adjustment quantity must be positive');
      }

      final validTypes = ['damage', 'loss', 'recount_correction', 'theft', 'expiry'];
      if (!validTypes.contains(adjustmentType)) {
        throw Exception('Invalid adjustment type: $adjustmentType');
      }

      final docRef = await _firestore.collection('$_collectionPrefix/stock_adjustments').add({
        'product_id': productId,
        'product_name': productName,
        'adjustment_type': adjustmentType,
        'quantity': quantity,
        'reason': reason,
        'batch_number': batchNumber,
        'status': 'pending',
        'created_by': createdBy,
        'created_at': FieldValue.serverTimestamp(),
        'approved_by': null,
        'approved_at': null,
        'rejection_reason': null,
        'notes': '',
      });

      developer.log('Stock adjustment created: ${docRef.id}');
      _clearAdjustmentCache();

      return docRef.id;
    } catch (e) {
      developer.log('Error creating stock adjustment: $e', error: e);
      rethrow;
    }
  }

  // Get all stock adjustments with optional status filter
  Future<List<Map<String, dynamic>>> getStockAdjustments({String? status}) async {
    try {
      developer.log('Fetching stock adjustments (status: $status)');

      final cacheKey = 'stock_adjustments_${status ?? "all"}';
      final cached = AnalyticsPerformance.getCachedValue<List<Map<String, dynamic>>>(cacheKey);
      if (cached != null) {
        developer.log('Cache hit for $cacheKey');
        return cached;
      }

      var query = _firestore.collection('$_collectionPrefix/stock_adjustments') as Query<Map<String, dynamic>>;

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.orderBy('created_at', descending: true).get();

      final adjustments = snapshot.docs.map((doc) {
        final data = doc.data();
        return {...data, 'id': doc.id};
      }).toList();

      AnalyticsPerformance.setCachedValue(cacheKey, adjustments, Duration(minutes: 30));

      return adjustments;
    } catch (e) {
      developer.log('Error fetching stock adjustments: $e', error: e);
      rethrow;
    }
  }

  // Stream real-time adjustments
  Stream<List<Map<String, dynamic>>> streamStockAdjustments({String? status}) {
    developer.log('Starting stream for stock adjustments (status: $status)');

    var query = _firestore.collection('$_collectionPrefix/stock_adjustments') as Query<Map<String, dynamic>>;

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {...data, 'id': doc.id};
          }).toList();
        })
        .handleError((e) {
          developer.log('Stream error for stock adjustments: $e', error: e);
        });
  }

  // Get pending adjustments for approval
  Future<List<Map<String, dynamic>>> getPendingAdjustments() async {
    try {
      developer.log('Fetching pending stock adjustments');

      const cacheKey = 'pending_adjustments';
      final cached = AnalyticsPerformance.getCachedValue<List<Map<String, dynamic>>>(cacheKey);
      if (cached != null) {
        return cached;
      }

      final snapshot = await _firestore
          .collection('$_collectionPrefix/stock_adjustments')
          .where('status', isEqualTo: 'pending')
          .orderBy('created_at', descending: true)
          .get();

      final adjustments = snapshot.docs.map((doc) {
        final data = doc.data();
        return {...data, 'id': doc.id};
      }).toList();

      AnalyticsPerformance.setCachedValue(cacheKey, adjustments, Duration(minutes: 15));

      return adjustments;
    } catch (e) {
      developer.log('Error fetching pending adjustments: $e', error: e);
      rethrow;
    }
  }

  // Approve a stock adjustment (transaction-safe)
  Future<void> approveAdjustment({
    required String adjustmentId,
    required String productId,
    required int quantity,
    required String adjustmentType,
    required String approvedBy,
    required String notes,
  }) async {
    try {
      developer.log('Approving stock adjustment: $adjustmentId');

      final adjustmentRef = _firestore.collection('$_collectionPrefix/stock_adjustments').doc(adjustmentId);
      final stockRef = _firestore.collection('$_collectionPrefix/stock_levels/products').doc(productId);
      final movementRef = _firestore.collection('$_collectionPrefix/inventory_movements').doc();

      await _firestore.runTransaction((transaction) async {
        final adjustmentDoc = await transaction.get(adjustmentRef);
        if (!adjustmentDoc.exists) {
          throw Exception('Adjustment not found');
        }

        final status = adjustmentDoc['status'];
        if (status != 'pending') {
          throw Exception('Can only approve pending adjustments');
        }

        final stockDoc = await transaction.get(stockRef);
        if (!stockDoc.exists) {
          throw Exception('Stock level not found for product');
        }

        // Update adjustment status
        transaction.update(adjustmentRef, {
          'status': 'approved',
          'approved_by': approvedBy,
          'approved_at': FieldValue.serverTimestamp(),
          'notes': notes,
        });

        // Update stock levels based on adjustment type
        final currentStock = (stockDoc['available_quantity'] ?? 0) as int;
        final currentDamaged = (stockDoc['damaged_quantity'] ?? 0) as int;

        int newAvailable = currentStock;
        int newDamaged = currentDamaged;

        if (adjustmentType == 'damage') {
          newAvailable = (currentStock - quantity).clamp(0, currentStock);
          newDamaged = currentDamaged + quantity;
        } else {
          // loss, theft, recount_correction, expiry
          newAvailable = (currentStock - quantity).clamp(0, currentStock);
        }

        transaction.update(stockRef, {
          'available_quantity': newAvailable,
          'damaged_quantity': newDamaged,
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Create movement log
        transaction.set(movementRef, {
          'product_id': productId,
          'movement_type': 'adjustment',
          'quantity_change': -quantity,
          'reason': adjustmentType,
          'reference_id': adjustmentId,
          'reference_type': 'stock_adjustment',
          'created_by': approvedBy,
          'created_at': FieldValue.serverTimestamp(),
        });
      });

      developer.log('Stock adjustment approved: $adjustmentId');
      _clearAdjustmentCache();
    } catch (e) {
      developer.log('Error approving stock adjustment: $e', error: e);
      rethrow;
    }
  }

  // Reject a stock adjustment
  Future<void> rejectAdjustment({
    required String adjustmentId,
    required String rejectionReason,
    required String rejectedBy,
  }) async {
    try {
      developer.log('Rejecting stock adjustment: $adjustmentId');

      await _firestore.collection('$_collectionPrefix/stock_adjustments').doc(adjustmentId).update({
        'status': 'rejected',
        'rejection_reason': rejectionReason,
        'approved_by': rejectedBy,
        'approved_at': FieldValue.serverTimestamp(),
      });

      developer.log('Stock adjustment rejected: $adjustmentId');
      _clearAdjustmentCache();
    } catch (e) {
      developer.log('Error rejecting stock adjustment: $e', error: e);
      rethrow;
    }
  }

  // Get adjustment by ID
  Future<Map<String, dynamic>?> getAdjustment(String adjustmentId) async {
    try {
      developer.log('Fetching stock adjustment: $adjustmentId');

      final doc = await _firestore
          .collection('$_collectionPrefix/stock_adjustments')
          .doc(adjustmentId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return {...doc.data()!, 'id': doc.id};
    } catch (e) {
      developer.log('Error fetching adjustment: $e', error: e);
      rethrow;
    }
  }

  // Get adjustments for a specific product
  Future<List<Map<String, dynamic>>> getAdjustmentsByProduct(String productId) async {
    try {
      developer.log('Fetching adjustments for product: $productId');

      final snapshot = await _firestore
          .collection('$_collectionPrefix/stock_adjustments')
          .where('product_id', isEqualTo: productId)
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {...data, 'id': doc.id};
      }).toList();
    } catch (e) {
      developer.log('Error fetching product adjustments: $e', error: e);
      rethrow;
    }
  }

  // Get adjustment statistics
  Future<Map<String, dynamic>> getAdjustmentStats() async {
    try {
      developer.log('Calculating adjustment statistics');

      final snapshot = await _firestore
          .collection('$_collectionPrefix/stock_adjustments')
          .get();

      int pending = 0;
      int approved = 0;
      int rejected = 0;
      int totalQuantity = 0;

      for (final doc in snapshot.docs) {
        final status = doc['status'] as String?;
        final quantity = doc['quantity'] as int? ?? 0;

        if (status == 'pending') pending++;
        if (status == 'approved') {
          approved++;
          totalQuantity += quantity;
        }
        if (status == 'rejected') rejected++;
      }

      return {
        'pending_count': pending,
        'approved_count': approved,
        'rejected_count': rejected,
        'total_quantity_adjusted': totalQuantity,
        'approval_rate': approved > 0 ? (approved / (approved + rejected) * 100).toStringAsFixed(1) : '0',
      };
    } catch (e) {
      developer.log('Error calculating adjustment stats: $e', error: e);
      rethrow;
    }
  }

  // Clear adjustment cache
  void _clearAdjustmentCache() {
    developer.log('Clearing adjustment cache');
    AnalyticsPerformance.clearCacheKey('stock_adjustments_pending');
    AnalyticsPerformance.clearCacheKey('stock_adjustments_approved');
    AnalyticsPerformance.clearCacheKey('stock_adjustments_rejected');
    AnalyticsPerformance.clearCacheKey('stock_adjustments_all');
    AnalyticsPerformance.clearCacheKey('pending_adjustments');
  }
}
