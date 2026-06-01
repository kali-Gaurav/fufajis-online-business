import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'remote_config_service.dart';

/// Enterprise WhatsApp Service using Meta Business API
/// 
/// Requirements: 
/// 1. Meta App ID
/// 2. Permanent Access Token
/// 3. Verified Phone Number ID
class MetaWhatsAppService {
  static final MetaWhatsAppService _instance = MetaWhatsAppService._internal();
  factory MetaWhatsAppService() => _instance;
  MetaWhatsAppService._internal();

  final _remoteConfig = RemoteConfigService();

  // Template Names (Must be approved in Meta Business Suite)
  static const String templateOrderConfirmed = 'order_confirmed_v2';
  static const String templateOrderPacked = 'order_packed_v1';
  static const String templateOrderOutForDelivery = 'delivery_started_otp';
  static const String templateLowStockAlert = 'owner_inventory_alert';

  /// Sends a transactional WhatsApp message
  Future<bool> sendTemplateMessage({
    required String recipientPhone,
    required String templateName,
    required List<String> parameters,
  }) async {
    final String accessToken = dotenv.get('WHATSAPP_TOKEN', fallback: '');
    final String phoneId = dotenv.get('WHATSAPP_PHONE_ID', fallback: '');

    if (accessToken.isEmpty || phoneId.isEmpty) {
      debugPrint('WhatsApp Error: Live API Credentials not found in environment.');
      return false;
    }

    final url = Uri.parse('https://graph.facebook.com/v18.0/$phoneId/messages');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "messaging_product": "whatsapp",
          "to": recipientPhone.replaceAll('+', ''),
          "type": "template",
          "template": {
            "name": templateName,
            "language": {"code": "en_US"},
            "components": [
              {
                "type": "body",
                "parameters": parameters.map((p) => {"type": "text", "text": p}).toList(),
              }
            ]
          }
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('WhatsApp Sent: $templateName to $recipientPhone');
        return true;
      } else {
        debugPrint('WhatsApp Meta API Error: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('WhatsApp Exception: $e');
      return false;
    }
  }

  /// Sends the delivery OTP to the customer (Feature 29/37)
  Future<void> sendDeliveryOTP(String phone, String name, String orderNum, String otp) async {
    await sendTemplateMessage(
      recipientPhone: phone,
      templateName: templateOrderOutForDelivery,
      parameters: [name, orderNum, otp],
    );
  }
}
