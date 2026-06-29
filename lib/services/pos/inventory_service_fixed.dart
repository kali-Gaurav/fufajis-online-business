import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Enhanced inventory service with pessimistic locking
///
/// This service resolves race conditions in stock deduction by using
/// a Cloud Function that acquires a lock before reading/deducting stock.
///
/// Problem solved:
/// - Two concurrent orders read stock=5
/// - Both pass validation
/// - Both deduct 3 units
/// - Result: stock becomes -1 (NEGATIVE!)
///
/// Solution:
/// - Lock product before reading stock
/// - Read guaranteed-fresh stock within lock
/// - Validate and deduct atomically
/// - Release lock
class InventoryServiceFixed {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static final InventoryServiceFixed _instance =
      InventoryServiceFixed._internal();

  factory InventoryServiceFixed() => _instance;
  InventoryServiceFixed._internal();

  /// Deduct inventory safely using Cloud Function with pessimistic locking
  ///
  /// This is the PRIMARY method for deducting stock during order creation.
  /// It ensures atomicity and prevents race conditions.
  ///
  /// Returns: Map with keys:
  ///   - 'success': bool
  ///   - 'stockBefore': int - stock before deduction
  ///   - 'stockAfter': int - stock after deduction
  ///   - 'productId': string
  ///   - 'orderId': string
  ///
  /// Throws:
  ///   - 'resource-exhausted': Product is locked by another transaction
  ///   - 'failed-precondition': Insufficient stock available
  ///   - 'not-found': Product doesn't exist
  ///
  Future<Map<String, dynamic>> deductInventorySafe({
    required String productId,
    required int quantity,
    required String orderId,
    required String shopId,
  }) async {
    try {
      final callable = _functions.httpsCallable('deductInventoryAtomic');

      final result = await callable.call({
        'productId': productId,
        'quantity': quantity,
        'orderId': orderId,
        'shopId': shopId,
      });

      final data = result.data as Map<String, dynamic>;

      debugPrint(
        '[InventoryServiceFixed] Stock deducted successfully. '
        'Product: $productId, Before: ${data['stockBefore']}, '
        'After: ${data['stockAfter']}, Order: $orderId'
      );

      return data;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '[InventoryServiceFixed] CloudFunction error: ${e.code} - ${e.message}'
      );

      // User-friendly error messages
      if (e.code == 'resource-exhausted') {
        throw Exception(
          'Product is being processed by another order. Please try again in a few seconds.'
        );
      } else if (e.code == 'failed-precondition') {
        throw Exception(e.message ?? 'Out of stock');
      } else if (e.code == 'not-found') {
        throw Exception('Product not found in inventory');
      } else {
        throw Exception('Error deducting inventory: ${e.message}');
      }
    } catch (e) {
      debugPrint('[InventoryServiceFixed] Unexpected error: $e');
      throw Exception('Unexpected error during inventory deduction: $e');
    }
  }

  /// Manual lock release (emergency recovery only)
  ///
  /// Use this ONLY if a transaction fails partway through and leaves
  /// a lock in place. Normal operations should not call this.
  Future<void> releaseLock({
    required String productId,
    required String orderId,
  }) async {
    try {
      final callable = _functions.httpsCallable('releaseInventoryLock');

      await callable.call({
        'productId': productId,
        'orderId': orderId,
      });

      debugPrint('[InventoryServiceFixed] Lock released for $productId');
    } catch (e) {
      debugPrint('[InventoryServiceFixed] Error releasing lock: $e');
      rethrow;
    }
  }

  /// Validate stock availability (read-only check)
  ///
  /// This is a lightweight check to display available stock to users.
  /// It does NOT reserve stock - use deductInventorySafe() for that.
  Future<int> getAvailableStock({
    required String productId,
    required String shopId,
  }) async {
    try {
      final docSnapshot = await _firestore
          .collection('products')
          .doc(productId)
          .get();

      if (!docSnapshot.exists) {
        return 0;
      }

      final data = docSnapshot.data()!;
      final branchStockMap = data['branchStock'] as Map<String, dynamic>? ?? {};

      int stock = 0;
      if (branchStockMap.containsKey(shopId)) {
        stock = (branchStockMap[shopId] ?? 0) as int;
      } else if (shopId == 'primary' || branchStockMap.isEmpty) {
        stock = (data['stockQuantity'] ?? 0) as int;
      }

      return stock;
    } catch (e) {
      debugPrint('[InventoryServiceFixed] Error getting available stock: $e');
      return 0;
    }
  }

  /// Get stock for multiple products efficiently
  Future<Map<String, int>> getAvailableStockBatch({
    required List<String> productIds,
    required String shopId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where(FieldPath.documentId, whereIn: productIds)
          .get();

      final stocks = <String, int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final branchStockMap = data['branchStock'] as Map<String, dynamic>? ?? {};

        int stock = 0;
        if (branchStockMap.containsKey(shopId)) {
          stock = (branchStockMap[shopId] ?? 0) as int;
        } else if (shopId == 'primary' || branchStockMap.isEmpty) {
          stock = (data['stockQuantity'] ?? 0) as int;
        }

        stocks[doc.id] = stock;
      }

      return stocks;
    } catch (e) {
      debugPrint('[InventoryServiceFixed] Error getting batch stock: $e');
      return {};
    }
  }

  /// Stream stock updates for a product (real-time UI updates)
  Stream<int> watchStock({
    required String productId,
    required String shopId,
  }) {
    return _firestore
        .collection('products')
        .doc(productId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return 0;

          final data = snapshot.data()!;
          final branchStockMap = data['branchStock'] as Map<String, dynamic>? ?? {};

          int stock = 0;
          if (branchStockMap.containsKey(shopId)) {
            stock = (branchStockMap[shopId] ?? 0) as int;
          } else if (shopId == 'primary' || branchStockMap.isEmpty) {
            stock = (data['stockQuantity'] ?? 0) as int;
          }

          return stock;
        });
  }

  /// Check if stock is below low-stock threshold
  Future<bool> isLowStock({
    required String productId,
    required int lowStockThreshold,
    required String shopId,
  }) async {
    final stock = await getAvailableStock(
      productId: productId,
      shopId: shopId,
    );
    return stock < lowStockThreshold;
  }
}
