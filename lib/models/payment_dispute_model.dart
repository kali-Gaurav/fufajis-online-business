import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a payment dispute / chargeback raised by the payment gateway
/// (Razorpay `payment.dispute.*` webhook events).
enum DisputeStatus {
  open,
  underReview,
  evidenceSubmitted,
  won,
  lost,
  closed,
}

extension DisputeStatusX on DisputeStatus {
  String get label {
    switch (this) {
      case DisputeStatus.open:
        return 'Open';
      case DisputeStatus.underReview:
        return 'Under Review';
      case DisputeStatus.evidenceSubmitted:
        return 'Evidence Submitted';
      case DisputeStatus.won:
        return 'Won';
      case DisputeStatus.lost:
        return 'Lost';
      case DisputeStatus.closed:
        return 'Closed';
    }
  }

  static DisputeStatus fromString(String raw) {
    final v = raw.split('.').last;
    switch (v) {
      case 'underReview':
      case 'under_review':
        return DisputeStatus.underReview;
      case 'evidenceSubmitted':
      case 'evidence_submitted':
        return DisputeStatus.evidenceSubmitted;
      case 'won':
        return DisputeStatus.won;
      case 'lost':
        return DisputeStatus.lost;
      case 'closed':
        return DisputeStatus.closed;
      case 'open':
      default:
        return DisputeStatus.open;
    }
  }
}

/// A payment dispute / chargeback raised against a captured payment.
///
/// Created/updated by the `razorpayWebhook` Cloud Function when it receives
/// `payment.dispute.created` / `.under_review` / `.won` / `.lost` / `.closed`
/// events (Task #50). Owners respond from the Dispute Management screen by
/// uploading evidence and tracking the gateway's resolution.
class PaymentDispute {
  final String id; // Razorpay dispute id (dsp_...)
  final String paymentId;
  final String? orderId;
  final String? orderNumber;
  final String? customerId;
  final double amount; // disputed amount in rupees
  final String currency;
  final String reasonCode;
  final String reasonDescription;
  final DisputeStatus status;
  final DateTime? respondBy; // gateway deadline to submit evidence
  final List<String> evidenceUrls;
  final String? evidenceNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final String? gatewayPhase; // raw Razorpay 'phase' field for audit

  const PaymentDispute({
    required this.id,
    required this.paymentId,
    this.orderId,
    this.orderNumber,
    this.customerId,
    required this.amount,
    this.currency = 'INR',
    this.reasonCode = '',
    this.reasonDescription = '',
    this.status = DisputeStatus.open,
    this.respondBy,
    this.evidenceUrls = const [],
    this.evidenceNotes,
    required this.createdAt,
    this.updatedAt,
    this.resolvedAt,
    this.gatewayPhase,
  });

  factory PaymentDispute.fromMap(Map<String, dynamic> map, String id) {
    DateTime? toDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return PaymentDispute(
      id: id,
      paymentId: map['paymentId'] as String? ?? '',
      orderId: map['orderId'] as String?,
      orderNumber: map['orderNumber'] as String?,
      customerId: map['customerId'] as String?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'INR',
      reasonCode: map['reasonCode'] as String? ?? '',
      reasonDescription: map['reasonDescription'] as String? ?? '',
      status: DisputeStatusX.fromString(map['status'] as String? ?? 'open'),
      respondBy: toDate(map['respondBy']),
      evidenceUrls: (map['evidenceUrls'] as List?)?.map((e) => e.toString()).toList() ?? [],
      evidenceNotes: map['evidenceNotes'] as String?,
      createdAt: toDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: toDate(map['updatedAt']),
      resolvedAt: toDate(map['resolvedAt']),
      gatewayPhase: map['gatewayPhase'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'customerId': customerId,
      'amount': amount,
      'currency': currency,
      'reasonCode': reasonCode,
      'reasonDescription': reasonDescription,
      'status': 'DisputeStatus.${status.name}',
      'respondBy': respondBy != null ? Timestamp.fromDate(respondBy!) : null,
      'evidenceUrls': evidenceUrls,
      'evidenceNotes': evidenceNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'gatewayPhase': gatewayPhase,
    };
  }

  /// Whether this dispute still requires owner action (evidence/response).
  bool get needsAction =>
      status == DisputeStatus.open || status == DisputeStatus.underReview;

  /// Days remaining to respond, or null if no deadline / already resolved.
  int? get daysRemaining {
    if (respondBy == null || !needsAction) return null;
    return respondBy!.difference(DateTime.now()).inDays;
  }
}
