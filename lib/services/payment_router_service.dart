import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math' show pow;

/// Component 8 — Razorpay Route vs. Firestore Ledger Reconciliation
///
/// Payment flow decision matrix:
///   Order Value < ₹500  → UPI/COD preferred (avoid Razorpay fees)
///   Order Value ≥ ₹500  → Razorpay (cards, net banking, EMI)
///   Any failed Razorpay → Firestore Ledger + manual reconciliation queue
///
/// The ledger in Firestore (/payments/{paymentId}) is the source of truth.
/// Razorpay IDs are cross-linked for reconciliation.
///
/// Reconciliation Workflow:
///   1. On payment failure: write FAILED entry to ledger
///   2. Retry via alternate route (exponential backoff)
///   3. Fallback to wallet deduction if all retries exhausted
///   4. Nightly job marks unresolved entries for owner review
class PaymentRouterService {
  static final PaymentRouterService _instance = PaymentRouterService._internal();
  factory PaymentRouterService() => _instance;
  PaymentRouterService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Config loaded from Firestore /settings/payment_routing
  static const double _razorpayMinThreshold = 500.0;
  static const double _razorpayFeePercent = 2.0; // 2% Razorpay fee

  // Retry Configuration
  static const int _maxRetries = 3;
  static const int _initialBackoffMs = 1000; // 1 second
  static const double _backoffMultiplier = 2.0; // exponential: 1s, 2s, 4s
  @deprecated
  static String get _razorpayWebhookSecret => '';

  // ─────────────── WEBHOOK HANDLER (Razorpay) ───────────────

  /// Handles incoming Razorpay webhook events
  /// Deprecated: Webhooks must be processed exclusively on the Node.js backend.
  @deprecated
  Future<void> handleRazorpayWebhook({
    required String eventId,
    required String eventType,
    required Map<String, dynamic> payload,
    required String webhookSignature,
  }) async {
    debugPrint('[PaymentRouter] ❌ Client-side webhook handling is deprecated and disabled.');
    throw UnsupportedError('Webhook handling is disabled on the client.');
  }

  /// Validates HMAC-SHA256 signature (Razorpay webhook security)
  /// Deprecated: Webhooks must be processed exclusively on the Node.js backend.
  @deprecated
  bool _validateWebhookSignature(
    String eventId,
    String eventType,
    Map<String, dynamic> payload,
    String signature,
  ) {
    debugPrint('[PaymentRouter] ❌ Client-side signature verification is deprecated and disabled.');
    return false;
  }

