import 'dart:math';
import '../models/product_model.dart';
import '../utils/monetary_value.dart';
import 'product_service.dart';
import 'shop_config_service.dart';

class MandiMarketFeed {
  final String itemName;
  final String category;
  final double baseMandiPrice;
  final double currentMandiPrice;
  final double dailyChangePercentage;

  MandiMarketFeed({
    required this.itemName,
    required this.category,
    required this.baseMandiPrice,
    required this.currentMandiPrice,
    required this.dailyChangePercentage,
  });
}

class PricingService {
  static final PricingService _instance = PricingService._internal();
  factory PricingService() => _instance;
  PricingService._internal();

  // Baseline mandi prices per kg/L/unit
  final Map<String, double> _baseMandiPrices = {
    'potato': 18.0,
    'onion': 22.0,
    'tomato': 25.0,
    'coriander': 60.0,
    'spinach': 15.0,
    'cauliflower': 30.0,
    'mango': 110.0,
    'banana': 35.0,
    'apple': 90.0,
    'milk': 54.0,
    'paneer': 280.0,
    'ghee': 550.0,
    'rice': 75.0,
    'wheat': 24.0,
    'jaggery': 38.0,
    'turmeric': 120.0,
  };

  // Profit margins & buffers (configurable by owner)
  double marginPercentage = 20.0; // 20% markup
  double transportChargePercentage = 5.0; // 5% transportation costs
  double wastageBufferPercentage = 4.0; // 4% wastage/spoilage buffer
  bool isAutoPilotEnabled = false;

  /// Retrieves the simulated real-time wholesale Mandi market feed.
  /// Fluctuation is calculated deterministically per calendar day for consistent demo feedback.
  List<MandiMarketFeed> getMandiFeeds() {
    final today = DateTime.now();
    // Deterministic random seed based on day, month, year
    final seed = today.year * 10000 + today.month * 100 + today.day;
    final rand = Random(seed);

    return _baseMandiPrices.entries.map((entry) {
      final key = entry.key;
      final base = entry.value;

      // Simulate a daily swing of -12% to +15%
      final double swing = (rand.nextDouble() * 27.0) - 12.0;
      final current = base * (1 + swing / 100.0);

      String category = 'groceries';
      if ([
        'potato',
        'onion',
        'tomato',
        'coriander',
        'spinach',
        'cauliflower',
      ].contains(key)) {
        category = 'vegetables';
      } else if (['mango', 'banana', 'apple'].contains(key)) {
        category = 'fruits';
      } else if (['milk', 'paneer', 'ghee'].contains(key)) {
        category = 'dairy';
      }

      return MandiMarketFeed(
        itemName: _capitalize(key),
        category: category,
        baseMandiPrice: base,
        currentMandiPrice: double.parse(current.toStringAsFixed(1)),
        dailyChangePercentage: double.parse(swing.toStringAsFixed(1)),
      );
    }).toList();
  }

  /// Calculates Suggested Retail Price (SRP) adding markup, transport surcharge, and wastage buffers
  double calculateSuggestedRetailPrice(double mandiPrice) {
    final totalMultiplier =
        1.0 +
        (marginPercentage +
                transportChargePercentage +
                wastageBufferPercentage) /
            100.0;
    final suggested = mandiPrice * totalMultiplier;
    // Round to nearest rupee for clean customer pricing
    return suggested.roundToDouble();
  }

  /// Evaluates product names to map to appropriate mandi feed items
  MandiMarketFeed? matchProductToFeed(ProductModel product) {
    final nameLower = product.name.toLowerCase();
    final feeds = getMandiFeeds();
    for (final feed in feeds) {
      if (nameLower.contains(feed.itemName.toLowerCase())) {
        return feed;
      }
    }
    // Fallback search inside tag list
    for (final tag in product.tags) {
      for (final feed in feeds) {
        if (tag.toLowerCase() == feed.itemName.toLowerCase()) {
          return feed;
        }
      }
    }
    return null;
  }

  /// Automatically updates all eligible product prices matching current Mandi rates
  Future<int> autoUpdateEligibleProductPrices(
    List<ProductModel> allProducts,
  ) async {
    try {
      final config = await ShopConfigService().getShopConfig();
      if (!config.isAutoPilotEnabled) {
        return 0;
      }
    } catch (e) {
      // Fallback: If config load fails, don't run autopilot by default
      return 0;
    }

    final productService = ProductService();
    int updatedCount = 0;

    for (final product in allProducts) {
      // Only auto-price vegetables, fruits, and dairy
      final cat = product.category.toLowerCase();
      if (cat == 'vegetables' || cat == 'fruits' || cat == 'dairy') {
        final feed = matchProductToFeed(product);
        if (feed != null) {
          final srp = calculateSuggestedRetailPrice(feed.currentMandiPrice);
          // If price differs, perform update
          if ((product.price.toDouble() - srp).abs() > 0.1) {
            final updatedProd = product.copyWith(
              price: MonetaryValue(srp),
              originalPrice: MonetaryValue(srp),
              discountPercentage: MonetaryValue(0.0),
              updatedAt: DateTime.now(),
            );

            await productService.updateProduct(
              updatedProd.id,
              updatedProd.toMap(),
            );
            updatedCount++;
          }
        }
      }
    }
    return updatedCount;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }
}
