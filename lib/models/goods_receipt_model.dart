import 'package:cloud_firestore/cloud_firestore.dart';

class GoodsReceiptModel {
  final String id;
  final String purchaseOrderId;
  final String supplierId;
  final String branchId;
  final String productId;
  final int receivedQuantity;
  final int damagedQuantity;
  final int acceptedQuantity; // receivedQuantity - damagedQuantity
  final String recordedByUserId;
  final DateTime timestamp;

  GoodsReceiptModel({
    required this.id,
    required this.purchaseOrderId,
    required this.supplierId,
    required this.branchId,
    required this.productId,
    required this.receivedQuantity,
    required this.damagedQuantity,
    required this.acceptedQuantity,
    required this.recordedByUserId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchaseOrderId': purchaseOrderId,
      'supplierId': supplierId,
      'branchId': branchId,
      'productId': productId,
      'receivedQuantity': receivedQuantity,
      'damagedQuantity': damagedQuantity,
      'acceptedQuantity': acceptedQuantity,
      'recordedByUserId': recordedByUserId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory GoodsReceiptModel.fromMap(Map<String, dynamic> map, String docId) {
    return GoodsReceiptModel(
      id: docId,
      purchaseOrderId: map['purchaseOrderId'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      receivedQuantity: map['receivedQuantity'] as int? ?? 0,
      damagedQuantity: map['damagedQuantity'] as int? ?? 0,
      acceptedQuantity: map['acceptedQuantity'] as int? ?? 0,
      recordedByUserId: map['recordedByUserId'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