  /// Async handler: Payment succeeded
  Future<void> _onPaymentSuccess(Map<String, dynamic> payload) async {
    final razorpayPaymentId = payload['payment_id'] as String?;

    if (razorpayPaymentId == null) {
      debugPrint('[PaymentRouter] ❌ Missing payment_id in success webhook');
      return;
    }

    // Update order status to confirmed
    try {
      await _firestore.runTransaction((transaction) async {
        // Find order by razorpay payment ID
        final orderQuery = await _firestore
            .collection('orders')
            .where('razorpayPaymentId', isEqualTo: razorpayPaymentId)
            .limit(1)
            .get();

        if (orderQuery.docs.isEmpty) {
          debugPrint('[PaymentRouter] Order not found for payment: $razorpayPaymentId');
          return;
        }

        final orderDoc = orderQuery.docs.first;
        final orderId = orderDoc.id;

        // Update order status
        transaction.update(orderDoc.reference, {
          'status': 'confirmed',
          'paymentStatus': 'completed',
          'razorpayPaymentId': razorpayPaymentId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update payment ledger
        final paymentId = 'rzp_$razorpayPaymentId';
        final paymentRef = _firestore.collection('payments').doc(paymentId);
        transaction.update(paymentRef, {
          'status': 'success',
          'razorpayPaymentId': razorpayPaymentId,
          'completedAt': FieldValue.serverTimestamp(),
          'needsReconciliation': false,
        });

        debugPrint('[PaymentRouter] ✅ Order $orderId confirmed via webhook');
      });
    } catch (e) {
      debugPrint('[PaymentRouter] Error processing payment success: $e');
    }
  }

  /// Async handler: Payment failed → Enqueue for retry
  Future<void> _onPaymentFailed(Map<String, dynamic> payload) async {
    final razorpayPaymentId = payload['payment_id'] as String?;
    final orderId = payload['order_id'] as String?;
    final reason = payload['description'] as String? ?? 'unknown';

    if (razorpayPaymentId == null || orderId == null) {
      debugPrint('[PaymentRouter] ❌ Missing IDs in failed webhook');
      return;
    }

    try {
      // Create retry entry
      final retryId = 'retry_${DateTime.now().millisecondsSinceEpoch}_$razorpayPaymentId';
      await _firestore.collection('payment_retry_queue').doc(retryId).set({
        'razorpayPaymentId': razorpayPaymentId,
        'orderId': orderId,
        'failureReason': reason,
        'retryCount': 0,
        'maxRetries': _maxRetries,
        'status': 'pending',
        'nextRetryAt': DateTime.now().add(const Duration(milliseconds: _initialBackoffMs)),
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[PaymentRouter] 🔄 Enqueued for retry: $retryId');
    } catch (e) {
      debugPrint('[PaymentRouter] Error handling payment failure: $e');
    }
  }

  /// Async handler: UPI payment authorized
  Future<void> _onUpiSuccess(Map<String, dynamic> payload) async {
    // Similar to _onPaymentSuccess but for UPI
    final upiTransactionId = payload['upi_transaction_id'] as String?;
    final orderId = payload['order_id'] as String?;

    if (upiTransactionId == null || orderId == null) return;

    try {
      final orderRef = _firestore.collection('orders').doc(orderId);
      await orderRef.update({
        'status': 'confirmed',
        'paymentStatus': 'completed',
        'upiTransactionId': upiTransactionId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[PaymentRouter] ✅ UPI Order $orderId confirmed');
    } catch (e) {
      debugPrint('[PaymentRouter] Error processing UPI success: $e');
    }
  }

  // ─────────────── RETRY LOGIC (Exponential Backoff) ───────────────

  /// Processes payment retries with exponential backoff
  /// Call this from a scheduled Cloud Function or timer
  Future<void> processPaymentRetries() async {
    try {
      final now = DateTime.now();
      final retries = await _firestore
          .collection('payment_retry_queue')
          .where('status', isEqualTo: 'pending')
          .where('nextRetryAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .get();

      for (final retryDoc in retries.docs) {
        final retry = retryDoc.data();
        final retryCount = (retry['retryCount'] as int?) ?? 0;
        final maxRetries = (retry['maxRetries'] as int?) ?? _maxRetries;
        final orderId = retry['orderId'] as String?;

        if (retryCount >= maxRetries) {
          // Max retries exhausted → fallback to wallet
          await _fallbackToWallet(orderId, retry);
          await retryDoc.reference.update({'status': 'wallet_fallback_applied'});
        } else {
          // Retry with exponential backoff
          final backoffMs = (_initialBackoffMs * pow(_backoffMultiplier, retryCount)).toInt();
          await retryDoc.reference.update({
            'retryCount': retryCount + 1,
            'nextRetryAt': Timestamp.fromDate(
              now.add(Duration(milliseconds: backoffMs)),
            ),
          });

          debugPrint('[PaymentRouter] 🔄 Retry #${retryCount + 1} scheduled in ${backoffMs}ms for $orderId');
        }
      }
    } catch (e) {
      debugPrint('[PaymentRouter] Error processing retries: $e');
    }
  }

  /// Fallback: Deduct payment amount from customer wallet
  Future<void> _fallbackToWallet(String? orderId, Map<String, dynamic> retry) async {
    if (orderId == null) return;

    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return;

      final order = orderDoc.data()!;
      final customerId = order['customerId'] as String?;
      final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0;

      if (customerId == null) return;

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(customerId);
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) return;

        final userData = userDoc.data()!;
        final walletBalance = (userData['walletBalance'] as num?)?.toDouble() ?? 0;

        if (walletBalance < totalAmount) {
          debugPrint('[PaymentRouter] ⚠️ Insufficient wallet balance for fallback: $customerId');
          return; // Wallet insufficient
        }

        // Deduct from wallet
        final newBalance = walletBalance - totalAmount;
        transaction.update(userRef, {
          'walletBalance': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update order as wallet-paid
        transaction.update(orderDoc.reference, {
          'status': 'confirmed',
          'paymentStatus': 'wallet_paid',
          'paymentMethod': 'wallet',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Record wallet transaction
        final txnRef = userRef.collection('wallet_transactions').doc();
        transaction.set(txnRef, {
          'type': 'payment_fallback',
          'amount': totalAmount,
          'orderReference': orderId,
          'reason': 'Payment retry failed, fallback to wallet',
          'balanceAfter': newBalance,
          'timestamp': FieldValue.serverTimestamp(),
        });

        debugPrint('[PaymentRouter] ✅ Wallet fallback applied: $customerId -₹$totalAmount');
      });
    } catch (e) {
      debugPrint('[PaymentRouter] Error applying wallet fallback: $e');
    }
  }

  // ─────────────── ROUTING DECISION ───────────────

  /// Decides the optimal payment route for a given order amount and context.
  Future<PaymentRoute> decideRoute({
    required double orderAmount,
    required String customerId,
    required List<String> availableMethods,
  }) async {
    final config = await _loadRoutingConfig();

    // Check if customer has a default preference
    final pref = await _getCustomerPreference(customerId);
    if (pref != null && availableMethods.contains(pref)) {
      return PaymentRoute(
        method: pref,
        reason: 'customer_preference',
        estimatedFee: _estimateFee(pref, orderAmount),
      );
    }

    final minThreshold = (config['razorpayMinThreshold'] as num?) ?? _razorpayMinThreshold;

    // Below threshold → prefer UPI (zero fee)
    if (orderAmount < minThreshold) {
      if (availableMethods.contains('upi')) {
        return const PaymentRoute(method: 'upi', reason: 'low_order_value', estimatedFee: 0);
      }
      if (availableMethods.contains('cod')) {
        return const PaymentRoute(method: 'cod', reason: 'low_order_value_fallback', estimatedFee: 0);
      }
    }

    // At or above threshold → prefer Razorpay for card/EMI support
    if (availableMethods.contains('razorpay')) {
      return PaymentRoute(
        method: 'razorpay',
        reason: 'high_order_value',
        estimatedFee: _estimateFee('razorpay', orderAmount),
      );
    }

    // Final fallback
    return PaymentRoute(
      method: availableMethods.isNotEmpty ? availableMethods.first : 'cod',
      reason: 'fallback',
      estimatedFee: 0,
    );
  }

  double _estimateFee(String method, double amount) {
    switch (method) {
      case 'razorpay':
        return (amount * _razorpayFeePercent / 100).roundToDouble();
      case 'upi':
      case 'cod':
      default:
        return 0;
    }
  }

  // ─────────────── FIRESTORE LEDGER WRITE ───────────────

  /// Records a payment attempt (success or failure) in the Firestore ledger.
  Future<void> recordPaymentAttempt({
    required String paymentId,
    required String orderId,
    required String customerId,
    required double amount,
    required String method,
    required PaymentLedgerStatus status,
    String? razorpayPaymentId,
    String? razorpayOrderId,
    String? failureReason,
  }) async {
    // Idempotency check: check if this payment was already recorded as success/captured
    try {
      final doc = await _firestore.collection('payments').doc(paymentId).get();
      if (doc.exists) {
        final existingStatus = doc.data()?['status']?.toString();
        if (existingStatus == 'success' || existingStatus == 'captured') {
          debugPrint('[PaymentRouter] Payment attempt $paymentId already succeeded. Skipping duplicate ledger write.');
          return;
        }
      }
    } catch (e) {
      debugPrint('[PaymentRouter] Idempotency check failed, continuing: $e');
    }

    final data = {
      'paymentId': paymentId,
      'orderId': orderId,
      'customerId': customerId,
      'amount': amount,
      'method': method,
      'status': status.name,
      'razorpayPaymentId': razorpayPaymentId ?? '',
      'razorpayOrderId': razorpayOrderId ?? '',
      'failureReason': failureReason ?? '',
      'needsReconciliation': status == PaymentLedgerStatus.failed,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('payments').doc(paymentId).set(data);
    debugPrint('[PaymentRouter] Ledger entry: $paymentId → ${status.name}');

    // If failed, add to reconciliation queue
    if (status == PaymentLedgerStatus.failed) {
      await _enqueueReconciliation(paymentId, orderId, amount, failureReason);
    }
  }

  /// Updates an existing ledger entry (e.g., after successful retry).
  Future<void> updatePaymentStatus({
    required String paymentId,
    required PaymentLedgerStatus status,
    String? razorpayPaymentId,
    String? resolvedBy,
  }) async {
    await _firestore.collection('payments').doc(paymentId).update({
      'status': status.name,
      'needsReconciliation': status == PaymentLedgerStatus.failed,
      'razorpayPaymentId': razorpayPaymentId ?? '',
      'resolvedBy': resolvedBy ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[PaymentRouter] Updated payment $paymentId → ${status.name}');
  }

  // ─────────────── RECONCILIATION QUEUE ───────────────

  Future<void> _enqueueReconciliation(
    String paymentId,
    String orderId,
    double amount,
    String? reason,
  ) async {
    final entryId = 'recon_${DateTime.now().millisecondsSinceEpoch}_$paymentId';
    await _firestore.collection('reconciliation_queue').doc(entryId).set({
      'paymentId': paymentId,
      'orderId': orderId,
      'amount': amount,
      'failureReason': reason ?? 'unknown',
      'status': 'pending',
      'retryCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[PaymentRouter] Enqueued reconciliation: $entryId');
  }

  /// Fetches all unresolved reconciliation entries (for admin dashboard).
  Future<List<Map<String, dynamic>>> getPendingReconciliations() async {
    try {
      final snap = await _firestore
          .collection('reconciliation_queue')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: false)
          .get();
      return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    } catch (e) {
      debugPrint('[PaymentRouter] Reconciliation fetch error: $e');
      return [];
    }
  }

  /// Marks a reconciliation entry as resolved by the owner.
  Future<void> resolveReconciliation(String reconId, String resolvedBy) async {
    await _firestore.collection('reconciliation_queue').doc(reconId).update({
      'status': 'resolved',
      'resolvedBy': resolvedBy,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetches payment ledger entry by payment ID.
  Future<Map<String, dynamic>?> getLedgerEntry(String paymentId) async {
    try {
      final doc = await _firestore.collection('payments').doc(paymentId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('[PaymentRouter] Ledger read error: $e');
      return null;
    }
  }

  /// Streams real-time reconciliation queue for admin panel.
  Stream<List<Map<String, dynamic>>> watchReconciliationQueue() {
    return _firestore
        .collection('reconciliation_queue')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  // ─────────────── HELPERS ───────────────

  Future<Map<String, dynamic>> _loadRoutingConfig() async {
    try {
      final doc = await _firestore
          .collection('settings')
          .doc('payment_routing')
          .get();
      return doc.exists ? doc.data()! : {};
    } catch (_) {
      return {};
    }
  }

  Future<String?> _getCustomerPreference(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['preferredPaymentMethod'] as String?;
    } catch (_) {
      return null;
    }
  }
}

// ─────────────── VALUE OBJECTS ───────────────

enum PaymentLedgerStatus { pending, success, failed, refunded, disputed }

class PaymentRoute {
  final String method;
  final String reason;
  final double estimatedFee;

  const PaymentRoute({
    required this.method,
    required this.reason,
    required this.estimatedFee,
  });

  @override
  String toString() =>
      'PaymentRoute(method=$method, reason=$reason, fee=₹$estimatedFee)';
}
