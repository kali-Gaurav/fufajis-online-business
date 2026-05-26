import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WhatsAppNotificationService {
  static String get _token => dotenv.get('WHATSAPP_TOKEN', fallback: '');
  static String get _phoneId => dotenv.get('WHATSAPP_PHONE_ID', fallback: '');
  static String get _baseUrl => "https://graph.facebook.com/v25.0/$_phoneId/messages";

  /// Sends a template message to a customer via WhatsApp Meta API
  static Future<bool> sendStatusUpdate({
    required String phoneNumber,
    required String customerName,
    required String orderNumber,
    required String status,
    String? otp,
  }) async {
    // Basic phone number sanitation (Meta requires number without '+')
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Ensure it has country code, default to 91 for India if missing
    if (cleanNumber.length == 10) {
      cleanNumber = '91$cleanNumber';
    }

    // NOTE: Meta requires you to have these templates approved in your WhatsApp Manager.
    // If you haven't created 'order_update' template yet, this will fail.
    // I am using 'hello_world' as a fallback if you just want to test connection.
    
    final String templateName = _getTemplateName(status);

    try {
      debugPrint("Attempting Meta WhatsApp API call to $cleanNumber using template: $templateName");
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_token",
        },
        body: jsonEncode({
          "messaging_product": "whatsapp",
          "to": cleanNumber,
          "type": "template",
          "template": {
            "name": templateName,
            "language": { "code": "en_US" },
            "components": [
              {
                "type": "body",
                "parameters": _getTemplateParameters(customerName, orderNumber, status, otp)
              }
            ]
          }
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("WhatsApp Sent Successfully!");
        return true;
      } else {
        debugPrint("WhatsApp API Failure: ${response.statusCode} - ${response.body}");
        // If your custom templates aren't approved yet, try sending 'hello_world' to test connection
        if (templateName != 'hello_world') {
           debugPrint("Retrying with 'hello_world' test template...");
           return await sendHelloWorld(cleanNumber);
        }
        return false;
      }
    } catch (e) {
      debugPrint("WhatsApp API Error: $e");
      return false;
    }
  }

  /// Special method to send the default 'hello_world' template provided by Meta
  static Future<bool> sendHelloWorld(String cleanNumber) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_token",
        },
        body: jsonEncode({
          "messaging_product": "whatsapp",
          "to": cleanNumber,
          "type": "template",
          "template": {
            "name": "hello_world",
            "language": { "code": "en_US" }
          }
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static String _getTemplateName(String status) {
    // These names MUST match the "Template Name" you created in Meta WhatsApp Manager
    switch (status.toLowerCase()) {
      case 'confirmed': return 'order_confirmed';
      case 'outfordelivery': return 'order_out_for_delivery';
      case 'delivered': return 'order_delivered';
      default: return 'hello_world'; // Default test template
    }
  }

  static List<Map<String, dynamic>> _getTemplateParameters(
    String name, 
    String order, 
    String status, 
    String? otp
  ) {
    // These are the {{1}}, {{2}} variables in your Meta templates
    List<Map<String, dynamic>> params = [
      {"type": "text", "text": name},
      {"type": "text", "text": order},
    ];

    if (status.toLowerCase() == 'outfordelivery' && otp != null) {
      params.add({"type": "text", "text": otp});
    }

    return params;
  }
}
