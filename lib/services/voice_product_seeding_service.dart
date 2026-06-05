import 'package:flutter/material.dart';

import '../models/product_model.dart';
import 'gemini_service.dart';

/// Step 23: Voice-Powered Product Seeding
/// Uses STT and Gemini to auto-populate product creation forms.
class VoiceProductSeedingService {
  static final VoiceProductSeedingService _instance = VoiceProductSeedingService._internal();
  factory VoiceProductSeedingService() => _instance;
  VoiceProductSeedingService._internal();

  final GeminiService _geminiService = GeminiService();

  /// Parses voice text into product data using Gemini (Step 23.2)
  Future<ProductModel?> parseProductFromVoice(String voiceInput) async {
    try {
      final product = await _geminiService.parseProductFromVoice(voiceInput);
      return product;
    } catch (e) {
      debugPrint('[VoiceSeeding] Parsing failed: $e');
      return null;
    }
  }

  /// Suggests HSN Code and GST based on category (Step 23.5)
  Map<String, dynamic> getTaxSuggestions(String category) {
    switch (category.toLowerCase()) {
      case 'vegetables':
      case 'fruits':
        return {'hsn': '0701', 'gst': 0};
      case 'dairy':
        return {'hsn': '0401', 'gst': 5};
      case 'groceries':
        return {'hsn': '1901', 'gst': 12};
      default:
        return {'hsn': '0000', 'gst': 18};
    }
  }
}
