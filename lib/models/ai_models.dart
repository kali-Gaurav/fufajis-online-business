/// AI Models for recommendation, forecasting, fraud detection, and insights
///
/// This file contains all data models used by AI services in the Fufaji app.
/// These models are designed to work with both placeholder implementations
/// and future ML model integrations.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// AIRecommendation - Product recommendation with reasoning
///
/// Represents a single recommended product with confidence score and reason.
/// Used by the recommendation engine to suggest products to customers.
class AIRecommendation {
  final String productId;
  final String reason; // e.g., "trending", "browsed_similar", "frequently_bought_together"
  final double confidence; // 0.0 - 1.0 confidence score
  final double? score; // Optional raw score from model
  final DateTime generatedAt;

  // Tracking fields for model improvement
  bool? wasClicked;
  bool? wasPurchased;

  AIRecommendation({
    required this.productId,
    required this.reason,
    required this.confidence,
    this.score,
    DateTime? generatedAt,
    this.wasClicked,
    this.wasPurchased,
  }) : generatedAt = generatedAt ?? DateTime.now();

  /// Convert from Firestore document
  factory AIRecommendation.fromMap(Map<String, dynamic> map) {
    return AIRecommendation(
      productId: map['productId'] as String? ?? '',
      reason: map['reason'] as String? ?? 'recommended',
      confidence: (map['confidence'] as num? ?? 0.5).toDouble(),
      score: (map['score'] as num?)?.toDouble(),
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      wasClicked: map['wasClicked'] as bool?,
      wasPurchased: map['wasPurchased'] as bool?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'reason': reason,
      'confidence': confidence,
      'score': score,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'wasClicked': wasClicked,
      'wasPurchased': wasPurchased,
    };
  }
}

/// DemandForecast - Predicted demand for a product on a specific date
///
/// Used by inventory management to predict future demand and optimize stock levels.
class DemandForecast {
  final String productId;
  final int forecastedUnits;
  final double confidence; // 0.0 - 1.0 confidence in forecast
  final DateTime date;
  final double? forecastedRevenue;
  final List<String>? factors; // e.g., ["seasonal_trend", "holiday_effect", "price_drop"]
  final DateTime generatedAt;

