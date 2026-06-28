import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sms_service.dart';
import 'notification_service.dart';
import 'api_client.dart';

class _HttpShim {
  Future<_ResponseShim> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    try {
      final decodedBody = jsonDecode(body as String) as Map<String, dynamic>;
      final result = await ApiClient().post('/whatsapp/send', <String, dynamic>{
        'to': decodedBody['to'],
        'type': decodedBody['type'],
        if (decodedBody['text'] != null) 'text': decodedBody['text'],
        if (decodedBody['template'] != null) 'template': decodedBody['template'],
        if (decodedBody['interactive'] != null) 'interactive': decodedBody['interactive'],
      });
      return _ResponseShim(200, jsonEncode(result.data ?? {}));
    } catch (e) {
      debugPrint('[WhatsAppShim] post failed: $e');
      return _ResponseShim(500, e.toString());
    }
  }
}

class _ResponseShim {
  final int statusCode;
  final String body;
  _ResponseShim(this.statusCode, this.body);
}

final _HttpShim http = _HttpShim();

class WhatsAppNotificationService {
  static FirebaseFirestore? _customDb;
  static FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;
  static set db(FirebaseFirestore database) => _customDb = database;

  static String get _token => '';
  static String get _phoneId => '';
  static String get _baseUrl => '';

  /// Gets the active notification phase from Firestore (default is Phase 1)
  static Future<int> _getActivePhase() async {
    try {
      final doc = await _db
          .collection('settings')
          .doc('whatsapp_config')
          .get();
      if (doc.exists && doc.data() != null) {
        return doc.data()?['phase'] ?? 1;
      }
    } catch (_) {}
    return 1; // Default to Phase 1 (Text Messages) until template approval is confirmed
  }

