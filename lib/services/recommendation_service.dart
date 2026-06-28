import '../models/product_model.dart';
import '../models/order_model.dart';

class RecommendationService {
  static final RecommendationService _instance = RecommendationService._internal();
  factory RecommendationService() => _instance;
  RecommendationService._internal();

  /// Basic collaborative filtering simulated via category affinity
  static List<ProductModel> getRecommendations({
    required List<ProductModel> allProducts,
    required List<ProductModel> cartProducts,
    int limit = 6,
  }) {
    if (cartProducts.isEmpty) {
      return allProducts.where((p) => p.isTrending).take(limit).toList();
    }

    final Map<String, int> categoryScores = {};
    for (var p in cartProducts) {
      categoryScores[p.categoryId] = (categoryScores[p.categoryId] ?? 0) + 1;
    }

    final sortedCategories = categoryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final Set<String> cartIds = cartProducts.map((p) => p.id).toSet();
    final List<ProductModel> recommendations = [];

    for (var catEntry in sortedCategories) {
      final catProducts = allProducts
          .where((p) => p.categoryId == catEntry.key && !cartIds.contains(p.id))
          .toList();
      recommendations.addAll(catProducts);
      if (recommendations.length >= limit) break;
    }

    if (recommendations.length < limit) {
      recommendations.addAll(allProducts
          .where((p) => p.isTrending && !cartIds.contains(p.id) && !recommendations.contains(p))
          .take(limit - recommendations.length));
    }

    return recommendations.take(limit).toList();
  }

  /// Returns the user's top categories based on history
  static List<String> getFavoriteCategories(List<OrderModel> orders, List<ProductModel> allProducts) {
    if (orders.isEmpty) return [];
    
    final Map<String, int> scores = {};
    for (var order in orders) {
      for (var item in order.items) {
        final p = allProducts.firstWhere((element) => element.id == item.productId, orElse: () => allProducts.first);
        scores[p.categoryId] = (scores[p.categoryId] ?? 0) + 1;
      }
    }
    
    final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).take(5).toList();
  }

  /// Finds "Frequently Bought Together" items (Upsell)
  List<ProductModel> getComplementaryProducts(ProductModel product, List<ProductModel> allProducts) {
    // Basic logic: same category + popular
    return allProducts
        .where((p) => p.categoryId == product.categoryId && p.id != product.id && p.isTrending)
        .take(4)
        .toList();
  }
}
