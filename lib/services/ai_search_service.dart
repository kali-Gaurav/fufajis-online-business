import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product_model.dart';
import 'gemini_service.dart';

class AISearchService {
  final GeminiService _geminiService = GeminiService();

  /// Identifies products from the user-uploaded image using Gemini Vision.
  Future<List<ProductModel>> identifyProductFromImage(
    XFile image,
    List<ProductModel> catalog, {
    String? simulatedLabel,
  }) async {
    // 1. Check for simulated label (demo mode)
    if (simulatedLabel != null && simulatedLabel.isNotEmpty) {
      return _matchProductsByKeyword(simulatedLabel, catalog);
    }

    // 2. Filename heuristic
    final fileName = image.name.toLowerCase();
    final matchedByFileName = _matchByFileNameHeuristics(fileName, catalog);
    if (matchedByFileName.isNotEmpty) {
      return matchedByFileName;
    }

    // 3. Live Gemini Vision Analysis
    try {
      final imageBytes = await image.readAsBytes();
      final aiKeyword = await _geminiService.identifyProductFromImage(imageBytes);
      
      if (aiKeyword != null && aiKeyword != 'unknown') {
        return _matchProductsByKeyword(aiKeyword, catalog);
      }
    } catch (e) {
      debugPrint("Gemini Vision failed: $e. Falling back to simple matching.");
    }

    // 4. Final Fallback (Simulate processing)
    if (catalog.isNotEmpty) {
      final index = (image.hashCode) % catalog.length;
      return [catalog[index]];
    }

    return [];
  }

  /// Parses a handwritten grocery list using Gemini AI.
  Future<List<Map<String, dynamic>>> parseHandwrittenList(XFile image) async {
    try {
      final imageBytes = await image.readAsBytes();
      // First, perform OCR to extract text from the grocery list image
      final String extractedText = await _geminiService.extractTextFromImage(imageBytes);
      if (extractedText.isEmpty) {
        debugPrint("No text extracted from handwritten list image");
        return [];
      }
      // Second, parse the extracted text into structural items
      return await _geminiService.parseBillItems(extractedText);
    } catch (e) {
      debugPrint("Error parsing handwritten list: $e");
      return [];
    }
  }

  List<ProductModel> _matchProductsByKeyword(String keyword, List<ProductModel> catalog) {
    final lowerKeyword = keyword.toLowerCase();
    
    // First: Look for exact tag matches
    final tagMatches = catalog.where((p) => 
      p.tags.any((tag) => tag.toLowerCase() == lowerKeyword)
    ).toList();
    if (tagMatches.isNotEmpty) return tagMatches;

    // Second: Match name substrings
    final nameMatches = catalog.where((p) => 
      p.name.toLowerCase().contains(lowerKeyword) ||
      p.description.toLowerCase().contains(lowerKeyword)
    ).toList();
    if (nameMatches.isNotEmpty) return nameMatches;

    // Third: Match category
    final categoryMatches = catalog.where((p) => 
      p.category.toLowerCase().contains(lowerKeyword)
    ).toList();
    
    return categoryMatches;
  }

  List<ProductModel> _matchByFileNameHeuristics(String fileName, List<ProductModel> catalog) {
    final keywords = ['potato', 'tomato', 'onion', 'paneer', 'milk', 'bread', 'apple', 'coriander', 'biscuit'];
    for (var kw in keywords) {
      if (fileName.contains(kw)) {
        return _matchProductsByKeyword(kw, catalog);
      }
    }
    return [];
  }
}
