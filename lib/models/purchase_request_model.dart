import 'package:cloud_firestore/cloud_firestore.dart';

enum PurchaseRequestStatus { pending, approved, rejected, ordered, received }

class PurchaseRequestModel {
  final String id;
  final String productId;
  final String branchId;
  final String? supplierId;
  final int currentStock;
  final int recommendedStock;
  final int suggestedPurchaseQty;
  final double expectedCost;
  final PurchaseRequestStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PurchaseRequestModel({
    required this.id,
    required this.productId,
    required this.branchId,
    this.supplierId,
    required this.currentStock,
    required this.recommendedStock,
    required this.suggestedPurchaseQty,
    required this.expectedCost,
    this.status = PurchaseRequestStatus.pending,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'branchId': branchId,
      'supplierId': supplierId,
      'currentStock': currentStock,
      'recommendedStock': recommendedStock,
      'suggestedPurchaseQty': suggestedPurchaseQty,
      'expectedCost': expectedCost,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory PurchaseRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    return PurchaseRequestModel(
      id: docId,
      productId: map['productId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? 'global',
      supplierId: map['supplierId'] as String?,
      currentStock: map['currentStock'] as int? ?? 0,
      recommendedStock: map['recommendedStock'] as int? ?? 0,
      suggestedPurchaseQty: map['suggestedPurchaseQty'] as int? ?? 0,
      expectedCost: (map['expectedCost'] as num? ?? 0.0).toDouble(),
      status: PurchaseRequestStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => PurchaseRequestStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  PurchaseRequestModel copyWith({
    String? id,
    String? productId,
    String? branchId,
    String? supplierId,
    int? currentStock,
    int? recommendedStock,
    int? suggestedPurchaseQty,
    double? expectedCost,
    PurchaseRequestStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PurchaseRequestModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      branchId: branchId ?? this.branchId,
      supplierId: supplierId ?? this.supplierId,
      currentStock: currentStock ?? this.currentStock,
      recommendedStock: recommendedStock ?? this.recommendedStock,
      suggestedPurchaseQty: suggestedPurchaseQty ?? this.suggestedPurchaseQty,
      expectedCost: expectedCost ?? this.expectedCost,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
