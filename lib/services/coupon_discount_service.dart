import 'package:cloud_firestore/cloud_firestore.dart';

/// Coupon Discount Service — Calculate discount amount based on coupon type
/// FIXES BUG: 'fixed' vs 'flat' type mismatch zeroing all discounts
class CouponDiscountService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate discount amount based on coupon type and order subtotal
  static double calculateDiscountAmount({
    required String couponCode,
    required Map<String, dynamic> couponData,
    required double orderSubtotal,
  }) {
    final discountType = couponData['discountType'] as String? ?? 'fixed';
    final discountValue = (couponData['discountValue'] as num?)?.toDouble() ?? 0.0;
    final maxDiscount = (couponData['maxDiscount'] as num?)?.toDouble() ?? double.infinity;

    double calculatedDiscount = 0.0;

    // FIXED: Handle both 'fixed' and 'flat' types correctly
    // (audit found that 'fixed' vs 'flat' mismatch was zeroing discounts)
    if (discountType == 'fixed' || discountType == 'flat') {
      // Fixed rupee amount
      calculatedDiscount = discountValue;
    } else if (discountType == 'percentage' || discountType == 'percent') {
      // Percentage of order subtotal
      calculatedDiscount = (orderSubtotal * discountValue) / 100.0;
    } else {
      // Default: treat as fixed amount
      calculatedDiscount = discountValue;
    }

    // Cap discount at maxDiscount if specified
    if (calculatedDiscount > maxDiscount) {
      calculatedDiscount = maxDiscount;
    }

    // Cap discount at order subtotal (can't discount more than order is worth)
    if (calculatedDiscount > orderSubtotal) {
      calculatedDiscount = orderSubtotal;
    }

    return calculatedDiscount;
  }

  /// Validate coupon before applying
  static Future<({bool valid, String message, Map<String, dynamic>? couponData})> validateCoupon({
    required String couponCode,
    required String userId,
    required double orderSubtotal,
  }) async {
    try {
      final couponDoc = await _firestore
          .collection('coupons')
          .where('code', isEqualTo: couponCode)
          .limit(1)
          .get();

      if (couponDoc.docs.isEmpty) {
        return (valid: false, message: 'Coupon not found', couponData: null);
      }

      final coupon = couponDoc.docs.first.data();
      final isActive = coupon['isActive'] as bool? ?? false;
      final minOrderAmount = (coupon['minOrderAmount'] as num?)?.toDouble() ?? 0.0;
      final maxRedemptions = coupon['maxRedemptions'] as int?;
      final redemptionCount = coupon['redemptionCount'] as int? ?? 0;
      final expiryDate = coupon['expiryDate'] as Timestamp?;

      // Check if active
      if (!isActive) {
        return (valid: false, message: 'Coupon is not active', couponData: null);
      }

      // Check expiry
      if (expiryDate != null && expiryDate.toDate().isBefore(DateTime.now())) {
        return (valid: false, message: 'Coupon has expired', couponData: null);
      }

      // Check min order amount
      if (orderSubtotal < minOrderAmount) {
        return (
          valid: false,
          message: 'Minimum order amount ₹${minOrderAmount.toStringAsFixed(0)} required',
          couponData: null
        );
      }

      // Check redemption limit
      if (maxRedemptions != null && redemptionCount >= maxRedemptions) {
        return (valid: false, message: 'Coupon redemption limit reached', couponData: null);
      }

      return (valid: true, message: 'Coupon is valid', couponData: coupon);
    } catch (e) {
      return (valid: false, message: 'Error validating coupon: $e', couponData: null);
    }
  }

  /// Record coupon redemption
  static Future<bool> recordRedemption({
    required String couponCode,
    required String userId,
    required String orderId,
    required double discountAmount,
  }) async {
    try {
      final couponDoc = await _firestore
          .collection('coupons')
          .where('code', isEqualTo: couponCode)
          .limit(1)
          .get();

      if (couponDoc.docs.isEmpty) return false;

      final couponRef = couponDoc.docs.first.reference;

      // Record redemption + increment counter (atomic)
      await _firestore.runTransaction((transaction) async {
        final couponData = await transaction.get(couponRef);
        final currentCount = (couponData.get('redemptionCount') as int?) ?? 0;

        transaction.update(couponRef, {
          'redemptionCount': currentCount + 1,
          'lastRedemptionDate': FieldValue.serverTimestamp(),
        });

        transaction.set(
          _firestore.collection('coupon_redemptions').doc(),
          {
            'couponCode': couponCode,
            'userId': userId,
            'orderId': orderId,
            'discountAmount': discountAmount,
            'redemptionDate': FieldValue.serverTimestamp(),
          },
        );
      });

      return true;
    } catch (e) {
      print('[CouponDiscountService] Error recording redemption: $e');
      return false;
    }
  }
}
