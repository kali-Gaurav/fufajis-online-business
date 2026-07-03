import 'package:cloud_firestore/cloud_firestore.dart';

class OperationalHealthModel {
  final String branchId;
  final double inventoryHealth; // 0-100
  final double deliveryHealth; // 0-100
  final double employeeHealth; // 0-100
  final double supplierHealth; // 0-100
  final double customerHealth; // 0-100
  final double financialHealth; // 0-100
  final DateTime lastUpdated;

  OperationalHealthModel({
    required this.branchId,
    this.inventoryHealth = 100.0,
    this.deliveryHealth = 100.0,
    this.employeeHealth = 100.0,
    this.supplierHealth = 100.0,
    this.customerHealth = 100.0,
    this.financialHealth = 100.0,
    required this.lastUpdated,
  });

  double get overallScore {
    return (inventoryHealth +
            deliveryHealth +
            employeeHealth +
            supplierHealth +
            customerHealth +
            financialHealth) /
        6;
  }

  Map<String, dynamic> toMap() {
    return {
      'branchId': branchId,
      'inventoryHealth': inventoryHealth,
      'deliveryHealth': deliveryHealth,
      'employeeHealth': employeeHealth,
      'supplierHealth': supplierHealth,
      'customerHealth': customerHealth,
      'financialHealth': financialHealth,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory OperationalHealthModel.fromMap(Map<String, dynamic> map) {
    return OperationalHealthModel(
      branchId: map['branchId'] as String? ?? '',
      inventoryHealth: (map['inventoryHealth'] as num? ?? 100.0).toDouble(),
      deliveryHealth: (map['deliveryHealth'] as num? ?? 100.0).toDouble(),
      employeeHealth: (map['employeeHealth'] as num? ?? 100.0).toDouble(),
      supplierHealth: (map['supplierHealth'] as num? ?? 100.0).toDouble(),
      customerHealth: (map['customerHealth'] as num? ?? 100.0).toDouble(),
      financialHealth: (map['financialHealth'] as num? ?? 100.0).toDouble(),
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
