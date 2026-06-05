import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseOrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final String unit;
  final double estimatedCost;

  PurchaseOrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.estimatedCost,
  });

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 0,
      unit: map['unit'] ?? '',
      estimatedCost: (map['estimatedCost'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
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
      id: map['id'] ?? '',
      shopId: map['shopId'] ?? '',
      distributorName: map['distributorName'] ?? '',
      items:
          (map['items'] as List?)
              ?.map(
                (i) => PurchaseOrderItem.fromMap(Map<String, dynamic>.from(i)),
              )
              .toList() ??
          [],
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
                DateTime.now(),
      status: map['status'] ?? 'draft',
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
