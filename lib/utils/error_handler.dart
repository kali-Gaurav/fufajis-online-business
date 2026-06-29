/// error_handler.dart - User-Friendly Error Messages
/// Converts backend error codes to customer-facing messages
///
/// Usage:
/// String message = getUserFriendlyError(errorCode, originalMessage);
library;

import 'package:flutter/foundation.dart';

class ErrorHandler {
  // Define error codes used across the app
  static const String RATE_LIMITED = 'rate_limited';
  static const String RATE_LIMITED_SEVERE = 'rate_limited_severe';
  static const String INVALID_OTP = 'invalid_otp';
  static const String OTP_EXPIRED = 'otp_expired';
  static const String OTP_SEND_FAILED = 'otp_send_failed';
  static const String INVALID_PHONE = 'invalid_phone';
  static const String INVALID_PIN = 'invalid_pin';
  static const String PIN_LOCKED = 'pin_locked';
  static const String TOTP_INVALID = 'totp_invalid';
  static const String PAYMENT_FAILED = 'payment_failed';
  static const String PAYMENT_CANCELLED = 'payment_cancelled';
  static const String OUT_OF_STOCK = 'out_of_stock';
  static const String NETWORK_ERROR = 'network_error';
  static const String SERVER_ERROR = 'server_error';
  static const String UNAUTHORIZED = 'unauthorized';
  static const String FORBIDDEN = 'forbidden';
  static const String NOT_FOUND = 'not_found';
  static const String INVALID_INPUT = 'invalid_input';
  static const String VERIFICATION_FAILED = 'verification_failed';
  static const String SESSION_EXPIRED = 'session_expired';
  static const String DEVICE_NOT_SUPPORTED = 'device_not_supported';

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
    debugPrint(
      '[ErrorHandler] Code: $errorCode, Original: $originalMessage',
    );