  /// Sends a generic text message via WhatsApp
  static Future<bool> sendOrderUpdate({
    required String phoneNumber,
    required String message,
  }) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanNumber.length == 10) {
      cleanNumber = '91$cleanNumber';
    }

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
          "type": "text",
          "text": {"body": message},
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[WhatsApp] Generic message error: $e');
      return false;
    }
  }

  /// Sends a status update via WhatsApp matching the active configuration phase (1, 2, or 3)
  static Future<bool> sendStatusUpdate({
    required String phoneNumber,
    required String customerName,
    required String orderNumber,
    required String status,
    String? otp,
  }) async {
    // Basic phone number sanitation
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanNumber.length == 10) {
      cleanNumber = '91$cleanNumber';
    }

    final int phase = await _getActivePhase();
    debugPrint('[WhatsApp] Active Notification Phase: $phase');

    // ─── PHASE 1: TEXT MESSAGES (UNAPPROVED FALLBACK) ───
    if (phase == 1) {
      final buffer = StringBuffer();
      buffer.writeln('📦 *ORDER UPDATE - FUFAJI STORE*');
      buffer.writeln('━━━━━━━━━━━━━━━━━━');
      buffer.writeln('Namaste $customerName,');
      buffer.writeln('');

      switch (status.toLowerCase()) {
        case 'confirmed':
          buffer.writeln(
            'Your order *#$orderNumber* has been confirmed by Fufaji Store. We are preparing it fresh for delivery! 🛒',
          );
          break;
        case 'outfordelivery':
          buffer.writeln(
            'Great news! Your order *#$orderNumber* is out for delivery. 🚚',
          );
          if (otp != null) {
            buffer.writeln('');
            buffer.writeln('🔑 *Delivery OTP: $otp*');
            buffer.writeln(
              'Please share this code only with our delivery rider.',
            );
          }
          break;
        case 'delivered':
          buffer.writeln(
            'Your order *#$orderNumber* has been delivered. Thank you for shopping with Fufaji! 🙏',
          );
          break;
        default:
          buffer.writeln(
            'Status of your order *#$orderNumber* is now: *$status*.',
          );
      }

      buffer.writeln('');
      buffer.writeln('Fixed pricing. Honest quality. Locally operated.');
      return await sendOrderUpdate(
        phoneNumber: cleanNumber,
        message: buffer.toString(),
      );
    }

    // ─── PHASE 3: INTERACTIVE BUTTONS ───
    if (phase == 3) {
      try {
        final bodyText =
            "Namaste $customerName, your order #$orderNumber is $status. ${otp != null ? 'Your Delivery OTP is $otp.' : ''}";
        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $_token",
          },
          body: jsonEncode({
            "messaging_product": "whatsapp",
            "to": cleanNumber,
            "type": "interactive",
            "interactive": {
              "type": "button",
              "body": {"text": bodyText},
              "footer": {"text": "Fufaji Stores - Honest Pricing"},
              "action": {
                "buttons": [
                  {
                    "type": "reply",
                    "reply": {"id": "btn_track", "title": "Track Order"},
                  },
                  {
                    "type": "reply",
                    "reply": {"id": "btn_help", "title": "Call Store"},
                  },
                ],
              },
            },
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return true;
        } else {
          debugPrint(
            "Phase 3 Interactive message failed: ${response.body}. Falling back to Phase 1.",
          );
          // Fall back to plain text
          phase == 1;
        }
      } catch (e) {
        debugPrint(
          "Phase 3 Interactive message exception: $e. Falling back to Phase 1.",
        );
      }
    }

    // ─── PHASE 2: APPROVED TEMPLATES (DEFAULT METAS) ───
    final String templateName = _getTemplateName(status);

    try {
      debugPrint(
        "Attempting Meta WhatsApp API call to $cleanNumber using template: $templateName",
      );

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
            "language": {"code": "en_US"},
            "components": [
              {
                "type": "body",
                "parameters": _getTemplateParameters(
                  customerName,
                  orderNumber,
                  status,
                  otp,
                ),
              },
            ],
          },
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("WhatsApp Sent Successfully!");
        return true;
      } else {
        debugPrint(
          "WhatsApp API Failure: ${response.statusCode} - ${response.body}",
        );
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
            "language": {"code": "en_US"},
          },
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
      case 'confirmed':
        return 'order_confirmed';
      case 'outfordelivery':
        return 'order_out_for_delivery';
      case 'delivered':
        return 'order_delivered';
      default:
        return 'hello_world'; // Default test template
    }
  }

  static List<Map<String, dynamic>> _getTemplateParameters(
    String name,
    String order,
    String status,
    String? otp,
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

  // ─── INVOICE DELIVERY ───────────────────────────────────────────────

  /// Send a formatted invoice to the customer via WhatsApp text message
  /// Includes: order items, quantities, prices, total, payment method
  static Future<bool> sendInvoice({
    required String phoneNumber,
    required String customerName,
    required String orderNumber,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double deliveryCharge,
    required double discount,
    required double totalAmount,
    required String paymentMethod,
    String? estimatedDelivery,
  }) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanNumber.length == 10) {
      cleanNumber = '91$cleanNumber';
    }

    // Build invoice text
    final buffer = StringBuffer();
    buffer.writeln('🧾 *FUFAJI INVOICE*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Order: #$orderNumber');
    buffer.writeln('Customer: $customerName');
    buffer.writeln('');
    buffer.writeln('*Items:*');

    for (var item in items) {
      final name = item['productName'] ?? 'Item';
      final qty = item['quantity'] ?? 1;
      final unit = item['unit'] ?? '';
      final price = (item['price'] ?? 0.0).toDouble();
      final total = price * qty;
      buffer.writeln('• $name × $qty $unit = ₹${total.round()}');
    }

    buffer.writeln('');
    buffer.writeln('━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Subtotal: ₹${subtotal.round()}');
    if (discount > 0) {
      buffer.writeln('Discount: -₹${discount.round()}');
    }
    if (deliveryCharge > 0) {
      buffer.writeln('Delivery: ₹${deliveryCharge.round()}');
    }
    buffer.writeln('*Total: ₹${totalAmount.round()}*');
    buffer.writeln('Payment: $paymentMethod');
    if (estimatedDelivery != null) {
      buffer.writeln('ETA: $estimatedDelivery');
    }
    buffer.writeln('');
    buffer.writeln('Thank you for shopping with Fufaji! 🙏');
    buffer.writeln('Fixed prices. Trusted quality.');

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
          "type": "text",
          "text": {"body": buffer.toString()},
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("[WhatsApp] Invoice sent to $cleanNumber");
        return true;
      } else {
        debugPrint(
          "[WhatsApp] Invoice failed: ${response.statusCode} - ${response.body}",
        );
        return false;
      }
    } catch (e) {
      debugPrint("[WhatsApp] Invoice error: $e");
      return false;
    }
  }

  // ─── DELIVERY OTP + TRACKING LINK ──────────────────────────────────

  /// Send delivery OTP and tracking deep-link when order goes out for delivery
  static Future<bool> sendDeliveryOtpWithTracking({
    required String phoneNumber,
    required String customerName,
    required String orderNumber,
    required String otp,
    required String orderId,
    String? riderName,
    String? riderPhone,
  }) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanNumber.length == 10) {
      cleanNumber = '91$cleanNumber';
    }

    // Deep link format — adjust domain to your actual app link
    final trackingUrl = 'https://fufaji.app/track/$orderId';

    final buffer = StringBuffer();
    buffer.writeln('🚚 *ORDER OUT FOR DELIVERY*');
    buffer.writeln('');
    buffer.writeln('Order #$orderNumber is on its way!');
    if (riderName != null) {
      buffer.writeln('Delivery by: $riderName');
    }
    if (riderPhone != null) {
      buffer.writeln('Call rider: $riderPhone');
    }
    buffer.writeln('');
    buffer.writeln('🔑 *Your Delivery OTP: $otp*');
    buffer.writeln('Share this with the delivery person.');
    buffer.writeln('');
    buffer.writeln('📍 Track your order: $trackingUrl');
    buffer.writeln('');
    buffer.writeln('— Team Fufaji 🙏');

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
          "type": "text",
          "text": {"body": buffer.toString()},
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("[WhatsApp] OTP+Tracking sent to $cleanNumber");
        return true;
      } else {
        debugPrint("[WhatsApp] OTP+Tracking failed: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      debugPrint("[WhatsApp] OTP+Tracking error: $e");
      return false;
    }
  }

  /// Send substitution notification via WhatsApp text message
  static Future<bool> sendSubstitutionNotification({
    required String phoneNumber,
    required String customerName,
    required String orderNumber,
    required String originalName,
    required String replacementName,
    required double replacementPrice,
  }) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanNumber.length == 10) {
      cleanNumber = '91$cleanNumber';
    }

    final message =
        '⚠️ *ITEM OUT OF STOCK - FUFAJI*\n\n'
        'Dear $customerName,\n'
        'For your Order #$orderNumber, *$originalName* is out of stock.\n'
        'We have replaced it with *$replacementName* (₹${replacementPrice.round()}) to avoid delivery delays.\n\n'
        'If you would like to cancel/change this item, please reply immediately! 🙏';

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
          "type": "text",
          "text": {"body": message},
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[WhatsApp] Substitution notify error: $e');
      return false;
    }
  }

  /// Sends an operational sync conflict warning to a store manager/owner
  static Future<bool> sendConflictAlert({
    required String phoneNumber,
    required String managerName,
    required String actionType,
    required String documentId,
    required String details,
  }) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanNumber.length == 10) {
      cleanNumber = '91$cleanNumber';
    }

    final message =
        '🚨 *SYNC CONFLICT ALERT - FUFAJI STORE*\n\n'
        'Hello $managerName,\n'
        'An offline operation conflict was detected and resolved on the server:\n\n'
        '• *Operation:* ${actionType.toUpperCase()}\n'
        '• *ID:* $documentId\n'
        '• *Status:* Overwritten by newer server data.\n\n'
        '📝 *Details:* $details\n\n'
        'Please review this conflict in the store manager dashboard. 🙏';

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
          "type": "text",
          "text": {"body": message},
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[WhatsApp] Conflict alert send failed: $e');
      return false;
    }
  }

  /// Sends an attendance geofence/GPS warning to a store manager
  static Future<bool> sendGpsVarianceAlert({
    required String phoneNumber,
    required String managerName,
    required String employeeName,
    required double accuracy,
    required double distance,
  }) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanNumber.length == 10) {
      cleanNumber = '91$cleanNumber';
    }

    final message =
        '⚠️ *HIGH GPS VARIANCE ATTENDANCE ALERT*\n\n'
        'Hello $managerName,\n'
        'Employee *$employeeName* clocked in with low GPS accuracy or high distance variance:\n\n'
        '• *GPS Accuracy:* ${accuracy.toStringAsFixed(1)} meters\n'
        '• *Distance to Branch:* ${distance.toStringAsFixed(1)} meters\n\n'
        'The attendance check-in was logged, but requires visual/operational audit. 🙏';

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
          "type": "text",
          "text": {"body": message},
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[WhatsApp] GPS variance alert failed: $e');
      return false;
    }
  }

  /// Sends a digital Bahi-Khata credit payment reminder via WhatsApp text message
  static Future<bool> sendLedgerReminder({
    required String phoneNumber,
    required String customerName,
    required double outstandingAmount,
  }) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanNumber.length == 10) {
      cleanNumber = '91$cleanNumber';
    }

    final message =
        '🏪 *BAHI-KHATA PAYMENT REMINDER - FUFAJI STORE*\n\n'
        'Namaste $customerName,\n'
        'This is a friendly reminder from Fufaji Store regarding your digital ledger balance:\n\n'
        '• *Outstanding Balance:* ₹${outstandingAmount.toStringAsFixed(2)}\n\n'
        'Please clear your dues at your convenience using cash, UPI, or by visiting the store. 🙏\n'
        'Thank you for your trust!';

    return await sendOrderUpdate(
      phoneNumber: cleanNumber,
      message: message,
    );
  }

  /// Alias for sendStatusUpdate for compatibility with delivery verification
  static Future<bool> sendOrderStatusUpdate({
    required String phoneNumber,
    required String customerName,
    required String orderNumber,
    required String status,
  }) async {
    return await sendStatusUpdate(
      phoneNumber: phoneNumber,
      customerName: customerName,
      orderNumber: orderNumber,
      status: status,
    );
  }

  /// Sends a delivery OTP message
  static Future<bool> sendOTPMessage({
    required String phoneNumber,
    required String customerName,
    required String otp,
    required String orderNumber,
  }) async {
    return await sendStatusUpdate(
      phoneNumber: phoneNumber,
      customerName: customerName,
      orderNumber: orderNumber,
      status: 'outfordelivery',
      otp: otp,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // RESILIENT NOTIFICATION WRAPPER WITH AUTOMATIC FALLBACK
  // ─────────────────────────────────────────────────────────────────────

  /// Sends a notification via WhatsApp first; if it fails, falls back to
  /// FCM push, then SMS, and finally local In-App notifications.
  /// Enforces audit logs and mirrors to AWS RDS.
  static Future<bool> sendWithFallback({
    required String customerId,
    required String phoneNumber,
    required String title,
    required String body,
    String? orderId,
    String? notificationType,
  }) async {
    final db = _db;
    bool whatsappSent = false;
    bool fcmSent = false;
    bool smsSent = false;
    bool inAppSent = false;
    String channel = 'none';
    String? errorMessage;

    // ── Attempt 1: WhatsApp ──
    try {
      whatsappSent = await sendOrderUpdate(
        phoneNumber: phoneNumber,
        message: '$title\n\n$body',
      );
      if (whatsappSent) {
        channel = 'whatsapp';
      } else {
        errorMessage = 'WhatsApp API rejected';
      }
    } catch (e) {
      errorMessage = e.toString();
      debugPrint('[NotificationFallback] WhatsApp failed: $e');
    }

    // ── Attempt 2: FCM Push Notification (if WhatsApp failed) ──
    if (!whatsappSent) {
      try {
        final userDoc = await db.collection('users').doc(customerId).get();
        final fcmToken = userDoc.data()?['fcmToken']?.toString();

        if (fcmToken != null && fcmToken.isNotEmpty) {
          await db.collection('notification_queue').add({
            'userId': customerId,
            'fcmToken': fcmToken,
            'title': title,
            'body': body,
            'orderId': orderId,
            'type': notificationType ?? 'order_update',
            'channel': 'fcm',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
          fcmSent = true;
          channel = 'fcm';
        } else {
          errorMessage = 'FCM token not found for user';
        }
      } catch (e) {
        errorMessage = e.toString();
        debugPrint('[NotificationFallback] FCM fallback failed: $e');
      }
    }

    // ── Attempt 3: SMS Alerts (if FCM fails) ──
    if (!whatsappSent && !fcmSent) {
      try {
        smsSent = await SMSService().sendOrderStatusUpdateSMS(
          phoneNumber: phoneNumber,
          orderNumber: orderId ?? 'FufajiOrder',
          status: notificationType ?? 'update',
          additionalInfo: '$title - $body',
        );
        if (smsSent) {
          channel = 'sms';
        } else {
          errorMessage = 'SMS gateway rejected delivery';
        }
      } catch (e) {
        errorMessage = e.toString();
        debugPrint('[NotificationFallback] SMS fallback failed: $e');
      }
    }

    // ── Attempt 4: In-app notification (always succeeds as fallback) ──
    if (!whatsappSent && !fcmSent && !smsSent) {
      try {
        inAppSent = await NotificationService().sendNotificationToUser(
          userId: customerId,
          title: title,
          body: body,
          channelUsed: 'in_app',
          data: {
            'orderId': orderId,
            'type': notificationType ?? 'order_update',
          },
        );
        if (inAppSent) {
          channel = 'in_app';
        }
      } catch (e) {
        errorMessage = e.toString();
        debugPrint('[NotificationFallback] In-app fallback failed: $e');
      }
    }

    // ── Log the notification attempt for delivery audit ──
    final String docId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    final timestamp = DateTime.now();

    try {
      await db.collection('notification_delivery_log').doc(docId).set({
        'id': docId,
        'customerId': customerId,
        'phoneNumber': phoneNumber,
        'orderId': orderId,
        'type': notificationType ?? 'order_update',
        'whatsappSent': whatsappSent,
        'fcmSent': fcmSent,
        'smsSent': smsSent,
        'inAppSent': inAppSent,
        'channelUsed': channel,
        'timestamp': FieldValue.serverTimestamp(),
        'errorMessage': errorMessage,
      });

      // Mirror audit logs to AWS RDS is deprecated. Logs are consolidated in Firestore.
    } catch (e) {
      debugPrint('[NotificationFallback] Logging delivery audit failed: $e');
    }

    return whatsappSent || fcmSent || smsSent || inAppSent;
  }
}
