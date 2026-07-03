import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/product_model.dart';
import '../models/product_review_model.dart';
import '../models/low_stock_alert_model.dart';
import '../utils/monetary_value.dart';
import 'notification_service.dart';
import 'audit_service.dart';
import 'inventory_alert_service.dart';
import 'supabase_service.dart';

// Custom exception for authorization failures
class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
  @override
  String toString() => 'UnauthorizedException: $message';
}

class ProductService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  Stream<List<ProductModel>> getProductsStream() {
    return _db.collection('products').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ProductModel.fromMap(doc.data())).toList();
    });
  }

  Future<List<ProductModel>> getProducts() async {
    final snapshot = await _db.collection('products').get();
    return snapshot.docs.map((doc) => ProductModel.fromMap(doc.data())).toList();
  }

  Future<void> addProduct(ProductModel product) async {
    try {
      // SECURITY: Verify shop ownership before allowing product creation
      await _verifyShopOwnership(product.shopId);

      // VALIDATION: Ensure required fields are valid
      _validateProductData(product);

      await _db.collection('products').doc(product.id).set(product.toMap());
      debugPrint('[ProductService] Product added to Firestore: ${product.id}');

      // Dual-write to Supabase
      try {
        await SupabaseService().addProduct({
          'firestore_id': product.id,
          'shop_id': product.shopId,
          'name': product.name,
          'description': product.description,
          'price': product.price.toDouble(),
          'stock': product.stockQuantity,
          'image_url': product.imageUrl,
          'category_id': product.categoryId,
          'barcode': product.barcode,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('[ProductService] Product dual-write successful');
      } catch (sbErr) {
        debugPrint('[ProductService] Supabase dual-write failed: $sbErr');
      }
    } catch (e) {
      debugPrint('[ProductService] ERROR adding product: $e');
      rethrow;
    }
  }

  /// Verifies that the current user owns the shop before allowing product operations
  Future<void> _verifyShopOwnership(String shopId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw UnauthorizedException('User not authenticated');
      }

      final shopDoc = await _db.collection('shops').doc(shopId).get();
      if (!shopDoc.exists) {
        throw UnauthorizedException('Shop $shopId does not exist');
      }

      final shopData = shopDoc.data() as Map<String, dynamic>;
      final ownerId = shopData['owner_id'] as String?;

      if (ownerId != user.uid) {
        throw UnauthorizedException('User is not the owner of shop $shopId');
      }
    } catch (e) {
      debugPrint('[ProductService] Ownership verification failed: $e');
      rethrow;
    }
  }

  /// Validates product data to ensure all required fields meet constraints
  void _validateProductData(ProductModel product) {
    // Validate price >= 0
    if (product.price < 0.inr) {
      throw ArgumentError('Product price must be >= 0');
    }

    // Validate stock >= 0
    if (product.stockQuantity < 0) {
      throw ArgumentError('Product stock quantity must be >= 0');
    }

    // Validate category is not empty
    if (product.category.trim().isEmpty) {
      throw ArgumentError('Product category cannot be empty');
    }

    // Validate product name is not empty
    if (product.name.trim().isEmpty) {
      throw ArgumentError('Product name cannot be empty');
    }

    debugPrint('[ProductService] Product data validated successfully');
  }

  Future<void> batchAddProducts(List<ProductModel> products) async {
    try {
      if (products.isEmpty) return;

      // SECURITY: Verify shop ownership for all products (use first product's shop as reference)
      final shopId = products.first.shopId;
      await _verifyShopOwnership(shopId);

      // VALIDATION: Validate all products before batch write
      for (final product in products) {
        // Ensure all products belong to same shop
        if (product.shopId != shopId) {
          throw ArgumentError('All products must belong to the same shop');
        }
        _validateProductData(product);
      }

      const int batchSize = 50;
      for (var i = 0; i < products.length; i += batchSize) {
        final batch = _db.batch();
        final chunk = products.sublist(
          i,
          i + batchSize > products.length ? products.length : i + batchSize,
        );

        for (var product in chunk) {
          final docRef = _db.collection('products').doc(product.id);
          batch.set(docRef, product.toMap());
        }

        await batch.commit();
      }

      debugPrint('[ProductService] Batch added ${products.length} products to shop $shopId');
    } catch (e) {
      debugPrint('[ProductService] ERROR in batchAddProducts: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> data) async {
    try {
      final doc = await _db.collection('products').doc(productId).get();
      final oldData = doc.data() ?? {};

      // SECURITY: Verify shop ownership before allowing update
      final shopId = oldData['shopId'] as String?;
      if (shopId != null) {
        await _verifyShopOwnership(shopId);
      }

      // VALIDATION: Validate updated fields if they exist
      if (data.containsKey('price')) {
        final newPrice = data['price'] as num?;
        if (newPrice != null && newPrice < 0) {
          throw ArgumentError('Product price must be >= 0');
        }
      }

      if (data.containsKey('stockQuantity')) {
        final newStock = data['stockQuantity'] as int?;
        if (newStock != null && newStock < 0) {
          throw ArgumentError('Product stock quantity must be >= 0');
        }
      }

      if (data.containsKey('category')) {
        final newCategory = data['category'] as String?;
        if (newCategory != null && newCategory.trim().isEmpty) {
          throw ArgumentError('Product category cannot be empty');
        }
      }

      await _db.collection('products').doc(productId).update(data);

      // Dual-write update to Supabase
      try {
        final Map<String, dynamic> sbData = {};
        if (data.containsKey('name')) sbData['name'] = data['name'];
        if (data.containsKey('description')) sbData['description'] = data['description'];
        if (data.containsKey('price')) {
          final price = data['price'];
          sbData['price'] = price is num ? price.toDouble() : (price as MonetaryValue).toDouble();
        }
        if (data.containsKey('stockQuantity')) sbData['stock'] = data['stockQuantity'];
        if (data.containsKey('imageUrl')) sbData['image_url'] = data['imageUrl'];
        if (data.containsKey('categoryId')) sbData['category_id'] = data['categoryId'];

        if (sbData.isNotEmpty) {
          sbData['updated_at'] = DateTime.now().toIso8601String();
          await SupabaseService().updateProduct(productId, sbData);
        }
      } catch (sbErr) {
        debugPrint('[ProductService] Supabase update failed: $sbErr');
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUid = currentUser?.uid ?? 'system';
      final currentName = currentUser?.displayName ?? currentUser?.email ?? 'Owner/Admin';

      if (data.containsKey('stockQuantity')) {
        await AuditService().logAction(
          userId: currentUid,
          userName: currentName,
          action: AuditAction.stockAdjustment,
          description: 'Stock updated for ${oldData['name'] ?? productId}',
          metadata: {
            'productId': productId,
            'oldStock': oldData['stockQuantity'],
            'newStock': data['stockQuantity'],
          },
        );
      }

      if (data.containsKey('price')) {
        await AuditService().logAction(
          userId: currentUid,
          userName: currentName,
          action: AuditAction.priceUpdate,
          description: 'Price updated for ${oldData['name'] ?? productId}',
          metadata: {
            'productId': productId,
            'oldPrice': oldData['price'],
            'newPrice': data['price'],
          },
        );
      }

      if (data.containsKey('stockQuantity') || data.containsKey('minimumStock')) {
        if (doc.exists) {
          final freshDoc = await _db.collection('products').doc(productId).get();
          final freshProduct = ProductModel.fromMap(freshDoc.data()!);

          if (freshProduct.stockQuantity < freshProduct.minimumStock) {
            await createLowStockAlert(freshProduct);
          }
        }
      }
    } catch (e) {
      debugPrint('[ProductService] ERROR updating product: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      // 1. Clean up images in Firebase Storage folder
      final storageRef = FirebaseStorage.instance.ref().child('products/$productId');
      try {
        final listResult = await storageRef.listAll();
        for (final item in listResult.items) {
          await item.delete();
        }
      } catch (e) {
        debugPrint('[ProductService] Firebase storage cleanup skipped or failed: $e');
      }

      // 2. Delete Firestore document
      await _db.collection('products').doc(productId).delete();

      // 3. Delete from Supabase
      try {
        await SupabaseService().deleteProduct(productId);
      } catch (sbErr) {
        debugPrint('[ProductService] Supabase delete failed: $sbErr');
      }
    } catch (e) {
      debugPrint('[ProductService] ERROR deleting product: $e');
      rethrow;
    }
  }

  Future<void> createLowStockAlert(ProductModel product) async {
    final alertService = InventoryAlertService();
    final velocityData = await alertService.calculateSalesVelocityWithTrend(product.id);
    final double velocity = (velocityData['velocity'] as num?)?.toDouble() ?? 0.0;
    final int daysUntilStockout = await alertService.predictDaysUntilStockout(
      product.id,
      product.stockQuantity,
      precalculatedVelocity: velocityData,
    );
    final int recommendedReorder = await alertService.calculateReorderQuantity(
      product.id,
      product.stockQuantity,
      precalculatedVelocity: velocityData,
    );
    final String severityScore = daysUntilStockout <= 1
        ? 'Critical'
        : (daysUntilStockout <= 3 ? 'High' : (daysUntilStockout <= 7 ? 'Medium' : 'Low'));

    final alert = LowStockAlert(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      productId: product.id,
      productName: product.name,
      currentStock: product.stockQuantity,
      minimumStock: product.minimumStock,
      createdAt: DateTime.now(),
      severity: severityScore,
      recommendedReorderQuantity: recommendedReorder,
      averageDailySales: velocity,
      daysUntilStockout: daysUntilStockout,
      recommendedStockDays: 14,
    );
    await _db.collection('low_stock_alerts').doc(alert.id).set(alert.toMap());

    NotificationService().showLocalNotification(
      '⚠️ Low Stock Alert',
      '${product.name} is running low (${product.stockQuantity} remaining). Days left: $daysUntilStockout',
    );
  }

  Stream<List<LowStockAlert>> getLowStockAlertsStream() {
    return _db
        .collection('low_stock_alerts')
        .where('isDismissed', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => LowStockAlert.fromMap(doc.data())).toList();
        });
  }

  Future<void> dismissLowStockAlert(String alertId) async {
    await _db.collection('low_stock_alerts').doc(alertId).update({'isDismissed': true});
  }

  Stream<List<ProductReviewModel>> getProductReviewsStream(String productId) {
    return _db
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => ProductReviewModel.fromMap(doc.data())).toList();
        });
  }

  Future<void> addProductReview(ProductReviewModel review) async {
    final productRef = _db.collection('products').doc(review.productId);
    final reviewRef = productRef.collection('reviews').doc(review.id);

    await _db.runTransaction((transaction) async {
      final productSnapshot = await transaction.get(productRef);
      final data = productSnapshot.data();
      final currentRating = (data?['rating'] ?? 0.0).toDouble();
      final currentCount = data?['reviewCount'] ?? 0;
      final nextCount = currentCount + 1;
      final nextRating = ((currentRating * currentCount) + review.rating) / nextCount;

      transaction.set(reviewRef, review.toMap());
      transaction.update(productRef, {
        'rating': double.parse(nextRating.toStringAsFixed(1)),
        'reviewCount': nextCount,
      });
    });
  }

  Future<void> addOwnerResponse(String productId, String reviewId, String response) async {
    await _db.collection('products').doc(productId).collection('reviews').doc(reviewId).update({
      'ownerReply': response,
      'ownerReplyDate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> flagReview(String productId, String reviewId, List<String> reasons) async {
    await _db.collection('products').doc(productId).collection('reviews').doc(reviewId).update({
      'isFlagged': true,
      'flagReasons': reasons,
    });
  }

  Future<void> markReviewAsHelpful(String productId, String reviewId) async {
    await _db.collection('products').doc(productId).collection('reviews').doc(reviewId).update({
      'helpfulCount': FieldValue.increment(1),
    });
  }

  // ── Price Change Management ──

  Stream<List<Map<String, dynamic>>> getPendingPriceChangesStream() {
    return _db
        .collection('price_change_proposals')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Stream<List<Map<String, dynamic>>> getPriceChangesHistoryStream() {
    return _db
        .collection('price_change_proposals')
        .where('status', whereIn: ['approved', 'rejected'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> approvePriceChange(String changeId) async {
    final doc = await _db.collection('price_change_proposals').doc(changeId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final productId = data['productId'] as String;
    final newPrice = (data['newPrice'] as num).toDouble();

    await _db.runTransaction((tx) async {
      tx.update(_db.collection('products').doc(productId), {'price': newPrice});
      tx.update(_db.collection('price_change_proposals').doc(changeId), {
        'status': 'approved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> approveAllPriceChanges(List<String> changeIds) async {
    for (final id in changeIds) {
      await approvePriceChange(id);
    }
  }

  Future<void> rejectPriceChange(String changeId, String reason) async {
    await _db.collection('price_change_proposals').doc(changeId).update({
      'status': 'rejected',
      'rejectionReason': reason,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> proposePriceChange({
    required String productId,
    required String productName,
    required double oldPrice,
    required double newPrice,
    required String reason,
    required String requestedBy,
  }) async {
    await _db.collection('price_change_proposals').add({
      'productId': productId,
      'productName': productName,
      'oldPrice': oldPrice,
      'newPrice': newPrice,
      'reason': reason,
      'requestedBy': requestedBy,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<ProductModel>> getProductsByShopId(String shopId) async {
    final s = await _db.collection('products').where('shopId', isEqualTo: shopId).get();
    return s.docs.map((d) => ProductModel.fromMap(d.data())).toList();
  }

  /// Check whether a barcode is already used by another product.
  Future<bool> isBarcodeUnique(String barcode, {String? excludeProductId}) async {
    final query = await FirebaseFirestore.instance
        .collection('products')
        .where('barcode', isEqualTo: barcode)
        .limit(2)
        .get();
    if (query.docs.isEmpty) return true;
    if (excludeProductId != null &&
        query.docs.length == 1 &&
        query.docs.first.id == excludeProductId) {
      return true;
    }
    return false;
  }
}
