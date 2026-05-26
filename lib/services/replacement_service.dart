import '../models/product_model.dart';

class ReplacementService {
  /// Suggests replacements for an out-of-stock product
  List<ProductModel> suggestReplacements(ProductModel original, List<ProductModel> catalog) {
    // Strategy: Same category, similar price point, in stock
    final available = catalog.where((p) => p.id != original.id && p.stockQuantity > 0).toList();
    
    // 1. Filter by category
    var matches = available.where((p) => p.category == original.category).toList();
    
    // 2. Score by tag overlap
    matches.sort((a, b) {
      final aOverlap = a.tags.where((t) => original.tags.contains(t)).length;
      final bOverlap = b.tags.where((t) => original.tags.contains(t)).length;
      return bOverlap.compareTo(aOverlap);
    });

    return matches.take(3).toList();
  }

  String formatReplacementMessage(ProductModel original, ProductModel replacement) {
    return "Sorry, ${original.name} is out of stock. Would you like ${replacement.name} instead (₹${replacement.price})?";
  }
}
