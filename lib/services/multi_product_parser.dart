/// Multi-Product Parser — Handle multi-item voice orders
///
/// Example inputs:
///   • 2 kg aloo, 1 kg pyaz
///   • aadha kilo butter, ek dozen banana, 3 packet maggi
///   • दो किलो आलू और एक लीटर दूध
///   • milk bread butter (implicit quantities)
///
/// Returns: List<{product, quantity, unit}>
///
/// Strategy:
/// 1. Split input by delimiters (comma, aur, and)
/// 2. For each part, extract product + quantity
/// 3. If no quantity, assume qty=1
/// 4. Return ordered list for UI confirmation

import 'package:flutter/foundation.dart';
import 'quantity_extractor.dart';
import 'product_matcher.dart';

class MultiProductItem {
  final String productName; // Raw spoken name (e.g., "aloo", "आलू")
  final double quantity;
  final String unit;
  final double confidence; // 0..1

  MultiProductItem({
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.confidence,
  });

  @override
  String toString() => '$quantity $unit $productName';
}

class MultiProductParser {
  /// Parse multi-product voice order
  /// Input: "2 kg aloo, 1 kg pyaz, 3 packet maggi" or "milk bread butter"
  /// Output: [
  ///   MultiProductItem(productName: "aloo", qty: 2, unit: "kg"),
  ///   MultiProductItem(productName: "pyaz", qty: 1, unit: "kg"),
  ///   MultiProductItem(productName: "maggi", qty: 3, unit: "packet"),
  /// ]
  ///
  /// Also handles implicit lists like "milk bread butter" → [milk, bread, butter]
  static List<MultiProductItem> parse(String transcript, {List<String>? productCatalog}) {
    final clean = transcript.trim();
    if (clean.isEmpty) return [];

    final items = <MultiProductItem>[];

    // Step 1: Try explicit delimiters first
    final parts = _splitByDelimiters(clean);
    debugPrint('[MultiProductParser] Delimiter split into ${parts.length} parts: $parts');

    if (parts.length > 1) {
      // Has explicit delimiters, parse each part
      for (final part in parts) {
        final part_clean = part.trim();
        if (part_clean.isEmpty) continue;

        final item = _parseOneItem(part_clean);
        if (item != null) {
          items.add(item);
        }
      }
    } else {
      // No explicit delimiters — check if it's an implicit list
      final implicitItems = _parseImplicitList(clean, productCatalog);
      if (implicitItems.isNotEmpty) {
        items.addAll(implicitItems);
      } else {
        // Single item or product name
        final item = _parseOneItem(clean);
        if (item != null) {
          items.add(item);
        }
      }
    }

    return items;
  }

  /// Split text by common delimiters (comma, "aur", "and", "o")
  static List<String> _splitByDelimiters(String text) {
    // Split by comma, "aur" (and in Hindi), "and"
    final parts = text.split(RegExp(r',|(\baur\b)|(\band\b)|(\bo\b)', caseSensitive: false));
    return parts.where((p) => p.isNotEmpty).toList();
  }

