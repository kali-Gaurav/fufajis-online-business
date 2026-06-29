import 'package:flutter/foundation.dart';

/// Service for sending transactional emails via SendGrid (through Cloud Functions).
/// Mirrors the pattern used by [SMSService].
class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  /// Generic email send.
  Future<bool> sendEmail({
    required String to,
    required String subject,
    String? html,
    String? text,
    List<String>? categories,
  }) async {
    debugPrint('[EmailService] Stub: Send email to $to, subject: $subject');
    return true;
  }

  /// Order confirmation email sent right after an order is placed.
  Future<bool> sendOrderConfirmationEmail({
    required String email,
    String? customerName,
    required String orderNumber,
    String? estimatedDeliveryDate,
    double? totalAmount,
    List<Map<String, dynamic>>? items,
  }) async {
    debugPrint('[EmailService] Stub: Order confirmation email to $email, order: $orderNumber');
    return true;
  }

  /// Order receipt / invoice email sent on delivery completion.
  Future<bool> sendOrderReceiptEmail({
    required String email,
    String? customerName,
    required String orderNumber,
    double? subtotal,
    double? deliveryCharge,
    double? discount,
    double? tax,
    double? totalAmount,
    String? paymentMethod,
    List<Map<String, dynamic>>? items,
  }) async {
    debugPrint('[EmailService] Stub: Order receipt email to $email, order: $orderNumber');
    return true;
  }

  /// Welcome email sent on new account creation.
  Future<bool> sendWelcomeEmail({required String email, String? name}) async {
    debugPrint('[EmailService] Stub: Welcome email to $email');
    return true;
  }

  /// Password-changed / security notice email.
  Future<bool> sendPasswordChangedEmail({required String email, String? name}) async {
    debugPrint('[EmailService] Stub: Password changed email to $email');
    return true;
  }

  /// New sign-in alert email.
  Future<bool> sendLoginAlertEmail({required String email, String? name, String? device}) async {
    debugPrint('[EmailService] Stub: Login alert email to $email for device: $device');
    return true;
  }

  /// Promotional / campaign email.
  Future<bool> sendPromotionalEmail({
    required String email,
    required String subject,
    String? html,
    String? text,
  }) async {
    debugPrint('[EmailService] Stub: Promotional email to $email, subject: $subject');
    return true;
  }

  /// Basic email format validation.
  static bool isValidEmail(String email) {
    if (email.trim().isEmpty) return false;
    final regex = RegExp(r'^[\w\.\-+]+@[\w\-]+\.[\w\-.]+$');
    return regex.hasMatch(email.trim());
  }
}
