import 'package:cloud_firestore/cloud_firestore.dart';

enum RiskLevel { low, medium, high, critical }

class DeliveryIntelligenceModel {
  final String branchId;
  final RiskLevel expectedDelayRisk;
  final List<String> bottlenecks;
  final String peakWindow;
  final double driverUtilization; // percentage
  final DateTime generatedAt;

  DeliveryIntelligenceModel({
    required this.branchId,
    required this.expectedDelayRisk,
    required this.bottlenecks,
    required this.peakWindow,
    required this.driverUtilization,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'branchId': branchId,
      'expectedDelayRisk': expectedDelayRisk.name,
      'bottlenecks': bottlenecks,
      'peakWindow': peakWindow,
      'driverUtilization': driverUtilization,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }

  factory DeliveryIntelligenceModel.fromMap(Map<String, dynamic> map, String docId) {
    return DeliveryIntelligenceModel(
      branchId: docId, // Usually docId is the branchId
      expectedDelayRisk: RiskLevel.values.firstWhere(
        (e) => e.name == map['expectedDelayRisk'] as String?,
        orElse: () => RiskLevel.low,
      ),
      bottlenecks: List<String>.from(map['bottlenecks'] as Iterable? ?? []),
      peakWindow: map['peakWindow'] as String? ?? '',
      driverUtilization: (map['driverUtilization'] as num? ?? 0.0).toDouble(),
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