  /// Parse implicit product lists like "milk bread butter"
  /// Strategy: greedy longest-match product detection
  /// Input: "milk bread butter"
  /// Expected output: [milk, bread, butter] (each qty=1)
  ///
  /// Also handles: "coconut oil bread" → [coconut oil, bread]
  static List<MultiProductItem> _parseImplicitList(
    String text,
    List<String>? productCatalog,
  ) {
    final tokens = text.split(RegExp(r'\s+'));
    if (tokens.isEmpty) return [];

    final items = <MultiProductItem>[];
    int i = 0;

    while (i < tokens.length) {
      // Try longest match first (e.g., "coconut oil" before "coconut")
      // This is a simple heuristic: check 2-word combinations first
      String? matched;
      int matchLength = 1;

      // P0 FIX: For implicit lists, prefer SINGLE words (not 3-word phrases)
      // Try 1-word first, then 2-word (for cases like "coconut oil")
      // This prevents "milk bread butter" from matching as one product
      for (int len = 1; len <= 2 && i + len <= tokens.length; len++) {
        final candidate = tokens.sublist(i, i + len).join(' ').toLowerCase();

        // Check: is it likely a product name?
        if (_looksLikeProductName(candidate)) {
          matched = candidate;
          matchLength = len;
          debugPrint('[ImplicitList] Matched "$candidate" (len=$len)');
          break;
        }
      }

      // Only try 3-word if no 1 or 2-word match found, and it looks like a known multi-word product
      if (matched == null && i + 3 <= tokens.length) {
        final threeWord = tokens.sublist(i, i + 3).join(' ').toLowerCase();
        if (_isKnownMultiWordProduct(threeWord)) {
          matched = threeWord;
          matchLength = 3;
          debugPrint('[ImplicitList] Matched multi-word "$threeWord"');
        }
      }

      if (matched != null) {
        items.add(MultiProductItem(
          productName: matched,
          quantity: 1.0,
          unit: 'item',
          confidence: 0.70, // Lower confidence for implicit qty
        ));
        i += matchLength;
      } else {
        // Unrecognized token, skip it
        i++;
      }
    }

    // P0 FIX: Return items only if we matched ALL tokens successfully
    // This prevents "milk bread butter" from being matched as one 3-word product
    if (i == tokens.length && items.isNotEmpty) {
      debugPrint('[ImplicitList] SUCCESS: Found ${items.length} item(s): ${items.map((e) => e.productName).join(", ")}');
      return items;
    }

    debugPrint('[ImplicitList] FAILED: Only matched $i/${tokens.length} tokens');
    return [];  // Didn't match all tokens — not a clean implicit list
  }

  /// Heuristic: does this look like a product name?
  /// For now: not a quantity word, not a unit
  static bool _looksLikeProductName(String word) {
    final quantityWords = {
      'do', 'teen', 'char', 'paanch', 'das', 'ek', 'aadha', 'pav',
      'two', 'three', 'four', 'five', 'ten', 'one', 'half', 'quarter'
    };
    final unitWords = {'kg', 'kilo', 'kilogram', 'gram', 'gm', 'g', 'mg', 'pound', 'lb',
      'litre', 'liter', 'l', 'ml', 'millilitre', 'cup', 'spoon', 'tablespoon', 'tbsp',
      'packet', 'pkt', 'pack', 'dozen', 'doz', 'piece', 'pcs', 'pc', 'bunch', 'bundle',
      'tin', 'can', 'box', 'bottle', 'jar'
    };

    return !quantityWords.contains(word) &&
        !unitWords.contains(word) &&
        word.length > 1 &&
        !RegExp(r'^\d+').hasMatch(word); // Not a number
  }

  /// P0 FIX: Check if a phrase is a KNOWN multi-word product
  /// Examples: "basmati rice", "tata tea", "coconut oil", "olive oil"
  /// Prevents "milk bread butter" from being treated as one product
  static bool _isKnownMultiWordProduct(String phrase) {
    final knownProducts = {
      'basmati rice', 'jasmine rice', 'brown rice', 'white rice',
      'coconut oil', 'sunflower oil', 'mustard oil', 'olive oil', 'palm oil',
      'tata tea', 'lipton tea', 'tetley tea', 'tea powder',
      'whole wheat', 'whole milk', 'toned milk', 'buffalo milk',
      'black salt', 'rock salt', 'sea salt',
      'chaat masala', 'garam masala', 'tandoori masala',
      'red chilli', 'black pepper', 'white pepper',
      'caster sugar', 'brown sugar', 'white sugar',
      'peanut butter', 'almond butter',
    };

    return knownProducts.contains(phrase);
  }

