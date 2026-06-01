import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';

class RecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Association matrix mapping a source category to targeted complementary categories
  static const Map<String, List<String>> _categoryAssociations = {
    'vegetables': ['groceries', 'dairy'],
    'fruits': ['dairy', 'beverages'],
    'groceries': ['vegetables', 'dairy'],
    'dairy': ['bakery', 'groceries'],
    'bakery': ['dairy', 'beverages'],
    'snacks': ['beverages', 'bakery'],
    'beverages': ['snacks', 'bakery'],
    'household': ['groceries', 'dairy'],
  };

  /// Specific cross-sell products to suggest when a certain product tag is present
  static const Map<String, List<String>> _tagAssociations = {
    'potato': ['onion', 'tomato', 'oil'],
    'rice': ['dal', 'ghee', 'spices'],
    'flour': ['ghee', 'salt', 'paneer'],
    'milk': ['bread', 'rusk', 'tea'],
    'bread': ['butter', 'jam', 'tea'],
    'samosa': ['cold drink', 'sauce'],
  };

  /// Fetch frequently bought products from user's order history
  Future<List<String>> getFrequentlyBoughtProducts(String userId, {int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .where('status', isEqualTo: 'OrderStatus.delivered')
          .limit(20)
          .get();

      final Map<String, int> productCounts = {};
      for (var doc in snapshot.docs) {
        final order = OrderModel.fromMap(doc.data());
        for (var item in order.items) {
          productCounts[item.productId] = (productCounts[item.productId] ?? 0) + item.quantity;
        }
      }

      final sortedProducts = productCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedProducts.map((e) => e.key).take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get user's favorite categories sorted by purchase frequency
  Future<List<String>> getFavoriteCategories(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .where('status', isEqualTo: 'OrderStatus.delivered')
          .limit(20)
          .get();

      final Map<String, int> categoryCounts = {};
      for (var doc in snapshot.docs) {
        final order = OrderModel.fromMap(doc.data());
        for (var item in order.items) {
          // In a production app, category is resolved via catalog reference
          // For simplicity we extract if available, otherwise skip
          final cat = item.productId.split('_')[0]; // Simple mock logic fallback
          categoryCounts[cat] = (categoryCounts[cat] ?? 0) + item.quantity;
        }
      }

      final sortedCategories = categoryCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedCategories.map((e) => e.key).toList();
    } catch (_) {
      return [];
    }
  }

  /// Recommends products based on current basket contents.
  /// Filters out items that are already in the basket.
  static List<ProductModel> getRecommendations({
    required List<ProductModel> allProducts,
    required List<ProductModel> cartProducts,
    int limit = 5,
  }) {
    if (allProducts.isEmpty) return [];

    final cartIds = cartProducts.map((p) => p.id).toSet();
    final cartCategories = cartProducts.map((p) => p.category.toLowerCase()).toSet();
    final cartTags = cartProducts.expand((p) => p.tags.map((t) => t.toLowerCase())).toSet();

    // Priority 1: Specific tag associations
    final Set<String> targetTags = {};
    for (final tag in cartTags) {
      if (_tagAssociations.containsKey(tag)) {
        targetTags.addAll(_tagAssociations[tag]!);
      }
    }

    // Priority 2: Category associations
    final Set<String> targetCategories = {};
    for (final cat in cartCategories) {
      if (_categoryAssociations.containsKey(cat)) {
        targetCategories.addAll(_categoryAssociations[cat]!);
      }
    }

    // Score and sort products
    final List<MapEntry<ProductModel, double>> scoredProducts = [];

    for (final product in allProducts) {
      // Rule: Do not recommend items already in cart
      if (cartIds.contains(product.id)) continue;

      double score = 0.0;

      // Score based on category match
      if (targetCategories.contains(product.category.toLowerCase())) {
        score += 3.0;
      }

      // Score based on tag match
      final productTags = product.tags.map((t) => t.toLowerCase()).toSet();
      final intersection = productTags.intersection(targetTags);
      score += intersection.length * 2.0;

      // Small score for popular products to fill space if needed
      if (product.isTrending) score += 0.5;
      if (product.isFeatured) score += 0.3;

      if (score > 0) {
        scoredProducts.add(MapEntry(product, score));
      }
    }

    // Sort by descending score
    scoredProducts.sort((a, b) => b.value.compareTo(a.value));

    // Return the top N items
    return scoredProducts.map((entry) => entry.key).take(limit).toList();
  }
}
