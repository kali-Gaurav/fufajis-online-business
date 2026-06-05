import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/product_model.dart';

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

  /// Enhanced Bill OCR: Extract supplier details + structured items from bill image
  /// Returns: { supplier, billNumber, billDate, items: [{ name, quantity, unit, price, total }] }
  Future<Map<String, dynamic>> extractBillWithSupplierDetails(Uint8List imageBytes) async {
    if (_apiKey.isEmpty) {
      return _simulatedBillResult();
    }
    try {
      final base64Image = base64Encode(imageBytes);
      final url = '$_baseUrl/$_model:generateContent?key=$_apiKey';

      const prompt = '''
Analyze this supplier bill/challan image carefully and extract ALL information.

Return ONLY a valid JSON object with this exact structure:
{
  "supplier": "Supplier/Distributor name from bill header (or 'Unknown')",
  "billNumber": "Bill/Invoice number (or 'N/A')",
  "billDate": "Date from bill in DD-MM-YYYY format (or today's date)",
  "items": [
    {
      "name": "Product name in English",
      "quantity": 10,
      "unit": "kg",
      "pricePerUnit": 30.0,
      "total": 300.0
    }
  ]
}

Rules:
- Translate Hindi product names to English (e.g. "आलू" → "Potato", "प्याज" → "Onion")
- quantity must be a number, unit must be one of: kg, g, l, ml, packet, piece, bottle, box, dozen
- pricePerUnit and total must be numbers
- If you can't read a value, use reasonable defaults
- Do NOT include any text outside the JSON object
''';

      final response = await _dio.post(url, data: {
        "contents": [
          {
            "parts": [
              {"text": prompt},
              {
                "inlineData": {"mimeType": "image/jpeg", "data": base64Image}
              }
            ]
          }
        ]
      });

      final rawText = response.data['candidates'][0]['content']['parts'][0]['text'] ?? '';
      final cleaned = rawText.replaceAll('```json', '').replaceAll('```', '').trim();

      try {
        final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
        // Ensure items is a list
        if (decoded['items'] is! List) {
          decoded['items'] = [];
        }
        return decoded;
      } catch (_) {
        // Fallback: use old pipeline
        debugPrint('[GeminiService] Structured bill parse failed, falling back to text extraction');
        final text = await extractTextFromImage(imageBytes);
        final items = await parseBillItems(text);
        return {
          'supplier': 'Unknown',
          'billNumber': 'N/A',
          'billDate': DateTime.now().toString().substring(0, 10),
          'items': items,
        };
      }
    } catch (e) {
      debugPrint('[GeminiService] extractBillWithSupplierDetails error: $e');
      return _simulatedBillResult();
    }
  }

  Map<String, dynamic> _simulatedBillResult() => {
    'supplier': 'Jaipur Mandi Supplier',
    'billNumber': 'INV-2026-001',
    'billDate': DateTime.now().toString().substring(0, 10),
    'items': [
      {'name': 'Potato', 'quantity': 50, 'unit': 'kg', 'pricePerUnit': 25.0, 'total': 1250.0},
      {'name': 'Onion', 'quantity': 30, 'unit': 'kg', 'pricePerUnit': 35.0, 'total': 1050.0},
      {'name': 'Tomato', 'quantity': 20, 'unit': 'kg', 'pricePerUnit': 40.0, 'total': 800.0},
    ],
  };

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

  /// Extract product details from voice transcription using Gemini Flash
  Future<ProductModel> parseProductFromVoice(String text, {String? context}) async {
    String translatedText = text;
    hindiProductDictionary.forEach((key, value) {
      translatedText = translatedText.replaceAll(RegExp(key, caseSensitive: false), value);
    });

    if (_apiKey.isEmpty) {
      return ProductModel(
        id: 'p_${DateTime.now().millisecondsSinceEpoch}',
        name: text,
        price: 100.0,
        stockQuantity: 10,
        district: 'Jaipur',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        description: 'Voice added: "$text"',
        unit: 'piece',
        category: 'other',
        shopId: 's1',
        shopName: 'Shop',
        imageUrl: '',
      );
    }

    try {
      final prompt = '''
Analyze the following voice command representing a product being added to inventory: "$translatedText"

Extract these details:
1. Product Name (translate/normalize common Hindi terms like "aloo" to "Potato", "doodh" to "Milk", etc., or keep original brand/name).
2. Price (a numeric value, default 0.0).
3. Stock Quantity (a numeric value, default 1).
4. Unit (e.g. "kg", "g", "liter", "ml", "packet", "bottle", "piece", default "piece").
5. Category (must be one of: groceries, vegetables, fruits, dairy, bakery, snacks, beverages, household, personalCare, other).

Format the output strictly as a JSON object with these keys: name, price, stockQuantity, unit, category. Do not include any explanation or markdown formatting in your response.
Example Output:
{"name": "Apples", "price": 150.0, "stockQuantity": 20, "unit": "kg", "category": "fruits"}
''';

      final response = await _generateContent(prompt);
      final cleaned = response.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> data = jsonDecode(cleaned);

      return ProductModel(
        id: 'p_${DateTime.now().millisecondsSinceEpoch}',
        name: data['name']?.toString() ?? text,
        price: (data['price'] ?? 0.0).toDouble(),
        stockQuantity: (data['stockQuantity'] ?? 1).toInt(),
        unit: data['unit']?.toString() ?? 'piece',
        category: data['category']?.toString() ?? 'other',
        description: 'Added via voice: "$text"',
        district: 'Jaipur',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        shopId: 's1',
        shopName: 'Shop',
        imageUrl: '',
      );
    } catch (e) {
      debugPrint('Gemini parseProductFromVoice failed: $e');
      return ProductModel(
        id: 'p_${DateTime.now().millisecondsSinceEpoch}',
        name: text,
        price: 100.0,
        stockQuantity: 10,
        district: 'Jaipur',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        description: 'Voice added fallback: "$text"',
        unit: 'piece',
        category: 'other',
        shopId: 's1',
        shopName: 'Shop',
        imageUrl: '',
      );
    }
  }
}
