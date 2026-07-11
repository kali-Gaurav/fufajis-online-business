import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fufaji/utils/analytics_performance.dart';
import 'dart:developer' as developer;

/// Warehouse Management Service
/// Handles bin locations, stock placement, and warehouse operations
class WarehouseService {
  static final WarehouseService _instance = WarehouseService._internal();

  factory WarehouseService() {
    return _instance;
  }

  WarehouseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPrefix = 'inventory';

  // Create warehouse zone
  Future<String> createWarehouse({
    required String warehouseName,
    required String zone,
    required int? temperature,
    required int? humidity,
    required int totalBins,
  }) async {
    try {
      developer.log('Creating warehouse zone: $zone in $warehouseName');

      final docRef = await _firestore
          .collection('$_collectionPrefix/warehouses')
          .add({
            'warehouse_name': warehouseName,
            'zone': zone,
            'temperature': temperature,
            'humidity': humidity,
            'total_bins': totalBins,
            'used_bins': 0,
            'capacity_units': totalBins * 100,
            'active': true,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });

      developer.log('Successfully created warehouse: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      developer.log('Error creating warehouse: $e', error: e);
      rethrow;
    }
  }

  // Place item in bin
  Future<String> placeBinLocation({
    required String warehouseId,
    required String binId,
    required String productId,
    required int quantity,
    required String batchNumber,
    required DateTime? expiryDate,
  }) async {
    try {
      developer.log('Placing item in bin: $binId');

      if (quantity <= 0) {
        throw Exception('Quantity must be positive');
      }

      // Check if bin already exists
      final existingBin = await _firestore
          .collection('$_collectionPrefix/warehouse_locations')
          .where('bin_id', isEqualTo: binId)
          .where('warehouse_id', isEqualTo: warehouseId)
          .limit(1)
          .get();

      if (existingBin.docs.isNotEmpty) {
        throw Exception('Bin $binId already occupied');
      }

      final docRef = await _firestore
          .collection('$_collectionPrefix/warehouse_locations')
          .add({
            'warehouse_id': warehouseId,
            'bin_id': binId,
            'product_id': productId,
            'quantity': quantity,
            'batch_number': batchNumber,
            'expiry_date': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
            'placed_at': FieldValue.serverTimestamp(),
            'last_counted_at': FieldValue.serverTimestamp(),
            'status': 'active',
            'updated_at': FieldValue.serverTimestamp(),
          });

      developer.log('Successfully placed item in bin: $binId');
      _clearWarehouseCache();

      return docRef.id;
    } catch (e) {
      developer.log('Error placing item in bin: $e', error: e);
      rethrow;
    }
  }

  // Get bin details
  Future<Map<String, dynamic>?> getBinDetails(String binId) async {
    try {
      developer.log('Fetching bin details: $binId');

      final snapshot = await _firestore
          .collection('$_collectionPrefix/warehouse_locations')
          .where('bin_id', isEqualTo: binId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return snapshot.docs.first.data();
    } catch (e) {
      developer.log('Error fetching bin details: $e', error: e);
      rethrow;
    }
  }

  // Remove item from bin (pick/pick complete)
  Future<void> removeBinLocation(String binLocationId, int quantityPicked) async {
    try {
      developer.log('Removing item from bin location: $binLocationId');

      await _firestore.runTransaction((transaction) async {
        final binRef = _firestore
            .collection('$_collectionPrefix/warehouse_locations')
            .doc(binLocationId);

        final snapshot = await transaction.get(binRef);
        if (!snapshot.exists) {
          throw Exception('Bin location not found');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final quantity = data['quantity'] as int;

        if (quantityPicked > quantity) {
          throw Exception('Cannot pick more than available quantity');
        }

        if (quantityPicked == quantity) {
          // Remove bin completely if all picked
          transaction.delete(binRef);
        } else {
          // Update remaining quantity
          transaction.update(binRef, {
            'quantity': quantity - quantityPicked,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      });

      developer.log('Successfully removed item from bin');
      _clearWarehouseCache();
    } catch (e) {
      developer.log('Error removing item from bin: $e', error: e);
      rethrow;
    }
  }

  // Get warehouse utilization
  Future<Map<String, dynamic>> getWarehouseUtilization(String warehouseId) async {
    try {
      developer.log('Calculating warehouse utilization: $warehouseId');

      final warehouseSnap = await _firestore
          .collection('$_collectionPrefix/warehouses')
          .doc(warehouseId)
          .get();

      if (!warehouseSnap.exists) {
        throw Exception('Warehouse not found');
      }

      final warehouseData = warehouseSnap.data() as Map<String, dynamic>;
      final totalBins = warehouseData['total_bins'] as int;
      final capacityUnits = warehouseData['capacity_units'] as int;

      final binsSnapshot = await _firestore
          .collection('$_collectionPrefix/warehouse_locations')
          .where('warehouse_id', isEqualTo: warehouseId)
          .where('status', isEqualTo: 'active')
          .get();

      int usedBins = binsSnapshot.docs.length;
      int totalQuantity = 0;

      for (final doc in binsSnapshot.docs) {
        totalQuantity += doc['quantity'] as int? ?? 0;
      }

      return {
        'warehouse_id': warehouseId,
        'total_bins': totalBins,
        'used_bins': usedBins,
        'available_bins': totalBins - usedBins,
        'bin_utilization_percentage': (usedBins / totalBins * 100).toStringAsFixed(1),
        'capacity_units': capacityUnits,
        'stored_units': totalQuantity,
        'capacity_utilization_percentage': (totalQuantity / capacityUnits * 100).toStringAsFixed(1),
      };
    } catch (e) {
      developer.log('Error calculating warehouse utilization: $e', error: e);
      rethrow;
    }
  }

  // Get all bins in warehouse
  Future<List<Map<String, dynamic>>> getWarehouseBins(String warehouseId) async {
    try {
      developer.log('Fetching bins for warehouse: $warehouseId');

      final cached = AnalyticsPerformance.getCachedValue<List<Map<String, dynamic>>>('warehouse_bins_$warehouseId');
      if (cached != null) {
        return cached;
      }

      final snapshot = await _firestore
          .collection('$_collectionPrefix/warehouse_locations')
          .where('warehouse_id', isEqualTo: warehouseId)
          .where('status', isEqualTo: 'active')
          .orderBy('bin_id', descending: false)
          .get();

      final bins = snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();

      AnalyticsPerformance.setCachedValue('warehouse_bins_$warehouseId', bins, Duration(hours: 2));

      return bins;
    } catch (e) {
      developer.log('Error fetching warehouse bins: $e', error: e);
      rethrow;
    }
  }

  // Stock count verification
  Future<Map<String, dynamic>> performStockCount(String warehouseId, String countedBy) async {
    try {
      developer.log('Performing stock count for warehouse: $warehouseId');

      final binsSnapshot = await _firestore
          .collection('$_collectionPrefix/warehouse_locations')
          .where('warehouse_id', isEqualTo: warehouseId)
          .where('status', isEqualTo: 'active')
          .get();

      int discrepancies = 0;
      double discrepancyValue = 0;

      final batch = _firestore.batch();

      for (final binDoc in binsSnapshot.docs) {
        batch.update(binDoc.reference, {
          'last_counted_at': FieldValue.serverTimestamp(),
          'counted_by': countedBy,
        });
      }

      await batch.commit();

      return {
        'warehouse_id': warehouseId,
        'bins_counted': binsSnapshot.docs.length,
        'discrepancies_found': discrepancies,
        'discrepancy_value': discrepancyValue,
        'count_completed_at': DateTime.now().toIso8601String(),
        'count_completed_by': countedBy,
      };
    } catch (e) {
      developer.log('Error performing stock count: $e', error: e);
      rethrow;
    }
  }

  // Move item between bins
  Future<void> moveBinItem(
    String fromBinId,
    String toBinId,
    String warehouseId,
    int quantity,
    String movedBy,
  ) async {
    try {
      developer.log('Moving $quantity units from $fromBinId to $toBinId');

      await _firestore.runTransaction((transaction) async {
        // Get from bin
        final fromSnapshot = await _firestore
            .collection('$_collectionPrefix/warehouse_locations')
            .where('bin_id', isEqualTo: fromBinId)
            .where('warehouse_id', isEqualTo: warehouseId)
            .limit(1)
            .get();

        if (fromSnapshot.docs.isEmpty) {
          throw Exception('Source bin not found');
        }

        // Get to bin
        final toSnapshot = await _firestore
            .collection('$_collectionPrefix/warehouse_locations')
            .where('bin_id', isEqualTo: toBinId)
            .where('warehouse_id', isEqualTo: warehouseId)
            .limit(1)
            .get();

        if (toSnapshot.docs.isEmpty) {
          throw Exception('Destination bin not found');
        }

        final fromData = fromSnapshot.docs.first.data();
        final toData = toSnapshot.docs.first.data();
        final fromQuantity = fromData['quantity'] as int;
        final toQuantity = toData['quantity'] as int;

        if (fromQuantity < quantity) {
          throw Exception('Insufficient quantity in source bin');
        }

        // Update from bin
        if (fromQuantity == quantity) {
          transaction.delete(fromSnapshot.docs.first.reference);
        } else {
          transaction.update(fromSnapshot.docs.first.reference, {
            'quantity': fromQuantity - quantity,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }

        // Update to bin
        transaction.update(toSnapshot.docs.first.reference, {
          'quantity': toQuantity + quantity,
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Log movement
        final movementRef = _firestore
            .collection('$_collectionPrefix/inventory_movements')
            .doc();

        transaction.set(movementRef, {
          'product_id': fromData['product_id'],
          'movement_type': 'warehouse_transfer',
          'quantity_change': 0,
          'reason': 'Warehouse relocation',
          'reference_id': fromBinId,
          'reference_type': 'bin_transfer',
          'notes': 'From $fromBinId to $toBinId, Qty: $quantity',
          'created_by': movedBy,
          'created_at': FieldValue.serverTimestamp(),
        });
      });

      developer.log('Successfully moved items between bins');
      _clearWarehouseCache(warehouseId);
    } catch (e) {
      developer.log('Error moving bin item: $e', error: e);
      rethrow;
    }
  }

  void _clearWarehouseCache([String? warehouseId]) {
    developer.log('Clearing warehouse cache');
    if (warehouseId != null) {
      AnalyticsPerformance.clearCacheKey('warehouse_bins_$warehouseId');
    }
    AnalyticsPerformance.clearCacheKey('warehouse_utilization');
  }
}
