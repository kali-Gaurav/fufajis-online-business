/// 💰 Pricing Utilities
/// Calculate prices, GST, discounts, and format for Indian currency (INR)

class PricingUtils {
  /// Standard GST rate for products in India (18%)
  static const double defaultGstRate = 18.0;

  /// Format amount as Indian Rupees (₹)
  /// Examples:
  /// - 99 → ₹99
  /// - 1000 → ₹1,000
  /// - 1000000 → ₹10,00,000 (Indian numbering)
  static String formatINR(double amount) {
    if (amount.isNaN || amount.isInfinite) return '₹0';

    // Round to 2 decimal places
    String formatted = amount.toStringAsFixed(2);

    // Convert to int if no decimals
    if (formatted.endsWith('.00')) {
      formatted = amount.toInt().toString();
    }

    // Add Indian number formatting (commas at specific positions)
    return '₹${_addIndianNumberFormatting(formatted)}';
  }

  /// Add Indian number formatting with commas
  /// Indian format: XX,XX,XXX (commas at 2-digit intervals from right)
  /// Example: 1000000 → 10,00,000
  static String _addIndianNumberFormatting(String number) {
    // Split into integer and decimal parts if exists
    List<String> parts = number.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? '.${parts[1]}' : '';

    // If less than 100, no formatting needed
    if (integerPart.length <= 2) {
      return integerPart + decimalPart;
    }

    // Format: add comma from right
    // First comma after 3 digits from right
    // Subsequent commas after every 2 digits
    String result = '';
    int count = 0;

    for (int i = integerPart.length - 1; i >= 0; i--) {
      if (count == 3 || (count > 3 && (count - 3) % 2 == 0)) {
        result = ',' + result;
      }
      result = integerPart[i] + result;
      count++;
    }

    return result + decimalPart;
  }

  /// Calculate discounted price
  /// Example: basePrice=100, discount=20% → 80
  static double calculateDiscountedPrice(double basePrice, double discountPercent) {
    if (basePrice < 0 || discountPercent < 0 || discountPercent > 100) {
      throw ArgumentError('Invalid price or discount values');
    }
    return basePrice * (1 - (discountPercent / 100));
  }

  /// Calculate GST amount on a price
  /// Example: price=100, gstRate=18% → 18
  static double calculateGST(double price, [double gstRate = defaultGstRate]) {
    if (price < 0 || gstRate < 0 || gstRate > 100) {
      throw ArgumentError('Invalid price or GST rate');
    }
    return price * (gstRate / 100);
  }

  /// Calculate final price (base + GST + discount)
  /// Example: basePrice=100, discount=10%, gst=18%
  /// → discountedPrice=90, gstAmount=16.2, finalPrice=106.2
  static double calculateFinalPrice(
    double basePrice,
    double discountPercent, [
    double gstRate = defaultGstRate,
  ]) {
    double discounted = calculateDiscountedPrice(basePrice, discountPercent);
    double gst = calculateGST(discounted, gstRate);
    return discounted + gst;
  }

  /// Calculate discount percentage between two prices
  /// Example: original=100, discounted=80 → 20%
  static double calculateDiscountPercent(double originalPrice, double discountedPrice) {
    if (originalPrice <= 0) return 0;
    return ((originalPrice - discountedPrice) / originalPrice) * 100;
  }

  /// Get discount percentage as rounded integer
  static int getDiscountPercentInt(double original, double discounted) {
    return calculateDiscountPercent(original, discounted).round();
  }

  /// Create a detailed price breakdown
  static PriceBreakdown getPriceBreakdown(
    double basePrice,
    double discountPercent, [
    double gstRate = defaultGstRate,
  ]) {
    double discountedPrice = calculateDiscountedPrice(basePrice, discountPercent);
    double gstAmount = calculateGST(discountedPrice, gstRate);
    double finalPrice = discountedPrice + gstAmount;

    return PriceBreakdown(
      basePrice: basePrice,
      discountPercent: discountPercent,
      discountAmount: basePrice - discountedPrice,
      priceAfterDiscount: discountedPrice,
      gstRate: gstRate,
      gstAmount: gstAmount,
      finalPrice: finalPrice,
    );
  }

  /// Format price breakdown as human-readable string
  static String formatPriceBreakdown(PriceBreakdown breakdown) {
    return '''
Base Price: ${formatINR(breakdown.basePrice)}
Discount (${breakdown.discountPercent.toStringAsFixed(1)}%): -${formatINR(breakdown.discountAmount)}
Price after Discount: ${formatINR(breakdown.priceAfterDiscount)}
GST (${breakdown.gstRate.toStringAsFixed(1)}%): +${formatINR(breakdown.gstAmount)}
Final Price: ${formatINR(breakdown.finalPrice)}
    '''.trim();
  }

  /// Check if prices are reasonable (not negative, not too high)
  static bool isValidPrice(double price, [double maxPrice = 10000]) {
    return price >= 0 && price <= maxPrice && !price.isNaN && !price.isInfinite;
  }

  /// Round price to nearest rupee
  static double roundToNearestRupee(double price) {
    return price.round().toDouble();
  }

  /// Round price to nearest 50 paise
  static double roundToNearest50Paise(double price) {
    return (price * 2).round() / 2;
  }

  /// Calculate savings amount
  static double calculateSavings(double originalPrice, double finalPrice) {
    double savings = originalPrice - finalPrice;
    return savings > 0 ? savings : 0;
  }

  /// Get payment options based on price
  /// Example: return suitable payment methods for this amount
  static List<String> getPaymentOptions(double amount) {
    List<String> options = ['UPI', 'Debit Card', 'Credit Card'];

    // Add EMI option for high-value purchases
    if (amount > 5000) {
      options.add('EMI (3/6/12 months)');
    }

    // Add bank transfer for very high values
    if (amount > 50000) {
      options.add('Bank Transfer');
    }

    return options;
  }
}

/// Price breakdown details
class PriceBreakdown {
  final double basePrice;
  final double discountPercent;
  final double discountAmount;
  final double priceAfterDiscount;
  final double gstRate;
  final double gstAmount;
  final double finalPrice;

  PriceBreakdown({
    required this.basePrice,
    required this.discountPercent,
    required this.discountAmount,
    required this.priceAfterDiscount,
    required this.gstRate,
    required this.gstAmount,
    required this.finalPrice,
  });

  /// Get savings as formatted string
  String get formattedSavings =>
      PricingUtils.formatINR(discountAmount);

  /// Get breakdown as map
  Map<String, dynamic> toMap() => {
        'basePrice': basePrice,
        'discountPercent': discountPercent,
        'discountAmount': discountAmount,
        'priceAfterDiscount': priceAfterDiscount,
        'gstRate': gstRate,
        'gstAmount': gstAmount,
        'finalPrice': finalPrice,
      };
}
