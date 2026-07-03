import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:fufajis_online/models/pricing_models.dart';
import 'package:fufajis_online/services/logging_service.dart';

/// Pricing Expert Agent Service
/// Analyzes products and recommends optimal pricing strategies:
/// - Dynamic pricing based on stock, demand, competition
/// - Margin optimization
/// - Bundle & discount strategy
class PricingExpertService {
  final FirebaseFirestore _firestore;
  final GenerativeModel _geminiModel;
  final String shopId;

  PricingExpertService({
    required this.shopId,
    required FirebaseFirestore firestore,
    required GenerativeModel geminiModel,
  }) : _firestore = firestore,
       _geminiModel = geminiModel;

  /// ==========================================
  /// MAIN ENTRY POINTS
  /// ==========================================

  /// Analyze a single product and generate pricing recommendation
  Future<PricingRecommendation?> analyzeSingleProduct(String productId) async {
    try {
      LoggingService().info('🔍 Pricing Expert analyzing product: $productId');

      // Fetch product data
      final productDoc = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .doc(productId)
          .get();

      if (!productDoc.exists) {
        LoggingService().warning('Product not found: $productId');
        return null;
      }

      final productData = productDoc.data()!;

      // Fetch inventory data
      final inventoryDoc = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('inventory')
          .doc(productId)
          .get();

      final stock = inventoryDoc.exists ? inventoryDoc['quantity'] as int : 0;

      // Fetch sales history (last 30 days)
      final ordersSnapshot = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('orders')
          .where('items', arrayContains: productId)
          .where(
            'createdAt',
            isGreaterThan: Timestamp.now().toDate().subtract(const Duration(days: 30)),
          )
          .get();

      final salesCount = ordersSnapshot.docs.length;
      final salesVelocity = salesCount / 30; // sales per day

      // Fetch reviews for product feedback
      final reviewsSnapshot = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('product_reviews')
          .where('productId', isEqualTo: productId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final avgRating = reviewsSnapshot.docs.isEmpty
          ? 4.0
          : reviewsSnapshot.docs
                    .map((d) => (d['rating'] as num).toDouble())
                    .reduce((a, b) => a + b) /
                reviewsSnapshot.docs.length;

      // Generate recommendation using Gemini
      return _generatePricingRecommendation(
        productId: productId,
        productData: productData,
        stock: stock,
        salesVelocity: salesVelocity,
        avgRating: avgRating,
        reviews: reviewsSnapshot.docs,
      );
    } catch (e) {
      LoggingService().error('Error analyzing product $productId: $e');
      return null;
    }
  }

  /// Analyze all active products and generate recommendations
  Future<List<PricingRecommendation>> analyzeAllProducts() async {
    try {
      LoggingService().info('🔍 Pricing Expert analyzing all products...');

      final productsSnapshot = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .where('status', isEqualTo: 'ACTIVE')
          .get();

      final recommendations = <PricingRecommendation>[];

      for (final productDoc in productsSnapshot.docs) {
        final rec = await analyzeSingleProduct(productDoc.id);
        if (rec != null) {
          recommendations.add(rec);
        }
      }

      LoggingService().info('✅ Generated ${recommendations.length} pricing recommendations');
      return recommendations;
    } catch (e) {
      LoggingService().error('Error analyzing all products: $e');
      return [];
    }
  }

  /// Get pending recommendations for approval
  Future<List<PricingRecommendation>> getPendingRecommendations() async {
    try {
      final snapshot = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('pricing_recommendations')
          .where('status', isEqualTo: 'PENDING')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => PricingRecommendation.fromJson(doc.data())).toList();
    } catch (e) {
      LoggingService().error('Error fetching pending recommendations: $e');
      return [];
    }
  }

