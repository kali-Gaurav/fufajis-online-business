import 'package:cloud_firestore/cloud_firestore.dart';

class CodSettlementModel {
  final String id;
  final String riderId;
  final String riderName;
  final String riderPhone;
  final double amount; // backward-compatibility
  final double expectedAmount;
  final double receivedAmount;
  final double difference;
  final String? approvedBy; // managerId
  final String? reason;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime submittedAt;
  final DateTime? resolvedAt;
  final String? notes;

  CodSettlementModel({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.riderPhone,
    required this.amount,
    required this.expectedAmount,
    required this.receivedAmount,
    required this.difference,
    this.approvedBy,
    this.reason,
    required this.status,
    required this.submittedAt,
    this.resolvedAt,
    this.notes,
  });

  factory CodSettlementModel.fromMap(Map<String, dynamic> map) {
    return CodSettlementModel(
      id: map['id'] ?? '',
      riderId: map['riderId'] ?? '',
      riderName: map['riderName'] ?? '',
      riderPhone: map['riderPhone'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      expectedAmount: (map['expectedAmount'] ?? 0.0).toDouble(),
      receivedAmount: (map['receivedAmount'] ?? 0.0).toDouble(),
      difference: (map['difference'] ?? 0.0).toDouble(),
      approvedBy: map['approvedBy'],
      reason: map['reason'],
      status: map['status'] ?? 'pending',
      submittedAt: map['submittedAt'] != null
          ? (map['submittedAt'] as Timestamp).toDate()
          : DateTime.now(),
      resolvedAt: map['resolvedAt'] != null
          ? (map['resolvedAt'] as Timestamp).toDate()
          : null,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'riderId': riderId,
      'riderName': riderName,
      'riderPhone': riderPhone,
      'amount': amount,
      'expectedAmount': expectedAmount,
      'receivedAmount': receivedAmount,
      'difference': difference,
      'approvedBy': approvedBy,
      'reason': reason,
      'status': status,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'notes': notes,
    };
  }

  CodSettlementModel copyWith({
    String? id,
    String? riderId,
    String? riderName,
    String? riderPhone,
    double? amount,
    double? expectedAmount,
    double? receivedAmount,
    double? difference,
    String? approvedBy,
    String? reason,
    String? status,
    DateTime? submittedAt,
    DateTime? resolvedAt,
    String? notes,
  }) {
    return CodSettlementModel(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      riderPhone: riderPhone ?? this.riderPhone,
      amount: amount ?? this.amount,
      expectedAmount: expectedAmount ?? this.expectedAmount,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      difference: difference ?? this.difference,
      approvedBy: approvedBy ?? this.approvedBy,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      notes: notes ?? this.notes,
    );
  }
}
