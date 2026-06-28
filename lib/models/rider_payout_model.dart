import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/monetary_value.dart';

enum PayoutStatus { pending, processed, failed }

class RiderPayoutModel {
  final String id;
  final String riderId;
  final String branchId;
  final String? deliveryTaskId;
  final String riderName;
  final MonetaryValue amount; // total payout
  final double distanceFee;
  final double baseFee;
  final double surgeBonus;
  final String currency;
  final PayoutStatus status;
  final DateTime timestamp;
  final String? transactionId;
  final String? errorMessage;
  final String type; // e.g., 'weekly_earnings', 'instant_incentive', 'task_payout'

  RiderPayoutModel({
    required this.id,
    required this.riderId,
    required this.branchId,
    this.deliveryTaskId,
    required this.riderName,
    required this.amount,
    this.distanceFee = 0.0,
    this.baseFee = 0.0,
    this.surgeBonus = 0.0,
    this.currency = 'INR',
    required this.status,
    required this.timestamp,
    this.transactionId,
    this.errorMessage,
    this.type = 'task_payout',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'riderId': riderId,
      'branchId': branchId,
      'deliveryTaskId': deliveryTaskId,
      'riderName': riderName,
      'amount': amount,
      'distanceFee': distanceFee,
      'baseFee': baseFee,
      'surgeBonus': surgeBonus,
      'currency': currency,
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'transactionId': transactionId,
      'errorMessage': errorMessage,
      'type': type,
    };
  }

  factory RiderPayoutModel.fromMap(Map<String, dynamic> map, String docId) {
    return RiderPayoutModel(
      id: docId,
      riderId: map['riderId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      deliveryTaskId: map['deliveryTaskId'] as String?,
      riderName: map['riderName'] as String? ?? 'Rider',
      amount: MonetaryValue(map['amount'] ?? 0.0),
      distanceFee: (map['distanceFee'] as num? ?? 0.0).toDouble(),
      baseFee: (map['baseFee'] as num? ?? 0.0).toDouble(),
      surgeBonus: (map['surgeBonus'] as num? ?? 0.0).toDouble(),
      currency: map['currency'] as String? ?? 'INR',
      status: PayoutStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => PayoutStatus.pending,
      ),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      transactionId: map['transactionId'] as String?,
      errorMessage: map['errorMessage'] as String?,
      type: map['type'] as String? ?? 'task_payout',
    );
  }
}
