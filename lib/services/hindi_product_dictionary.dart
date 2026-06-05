const Map<String, String> hindiProductDictionary = {
  'aloo': 'Potato',
  'aaloo': 'Potato',
  'alu': 'Potato',
  'tamatar': 'Tomato',
  'doodh': 'Milk',
  'cheeni': 'Sugar',
  'chini': 'Sugar',
  'pyaz': 'Onion',
  'pyaaz': 'Onion',
  'adrak': 'Ginger',
  'lehsun': 'Garlic',
  'paneer': 'Paneer',
  'dahi': 'Curd',
  'makkhan': 'Butter',
  'namak': 'Salt',
  'chawal': 'Rice',
  'aata': 'Atta',
  'atta': 'Atta',
  'dal': 'Pulse',
  'daal': 'Pulse',
  'tel': 'Oil',
  'ghee': 'Ghee',
  'chai': 'Tea',
  'patti': 'Tea',
  'shakkar': 'Sugar',
  'paani': 'Water',
  'pani': 'Water',
  'kela': 'Banana',
  'seb': 'Apple',
  'santra': 'Orange',
  'aam': 'Mango',
};

const Map<String, double> hindiMarwariQuantityDictionary = {
  'पाव': 0.25,
  'पावरा': 0.25,
  'आधा': 0.50,
  'आधा किलो': 0.50,
  'पौन': 0.75,
  'पौन किलो': 0.75,
  'एक किलो': 1.00,
};

const Map<String, String> hindiMarwariUnitDictionary = {
  'बोतल': 'bottle',
  'लीटर': 'liter',
  'पैकेट': 'packet',
  'डिब्बा': 'box',
  'थैली': 'bag',
};

class ParsedVoiceOrder {
  final double quantity;
  final String unit;
  final String productKeyword;

  ParsedVoiceOrder({
    required this.quantity,
    required this.unit,
    required this.productKeyword,
  });

  @override
  String toString() => 'Qty: $quantity, Unit: $unit, Product: $productKeyword';
}

String translateHindiProduct(String text) {
  final clean = text.toLowerCase().trim();
  if (hindiProductDictionary.containsKey(clean)) {
    return hindiProductDictionary[clean]!;
  }

  // Try partial fuzzy keyword matches
  for (var key in hindiProductDictionary.keys) {
    if (clean.contains(key)) {
      return hindiProductDictionary[key]!;
    }
  }
  return text;
}

ParsedVoiceOrder parseVoiceInput(String text) {
  final clean = text.toLowerCase().trim();

  double quantity = 1.0;
  String unit = 'packet';
  String productKeyword = text;

  // 1. Try to find quantity in dictionary
  for (var key in hindiMarwariQuantityDictionary.keys) {
    if (clean.contains(key)) {
      quantity = hindiMarwariQuantityDictionary[key]!;
      productKeyword = productKeyword.replaceAll(key, '');
      break;
    }
  }

  // 2. Try to find unit in dictionary
  for (var key in hindiMarwariUnitDictionary.keys) {
    if (clean.contains(key)) {
      unit = hindiMarwariUnitDictionary[key]!;
      productKeyword = productKeyword.replaceAll(key, '');
      break;
    }
  }

  // Find numerical counts (e.g., "2 packet milk")
  final numMatch = RegExp(r'\b(\d+(?:\.\d+)?)\b').firstMatch(clean);
  if (numMatch != null) {
    final parsedNum = double.tryParse(numMatch.group(1) ?? '');
    if (parsedNum != null) {
      quantity = parsedNum;
      productKeyword = productKeyword.replaceAll(numMatch.group(1)!, '');
    }
  }

  // Clean trailing spaces and helper speech words
  productKeyword = productKeyword
      .replaceAll(
        RegExp(
          r'(?:chahiye|do|add\s*karo|de\s*do|le\s*lo|kilo|gram|gm|kg|lekar)',
          caseSensitive: false,
        ),
        '',
      )
      .trim();

  // Translate product name using helper
  productKeyword = translateHindiProduct(productKeyword);

  return ParsedVoiceOrder(
    quantity: quantity,
    unit: unit,
    productKeyword: productKeyword,
  );
}
