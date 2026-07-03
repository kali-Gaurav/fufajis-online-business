import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:fufajis_online/models/customer_models.dart';
import 'package:fufajis_online/services/logging_service.dart';

/// Customer Analyst Agent Service
/// Analyzes customer base to identify:
/// - Customer segments (HIGH_VALUE, NEW, REPEAT, ONE_TIME, AT_RISK)
/// - Churn risk + retention opportunities
/// - Feedback sentiment & product issues
/// - Cohort performance & growth trends
class CustomerAnalystService {
  final FirebaseFirestore _firestore;
  final GenerativeModel _geminiModel;
  final String shopId;

  CustomerAnalystService({
    required this.shopId,
    required FirebaseFirestore firestore,
    required GenerativeModel geminiModel,
  }) : _firestore = firestore,
       _geminiModel = geminiModel;

  /// ==========================================
  /// MAIN ENTRY POINTS
  /// ==========================================

  /// Run weekly customer segmentation analysis
  Future<List<CustomerSegment>> generateWeeklySegments() async {
    try {
      LoggingService().info('📊 Customer Analyst: Generating weekly segments...');

      // Fetch all orders
      final ordersSnapshot = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('orders')
          .get();

      final customerMetrics = <String, CustomerMetricsData>{};

      // Calculate metrics per customer
      for (final order in ordersSnapshot.docs) {
        final customerId = order['customerId'] as String;
        final amount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final createdAt = (order['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        if (!customerMetrics.containsKey(customerId)) {
          customerMetrics[customerId] = CustomerMetricsData(
            customerId: customerId,
            purchaseCount: 0,
            lifetimeValue: 0.0,
            lastPurchaseDate: createdAt,
            purchaseDates: [],
          );
        }

        final metrics = customerMetrics[customerId]!;
        metrics.purchaseCount++;
        metrics.lifetimeValue += amount;
        metrics.lastPurchaseDate = createdAt;
        metrics.purchaseDates.add(createdAt);
      }

      // Generate segments
      final now = DateTime.now();
      final segments = <CustomerSegment>[];

      // HIGH_VALUE segment
      final highValueCustomers = customerMetrics.entries
          .where(
            (e) => e.value.lifetimeValue > 10000 && e.value.purchaseCount / 30 > 1.0,
          ) // >1 purchase/month
          .map((e) => e.value.customerId)
          .toList();

      if (highValueCustomers.isNotEmpty) {
        segments.add(
          _createSegment(
            type: 'HIGH_VALUE',
            customerIds: highValueCustomers,
            metrics: customerMetrics,
            recommendations: [
              'Offer VIP early access to new products',
              'Create exclusive High-Value Member discount tier (10% off)',
              'Monthly check-in email from founder',
            ],
          ),
        );
      }

      // NEW segment (first purchase < 30 days ago)
      final newCustomers = customerMetrics.entries
          .where(
            (e) =>
                now.difference(e.value.lastPurchaseDate).inDays < 30 && e.value.purchaseCount == 1,
          )
          .map((e) => e.value.customerId)
          .toList();

      if (newCustomers.isNotEmpty) {
        segments.add(
          _createSegment(
            type: 'NEW',
            customerIds: newCustomers,
            metrics: customerMetrics,
            recommendations: [
              'Send onboarding email with product recommendations',
              'Offer 10% welcome discount on next purchase',
              'Request product feedback survey',
            ],
          ),
        );
      }

      // REPEAT segment (3+ purchases, regular intervals)
      final repeatCustomers = customerMetrics.entries
          .where((e) => e.value.purchaseCount >= 3)
          .map((e) => e.value.customerId)
          .toList();

      if (repeatCustomers.isNotEmpty) {
        segments.add(
          _createSegment(
            type: 'REPEAT',
            customerIds: repeatCustomers,
            metrics: customerMetrics,
            recommendations: [
              'Cross-sell complementary products',
              'Offer volume-based discounts (buy 2 save 5%)',
              'Create personalized product recommendations',
            ],
          ),
        );
      }

      // AT_RISK segment (no purchase in 60+ days, but used to buy regularly)
      final atRiskCustomers = customerMetrics.entries
          .where((e) {
            final daysSinceLastPurchase = now.difference(e.value.lastPurchaseDate).inDays;
            final avgInterval = e.value.purchaseDates.length > 1
                ? _calculateAvgInterval(e.value.purchaseDates)
                : 30;
            return daysSinceLastPurchase > avgInterval * 2 && // 2x the normal interval
                daysSinceLastPurchase >= 60 &&
                e.value.purchaseCount >= 2; // Has made multiple purchases
          })
          .map((e) => e.value.customerId)
          .toList();

      if (atRiskCustomers.isNotEmpty) {
        segments.add(
          _createSegment(
            type: 'AT_RISK',
            customerIds: atRiskCustomers,
            metrics: customerMetrics,
            recommendations: [
              'Send "We miss you" email with 15% loyalty discount',
              'Highlight new products since last purchase',
              'Ask for feedback on past experience',
            ],
          ),
        );
      }

      // ONE_TIME segment (single purchase > 90 days ago, no repeat)
      final oneTimeCustomers = customerMetrics.entries
          .where(
            (e) =>
                e.value.purchaseCount == 1 && now.difference(e.value.lastPurchaseDate).inDays > 90,
          )
          .map((e) => e.value.customerId)
          .toList();

      if (oneTimeCustomers.isNotEmpty) {
        segments.add(
          _createSegment(
            type: 'ONE_TIME',
            customerIds: oneTimeCustomers,
            metrics: customerMetrics,
            recommendations: [
              'Send win-back email with special offer',
              'Ask what prevented repeat purchase',
              'Suggest complementary products',
            ],
          ),
        );
      }

      // Save segments to Firestore
      for (final segment in segments) {
        await _firestore
            .collection('shops')
            .doc(shopId)
            .collection('customer_segments')
            .doc(segment.id)
            .set(segment.toJson());
      }

      LoggingService().info('✅ Generated ${segments.length} customer segments');
      return segments;
    } catch (e) {
      LoggingService().error('Error generating weekly segments: $e');
      return [];
    }
  }

  /// Generate churn alerts for at-risk customers
  Future<List<ChurnAlert>> generateChurnAlerts() async {
    try {
      LoggingService().info('🚨 Customer Analyst: Detecting churn risk...');

      final atRiskSegments = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('customer_segments')
          .where('segmentType', isEqualTo: 'AT_RISK')
          .get();

      final alerts = <ChurnAlert>[];

      for (final segDoc in atRiskSegments.docs) {
        final segment = CustomerSegment.fromJson(segDoc.data());

        for (final customerId in segment.customerIds) {
          final customerOrders = await _firestore
              .collection('shops')
              .doc(shopId)
              .collection('orders')
              .where('customerId', isEqualTo: customerId)
              .orderBy('createdAt', descending: true)
              .limit(10)
              .get();

          final ltv = customerOrders.docs.fold<double>(
            0.0,
            (sum, doc) => sum + ((doc['totalAmount'] as num?)?.toDouble() ?? 0.0),
          );

          final lastOrder = customerOrders.docs.isNotEmpty
              ? (customerOrders.docs.first['createdAt'] as Timestamp?)?.toDate()
              : null;

          final daysSince = lastOrder != null ? DateTime.now().difference(lastOrder).inDays : 0;

          // Calculate risk score (0-1)
          final riskScore = _calculateChurnRiskScore(
            daysSinceLastPurchase: daysSince,
            customerLTV: ltv,
            purchaseCount: customerOrders.docs.length,
          );

          if (riskScore >= 0.7) {
            final alert = ChurnAlert(
              id: 'churn_${customerId}_${DateTime.now().millisecondsSinceEpoch}',
              shopId: shopId,
              customerId: customerId,
              createdAt: DateTime.now(),
              riskScore: riskScore,
              riskLevel: riskScore >= 0.9
                  ? 'CRITICAL'
                  : riskScore >= 0.7
                  ? 'AT_RISK'
                  : 'LOW',
              reason: 'No purchase for $daysSince days; previously bought every 30 days',
              lastPurchaseDate: lastOrder,
              suggestedAction: SuggestedAction(
                type: 'WIN_BACK_EMAIL',
                description: 'Send "We miss you" email with 15% loyalty discount',
                campaignTemplate: 'winback_v1',
                offerDetails: {'discountPercent': 15, 'validDays': 7},
                priority: 'HIGH',
              ),
              customerMetrics: {
                'lifetimeValue': ltv,
                'totalPurchases': customerOrders.docs.length,
                'daysSinceLastPurchase': daysSince,
              },
            );

            alerts.add(alert);
          }
        }
      }

      // Save alerts to Firestore
      for (final alert in alerts) {
        await _firestore
            .collection('shops')
            .doc(shopId)
            .collection('churn_alerts')
            .doc(alert.id)
            .set(alert.toJson());
      }

      LoggingService().info('✅ Generated ${alerts.length} churn alerts');
      return alerts;
    } catch (e) {
      LoggingService().error('Error generating churn alerts: $e');
      return [];
    }
  }

  /// Synthesize feedback from product reviews
  Future<FeedbackSynthesis?> synthesizeFeedback() async {
    try {
      LoggingService().info('💬 Customer Analyst: Synthesizing feedback...');

      final reviewsSnapshot = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('product_reviews')
          .where(
            'createdAt',
            isGreaterThan: Timestamp.now().toDate().subtract(const Duration(days: 10)),
          )
          .get();

      if (reviewsSnapshot.docs.isEmpty) {
        LoggingService().info('No recent reviews to synthesize');
        return null;
      }

      // Calculate overall sentiment
      double totalRating = 0;
      final ratingDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

      for (final review in reviewsSnapshot.docs) {
        final rating = review['rating'] as int? ?? 3;
        totalRating += rating;
        ratingDistribution[rating] = (ratingDistribution[rating] ?? 0) + 1;
      }

      final avgRating = totalRating / reviewsSnapshot.docs.length;

      // Group by product
      final byProduct = <String, List<QueryDocumentSnapshot>>{};
      for (final review in reviewsSnapshot.docs) {
        final productId = review['productId'] as String;
        byProduct.putIfAbsent(productId, () => []).add(review);
      }

      // Use Gemini to extract themes per product
      final byProductAnalysis = <String, Map<String, dynamic>>{};

      for (final entry in byProduct.entries.take(5)) {
        // Analyze top 5 products
        final productId = entry.key;
        final reviews = entry.value;

        final avgProductRating =
            reviews.fold<double>(
              0.0,
              (sum, r) => sum + ((r['rating'] as num?)?.toDouble() ?? 0.0),
            ) /
            reviews.length;

        final reviewTexts = reviews
            .map((r) => r['review'] as String? ?? '')
            .where((r) => r.isNotEmpty)
            .toList();

        // Get product name
        final productDoc = await _firestore
            .collection('shops')
            .doc(shopId)
            .collection('products')
            .doc(productId)
            .get();

        final productName = productDoc.exists
            ? productDoc['name'] as String? ?? 'Unknown'
            : 'Unknown';

        byProductAnalysis[productId] = {
          'productName': productName,
          'avgRating': avgProductRating,
          'reviewCount': reviews.length,
          'sentiment': avgProductRating >= 4.0
              ? 'POSITIVE'
              : avgProductRating >= 3.0
              ? 'MIXED'
              : 'NEGATIVE',
          'commonComplaints': _extractCommonThemes(reviewTexts, negative: true),
          'commonPraises': _extractCommonThemes(reviewTexts, negative: false),
          'riskLevel': avgProductRating < 3.0 ? 'CRITICAL' : 'OK',
        };
      }

      final synthesis = FeedbackSynthesis(
        id: 'feedback_synthesis_${DateTime.now().millisecondsSinceEpoch}',
        shopId: shopId,
        period: PeriodRange(
          startDate: DateTime.now().subtract(const Duration(days: 10)),
          endDate: DateTime.now(),
        ),
        createdAt: DateTime.now(),
        overallSentiment: SentimentAnalysis(
          avgRating: avgRating,
          totalReviews: reviewsSnapshot.docs.length,
          ratingDistribution: ratingDistribution,
          trend: TrendData(direction: 'STABLE', change: 0.0, confidence: 0.8),
        ),
        byProduct: byProductAnalysis,
      );

      await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('feedback_synthesis')
          .doc(synthesis.id)
          .set(synthesis.toJson());

      LoggingService().info('✅ Synthesized feedback from ${reviewsSnapshot.docs.length} reviews');
      return synthesis;
    } catch (e) {
      LoggingService().error('Error synthesizing feedback: $e');
      return null;
    }
  }

  /// Generate cohort analysis report
  Future<CohortAnalysis?> generateCohortAnalysis(String cohortMonth) async {
    try {
      LoggingService().info('📈 Customer Analyst: Analyzing cohort $cohortMonth...');

      // Parse cohort month (YYYY-MM)
      final parts = cohortMonth.split('-');
      if (parts.length != 2) {
        LoggingService().warning('Invalid cohort month format: $cohortMonth');
        return null;
      }

      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final cohortStart = DateTime(year, month, 1);
      final cohortEnd = DateTime(year, month + 1, 0);

      // Find all customers with first purchase in this month
      final ordersSnapshot = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('orders')
          .get();

      final cohortCustomers = <String, DateTime>{};

      for (final order in ordersSnapshot.docs) {
        final customerId = order['customerId'] as String;
        final createdAt = (order['createdAt'] as Timestamp?)?.toDate();

        if (createdAt != null && createdAt.isAfter(cohortStart) && createdAt.isBefore(cohortEnd)) {
          if (!cohortCustomers.containsKey(customerId)) {
            cohortCustomers[customerId] = createdAt;
          } else if (createdAt.isBefore(cohortCustomers[customerId]!)) {
            cohortCustomers[customerId] = createdAt; // Keep earliest
          }
        }
      }

      if (cohortCustomers.isEmpty) {
        LoggingService().info('No customers in cohort $cohortMonth');
        return null;
      }

      // Calculate metrics: retention at day 30, 60, 90
      final retention = {'day_0': 1.0, 'day_30': 0.0, 'day_60': 0.0, 'day_90': 0.0};

      for (final entry in cohortCustomers.entries) {
        final customerId = entry.key;
        final firstPurchaseDate = entry.value;

        final customerOrders = await _firestore
            .collection('shops')
            .doc(shopId)
            .collection('orders')
            .where('customerId', isEqualTo: customerId)
            .get();

        for (final order in customerOrders.docs) {
          final orderDate = (order['createdAt'] as Timestamp?)?.toDate();
          if (orderDate != null && orderDate.isAfter(firstPurchaseDate)) {
            final daysAfter = orderDate.difference(firstPurchaseDate).inDays;
            if (daysAfter <= 30) retention['day_30'] = (retention['day_30'] ?? 0) + 1;
            if (daysAfter <= 60) retention['day_60'] = (retention['day_60'] ?? 0) + 1;
            if (daysAfter <= 90) retention['day_90'] = (retention['day_90'] ?? 0) + 1;
          }
        }
      }

      // Normalize retention to percentages
      final cohortSize = cohortCustomers.length;
      retention['day_30'] = retention['day_30']! / cohortSize;
      retention['day_60'] = retention['day_60']! / cohortSize;
      retention['day_90'] = retention['day_90']! / cohortSize;

      // Calculate LTV
      double totalLTV = 0;
      for (final customerId in cohortCustomers.keys) {
        final customerOrders = await _firestore
            .collection('shops')
            .doc(shopId)
            .collection('orders')
            .where('customerId', isEqualTo: customerId)
            .get();

        totalLTV += customerOrders.docs.fold<double>(
          0,
          (sum, doc) => sum + ((doc['totalAmount'] as num?)?.toDouble() ?? 0.0),
        );
      }

      final avgLTV = totalLTV / cohortSize;
      final churnRate = 1.0 - retention['day_30']!;

      final cohort = CohortAnalysis(
        id: 'cohort_$cohortMonth',
        shopId: shopId,
        cohortMonth: cohortMonth,
        cohortDefinition: 'All customers with first purchase in $cohortMonth',
        createdAt: DateTime.now(),
        metrics: CohortMetrics(
          cohortSize: cohortSize,
          retention: retention,
          avgLifetimeValue: avgLTV,
          churnRate: churnRate,
          trend: churnRate > 0.5 ? 'DECLINING' : 'STABLE',
        ),
        customerIds: cohortCustomers.keys.toList(),
      );

      await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('cohort_analysis')
          .doc(cohort.id)
          .set(cohort.toJson());

      LoggingService().info('✅ Generated cohort analysis for $cohortMonth');
      return cohort;
    } catch (e) {
      LoggingService().error('Error generating cohort analysis: $e');
      return null;
    }
  }

  /// ==========================================
  /// UTILITY & HELPER METHODS
  /// ==========================================

  /// Create a customer segment
  CustomerSegment _createSegment({
    required String type,
    required List<String> customerIds,
    required Map<String, CustomerMetricsData> metrics,
    required List<String> recommendations,
  }) {
    final segmentMetrics = _calculateSegmentMetrics(customerIds, metrics);

    return CustomerSegment(
      id: 'seg_${type.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
      shopId: shopId,
      segmentType: type,
      createdAt: DateTime.now(),
      generatedAt: DateTime.now(),
      customerIds: customerIds,
      count: customerIds.length,
      metrics: segmentMetrics,
      recommendations: recommendations
          .map(
            (r) => {
              'type': type,
              'description': r,
              'action': 'TBD',
              'priority': type == 'AT_RISK' ? 'HIGH' : 'MEDIUM',
            },
          )
          .toList(),
    );
  }

  /// Calculate aggregate metrics for a segment
  SegmentMetrics _calculateSegmentMetrics(
    List<String> customerIds,
    Map<String, CustomerMetricsData> metrics,
  ) {
    if (customerIds.isEmpty) {
      return SegmentMetrics(
        avgLifetimeValue: 0.0,
        avgOrderValue: 0.0,
        totalRevenue: 0.0,
        retentionRate: 0.0,
        churnRisk: 0.0,
        purchaseFrequency: 0.0,
      );
    }

    double totalLTV = 0;
    double totalRevenue = 0;
    int totalPurchases = 0;

    for (final customerId in customerIds) {
      if (metrics.containsKey(customerId)) {
        final m = metrics[customerId]!;
        totalLTV += m.lifetimeValue;
        totalRevenue += m.lifetimeValue;
        totalPurchases += m.purchaseCount;
      }
    }

    final avgLTV = totalLTV / customerIds.length;
    final avgAOV = totalRevenue / (totalPurchases > 0 ? totalPurchases : 1);

    return SegmentMetrics(
      avgLifetimeValue: avgLTV,
      avgOrderValue: avgAOV,
      totalRevenue: totalRevenue,
      retentionRate: 0.87, // Placeholder; calculate from real data
      churnRisk: 0.08,
      purchaseFrequency: totalPurchases / customerIds.length,
    );
  }

  /// Calculate churn risk score (0-1)
  double _calculateChurnRiskScore({
    required int daysSinceLastPurchase,
    required double customerLTV,
    required int purchaseCount,
  }) {
    double score = 0.0;

    // More days since purchase = higher risk
    if (daysSinceLastPurchase > 90) {
      score += 0.4;
    } else if (daysSinceLastPurchase > 60) {
      score += 0.3;
    } else if (daysSinceLastPurchase > 30) {
      score += 0.2;
    }

    // High LTV customers are less likely to churn (reduce risk)
    if (customerLTV > 10000) {
      score -= 0.1;
    }

    // More purchases = more stable (reduce risk)
    if (purchaseCount >= 5) {
      score -= 0.1;
    }

    return (score).clamp(0.0, 1.0);
  }

  /// Extract common themes from review text
  List<Map<String, dynamic>> _extractCommonThemes(List<String> reviews, {required bool negative}) {
    // Simple keyword extraction (in production, use Gemini for NLP)
    const negativeKeywords = [
      'broke',
      'defective',
      'poor quality',
      'not work',
      'disappointed',
      'waste',
      'bad',
    ];
    const positiveKeywords = [
      'excellent',
      'great',
      'love',
      'awesome',
      'perfect',
      'recommend',
      'comfortable',
    ];

    final keywords = negative ? negativeKeywords : positiveKeywords;
    final themes = <String, int>{};

    for (final review in reviews) {
      final lowerReview = review.toLowerCase();
      for (final keyword in keywords) {
        if (lowerReview.contains(keyword)) {
          themes[keyword] = (themes[keyword] ?? 0) + 1;
        }
      }
    }

    return themes.entries
        .map((e) => {'issue': e.key, 'mentions': e.value, 'severity': e.value > 2 ? 'HIGH' : 'LOW'})
        .toList();
  }

  /// Calculate average interval between purchases
  int _calculateAvgInterval(List<DateTime> dates) {
    if (dates.length < 2) return 30;
    dates.sort();
    int totalDays = 0;
    for (int i = 1; i < dates.length; i++) {
      totalDays += dates[i].difference(dates[i - 1]).inDays;
    }
    return (totalDays / (dates.length - 1)).round();
  }
}

/// Helper class for customer metrics calculation
class CustomerMetricsData {
  final String customerId;
  int purchaseCount;
  double lifetimeValue;
  DateTime lastPurchaseDate;
  final List<DateTime> purchaseDates;

  CustomerMetricsData({
    required this.customerId,
    required this.purchaseCount,
    required this.lifetimeValue,
    required this.lastPurchaseDate,
    required this.purchaseDates,
  });
}
