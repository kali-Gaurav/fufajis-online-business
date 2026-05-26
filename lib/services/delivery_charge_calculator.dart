import 'package:flutter/material.dart';
import '../models/delivery_type.dart';

/// Service for calculating delivery charges based on order subtotal and delivery type
class DeliveryChargeCalculator {
  /// Threshold for free standard delivery
  static const double freeDeliveryThreshold = 500.0;

  /// Threshold for reduced standard delivery charge
  static const double reducedDeliveryThreshold = 200.0;

  /// Standard delivery charge for orders below reduced threshold
  static const double standardDeliveryChargeBelow200 = 40.0;

  /// Standard delivery charge for orders between reduced and free threshold
  static const double standardDeliveryChargeBelow500 = 20.0;

  /// Express delivery base charge
  static const double expressDeliveryCharge = 50.0;

  /// Same day delivery base charge
  static const double sameDayDeliveryCharge = 100.0;

  /// Village delivery base charge
  static const double villageDeliveryCharge = 30.0;

  /// Calculate delivery charge based on delivery type and order subtotal
  ///
  /// [type] - The selected delivery type
  /// [subtotal] - The order subtotal amount
  ///
  /// Returns the calculated delivery charge
  static double calculateDeliveryCharge(DeliveryType type, double subtotal) {
    switch (type) {
      case DeliveryType.standard:
        return _calculateStandardDeliveryCharge(subtotal);
      case DeliveryType.express:
        return expressDeliveryCharge;
      case DeliveryType.sameDay:
        return sameDayDeliveryCharge;
      case DeliveryType.villageDelivery:
        return villageDeliveryCharge;
      case DeliveryType.scheduled:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  /// Calculate standard delivery charge based on subtotal
  static double _calculateStandardDeliveryCharge(double subtotal) {
    if (subtotal >= freeDeliveryThreshold) {
      return 0.0;
    } else if (subtotal >= reducedDeliveryThreshold) {
      return standardDeliveryChargeBelow500;
    } else {
      return standardDeliveryChargeBelow200;
    }
  }

  /// Get estimated delivery date based on delivery type
  ///
  /// [type] - The selected delivery type
  /// [fromDate] - The starting date (defaults to now)
  ///
  /// Returns the estimated delivery date
  static DateTime getEstimatedDeliveryDate(
    DeliveryType type, {
    DateTime? fromDate,
  }) {
    final now = fromDate ?? DateTime.now();
    final option = DeliveryTypeOption.fromType(type);
    return now.add(Duration(days: option.estimatedDays));
  }

  /// Get formatted estimated delivery date string
  ///
  /// [type] - The selected delivery type
  /// [fromDate] - The starting date (defaults to now)
  ///
  /// Returns a formatted string like "Tomorrow, 10 Jan" or "Within 8 hours"
  static String getFormattedDeliveryDate(
    DeliveryType type, {
    DateTime? fromDate,
  }) {
    final now = fromDate ?? DateTime.now();
    final option = DeliveryTypeOption.fromType(type);

    if (option.estimatedTime != null && option.estimatedTime!.isNotEmpty) {
      return option.estimatedTime!;
    }

    final estimatedDate = now.add(Duration(days: option.estimatedDays));
    final today = DateTime(now.year, now.month, now.day);
    final estimatedDay = DateTime(
      estimatedDate.year,
      estimatedDate.month,
      estimatedDate.day,
    );

    if (estimatedDay == today) {
      return 'Today';
    } else if (estimatedDay.difference(today).inDays == 1) {
      return 'Tomorrow';
    } else {
      final dayName = _getDayName(estimatedDate);
      final dateStr = '${estimatedDate.day} ${_getMonthName(estimatedDate)}';
      return '$dayName, $dateStr';
    }
  }

  /// Get day name for date formatting
  static String _getDayName(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }

  /// Get month name for date formatting
  static String _getMonthName(DateTime date) {
    switch (date.month) {
      case DateTime.january:
        return 'Jan';
      case DateTime.february:
        return 'Feb';
      case DateTime.march:
        return 'Mar';
      case DateTime.april:
        return 'Apr';
      case DateTime.may:
        return 'May';
      case DateTime.june:
        return 'Jun';
      case DateTime.july:
        return 'Jul';
      case DateTime.august:
        return 'Aug';
      case DateTime.september:
        return 'Sep';
      case DateTime.october:
        return 'Oct';
      case DateTime.november:
        return 'Nov';
      case DateTime.december:
        return 'Dec';
      default:
        return '';
    }
  }

  /// Get delivery charge details for display
  ///
  /// [type] - The selected delivery type
  /// [subtotal] - The order subtotal amount
  ///
  /// Returns a map with charge details
  static Map<String, dynamic> getDeliveryDetails(
    DeliveryType type,
    double subtotal,
  ) {
    final charge = calculateDeliveryCharge(type, subtotal);
    final formattedDate = getFormattedDeliveryDate(type);
    final option = DeliveryTypeOption.fromType(type);

    return {
      'charge': charge,
      'formattedCharge': charge == 0 ? 'FREE' : '₹${charge.round()}',
      'estimatedDate': formattedDate,
      'estimatedDateTime': getEstimatedDeliveryDate(type),
      'name': option.name,
      'description': option.description,
      'isFree': charge == 0,
    };
  }

  /// Check if standard delivery is free for the given subtotal
  static bool isStandardDeliveryFree(double subtotal) {
    return subtotal >= freeDeliveryThreshold;
  }

  /// Get the amount needed for free standard delivery
  static double getAmountNeededForFreeDelivery(double subtotal) {
    if (subtotal >= freeDeliveryThreshold) {
      return 0;
    }
    return freeDeliveryThreshold - subtotal;
  }

  /// Calculate total order amount including delivery
  ///
  /// [subtotal] - The order subtotal
  /// [deliveryType] - The selected delivery type
  /// [discount] - Any discount amount (optional)
  /// [walletAmount] - Wallet amount to apply (optional)
  ///
  /// Returns the total order amount
  static double calculateTotal({
    required double subtotal,
    required DeliveryType deliveryType,
    double discount = 0,
    double walletAmount = 0,
  }) {
    final deliveryCharge = calculateDeliveryCharge(deliveryType, subtotal);
    final total = subtotal - discount + deliveryCharge - walletAmount;
    return total.clamp(0, total);
  }
}
