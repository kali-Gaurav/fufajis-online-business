import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/reorder_template_model.dart';
import '../providers/cart_provider.dart';
import '../models/product_model.dart';

/// Production-grade reorder service handling:
/// - Recent order retrieval for "Buy Again"
/// - Reorder template CRUD (saved presets like "Weekly Essentials")
/// - Cart population from orders or templates with real-time price/stock validation
/// - Auto-template generation from completed orders
///
/// Firestore structure:
///   users/{userId}/reorder_templates/{templateId}
class ReorderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final ReorderService _instance = ReorderService._internal();
  factory ReorderService() => _instance;
  ReorderService._internal();

  // ─── RECENT ORDERS ──────────────────────────────────────────────────

  /// Retrieve user's recent completed orders for "Buy Again" display
  Future<List<OrderModel>> getRecentOrders(
    String userId, {
    int limit = 5,
  }) async {
    try {
      final snapshot = await _db
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .where('status', isEqualTo: 'OrderStatus.delivered')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[ReorderService] Error fetching recent orders: $e');
      return [];
    }
  }

  /// Retrieve the user's last completed order
  Future<OrderModel?> getLastOrder(String userId) async {
    final orders = await getRecentOrders(userId, limit: 1);
    return orders.isNotEmpty ? orders.first : null;
  }

  // ─── TEMPLATE CRUD ──────────────────────────────────────────────────

  /// Get all saved reorder templates for a user
  Future<List<ReorderTemplate>> getTemplates(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('reorder_templates')
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ReorderTemplate.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[ReorderService] Error fetching templates: $e');
      return [];
    }
  }

  /// Create or update a reorder template
  Future<void> saveTemplate(ReorderTemplate template) async {
    try {
      await _db
          .collection('users')
          .doc(template.userId)
          .collection('reorder_templates')
          .doc(template.id)
          .set(template.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ReorderService] Error saving template: $e');
      rethrow;
    }
  }

  /// Delete a reorder template
  Future<void> deleteTemplate(String userId, String templateId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('reorder_templates')
          .doc(templateId)
          .delete();
    } catch (e) {
      debugPrint('[ReorderService] Error deleting template: $e');
      rethrow;
    }
  }

  /// Auto-generate a template from a completed order
  Future<ReorderTemplate> createTemplateFromOrder({
    required OrderModel order,
    String? customName,
  }) async {
    final template = ReorderTemplate.fromOrder(
      userId: order.customerId,
      orderId: order.id,
      orderNumber: order.orderNumber,
      orderItems: order.items
          .map(
            (item) => {
              'productId': item.productId,
              'productName': item.productName,
              'productImage': item.productImage,
              'unit': item.unit,
              'quantity': item.quantity,
              'price': item.price,
              'selectedVariant': item.selectedVariant,
            },
          )
          .toList(),
      customName: customName,
    );

    await saveTemplate(template);
    return template;
  }

  /// Increment usage count when a template is reordered
  Future<void> _incrementUsageCount(ReorderTemplate template) async {
    try {
      await _db
          .collection('users')
          .doc(template.userId)
          .collection('reorder_templates')
          .doc(template.id)
          .update({
            'usageCount': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('[ReorderService] Error updating usage count: $e');
    }
  }

  // ─── CART POPULATION ────────────────────────────────────────────────

  /// Populate cart from a previous order with real-time price/stock validation
  /// Returns a report of what was added vs. what was unavailable
  Future<ReorderResult> populateCartFromOrder({
    required OrderModel order,
    required CartProvider cartProvider,
  }) async {
    final List<String> addedItems = [];
    final List<String> unavailableItems = [];
    final List<String> priceChangedItems = [];

    try {
      cartProvider.clearCart();

      for (var item in order.items) {
        final prodDoc = await _db
            .collection('products')
            .doc(item.productId)
            .get();

        if (!prodDoc.exists) {
          unavailableItems.add(item.productName);
          continue;
        }

        final product = ProductModel.fromMap(prodDoc.data()!);

        // Check stock availability
        if (!product.isAvailable || product.stockQuantity <= 0) {
          unavailableItems.add(item.productName);
          continue;
        }

        // Track price changes
        if ((product.price - item.price).abs() > 0.5) {
          priceChangedItems.add(
            '${item.productName}: ₹${item.price.round()} → ₹${product.price.round()}',
          );
        }

        // Match unit option variant
        ProductUnitOption? matchedOption;
        if (item.selectedVariant != null) {
          final options = product.unitOptions.where(
            (opt) => opt.id == item.selectedVariant,
          );
          if (options.isNotEmpty) {
            matchedOption = options.first;
          }
        }

        // Clamp quantity to available stock
        final safeQuantity = item.quantity.clamp(1, product.stockQuantity);

        cartProvider.addToCart(
          product,
          quantity: safeQuantity,
          selectedUnit: matchedOption,
        );
        addedItems.add(item.productName);
      }

      return ReorderResult(
        success: addedItems.isNotEmpty,
        addedItems: addedItems,
        unavailableItems: unavailableItems,
        priceChangedItems: priceChangedItems,
      );
    } catch (e) {
      debugPrint('[ReorderService] Error populating cart: $e');
      return ReorderResult(
        success: false,
        addedItems: addedItems,
        unavailableItems: unavailableItems,
        priceChangedItems: priceChangedItems,
        error: e.toString(),
      );
    }
  }

  /// Populate cart from a saved template
  Future<ReorderResult> populateCartFromTemplate({
    required ReorderTemplate template,
    required CartProvider cartProvider,
  }) async {
    final List<String> addedItems = [];
    final List<String> unavailableItems = [];
    final List<String> priceChangedItems = [];

    try {
      cartProvider.clearCart();

      for (var item in template.items) {
        final prodDoc = await _db
            .collection('products')
            .doc(item.productId)
            .get();

        if (!prodDoc.exists) {
          unavailableItems.add(item.productName);
          continue;
        }

        final product = ProductModel.fromMap(prodDoc.data()!);

        if (!product.isAvailable || product.stockQuantity <= 0) {
          unavailableItems.add(item.productName);
          continue;
        }

        if ((product.price - item.lastPrice).abs() > 0.5) {
          priceChangedItems.add(
            '${item.productName}: ₹${item.lastPrice.round()} → ₹${product.price.round()}',
          );
        }

        ProductUnitOption? matchedOption;
        if (item.selectedVariant != null) {
          final options = product.unitOptions.where(
            (opt) => opt.id == item.selectedVariant,
          );
          if (options.isNotEmpty) {
            matchedOption = options.first;
          }
        }

        final safeQuantity = item.quantity.clamp(1, product.stockQuantity);

        cartProvider.addToCart(
          product,
          quantity: safeQuantity,
          selectedUnit: matchedOption,
        );
        addedItems.add(item.productName);
      }

      // Track usage
      await _incrementUsageCount(template);

      return ReorderResult(
        success: addedItems.isNotEmpty,
        addedItems: addedItems,
        unavailableItems: unavailableItems,
        priceChangedItems: priceChangedItems,
      );
    } catch (e) {
      debugPrint('[ReorderService] Error populating from template: $e');
      return ReorderResult(
        success: false,
        addedItems: addedItems,
        unavailableItems: unavailableItems,
        priceChangedItems: priceChangedItems,
        error: e.toString(),
      );
    }
  }
}

/// Result of a reorder operation with detailed feedback
class ReorderResult {
  final bool success;
  final List<String> addedItems;
  final List<String> unavailableItems;
  final List<String> priceChangedItems;
  final String? error;

  const ReorderResult({
    required this.success,
    required this.addedItems,
    required this.unavailableItems,
    required this.priceChangedItems,
    this.error,
  });

  bool get hasUnavailableItems => unavailableItems.isNotEmpty;
  bool get hasPriceChanges => priceChangedItems.isNotEmpty;

  /// User-friendly summary message
  String get summaryMessage {
    if (!success && error != null) return 'Failed to reorder: $error';
    if (addedItems.isEmpty) return 'None of the items are currently available.';

    final parts = <String>[];
    parts.add(
      '${addedItems.length} item${addedItems.length > 1 ? 's' : ''} added to cart.',
    );

    if (hasUnavailableItems) {
      parts.add(
        '${unavailableItems.length} item${unavailableItems.length > 1 ? 's' : ''} unavailable.',
      );
    }
    if (hasPriceChanges) {
      parts.add(
        '${priceChangedItems.length} price${priceChangedItems.length > 1 ? 's' : ''} updated.',
      );
    }

    return parts.join(' ');
  }
}
