import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import 'gemini_service.dart';

/// WhatsApp Sync Service for Bulk Product Upload
/// Handles incoming WhatsApp messages, processes bill photos, and updates inventory
class WhatsAppSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GeminiService _geminiService = GeminiService();
  final Uuid _uuid = const Uuid();

  // WhatsApp Webhook configuration
  static const String _verifyToken = 'fufaji_whatsapp_verify';
  static const String _apiUrl = 'https://graph.facebook.com/v18.0';

  // WhatsApp Business Phone Number ID
  String? _phoneNumberId;
  String? _accessToken;

  /// Configure WhatsApp Business credentials
  void configure({required String phoneNumberId, required String accessToken}) {
    _phoneNumberId = phoneNumberId;
    _accessToken = accessToken;
  }

  /// Verify WhatsApp webhook
  String verifyWebhook(String mode, String token, String challenge) {
    if (mode == 'subscribe' && token == _verifyToken) {
      return challenge;
    }
    return '';
  }

  /// Process incoming WhatsApp message
  Future<void> processIncomingMessage(Map<String, dynamic> webhookData) async {
    try {
      final entry = webhookData['entry']?[0];
      final changes = entry?['changes']?[0];
      final value = changes?['value'];

      final messages = value?['messages'];
      if (messages == null || messages.isEmpty) return;

      for (final message in messages) {
        final from = message['from'];
        final messageId = message['id'];
        final type = message['type'];

        // Check if already processed
        if (await _isMessageProcessed(messageId)) continue;

        switch (type) {
          case 'text':
            await _processTextMessage(from, message['text']['body'], messageId);
            break;
          case 'image':
            await _processImageMessage(from, message['image'], messageId);
            break;
          case 'document':
            await _processDocumentMessage(from, message['document'], messageId);
            break;
          default:
            await _sendReply(from, 'Sorry, I can only process text messages and images of bills. Please send a photo of your bill or a list of items.');
        }

        // Mark message as processed
        await _markMessageProcessed(messageId, from);
      }
    } catch (e) {
      debugPrint('Error processing WhatsApp message: $e');
    }
  }

  /// Process text message with item list
  Future<void> _processTextMessage(String from, String message, String messageId) async {
    try {
      // Parse the item list using Gemini AI
      final items = await _geminiService.parseItemListFromText(message);

      if (items.isEmpty) {
        await _sendReply(from, 'I could not understand the items list. Please try again with a format like:\n\n"Add 20 apples at 150, 10 bananas at 50"');
        return;
      }

      // Get or create shop profile for this user
      final shopId = await _getShopIdFromPhone(from);
      if (shopId == null) {
        await _sendReply(from, 'Your phone number is not registered as a shop. Please register your shop first.');
        return;
      }

      // Process and add items to inventory
      final results = await _addItemsToInventory(shopId, items);

      // Send summary to shop owner
      final successCount = results.where((r) => r['success']).length;
      final failCount = results.length - successCount;

      String response = '✅ Added $successCount items to inventory:\n\n';
      for (final result in results.where((r) => r['success'])) {
        response += '• ${result['name']} - ₹${result['price']} (${result['quantity']} ${result['unit']})\n';
      }

      if (failCount > 0) {
        response += '\n⚠️ $failCount items could not be added. Please check and try again.';
      }

      await _sendReply(from, response);
    } catch (e) {
      await _sendReply(from, 'Error processing your message: $e');
    }
  }

  /// Process image message (bill photo)
  Future<void> _processImageMessage(String from, Map<String, dynamic> imageData, String messageId) async {
    try {
      await _sendReply(from, '📸 Processing your bill image... This may take a moment.');

      // Download the image
      final imageUrl = imageData['id'];
      final imageBytes = await _downloadMedia(imageUrl);

      // Enhance image for better OCR
      final enhancedImage = await _enhanceImage(imageBytes);

      // Extract text using OCR (Gemini Vision)
      final extractedText = await _geminiService.extractTextFromImage(enhancedImage);

      // Parse the extracted text into items
      final items = await _geminiService.parseBillItems(extractedText);

      if (items.isEmpty) {
        await _sendReply(from, 'I could not extract any items from this image. Please try sending a clearer image or type the items manually.');
        return;
      }

      // Get or create shop profile
      final shopId = await _getShopIdFromPhone(from);
      if (shopId == null) {
        await _sendReply(from, 'Your phone number is not registered as a shop. Please register your shop first.');
        return;
      }

      // Process and add items
      final results = await _addItemsToInventory(shopId, items);

      // Send summary
      final successCount = results.where((r) => r['success']).length;
      
      String response = '✅ Successfully processed bill! Added $successCount items:\n\n';
      for (final result in results.where((r) => r['success']).take(5)) {
        response += '• ${result['name']} - ₹${result['price']}\n';
      }
      if (results.length > 5) {
        response += '\n...and ${results.length - 5} more items';
      }

      await _sendReply(from, response);
    } catch (e) {
      await _sendReply(from, 'Error processing image: $e. Please try again.');
    }
  }

  /// Process document message (PDF/Excel bill)
  Future<void> _processDocumentMessage(String from, Map<String, dynamic> documentData, String messageId) async {
    try {
      await _sendReply(from, '📄 Processing your document...');

      // Download the document
      final mimeType = documentData['mime_type'];

      if (mimeType == 'application/pdf') {
        // Process PDF bill
        await _sendReply(from, 'PDF processing is not yet supported. Please send an image of the bill.');
      } else {
        await _sendReply(from, 'Unsupported document format. Please send an image of the bill.');
      }
    } catch (e) {
      await _sendReply(from, 'Error processing document: $e');
    }
  }

  /// Download media from WhatsApp
  Future<Uint8List> _downloadMedia(String mediaId) async {
    final url = '$_apiUrl/$mediaId';
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to download media: ${response.statusCode}');
    }

    return response.bodyBytes;
  }

  /// Enhance image for better OCR
  Future<Uint8List> _enhanceImage(Uint8List imageBytes) async {
    try {
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      // Increase contrast
      image = img.adjustColor(image, contrast: 1.2, brightness: 1.1);

      // Sharpen - Using convolution as sharpen is sometimes not available in all versions
      image = img.convolution(image, filter: [
        0, -1,  0,
       -1,  5, -1,
        0, -1,  0
      ]);

      // Convert back to bytes
      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      return imageBytes;
    }
  }

  /// Get shop ID from phone number
  Future<String?> _getShopIdFromPhone(String phone) async {
    // Normalize phone number
    final normalizedPhone = _normalizePhoneNumber(phone);

    // Query Firestore for shop with this phone
    final snapshot = await _firestore
        .collection('shops')
        .where('phoneNumber', isEqualTo: normalizedPhone)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.id;
    }

    // Check users collection
    final userSnapshot = await _firestore
        .collection('users')
        .where('phoneNumber', isEqualTo: normalizedPhone)
        .where('role', isEqualTo: 'shop_owner')
        .limit(1)
        .get();

    if (userSnapshot.docs.isNotEmpty) {
      return userSnapshot.docs.first.id;
    }

    return null;
  }

  /// Normalize phone number
  String _normalizePhoneNumber(String phone) {
    // Remove any non-digit characters
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    
    // Add country code if missing
    if (digits.length == 10) {
      digits = '91$digits';
    }
    
    return digits;
  }

  /// Add items to inventory
  Future<List<Map<String, dynamic>>> _addItemsToInventory(
    String shopId,
    List<Map<String, dynamic>> items,
  ) async {
    final results = <Map<String, dynamic>>[];
    final shopDoc = await _firestore.collection('shops').doc(shopId).get();
    final shopName = shopDoc.data()?['shopName'] ?? 'My Shop';

    for (final item in items) {
      try {
        final productId = _uuid.v4();
        final now = DateTime.now();

        final product = ProductModel(
          id: productId,
          name: item['name'] ?? 'Unknown Item',
          description: 'Added via WhatsApp',
          price: (item['price'] ?? 0).toDouble(),
          originalPrice: (item['price'] ?? 0).toDouble(),
          unit: item['unit'] ?? 'piece',
          category: item['category'] ?? 'groceries',
          shopId: shopId,
          shopName: shopName,
          imageUrl: '',
          images: [],
          stockQuantity: item['quantity'] ?? 0,
          isAvailable: true,
          createdAt: now,
          updatedAt: now,
          district: shopDoc.data()?['district'] ?? 'Jaipur',
        );

        await _firestore.collection('products').doc(productId).set(product.toMap());

        results.add({
          'success': true,
          'name': product.name,
          'price': product.price,
          'quantity': product.stockQuantity,
          'unit': product.unit,
        });
      } catch (e) {
        results.add({
          'success': false,
          'name': item['name'] ?? 'Unknown',
          'error': e.toString(),
        });
      }
    }

    return results;
  }

  /// Send reply message
  Future<void> _sendReply(String to, String message) async {
    if (_phoneNumberId == null || _accessToken == null) {
      debugPrint('WhatsApp credentials not configured');
      return;
    }

    final url = '$_apiUrl/$_phoneNumberId/messages';
    final body = jsonEncode({
      'messaging_product': 'whatsapp',
      'to': to,
      'type': 'text',
      'text': {'body': message},
    });

    await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: body,
    );
  }

  /// Check if message was already processed
  Future<bool> _isMessageProcessed(String messageId) async {
    final doc = await _firestore.collection('whatsapp_processed').doc(messageId).get();
    return doc.exists;
  }

  /// Mark message as processed
  Future<void> _markMessageProcessed(String messageId, String from) async {
    await _firestore.collection('whatsapp_processed').doc(messageId).set({
      'from': from,
      'processedAt': DateTime.now(),
    });
  }

  /// Send template message for new shop registration
  Future<void> sendRegistrationTemplate(String phone) async {
    const message = '''🏪 Welcome to Fufaji Online!

Your shop has been registered successfully. You can now:

📸 Send photos of bills to add products
📝 Type item lists to update inventory
💰 Track sales and manage orders

Start by sending a photo of your product list or inventory bill!

Reply HELP for assistance.''';

    await _sendReply(phone, message);
  }

  /// Send low stock alert
  Future<void> sendLowStockAlert(String shopId, List<Map<String, dynamic>> lowStockItems) async {
    final shopDoc = await _firestore.collection('shops').doc(shopId).get();
    final phone = shopDoc.data()?['phoneNumber'];

    if (phone == null) return;

    String message = '⚠️ Low Stock Alert!\n\nThe following items need restocking:\n\n';
    for (final item in lowStockItems.take(5)) {
      message += '• ${item['name']} - Only ${item['quantity']} left\n';
    }
    if (lowStockItems.length > 5) {
      message += '\n...and ${lowStockItems.length - 5} more items';
    }

    message += '\n\nReply with item details to add stock.';

    await _sendReply(phone, message);
  }
}
