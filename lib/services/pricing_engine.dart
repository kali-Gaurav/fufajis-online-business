import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import 'notification_service.dart';
import 'analytics_service.dart';
import 'dynamic_pricing_config_service.dart';

/// Pricing Engine Service for Dynamic Price Adjustment & Competitor Matching
/// Automatically matches or beats competitor prices on basic items
class PricingEngineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final Uuid _uuid = const Uuid();

  // Dynamic configuration — all values loaded from Firestore via DynamicPricingConfigService
  final DynamicPricingConfigService _pricingConfig = DynamicPricingConfigService();
  static const int _priceHistoryDays = 90; // fallback, overridden by Firestore config

  // Collection references
  CollectionReference _productsCollection(String shopId) =>
      _firestore.collection('shops').doc(shopId).collection('products');

  CollectionReference _competitorPricesCollection(String shopId) =>
      _firestore.collection('shops').doc(shopId).collection('competitor_prices');

  CollectionReference _priceHistoryCollection(String productId) =>
      _firestore.collection('products').doc(productId).collection('price_history');

  CollectionReference _pricingRulesCollection(String shopId) =>
      _firestore.collection('shops').doc(shopId).collection('pricing_rules');

  CollectionReference _priceAlertsCollection(String shopId) =>
      _firestore.collection('shops').doc(shopId).collection('price_alerts');

  /// Competitor price data structure
  final Map<String, dynamic> competitorPrices = {};

  /// Add or update competitor price
  Future<void> updateCompetitorPrice({
    required String shopId,
    required String productName,
    required String competitorName,
    required double price,
    String? productCategory,
  }) async {
    final docId = '${productName.toLowerCase()}_${competitorName.toLowerCase()}';
    
    await _competitorPricesCollection(shopId).doc(docId).set({
      'productName': productName,
      'competitorName': competitorName,
      'price': price,
      'category': productCategory,
      'updatedAt': Timestamp.now(),
    });

    // Track analytics
    _analyticsService.trackEvent('competitor_price_updated', {
      'shopId': shopId,
      'productName': productName,
      'competitorName': competitorName,
      'price': price,
    });
  }

  /// Get competitor prices for a product
  Future<List<Map<String, dynamic>>> getCompetitorPrices(
    String shopId,
    String productName,
  ) async {
    final snapshot = await _competitorPricesCollection(shopId)
        .where('productName', isEqualTo: productName)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Get lowest competitor price
  Future<double?> getLowestCompetitorPrice(
    String shopId,
    String productName,
  ) async {
    final prices = await getCompetitorPrices(shopId, productName);
    if (prices.isEmpty) return null;

    return prices.map((p) => p['price'] as double).reduce(min);
  }

  /// Calculate optimal price based on competitors and rules
  Future<double> calculateOptimalPrice({
    required String shopId,
    required String productId,
    required double costPrice,
    required String productName,
    String? category,
    List<Map<String, dynamic>>? precalculatedCompetitorPrices,
  }) async {
    try {
      // Get competitor prices
      final competitorPrices = precalculatedCompetitorPrices ?? await getCompetitorPrices(shopId, productName);
      final lowestCompetitorPrice = competitorPrices.isNotEmpty
          ? competitorPrices.map((p) => p['price'] as double).reduce(min)
          : null;

      // Get dynamic pricing config (Firestore-driven, 15-min cached)
      final effectiveMarginPct = await _pricingConfig.getEffectiveMargin(
        shopId: shopId, category: category ?? 'other');
      final effectiveStrategy = await _pricingConfig.getEffectiveStrategy(
        shopId: shopId, category: category ?? 'other');
      final rules = await getPricingRules(shopId, category);
      final defaultRule = rules.firstWhere(
        (r) => r['isDefault'] == true,
        orElse: () => {
          'margin': effectiveMarginPct / 100.0,
          'strategy': effectiveStrategy,
          'isDefault': true,
        },
      );

      // Calculate base price
      double optimalPrice;
      final margin = (defaultRule['margin'] as double?) ?? (effectiveMarginPct / 100.0);
      final strategy = defaultRule['strategy'] as String;

      switch (strategy) {
        case 'beat':
          // Price slightly below lowest competitor
          if (lowestCompetitorPrice != null) {
            final beatThreshold = effectiveMarginPct / 100.0 * 0.4; // 40% of margin as beat gap
            optimalPrice = lowestCompetitorPrice * (1 - beatThreshold);
          } else {
            optimalPrice = costPrice * (1 + margin);
          }
          break;
        case 'match':
          // Match lowest competitor or use margin
          if (lowestCompetitorPrice != null) {
            optimalPrice = lowestCompetitorPrice;
          } else {
            optimalPrice = costPrice * (1 + margin);
          }
          break;
        case 'premium':
          // Price above competitors (premium positioning)
          if (lowestCompetitorPrice != null) {
            optimalPrice = lowestCompetitorPrice * (1 + margin);
          } else {
            optimalPrice = costPrice * (1 + margin * 2);
          }
          break;
        case 'cost_plus':
          // Simple cost plus margin
          optimalPrice = costPrice * (1 + margin);
          break;
        default:
          optimalPrice = costPrice * (1 + margin);
      }

      // Ensure price is above cost
      optimalPrice = max(optimalPrice, costPrice * 1.01);

      // Round to nearest rupee
      return optimalPrice.roundToDouble();
    } catch (e) {
      print('Error calculating optimal price: $e');
      return costPrice;
    }
  }

  Future<List<Map<String, dynamic>>> adjustPrices({
    required String shopId,
    bool autoApply = false,
  }) async {
    final now = DateTime.now();
    final priceChanges = <Map<String, dynamic>>[];

    try {
      // Pre-fetch all competitor prices for the shop
      final allCompetitorPricesSnapshot = await _competitorPricesCollection(shopId).get();
      final Map<String, List<Map<String, dynamic>>> competitorPricesByProduct = {};
      for (final doc in allCompetitorPricesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final productName = data['productName'] as String;
        competitorPricesByProduct.putIfAbsent(productName, () => []).add(data);
      }

      // Get all products
      final snapshot = await _productsCollection(shopId).get();

      for (final doc in snapshot.docs) {
        final product = ProductModel.fromMap(doc.data() as Map<String, dynamic>);
        
        // Skip if no cost price (can't calculate margin)
        // Skip non-competitor tracked items
        final competitorPrices = competitorPricesByProduct[product.name] ?? [];
        if (competitorPrices.isEmpty) continue;

        // Calculate optimal price
        final optimalPrice = await calculateOptimalPrice(
          shopId: shopId,
          productId: product.id,
          costPrice: product.price * 0.8, // Assume 20% margin
          productName: product.name,
          category: product.category,
          precalculatedCompetitorPrices: competitorPrices,
        );

        // Check if price change is needed (threshold read from dynamic config)
        final priceDifference = (optimalPrice - product.price) / product.price;
        final globalConfig = await _pricingConfig.getGlobalConfig();
        final matchThreshold = globalConfig.defaultCompetitorMatchThreshold / 100.0;
        
        if (priceDifference.abs() > matchThreshold) {
          final change = {
            'productId': product.id,
            'productName': product.name,
            'currentPrice': product.price,
            'newPrice': optimalPrice,
            'changePercentage': (priceDifference * 100).round(),
            'reason': 'competitor_price_match',
            'createdAt': now,
          };

          if (autoApply) {
            await _applyPriceChange(shopId, product.id, optimalPrice, now);
            priceChanges.add(change);
          } else {
            // Save as pending change
            await _savePendingChange(shopId, product.id, change);
            priceChanges.add({...change, 'status': 'pending'});
          }
        }
      }

      // Track analytics
      if (priceChanges.isNotEmpty) {
        _analyticsService.trackEvent('price_adjustments_analyzed', {
          'shopId': shopId,
          'count': priceChanges.length,
          'autoApplied': autoApply,
        });
      }

      return priceChanges;
    } catch (e) {
      print('Error adjusting prices: $e');
      return [];
    }
  }

  /// Apply price change
  Future<void> _applyPriceChange(
    String shopId,
    String productId,
    double newPrice,
    DateTime now,
  ) async {
    // Get current price
    final productDoc = await _firestore.collection('products').doc(productId).get();
    final product = ProductModel.fromMap(productDoc.data() as Map<String, dynamic>);
    final oldPrice = product.price;

    // Update product price
    await _firestore.collection('products').doc(productId).update({
      'price': newPrice,
      'originalPrice': product.originalPrice ?? oldPrice,
      'updatedAt': Timestamp.fromDate(now),
    });

    // Save to price history
    await _priceHistoryCollection(productId).add({
      'oldPrice': oldPrice,
      'newPrice': newPrice,
      'reason': 'competitor_price_match',
      'createdAt': Timestamp.now(),
    });

    // Clean up old history
    final cutoff = now.subtract(const Duration(days: _priceHistoryDays));
    final oldDocs = await _priceHistoryCollection(productId)
        .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
        .get();
    for (final doc in oldDocs.docs) {
      await doc.reference.delete();
    }
  }

  /// Save pending price change
  Future<void> _savePendingChange(
    String shopId,
    String productId,
    Map<String, dynamic> change,
  ) async {
    await _priceAlertsCollection(shopId).doc(productId).set({
      ...change,
      'status': 'pending',
      'createdAt': Timestamp.now(),
    });
  }

  /// Approve pending price change
  Future<void> approvePriceChange(String shopId, String productId) async {
    final doc = await _priceAlertsCollection(shopId).doc(productId).get();
    if (!doc.exists) return;

    final change = doc.data() as Map<String, dynamic>;
    await _applyPriceChange(
      shopId,
      productId,
      change['newPrice'] as double,
      DateTime.now(),
    );

    await _priceAlertsCollection(shopId).doc(productId).delete();
  }

  /// Reject pending price change
  Future<void> rejectPriceChange(String shopId, String productId, String reason) async {
    await _priceAlertsCollection(shopId).doc(productId).update({
      'status': 'rejected',
      'rejectedReason': reason,
      'rejectedAt': Timestamp.now(),
    });
  }

  /// Get pricing rules for a shop
  Future<List<Map<String, dynamic>>> getPricingRules(
    String shopId, [
    String? category,
  ]) async {
    Query query = _pricingRulesCollection(shopId).orderBy('priority', descending: true);
    
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Add or update pricing rule
  Future<void> setPricingRule({
    required String shopId,
    required String name,
    required String strategy,
    required double margin,
    String? category,
    bool isDefault = false,
  }) async {
    final ruleId = category != null ? 'rule_$category' : 'rule_default';
    
    await _pricingRulesCollection(shopId).doc(ruleId).set({
      'name': name,
      'strategy': strategy,
      'margin': margin,
      'category': category,
      'isDefault': isDefault,
      'priority': category != null ? 1 : 0,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Get price history for a product
  Stream<List<Map<String, dynamic>>> getPriceHistory(String productId) {
    return _priceHistoryCollection(productId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get pending price changes
  Stream<List<Map<String, dynamic>>> getPendingPriceChanges(String shopId) {
    return _priceAlertsCollection(shopId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get price analytics for a shop
  Future<Map<String, dynamic>> getPriceAnalytics(String shopId) async {
    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));

    try {
      // Get all products
      final productsSnapshot = await _productsCollection(shopId).get();
      final products = productsSnapshot.docs
          .map((doc) => ProductModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      // Calculate average prices
      double totalPrice = 0;
      int priceChangeCount = 0;
      double totalChangePercentage = 0;

      for (final product in products) {
        totalPrice += product.price;
        
        // Get price changes in last 30 days
        final changesSnapshot = await _priceHistoryCollection(product.id)
            .where('createdAt', isGreaterThan: Timestamp.fromDate(monthAgo))
            .get();
        
        for (final changeDoc in changesSnapshot.docs) {
          final change = changeDoc.data() as Map<String, dynamic>;
          priceChangeCount++;
          totalChangePercentage += ((change['newPrice'] as num) - (change['oldPrice'] as num)) / (change['oldPrice'] as num) * 100;
        }
      }

      final avgPrice = products.isNotEmpty ? totalPrice / products.length : 0;
      final avgChange = priceChangeCount > 0 ? totalChangePercentage / priceChangeCount : 0;

      // Get competitor coverage
      final competitorCount = await _competitorPricesCollection(shopId).count().get();
      final productsWithCompetitors = products.where((p) => 
        p.name.toLowerCase().contains('sugar') || 
        p.name.toLowerCase().contains('flour') || 
        p.name.toLowerCase().contains('rice')
      ).length;

      return {
        'totalProducts': products.length,
        'averagePrice': avgPrice.round(),
        'priceChanges30Days': priceChangeCount,
        'averageChangePercentage': avgChange.round(),
        'competitorPricesTracked': competitorCount.count,
        'productsWithCompetitors': productsWithCompetitors,
        'generatedAt': now,
      };
    } catch (e) {
      print('Error getting price analytics: $e');
      return {
        'totalProducts': 0,
        'averagePrice': 0,
        'priceChanges30Days': 0,
        'averageChangePercentage': 0,
      };
    }
  }

  /// Send price change notifications
  Future<void> sendPriceChangeNotifications(String shopId) async {
    try {
      final pendingChanges = await _priceAlertsCollection(shopId)
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      if (pendingChanges.count == 0) return;

      // Get shop owner
      final shopDoc = await _firestore.collection('shops').doc(shopId).get();
      final ownerId = shopDoc.data()?['ownerId'];

      if (ownerId == null) return;

      await _notificationService.sendNotificationToUser(
        userId: ownerId,
        title: '💰 Price Update Recommendations',
        body: '${pendingChanges.count} products have price recommendations based on competitor analysis.',
        data: {
          'type': 'price_recommendations',
          'shopId': shopId,
          'count': pendingChanges.count.toString(),
        },
      );
    } catch (e) {
      print('Error sending price notifications: $e');
    }
  }

  /// Simulate competitor price check (for demo/testing)
  Future<Map<String, double>> simulateCompetitorCheck(String productName) async {
    // In production, this would call actual competitor APIs
    // For demo, generate realistic mock data
    final basePrice = 50.0 + Random().nextDouble() * 100;
    
    return {
      'competitor_a': basePrice * (0.95 + Random().nextDouble() * 0.1),
      'competitor_b': basePrice * (0.92 + Random().nextDouble() * 0.12),
      'competitor_c': basePrice * (0.98 + Random().nextDouble() * 0.08),
      'market_average': basePrice,
    };
  }

  /// Bulk import competitor prices
  Future<void> bulkImportCompetitorPrices(
    String shopId,
    List<Map<String, dynamic>> prices,
  ) async {
    final batch = _firestore.batch();

    for (final price in prices) {
      final docId = '${price['productName'].toString().toLowerCase()}_${price['competitorName'].toString().toLowerCase()}';
      final docRef = _competitorPricesCollection(shopId).doc(docId);
      batch.set(docRef, {
        ...price,
        'updatedAt': Timestamp.now(),
      });
    }

    await batch.commit();

    _analyticsService.trackEvent('competitor_prices_bulk_import', {
      'shopId': shopId,
      'count': prices.length,
    });
  }

  /// Get price comparison report
  Future<Map<String, dynamic>> getPriceComparisonReport(String shopId) async {
    final now = DateTime.now();
    
    try {
      // Get all competitor prices
      final competitorSnapshot = await _competitorPricesCollection(shopId).get();
      
      // Group by product
      final productPrices = <String, List<Map<String, dynamic>>>{};
      for (final doc in competitorSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final productName = data['productName'] as String;
        productPrices.putIfAbsent(productName, () => []).add(data);
      }

      // Calculate comparisons
      final comparisons = <Map<String, dynamic>>[];
      for (final entry in productPrices.entries) {
        final prices = entry.value;
        final myPrice = await getMyPrice(entry.key);
        final lowestCompetitor = prices.map((p) => p['price'] as double).reduce(min);
        final highestCompetitor = prices.map((p) => p['price'] as double).reduce(max);
        
        comparisons.add({
          'productName': entry.key,
          'myPrice': myPrice,
          'lowestCompetitor': lowestCompetitor,
          'highestCompetitor': highestCompetitor,
          'marketPosition': myPrice == null ? 'unknown' :
                           (myPrice <= lowestCompetitor ? 'lowest' : 
                            (myPrice >= highestCompetitor ? 'highest' : 'middle')),
          'competitorCount': prices.length,
        });
      }

      return {
        'generatedAt': now,
        'totalProductsTracked': comparisons.length,
        'comparisons': comparisons,
        'summary': {
          'lowestPriceCount': comparisons.where((c) => c['marketPosition'] == 'lowest').length,
          'highestPriceCount': comparisons.where((c) => c['marketPosition'] == 'highest').length,
          'middlePriceCount': comparisons.where((c) => c['marketPosition'] == 'middle').length,
        },
      };
    } catch (e) {
      print('Error getting price comparison: $e');
      return {
        'totalProductsTracked': 0,
        'comparisons': [],
        'summary': {},
      };
    }
  }

  /// Get my price for a product
  Future<double?> getMyPrice(String productName) async {
    final snapshot = await _firestore
        .collectionGroup('products')
        .where('name', isEqualTo: productName)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    
    final product = ProductModel.fromMap(snapshot.docs.first.data() as Map<String, dynamic>);
    return product.price;
  }
}
