import 'package:cloud_firestore/cloud_firestore.dart';

class LowStockAlert {
  final String id;
  final String productId;
  final String productName;
  final int currentStock;
  final int minimumStock;
  final DateTime createdAt;
  final bool isDismissed;
  final String severity; // High, Medium, Low
  final int recommendedReorderQuantity;
  final double averageDailySales;
  final int daysUntilStockout;
  final int recommendedStockDays;

  LowStockAlert({
    required this.id,
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.minimumStock,
    required this.createdAt,
    this.isDismissed = false,
    this.severity = 'Medium',
    this.recommendedReorderQuantity = 0,
    this.averageDailySales = 0.0,
    this.daysUntilStockout = 0,
    this.recommendedStockDays = 0,
  });

  factory LowStockAlert.fromMap(Map<String, dynamic> map) {
    return LowStockAlert(
      id: map['id'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      currentStock: map['currentStock'] as int? ?? 0,
      minimumStock: map['minimumStock'] as int? ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDismissed: map['isDismissed'] as bool? ?? false,
      severity: map['severity'] as String? ?? 'Medium',
      recommendedReorderQuantity: map['recommendedReorderQuantity'] as int? ?? 0,
      averageDailySales: (map['averageDailySales'] as num? ?? 0.0).toDouble(),
      daysUntilStockout: map['daysUntilStockout'] as int? ?? 0,
      recommendedStockDays: map['recommendedStockDays'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'currentStock': currentStock,
      'minimumStock': minimumStock,
      'createdAt': createdAt,
      'isDismissed': isDismissed,
      'severity': severity,
      'recommendedReorderQuantity': recommendedReorderQuantity,
      'averageDailySales': averageDailySales,
      'daysUntilStockout': daysUntilStockout,
      'recommendedStockDays': recommendedStockDays,
    };
  }
}
