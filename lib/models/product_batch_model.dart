import 'package:cloud_firestore/cloud_firestore.dart';

class ProductBatch {
  final String batchId;
  final String productId;
  final int quantity;
  final DateTime expiryDate;
  final DateTime receivedDate;
  final double costPrice;
  final String branchId;

  ProductBatch({
    required this.batchId,
    required this.productId,
    required this.quantity,
    required this.expiryDate,
    required this.receivedDate,
    required this.costPrice,
    required this.branchId,
  });

  factory ProductBatch.fromMap(Map<String, dynamic> map) {
    return ProductBatch(
      batchId: map['batchId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      expiryDate: map['expiryDate'] is Timestamp
          ? (map['expiryDate'] as Timestamp).toDate()
          : DateTime.tryParse(map['expiryDate']?.toString() ?? '') ?? DateTime.now(),
      receivedDate: map['receivedDate'] is Timestamp
          ? (map['receivedDate'] as Timestamp).toDate()
          : DateTime.tryParse(map['receivedDate']?.toString() ?? '') ?? DateTime.now(),
      costPrice: (map['costPrice'] as num? ?? 0.0).toDouble(),
      branchId: map['branchId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'batchId': batchId,
      'productId': productId,
      'quantity': quantity,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'receivedDate': Timestamp.fromDate(receivedDate),
      'costPrice': costPrice,
      'branchId': branchId,
    };
  }

  ProductBatch copyWith({
    String? batchId,
    String? productId,
    int? quantity,
    DateTime? expiryDate,
    DateTime? receivedDate,
    double? costPrice,
    String? branchId,
  }) {
    return ProductBatch(
      batchId: batchId ?? this.batchId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      expiryDate: expiryDate ?? this.expiryDate,
      receivedDate: receivedDate ?? this.receivedDate,
      costPrice: costPrice ?? this.costPrice,
      branchId: branchId ?? this.branchId,
    );
  }
}
