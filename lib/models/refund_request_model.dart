import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/monetary_value.dart';

enum RefundMethod { wallet, upi, gateway, bank }

enum RefundStatus { pending, approved, processing, completed, failed }

class RefundRequest {
  final String id;
  final String orderId;
  final String customerId;
  final MonetaryValue amount;
  final RefundMethod refundMethod;
  final RefundStatus status;
  final String? approvedBy;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String idempotencyKey;

  // Bank-transfer refund details (RefundMethod.bank only). Populated either
  // from the customer's saved bank account or entered by the owner in the
  // Refund Processing screen before the transfer is initiated.
  final String? bankAccountHolderName;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? payoutId;

  RefundRequest({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.amount,
    this.refundMethod = RefundMethod.wallet,
    this.status = RefundStatus.pending,
    this.approvedBy,
    required this.createdAt,
    this.processedAt,
    required this.idempotencyKey,
    this.bankAccountHolderName,
    this.bankAccountNumber,
    this.bankIfsc,
    this.payoutId,
  });

  /// Whether bank details have been captured for a bank-transfer refund.
  bool get hasBankDetails =>
      (bankAccountNumber?.isNotEmpty ?? false) && (bankIfsc?.isNotEmpty ?? false);

  factory RefundRequest.fromMap(Map<String, dynamic> map, String id) {
    return RefundRequest(
      id: id,
      orderId: map['orderId'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      amount: MonetaryValue(map['amount'] ?? 0.0),
      refundMethod: RefundMethod.values.firstWhere(
        (e) => e.name == map['refundMethod'] as String?,
        orElse: () => RefundMethod.wallet,
      ),
      status: RefundStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => RefundStatus.pending,
      ),
      approvedBy: map['approvedBy'] as String?,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      processedAt: _parseDate(map['processedAt']),
      idempotencyKey: map['idempotencyKey'] as String? ?? '',
      bankAccountHolderName: map['bankAccountHolderName'] as String?,
      bankAccountNumber: map['bankAccountNumber'] as String?,
      bankIfsc: map['bankIfsc'] as String?,
      payoutId: map['payoutId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'customerId': customerId,
      'amount': amount,
      'refundMethod': refundMethod.name,
      'status': status.name,
      'approvedBy': approvedBy,
      'createdAt': createdAt,
      'processedAt': processedAt,
      'idempotencyKey': idempotencyKey,
      if (bankAccountHolderName != null) 'bankAccountHolderName': bankAccountHolderName,
      if (bankAccountNumber != null) 'bankAccountNumber': bankAccountNumber,
      if (bankIfsc != null) 'bankIfsc': bankIfsc,
      if (payoutId != null) 'payoutId': payoutId,
    };
  }

  RefundRequest copyWith({
    RefundStatus? status,
    String? approvedBy,
    DateTime? processedAt,
    String? bankAccountHolderName,
    String? bankAccountNumber,
    String? bankIfsc,
    String? payoutId,
  }) {
    return RefundRequest(
      id: id,
      orderId: orderId,
      customerId: customerId,
      amount: amount,
      refundMethod: refundMethod,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      createdAt: createdAt,
      processedAt: processedAt ?? this.processedAt,
      idempotencyKey: idempotencyKey,
      bankAccountHolderName: bankAccountHolderName ?? this.bankAccountHolderName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIfsc: bankIfsc ?? this.bankIfsc,
      payoutId: payoutId ?? this.payoutId,
    );
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is Timestamp) return val.toDate();
    try {
      return DateTime.tryParse(val.toString());
    } catch (_) {
      return null;
    }
  }
}
