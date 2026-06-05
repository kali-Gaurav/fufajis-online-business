import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'hindi_product_dictionary.dart';

/// Component 7 — Hinglish & Local Voice Search Parser
///
/// Handles mixed Hindi-English (Hinglish) voice queries and converts them
/// into structured product search terms. Supports:
///   • Hindi product names (from dictionary + Firestore synonyms)
///   • Marwari fractional quantities (पाव, आधा, पौन)
///   • Numeric quantity patterns ("do kilo aloo", "2 kg potato")
///   • Common Hinglish suffixes (chahiye, de do, add karo, le lo)
///   • Phonetic misspellings via fuzzy matching
///   • Dynamic synonyms from Firestore (can be updated without app release)
class HinglishVoiceSearchParser {
  static final HinglishVoiceSearchParser _instance =
      HinglishVoiceSearchParser._internal();
  factory HinglishVoiceSearchParser() => _instance;
  HinglishVoiceSearchParser._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Firestore-loaded synonym override cache
  Map<String, String> _dynamicSynonyms = {};
  DateTime? _synonymCacheExpiry;
  static const Duration _cacheTTL = Duration(hours: 6);

  final TranslationTrie _translationTrie = TranslationTrie();
  bool _trieBuilt = false;

  // Extended built-in dictionary (supplements the static hindiProductDictionary)
  static const Map<String, String> _extendedDict = {
    // Grains & Pulses
    'gehu': 'Wheat', 'gehun': 'Wheat', 'गेहूं': 'Wheat',
    'bajra': 'Bajra', 'jowar': 'Jowar', 'makka': 'Maize',
    'moong': 'Moong Dal', 'mung': 'Moong Dal',
    'chana': 'Chickpeas', 'kabuli': 'Chickpeas',
    'masoor': 'Masoor Dal', 'urad': 'Urad Dal',
    'rajma': 'Kidney Beans', 'lobiya': 'Black Eyed Peas',
    // Spices
    'haldi': 'Turmeric', 'mirchi': 'Chilli',
    'lal mirch': 'Red Chilli', 'kali mirch': 'Black Pepper',
    'dhaniya': 'Coriander', 'jeera': 'Cumin',
    'methi': 'Fenugreek', 'ajwain': 'Carom Seeds',
    'hing': 'Asafoetida', 'saunf': 'Fennel',
    'dalchini': 'Cinnamon', 'laung': 'Cloves',
    'elaichi': 'Cardamom', 'tej patta': 'Bay Leaf',
    // Dairy
    'makhan': 'Butter', 'malai': 'Cream', 'mawa': 'Khoya',
    'chhachh': 'Buttermilk', 'lassi': 'Lassi',
    'rabri': 'Rabri', 'kheer': 'Kheer Mix',
    // Vegetables
    'gobhi': 'Cauliflower', 'bandh gobhi': 'Cabbage',
    'paalak': 'Spinach', 'palak': 'Spinach',
    'bhindi': 'Okra', 'lady finger': 'Okra',
    'karela': 'Bitter Gourd', 'lauki': 'Bottle Gourd',
    'tinda': 'Indian Round Gourd', 'turai': 'Ridge Gourd',
    'arbi': 'Colocasia', 'shakarkand': 'Sweet Potato',
    'kathal': 'Jackfruit', 'kaddu': 'Pumpkin',
    'baingan': 'Brinjal', 'shimla mirch': 'Capsicum',
    'hara pyaz': 'Spring Onion', 'hari mirch': 'Green Chilli',
    // Fruits
    'angoor': 'Grapes', 'nashpati': 'Pear',
    'papita': 'Papaya', 'ananas': 'Pineapple',
    'tarbuj': 'Watermelon', 'kharbuja': 'Muskmelon',
    'imli': 'Tamarind', 'nariyal': 'Coconut',
    'jamun': 'Indian Berry', 'litchi': 'Lychee',
    // Packaged
    'biscuit': 'Biscuit', 'namkeen': 'Namkeen',
    'papad': 'Papad', 'achaar': 'Pickle',
    'chutney': 'Chutney', 'murabba': 'Murabba',
    // Common Hinglish combos
    'mustard tel': 'Mustard Oil', 'sarson tel': 'Mustard Oil',
    'sunflower tel': 'Sunflower Oil', 'refined tel': 'Refined Oil',
    'dudh': 'Milk', 'milk': 'Milk',
    'anda': 'Egg', 'anday': 'Egg', 'अंडा': 'Egg',
  };

