import 'package:cloud_firestore/cloud_firestore.dart';

enum InventoryRecommendationStatus { pending, approved, rejected, executed }

class InventoryRecommendationModel {
  final String id;
  final String productId;
  final String branchId;
  final int currentStock;
  final int predictedDemand;
  final int recommendedOrderQty;
  final double confidenceScore;
  final String reason;
  final InventoryRecommendationStatus status;
  final DateTime createdAt;

  InventoryRecommendationModel({
    required this.id,
    required this.productId,
    required this.branchId,
    required this.currentStock,
    required this.predictedDemand,
    required this.recommendedOrderQty,
    required this.confidenceScore,
    required this.reason,
    this.status = InventoryRecommendationStatus.pending,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'branchId': branchId,
      'currentStock': currentStock,
      'predictedDemand': predictedDemand,
      'recommendedOrderQty': recommendedOrderQty,
      'confidenceScore': confidenceScore,
      'reason': reason,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory InventoryRecommendationModel.fromMap(Map<String, dynamic> map, String docId) {
    return InventoryRecommendationModel(
      id: docId,
      productId: map['productId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? 'global',
      currentStock: map['currentStock'] as int? ?? 0,
      predictedDemand: map['predictedDemand'] as int? ?? 0,
      recommendedOrderQty: map['recommendedOrderQty'] as int? ?? 0,
      confidenceScore: (map['confidenceScore'] as num? ?? 0.0).toDouble(),
      reason: map['reason'] as String? ?? '',
      status: InventoryRecommendationStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => InventoryRecommendationStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
