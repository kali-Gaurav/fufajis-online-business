import 'package:cloud_firestore/cloud_firestore.dart';

enum SupplierQuoteStatus { pending, accepted, rejected }

class SupplierQuoteModel {
  final String id;
  final String purchaseRequestId;
  final String supplierId;
  final String productId; // To easily display to supplier without joining
  final int requestedQuantity;
  final double quotedPricePerUnit;
  final DateTime estimatedDeliveryDate;
  final String? notes;
  final SupplierQuoteStatus status;
  final DateTime createdAt;

  SupplierQuoteModel({
    required this.id,
    required this.purchaseRequestId,
    required this.supplierId,
    required this.productId,
    required this.requestedQuantity,
    required this.quotedPricePerUnit,
    required this.estimatedDeliveryDate,
    this.notes,
    this.status = SupplierQuoteStatus.pending,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchaseRequestId': purchaseRequestId,
      'supplierId': supplierId,
      'productId': productId,
      'requestedQuantity': requestedQuantity,
      'quotedPricePerUnit': quotedPricePerUnit,
      'estimatedDeliveryDate': Timestamp.fromDate(estimatedDeliveryDate),
      'notes': notes,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory SupplierQuoteModel.fromMap(Map<String, dynamic> map, String docId) {
    return SupplierQuoteModel(
      id: docId,
      purchaseRequestId: map['purchaseRequestId'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      requestedQuantity: map['requestedQuantity'] as int? ?? 0,
      quotedPricePerUnit: (map['quotedPricePerUnit'] as num? ?? 0.0).toDouble(),
      estimatedDeliveryDate: (map['estimatedDeliveryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: map['notes'] as String?,
      status: SupplierQuoteStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => SupplierQuoteStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
