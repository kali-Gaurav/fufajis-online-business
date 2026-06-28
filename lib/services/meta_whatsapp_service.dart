import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// Enterprise WhatsApp Service using Meta Business API
/// Routed securely through Cloud Functions.
class MetaWhatsAppService {
  static final MetaWhatsAppService _instance = MetaWhatsAppService._internal();
  factory MetaWhatsAppService() => _instance;
  MetaWhatsAppService._internal();

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
    try {
      final result = await ApiClient().post('/whatsapp/send', <String, dynamic>{
        'to': recipientPhone.replaceAll('+', '').replaceAll(RegExp(r'[^\d]'), ''),
        'type': 'template',
        'template': {
          "name": templateName,
          "language": {"code": "en_US"},
          "components": [
            {
              "type": "body",
              "parameters": parameters
                  .map((p) => {"type": "text", "text": p})
                  .toList(),
            },
          ],
        },
      });

      final resData = Map<String, dynamic>.from(result.data as Map);
      return resData['success'] == true;
    } catch (e) {
      debugPrint('WhatsApp Meta API Error via ApiClient: $e');
      return false;
    }
  }

  /// Sends the delivery OTP to the customer (Feature 29/37)
  Future<void> sendDeliveryOTP(
    String phone,
    String name,
    String orderNum,
    String otp,
  ) async {
    await sendTemplateMessage(
      recipientPhone: phone,
      templateName: templateOrderOutForDelivery,
      parameters: [name, orderNum, otp],
    );
  }
}
