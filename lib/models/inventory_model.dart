import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryModel {
  final String productId;
  final String branchId;
  final int availableStock;
  final int reservedStock;
  final int committedStock;
  final int damagedStock;
  final int qcStock;
  final int minimumStock;
  final DateTime updatedAt;

  InventoryModel({
    required this.productId,
    this.branchId = 'default',
    this.availableStock = 0,
    this.reservedStock = 0,
    this.committedStock = 0,
    this.damagedStock = 0,
    this.qcStock = 0,
    this.minimumStock = 10,
    required this.updatedAt,
  });

  int get totalStock => availableStock + reservedStock + committedStock + damagedStock + qcStock;

  bool get inStock => availableStock > 0;
  bool get isLowStock => availableStock <= minimumStock;

  factory InventoryModel.fromMap(Map<String, dynamic> map) {
    return InventoryModel(
      productId: map['productId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? 'default',
      availableStock:
          (map['availableStock'] as int?) ??
          (map['stockQuantity'] as int?) ??
          0, // Fallback to legacy
      reservedStock: map['reservedStock'] as int? ?? 0,
      committedStock: map['committedStock'] as int? ?? 0,
      damagedStock: map['damagedStock'] as int? ?? 0,
      qcStock: map['qcStock'] as int? ?? 0,
      minimumStock: map['minimumStock'] as int? ?? 10,
      updatedAt: _parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'branchId': branchId,
      'availableStock': availableStock,
      'reservedStock': reservedStock,
      'committedStock': committedStock,
      'damagedStock': damagedStock,
      'qcStock': qcStock,
      'minimumStock': minimumStock,
      'updatedAt': updatedAt,
    };
  }

  InventoryModel copyWith({
    String? productId,
    String? branchId,
    int? availableStock,
    int? reservedStock,
    int? committedStock,
    int? damagedStock,
    int? qcStock,
    int? minimumStock,
    DateTime? updatedAt,
  }) {
    return InventoryModel(
      productId: productId ?? this.productId,
      branchId: branchId ?? this.branchId,
      availableStock: availableStock ?? this.availableStock,
      reservedStock: reservedStock ?? this.reservedStock,
      committedStock: committedStock ?? this.committedStock,
      damagedStock: damagedStock ?? this.damagedStock,
      qcStock: qcStock ?? this.qcStock,
      minimumStock: minimumStock ?? this.minimumStock,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is Timestamp) return val.toDate();
    try {
      return DateTime.tryParse(val.toString());
    } catch (_) {
      return null;
    }
  }
}
