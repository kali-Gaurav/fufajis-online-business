import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../models/cod_settlement_model.dart';
import '../models/payment_method.dart';
import '../constants/order_status.dart';

/// Result of a COD eligibility/capacity check.
class CodLimitCheckResult {
  final bool allowed;
  final double currentExposure;
  final double limit;
  final double afterAmount;
  final String? message;

  const CodLimitCheckResult({
    required this.allowed,
    required this.currentExposure,
    required this.limit,
    required this.afterAmount,
    this.message,
  });

  double get remaining => (limit - currentExposure).clamp(0, limit);
}

/// Task #51 — Enforce COD limits per vendor/rider.
///
/// Two distinct limits are enforced:
///  1. Per-customer COD order limit ([UserModel.codLimit]) — caps the total
///     value of a customer's *outstanding* (not yet delivered/settled) COD
///     orders. Checked at checkout time before a COD order is placed.
///  2. Per-rider COD cash-in-hand limit ([UserModel.maxCashInHand]) — caps
///     the amount of collected-but-unsettled COD cash a delivery agent may
///     hold before new COD deliveries should be withheld from them.
///
/// Both checks mirror the existing aggregation patterns already used in
/// `delivery_earnings_screen.dart` (cashInHand = codCollected - approvedSettlements)
/// so results stay consistent with what riders/owners already see.
class CodLimitService {
  final FirebaseFirestore _firestore;

  CodLimitService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // Order statuses that no longer count toward a customer's outstanding
  // COD exposure (money has either been collected/settled or the order
  // will never be fulfilled).
  static const Set<OrderStatus> _settledOrTerminalStatuses = {
    OrderStatus.delivered,
    OrderStatus.cancelled,
    OrderStatus.returned,
    OrderStatus.refunded,
  };

  /// Sum of `totalAmount` across this customer's COD orders that are not
  /// yet delivered/cancelled/returned/refunded — i.e. money the business is
  /// still "exposed" to for this customer.
  Future<double> getCustomerCodExposure(String customerId) async {
    final snap = await _firestore
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .where('paymentMethod', isEqualTo: PaymentMethod.cod.toString())
        .get();

    double exposure = 0.0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final statusStr = data['status'] as String?;
      final status = OrderStatus.values.firstWhere(
        (e) => e.toString() == statusStr,
        orElse: () => OrderStatus.pending,
      );
      if (_settledOrTerminalStatuses.contains(status)) continue;
      exposure += (data['totalAmount'] as num? ?? 0).toDouble();
    }
    return exposure;
  }

  /// Checks whether [customer] can place a new COD order of [orderAmount].
  ///
  /// Compares (current outstanding COD exposure + orderAmount) against
  /// `customer.codLimit`. Returns a [CodLimitCheckResult] describing the
  /// outcome so the UI can show a clear, actionable message.
  Future<CodLimitCheckResult> canPlaceCodOrder(UserModel customer, double orderAmount) async {
    final exposure = await getCustomerCodExposure(customer.id);
    final after = exposure + orderAmount;
    final limit = customer.codLimit;

    if (after > limit) {
      return CodLimitCheckResult(
        allowed: false,
        currentExposure: exposure,
        limit: limit,
        afterAmount: after,
        message:
            'This order would take your Cash on Delivery balance to ₹${after.toStringAsFixed(0)}, '
            'which is above your COD limit of ₹${limit.toStringAsFixed(0)}. '
            'Please pay online, or clear pending COD orders first.',
      );
    }

    return CodLimitCheckResult(
      allowed: true,
      currentExposure: exposure,
      limit: limit,
      afterAmount: after,
    );
  }

  /// Total COD cash a rider has collected (delivered COD orders) minus any
  /// settlements already approved — i.e. cash they are currently holding.
  /// Mirrors the calculation in `delivery_earnings_screen.dart`.
  Future<double> getRiderCashInHand(String riderId) async {
    final ordersSnap = await _firestore
        .collection('orders')
        .where('deliveryAgentId', isEqualTo: riderId)
        .where('paymentMethod', isEqualTo: PaymentMethod.cod.toString())
        .where('status', isEqualTo: OrderStatus.delivered.toString())
        .get();

    double codCollected = 0.0;
    for (final doc in ordersSnap.docs) {
      codCollected += (doc.data()['totalAmount'] as num? ?? 0).toDouble();
    }

    final settlementsSnap = await _firestore
        .collection('cod_settlements')
        .where('riderId', isEqualTo: riderId)
        .get();

    double approvedSettlements = 0.0;
    for (final doc in settlementsSnap.docs) {
      final s = CodSettlementModel.fromMap({...doc.data(), 'id': doc.id});
      if (s.status == 'approved') {
        approvedSettlements += s.amount;
      }
    }

    return codCollected - approvedSettlements;
  }

  /// Checks whether [rider] has enough remaining cash-in-hand capacity to
  /// take on another COD delivery worth [codAmount].
  Future<CodLimitCheckResult> canAssignCodTask(UserModel rider, double codAmount) async {
    final cashInHand = await getRiderCashInHand(rider.id);
    final after = cashInHand + codAmount;
    final limit = rider.maxCashInHand;

    if (after > limit) {
      return CodLimitCheckResult(
        allowed: false,
        currentExposure: cashInHand,
        limit: limit,
        afterAmount: after,
        message:
            '${rider.name ?? 'This rider'} is holding ₹${cashInHand.toStringAsFixed(0)} in COD cash '
            '(limit ₹${limit.toStringAsFixed(0)}). Assigning this ₹${codAmount.toStringAsFixed(0)} COD '
            'delivery would exceed their cash-in-hand limit — settle their cash first or '
            'assign a different rider.',
      );
    }

    return CodLimitCheckResult(
      allowed: true,
      currentExposure: cashInHand,
      limit: limit,
      afterAmount: after,
    );
  }
}
