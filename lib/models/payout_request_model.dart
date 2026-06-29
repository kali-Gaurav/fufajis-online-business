import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/monetary_value.dart';

/// Type of recipient an automated payout request was generated for.
enum PayoutRequestType { rider, vendor }

/// Lifecycle status of an automated payout request.
///
/// Per the standing "owner review and approval" policy, every automated
/// payout request lands as [pending] and only moves to [paid] after an
/// owner explicitly [approved] it (or stays [rejected]/[failed]).
enum PayoutRequestStatus { pending, approved, rejected, paid, failed }

/// A periodic, system-generated payout request awaiting owner review
/// (Task #53 — Automate rider/vendor payouts).
///
/// Generated weekly by the `generatePayoutRequests` scheduled Cloud
/// Function in `functions/src/automation/cronJobs.ts`, which aggregates:
///  - unpaid rider delivery earnings (sum of `deliveryCharge` on delivered
///    orders not yet attached to a payout request), and
///  - unpaid vendor dues (sum of `totalAmount * (1 - commissionPercent/100)`
///    on delivered orders for each shop).
///
/// Approval (owner action in [AutomatedPayoutsScreen]) triggers the actual
/// transfer: [RiderPayoutService.initiateInstantPayout] for riders, or a
/// vendor wallet credit + ledger entry for vendors. Nothing is paid out
/// automatically — this model only represents the *request*.
class PayoutRequestModel {
  final String id;
  final PayoutRequestType type;
  final String recipientId; // riderId or shopId
  final String recipientName;
  final MonetaryValue amount;
  final String currency;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<String> orderIds;
  final int orderCount;
  final PayoutRequestStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? notes;
  final String? transactionId;
  final String? errorMessage;

  PayoutRequestModel({
    required this.id,
    required this.type,
    required this.recipientId,
    required this.recipientName,
    required this.amount,
    this.currency = 'INR',
    required this.periodStart,
    required this.periodEnd,
    this.orderIds = const [],
    this.orderCount = 0,
    this.status = PayoutRequestStatus.pending,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
    this.notes,
    this.transactionId,
    this.errorMessage,
  });

  factory PayoutRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    return PayoutRequestModel(
      id: docId,
      type: PayoutRequestType.values.firstWhere(
        (e) => e.name == map['type'] as String?,
        orElse: () => PayoutRequestType.rider,
      ),
      recipientId: map['recipientId'] as String? ?? '',
      recipientName: map['recipientName'] as String? ?? '',
      amount: MonetaryValue(map['amount'] ?? 0.0),
      currency: map['currency'] as String? ?? 'INR',
      periodStart: (map['periodStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      periodEnd: (map['periodEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      orderIds: (map['orderIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      orderCount: (map['orderCount'] as num?)?.toInt() ?? 0,
      status: PayoutRequestStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => PayoutRequestStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      resolvedBy: map['resolvedBy'] as String?,
      notes: map['notes'] as String?,
      transactionId: map['transactionId'] as String?,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'amount': amount,
      'currency': currency,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
      'orderIds': orderIds,
      'orderCount': orderCount,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolvedBy': resolvedBy,
      'notes': notes,
      'transactionId': transactionId,
      'errorMessage': errorMessage,
    };
  }

  PayoutRequestModel copyWith({
    PayoutRequestStatus? status,
    DateTime? resolvedAt,
    String? resolvedBy,
    String? notes,
    String? transactionId,
    String? errorMessage,
  }) {
    return PayoutRequestModel(
      id: id,
      type: type,
      recipientId: recipientId,
      recipientName: recipientName,
      amount: amount,
      currency: currency,
      periodStart: periodStart,
      periodEnd: periodEnd,
      orderIds: orderIds,
      orderCount: orderCount,
      status: status ?? this.status,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      notes: notes ?? this.notes,
      transactionId: transactionId ?? this.transactionId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
