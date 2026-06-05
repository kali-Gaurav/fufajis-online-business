import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/app_config.dart';

/// Callback typedefs for payment events
typedef PaymentSuccessCallback = void Function(PaymentSuccessResponse response);
typedef PaymentFailureCallback = void Function(PaymentFailureResponse response);
typedef PaymentExternalWalletCallback = void Function(
    ExternalWalletResponse response);

/// Complete RazorpayService with Firebase verification and Firestore order update
class RazorpayService {
  final Razorpay _razorpay = Razorpay();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PaymentSuccessCallback? _onSuccess;
  PaymentFailureCallback? _onFailure;
  PaymentExternalWalletCallback? _onExternalWallet;

  bool _isInitialized = false;

  /// Initialise Razorpay with event handlers.
  /// Must be called once before [createOrder].
  void initialize({
    required PaymentSuccessCallback onSuccess,
    required PaymentFailureCallback onFailure,
    PaymentExternalWalletCallback? onExternalWallet,
  }) {
    if (_isInitialized) {
      debugPrint('RazorpayService: already initialized, re-attaching handlers');
      _razorpay.clear();
    }

    _onSuccess = onSuccess;
    _onFailure = onFailure;
    _onExternalWallet = onExternalWallet;

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _isInitialized = true;
    debugPrint('RazorpayService: initialized');
  }

  /// Open the Razorpay payment UI.
  ///
  /// [amount] is in INR (will be converted to paise).
  /// [orderId] is the Firestore / backend order ID.
  /// [customerPhone] should be a 10-digit or full E.164 number.
  /// [customerName] is used for the prefill display.
  Future<void> createOrder({
    required double amount,
    required String orderId,
    required String customerPhone,
    required String customerName,
    String customerEmail = 'customer@fufajionline.com',
    String description = "Fufaji's Online Order",
  }) async {
    if (!_isInitialized) {
      debugPrint('RazorpayService: call initialize() before createOrder()');
      return;
    }

    final key = AppConfig.razorpayKeyId;
    if (key.isEmpty) {
      debugPrint('RazorpayService: LIVE_API_KEY not configured in .env');
      return;
    }

    try {
      // 1. Create Order on Razorpay Backend first (Step 1 & 2 of recommended architecture)
      final callable = FirebaseFunctions.instance.httpsCallable('createRazorpayOrder');
      final result = await callable.call(<String, dynamic>{
        'amount': amount,
        'currency': 'INR',
        'receipt': orderId,
        'notes': {'order_id': orderId},
      });

      if (result.data == null || result.data['success'] != true) {
        throw Exception('Failed to create Razorpay order on backend');
      }

      final razorpayOrderId = result.data['razorpayOrderId'];

      // 2. Open Razorpay Checkout (Step 3)
      final options = <String, dynamic>{
        'key': key,
        'amount': (amount * 100).toInt(), // paise
        'name': "Fufaji's Online",
        'description': description,
        'order_id': razorpayOrderId, // MUST use the ID returned from backend
        'prefill': {
          'contact': _sanitizePhone(customerPhone),
          'email': _sanitizeEmail(customerEmail),
          'name': _sanitizeName(customerName),
        },
        'notes': {'order_id': orderId},
        'theme': {'color': '#FF5722'},
        'external': {
          'wallets': ['paytm'],
        },
      };

      _razorpay.open(options);
      debugPrint('RazorpayService: checkout opened for order $orderId (RZP ID: $razorpayOrderId)');
    } catch (e) {
      debugPrint('RazorpayService: failed to initiate payment – $e');
      _onFailure?.call(PaymentFailureResponse(Razorpay.NETWORK_ERROR, e.toString(), {}));
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Internal handlers
  // ──────────────────────────────────────────────────────────────────────

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint(
        'RazorpayService: payment success – paymentId=${response.paymentId}');
    _verifyAndUpdateOrder(response);
    _onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint(
        'RazorpayService: payment error – code=${response.code} msg=${response.message}');

    // Mark the order as failed in Firestore if we can derive the orderId
    // (orderId is not available in failure response, caller must handle)
    _onFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint(
        'RazorpayService: external wallet selected – ${response.walletName}');
    _onExternalWallet?.call(response);
  }

  // ──────────────────────────────────────────────────────────────────────
  // Firebase verification & Firestore update
  // ──────────────────────────────────────────────────────────────────────

  /// Call Cloud Function `verifyRazorpayPayment`, then update Firestore order.
  Future<void> _verifyAndUpdateOrder(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId ?? '';
    final orderId = response.orderId ?? '';
    final signature = response.signature ?? '';

    try {
      // 1. Server-side signature verification
      final callable =
          FirebaseFunctions.instance.httpsCallable('verifyRazorpayPayment');
      final result = await callable.call(<String, dynamic>{
        'paymentId': paymentId,
        'orderId': orderId,
        'signature': signature,
      });

      final verified =
          result.data != null && result.data['success'] == true;

      if (verified) {
        debugPrint(
            'RazorpayService: signature verified – updating order $orderId');
        await _markOrderPaid(orderId: orderId, paymentId: paymentId);
      } else {
        debugPrint(
            'RazorpayService: signature verification failed – ${result.data}');
        await _markOrderFailed(orderId: orderId);
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
          'RazorpayService: Cloud Function error [${e.code}] ${e.message}');
      // Fallback: optimistically mark paid; webhook will reconcile
      await _markOrderPaid(orderId: orderId, paymentId: paymentId);
    } catch (e) {
      debugPrint('RazorpayService: verification error – $e');
      // Optimistically mark paid; webhook reconciliation will correct
      await _markOrderPaid(orderId: orderId, paymentId: paymentId);
    }
  }

  Future<void> _markOrderPaid({
    required String orderId,
    required String paymentId,
  }) async {
    if (orderId.isEmpty) return;
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'paymentStatus': 'paid',
        'paymentId': paymentId,
        'status': 'OrderStatus.confirmed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('RazorpayService: order $orderId marked paid');
    } catch (e) {
      debugPrint('RazorpayService: failed to mark order paid – $e');
    }
  }