  // Quantity words (fractional and verbal)
  static const Map<String, double> _quantityWords = {
    'ek': 1.0, 'do': 2.0, 'teen': 3.0, 'char': 4.0, 'paanch': 5.0,
    'six': 6.0, 'sat': 7.0, 'aath': 8.0, 'nau': 9.0, 'das': 10.0,
    'आधा': 0.5, 'aadha': 0.5, 'half': 0.5,
    'पाव': 0.25, 'pav': 0.25, 'quarter': 0.25,
    'पौन': 0.75, 'paun': 0.75,
    'ek kilo': 1.0, 'do kilo': 2.0, 'teen kilo': 3.0,
    'ek kg': 1.0, 'do kg': 2.0,
    'ek litre': 1.0, 'do litre': 2.0,
    'ek packet': 1.0, 'do packet': 2.0,
  };

  static const Map<String, String> _unitWords = {
    'kilo': 'kg', 'kg': 'kg', 'किलो': 'kg',
    'gram': 'g', 'gm': 'g', 'graam': 'g',
    'litre': 'l', 'liter': 'l', 'l': 'l', 'लीटर': 'l',
    'ml': 'ml', 'millilitre': 'ml',
    'packet': 'packet', 'पैकेट': 'packet', 'pack': 'packet',
    'bottle': 'bottle', 'बोतल': 'bottle',
    'dozen': 'dozen', 'darjan': 'dozen',
    'box': 'box', 'डिब्बा': 'box', 'dibba': 'box',
    'piece': 'piece', 'pcs': 'piece', 'nag': 'piece',
    'bag': 'bag', 'थैली': 'bag',
  };

  // Noise words to strip from voice input
  static final RegExp _noisePattern = RegExp(
    r'\b(chahiye|de\s*do|add\s*karo|le\s*lo|dena|milega|dedo|lelo|please|'
    r'mujhe|mujhey|ek\s*baar|thoda|thodi|zara|jaldi|abhi|lao|la\s*do)\b',
    caseSensitive: false,
  );

  // ─────────────── PUBLIC API ───────────────

  /// Parse a raw voice/text query into a structured search intent.
  Future<VoiceSearchIntent> parse(String rawInput) async {
    if (rawInput.trim().isEmpty) {
      return VoiceSearchIntent.empty();
    }

    await _ensureSynonymsLoaded();

    String text = rawInput.trim();

    // 1. Strip noise words
    text = text.replaceAll(_noisePattern, ' ').trim();

    // 2. Extract quantity
    final quantityResult = _extractQuantity(text);
    text = quantityResult.cleanedText;
    final quantity = quantityResult.quantity;

    // 3. Extract unit
    final unitResult = _extractUnit(text);
    text = unitResult.cleanedText;
    final unit = unitResult.unit;

    // 4. Translate product name
    final productQuery = _translateProduct(text.trim());

    // 5. Determine search category (heuristic)
    final category = _inferCategory(productQuery);

    debugPrint('[HinglishParser] "$rawInput" → qty=$quantity unit=$unit product="$productQuery" cat=$category');

    return VoiceSearchIntent(
      originalInput: rawInput,
      productQuery: productQuery,
      quantity: quantity,
      unit: unit,
      inferredCategory: category,
      confidence: _estimateConfidence(rawInput, productQuery),
    );
  }

