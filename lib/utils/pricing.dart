import 'package:intl/intl.dart';

/// Pricing and GST calculation utilities for Indian e-commerce
class PricingUtils {
  static const double DEFAULT_GST_RATE = 18.0; // 18% GST

  /// Calculate GST amount for a base price
  /// Returns: GST amount
  static double calculateGST(double basePrice, {double gstRate = DEFAULT_GST_RATE}) {
    return (basePrice * gstRate) / 100.0;
  }

  /// Calculate total price including GST
  /// Returns: basePrice + GST
  static double calculateTotal(double basePrice, {double gstRate = DEFAULT_GST_RATE}) {
    return basePrice + calculateGST(basePrice, gstRate: gstRate);
  }

  /// Format amount as Indian Rupees (₹)
  /// Example: 1000 → "₹1,000.00"
  static String formatINR(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Format amount as INR without decimal places
  /// Example: 1000 → "₹1,000"
  static String formatINRCompact(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  /// Get pricing breakdown for an order
  /// Returns: {base, gst, total, gstRate}
  static Map<String, double> getPriceBreakdown(
    double basePrice, {
    double gstRate = DEFAULT_GST_RATE,
  }) {
    final gstAmount = calculateGST(basePrice, gstRate: gstRate);
    final total = basePrice + gstAmount;

    return {
      'base': basePrice,
      'gst': gstAmount,
      'total': total,
      'gstRate': gstRate,
    };
  }

  /// Round to 2 decimal places (common for currency)
  static double roundToTwo(double value) {
    return (value * 100).round() / 100;
  }

  /// Check if amount is valid (> 0)
  static bool isValidAmount(double amount) {
    return amount > 0;
  }

  /// Apply discount percentage
  /// Returns: discounted amount
  static double applyDiscount(double amount, double discountPercent) {
    return amount * (1 - discountPercent / 100);
  }

  /// Calculate discount amount
  /// Returns: discount amount
  static double calculateDiscount(double amount, double discountPercent) {
    return amount * (discountPercent / 100);
  }
}

/// Pricing UI helper for display
class PricingDisplay {
  final double basePrice;
  final double gstAmount;
  final double gstRate;

  double get totalPrice => basePrice + gstAmount;

  PricingDisplay({
    required this.basePrice,
    required this.gstRate,
  }) : gstAmount = PricingUtils.calculateGST(basePrice, gstRate: gstRate);

  String get basePriceFormatted => PricingUtils.formatINR(basePrice);
  String get gstAmountFormatted => PricingUtils.formatINR(gstAmount);
  String get totalPriceFormatted => PricingUtils.formatINR(totalPrice);

  String get basePriceCompact => PricingUtils.formatINRCompact(basePrice);
  String get gstAmountCompact => PricingUtils.formatINRCompact(gstAmount);
  String get totalPriceCompact => PricingUtils.formatINRCompact(totalPrice);

  /// Get GST display string
  /// Example: "18% GST"
  String get gstDisplayString {
    return '${gstRate.toStringAsFixed(0)}% GST';
  }

  /// Get full breakdown string
  /// Example: "₹100 + ₹18 GST = ₹118"
  String get breakdownString {
    return '$basePriceFormatted + $gstAmountFormatted GST = $totalPriceFormatted';
  }

  /// Get compact breakdown
  /// Example: "₹100 + ₹18 = ₹118"
  String get breakdownCompact {
    return '$basePriceCompact + $gstAmountCompact = $totalPriceCompact';
  }
}
