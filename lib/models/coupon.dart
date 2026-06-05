import 'package:cloud_firestore/cloud_firestore.dart';

class Coupon {
  final String id;
  final String code;
  final String name;
  final String description;
  final String discountType; // 'percentage' or 'flat'
  final double discountValue;
  final double minimumOrderAmount;
  final double maximumDiscountAmount;
  final DateTime startDate;
  final DateTime endDate;

  Coupon({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.minimumOrderAmount,
    required this.maximumDiscountAmount,
    required this.startDate,
    required this.endDate,
  });

  factory Coupon.fromMap(Map<String, dynamic> map) {
    return Coupon(
      id: map['id'] ?? '',
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      discountType: map['discountType'] ?? 'percentage',
      discountValue: (map['discountValue'] ?? 0.0).toDouble(),
      minimumOrderAmount: (map['minimumOrderAmount'] ?? 0.0).toDouble(),
      maximumDiscountAmount: (map['maximumDiscountAmount'] ?? 0.0).toDouble(),
      startDate: map['startDate'] != null
          ? (map['startDate'] is DateTime
                ? map['startDate']
                : (map['startDate'] as Timestamp).toDate())
          : DateTime.now(),
      endDate: map['endDate'] != null
          ? (map['endDate'] is DateTime
                ? map['endDate']
                : (map['endDate'] as Timestamp).toDate())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'discountType': discountType,
      'discountValue': discountValue,
      'minimumOrderAmount': minimumOrderAmount,
      'maximumDiscountAmount': maximumDiscountAmount,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
    };
  }

  double calculateDiscount(double subtotal) {
    if (subtotal < minimumOrderAmount) return 0.0;

    double discount = 0.0;
    if (discountType == 'percentage') {
      discount = subtotal * (discountValue / 100.0);
      if (discount > maximumDiscountAmount) {
        discount = maximumDiscountAmount;
      }
    } else if (discountType == 'flat') {
      discount = discountValue;
    }
    return discount;
  }
}
