/// Quantity Extractor — Parse Hindi/Hinglish/English quantity expressions
///
/// Examples it must handle:
///   • 2 kg aloo
///   • aadha kilo pyaz (0.5 kg)
///   • pav kilo tamatar (0.25 kg)
///   • ek dozen banana
///   • 3 packet maggi
///   • ek litre milk
///   • 250 gram butter
///   • 2 लीटर दूध (2 liters milk in Hindi)
///
/// Returns: (quantity: int, unit: String)
/// or null if unparseable

class QuantityExtractor {
  // Hindi number words
  static const Map<String, int> _hindiNumbers = {
    'ek': 1,
    'do': 2,
    'teen': 3,
    'char': 4,
    'paanch': 5,
    'chhe': 6,
    'saat': 7,
    'aath': 8,
    'nau': 9,
    'das': 10,
    'gyarah': 11,
    'barah': 12,
    'trah': 13,
    'chaudah': 14,
    'pandrah': 15,
    'solah': 16,
    'satrah': 17,
    'athrah': 18,
    'unnis': 19,
    'bees': 20,
    'tees': 30,
    'chalis': 40,
    'pachas': 50,
  };

  // Hindi fractional quantities
  static const Map<String, double> _hindiFractions = {
    'aadha': 0.5,
    'adha': 0.5,
    'pav': 0.25,
    'char-paai': 0.25,
    'tin-paai': 0.75,
    'swaad': 0.5, // regional variant
  };

  // Unit conversions (all normalized to base units)
  static const Map<String, String> _unitMap = {
    // Weight
    'kg': 'kg',
    'kilo': 'kg',
    'kilogram': 'kg',
    'gram': 'g',
    'gm': 'g',
    'g': 'g',
    'mg': 'mg',
    'milligram': 'mg',
    'pound': 'lb',
    'lb': 'lb',
    // Volume
    'litre': 'l',
    'liter': 'l',
    'l': 'l',
    'ml': 'ml',
    'millilitre': 'ml',
    'cup': 'cup',
    'spoon': 'tbsp',
    'tablespoon': 'tbsp',
    'tbsp': 'tbsp',
    // Count
    'packet': 'packet',
    'pkt': 'packet',
    'pack': 'packet',
    'dozen': 'dozen',
    'doz': 'dozen',
    'piece': 'piece',
    'pcs': 'piece',
    'pc': 'piece',
    'bunch': 'bunch',
    'bundle': 'bundle',
    'tin': 'tin',
    'can': 'can',
    'box': 'box',
    'bottle': 'bottle',
    'jar': 'jar',
    // Hindi units
    'किलो': 'kg',
    'ग्राम': 'g',
    'लीटर': 'l',
    'मिलीलीटर': 'ml',
    'पैकेट': 'packet',
    'दर्जन': 'dozen',
    'टिन': 'tin',
  };

  /// Extract quantity and unit from spoken text.
  /// Returns {quantity: int, unit: String, latencyMs: int} or null if not found
  static Map<String, dynamic>? extract(String text) {
    final sw = Stopwatch()..start();
    final clean = text.trim().toLowerCase();
    if (clean.isEmpty) return null;

    // Try numeric extraction first (e.g., "2 kg")
    final numericMatch = _extractNumeric(clean);
    if (numericMatch != null) {
      numericMatch['latencyMs'] = sw.elapsedMilliseconds;
      return numericMatch;
    }

    // Try Hindi number words (e.g., "do kilo")
    final hindiMatch = _extractHindi(clean);
    if (hindiMatch != null) {
      hindiMatch['latencyMs'] = sw.elapsedMilliseconds;
      return hindiMatch;
    }

    // Try fractional Hindi (e.g., "aadha kilo")
    final fractionalMatch = _extractFractional(clean);
    if (fractionalMatch != null) {
      fractionalMatch['latencyMs'] = sw.elapsedMilliseconds;
      return fractionalMatch;
    }

    return null;
  }

  /// Extract numeric quantities: "2 kg", "500g", "2.5 litre"
  static Map<String, dynamic>? _extractNumeric(String text) {
    // Pattern: optional decimal number + optional space/no-space + unit
    final patterns = [
      RegExp(r'(\d+(?:\.\d+)?)\s*([a-z]+)'), // 2 kg, 2kg, 2.5 litre
      RegExp(r'(\d+)\s*(\w+)'), // 2 kg (catches all)
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final qtyStr = match.group(1);
        final unitStr = match.group(2)?.trim() ?? '';

        final qty = double.tryParse(qtyStr ?? '0');
        if (qty == null || qty <= 0) continue;

        final normalizedUnit = _unitMap[unitStr] ?? unitStr;
        if (normalizedUnit.isEmpty) continue;

        return {
          'quantity': qty.toInt(),
          'quantityDecimal': qty,
          'unit': normalizedUnit,
          'confidence': 0.95,
        };
      }
    }

    return null;
  }

  /// Extract Hindi number words: "do kilo", "teen litre", "paanch packet"
  static Map<String, dynamic>? _extractHindi(String text) {
    // Split into tokens
    final tokens = text.split(RegExp(r'\s+'));
    if (tokens.isEmpty) return null;

    // First token should be a Hindi number
    final firstToken = tokens[0];
    final quantity = _hindiNumbers[firstToken];
    if (quantity == null) return null;

    // Second token should be a unit
    String? unit;
    for (int i = 1; i < tokens.length; i++) {
      final token = tokens[i];
      unit = _unitMap[token];
      if (unit != null) break;
    }

    if (unit == null || unit.isEmpty) return null;

    return {
      'quantity': quantity,
      'quantityDecimal': quantity.toDouble(),
      'unit': unit,
      'confidence': 0.90,
    };
  }

  /// Extract fractional quantities: "aadha kilo", "pav packet"
  /// BUG FIX: Don't multiply by 1000 — keep fraction as decimal value
  /// "aadha kilo" → 0.5 kg (NOT 500 kg)
  static Map<String, dynamic>? _extractFractional(String text) {
    final tokens = text.split(RegExp(r'\s+'));
    if (tokens.isEmpty) return null;

    // First token should be a fraction
    final firstToken = tokens[0];
    final fraction = _hindiFractions[firstToken];
    if (fraction == null) return null;

    // Second token should be a unit
    String? unit;
    for (int i = 1; i < tokens.length; i++) {
      final token = tokens[i];
      unit = _unitMap[token];
      if (unit != null) break;
    }

    if (unit == null || unit.isEmpty) return null;

    // FIXED: Return fraction as decimal, keep unit as-is
    // Don't convert to grams internally — let caller handle normalization
    return {
      'quantity': fraction.toInt(), // For display as whole number
      'quantityDecimal': fraction, // Actual value (0.5, 0.25, etc.)
      'unit': unit,
      'confidence': 0.90,
    };
  }

  /// Normalize quantity to a standard unit
  /// E.g., 500g → 0.5kg
  static double normalizeToKg(int quantity, String unit) {
    const conversions = {
      'kg': 1.0,
      'g': 0.001,
      'mg': 0.000001,
      'lb': 0.453592,
    };
    return quantity * (conversions[unit] ?? 1.0);
  }

  /// Normalize quantity to a standard volume
  /// E.g., 500ml → 0.5l
  static double normalizeToLiter(int quantity, String unit) {
    const conversions = {
      'l': 1.0,
      'ml': 0.001,
      'cup': 0.236588,
    };
    return quantity * (conversions[unit] ?? 1.0);
  }
}
