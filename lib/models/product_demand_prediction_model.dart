import 'package:cloud_firestore/cloud_firestore.dart';

class ProductDemandPredictionModel {
  final String productId;
  final String branchId;
  final int predictedDemand;
  final double confidence; // 0.0 to 1.0
  final DateTime generatedAt;

  ProductDemandPredictionModel({
    required this.productId,
    required this.branchId,
    required this.predictedDemand,
    required this.confidence,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'branchId': branchId,
      'predictedDemand': predictedDemand,
      'confidence': confidence,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }

  factory ProductDemandPredictionModel.fromMap(Map<String, dynamic> map) {
    return ProductDemandPredictionModel(
      productId: map['productId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? 'global',
      predictedDemand: map['predictedDemand'] as int? ?? 0,
      confidence: (map['confidence'] as num? ?? 0.0).toDouble(),
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
