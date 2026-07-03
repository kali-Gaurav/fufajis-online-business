/// error_handler.dart - User-Friendly Error Messages
/// Converts backend error codes to customer-facing messages
///
/// Usage:
/// String message = getUserFriendlyError(errorCode, originalMessage);
library;

import 'package:flutter/foundation.dart';

class ErrorHandler {
  // Define error codes used across the app
  static const String rateLimited = 'rate_limited';
  static const String rateLimitedSevere = 'rate_limited_severe';
  static const String invalidOtp = 'invalid_otp';
  static const String otpExpired = 'otp_expired';
  static const String otpSendFailed = 'otp_send_failed';
  static const String invalidPhone = 'invalid_phone';
  static const String invalidPin = 'invalid_pin';
  static const String pinLocked = 'pin_locked';
  static const String totpInvalid = 'totp_invalid';
  static const String paymentFailed = 'payment_failed';
  static const String paymentCancelled = 'payment_cancelled';
  static const String outOfStock = 'out_of_stock';
  static const String networkError = 'network_error';
  static const String serverError = 'server_error';
  static const String unauthorized = 'unauthorized';
  static const String forbidden = 'forbidden';
  static const String notFound = 'not_found';
  static const String invalidInput = 'invalid_input';
  static const String verificationFailed = 'verification_failed';
  static const String sessionExpired = 'session_expired';
  static const String deviceNotSupported = 'device_not_supported';

  /// Convert backend error code to user-friendly message (Hindi + English)
  ///
  /// [errorCode]: Error code from backend (e.g., 'rate_limited')
  /// [originalMessage]: Original error message for logging/debugging
  /// [useHindi]: If true, return Hindi message; otherwise English
  static String getUserFriendlyError(
    String errorCode, {
    String? originalMessage,
    bool useHindi = false,
  }) {
    debugPrint('[ErrorHandler] Code: $errorCode, Original: $originalMessage');

    final messages = useHindi ? _hindiMessages : _englishMessages;
    return messages[errorCode] ??
        (useHindi
            ? _defaultHindiMessage(originalMessage)
            : _defaultEnglishMessage(originalMessage));
  }

  /// English error messages
  static const Map<String, String> _englishMessages = {
    rateLimited: 'Too many requests. Please wait a few minutes before trying again.',
    rateLimitedSevere:
        'Your account has been temporarily locked due to too many attempts. Please contact support.',
    invalidOtp: 'Incorrect OTP. Please check and try again.',
    otpExpired: 'OTP has expired. Please request a new one.',
    otpSendFailed: 'Failed to send OTP. Please check your phone number and try again.',
    invalidPhone: 'Invalid phone number format. Please enter a valid number.',
    invalidPin: 'Invalid PIN. Please check and try again.',
    pinLocked: 'Too many failed PIN attempts. Your account is locked for 30 minutes.',
    totpInvalid: 'Invalid authentication code. Please check and try again.',
    paymentFailed: 'Payment failed. Please try another payment method or contact support.',
    paymentCancelled: 'Payment was cancelled. Please try again.',
    outOfStock: 'This item is currently out of stock. Please try again later.',
    networkError: 'Network connection failed. Please check your internet.',
    serverError: 'Server error. Our team is working on it. Please try again later.',
    unauthorized: 'Unauthorized. Please log in again and try your action again.',
    forbidden: 'You do not have permission to perform this action.',
    notFound: 'The requested item was not found.',
    invalidInput: 'Invalid input. Please check your information and try again.',
    verificationFailed: 'Verification failed. Please try again.',
    sessionExpired: 'Your session has expired. Please log in again.',
    deviceNotSupported: 'Your device is not supported. Please update your app.',
  };

