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

  /// Send order confirmation SMS
  Future<bool> sendOrderConfirmationSMS({
    required String phoneNumber,
    required String orderNumber,
    required String estimatedDeliveryDate,
    required double totalAmount,
  }) async {
    debugPrint('[SMSService] Stub: Order confirmation for $orderNumber to $phoneNumber');
    return true;
  }

  /// Send order status update SMS
  Future<bool> sendOrderStatusUpdateSMS({
    required String phoneNumber,
    required String orderNumber,
    required String status,
    String? additionalInfo,
  }) async {
    debugPrint('[SMSService] Stub: Order status update $status for $orderNumber to $phoneNumber');
    return true;
  }

  /// Send delivery OTP SMS
  Future<bool> sendDeliveryOTPSMS({
    required String phoneNumber,
    required String orderNumber,
    required String otp,
  }) async {
    debugPrint('[SMSService] Stub: Delivery OTP for $orderNumber to $phoneNumber');
    return true;
  }

  /// Send order cancellation SMS
  Future<bool> sendOrderCancellationSMS({
    required String phoneNumber,
    required String orderNumber,
    required double refundAmount,
  }) async {
    debugPrint('[SMSService] Stub: Order cancellation for $orderNumber to $phoneNumber');
    return true;
  }

  /// Send delivery agent assignment SMS
  Future<bool> sendDeliveryAgentAssignmentSMS({
    required String phoneNumber,
    required String orderNumber,
    required String agentName,
    required String agentPhone,
    required String estimatedArrivalTime,
  }) async {
    debugPrint('[SMSService] Stub: Agent assignment for $orderNumber to $phoneNumber');
    return true;
  }

  /// Send promotional SMS
  Future<bool> sendPromotionalSMS({
    required String phoneNumber,
    required String message,
  }) async {
    debugPrint('[SMSService] Stub: Promotional SMS to $phoneNumber');
    return true;
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
