import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/app_config.dart';
import '../models/payment_result.dart';

/// Callback typedef for payment events
typedef PaymentSuccessCallback = void Function(PaymentResult result);
typedef PaymentFailureCallback = void Function(PaymentResult result);
typedef PaymentExternalWalletCallback = void Function(String walletName);

/// Razorpay payment service for handling online payments
/// 
/// This service provides a clean interface for:
/// - Initializing Razorpay checkout
/// - Handling success, failure, and external wallet callbacks
/// - Cleaning up resources on dispose
class RazorpayService {
  final Razorpay _razorpay = Razorpay();
  PaymentSuccessCallback? _onSuccess;
  PaymentFailureCallback? _onFailure;
  PaymentExternalWalletCallback? _onExternalWallet;
  bool _isInitialized = false;

  /// Initialize the Razorpay instance with event handlers
  /// Must be called before opening checkout
  void initialize({
    required PaymentSuccessCallback onSuccess,
    required PaymentFailureCallback onFailure,
    PaymentExternalWalletCallback? onExternalWallet,
  }) {
    if (_isInitialized) {
      debugPrint('RazorpayService: Already initialized');
      return;
    }

    _onSuccess = onSuccess;
    _onFailure = onFailure;
    _onExternalWallet = onExternalWallet;

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _isInitialized = true;
    debugPrint('RazorpayService: Initialized successfully');
  }

  /// Open Razorpay checkout with order details
  /// 
  /// Parameters:
  /// - amount: Order amount in INR (will be converted to paise)
  /// - orderId: Unique order ID from your backend
  /// - customerName: Customer's name for prefill
  /// - customerEmail: Customer's email for prefill
  /// - customerPhone: Customer's phone for prefill
  /// - description: Payment description
  /// - themeColor: Custom theme color for checkout UI
  /// 
  /// Returns true if checkout opened successfully, false otherwise
  bool checkout({
    required double amount,
    required String orderId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    String description = 'Order Payment',
    Color? themeColor,
  }) {
    if (!_isInitialized) {
      debugPrint('RazorpayService: Not initialized. Call initialize() first.');
      return false;
    }

    if (AppConfig.razorpayKeyId.isEmpty) {
      debugPrint('RazorpayService: API key not configured');
      return false;
    }

    try {
      // Production Hardening: Enhanced prefill sanitation
      final String cleanPhone = _sanitizePhone(customerPhone);
      final String cleanEmail = _sanitizeEmail(customerEmail);
      final String cleanName = _sanitizeName(customerName);

      debugPrint('RazorpayService: Sanitized inputs -> Phone: $cleanPhone, Email: $cleanEmail, Name: $cleanName');

      var options = <String, dynamic>{
        'key': AppConfig.razorpayKeyId,
        'amount': (amount * 100).toInt(), // Convert to paise
        'name': "Fufaji Online",
        'description': description,
        'order_id': orderId,
        'prefill': {
          'contact': cleanPhone,
          'email': cleanEmail,
          'name': cleanName,
        },
        'notes': {
          'order_id': orderId,
        },
        'theme': {
          'color': themeColor != null
              ? '#${(themeColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}'
              : '#FF5722',
        },
      };

      _razorpay.open(options);
      debugPrint('RazorpayService: Checkout opened for order $orderId');
      return true;
    } catch (e) {
      debugPrint('RazorpayService: Error opening checkout - $e');
      return false;
    }
  }

  /// Helper to sanitize phone number for Razorpay
  String _sanitizePhone(String phone) {
    // Remove all non-digit characters
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    
    // If it starts with 91 and is 12 digits, assume it's Indian format
    if (digits.startsWith('91') && digits.length == 12) {
      return digits;
    }
    
    // If it's 10 digits, add 91 prefix
    if (digits.length == 10) {
      return '91$digits';
    }
    
    // If too short or too long, return it as is or default
    return digits.length >= 10 ? digits : '910000000000';
  }

  /// Helper to sanitize email for Razorpay
  String _sanitizeEmail(String email) {
    String clean = email.trim().toLowerCase();
    // Basic email validation regex
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(clean)) {
      return 'customer@fufajionline.com'; // Default safe email
    }
    return clean;
  }

  /// Helper to sanitize name for Razorpay
  String _sanitizeName(String name) {
    String clean = name.trim().replaceAll(RegExp(r'[^\w\s]'), '');
    return clean.isEmpty ? 'Valued Customer' : clean;
  }

  /// Open checkout with a pre-created order from backend
  /// This is the recommended approach for production
  bool checkoutWithOrder({
    required String orderId,
    required double amount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    String description = 'Order Payment',
  }) {
    return checkout(
      amount: amount,
      orderId: orderId,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      description: description,
    );
  }

  /// Handle successful payment
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('RazorpayService: Payment success - ${response.paymentId}');

    final result = PaymentResult.success(
      paymentId: response.paymentId ?? '',
      orderId: response.orderId,
      signature: response.signature,
    );

    _onSuccess?.call(result);
  }

  /// Handle payment failure
  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('RazorpayService: Payment failed - ${response.code}: ${response.message}');

    final result = PaymentResult.failed(
      errorCode: response.code.toString(),
      errorMessage: response.message ?? 'Payment failed',
    );

    _onFailure?.call(result);
  }

  /// Handle external wallet selection
  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('RazorpayService: External wallet selected - ${response.walletName}');

    _onExternalWallet?.call(response.walletName ?? '');
  }

  /// Re-attach event handlers (useful after app resume)
  void reattachHandlers() {
    if (!_isInitialized) return;

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  /// Clear the Razorpay instance and release resources
  /// Call this in dispose() of your widget
  void dispose() {
    _razorpay.clear();
    _onSuccess = null;
    _onFailure = null;
    _onExternalWallet = null;
    _isInitialized = false;
    debugPrint('RazorpayService: Disposed');
  }

  /// Check if Razorpay is properly configured
  bool get isConfigured => AppConfig.razorpayKeyId.isNotEmpty;

  /// Get the current API key (masked for security)
  String get maskedKeyId {
    final key = AppConfig.razorpayKeyId;
    if (key.length <= 8) return '****';
    return '${key.substring(0, 4)}****${key.substring(key.length - 4)}';
  }
}

/// Extension to get human-readable error message
extension PaymentErrorExtension on PaymentFailureResponse {
  /// Get user-friendly error message
  String get userFriendlyMessage {
    switch (code) {
      case Razorpay.NETWORK_ERROR:
        return 'Network error. Please check your connection and try again.';
      case Razorpay.INVALID_OPTIONS:
        return 'Invalid payment configuration. Please contact support.';
      case Razorpay.PAYMENT_CANCELLED:
        return 'Payment was cancelled.';
      case Razorpay.TLS_ERROR:
        return 'Security error. Please try again or use a different payment method.';
      default:
        return message ?? 'Payment failed. Please try again.';
    }
  }
}
