import 'package:fufajis_online/models/inventory_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fufajis_online/utils/analytics_performance.dart';
import 'dart:developer' as developer;

/// Expiry Management Service
/// Handles shelf life tracking, disposal, and expiry alerts
class ExpiryService {
  static final ExpiryService _instance = ExpiryService._internal();

  factory ExpiryService() {
    return _instance;
  }

  ExpiryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPrefix = 'inventory';

  // Track batch with expiry date
  Future<String> trackBatch({
    required String productId,
    required String productName,
    required String batchNumber,
    required DateTime manufactureDate,
    required DateTime expiryDate,
    required int quantityReceived,
    required String supplierId,
    required String poId,
    required String location,
    required String receivedBy,
  }) async {
    try {
      developer.log('Tracking batch: $batchNumber for product: $productId');

      if (expiryDate.isBefore(DateTime.now())) {
        throw Exception('Cannot track already expired batch');
      }

      final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
      final status = _calculateExpiryStatus(daysUntilExpiry);

      final docRef = await _firestore.collection('$_collectionPrefix/inventory_batches').add({
        'batch_number': batchNumber,
        'product_id': productId,
        'product_name': productName,
        'quantity_received': quantityReceived,
        'quantity_remaining': quantityReceived,
        'manufacture_date': Timestamp.fromDate(manufactureDate),
        'expiry_date': Timestamp.fromDate(expiryDate),
        'supplier_id': supplierId,
        'po_id': poId,
        'location': location,
        'received_by': receivedBy,
        'status': status,
        'days_until_expiry': daysUntilExpiry,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      developer.log('Successfully tracked batch: $batchNumber');
      _clearExpiryCache();

      // Create alert if expiring soon
      if (daysUntilExpiry < 30) {
        await _createExpiryAlert(productId, productName, batchNumber, expiryDate, quantityReceived, location, daysUntilExpiry);
      }

      return docRef.id;
    } catch (e) {
      developer.log('Error tracking batch: $e', error: e);
      rethrow;
    }
  }

  // Get batches by expiry status
  Future<List<ExpiryAlert>> getExpiryAlerts({int daysThreshold = 30}) async {
    try {
      developer.log('Fetching expiry alerts (threshold: $daysThreshold days)');

      final cached = AnalyticsPerformance.getCachedValue<List<ExpiryAlert>>('expiry_alerts');
      if (cached != null) {
        return cached;
      }

      final snapshot = await _firestore
          .collection('$_collectionPrefix/expiry_alerts')
          .where('days_until_expiry', isLessThan: daysThreshold)
          .orderBy('days_until_expiry', descending: false)
          .get();

      final alerts = snapshot.docs
          .map((doc) => ExpiryAlert.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      AnalyticsPerformance.setCachedValue('expiry_alerts', alerts, Duration(hours: 1));

      return alerts;
    } catch (e) {
      developer.log('Error fetching expiry alerts: $e', error: e);
      rethrow;
    }
  }

  // Stream real-time expiry alerts
  Stream<List<ExpiryAlert>> streamExpiryAlerts({int daysThreshold = 30}) {
    developer.log('Streaming expiry alerts');

    return _firestore
        .collection('$_collectionPrefix/expiry_alerts')
        .where('days_until_expiry', isLessThan: daysThreshold)
        .orderBy('days_until_expiry', descending: false)
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

  // Dispose batch (remove from inventory)
  Future<void> disposeBatch({
    required String batchId,
    required String disposalMethod,
    required String reason,
    required String disposedBy,
  }) async {
    try {
      developer.log('Disposing batch: $batchId via $disposalMethod');

      final validMethods = ['destroyed', 'donated', 'returned', 'sold_as_discount'];
      if (!validMethods.contains(disposalMethod)) {
        throw Exception('Invalid disposal method: $disposalMethod');
      }

      await _firestore.runTransaction((transaction) async {
        final batchRef = _firestore
            .collection('$_collectionPrefix/inventory_batches')
            .doc(batchId);

        final batchSnap = await transaction.get(batchRef);
        if (!batchSnap.exists) {
          throw Exception('Batch not found');
        }

        final batchData = batchSnap.data() as Map<String, dynamic>;
        final productId = batchData['product_id'] as String;
        final quantityRemaining = batchData['quantity_remaining'] as int;

        // Update batch status
        transaction.update(batchRef, {
          'status': 'disposed',
          'disposal_method': disposalMethod,
          'disposal_reason': reason,
          'disposed_by': disposedBy,
          'disposal_date': FieldValue.serverTimestamp(),
          'quantity_remaining': 0,
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Log disposal in movements
        final movementRef = _firestore
            .collection('$_collectionPrefix/inventory_movements')
            .doc();

        transaction.set(movementRef, {
          'product_id': productId,
          'movement_type': 'disposal',
          'quantity_change': -quantityRemaining,
          'reason': reason,
          'reference_id': batchId,
          'reference_type': 'batch_disposal',
          'notes': 'Method: $disposalMethod',
          'created_by': disposedBy,
          'created_at': FieldValue.serverTimestamp(),
        });

        // Remove from stock
        final stockRef = _firestore
            .collection('$_collectionPrefix/stock_levels/products')
            .doc(productId);

        final stockSnap = await transaction.get(stockRef);
        if (stockSnap.exists) {
          final stockData = stockSnap.data() as Map<String, dynamic>;
          final currentDamaged = stockData['damaged_quantity'] as int? ?? 0;

          transaction.update(stockRef, {
            'damaged_quantity': currentDamaged + quantityRemaining,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      });

      developer.log('Successfully disposed batch: $batchId');
      _clearExpiryCache();
    } catch (e) {
      developer.log('Error disposing batch: $e', error: e);
      rethrow;
    }
  }

  // Get batch details
  Future<Map<String, dynamic>?> getBatchDetails(String batchId) async {
    try {
      developer.log('Fetching batch details: $batchId');

      final doc = await _firestore
          .collection('$_collectionPrefix/inventory_batches')
          .doc(batchId)
          .get();

      if (!doc.exists) return null;

      return doc.data();
    } catch (e) {
      developer.log('Error fetching batch details: $e', error: e);
      rethrow;
    }
  }

  // Get all batches for a product
  Future<List<Map<String, dynamic>>> getBatchesByProduct(String productId) async {
    try {
      developer.log('Fetching batches for product: $productId');

      final snapshot = await _firestore
          .collection('$_collectionPrefix/inventory_batches')
          .where('product_id', isEqualTo: productId)
          .orderBy('expiry_date', descending: false)
          .get();

      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      developer.log('Error fetching product batches: $e', error: e);
      rethrow;
    }
  }

  // Calculate days until expiry and update status
  Future<void> updateExpiryStatus(String batchId) async {
    try {
      developer.log('Updating expiry status for batch: $batchId');

      final batchRef = _firestore
          .collection('$_collectionPrefix/inventory_batches')
          .doc(batchId);

      final snapshot = await batchRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final expiryDate = (data['expiry_date'] as Timestamp).toDate();
      final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
      final status = _calculateExpiryStatus(daysUntilExpiry);

      await batchRef.update({
        'days_until_expiry': daysUntilExpiry,
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      });

      developer.log('Successfully updated expiry status');
    } catch (e) {
      developer.log('Error updating expiry status: $e', error: e);
      rethrow;
    }
  }

  // Get expiry metrics
  Future<Map<String, dynamic>> getExpiryMetrics() async {
    try {
      developer.log('Fetching expiry metrics');

      final snapshot = await _firestore
          .collection('$_collectionPrefix/inventory_batches')
          .where('status', whereIn: ['fresh', 'expiring', 'expired'])
          .get();

      int fresh = 0;
      int expiring = 0;
      int expired = 0;
      double totalValue = 0;

      for (final doc in snapshot.docs) {
        final status = doc['status'] as String?;
        final quantity = doc['quantity_remaining'] as int? ?? 0;

        switch (status) {
          case 'fresh':
            fresh += quantity;
          case 'expiring':
            expiring += quantity;
          case 'expired':
            expired += quantity;
        }

        totalValue += quantity * (doc['estimated_unit_cost'] as num? ?? 0);
      }

      return {
        'total_batches': snapshot.docs.length,
        'fresh_quantity': fresh,
        'expiring_quantity': expiring,
        'expired_quantity': expired,
        'total_at_risk_value': totalValue,
        'expiry_loss_percentage': snapshot.docs.isNotEmpty ? (expired / (fresh + expiring + expired) * 100) : 0,
      };
    } catch (e) {
      developer.log('Error fetching expiry metrics: $e', error: e);
      rethrow;
    }
  }

  // Create expiry alert
  Future<void> _createExpiryAlert(
    String productId,
    String productName,
    String batchNumber,
    DateTime expiryDate,
    int quantityRemaining,
    String location,
    int daysUntilExpiry,
  ) async {
    try {
      await _firestore.collection('$_collectionPrefix/expiry_alerts').add({
        'product_id': productId,
        'product_name': productName,
        'batch_number': batchNumber,
        'expiry_date': Timestamp.fromDate(expiryDate),
        'quantity_remaining': quantityRemaining,
        'location': location,
        'status': _calculateExpiryStatus(daysUntilExpiry),
        'days_until_expiry': daysUntilExpiry,
        'urgency': _calculateUrgency(daysUntilExpiry),
        'created_at': FieldValue.serverTimestamp(),
      });

      developer.log('Created expiry alert for batch: $batchNumber');
    } catch (e) {
      developer.log('Error creating expiry alert: $e', error: e);
    }
  }

  // Helper: Calculate expiry status
  String _calculateExpiryStatus(int daysUntilExpiry) {
    if (daysUntilExpiry < 0) return 'expired';
    if (daysUntilExpiry < 7) return 'expiring';
    return 'fresh';
  }

  // Helper: Calculate urgency level
  String _calculateUrgency(int daysUntilExpiry) {
    if (daysUntilExpiry < 0) return 'expired';
    if (daysUntilExpiry < 3) return 'critical';
    if (daysUntilExpiry < 7) return 'urgent';
    if (daysUntilExpiry < 30) return 'caution';
    return 'watch';
  }

  void _clearExpiryCache() {
    developer.log('Clearing expiry cache');
    AnalyticsPerformance.clearCacheKey('expiry_alerts');
    AnalyticsPerformance.clearCacheKey('expiry_metrics');
  }
}