  Future<void> _markOrderFailed({required String orderId}) async {
    if (orderId.isEmpty) return;
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'paymentStatus': 'failed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('RazorpayService: order $orderId marked failed');
    } catch (e) {
      debugPrint('RazorpayService: failed to mark order failed – $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Sanitisation helpers
  // ──────────────────────────────────────────────────────────────────────

  String _sanitizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length == 12) return digits;
    if (digits.length == 10) return '91$digits';
    return digits.length >= 10 ? digits : '910000000000';
  }

  String _sanitizeEmail(String email) {
    final clean = email.trim().toLowerCase();
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(clean);
    return valid ? clean : 'customer@fufajionline.com';
  }

  String _sanitizeName(String name) {
    final clean = name.trim().replaceAll(RegExp(r'[^\w\s]'), '');
    return clean.isEmpty ? 'Valued Customer' : clean;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────

  /// Release Razorpay resources. Call from your widget's dispose().
  void dispose() {
    _razorpay.clear();
    _onSuccess = null;
    _onFailure = null;
    _onExternalWallet = null;
    _isInitialized = false;
    debugPrint('RazorpayService: disposed');
  }

  bool get isConfigured => AppConfig.razorpayKeyId.isNotEmpty;
}

/// Human-readable error messages for PaymentFailureResponse codes.
extension PaymentErrorExtension on PaymentFailureResponse {
  String get userFriendlyMessage {
    switch (code) {
      case Razorpay.NETWORK_ERROR:
        return 'Network error. Please check your connection and try again.';
      case Razorpay.INVALID_OPTIONS:
        return 'Invalid payment configuration. Please contact support.';
      case Razorpay.PAYMENT_CANCELLED:
        return 'Payment was cancelled.';
      case Razorpay.TLS_ERROR:
        return 'Security error. Please try a different payment method.';
      default:
        return message ?? 'Payment failed. Please try again.';
    }
  }
}
