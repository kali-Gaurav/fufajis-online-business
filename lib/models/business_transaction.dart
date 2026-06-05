import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { payment, refund, cashback, referral, walletTopup, deliveryFee }
enum TransactionStatus { pending, completed, failed, reversed }

class BusinessTransaction {
  final String id;
  final String orderId;
  final String? orderNumber;
  final String customerId;
  final String? customerName;
  final double amount;
  final TransactionType type;
  final TransactionStatus status;
  final String paymentMethod;
  final String? gatewayTransactionId;
  final DateTime createdAt;
  final String? notes;

  BusinessTransaction({
    required this.id,
    required this.orderId,
    this.orderNumber,
    required this.customerId,
    this.customerName,
    required this.amount,
    required this.type,
    required this.status,
    required this.paymentMethod,
    this.gatewayTransactionId,
    required this.createdAt,
    this.notes,
  });

  factory BusinessTransaction.fromMap(Map<String, dynamic> map) {
    return BusinessTransaction(
      id: map['id'] ?? '',
      orderId: map['orderId'] ?? '',
      orderNumber: map['orderNumber'],
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'],
      amount: (map['amount'] ?? 0.0).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => TransactionType.payment,
      ),
      status: TransactionStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => TransactionStatus.pending,
      ),
      paymentMethod: map['paymentMethod'] ?? 'unknown',
      gatewayTransactionId: map['gatewayTransactionId'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'customerId': customerId,
      'customerName': customerName,
      'amount': amount,
      'type': type.toString(),
      'status': status.toString(),
      'paymentMethod': paymentMethod,
      'gatewayTransactionId': gatewayTransactionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
    };
  }
}