    final messages = useHindi ? _hindiMessages : _englishMessages;
    return messages[errorCode] ??
        (useHindi
            ? _defaultHindiMessage(originalMessage)
            : _defaultEnglishMessage(originalMessage));
  }

  /// English error messages
  static const Map<String, String> _englishMessages = {
    RATE_LIMITED:
        'Too many requests. Please wait a few minutes before trying again.',
    RATE_LIMITED_SEVERE:
        'Your account has been temporarily locked due to too many attempts. Please contact support.',
    INVALID_OTP: 'Incorrect OTP. Please check and try again.',
    OTP_EXPIRED: 'OTP has expired. Please request a new one.',
    OTP_SEND_FAILED:
        'Failed to send OTP. Please check your phone number and try again.',
    INVALID_PHONE: 'Invalid phone number format. Please enter a valid number.',
    INVALID_PIN: 'Invalid PIN. Please check and try again.',
    PIN_LOCKED:
        'Too many failed PIN attempts. Your account is locked for 30 minutes.',
    TOTP_INVALID: 'Invalid authentication code. Please check and try again.',
    PAYMENT_FAILED:
        'Payment failed. Please try another payment method or contact support.',
    PAYMENT_CANCELLED: 'Payment was cancelled. Please try again.',
    OUT_OF_STOCK: 'This item is currently out of stock. Please try again later.',
    NETWORK_ERROR: 'Network connection failed. Please check your internet.',
    SERVER_ERROR:
        'Server error. Our team is working on it. Please try again later.',
    UNAUTHORIZED:
        'Unauthorized. Please log in again and try your action again.',
    FORBIDDEN: 'You do not have permission to perform this action.',
    NOT_FOUND: 'The requested item was not found.',
    INVALID_INPUT: 'Invalid input. Please check your information and try again.',
    VERIFICATION_FAILED: 'Verification failed. Please try again.',
    SESSION_EXPIRED: 'Your session has expired. Please log in again.',
    DEVICE_NOT_SUPPORTED:
        'Your device is not supported. Please update your app.',
  };

  /// Hindi error messages (हिंदी)
  static const Map<String, String> _hindiMessages = {
    RATE_LIMITED: 'बहुत सारे अनुरोध किए जा रहे हैं। कृपया कुछ मिनट प्रतीक्षा करें।',
    RATE_LIMITED_SEVERE:
        'बहुत सारे असफल प्रयासों के कारण आपका खाता अस्थायी रूप से बंद हो गया है।',
    INVALID_OTP: 'गलत OTP। कृपया जांचकर फिर से कोशिश करें।',
    OTP_EXPIRED: 'OTP की अवधि समाप्त हो गई है। नया OTP प्राप्त करें।',
    OTP_SEND_FAILED:
        'OTP भेजने में विफल। कृपया अपना फोन नंबर जांचें और फिर से कोशिश करें।',
    INVALID_PHONE:
        'गलत फोन नंबर प्रारूप। कृपया सही नंबर दर्ज करें।',
    INVALID_PIN: 'गलत PIN। कृपया जांचकर फिर से कोशिश करें।',
    PIN_LOCKED:
        'बहुत सारे गलत PIN प्रयास। आपका खाता 30 मिनट के लिए बंद है।',
    TOTP_INVALID: 'गलत प्रमाणीकरण कोड। कृपया जांचकर फिर से कोशिश करें।',
    PAYMENT_FAILED:
        'भुगतान विफल। कृपया किसी अन्य भुगतान विधि का प्रयास करें।',
    PAYMENT_CANCELLED: 'भुगतान रद्द किया गया। कृपया फिर से कोशिश करें।',
    OUT_OF_STOCK:
        'यह आइटम वर्तमान में स्टॉक में नहीं है। बाद में कोशिश करें।',
    NETWORK_ERROR: 'इंटरनेट कनेक्शन विफल। कृपया जांचें और फिर से कोशिश करें।',
    SERVER_ERROR:
        'सर्वर त्रुटि। कृपया बाद में कोशिश करें।',
    UNAUTHORIZED:
        'अनुमति नहीं है। कृपया फिर से लॉग इन करें।',
    FORBIDDEN:
        'आपको यह कार्य करने की अनुमति नहीं है।',
    NOT_FOUND: 'अनुरोधित आइटम नहीं मिला।',
    INVALID_INPUT:
        'गलत जानकारी। कृपया जांचकर फिर से कोशिश करें।',
    VERIFICATION_FAILED: 'सत्यापन विफल। कृपया फिर से कोशिश करें।',
    SESSION_EXPIRED:
        'आपका सेशन समाप्त हो गया है। कृपया फिर से लॉग इन करें।',
    DEVICE_NOT_SUPPORTED:
        'आपका डिवाइस समर्थित नहीं है। कृपया ऐप अपडेट करें।',
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
      return error['error'] ?? error['errorCode'] ?? SERVER_ERROR;
    }

    return SERVER_ERROR;
  }

  /// Extract error message from various response formats
  static String? extractErrorMessage(dynamic error) {
    if (error is String) {
      return error;
    }

    if (error is Map) {
      return error['message'] ??
          error['error'] ??
          error['description'];
    }

    return null;
  }

  /// Handle API error response
  /// Returns formatted error message ready to show to user
  static String handleApiError(
    dynamic error, {
    bool useHindi = false,
    String? defaultMessage,
  }) {
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
    const retryableErrors = [
      NETWORK_ERROR,
      SERVER_ERROR,
      OTP_SEND_FAILED,
      PAYMENT_FAILED,
    ];
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
  String toUserFriendlyMessage({
    bool useHindi = false,
    String? defaultMessage,
  }) {
    return ErrorHandler.handleApiError(
      this,
      useHindi: useHindi,
      defaultMessage: defaultMessage,
    );
  }

  String extractError() {
    return ErrorHandler.extractErrorCode(this);
  }
}
