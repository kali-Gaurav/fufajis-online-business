import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// SMS Service for sending order confirmation and status update messages
/// 
/// This service handles SMS notifications for:
/// - Order confirmation
/// - Order status updates
/// - Delivery notifications
/// - Cancellation confirmations
class SMSService {
  static final SMSService _instance = SMSService._internal();
  factory SMSService() => _instance;
  SMSService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Send order confirmation SMS
  /// 
  /// Sends an SMS to the customer with order number and estimated delivery date
  /// 
  /// [Requirements 4.9]: Send confirmation SMS/notification
  Future<bool> sendOrderConfirmationSMS({
    required String phoneNumber,
    required String orderNumber,
    required String estimatedDeliveryDate,
    required double totalAmount,
  }) async {
    try {
      debugPrint('Sending order confirmation SMS to $phoneNumber');

      // Call Firebase Function to send SMS
      final result = await _functions.httpsCallable('sendOrderConfirmationSMS').call({
        'phoneNumber': phoneNumber,
        'orderNumber': orderNumber,
        'estimatedDeliveryDate': estimatedDeliveryDate,
        'totalAmount': totalAmount,
      });

      debugPrint('SMS sent successfully: ${result.data}');
      return true;
    } catch (e) {
      debugPrint('Error sending order confirmation SMS: $e');
      return false;
    }
  }

  /// Send order status update SMS
  /// 
  /// Sends an SMS to the customer with the new order status
  /// 
  /// [Requirements 5.3]: Send status update notifications
  Future<bool> sendOrderStatusUpdateSMS({
    required String phoneNumber,
    required String orderNumber,
    required String status,
    String? additionalInfo,
  }) async {
    try {
      debugPrint('Sending order status update SMS to $phoneNumber');

      final result = await _functions.httpsCallable('sendOrderStatusUpdateSMS').call({
        'phoneNumber': phoneNumber,
        'orderNumber': orderNumber,
        'status': status,
        'additionalInfo': additionalInfo,
      });

      debugPrint('Status update SMS sent successfully: ${result.data}');
      return true;
    } catch (e) {
      debugPrint('Error sending order status update SMS: $e');
      return false;
    }
  }

  /// Send delivery OTP SMS
  /// 
  /// Sends an SMS to the customer with the OTP for delivery verification
  /// 
  /// [Requirements 5.5]: Send OTP for delivery verification
  Future<bool> sendDeliveryOTPSMS({
    required String phoneNumber,
    required String orderNumber,
    required String otp,
  }) async {
    try {
      debugPrint('Sending delivery OTP SMS to $phoneNumber');

      final result = await _functions.httpsCallable('sendDeliveryOTPSMS').call({
        'phoneNumber': phoneNumber,
        'orderNumber': orderNumber,
        'otp': otp,
      });

      debugPrint('Delivery OTP SMS sent successfully: ${result.data}');
      return true;
    } catch (e) {
      debugPrint('Error sending delivery OTP SMS: $e');
      return false;
    }
  }

  /// Send order cancellation SMS
  /// 
  /// Sends an SMS to the customer confirming order cancellation and refund
  /// 
  /// [Requirements 5.7]: Send cancellation notification
  Future<bool> sendOrderCancellationSMS({
    required String phoneNumber,
    required String orderNumber,
    required double refundAmount,
  }) async {
    try {
      debugPrint('Sending order cancellation SMS to $phoneNumber');

      final result = await _functions.httpsCallable('sendOrderCancellationSMS').call({
        'phoneNumber': phoneNumber,
        'orderNumber': orderNumber,
        'refundAmount': refundAmount,
      });

      debugPrint('Cancellation SMS sent successfully: ${result.data}');
      return true;
    } catch (e) {
      debugPrint('Error sending order cancellation SMS: $e');
      return false;
    }
  }

  /// Send delivery agent assignment SMS
  /// 
  /// Sends an SMS to the customer with delivery agent details
  /// 
  /// [Requirements 5.4]: Send delivery agent assignment notification
  Future<bool> sendDeliveryAgentAssignmentSMS({
    required String phoneNumber,
    required String orderNumber,
    required String agentName,
    required String agentPhone,
    required String estimatedArrivalTime,
  }) async {
    try {
      debugPrint('Sending delivery agent assignment SMS to $phoneNumber');

      final result = await _functions.httpsCallable('sendDeliveryAgentAssignmentSMS').call({
        'phoneNumber': phoneNumber,
        'orderNumber': orderNumber,
        'agentName': agentName,
        'agentPhone': agentPhone,
        'estimatedArrivalTime': estimatedArrivalTime,
      });

      debugPrint('Delivery agent assignment SMS sent successfully: ${result.data}');
      return true;
    } catch (e) {
      debugPrint('Error sending delivery agent assignment SMS: $e');
      return false;
    }
  }

  /// Send promotional SMS
  /// 
  /// Sends promotional messages to customers
  Future<bool> sendPromotionalSMS({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      debugPrint('Sending promotional SMS to $phoneNumber');

      final result = await _functions.httpsCallable('sendPromotionalSMS').call({
        'phoneNumber': phoneNumber,
        'message': message,
      });

      debugPrint('Promotional SMS sent successfully: ${result.data}');
      return true;
    } catch (e) {
      debugPrint('Error sending promotional SMS: $e');
      return false;
    }
  }

  /// Verify phone number format
  /// 
  /// Validates that the phone number is in the correct format
  static bool isValidPhoneNumber(String phoneNumber) {
    // Indian phone number format: 10 digits
    final regex = RegExp(r'^[6-9]\d{9}$');
    return regex.hasMatch(phoneNumber.replaceAll(RegExp(r'[^\d]'), ''));
  }

  /// Format phone number for SMS sending
  /// 
  /// Ensures phone number is in the correct format for SMS gateway
  static String formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // If it starts with 0, remove it (Indian format)
    if (digits.startsWith('0')) {
      return '+91${digits.substring(1)}';
    }
    
    // If it doesn't start with country code, add +91
    if (!digits.startsWith('91')) {
      return '+91$digits';
    }
    
    return '+$digits';
  }
}