  /// Approve a recommendation and apply the pricing change
  Future<bool> approveRecommendation(String recommendationId, {double? overridePrice}) async {
    try {
      LoggingService().info('✅ Approving recommendation: $recommendationId');

      final recDoc = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('pricing_recommendations')
          .doc(recommendationId)
          .get();

      if (!recDoc.exists) {
        LoggingService().warning('Recommendation not found: $recommendationId');
        return false;
      }

      final rec = PricingRecommendation.fromJson(recDoc.data()!);
      final finalPrice = overridePrice ?? rec.recommendations.dynamicPrice.suggestedPrice;

      // Update recommendation status
      await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('pricing_recommendations')
          .doc(recommendationId)
          .update({
            'status': 'APPROVED',
            'approvedAt': FieldValue.serverTimestamp(),
            'editedPrice': overridePrice,
            'statusHistory': FieldValue.arrayUnion([
              {
                'status': 'APPROVED',
                'changedAt': FieldValue.serverTimestamp(),
                'changedBy': 'user',
              },
            ]),
          });

      // Apply price change to product
      await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .doc(rec.productId)
          .update({
            'priceHistory.previousPrice': rec.recommendations.dynamicPrice.currentPrice,
            'priceHistory.currentPrice': finalPrice,
            'priceHistory.priceChangedAt': FieldValue.serverTimestamp(),
            'priceHistory.priceChangeReason': 'Pricing Expert recommendation (dynamic)',
          });

      LoggingService().info(
        '💰 Price updated: ₹${rec.recommendations.dynamicPrice.currentPrice} → ₹$finalPrice',
      );
      return true;
    } catch (e) {
      LoggingService().error('Error approving recommendation: $e');
      return false;
    }
  }

  /// Reject a recommendation
  Future<bool> rejectRecommendation(
    String recommendationId, {
    String reason = 'User rejected',
  }) async {
    try {
      LoggingService().info('❌ Rejecting recommendation: $recommendationId');

      await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('pricing_recommendations')
          .doc(recommendationId)
          .update({
            'status': 'REJECTED',
            'rejectionReason': reason,
            'statusHistory': FieldValue.arrayUnion([
              {
                'status': 'REJECTED',
                'changedAt': FieldValue.serverTimestamp(),
                'changedBy': 'user',
                'reason': reason,
              },
            ]),
          });

      LoggingService().info('Recommendation rejected: $reason');
      return true;
    } catch (e) {
      LoggingService().error('Error rejecting recommendation: $e');
      return false;
    }
  }

  /// ==========================================
  /// CORE PRICING LOGIC
  /// ==========================================

  /// Generate pricing recommendation using multi-step analysis
  Future<PricingRecommendation> _generatePricingRecommendation({
    required String productId,
    required Map<String, dynamic> productData,
    required int stock,
    required double salesVelocity,
    required double avgRating,
    required List<QueryDocumentSnapshot> reviews,
  }) async {
    final currentPrice = (productData['price'] as num).toDouble();
    final cost = (productData['cost'] as num?)?.toDouble() ?? 0.0;
    final description = productData['description'] as String? ?? '';

    // 1. Dynamic Price Analysis
    final dynamicRec = _calculateDynamicPrice(
      currentPrice: currentPrice,
      stock: stock,
      salesVelocity: salesVelocity,
      avgRating: avgRating,
    );

    // 2. Margin Analysis
    final marginRec = _calculateMarginAnalysis(currentPrice: currentPrice, cost: cost);

    // 3. Bundle Opportunity Analysis (using Gemini)
    final bundleRec = await _calculateBundleOpportunity(
      productId: productId,
      productName: productData['name'] as String? ?? 'Unknown',
      description: description,
      avgRating: avgRating,
      reviews: reviews,
    );

    // Create recommendation document
    final recommendation = PricingRecommendation(
      id: 'price_rec_${DateTime.now().millisecondsSinceEpoch}',
      shopId: shopId,
      productId: productId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      agentVersion: 'pricing_expert_v1.0',
      recommendations: PricingRecommendations(
        dynamicPrice: dynamicRec,
        marginAnalysis: marginRec,
        bundleOpportunity: bundleRec,
      ),
      status: 'PENDING',
      approvedAt: null,
      rejectionReason: null,
    );

    // Save to Firestore
    await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('pricing_recommendations')
        .doc(recommendation.id)
        .set(recommendation.toJson());

    LoggingService().info('💾 Saved recommendation: ${recommendation.id}');
    return recommendation;
  }

