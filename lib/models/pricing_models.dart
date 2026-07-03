import 'package:cloud_firestore/cloud_firestore.dart';

/// Pricing Recommendation - Main document
class PricingRecommendation {
  final String id;
  final String shopId;
  final String productId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String agentVersion;
  final PricingRecommendations recommendations;
  final String status; // PENDING, APPROVED, REJECTED, ARCHIVED
  final DateTime? approvedAt;
  final String? rejectionReason;
  final double? editedPrice;
  final PricingMetrics? metrics;

  PricingRecommendation({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.createdAt,
    required this.updatedAt,
    required this.agentVersion,
    required this.recommendations,
    required this.status,
    this.approvedAt,
    this.rejectionReason,
    this.editedPrice,
    this.metrics,
  });

  factory PricingRecommendation.fromJson(Map<String, dynamic> json) {
    return PricingRecommendation(
      id: json['id'] as String? ?? '',
      shopId: json['shopId'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      agentVersion: json['agentVersion'] as String? ?? 'v1.0',
      recommendations: PricingRecommendations.fromJson(
        json['recommendations'] as Map<String, dynamic>? ?? {},
      ),
      status: json['status'] as String? ?? 'PENDING',
      approvedAt: (json['approvedAt'] as Timestamp?)?.toDate(),
      rejectionReason: json['rejectionReason'] as String?,
      editedPrice: (json['editedPrice'] as num?)?.toDouble(),
      metrics: json['metrics'] != null
          ? PricingMetrics.fromJson(json['metrics'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shopId': shopId,
      'productId': productId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'agentVersion': agentVersion,
      'recommendations': recommendations.toJson(),
      'status': status,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectionReason': rejectionReason,
      'editedPrice': editedPrice,
      'metrics': metrics?.toJson(),
    };
  }
}

/// Container for all three recommendation types
class PricingRecommendations {
  final DynamicPriceRecommendation dynamicPrice;
  final MarginAnalysisRecommendation marginAnalysis;
  final BundleOpportunityRecommendation? bundleOpportunity;

  PricingRecommendations({
    required this.dynamicPrice,
    required this.marginAnalysis,
    this.bundleOpportunity,
  });

  factory PricingRecommendations.fromJson(Map<String, dynamic> json) {
    return PricingRecommendations(
      dynamicPrice: DynamicPriceRecommendation.fromJson(
        json['dynamicPrice'] as Map<String, dynamic>? ?? {},
      ),
      marginAnalysis: MarginAnalysisRecommendation.fromJson(
        json['marginAnalysis'] as Map<String, dynamic>? ?? {},
      ),
      bundleOpportunity: json['bundleOpportunity'] != null
          ? BundleOpportunityRecommendation.fromJson(
              json['bundleOpportunity'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dynamicPrice': dynamicPrice.toJson(),
      'marginAnalysis': marginAnalysis.toJson(),
      'bundleOpportunity': bundleOpportunity?.toJson(),
    };
  }
}

/// Dynamic Price Recommendation
class DynamicPriceRecommendation {
  final double currentPrice;
  final double suggestedPrice;
  final String reason;
  final double confidence; // 0.0 - 1.0
  final List<String> triggers; // ['low_stock', 'high_rating', etc]
  final double estimatedRevenueLift;

  DynamicPriceRecommendation({
    required this.currentPrice,
    required this.suggestedPrice,
    required this.reason,
    required this.confidence,
    required this.triggers,
    required this.estimatedRevenueLift,
  });

  double get priceChangePercent => ((suggestedPrice - currentPrice) / currentPrice * 100);

  factory DynamicPriceRecommendation.fromJson(Map<String, dynamic> json) {
    return DynamicPriceRecommendation(
      currentPrice: (json['currentPrice'] as num?)?.toDouble() ?? 0.0,
      suggestedPrice: (json['suggestedPrice'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.7,
      triggers: List<String>.from(json['triggers'] as List? ?? []),
      estimatedRevenueLift: (json['estimatedRevenueLift'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentPrice': currentPrice,
      'suggestedPrice': suggestedPrice,
      'priceChangePercent': priceChangePercent,
      'reason': reason,
      'confidence': confidence,
      'triggers': triggers,
      'estimatedRevenueLift': estimatedRevenueLift,
    };
  }
}

/// Margin Analysis Recommendation
class MarginAnalysisRecommendation {
  final double cost;
  final double currentMarginPercent;
  final double projectedMarginPercent;
  final String marginalCategory; // HIGH, MEDIUM, LOW, LOSS
  final bool warningFlag;
  final String notes;
  final double priceFloorFor30Margin;

  MarginAnalysisRecommendation({
    required this.cost,
    required this.currentMarginPercent,
    required this.projectedMarginPercent,
    required this.marginalCategory,
    required this.warningFlag,
    required this.notes,
    required this.priceFloorFor30Margin,
  });

  factory MarginAnalysisRecommendation.fromJson(Map<String, dynamic> json) {
    return MarginAnalysisRecommendation(
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      currentMarginPercent: (json['currentMarginPercent'] as num?)?.toDouble() ?? 0.0,
      projectedMarginPercent: (json['projectedMarginPercent'] as num?)?.toDouble() ?? 0.0,
      marginalCategory: json['marginalCategory'] as String? ?? 'MEDIUM',
      warningFlag: json['warningFlag'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
      priceFloorFor30Margin: (json['priceFloorFor30Margin'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cost': cost,
      'currentMarginPercent': currentMarginPercent,
      'projectedMarginPercent': projectedMarginPercent,
      'marginalCategory': marginalCategory,
      'warningFlag': warningFlag,
      'notes': notes,
      'priceFloorFor30Margin': priceFloorFor30Margin,
    };
  }
}

/// Bundle Opportunity Recommendation
class BundleOpportunityRecommendation {
  final String bundleName;
  final String description;
  final List<String> productIds;
  final double suggestedBundlePrice;
  final double individualTotal;
  final double bundleDiscount;
  final double discountPercent;
  final BundleLift estimatedLift;
  final double confidence;

  BundleOpportunityRecommendation({
    required this.bundleName,
    required this.description,
    required this.productIds,
    required this.suggestedBundlePrice,
    required this.individualTotal,
    required this.bundleDiscount,
    required this.discountPercent,
    required this.estimatedLift,
    required this.confidence,
  });

  factory BundleOpportunityRecommendation.fromJson(Map<String, dynamic> json) {
    return BundleOpportunityRecommendation(
      bundleName: json['bundleName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      productIds: List<String>.from(json['productIds'] as List? ?? []),
      suggestedBundlePrice: (json['suggestedBundlePrice'] as num?)?.toDouble() ?? 0.0,
      individualTotal: (json['individualTotal'] as num?)?.toDouble() ?? 0.0,
      bundleDiscount: (json['bundleDiscount'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
      estimatedLift: BundleLift.fromJson(json['estimatedLift'] as Map<String, dynamic>? ?? {}),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.7,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bundleName': bundleName,
      'description': description,
      'productIds': productIds,
      'suggestedBundlePrice': suggestedBundlePrice,
      'individualTotal': individualTotal,
      'bundleDiscount': bundleDiscount,
      'discountPercent': discountPercent,
      'estimatedLift': estimatedLift.toJson(),
      'confidence': confidence,
    };
  }
}

/// Bundle lift metrics
class BundleLift {
  final String aovIncrease;
  final String adoptionRate;

  BundleLift({required this.aovIncrease, required this.adoptionRate});

  factory BundleLift.fromJson(Map<String, dynamic> json) {
    return BundleLift(
      aovIncrease: json['aovIncrease'] as String? ?? '₹0',
      adoptionRate: json['adoptionRate'] as String? ?? '0%',
    );
  }

  Map<String, dynamic> toJson() {
    return {'aovIncrease': aovIncrease, 'adoptionRate': adoptionRate};
  }
}

/// Pricing metrics and metadata
class PricingMetrics {
  final int viewCount;
  final int? timeToApproveSeconds;
  final Map<String, dynamic>? actualOutcome;

  PricingMetrics({required this.viewCount, this.timeToApproveSeconds, this.actualOutcome});

  factory PricingMetrics.fromJson(Map<String, dynamic> json) {
    return PricingMetrics(
      viewCount: json['viewCount'] as int? ?? 0,
      timeToApproveSeconds: json['timeToApproveSeconds'] as int?,
      actualOutcome: json['actualOutcome'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'viewCount': viewCount,
      'timeToApproveSeconds': timeToApproveSeconds,
      'actualOutcome': actualOutcome,
    };
  }
}

/// Monthly pricing report
class PricingReport {
  final String period;
  final int totalProducts;
  final double averageMargin;
  final int highMarginProducts;
  final int lowMarginProducts;
  final List<Map<String, dynamic>> lowMarginDetails;
  final String recommendations;

  PricingReport({
    required this.period,
    required this.totalProducts,
    required this.averageMargin,
    required this.highMarginProducts,
    required this.lowMarginProducts,
    required this.lowMarginDetails,
    required this.recommendations,
  });

  factory PricingReport.fromJson(Map<String, dynamic> json) {
    return PricingReport(
      period: json['period'] as String? ?? '',
      totalProducts: json['totalProducts'] as int? ?? 0,
      averageMargin: (json['averageMargin'] as num?)?.toDouble() ?? 0.0,
      highMarginProducts: json['highMarginProducts'] as int? ?? 0,
      lowMarginProducts: json['lowMarginProducts'] as int? ?? 0,
      lowMarginDetails: List<Map<String, dynamic>>.from(json['lowMarginDetails'] as List? ?? []),
      recommendations: json['recommendations'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'totalProducts': totalProducts,
      'averageMargin': averageMargin,
      'highMarginProducts': highMarginProducts,
      'lowMarginProducts': lowMarginProducts,
      'lowMarginDetails': lowMarginDetails,
      'recommendations': recommendations,
    };
  }
}
