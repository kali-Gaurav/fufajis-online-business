import 'package:cloud_firestore/cloud_firestore.dart';

class BranchAiScoreModel {
  final String branchId;
  final double healthScore; // 0-100
  final double revenueGrowth; // percentage
  final double orderGrowth; // percentage
  final double inventoryAccuracy; // 0-100
  final double customerRetention; // 0-100
  final double employeeProductivity; // 0-100
  final DateTime generatedAt;

  BranchAiScoreModel({
    required this.branchId,
    required this.healthScore,
    required this.revenueGrowth,
    required this.orderGrowth,
    required this.inventoryAccuracy,
    required this.customerRetention,
    required this.employeeProductivity,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'branchId': branchId,
      'healthScore': healthScore,
      'revenueGrowth': revenueGrowth,
      'orderGrowth': orderGrowth,
      'inventoryAccuracy': inventoryAccuracy,
      'customerRetention': customerRetention,
      'employeeProductivity': employeeProductivity,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }

  factory BranchAiScoreModel.fromMap(Map<String, dynamic> map, String docId) {
    return BranchAiScoreModel(
      branchId: docId,
      healthScore: (map['healthScore'] as num? ?? 0.0).toDouble(),
      revenueGrowth: (map['revenueGrowth'] as num? ?? 0.0).toDouble(),
      orderGrowth: (map['orderGrowth'] as num? ?? 0.0).toDouble(),
      inventoryAccuracy: (map['inventoryAccuracy'] as num? ?? 0.0).toDouble(),
      customerRetention: (map['customerRetention'] as num? ?? 0.0).toDouble(),
      employeeProductivity: (map['employeeProductivity'] as num? ?? 0.0).toDouble(),
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
