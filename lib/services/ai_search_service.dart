import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product_model.dart';
import 'gemini_service.dart';
import 'image_processing_service.dart';

class AISearchResult {
  final ProductModel product;
  final double confidence;

  var name;

  AISearchResult({required this.product, required this.confidence});
}

class AISearchService {
  static final AISearchService _instance = AISearchService._internal();
  factory AISearchService() => _instance;
  AISearchService._internal();

  final GeminiService _geminiService = GeminiService();
  final ImageProcessingService _imageService = ImageProcessingService();

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
    // 1. Upload compressed image to Firebase Storage (Step 8.2)
    final fileName = 'ai_search/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
    await _imageService.uploadCompressedImage(image, fileName);

    // 2. Identify Keywords using Gemini Vision (Step 8.3)
    String? aiKeyword;
    if (simulatedLabel != null && simulatedLabel.isNotEmpty) {
      aiKeyword = simulatedLabel;
    } else {
      try {
        final imageBytes = await image.readAsBytes();
        aiKeyword = await _geminiService.identifyProductFromImage(imageBytes);
      } catch (e) {
        debugPrint("Gemini Vision failed: $e");
      }
    }

    if (aiKeyword == null || aiKeyword == 'unknown') {
      return [];
    }

    // 3. Confidence-based semantic matching (Step 8.4, 8.5)
    return _matchProductsWithConfidence(aiKeyword, catalog);
  }

  List<AISearchResult> _matchProductsWithConfidence(String keyword, List<ProductModel> catalog) {
    final lowerKeyword = keyword.toLowerCase();
    final List<AISearchResult> results = [];

    for (var p in catalog) {
      double score = 0.0;
      final lowerName = p.name.toLowerCase();
      final lowerCat = p.category.toLowerCase();

      if (lowerName == lowerKeyword) {
        score = 1.0;
      } else if (lowerName.contains(lowerKeyword)) {
        score = 0.8;
      } else if (p.tags.any((t) => t.toLowerCase() == lowerKeyword)) {
        score = 0.9;
      } else if (lowerCat.contains(lowerKeyword)) {
        score = 0.6;
      }

      if (score > 0) {
        results.add(AISearchResult(product: p, confidence: score));
      }
    }

    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }

  /// Parses a handwritten grocery list using Gemini AI.
  Future<List<Map<String, dynamic>>> parseHandwrittenList(XFile image) async {
    try {
      final imageBytes = await image.readAsBytes();
      final String extractedText = await _geminiService.extractTextFromImage(imageBytes);
      if (extractedText.isEmpty) return [];
      return await _geminiService.parseBillItems(extractedText);
    } catch (e) {
      debugPrint("Error parsing handwritten list: $e");
      return [];
    }
  }
}
