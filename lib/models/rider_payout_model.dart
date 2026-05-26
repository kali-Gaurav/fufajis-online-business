import 'package:cloud_firestore/cloud_firestore.dart';

enum PayoutStatus { pending, processed, failed }

class RiderPayoutModel {
  final String id;
  final String riderId;
  final String riderName;
  final double amount;
  final String currency;
  final PayoutStatus status;
  final DateTime timestamp;
  final String? transactionId;
  final String? errorMessage;
  final String type; // e.g., 'weekly_earnings', 'instant_incentive'

  RiderPayoutModel({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.amount,
    this.currency = 'INR',
    required this.status,
    required this.timestamp,
    this.transactionId,
    this.errorMessage,
    this.type = 'weekly_earnings',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'riderId': riderId,
      'riderName': riderName,
      'amount': amount,
      'currency': currency,
      'status': status.toString().split('.').last,
      'timestamp': timestamp,
      'transactionId': transactionId,
      'errorMessage': errorMessage,
      'type': type,
    };
  }

  factory RiderPayoutModel.fromMap(Map<String, dynamic> map) {
    return RiderPayoutModel(
      id: map['id'] ?? '',
      riderId: map['riderId'] ?? '',
      riderName: map['riderName'] ?? 'Rider',
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] ?? 'INR',
      status: PayoutStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => PayoutStatus.pending,
      ),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      transactionId: map['transactionId'],
      errorMessage: map['errorMessage'],
      type: map['type'] ?? 'weekly_earnings',
    );
  }
}
