import 'package:cloud_firestore/cloud_firestore.dart';

/// Customer Segment - Weekly segmentation snapshot
class CustomerSegment {
  final String id;
  final String shopId;
  final String segmentType; // HIGH_VALUE, NEW, REPEAT, ONE_TIME, AT_RISK
  final DateTime createdAt;
  final DateTime generatedAt;
  final List<String> customerIds;
  final int count;
  final SegmentMetrics metrics;
  final List<Map<String, dynamic>> recommendations;
  final List<Map<String, dynamic>> actionsTaken;

  CustomerSegment({
    required this.id,
    required this.shopId,
    required this.segmentType,
    required this.createdAt,
    required this.generatedAt,
    required this.customerIds,
    required this.count,
    required this.metrics,
    required this.recommendations,
    this.actionsTaken = const [],
  });

  factory CustomerSegment.fromJson(Map<String, dynamic> json) {
    return CustomerSegment(
      id: json['id'] as String? ?? '',
      shopId: json['shopId'] as String? ?? '',
      segmentType: json['segmentType'] as String? ?? 'UNKNOWN',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      generatedAt: (json['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      customerIds: List<String>.from(json['customerIds'] as List? ?? []),
      count: json['count'] as int? ?? 0,
      metrics: SegmentMetrics.fromJson(json['metrics'] as Map<String, dynamic>? ?? {}),
      recommendations: List<Map<String, dynamic>>.from(json['recommendations'] as List? ?? []),
      actionsTaken: List<Map<String, dynamic>>.from(json['actionsTaken'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shopId': shopId,
      'segmentType': segmentType,
      'createdAt': Timestamp.fromDate(createdAt),
      'generatedAt': Timestamp.fromDate(generatedAt),
      'customerIds': customerIds,
      'count': count,
      'metrics': metrics.toJson(),
      'recommendations': recommendations,
      'actionsTaken': actionsTaken,
    };
  }
}

/// Segment-level metrics
class SegmentMetrics {
  final double avgLifetimeValue;
  final double avgOrderValue;
  final double totalRevenue;
  final double retentionRate;
  final double churnRisk;
  final double purchaseFrequency;

  SegmentMetrics({
    required this.avgLifetimeValue,
    required this.avgOrderValue,
    required this.totalRevenue,
    required this.retentionRate,
    required this.churnRisk,
    required this.purchaseFrequency,
  });

  factory SegmentMetrics.fromJson(Map<String, dynamic> json) {
    return SegmentMetrics(
      avgLifetimeValue: (json['avgLifetimeValue'] as num?)?.toDouble() ?? 0.0,
      avgOrderValue: (json['avgOrderValue'] as num?)?.toDouble() ?? 0.0,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      retentionRate: (json['retentionRate'] as num?)?.toDouble() ?? 0.0,
      churnRisk: (json['churnRisk'] as num?)?.toDouble() ?? 0.0,
      purchaseFrequency: (json['purchaseFrequency'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'avgLifetimeValue': avgLifetimeValue,
      'avgOrderValue': avgOrderValue,
      'totalRevenue': totalRevenue,
      'retentionRate': retentionRate,
      'churnRisk': churnRisk,
      'purchaseFrequency': purchaseFrequency,
    };
  }
}

/// Churn Alert - Individual customer at risk
class ChurnAlert {
  final String id;
  final String shopId;
  final String customerId;
  final DateTime createdAt;
  final double riskScore; // 0-1
  final String riskLevel; // LOW, AT_RISK, CRITICAL
  final String reason;
  final DateTime? lastPurchaseDate;
  final SuggestedAction suggestedAction;
  final Map<String, dynamic> customerMetrics;
  final String? actionTaken; // EMAIL_SENT, DISMISSED, MANUAL_OUTREACH
  final DateTime? actionTakenAt;
  final String? actionResult; // PURCHASED, NO_RESPONSE, UNSUBSCRIBED

  ChurnAlert({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.createdAt,
    required this.riskScore,
    required this.riskLevel,
    required this.reason,
    this.lastPurchaseDate,
    required this.suggestedAction,
    required this.customerMetrics,
    this.actionTaken,
    this.actionTakenAt,
    this.actionResult,
  });

  factory ChurnAlert.fromJson(Map<String, dynamic> json) {
    return ChurnAlert(
      id: json['id'] as String? ?? '',
      shopId: json['shopId'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      riskScore: (json['riskScore'] as num?)?.toDouble() ?? 0.0,
      riskLevel: json['riskLevel'] as String? ?? 'UNKNOWN',
      reason: json['reason'] as String? ?? '',
      lastPurchaseDate: (json['lastPurchaseDate'] as Timestamp?)?.toDate(),
      suggestedAction: SuggestedAction.fromJson(
        json['suggestedAction'] as Map<String, dynamic>? ?? {},
      ),
      customerMetrics: json['customerMetrics'] as Map<String, dynamic>? ?? {},
      actionTaken: json['actionTaken'] as String?,
      actionTakenAt: (json['actionTakenAt'] as Timestamp?)?.toDate(),
      actionResult: json['actionResult'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shopId': shopId,
      'customerId': customerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'reason': reason,
      'lastPurchaseDate': lastPurchaseDate != null ? Timestamp.fromDate(lastPurchaseDate!) : null,
      'suggestedAction': suggestedAction.toJson(),
      'customerMetrics': customerMetrics,
      'actionTaken': actionTaken,
      'actionTakenAt': actionTakenAt != null ? Timestamp.fromDate(actionTakenAt!) : null,
      'actionResult': actionResult,
    };
  }
}

/// Suggested action for churn alert
class SuggestedAction {
  final String type; // WIN_BACK_EMAIL, DISCOUNT_OFFER, SURVEY, etc
  final String description;
  final String campaignTemplate;
  final Map<String, dynamic> offerDetails;
  final String priority; // LOW, MEDIUM, HIGH

  SuggestedAction({
    required this.type,
    required this.description,
    required this.campaignTemplate,
    required this.offerDetails,
    required this.priority,
  });

  factory SuggestedAction.fromJson(Map<String, dynamic> json) {
    return SuggestedAction(
      type: json['type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      campaignTemplate: json['campaignTemplate'] as String? ?? '',
      offerDetails: json['offerDetails'] as Map<String, dynamic>? ?? {},
      priority: json['priority'] as String? ?? 'MEDIUM',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
      'campaignTemplate': campaignTemplate,
      'offerDetails': offerDetails,
      'priority': priority,
    };
  }
}

/// Feedback Synthesis - Weekly review analysis
class FeedbackSynthesis {
  final String id;
  final String shopId;
  final PeriodRange period;
  final DateTime createdAt;
  final SentimentAnalysis overallSentiment;
  final Map<String, Map<String, dynamic>> byProduct;
  final Map<String, Map<String, dynamic>>? byCategory;
  final List<Map<String, dynamic>> recommendations;
  final List<Map<String, dynamic>> actionsTaken;

  FeedbackSynthesis({
    required this.id,
    required this.shopId,
    required this.period,
    required this.createdAt,
    required this.overallSentiment,
    required this.byProduct,
    this.byCategory,
    this.recommendations = const [],
    this.actionsTaken = const [],
  });

  factory FeedbackSynthesis.fromJson(Map<String, dynamic> json) {
    return FeedbackSynthesis(
      id: json['id'] as String? ?? '',
      shopId: json['shopId'] as String? ?? '',
      period: PeriodRange.fromJson(json['period'] as Map<String, dynamic>? ?? {}),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      overallSentiment: SentimentAnalysis.fromJson(
        json['overallSentiment'] as Map<String, dynamic>? ?? {},
      ),
      byProduct: (json['byProduct'] as Map<String, dynamic>?)?.cast() ?? {},
      byCategory: (json['byCategory'] as Map<String, dynamic>?)?.cast(),
      recommendations: List<Map<String, dynamic>>.from(json['recommendations'] as List? ?? []),
      actionsTaken: List<Map<String, dynamic>>.from(json['actionsTaken'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shopId': shopId,
      'period': period.toJson(),
      'createdAt': Timestamp.fromDate(createdAt),
      'overallSentiment': overallSentiment.toJson(),
      'byProduct': byProduct,
      'byCategory': byCategory,
      'recommendations': recommendations,
      'actionsTaken': actionsTaken,
    };
  }
}

/// Period range for feedback synthesis
class PeriodRange {
  final DateTime startDate;
  final DateTime endDate;

  PeriodRange({required this.startDate, required this.endDate});

  factory PeriodRange.fromJson(Map<String, dynamic> json) {
    return PeriodRange(
      startDate: (json['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (json['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'startDate': Timestamp.fromDate(startDate), 'endDate': Timestamp.fromDate(endDate)};
  }
}

/// Overall sentiment analysis
class SentimentAnalysis {
  final double avgRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution;
  final TrendData trend;

  SentimentAnalysis({
    required this.avgRating,
    required this.totalReviews,
    required this.ratingDistribution,
    required this.trend,
  });

  factory SentimentAnalysis.fromJson(Map<String, dynamic> json) {
    final distribution = json['ratingDistribution'] as Map<String, dynamic>? ?? {};
    return SentimentAnalysis(
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: json['totalReviews'] as int? ?? 0,
      ratingDistribution: distribution.cast<int, int>(),
      trend: TrendData.fromJson(json['trend'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'avgRating': avgRating,
      'totalReviews': totalReviews,
      'ratingDistribution': ratingDistribution,
      'trend': trend.toJson(),
    };
  }
}

/// Trend data
class TrendData {
  final String direction; // IMPROVING, STABLE, DECLINING
  final double change;
  final double confidence;

  TrendData({required this.direction, required this.change, required this.confidence});

  factory TrendData.fromJson(Map<String, dynamic> json) {
    return TrendData(
      direction: json['direction'] as String? ?? 'STABLE',
      change: (json['change'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
    );
  }

  Map<String, dynamic> toJson() {
    return {'direction': direction, 'change': change, 'confidence': confidence};
  }
}

/// Cohort Analysis - Monthly cohort performance tracking
class CohortAnalysis {
  final String id;
  final String shopId;
  final String cohortMonth; // YYYY-MM
  final String cohortDefinition;
  final DateTime createdAt;
  final CohortMetrics metrics;
  final List<String> customerIds;
  final Map<String, dynamic>? comparison;
  final List<Map<String, dynamic>> recommendations;
  final List<Map<String, dynamic>> actionsTaken;

  CohortAnalysis({
    required this.id,
    required this.shopId,
    required this.cohortMonth,
    required this.cohortDefinition,
    required this.createdAt,
    required this.metrics,
    required this.customerIds,
    this.comparison,
    this.recommendations = const [],
    this.actionsTaken = const [],
  });

  factory CohortAnalysis.fromJson(Map<String, dynamic> json) {
    return CohortAnalysis(
      id: json['id'] as String? ?? '',
      shopId: json['shopId'] as String? ?? '',
      cohortMonth: json['cohortMonth'] as String? ?? '',
      cohortDefinition: json['cohortDefinition'] as String? ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metrics: CohortMetrics.fromJson(json['metrics'] as Map<String, dynamic>? ?? {}),
      customerIds: List<String>.from(json['customerIds'] as List? ?? []),
      comparison: json['comparison'] as Map<String, dynamic>?,
      recommendations: List<Map<String, dynamic>>.from(json['recommendations'] as List? ?? []),
      actionsTaken: List<Map<String, dynamic>>.from(json['actionsTaken'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shopId': shopId,
      'cohortMonth': cohortMonth,
      'cohortDefinition': cohortDefinition,
      'createdAt': Timestamp.fromDate(createdAt),
      'metrics': metrics.toJson(),
      'customerIds': customerIds,
      'comparison': comparison,
      'recommendations': recommendations,
      'actionsTaken': actionsTaken,
    };
  }
}

/// Cohort-level metrics
class CohortMetrics {
  final int cohortSize;
  final Map<String, double> retention; // day_0, day_30, day_60, day_90
  final double avgLifetimeValue;
  final double churnRate;
  final String trend; // IMPROVING, STABLE, DECLINING

  CohortMetrics({
    required this.cohortSize,
    required this.retention,
    required this.avgLifetimeValue,
    required this.churnRate,
    required this.trend,
  });

  factory CohortMetrics.fromJson(Map<String, dynamic> json) {
    return CohortMetrics(
      cohortSize: json['cohortSize'] as int? ?? 0,
      retention:
          (json['retention'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      avgLifetimeValue: (json['avgLifetimeValue'] as num?)?.toDouble() ?? 0.0,
      churnRate: (json['churnRate'] as num?)?.toDouble() ?? 0.0,
      trend: json['trend'] as String? ?? 'STABLE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cohortSize': cohortSize,
      'retention': retention,
      'avgLifetimeValue': avgLifetimeValue,
      'churnRate': churnRate,
      'trend': trend,
    };
  }
}