  /// Parse multiple items from one voice utterance.
  /// Example: "do kilo aloo aur ek packet namak"
  Future<List<VoiceSearchIntent>> parseMultiItem(String rawInput) async {
    final parts = rawInput.split(RegExp(r'\b(aur|or|and|,)\b', caseSensitive: false));
    final results = <VoiceSearchIntent>[];
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) {
        results.add(await parse(trimmed));
      }
    }
    return results;
  }

  // ─────────────── QUANTITY EXTRACTION ───────────────

  _ExtractionResult _extractQuantity(String text) {
    // Try verbal quantities first (e.g., "do kilo")
    for (final entry in _quantityWords.entries) {
      final pattern = RegExp(r'\b' + RegExp.escape(entry.key) + r'\b', caseSensitive: false);
      if (pattern.hasMatch(text)) {
        return _ExtractionResult(
          quantity: entry.value,
          unit: '',
          cleanedText: text.replaceFirst(pattern, ' ').trim(),
        );
      }
    }

    // Numeric pattern: "2", "2.5", "½"
    final numPattern = RegExp(r'\b(\d+(?:\.\d+)?)\b');
    final match = numPattern.firstMatch(text);
    if (match != null) {
      final qty = double.tryParse(match.group(1) ?? '') ?? 1.0;
      return _ExtractionResult(
        quantity: qty,
        unit: '',
        cleanedText: text.replaceFirst(match.group(0)!, ' ').trim(),
      );
    }

    return _ExtractionResult(quantity: 1.0, unit: '', cleanedText: text);
  }

  _ExtractionResult _extractUnit(String text) {
    for (final entry in _unitWords.entries) {
      final pattern = RegExp(r'\b' + RegExp.escape(entry.key) + r'\b', caseSensitive: false);
      if (pattern.hasMatch(text)) {
        return _ExtractionResult(
          quantity: 0,
          unit: entry.value,
          cleanedText: text.replaceFirst(pattern, ' ').trim(),
        );
      }
    }
    return _ExtractionResult(quantity: 0, unit: 'piece', cleanedText: text);
  }

  // ─────────────── PRODUCT TRANSLATION ───────────────

  String _translateProduct(String text) {
    final lower = text.toLowerCase().trim();

    // 1. Try exact match using Trie
    final exactMatch = _translationTrie.findExact(lower);
    if (exactMatch != null) return exactMatch;

    // 2. Try longest substring matching in Trie
    final substringMatch = _translationTrie.findTranslation(lower);
    if (substringMatch != null) return substringMatch;

    // Return cleaned original if no translation found
    return _titleCase(text);
  }

  // ─────────────── CATEGORY INFERENCE ───────────────

  String? _inferCategory(String productName) {
    final lower = productName.toLowerCase();
    if (_matchesAny(lower, ['milk', 'paneer', 'curd', 'butter', 'cream', 'ghee', 'lassi', 'khoya'])) {
      return 'dairy';
    }
    if (_matchesAny(lower, ['potato', 'tomato', 'onion', 'ginger', 'garlic', 'spinach', 'cauliflower',
        'cabbage', 'okra', 'brinjal', 'capsicum'])) {
      return 'vegetables';
    }
    if (_matchesAny(lower, ['mango', 'banana', 'apple', 'orange', 'grapes', 'papaya', 'watermelon'])) {
      return 'fruits';
    }
    if (_matchesAny(lower, ['rice', 'wheat', 'atta', 'flour', 'maize', 'bajra'])) {
      return 'groceries';
    }
    if (_matchesAny(lower, ['moong', 'dal', 'pulse', 'chana', 'masoor', 'urad', 'rajma'])) {
      return 'groceries';
    }
    if (_matchesAny(lower, ['oil', 'mustard', 'sunflower', 'refined'])) {
      return 'groceries';
    }
    if (_matchesAny(lower, ['turmeric', 'chilli', 'cumin', 'coriander', 'spice', 'pepper'])) {
      return 'groceries';
    }
    if (_matchesAny(lower, ['sugar', 'salt', 'tea', 'coffee'])) {
      return 'groceries';
    }
    if (_matchesAny(lower, ['biscuit', 'namkeen', 'chips', 'snack'])) {
      return 'snacks';
    }
    if (_matchesAny(lower, ['soap', 'shampoo', 'detergent', 'toothpaste'])) {
      return 'personalCare';
    }
    return null;
  }

  bool _matchesAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  // ─────────────── CONFIDENCE ───────────────

  double _estimateConfidence(String original, String translated) {
    if (translated == original.trim()) return 0.5; // no translation happened
    if (translated.isEmpty) return 0.1;
    return 0.9;
  }

  // ─────────────── DYNAMIC SYNONYMS (FIRESTORE) ───────────────

  void _buildTrie() {
    _translationTrie.clear();

    // 1. Insert static Hindi dictionary first (lowest priority)
    for (final entry in hindiProductDictionary.entries) {
      _translationTrie.insert(entry.key, entry.value);
    }

    // 2. Insert extended dictionary (medium priority)
    for (final entry in _extendedDict.entries) {
      _translationTrie.insert(entry.key, entry.value);
    }

    // 3. Insert dynamic synonyms (highest priority)
    for (final entry in _dynamicSynonyms.entries) {
      _translationTrie.insert(entry.key, entry.value);
    }

    _trieBuilt = true;
  }

  Future<void> _ensureSynonymsLoaded() async {
    if (_synonymCacheExpiry != null &&
        DateTime.now().isBefore(_synonymCacheExpiry!) &&
        _trieBuilt) {
      return;
    }

    try {
      final snap = await _firestore
          .collection('settings')
          .doc('voice_search_synonyms')
          .get();
      if (snap.exists) {
        _dynamicSynonyms = Map<String, String>.from(snap.data()?['synonyms'] ?? {});
        debugPrint('[HinglishParser] Loaded ${_dynamicSynonyms.length} dynamic synonyms.');
      }
      _buildTrie();
      _synonymCacheExpiry = DateTime.now().add(_cacheTTL);
    } catch (e) {
      debugPrint('[HinglishParser] Synonym load failed: $e');
      if (!_trieBuilt) {
        _buildTrie();
      }
      _synonymCacheExpiry = DateTime.now().add(const Duration(minutes: 5)); // short retry
    }
  }

  /// Add or update a synonym in Firestore (admin action)
  Future<void> addSynonym(String hindiWord, String englishProduct) async {
    await _firestore.collection('settings').doc('voice_search_synonyms').set({
      'synonyms': {hindiWord: englishProduct},
    }, SetOptions(merge: true));
    _dynamicSynonyms[hindiWord] = englishProduct;
    _translationTrie.insert(hindiWord, englishProduct);
  }

  // ─────────────── UTIL ───────────────

  String _titleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}

