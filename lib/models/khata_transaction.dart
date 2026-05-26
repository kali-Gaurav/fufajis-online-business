import 'package:cloud_firestore/cloud_firestore.dart';

enum KhataTransactionType { credit, payment }

class KhataTransaction {
  final String id;
  final String userId;
  final String shopId;
  final double amount;
  final KhataTransactionType type;
  final String? note;
  final String? orderId;
  final DateTime timestamp;

  KhataTransaction({
    required this.id,
    required this.userId,
    required this.shopId,
    required this.amount,
    required this.type,
    this.note,
    this.orderId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'shopId': shopId,
      'amount': amount,
      'type': type.toString(),
      'note': note,
      'orderId': orderId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory KhataTransaction.fromMap(Map<String, dynamic> map) {
    return KhataTransaction(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      shopId: map['shopId'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      type: KhataTransactionType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => KhataTransactionType.credit,
      ),
      note: map['note'],
      orderId: map['orderId'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
