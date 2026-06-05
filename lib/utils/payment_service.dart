import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentService {
  late Razorpay _razorpay;
  final String razorpayKeyId;
  final Function(PaymentSuccessResponse) onSuccess;
  final Function(PaymentFailureResponse) onFailure;

  PaymentService({
    required this.razorpayKeyId,
    required this.onSuccess,
    required this.onFailure,
  }) {
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
      var options = {
        'key': razorpayKeyId,
        'amount': (amount * 100).toInt(), // Convert to paise
        'name': "Fufaji's Online",
        'description': 'Order #$orderId',
        'prefill': {
          'contact': customerPhone,
          'email': customerEmail,
        },
        'notes': {
          'order_id': orderId,
        },
        'theme': {
          'color': '#FF5722',
        },
      };
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error starting payment: $e');
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