  DemandForecast({
    required this.productId,
    required this.forecastedUnits,
    required this.confidence,
    required this.date,
    this.forecastedRevenue,
    this.factors,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  /// Convert from Firestore document
  factory DemandForecast.fromMap(Map<String, dynamic> map) {
    return DemandForecast(
      productId: map['productId'] as String? ?? '',
      forecastedUnits: map['forecastedUnits'] as int? ?? 0,
      confidence: (map['confidence'] as num? ?? 0.5).toDouble(),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      forecastedRevenue: (map['forecastedRevenue'] as num?)?.toDouble(),
      factors: List<String>.from(map['factors'] as Iterable? ?? []),
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'forecastedUnits': forecastedUnits,
      'confidence': confidence,
      'date': Timestamp.fromDate(date),
      'forecastedRevenue': forecastedRevenue,
      'factors': factors,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }

  /// Get reorder quantity recommendation (safety stock + forecast)
  int getReorderQuantity(int safetyStock) {
    return forecastedUnits + safetyStock;
  }
}

/// FraudAlert - Fraud risk assessment for an order
///
/// Identifies potentially fraudulent orders with risk score and reasoning.
/// Used to flag orders for manual review or auto-approval.
class FraudAlert {
  final String orderId;
  final double riskScore; // 0.0 - 1.0 (higher = more likely fraud)
  final List<String> reasons; // e.g., ["unusual_payment_pattern", "high_value_first_order"]
  final FraudAction recommendedAction; // approve, manual_review, or block
  final DateTime detectedAt;

  // Resolution tracking
  bool? isResolved;
  bool? wasFraud;
  String? resolutionNotes;

  FraudAlert({
    required this.orderId,
    required this.riskScore,
    required this.reasons,
    required this.recommendedAction,
    DateTime? detectedAt,
    this.isResolved,
    this.wasFraud,
    this.resolutionNotes,
  }) : detectedAt = detectedAt ?? DateTime.now();

  /// Convert from Firestore document
  factory FraudAlert.fromMap(Map<String, dynamic> map) {
    return FraudAlert(
      orderId: map['orderId'] as String? ?? '',
      riskScore: (map['riskScore'] as num? ?? 0.0).toDouble(),
      reasons: List<String>.from(map['reasons'] as Iterable? ?? []),
      recommendedAction: _parseFraudAction(map['recommendedAction'] as String?),
      detectedAt: (map['detectedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isResolved: map['isResolved'] as bool?,
      wasFraud: map['wasFraud'] as bool?,
      resolutionNotes: map['resolutionNotes'] as String?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'riskScore': riskScore,
      'reasons': reasons,
      'recommendedAction': recommendedAction.toString().split('.').last,
      'detectedAt': Timestamp.fromDate(detectedAt),
      'isResolved': isResolved,
      'wasFraud': wasFraud,
      'resolutionNotes': resolutionNotes,
    };
  }

  /// Check if order should be auto-approved
  bool shouldAutoApprove() => riskScore < 0.2;

  /// Check if order should be blocked
  bool shouldBlock() => riskScore > 0.8;
}

/// FraudAction enum
enum FraudAction {
  approve, // Automatically approve the order
  manual_review, // Flag for manual review
  block, // Block the order immediately
}

FraudAction _parseFraudAction(String? value) {
  if (value == null) return FraudAction.manual_review;
  try {
    return FraudAction.values.firstWhere(
      (e) => e.toString().split('.').last == value,
      orElse: () => FraudAction.manual_review,
    );
  } catch (_) {
    return FraudAction.manual_review;
  }
}

/// OwnerInsight - AI-generated insight for shop owner
///
/// Actionable insights about shop performance, trends, and opportunities.
/// Helps owners make data-driven business decisions.
class OwnerInsight {
  final String insightId;
  final String ownerId;
  final InsightType type;
  final String title;
  final String description;
  final dynamic metric; // The actual data point (could be number, string, etc.)
  final String recommendation;
  final double? priority; // 0.0 - 1.0 (higher = more important)
  final DateTime generatedAt;

  // Tracking fields
  bool? wasViewed;
  bool? wasActedOn;
  String? actionTaken;

  OwnerInsight({
    String? insightId,
    required this.ownerId,
    required this.type,
    required this.title,
    required this.description,
    required this.metric,
    required this.recommendation,
    this.priority,
    DateTime? generatedAt,
    this.wasViewed,
    this.wasActedOn,
    this.actionTaken,
  })  : insightId = insightId ?? _generateInsightId(),
        generatedAt = generatedAt ?? DateTime.now();

  /// Convert from Firestore document
  factory OwnerInsight.fromMap(Map<String, dynamic> map) {
    return OwnerInsight(
      insightId: map['insightId'] as String?,
      ownerId: map['ownerId'] as String? ?? '',
      type: _parseInsightType(map['type'] as String?),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      metric: map['metric'],
      recommendation: map['recommendation'] as String? ?? '',
      priority: (map['priority'] as num?)?.toDouble(),
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      wasViewed: map['wasViewed'] as bool?,
      wasActedOn: map['wasActedOn'] as bool?,
      actionTaken: map['actionTaken'] as String?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'insightId': insightId,
      'ownerId': ownerId,
      'type': type.toString().split('.').last,
      'title': title,
      'description': description,
      'metric': metric,
      'recommendation': recommendation,
      'priority': priority,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'wasViewed': wasViewed,
      'wasActedOn': wasActedOn,
      'actionTaken': actionTaken,
    };
  }

  static String _generateInsightId() {
    return 'insight_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// InsightType enum - Categories of insights
enum InsightType {
  sales_trend, // Sales going up or down
  customer_churn, // Customers stopping purchases
  product_opportunity, // New product opportunity detected
  inventory_alert, // Stock issues or optimization
  pricing_opportunity, // Price optimization suggestion
  customer_satisfaction, // Review/rating trends
  revenue_forecast, // Predicted revenue changes
  marketing_opportunity, // Campaign/promotional ideas
  operational_efficiency, // Process improvements
  competitor_analysis, // Competitive insights
}

InsightType _parseInsightType(String? value) {
  if (value == null) return InsightType.sales_trend;
  try {
    return InsightType.values.firstWhere(
      (e) => e.toString().split('.').last == value,
      orElse: () => InsightType.sales_trend,
    );
  } catch (_) {
    return InsightType.sales_trend;
  }
}

/// AIModelPerformance - Tracks accuracy of AI models
///
/// Used for monitoring model performance and triggering retraining.
class AIModelPerformance {
  final String modelName;
  final DateTime date;
  final double accuracy;
  final double precision;
  final double recall;
  final int predictionsMade;
  final int correctPredictions;
  final double f1Score;

  AIModelPerformance({
    required this.modelName,
    required this.date,
    required this.accuracy,
    required this.precision,
    required this.recall,
    required this.predictionsMade,
    required this.correctPredictions,
    required this.f1Score,
  });

  /// Convert from Firestore document
  factory AIModelPerformance.fromMap(Map<String, dynamic> map) {
    return AIModelPerformance(
      modelName: map['modelName'] as String? ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      accuracy: (map['accuracy'] as num? ?? 0.0).toDouble(),
      precision: (map['precision'] as num? ?? 0.0).toDouble(),
      recall: (map['recall'] as num? ?? 0.0).toDouble(),
      predictionsMade: map['predictionsMade'] as int? ?? 0,
      correctPredictions: map['correctPredictions'] as int? ?? 0,
      f1Score: (map['f1Score'] as num? ?? 0.0).toDouble(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'modelName': modelName,
      'date': Timestamp.fromDate(date),
      'accuracy': accuracy,
      'precision': precision,
      'recall': recall,
      'predictionsMade': predictionsMade,
      'correctPredictions': correctPredictions,
      'f1Score': f1Score,
    };
  }

  /// Check if model performance is acceptable
  bool isAcceptable({double minAccuracy = 0.75}) => accuracy >= minAccuracy;
}
