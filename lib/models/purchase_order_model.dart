import 'package:cloud_firestore/cloud_firestore.dart';

enum PurchaseOrderStatus {
  draft,
  quote_requested,
  quotes_received,
  supplier_selected,
  po_generated,
  supplier_accepted,
  dispatched,
  in_transit,
  partially_received,
  fully_received,
  closed,
  cancelled,
}

class PurchaseOrderModel {
  final String id;
  final String purchaseRequestId;
  final String quoteId;
  final String supplierId;
  final String branchId;
  final String productId;
  final int quantity;
  final double agreedPricePerUnit;
  final double totalAmount;
  final PurchaseOrderStatus status;
  final DateTime expectedDeliveryDate;
  final DateTime createdAt;

  PurchaseOrderModel({
    required this.id,
    required this.purchaseRequestId,
    required this.quoteId,
    required this.supplierId,
    required this.branchId,
    required this.productId,
    required this.quantity,
    required this.agreedPricePerUnit,
    required this.totalAmount,
    this.status = PurchaseOrderStatus.po_generated,
    required this.expectedDeliveryDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchaseRequestId': purchaseRequestId,
      'quoteId': quoteId,
      'supplierId': supplierId,
      'branchId': branchId,
      'productId': productId,
      'quantity': quantity,
      'agreedPricePerUnit': agreedPricePerUnit,
      'totalAmount': totalAmount,
      'status': status.name,
      'expectedDeliveryDate': Timestamp.fromDate(expectedDeliveryDate),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PurchaseOrderModel.fromMap(Map<String, dynamic> map, String docId) {
    return PurchaseOrderModel(
      id: docId,
      purchaseRequestId: map['purchaseRequestId'] as String? ?? '',
      quoteId: map['quoteId'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      agreedPricePerUnit: (map['agreedPricePerUnit'] as num? ?? 0.0).toDouble(),
      totalAmount: (map['totalAmount'] as num? ?? 0.0).toDouble(),
      status: PurchaseOrderStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => PurchaseOrderStatus.po_generated,
      ),
      expectedDeliveryDate: (map['expectedDeliveryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
