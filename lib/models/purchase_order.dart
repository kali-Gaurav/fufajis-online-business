import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseOrderItem {
  final String productId;
  final String? barcode;
  final String productName;
  final int quantity;
  final String unit;
  final double estimatedCost;

  PurchaseOrderItem({
    required this.productId,
    this.barcode,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.estimatedCost,
  });

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItem(
      productId: map['productId'] as String? ?? '',
      barcode: map['barcode'] as String?,
      productName: map['productName'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      unit: map['unit'] as String? ?? '',
      estimatedCost: (map['estimatedCost'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'barcode': barcode,
    'productName': productName,
    'quantity': quantity,
    'unit': unit,
    'estimatedCost': estimatedCost,
  };
}

class PurchaseOrder {
  final String id;
  final String shopId;
  final String distributorName;
  final List<PurchaseOrderItem> items;
  final double totalAmount;
  final DateTime createdAt;
  final String status; // 'draft', 'sent', 'received'

  PurchaseOrder({
    required this.id,
    required this.shopId,
    required this.distributorName,
    required this.items,
    required this.totalAmount,
    required this.createdAt,
    this.status = 'draft',
  });

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) {
    return PurchaseOrder(
      id: map['id'] as String? ?? '',
      shopId: map['shopId'] as String? ?? '',
      distributorName: map['distributorName'] as String? ?? '',
      items:
          (map['items'] as List?)
              ?.map((i) => PurchaseOrderItem.fromMap(Map<String, dynamic>.from(i as Map)))
              .toList() ??
          [],
      totalAmount: (map['totalAmount'] as num? ?? 0.0).toDouble(),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      status: map['status'] as String? ?? 'draft',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'shopId': shopId,
    'distributorName': distributorName,
    'items': items.map((i) => i.toMap()).toList(),
    'totalAmount': totalAmount,
    'createdAt': Timestamp.fromDate(createdAt),
    'status': status,
  };
}
