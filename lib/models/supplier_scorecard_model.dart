import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierScorecardModel {
  final String supplierId;
  final double onTimeDeliveryPercentage;
  final double damageRatePercentage;
  final double orderFulfillmentPercentage;
  final double priceCompetitiveness; // 1-10 scale
  final double overallQualityRating; // 0-100 scale
  final int totalOrders;
  final DateTime lastUpdated;

  SupplierScorecardModel({
    required this.supplierId,
    this.onTimeDeliveryPercentage = 100.0,
    this.damageRatePercentage = 0.0,
    this.orderFulfillmentPercentage = 100.0,
    this.priceCompetitiveness = 5.0,
    this.overallQualityRating = 100.0,
    this.totalOrders = 0,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'supplierId': supplierId,
      'onTimeDeliveryPercentage': onTimeDeliveryPercentage,
      'damageRatePercentage': damageRatePercentage,
      'orderFulfillmentPercentage': orderFulfillmentPercentage,
      'priceCompetitiveness': priceCompetitiveness,
      'overallQualityRating': overallQualityRating,
      'totalOrders': totalOrders,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory SupplierScorecardModel.fromMap(Map<String, dynamic> map, String docId) {
    return SupplierScorecardModel(
      supplierId: docId,
      onTimeDeliveryPercentage: (map['onTimeDeliveryPercentage'] as num? ?? 100.0).toDouble(),
      damageRatePercentage: (map['damageRatePercentage'] as num? ?? 0.0).toDouble(),
      orderFulfillmentPercentage: (map['orderFulfillmentPercentage'] as num? ?? 100.0).toDouble(),
      priceCompetitiveness: (map['priceCompetitiveness'] as num? ?? 5.0).toDouble(),
      overallQualityRating: (map['overallQualityRating'] as num? ?? 100.0).toDouble(),
      totalOrders: map['totalOrders'] as int? ?? 0,
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
