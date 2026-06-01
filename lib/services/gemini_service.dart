import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/product_model.dart';
import 'package:uuid/uuid.dart';

import '../services/hindi_product_dictionary.dart';

/// Gemini AI Service for parsing and intelligence
class GeminiService {
  final Dio _dio = Dio();
  
  // API Configuration
  static String get _apiKey {
    const compileTimeKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    if (compileTimeKey.isNotEmpty) return compileTimeKey;
    try {
      return dotenv.env['GEMINI_API_KEY'] ?? '';
    } catch (_) {
      return '';
    }
  }
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  static const String _model = 'gemini-1.5-flash';

  /// Parse a list of items from plain text (WhatsApp message)
  Future<List<Map<String, dynamic>>> parseItemListFromText(String text) async {
    // Translate common Hindi names to English before processing
    String translatedText = text;
    hindiProductDictionary.forEach((key, value) {
      translatedText = translatedText.replaceAll(RegExp(key, caseSensitive: false), value);
    });

    if (_apiKey.isEmpty) return _simulateTextParsing(translatedText);
    try {
      final prompt = 'Parse the following grocery list into a JSON array with keys: name, quantity (num), unit, price, category. Text: "$translatedText"';
      final response = await _generateContent(prompt);
      return _parseJsonList(response);
    } catch (e) {
      debugPrint('Error parsing text list: $e');
      return _simulateTextParsing(translatedText);
    }
  }

  /// OCR: Extract text from bill image
  Future<String> extractTextFromImage(Uint8List imageBytes) async {
    if (_apiKey.isEmpty) return "Potato 10kg 500";
    try {
      final base64Image = base64Encode(imageBytes);
      final url = '$_baseUrl/$_model:generateContent?key=$_apiKey';
      final response = await _dio.post(url, data: {
        "contents": [{"parts": [{"text": "Extract items/prices from this bill."}, {"inlineData": {"mimeType": "image/jpeg", "data": base64Image}}]}]
      });
      return response.data['candidates'][0]['content']['parts'][0]['text'] ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Snap-to-Shop: Identify product
  Future<String?> identifyProductFromImage(Uint8List imageBytes) async {
    if (_apiKey.isEmpty) return "Potato";
    try {
      final base64Image = base64Encode(imageBytes);
      final url = '$_baseUrl/$_model:generateContent?key=$_apiKey';
      final response = await _dio.post(url, data: {
        "contents": [{"parts": [{"text": "Identify this product name in 1-2 words."}, {"inlineData": {"mimeType": "image/jpeg", "data": base64Image}}]}]
      });
      return response.data['candidates'][0]['content']['parts'][0]['text']?.trim();
    } catch (e) {
      return null;
    }
  }

  /// Voice-to-Inventory (Feature 35)
  Future<Map<String, dynamic>?> parseVoiceInventoryCommand(String text) async {
    if (_apiKey.isEmpty) return {'action': 'ADD', 'name': 'Potato', 'quantity': 10, 'unit': 'kg', 'price': 30.0};
    try {
      final prompt = 'Identify inventory action (ADD/UPDATE/DELETE), name, quantity, unit, price from: "$text". Return ONLY JSON.';
      final response = await _generateContent(prompt);
      return jsonDecode(response.replaceAll('```json', '').replaceAll('```', '').trim());
    } catch (e) {
      return null;
    }
  }

  /// Bill parsing (Feature 82)
  Future<List<Map<String, dynamic>>> parseBillItems(String extractedText) async {
    return parseItemListFromText(extractedText);
  }

  /// AI Chat Assistant (Feature 103)
  static Future<String> generateText(String prompt) async {
    if (_apiKey.isEmpty) return "I am Fufaji's AI. How can I help you today?";
    try {
      final dio = Dio();
      final response = await dio.post('$_baseUrl/$_model:generateContent?key=$_apiKey', data: {
        "contents": [{"parts": [{"text": prompt}]}]
      });
      return response.data['candidates'][0]['content']['parts'][0]['text'] ?? 'No response';
    } catch (e) {
      return "Sorry, I'm resting. Ask later!";
    }
  }

  Future<String> _generateContent(String prompt) async {
    final url = '$_baseUrl/$_model:generateContent?key=$_apiKey';
    final response = await _dio.post(url, data: {"contents": [{"parts": [{"text": prompt}]}]});
    return response.data['candidates'][0]['content']['parts'][0]['text'] ?? '';
  }

  List<Map<String, dynamic>> _parseJsonList(String response) {
    try {
      final cleaned = response.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(cleaned);
      return List<Map<String, dynamic>>.from(decoded is List ? decoded : [decoded]);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> parseOneClickOrder(String text) => parseItemListFromText(text);

  List<Map<String, dynamic>> _simulateTextParsing(String text) => [
    {'name': 'Potato', 'quantity': 5, 'unit': 'kg', 'price': 30.0, 'category': 'vegetables'}
  ];

  /// Extract keywords and intent from voice transcription (Step 6)
  Future<List<String>> extractKeywordsForSearch(String text) async {
    if (_apiKey.isEmpty) return text.split(' ').where((s) => s.length > 2).toList();
    try {
      final prompt = 'Extract primary searchable keywords (items like "potato", "milk") from this sentence in Hindi or English: "$text". Return ONLY a comma-separated list of English keywords.';
      final response = await _generateContent(prompt);
      return response.split(',').map((s) => s.trim().toLowerCase()).toList();
    } catch (e) {
      debugPrint('Gemini Search Keyword Extraction failed: $e');
      return text.split(' ').where((s) => s.length > 2).toList();
    }
  }

  /// Fallback for missing methods used elsewhere
  Future<ProductModel> parseProductFromVoice(String text, {String? context}) async {
    return ProductModel(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      name: text,
      price: 100,
      stockQuantity: 10,
      district: 'Jaipur',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      description: '',
      unit: 'unit',
      category: 'other',
      shopId: 's1',
      shopName: 'Shop',
      imageUrl: '',
    );
  }
}