  /// Calculate dynamic pricing based on stock, velocity, and rating
  DynamicPriceRecommendation _calculateDynamicPrice({
    required double currentPrice,
    required int stock,
    required double salesVelocity,
    required double avgRating,
  }) {
    double suggestedPrice = currentPrice;
    String reason = '';
    double confidence = 0.7;
    List<String> triggers = [];

    // Rule 1: Stock-based scarcity pricing
    if (stock < 5) {
      const premiumFactor = 1.15; // +15%
      suggestedPrice *= premiumFactor;
      reason = 'Stock critically low ($stock units); apply scarcity premium';
      triggers.add('low_stock');
      confidence = 0.92;
    } else if (stock < 10) {
      const premiumFactor = 1.08; // +8%
      suggestedPrice *= premiumFactor;
      reason = 'Stock low ($stock units); apply modest premium';
      triggers.add('low_stock');
      confidence = 0.85;
    } else if (stock > 50) {
      const discountFactor = 0.95; // -5%
      suggestedPrice *= discountFactor;
      reason = 'Excess inventory ($stock units); apply discount to clear';
      triggers.add('high_stock');
      confidence = 0.80;
    }

    // Rule 2: Rating-based pricing (higher rating = can sustain higher price)
    if (avgRating >= 4.5) {
      suggestedPrice *= 1.05; // +5% for excellent reviews
      reason += ' | Strong rating ($avgRating★) justifies premium';
      triggers.add('high_rating');
    } else if (avgRating < 3.0) {
      suggestedPrice *= 0.92; // -8% for poor reviews
      reason += ' | Low rating ($avgRating★) needs price incentive';
      triggers.add('low_rating');
    }

    // Rule 3: Velocity-based optimization
    if (salesVelocity < 0.5) {
      // Less than 1 sale per 2 days
      suggestedPrice *= 0.97; // -3% to stimulate demand
      reason += ' | Low sales velocity ($salesVelocity/day); encourage volume';
      triggers.add('low_velocity');
    } else if (salesVelocity > 2.0) {
      // More than 2 sales per day
      suggestedPrice *= 1.03; // +3% due to high demand
      reason += ' | High demand ($salesVelocity/day); price up slightly';
      triggers.add('high_velocity');
      confidence = min(confidence + 0.05, 0.95);
    }

    // Round to nearest ₹5
    suggestedPrice = (suggestedPrice / 5).round() * 5;

    final priceChangePercent = ((suggestedPrice - currentPrice) / currentPrice * 100);

    return DynamicPriceRecommendation(
      currentPrice: currentPrice,
      suggestedPrice: suggestedPrice,
      reason: reason.trim(),
      confidence: confidence,
      triggers: triggers,
      estimatedRevenueLift: (suggestedPrice - currentPrice) * 20, // Assume 20 sales/month
    );
  }

  /// Calculate margin analysis and warnings
  MarginAnalysisRecommendation _calculateMarginAnalysis({
    required double currentPrice,
    required double cost,
  }) {
    final marginPercent = cost > 0 ? ((currentPrice - cost) / currentPrice * 100) : 0.0;

    String marginalCategory = 'MEDIUM';
    bool warningFlag = false;
    String notes = '';

    if (marginPercent >= 40) {
      marginalCategory = 'HIGH';
      notes = 'Excellent margin; healthy profitability';
    } else if (marginPercent >= 25) {
      marginalCategory = 'MEDIUM';
      notes = 'Acceptable margin; meets retail minimum';
    } else if (marginPercent > 0) {
      marginalCategory = 'LOW';
      warningFlag = true;
      notes = 'Low margin; consider price increase or cost reduction';
    } else {
      marginalCategory = 'LOSS';
      warningFlag = true;
      notes = 'LOSS-MAKING PRODUCT: Selling below cost!';
    }

    // Calculate price floor for 30% margin target
    const targetMarginPercent = 30.0;
    final priceFloorFor30Margin = cost / (1 - targetMarginPercent / 100);

    return MarginAnalysisRecommendation(
      cost: cost,
      currentMarginPercent: marginPercent,
      projectedMarginPercent: marginPercent, // Same for now
      marginalCategory: marginalCategory,
      warningFlag: warningFlag,
      notes: notes,
      priceFloorFor30Margin: priceFloorFor30Margin,
    );
  }

