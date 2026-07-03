import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import 'api_client.dart';

/// Callback typedefs for payment events
typedef PaymentSuccessCallback = void Function(PaymentSuccessResponse response);
typedef PaymentFailureCallback = void Function(PaymentFailureResponse response);
typedef PaymentExternalWalletCallback = void Function(ExternalWalletResponse response);

/// RazorpayService with backend signature verification
/// Payments are verified via backend API (not direct Firestore writes)
/// Order status updates happen atomically in PostgreSQL + synced to Firestore
class RazorpayService {
  final Razorpay _razorpay = Razorpay();

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
    required String customerId,
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
      // Store order ID for later verification
      _lastOrderId = orderId;

      // 1. Create Order on Razorpay Backend first
      final result = await ApiClient.instance.post('/payments/razorpay/order', <String, dynamic>{
        'amount': amount,
        'orderId': orderId,
        'customerId': customerId,
        'notes': {'order_id': orderId, 'customer_id': customerId},
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['success'] != true) {
        throw Exception('Failed to create Razorpay order on backend: ${data['error']}');
      }

      final razorpayOrderId = data['razorpayOrderId'];

      // 2. Open Razorpay Checkout
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
        'notes': {'order_id': orderId, 'customer_id': customerId},
        'theme': {'color': '#FF5722'},
        'external': {
          'wallets': ['paytm'],
        },
      };

      _razorpay.open(options);
      debugPrint(
        'RazorpayService: checkout opened for order $orderId (RZP: $razorpayOrderId, Customer: $customerId)',
      );
    } catch (e) {
      debugPrint('RazorpayService: failed to initiate payment – $e');
      _onFailure?.call(PaymentFailureResponse(Razorpay.NETWORK_ERROR, e.toString(), {}));
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Internal handlers
  // ──────────────────────────────────────────────────────────────────────

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('RazorpayService: payment success – paymentId=${response.paymentId}');
    _verifyAndUpdateOrder(response);
    _onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('RazorpayService: payment error – code=${response.code} msg=${response.message}');

    // Mark the order as failed in Firestore if we can derive the orderId
    // (orderId is not available in failure response, caller must handle)
    _onFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('RazorpayService: external wallet selected – ${response.walletName}');
    _onExternalWallet?.call(response);
  }

  // ──────────────────────────────────────────────────────────────────────
  // Firebase verification & Firestore update
  // ──────────────────────────────────────────────────────────────────────

  /// Call backend API `/payments/verify` to verify signature and update order.
  /// CRITICAL: Backend verifies signature using HMAC-SHA256
  /// IDEMPOTENT: Safe to retry with same idempotency key
  Future<void> _verifyAndUpdateOrder(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId ?? '';
    final razorpayOrderId = response.orderId ?? '';
    final signature = response.signature ?? '';

    try {
      // Generate idempotency key (tied to payment ID + timestamp)
      // If client retries, backend recognizes same payment and returns cached response
      final idempotencyKey = '${_lastOrderId}_${paymentId}_verify';

      // 1. Server-side signature verification using backend
      // Backend MUST verify using HMAC-SHA256 (prevents payment fraud)
      final result = await ApiClient.instance.post('/admin/payments/verify', <String, dynamic>{
        'orderId': _lastOrderId,
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
        'expectedAmount': 0, // Caller should pass the order amount
        'idempotencyKey': idempotencyKey,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final verified = data['success'] == true;

      if (verified) {
        debugPrint(
          'RazorpayService: payment verified by backend – order ${data['orderId']} status: ${data['orderStatus']}',
        );
        // Backend has atomically:
        // 1. Verified Razorpay signature
        // 2. Updated order payment_status to 'paid'
        // 3. Updated order status to 'confirmed'
        // 4. Created audit log
        // 5. Synced to Firestore (eventually)

        await _markOrderPaid(orderId: data['orderId'] ?? _lastOrderId, paymentId: paymentId);
      } else {
        debugPrint('RazorpayService: signature verification failed – ${data['error']}');
        // Signature verification failed, mark order as failed
        await _markOrderFailed(orderId: _lastOrderId);
      }
    } catch (e) {
      debugPrint('RazorpayService: verification error – $e');
      // On network error: don't mark as paid or failed
      // Let caller decide based on error type
      // Webhook reconciliation will eventually resolve via backend
      rethrow; // Let caller handle retry logic
    }
  }

  // Store last order ID for reference
  String _lastOrderId = '';

  Future<void> _markOrderPaid({required String orderId, required String paymentId}) async {
    if (orderId.isEmpty) return;
    try {
      // CRITICAL: Backend API (/payments/razorpay/verify) already updated order status
      // DO NOT write directly to Firestore
      // Backend is authoritative, Firestore syncs eventually via Cloud Functions

      // Local logging only (for UX feedback)
      debugPrint('RazorpayService: order $orderId marked paid (backend verified)');

      // Optional: Trigger local cache refresh if needed
      // This allows Firestore listeners to update UI naturally via sync
    } catch (e) {
      debugPrint('RazorpayService: error in mark paid callback – $e');
    }
  }

  Future<void> _markOrderFailed({required String orderId}) async {
    if (orderId.isEmpty) return;
    try {
      // CRITICAL: Backend API (/payments/razorpay/verify) already updated order status to 'failed'
      // DO NOT write directly to Firestore
      // Backend is authoritative, Firestore syncs eventually via Cloud Functions

      // Local logging only (for UX feedback)
      debugPrint('RazorpayService: order $orderId marked failed (backend notified)');

      // Optional: Trigger local cache refresh if needed
      // This allows Firestore listeners to update UI naturally via sync
    } catch (e) {
      debugPrint('RazorpayService: error in mark failed callback – $e');
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
