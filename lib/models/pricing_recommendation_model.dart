import 'package:cloud_firestore/cloud_firestore.dart';

enum PricingRecommendationStatus { pending, approved, rejected, executed }

class PricingRecommendationModel {
  final String id;
  final String productId;
  final String branchId;
  final double currentPrice;
  final double suggestedPrice;
  final String reason;
  final double confidenceScore;
  final PricingRecommendationStatus status;
  final DateTime createdAt;

  PricingRecommendationModel({
    required this.id,
    required this.productId,
    required this.branchId,
    required this.currentPrice,
    required this.suggestedPrice,
    required this.reason,
    required this.confidenceScore,
    this.status = PricingRecommendationStatus.pending,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'branchId': branchId,
      'currentPrice': currentPrice,
      'suggestedPrice': suggestedPrice,
      'reason': reason,
      'confidenceScore': confidenceScore,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PricingRecommendationModel.fromMap(Map<String, dynamic> map, String docId) {
    return PricingRecommendationModel(
      id: docId,
      productId: map['productId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? 'global',
      currentPrice: (map['currentPrice'] as num? ?? 0.0).toDouble(),
      suggestedPrice: (map['suggestedPrice'] as num? ?? 0.0).toDouble(),
      reason: map['reason'] as String? ?? '',
      confidenceScore: (map['confidenceScore'] as num? ?? 0.0).toDouble(),
      status: PricingRecommendationStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => PricingRecommendationStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
