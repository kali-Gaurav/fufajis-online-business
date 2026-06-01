import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
///   2. Retry via alternate route
///   3. Nightly job marks unresolved entries for owner review
class PaymentRouterService {
  static final PaymentRouterService _instance = PaymentRouterService._internal();
  factory PaymentRouterService() => _instance;
  PaymentRouterService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Config loaded from Firestore /settings/payment_routing
  static const double _razorpayMinThreshold = 500.0;
  static const double _razorpayFeePercent = 2.0; // 2% Razorpay fee

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

    final minThreshold = config['razorpayMinThreshold'] ?? _razorpayMinThreshold;

    // Below threshold → prefer UPI (zero fee)
    if (orderAmount < minThreshold) {
      if (availableMethods.contains('upi')) {
        return PaymentRoute(method: 'upi', reason: 'low_order_value', estimatedFee: 0);
      }
      if (availableMethods.contains('cod')) {
        return PaymentRoute(method: 'cod', reason: 'low_order_value_fallback', estimatedFee: 0);
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
