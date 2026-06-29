import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessForecastModel {
  final String branchId;
  final double predictedRevenue7Days;
  final double predictedRevenue30Days;
  final int predictedOrders7Days;
  final int predictedOrders30Days;
  final DateTime generatedAt;

  BusinessForecastModel({
    required this.branchId,
    required this.predictedRevenue7Days,
    required this.predictedRevenue30Days,
    required this.predictedOrders7Days,
    required this.predictedOrders30Days,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'branchId': branchId,
      'predictedRevenue7Days': predictedRevenue7Days,
      'predictedRevenue30Days': predictedRevenue30Days,
      'predictedOrders7Days': predictedOrders7Days,
      'predictedOrders30Days': predictedOrders30Days,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }

  factory BusinessForecastModel.fromMap(Map<String, dynamic> map) {
    return BusinessForecastModel(
      branchId: map['branchId'] as String? ?? 'global',
      predictedRevenue7Days: (map['predictedRevenue7Days'] as num? ?? 0.0).toDouble(),
      predictedRevenue30Days: (map['predictedRevenue30Days'] as num? ?? 0.0).toDouble(),
      predictedOrders7Days: map['predictedOrders7Days'] as int? ?? 0,
      predictedOrders30Days: map['predictedOrders30Days'] as int? ?? 0,
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
