import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryCostMetricModel {
  final String id;
  final String branchId;
  final String zoneId;
  final String? riderId;
  final double costPerDelivery;
  final double costPerKilometer;
  final double totalCost;
  final int totalDeliveries;
  final DateTime date;

  DeliveryCostMetricModel({
    required this.id,
    required this.branchId,
    required this.zoneId,
    this.riderId,
    required this.costPerDelivery,
    required this.costPerKilometer,
    required this.totalCost,
    required this.totalDeliveries,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branchId': branchId,
      'zoneId': zoneId,
      'riderId': riderId,
      'costPerDelivery': costPerDelivery,
      'costPerKilometer': costPerKilometer,
      'totalCost': totalCost,
      'totalDeliveries': totalDeliveries,
      'date': Timestamp.fromDate(date),
    };
  }

  factory DeliveryCostMetricModel.fromMap(Map<String, dynamic> map, String docId) {
    return DeliveryCostMetricModel(
      id: docId,
      branchId: map['branchId'] as String? ?? '',
      zoneId: map['zoneId'] as String? ?? '',
      riderId: map['riderId'] as String?,
      costPerDelivery: (map['costPerDelivery'] as num? ?? 0.0).toDouble(),
      costPerKilometer: (map['costPerKilometer'] as num? ?? 0.0).toDouble(),
      totalCost: (map['totalCost'] as num? ?? 0.0).toDouble(),
      totalDeliveries: map['totalDeliveries'] as int? ?? 0,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