  /// Calculate bundle opportunity using Gemini
  Future<BundleOpportunityRecommendation?> _calculateBundleOpportunity({
    required String productId,
    required String productName,
    required String description,
    required double avgRating,
    required List<QueryDocumentSnapshot> reviews,
  }) async {
    try {
      // Extract review themes
      final reviewTexts = reviews
          .map((r) => r['review'] as String? ?? '')
          .where((r) => r.isNotEmpty)
          .take(5)
          .toList();

      // Fetch similar products
      final similarProducts = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .limit(20)
          .get();

      final similarNames = similarProducts.docs
          .where((doc) => doc.id != productId)
          .map((doc) => '${doc['name']} (${doc.id})')
          .take(5)
          .toList();

      // Use Gemini to suggest bundles
      final prompt =
          '''
You are a retail pricing expert. Analyze this product and suggest a bundle opportunity.

Product: $productName
Description: $description
Rating: $avgRating ⭐
Recent reviews: ${reviewTexts.join('; ')}

Other available products: ${similarNames.join(', ')}

Based on this product and the available catalog, suggest ONE compelling bundle:
1. Bundle name (e.g., "Dad Grooming Combo")
2. Why these products go together
3. Suggested discount (10-15%)

Respond in JSON format:
{
  "bundleName": "...",
  "description": "...",
  "discountPercent": 12,
  "estimatedLift": "...",
  "confidence": 0.78
}
''';

      final response = await _geminiModel.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '{"bundleName": null, "description": null}';

      // Parse JSON response
      final jsonStr = responseText.replaceAll('```json', '').replaceAll('```', '').trim();

      // Mock bundle data (in production, parse actual JSON from Gemini)
      return BundleOpportunityRecommendation(
        bundleName: 'Dad Essentials Bundle',
        description: 'Curated set of must-haves for the modern dad',
        productIds: [productId],
        suggestedBundlePrice: 1299.0,
        individualTotal: 1449.0,
        bundleDiscount: 150.0,
        discountPercent: 10.35,
        estimatedLift: BundleLift(aovIncrease: '₹200', adoptionRate: '12%'),
        confidence: 0.78,
      );
    } catch (e) {
      LoggingService().warning('Error generating bundle opportunity: $e');
      return null;
    }
  }

  /// ==========================================
  /// UTILITY METHODS
  /// ==========================================

  /// Generate monthly pricing report
  Future<Map<String, dynamic>> generateMonthlyReport() async {
    try {
      final allProducts = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .where('status', isEqualTo: 'ACTIVE')
          .get();

      double totalRevenue = 0;
      double totalCost = 0;
      int highMarginCount = 0;
      int lowMarginCount = 0;
      List<Map<String, dynamic>> lowMarginProducts = [];

      for (final doc in allProducts.docs) {
        final data = doc.data();
        final price = (data['price'] as num?)?.toDouble() ?? 0.0;
        final cost = (data['cost'] as num?)?.toDouble() ?? 0.0;

        totalRevenue += price;
        totalCost += cost;

        final margin = cost > 0 ? ((price - cost) / price * 100) : 0.0;

        if (margin >= 40) {
          highMarginCount++;
        } else if (margin < 25) {
          lowMarginCount++;
          lowMarginProducts.add({
            'productId': doc.id,
            'name': data['name'],
            'price': price,
            'cost': cost,
            'margin': margin,
          });
        }
      }

      final avgMargin = allProducts.docs.isEmpty
          ? 0.0
          : (totalRevenue - totalCost) / totalRevenue * 100;

      return {
        'period': 'Monthly Report - ${DateTime.now().toIso8601String().split('T')[0]}',
        'totalProducts': allProducts.docs.length,
        'averageMargin': avgMargin,
        'highMarginProducts': highMarginCount,
        'lowMarginProducts': lowMarginCount,
        'lowMarginDetails': lowMarginProducts,
        'recommendations': lowMarginCount > 5
            ? 'High number of low-margin products; review pricing strategy'
            : 'Margin health is good',
      };
    } catch (e) {
      LoggingService().error('Error generating monthly report: $e');
      return {};
    }
  }

  double min(double a, double b) => a < b ? a : b;
}
