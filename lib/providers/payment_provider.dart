import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';

class PaymentProvider with ChangeNotifier {
  late Razorpay _razorpay;
  bool _isProcessing = false;
  String? _errorMessage;

  // Callback functions
  Function(PaymentSuccessResponse)? onPaymentSuccess;
  Function(PaymentFailureResponse)? onPaymentError;
  Function(ExternalWalletResponse)? onExternalWallet;

  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;

  PaymentProvider() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void startRazorpayPayment({
    required double amount,
    required String orderId,
    required UserModel user,
    String description = "Fufaji's Online Order",
  }) {
    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    var options = {
      'key': 'rzp_live_Sr7JfZt4NbXzMw', // Use live key from .env
      'amount': (amount * 100).toInt(), // Amount in paise
      'name': "Fufaji's Online",
      'description': description,
      'order_id': orderId,
      'prefill': {
        'contact': user.phoneNumber,
        'email': user.email ?? 'customer@fufaji.com',
      },
      'external': {
        'wallets': ['paytm'],
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _errorMessage = "Failed to open payment gateway: $e";
      _isProcessing = false;
      notifyListeners();
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _isProcessing = false;
    notifyListeners();
    if (onPaymentSuccess != null) onPaymentSuccess!(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _isProcessing = false;
    _errorMessage = response.message ?? "Payment failed";
    notifyListeners();
    if (onPaymentError != null) onPaymentError!(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _isProcessing = false;
    notifyListeners();
    if (onExternalWallet != null) onExternalWallet!(response);
  }

  // Handle Khata/Credit Logic
  Future<bool> processCreditPayment(
    double amount,
    UserModel user,
    AuthProvider auth,
  ) async {
    if (user.creditBalance + amount > user.creditLimit) {
      _errorMessage =
          "Credit limit exceeded. Current: ₹${user.creditBalance.round()} / Limit: ₹${user.creditLimit.round()}";
      notifyListeners();
      return false;
    }

    try {
      await auth.updateCreditBalance(amount);
      return true;
    } catch (e) {
      _errorMessage = "Khata update failed: $e";
      return false;
    }
  }
}
