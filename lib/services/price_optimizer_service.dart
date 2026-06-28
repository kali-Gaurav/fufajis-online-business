import '../models/product_model.dart';
import '../utils/monetary_value.dart';

enum PricingStrategy { match, undercut, premium }

class PriceOptimizerService {
  static final PriceOptimizerService _instance = PriceOptimizerService._internal();
  factory PriceOptimizerService() => _instance;
  PriceOptimizerService._internal();

  /// Suggests an optimized price based on competitor data (Data Science Optimization)
  MonetaryValue suggestPrice(ProductModel product, {PricingStrategy strategy = PricingStrategy.undercut}) {
    if (product.competitorPrices.isEmpty) return product.price;

    final competitorPrices = product.competitorPrices.map((p) => p.price).toList();
    competitorPrices.sort();
    
    final minPrice = competitorPrices.first;
    final sumPrice = competitorPrices.reduce((a, b) => a + b);
    final avgPrice = sumPrice / competitorPrices.length;

    switch (strategy) {
      case PricingStrategy.match:
        return minPrice;
      case PricingStrategy.undercut:
        // Suggest 2% lower than the cheapest competitor, but not below cost if available
        final suggested = minPrice * 0.98;
        if (product.costPrice != null && suggested < MonetaryValue(product.costPrice!)) {
          return MonetaryValue(product.costPrice! * 1.05); // Maintain 5% margin if undercut is too deep
        }
        return suggested;
      case PricingStrategy.premium:
        return avgPrice * 1.1; // 10% premium above average
    }
  }

  /// Calculates potential revenue impact of a price change
  double estimateRevenueImpact(ProductModel product, MonetaryValue newPrice, int monthlyVolume) {
    final cost = MonetaryValue(product.costPrice ?? 0.0);
    final oldProfit = (product.price - cost) * monthlyVolume;
    final newProfit = (newPrice - cost) * monthlyVolume;
    return (newProfit - oldProfit).toDouble();
  }
}
