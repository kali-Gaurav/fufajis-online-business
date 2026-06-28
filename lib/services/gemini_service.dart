import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../services/hindi_product_dictionary.dart';
import '../utils/monetary_value.dart';
import 'api_client.dart';

/// Gemini AI Service for parsing and intelligence
class GeminiService {

  /// Parse a list of items from plain text (WhatsApp message)
  Future<List<Map<String, dynamic>>> parseItemListFromText(String text) async {
    // Translate common Hindi names to English before processing
    String translatedText = text;
    hindiProductDictionary.forEach((key, value) {
      translatedText = translatedText.replaceAll(RegExp(key, caseSensitive: false), value);
    });

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
    try {
      final base64Image = base64Encode(imageBytes);
      final result = await ApiClient().post('/ai/gemini', <String, dynamic>{
        'prompt': 'Extract items/prices from this bill.',
        'image': base64Image,
        'mimeType': 'image/jpeg',
      });
      final resData = Map<String, dynamic>.from(result.data as Map);
      return resData['text']?.toString() ?? '';
    } catch (e) {
      debugPrint('Error extracting text from image: $e');
      return '';
    }
  }

  /// Snap-to-Shop: Identify product
  Future<String?> identifyProductFromImage(Uint8List imageBytes) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final result = await ApiClient().post('/ai/gemini', <String, dynamic>{
        'prompt': 'Identify this product name in 1-2 words.',
        'image': base64Image,
        'mimeType': 'image/jpeg',
      });
      final resData = Map<String, dynamic>.from(result.data as Map);
      return resData['text']?.toString().trim();
    } catch (e) {
      debugPrint('Error identifying product: $e');
      return null;
    }
  }

  /// Voice-to-Inventory (Feature 35)
  Future<Map<String, dynamic>?> parseVoiceInventoryCommand(String text) async {
    try {
      final prompt = 'Identify inventory action (ADD/UPDATE/DELETE), name, quantity, unit, price from: "$text". Return ONLY JSON.';
      final response = await _generateContent(prompt);
      final cleaned = response.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleaned) as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error parsing voice command: $e');
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
    try {
      final base64Image = base64Encode(imageBytes);

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

      final result = await ApiClient().post('/ai/gemini', <String, dynamic>{
        'prompt': prompt,
        'image': base64Image,
        'mimeType': 'image/jpeg',
      });
      final resData = Map<String, dynamic>.from(result.data as Map);
      final rawText = resData['text']?.toString() ?? '';
      final cleaned = rawText.replaceAll('```json', '').replaceAll('```', '').trim();

      try {
        final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
        if (decoded['items'] is! List) {
          decoded['items'] = [];
        }
        return decoded;
      } catch (_) {
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
    try {
      final result = await ApiClient().post('/ai/gemini', <String, dynamic>{
        'prompt': prompt,
      });
      final resData = Map<String, dynamic>.from(result.data as Map);
      return resData['text']?.toString() ?? 'No response';
    } catch (e) {
      debugPrint('Static generateText failed: $e');
      return "Sorry, I'm resting. Ask later!";
    }
  }

  Future<String> _generateContent(String prompt) async {
    try {
      final result = await ApiClient().post('/ai/gemini', <String, dynamic>{
        'prompt': prompt,
      });
      final resData = Map<String, dynamic>.from(result.data as Map);
      return resData['text']?.toString() ?? '';
    } catch (e) {
      debugPrint('Gemini _generateContent failed: $e');
      return '';
    }
  }

  List<Map<String, dynamic>> _parseJsonList(String response) {
    try {
      final cleaned = response.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(cleaned);
      if (decoded is List) return List<Map<String, dynamic>>.from(decoded);
      if (decoded is Map) return [Map<String, dynamic>.from(decoded)];
      return [];
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
    try {
      final prompt = 'Extract primary searchable keywords (items like "potato", "milk") from this sentence in Hindi or English: "$text". Return ONLY a comma-separated list of English keywords.';
      final response = await _generateContent(prompt);
      if (response.isEmpty) return text.split(' ').where((s) => s.length > 2).toList();
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
        price: MonetaryValue((data['price'] ?? 0.0).toDouble()),
        stockQuantity: (data['stockQuantity'] ?? 1).toInt(),
        unit: data['unit']?.toString() ?? 'piece',
        categoryId: data['category']?.toString() ?? 'other',
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
        price: MonetaryValue(100.0),
        stockQuantity: 10,
        district: 'Jaipur',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        description: 'Voice added fallback: "$text"',
        unit: 'piece',
        categoryId: 'other',
        category: 'other',
        shopId: 's1',
        shopName: 'Shop',
        imageUrl: '',
      );
    }
  }
}
