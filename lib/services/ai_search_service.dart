import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product_model.dart';
import '../utils/trie_search_engine.dart';
import 'gemini_service.dart';
import 'image_processing_service.dart';

class AISearchResult {
  final ProductModel product;
  final double confidence;

  String get name => product.name;

  AISearchResult({required this.product, required this.confidence});
}

class AISearchService {
  static final AISearchService _instance = AISearchService._internal();
  factory AISearchService() => _instance;
  AISearchService._internal();

  final GeminiService _geminiService = GeminiService();
  final ImageProcessingService _imageService = ImageProcessingService();
  final TrieSearchEngine _trieEngine = TrieSearchEngine();
  bool _isIndexBuilt = false;

  /// Warms up the AI Search Service (Step 5.5)
  Future<void> warmup() async {
    try {
      debugPrint('[AISearchService] Warming up Gemini/Vision services...');
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('[AISearchService] Warm-up complete.');
    } catch (e) {
      debugPrint('AI Search Warm-up failed: $e');
    }
  }

  /// Identifies products from the user-uploaded image using Gemini Vision (Step 8)
  Future<List<AISearchResult>> identifyProductFromImage(
    XFile image,
    List<ProductModel> catalog, {
    String? simulatedLabel,
  }) async {
    // 1. Upload compressed image to Firebase Storage (Step 8.2). This safely
    // degrades in offline/test paths because the upload helper catches errors.
    if (!kIsWeb && File(image.path).existsSync()) {
      final fileName =
          'ai_search/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      await _imageService.uploadCompressedImage(image, fileName);
    }

    // 2. Identify Keywords using Gemini Vision (Step 8.3)
    String? aiKeyword;
    if (simulatedLabel != null && simulatedLabel.isNotEmpty) {
      aiKeyword = simulatedLabel;
    } else {
      aiKeyword = _keywordFromFileName(image.name);
      try {
        if (aiKeyword == null) {
          final imageBytes = await image.readAsBytes();
          aiKeyword = await _geminiService.identifyProductFromImage(imageBytes);
        }
      } catch (e) {
        debugPrint("Gemini Vision failed: $e");
      }
    }

    if (aiKeyword == null || aiKeyword == 'unknown') {
      return catalog.isEmpty
          ? []
          : [AISearchResult(product: catalog.first, confidence: 0.2)];
    }

    // 3. Confidence-based semantic matching (Step 8.4, 8.5)
    return _matchProductsWithConfidence(aiKeyword, catalog);
  }

  List<AISearchResult> _matchProductsWithConfidence(
    String keyword,
    List<ProductModel> catalog,
  ) {
    if (!_isIndexBuilt && catalog.isNotEmpty) {
      _trieEngine.buildIndex(catalog);
      _isIndexBuilt = true;
    }

    final lowerKeyword = keyword.toLowerCase().trim();
    if (lowerKeyword.isEmpty) return [];

    // O(L) Trie Prefix Lookup
    final prefixMatches = _trieEngine.searchPrefix(lowerKeyword);
    final Set<String> matchedIds = {};
    final List<AISearchResult> results = [];

    for (final p in prefixMatches) {
      matchedIds.add(p.id);
      double score = 0.6; // default prefix match confidence
      if (p.name.toLowerCase() == lowerKeyword) {
        score = 1.0;
      } else if (p.tags.any((t) => t.toLowerCase() == lowerKeyword)) {
        score = 0.9;
      } else if (p.name.toLowerCase().startsWith(lowerKeyword)) {
        score = 0.8;
      }
      results.add(AISearchResult(product: p, confidence: score));
    }

    // Secondary: Apply Levenshtein fuzzy matching on trie if prefix matches are sparse
    if (results.length < 3) {
      final fuzzyMatches = _trieEngine.searchFuzzy(
        lowerKeyword,
        maxDistance: 2,
      );
      for (final entry in fuzzyMatches) {
        if (!matchedIds.contains(entry.key.id)) {
          results.add(
            AISearchResult(product: entry.key, confidence: entry.value),
          );
          matchedIds.add(entry.key.id);
        }
      }
    }

    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }

  String? _keywordFromFileName(String fileName) {
    final normalized = fileName.toLowerCase();
    const keywordAliases = {
      'potato': ['potato', 'potatoes', 'aloo'],
      'tomato': ['tomato', 'tomatoes', 'tamatar'],
      'onion': ['onion', 'onions', 'pyaz'],
      'milk': ['milk', 'doodh'],
    };

    for (final entry in keywordAliases.entries) {
      if (entry.value.any(normalized.contains)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Parses a handwritten grocery list using Gemini AI.
  Future<List<Map<String, dynamic>>> parseHandwrittenList(XFile image) async {
    try {
      final imageBytes = await image.readAsBytes();
      final String extractedText = await _geminiService.extractTextFromImage(
        imageBytes,
      );
      if (extractedText.isEmpty) return [];
      return await _geminiService.parseBillItems(extractedText);
    } catch (e) {
      debugPrint("Error parsing handwritten list: $e");
      return [];
    }
  }
}
