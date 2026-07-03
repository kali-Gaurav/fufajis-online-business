import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentService {
  late Razorpay _razorpay;
  final String razorpayKeyId;
  final Function(PaymentSuccessResponse) onSuccess;
  final Function(PaymentFailureResponse) onFailure;

  PaymentService({required this.razorpayKeyId, required this.onSuccess, required this.onFailure}) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onFailure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Handle external wallet
  }

  void processPayment({
    required double amount,
    required String orderId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
  }) {
    try {
      // Validate inputs
      if (amount <= 0) {
        throw Exception('Amount must be greater than 0');
      }
      if (orderId.isEmpty) {
        throw Exception('Order ID cannot be empty');
      }
      if (customerPhone.isEmpty || customerPhone.length < 10) {
        throw Exception('Valid phone number required');
      }

      var options = {
        'key': razorpayKeyId,
        'amount': (amount * 100).toInt(), // Convert to paise
        'currency': 'INR',
        'receipt': orderId, // Store orderId as receipt for webhook reconciliation
        'name': "Fufaji's Online",
        'description': 'Order #$orderId',
        'prefill': {
          'contact': customerPhone,
          'email': customerEmail.isEmpty ? 'customer@fufaji.com' : customerEmail,
          'name': customerName.isEmpty ? 'Customer' : customerName,
        },
        'notes': {'order_id': orderId, 'customer_name': customerName},
        'theme': {'color': '#FF5722'},
      };
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error starting payment: $e');
      rethrow;
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}

// Extension to handle Razorpay response types
extension on Razorpay {
  static const String EVENT_PAYMENT_SUCCESS = 'payment.success';
  static const String EVENT_PAYMENT_ERROR = 'payment.error';
  static const String EVENT_EXTERNAL_WALLET = 'payment.external_wallet';
}