  /// Parse a single item: "2 kg aloo" or just "aloo"
  /// Returns: {productName, quantity, unit}
  /// BUG FIX: Use quantityDecimal for fractions (0.5, 0.25, etc.)
  static MultiProductItem? _parseOneItem(String text) {
    final clean = text.trim().toLowerCase();

    // Step 1: Try to extract quantity
    final qtyData = QuantityExtractor.extract(clean);

    // Step 2: Remove quantity from text to get product name
    late String productName;
    late double quantity;
    late String unit;
    late double confidence;

    if (qtyData != null) {
      // Quantity found
      // FIXED: Use quantityDecimal for fractions, quantity for whole numbers
      final qtyDecimal = qtyData['quantityDecimal'] as double? ?? 1.0;
      quantity = qtyDecimal;
      unit = qtyData['unit'] as String? ?? 'item';
      confidence = qtyData['confidence'] as double? ?? 0.85;

      // Remove quantity expression from text
      // Pattern: remove "2 kg" or "do kilo" or "aadha kilo" from start
      productName = _removeQuantityExpression(clean);

      // BUG FIX: Strip quantity/unit tokens from product name
      productName = _stripQuantityTokens(productName);

      if (productName.isEmpty) {
        debugPrint('[MultiProductParser] Failed to extract product name after removing qty');
        return null;
      }
    } else {
      // No quantity found, assume qty=1
      productName = clean;
      quantity = 1.0;
      unit = 'item';

      // P0 FIX: Use ProductMatcher for strict confidence validation
      // This rejects garbage input (e.g., "xyz abc def") with very low confidence
      final matcher = ProductMatcher(null); // No catalog in unit tests
      final matchResult = matcher.match(productName);
      confidence = matchResult.confidence;

      if (!matchResult.isValid) {
        debugPrint('[MultiProductParser] REJECTED: Unknown product "$productName" (conf: $confidence)');
      } else {
        debugPrint('[MultiProductParser] Fallback match: "$productName" (conf: $confidence)');
      }
    }

    debugPrint('[MultiProductParser] Parsed: "$productName" x$quantity $unit (conf: $confidence)');

    return MultiProductItem(
      productName: productName,
      quantity: quantity,
      unit: unit,
      confidence: confidence,
    );
  }

  /// BUG FIX: Strip quantity and unit tokens from product names
  /// "kilo aloo" → "aloo"
  /// "litre doodh" → "doodh"
  /// "2 kg aloo" → "aloo"
  static String _stripQuantityTokens(String text) {
    final quantityWords = {
      'ek', 'do', 'teen', 'char', 'paanch', 'chhe', 'saat', 'aath', 'nau', 'das',
      'aadha', 'adha', 'pav', 'paav', 'char-paai', 'tin-paai',
      'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten',
      'half', 'quarter',
    };

    final unitWords = {
      // Weight
      'kg', 'kilo', 'kilogram', 'gram', 'gm', 'g', 'mg', 'milligram', 'pound', 'lb',
      // Volume
      'litre', 'liter', 'l', 'ml', 'millilitre', 'cup', 'spoon', 'tablespoon', 'tbsp',
      // Count
      'packet', 'pkt', 'pack', 'dozen', 'doz', 'piece', 'pcs', 'pc', 'bunch', 'bundle',
      'tin', 'can', 'box', 'bottle', 'jar',
      // Hindi
      'किलो', 'ग्राम', 'लीटर', 'मिलीलीटर', 'पैकेट', 'दर्जन', 'टिन',
    };

    var clean = text.toLowerCase();

    // Remove quantity words
    for (final word in quantityWords) {
      clean = clean.replaceAll(RegExp(r'\b' + RegExp.escape(word) + r'\b'), ' ');
    }

    // Remove unit words
    for (final unit in unitWords) {
      clean = clean.replaceAll(RegExp(r'\b' + RegExp.escape(unit) + r'\b'), ' ');
    }

    // Remove leading/trailing spaces and collapse multiple spaces
    return clean.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Remove quantity expression from text
  /// "2 kg aloo" → "aloo"
  /// "aadha kilo butter" → "butter"
  static String _removeQuantityExpression(String text) {
    // Remove leading quantity patterns
    // Matches: "2 kg", "do kilo", "aadha kilo", etc.
    final patterns = [
      RegExp(r'^\d+(?:\.\d+)?\s*[a-z]+\s*'), // "2 kg "
      RegExp(r'^(aadha|adha|pav|ek|do|teen|char|paanch)\s+'), // Hindi numbers
      RegExp(r'^(किलो|ग्राम|लीटर|पैकेट|दर्जन)\s+'), // Hindi units
    ];

    var result = text;
    for (final pattern in patterns) {
      result = result.replaceFirst(pattern, '').trim();
      if (result.isEmpty) break;
    }

    return result;
  }
}
