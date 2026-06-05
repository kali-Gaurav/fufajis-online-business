import '../models/product_model.dart';

class InvertedIndex {
  final Map<String, List<ProductModel>> _categoryIndex = {};
  final Map<String, List<ProductModel>> _tagIndex = {};
  final List<ProductModel> trendingProducts = [];
  final List<ProductModel> featuredProducts = [];

  /// Build the inverted index using the provided product list
  void build(List<ProductModel> products) {
    _categoryIndex.clear();
    _tagIndex.clear();
    trendingProducts.clear();
    featuredProducts.clear();

    for (final product in products) {
      final category = product.category.toLowerCase().trim();
      _categoryIndex.putIfAbsent(category, () => []).add(product);

      for (final tag in product.tags) {
        final cleanTag = tag.toLowerCase().trim();
        _tagIndex.putIfAbsent(cleanTag, () => []).add(product);
      }

      if (product.isTrending) {
        trendingProducts.add(product);
      }
      if (product.isFeatured) {
        featuredProducts.add(product);
      }
    }
  }

  /// Get products matching a specific category
  List<ProductModel> getByCategory(String category) {
    return _categoryIndex[category.toLowerCase().trim()] ?? [];
  }

  /// Get products matching a specific tag
  List<ProductModel> getByTag(String tag) {
    return _tagIndex[tag.toLowerCase().trim()] ?? [];
  }
}
