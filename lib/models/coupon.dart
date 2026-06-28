import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/monetary_value.dart';

class Coupon {
  final String id;
  final String code;
  final String name;
  final String description;
  final String discountType; // 'percentage' or 'flat'
  final MonetaryValue discountValue;
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
      id: map['id'] as String? ?? '',
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      discountType: map['discountType'] as String? ?? 'percentage',
      discountValue: MonetaryValue(map['discountValue'] ?? 0.0),
      minimumOrderAmount: (map['minimumOrderAmount'] as num? ?? 0.0).toDouble(),
      maximumDiscountAmount: (map['maximumDiscountAmount'] as num? ?? 0.0).toDouble(),
      startDate: map['startDate'] != null
          ? (map['startDate'] is DateTime
                ? map['startDate'] as DateTime
                : (map['startDate'] as Timestamp).toDate())
          : DateTime.now(),
      endDate: map['endDate'] != null
          ? (map['endDate'] is DateTime
                ? map['endDate'] as DateTime
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

  MonetaryValue calculateDiscount(MonetaryValue subtotal) {
    final minOrderVal = MonetaryValue(minimumOrderAmount);
    if (subtotal < minOrderVal) return MonetaryValue(0.0);

    MonetaryValue discount = MonetaryValue(0.0);
    if (discountType == 'percentage') {
      discount = subtotal * (discountValue.toDouble() / 100.0);
      final maxDiscountVal = MonetaryValue(maximumDiscountAmount);
      if (discount > maxDiscountVal) {
        discount = maxDiscountVal;
      }
    } else if (discountType == 'flat') {
      discount = discountValue;
    }
    return discount;
  }
}