// ─────────────── VALUE OBJECTS ───────────────

class VoiceSearchIntent {
  final String originalInput;
  final String productQuery;
  final double quantity;
  final String unit;
  final String? inferredCategory;
  final double confidence; // 0.0–1.0

  const VoiceSearchIntent({
    required this.originalInput,
    required this.productQuery,
    required this.quantity,
    required this.unit,
    this.inferredCategory,
    required this.confidence,
  });

  factory VoiceSearchIntent.empty() => const VoiceSearchIntent(
        originalInput: '',
        productQuery: '',
        quantity: 1.0,
        unit: 'piece',
        confidence: 0.0,
      );

  bool get hasTranslation => productQuery.isNotEmpty;

  @override
  String toString() =>
      'VoiceSearchIntent(query="$productQuery", qty=$quantity $unit, cat=$inferredCategory, conf=${confidence.toStringAsFixed(2)})';
}

class _ExtractionResult {
  final double quantity;
  final String unit;
  final String cleanedText;
  const _ExtractionResult({required this.quantity, required this.unit, required this.cleanedText});
}

class TranslationTrieNode {
  final Map<String, TranslationTrieNode> children = {};
  String? translation;
}

class TranslationTrie {
  final TranslationTrieNode root = TranslationTrieNode();

  void insert(String key, String translation) {
    final cleanKey = key.toLowerCase().trim();
    if (cleanKey.isEmpty) return;
    TranslationTrieNode current = root;
    for (int i = 0; i < cleanKey.length; i++) {
      final char = cleanKey[i];
      current = current.children.putIfAbsent(char, () => TranslationTrieNode());
    }
    current.translation = translation;
  }

  void clear() {
    root.children.clear();
    root.translation = null;
  }

  String? findExact(String query) {
    final cleanQuery = query.toLowerCase().trim();
    if (cleanQuery.isEmpty) return null;
    TranslationTrieNode current = root;
    for (int i = 0; i < cleanQuery.length; i++) {
      final char = cleanQuery[i];
      final next = current.children[char];
      if (next == null) return null;
      current = next;
    }
    return current.translation;
  }

  String? findTranslation(String query) {
    final cleanQuery = query.toLowerCase().trim();
    if (cleanQuery.isEmpty) return null;

    String? longestMatchTranslation;
    int longestMatchLength = 0;

    for (int start = 0; start < cleanQuery.length; start++) {
      TranslationTrieNode current = root;
      int matchLen = 0;
      for (int i = start; i < cleanQuery.length; i++) {
        final char = cleanQuery[i];
        final nextNode = current.children[char];
        if (nextNode == null) break;
        current = nextNode;
        matchLen = i - start + 1;
        if (current.translation != null) {
          if (matchLen > longestMatchLength) {
            longestMatchLength = matchLen;
            longestMatchTranslation = current.translation;
          }
        }
      }
    }
    return longestMatchTranslation;
  }
}
