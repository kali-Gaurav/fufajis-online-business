import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/product_review_model.dart';
import '../models/low_stock_alert_model.dart';
import 'notification_service.dart';
import 'audit_service.dart';
import 'inventory_alert_service.dart';

class ProductService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
      await _db.collection('products').doc(product.id).set(product.toMap());
      debugPrint('[ProductService] Product added: ${product.id}');
    } catch (e) {
      debugPrint('[ProductService] ERROR adding product: $e');
      rethrow;
    }
  }

  Future<void> batchAddProducts(List<ProductModel> products) async {
    try {
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
    } catch (e) {
      debugPrint('[ProductService] ERROR in batchAddProducts: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> data) async {
    try {
      final doc = await _db.collection('products').doc(productId).get();
      final oldData = doc.data() ?? {};
      
      await _db.collection('products').doc(productId).update(data);

      if (data.containsKey('stockQuantity')) {
        await AuditService().logAction(
          userId: 'system',
          userName: 'Owner/Admin',
          action: AuditAction.stockAdjustment,
          description: 'Stock updated for ${oldData['name'] ?? productId}',
          metadata: {
            'productId': productId,
            'oldStock': oldData['stockQuantity'],
            'newStock': data['stockQuantity'],
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
      await _db.collection('products').doc(productId).delete();
    } catch (e) {
      debugPrint('[ProductService] ERROR deleting product: $e');
      rethrow;
    }
  }

  Future<void> createLowStockAlert(ProductModel product) async {
    final alertService = InventoryAlertService();
    final velocityData = await alertService.calculateSalesVelocityWithTrend(product.id);
    final double velocity = (velocityData['velocity'] as num?)?.toDouble() ?? 0.0;
    final int daysUntilStockout = await alertService.predictDaysUntilStockout(product.id, product.stockQuantity, precalculatedVelocity: velocityData);
    final int recommendedReorder = await alertService.calculateReorderQuantity(product.id, product.stockQuantity, precalculatedVelocity: velocityData);
    final String severityScore = daysUntilStockout <= 1 ? 'Critical' : (daysUntilStockout <= 3 ? 'High' : (daysUntilStockout <= 7 ? 'Medium' : 'Low'));

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
      return snapshot.docs
          .map((doc) => ProductReviewModel.fromMap(doc.data()))
          .toList();
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
      final nextRating =
          ((currentRating * currentCount) + review.rating) / nextCount;

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
}
