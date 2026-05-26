import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'gemini_service.dart';

class BillOCRService {
  static final BillOCRService _instance = BillOCRService._internal();
  factory BillOCRService() => _instance;
  BillOCRService._internal();

  final GeminiService _geminiService = GeminiService();

  /// Scans a bill image and returns a structured list of items (Feature 82)
  Future<List<Map<String, dynamic>>> scanBill(Uint8List imageBytes) async {
    try {
      debugPrint('[BillOCRService] Starting OCR scan for bill...');
      
      // 1. Extract raw text from image
      final rawText = await _geminiService.extractTextFromImage(imageBytes);
      
      if (rawText.isEmpty) {
        debugPrint('[BillOCRService] No text extracted from image.');
        return [];
      }

      // 2. Parse items from text
      final items = await _geminiService.parseBillItems(rawText);
      
      debugPrint('[BillOCRService] Successfully parsed ${items.length} items from bill.');
      return items;
    } catch (e) {
      debugPrint('[BillOCRService] Error during bill OCR: $e');
      return [];
    }
  }
}
