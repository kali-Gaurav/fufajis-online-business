import '../models/product_model.dart';
import 'package:intl/intl.dart';

/// GST (Goods and Services Tax) service for Indian tax compliance
/// Handles tax rate determination, calculations, and reporting
class GSTService {
  /// GST rates by product category (as per Indian taxation rules)
  static const Map<ProductCategory, double> gstRatesByCategory = {
    // 5% GST categories
    ProductCategory.groceries: 5.0,
    ProductCategory.vegetables: 5.0,
    ProductCategory.fruits: 5.0,
    ProductCategory.dairy: 5.0,
    ProductCategory.bakery: 5.0,
    ProductCategory.beverages: 5.0,
    ProductCategory.medicines: 5.0,
    ProductCategory.agricultural: 5.0,

    // 12% GST categories
    ProductCategory.snacks: 12.0,
    ProductCategory.household: 12.0,
    ProductCategory.personalCare: 12.0,
    ProductCategory.clothing: 12.0,
    ProductCategory.footwear: 12.0,
    ProductCategory.stationery: 12.0,

    // 18% GST categories
    ProductCategory.electronics: 18.0,
    ProductCategory.homeDecor: 18.0,
    ProductCategory.kitchenware: 18.0,

    // 28% GST categories (Luxury)
    ProductCategory.toys: 28.0,

    // Default 18%
    ProductCategory.other: 18.0,
  };

  /// Get GST rate for a product category
  /// Returns: 5.0, 12.0, 18.0, or 28.0 (percent)
  static double getProductGSTRate(ProductCategory category) {
    return gstRatesByCategory[category] ?? 18.0;
  }

  /// Calculate tax amount given base amount and GST rate
  /// [amount]: Base amount (before tax)
  /// [gstRate]: Tax rate as percentage (e.g., 5.0 for 5%)
  /// Returns: Tax amount
  static double calculateTax(double amount, double gstRate) {
    if (amount <= 0 || gstRate <= 0) return 0.0;
    return double.parse(((amount * gstRate) / 100).toStringAsFixed(2));
  }

  /// Calculate amount with tax included
  /// [amount]: Base amount (before tax)
  /// [gstRate]: Tax rate as percentage
  /// Returns: Amount including tax
  static double calculateAmountWithTax(double amount, double gstRate) {
    if (amount <= 0) return 0.0;
    final tax = calculateTax(amount, gstRate);
    return double.parse((amount + tax).toStringAsFixed(2));
  }

  /// Calculate grand total from subtotal, discount, and tax
  static double calculateGrandTotal({
    required double subtotal,
    required double totalTax,
    double discount = 0.0,
  }) {
    if (subtotal <= 0 && totalTax <= 0) return 0.0;
    final total = subtotal + totalTax - discount;
    return double.parse(total.toStringAsFixed(2));
  }

  /// Validate GSTIN (Goods and Services Tax Identification Number) format
  /// GSTIN format: 2 digits (state) + 10 chars (PAN) + 1 digit (entity) + 1 digit (check)
  /// Example: 27AAJCU1205R1Z0
  static bool validateGSTIN(String gstin) {
    if (gstin.isEmpty) return false;

    // Remove spaces and convert to uppercase
    final cleanGstin = gstin.replaceAll(' ', '').toUpperCase();

    // GSTIN must be 15 characters
    if (cleanGstin.length != 15) return false;

    // First 2 chars: state code (numeric)
    if (!RegExp(r'^\d{2}').hasMatch(cleanGstin)) return false;

    // Next 10 chars: PAN (alphanumeric, starts with 5 letters)
    final panSection = cleanGstin.substring(2, 12);
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(panSection)) return false;

    // Next char: entity type (numeric)
    if (!RegExp(r'\d').hasMatch(cleanGstin[12])) return false;

    // Last char: check digit (alphanumeric)
    if (!RegExp(r'[A-Z0-9]').hasMatch(cleanGstin[14])) return false;

    return true;
  }

  /// Format amount in Indian currency
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    return formatter.format(amount);
  }

  /// Get GST rate category name for display
  static String getGSTRateCategory(double rate) {
    switch (rate) {
      case 5.0:
        return 'Essentials (5%)';
      case 12.0:
        return 'Standard (12%)';
      case 18.0:
        return 'Regular (18%)';
      case 28.0:
        return 'Luxury (28%)';
      default:
        return 'Other';
    }
  }

  /// Get list of all unique GST rates used in an invoice
  static List<double> getUniqueGSTRates(List<double> rates) {
    return rates.toSet().toList()..sort();
  }
}

/// GST Report for compliance filing
class GSTReport {
  final String period; // e.g., "Q2-2026" or "2026-06"
  final DateTime generatedAt;
  final double totalSales; // Total sales value
  final Map<double, double> taxByRate; // Rate -> Tax collected
  final double totalTaxLiability; // Total GST collected
  final String? remarks;

  GSTReport({
    required this.period,
    required this.generatedAt,
    required this.totalSales,
    required this.taxByRate,
    this.remarks,
  }) : totalTaxLiability = taxByRate.values.reduce((a, b) => a + b);

  /// Get tax breakdown details
  String getTaxBreakdownSummary() {
    final buffer = StringBuffer();
    buffer.writeln('GST Report - $period');
    buffer.writeln('Generated: ${generatedAt.toIso8601String()}');
    buffer.writeln('Total Sales: ${GSTService.formatCurrency(totalSales)}');
    buffer.writeln('─' * 50);

    for (final rate in GSTService.getUniqueGSTRates(taxByRate.keys.toList())) {
      final tax = taxByRate[rate] ?? 0;
      buffer.writeln('${GSTService.getGSTRateCategory(rate)}: ${GSTService.formatCurrency(tax)}');
    }

    buffer.writeln('─' * 50);
    buffer.writeln('Total GST Liability: ${GSTService.formatCurrency(totalTaxLiability)}');

    if (remarks != null && remarks!.isNotEmpty) {
      buffer.writeln('Remarks: $remarks');
    }

    return buffer.toString();
  }

  /// Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'period': period,
      'generatedAt': generatedAt,
      'totalSales': totalSales,
      'taxByRate': taxByRate,
      'totalTaxLiability': totalTaxLiability,
      'remarks': remarks,
    };
  }

  @override
  String toString() =>
      'GSTReport($period - Liability: ${GSTService.formatCurrency(totalTaxLiability)})';
}