  /// Hindi error messages (हिंदी)
  static const Map<String, String> _hindiMessages = {
    rateLimited: 'बहुत सारे अनुरोध किए जा रहे हैं। कृपया कुछ मिनट प्रतीक्षा करें।',
    rateLimitedSevere: 'बहुत सारे असफल प्रयासों के कारण आपका खाता अस्थायी रूप से बंद हो गया है।',
    invalidOtp: 'गलत OTP। कृपया जांचकर फिर से कोशिश करें।',
    otpExpired: 'OTP की अवधि समाप्त हो गई है। नया OTP प्राप्त करें।',
    otpSendFailed: 'OTP भेजने में विफल। कृपया अपना फोन नंबर जांचें और फिर से कोशिश करें।',
    invalidPhone: 'गलत फोन नंबर प्रारूप। कृपया सही नंबर दर्ज करें।',
    invalidPin: 'गलत PIN। कृपया जांचकर फिर से कोशिश करें।',
    pinLocked: 'बहुत सारे गलत PIN प्रयास। आपका खाता 30 मिनट के लिए बंद है।',
    totpInvalid: 'गलत प्रमाणीकरण कोड। कृपया जांचकर फिर से कोशिश करें।',
    paymentFailed: 'भुगतान विफल। कृपया किसी अन्य भुगतान विधि का प्रयास करें।',
    paymentCancelled: 'भुगतान रद्द किया गया। कृपया फिर से कोशिश करें।',
    outOfStock: 'यह आइटम वर्तमान में स्टॉक में नहीं है। बाद में कोशिश करें।',
    networkError: 'इंटरनेट कनेक्शन विफल। कृपया जांचें और फिर से कोशिश करें।',
    serverError: 'सर्वर त्रुटि। कृपया बाद में कोशिश करें।',
    unauthorized: 'अनुमति नहीं है। कृपया फिर से लॉग इन करें।',
    forbidden: 'आपको यह कार्य करने की अनुमति नहीं है।',
    notFound: 'अनुरोधित आइटम नहीं मिला।',
    invalidInput: 'गलत जानकारी। कृपया जांचकर फिर से कोशिश करें।',
    verificationFailed: 'सत्यापन विफल। कृपया फिर से कोशिश करें।',
    sessionExpired: 'आपका सेशन समाप्त हो गया है। कृपया फिर से लॉग इन करें।',
    deviceNotSupported: 'आपका डिवाइस समर्थित नहीं है। कृपया ऐप अपडेट करें।',
  };

  static String _defaultEnglishMessage(String? originalMessage) {
    return originalMessage != null && originalMessage.isNotEmpty
        ? originalMessage
        : 'Something went wrong. Please try again later.';
  }

  static String _defaultHindiMessage(String? originalMessage) {
    return originalMessage != null && originalMessage.isNotEmpty
        ? originalMessage
        : 'कुछ गलत हुआ। कृपया बाद में कोशिश करें।';
  }

  /// Extract error code from various error response formats
  static String extractErrorCode(dynamic error) {
    if (error is String) {
      return error;
    }

    if (error is Map) {
      return error['error'] ?? error['errorCode'] ?? serverError;
    }

    return serverError;
  }

  /// Extract error message from various response formats
  static String? extractErrorMessage(dynamic error) {
    if (error is String) {
      return error;
    }

    if (error is Map) {
      return error['message'] ?? error['error'] ?? error['description'];
    }

    return null;
  }

  /// Handle API error response
  /// Returns formatted error message ready to show to user
  static String handleApiError(dynamic error, {bool useHindi = false, String? defaultMessage}) {
    final errorCode = extractErrorCode(error);
    final errorMessage = extractErrorMessage(error);

    return getUserFriendlyError(
      errorCode,
      originalMessage: errorMessage ?? defaultMessage,
      useHindi: useHindi,
    );
  }

  /// Log error for debugging/analytics (don't show to user)
  static void logError(String errorCode, String? message, [StackTrace? stack]) {
    debugPrint('[ERROR] Code: $errorCode');
    debugPrint('[ERROR] Message: $message');
    if (stack != null) {
      debugPrint('[ERROR] Stack: $stack');
    }

    // TODO: Send to error tracking service (Sentry, Firebase Crashlytics, etc.)
    // ErrorReporter.logError(errorCode, message, stack);
  }

  /// Determine if error is retryable
  static bool isRetryable(String errorCode) {
    const retryableErrors = [networkError, serverError, otpSendFailed, paymentFailed];
    return retryableErrors.contains(errorCode);
  }

  /// Get retry delay in milliseconds
  static int getRetryDelay(int attemptNumber) {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s (capped at 30s)
    return (1000 * (1 << attemptNumber)).clamp(1000, 30000);
  }
}

/// Extension on dynamic for convenient error handling
extension ErrorHandling on dynamic {
  String toUserFriendlyMessage({bool useHindi = false, String? defaultMessage}) {
    return ErrorHandler.handleApiError(this, useHindi: useHindi, defaultMessage: defaultMessage);
  }

  String extractError() {
    return ErrorHandler.extractErrorCode(this);
  }
}
