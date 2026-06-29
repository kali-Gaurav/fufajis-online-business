import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import '../utils/monetary_value.dart';
import 'product_service.dart';

/// Service for secure bulk product imports with ownership verification and validation
class BulkImportService {
  static final BulkImportService _instance = BulkImportService._internal();
  factory BulkImportService() => _instance;
  BulkImportService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ProductService _productService = ProductService();

  /// Import products from CSV or JSON data with full ownership verification.
  /// All products must belong to the same shop, and user must own that shop.
  ///
  /// Returns: List of successfully imported product IDs
  /// Throws: UnauthorizedException if user doesn't own the shop
  /// Throws: ArgumentError if validation fails
  Future<List<String>> importProducts({
    required String shopId,
    required List<ProductModel> products,
  }) async {
    try {
      if (products.isEmpty) {
        debugPrint('[BulkImportService] No products to import');
        return [];
      }

      // SECURITY: Verify user owns the shop
      await _verifyShopOwnership(shopId);

      // VALIDATION: Ensure all products belong to the target shop
      for (final product in products) {
        if (product.shopId != shopId) {
          throw ArgumentError(
            'All products must belong to shop $shopId. Found product ${product.id} for shop ${product.shopId}',
          );
        }
      }

      // VALIDATION: Validate all product data
      final validProducts = <ProductModel>[];
      for (final product in products) {
        try {
          _validateProductData(product);
          validProducts.add(product);
        } catch (e) {
          debugPrint('[BulkImportService] Validation failed for product ${product.id}: $e');
          // Continue processing other products but track failures
        }
      }

      if (validProducts.isEmpty) {
        throw ArgumentError('No valid products to import after validation');
      }

      // SECURITY: Perform batch import with ownership checks
      final importedIds = await _performBatchImport(shopId, validProducts);

      debugPrint('[BulkImportService] Successfully imported ${importedIds.length} products to shop $shopId');
      return importedIds;
    } catch (e) {
      debugPrint('[BulkImportService] Import failed: $e');
      rethrow;
    }
  }

  /// Performs the actual batch import into Firestore
  Future<List<String>> _performBatchImport(
    String shopId,
    List<ProductModel> products,
  ) async {
    final importedIds = <String>[];

    try {
      const int batchSize = 50;

      for (var i = 0; i < products.length; i += batchSize) {
        final batch = _db.batch();
        final chunk = products.sublist(
          i,
          (i + batchSize > products.length) ? products.length : i + batchSize,
        );

        for (final product in chunk) {
          final docRef = _db.collection('products').doc(product.id);
          batch.set(docRef, product.toMap());
          importedIds.add(product.id);
        }

        await batch.commit();
      }

      return importedIds;
    } catch (e) {
      debugPrint('[BulkImportService] Batch import failed: $e');
      rethrow;
    }
  }

  /// Verifies that the current user owns the specified shop
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
        throw UnauthorizedException(
          'User ${user.uid} is not the owner of shop $shopId (owner: $ownerId)',
        );
      }

      debugPrint('[BulkImportService] Shop ownership verified for $shopId');
    } catch (e) {
      debugPrint('[BulkImportService] Ownership verification failed: $e');
      rethrow;
    }
  }

  /// Validates a single product's data
  void _validateProductData(ProductModel product) {
    // Validate price >= 0
    if (product.price < 0.inr) {
      throw ArgumentError('Product price must be >= 0, got ${product.price}');
    }

    // Validate stock >= 0
    if (product.stockQuantity < 0) {
      throw ArgumentError('Product stock quantity must be >= 0, got ${product.stockQuantity}');
    }

    // Validate category is not empty
    if (product.category.trim().isEmpty) {
      throw ArgumentError('Product category cannot be empty');
    }

    // Validate product name is not empty
    if (product.name.trim().isEmpty) {
      throw ArgumentError('Product name cannot be empty');
    }

    // Validate shop_id is not empty
    if (product.shopId.trim().isEmpty) {
      throw ArgumentError('Product shopId cannot be empty');
    }
  }
}

/// Custom exception for authorization failures
class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
  @override
  String toString() => 'UnauthorizedException: $message';
}
