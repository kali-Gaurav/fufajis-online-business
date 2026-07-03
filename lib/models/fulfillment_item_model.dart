/// Status enum for fulfillment items
enum FulfillmentItemStatus { pending, packed, verified }

extension FulfillmentItemStatusExtension on FulfillmentItemStatus {
  String get displayName {
    switch (this) {
      case FulfillmentItemStatus.pending:
        return 'Pending';
      case FulfillmentItemStatus.packed:
        return 'Packed';
      case FulfillmentItemStatus.verified:
        return 'Verified';
    }
  }

  String get apiValue {
    switch (this) {
      case FulfillmentItemStatus.pending:
        return 'PENDING';
      case FulfillmentItemStatus.packed:
        return 'PACKED';
      case FulfillmentItemStatus.verified:
        return 'VERIFIED';
    }
  }

  static FulfillmentItemStatus fromApiValue(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return FulfillmentItemStatus.pending;
      case 'PACKED':
        return FulfillmentItemStatus.packed;
      case 'VERIFIED':
        return FulfillmentItemStatus.verified;
      default:
        return FulfillmentItemStatus.pending;
    }
  }
}

/// Represents a single item in a fulfillment task
class FulfillmentItemModel {
  final String id; // Unique ID for this item in the task
  final String productId;
  final String productName;
  final String? categoryId;
  final String? barcode;
  final String? productImage;
  final int requiredQty;
  final int packedQty;
  final int verifiedQty;
  final FulfillmentItemStatus status;
  final String? warehouseLocation;
  final String? notes;

  FulfillmentItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.categoryId,
    this.barcode,
    this.productImage,
    required this.requiredQty,
    this.packedQty = 0,
    this.verifiedQty = 0,
    this.status = FulfillmentItemStatus.pending,
    this.warehouseLocation,
    this.notes,
  });

  /// Create a copy with modifications
  FulfillmentItemModel copyWith({
    String? id,
    String? productId,
    String? productName,
    String? categoryId,
    String? barcode,
    String? productImage,
    int? requiredQty,
    int? packedQty,
    int? verifiedQty,
    FulfillmentItemStatus? status,
    String? warehouseLocation,
    String? notes,
  }) {
    return FulfillmentItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      categoryId: categoryId ?? this.categoryId,
      barcode: barcode ?? this.barcode,
      productImage: productImage ?? this.productImage,
      requiredQty: requiredQty ?? this.requiredQty,
      packedQty: packedQty ?? this.packedQty,
      verifiedQty: verifiedQty ?? this.verifiedQty,
      status: status ?? this.status,
      warehouseLocation: warehouseLocation ?? this.warehouseLocation,
      notes: notes ?? this.notes,
    );
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'categoryId': categoryId,
      'barcode': barcode,
      'productImage': productImage,
      'requiredQty': requiredQty,
      'packedQty': packedQty,
      'verifiedQty': verifiedQty,
      'status': status.apiValue,
      'warehouseLocation': warehouseLocation,
      'notes': notes,
    };
  }

  /// Create from Firestore JSON
  factory FulfillmentItemModel.fromJson(Map<String, dynamic> json) {
    return FulfillmentItemModel(
      id: json['id'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      categoryId: json['categoryId'] as String?,
      barcode: json['barcode'] as String?,
      productImage: json['productImage'] as String?,
      requiredQty: json['requiredQty'] as int? ?? 0,
      packedQty: json['packedQty'] as int? ?? 0,
      verifiedQty: json['verifiedQty'] as int? ?? 0,
      status: FulfillmentItemStatusExtension.fromApiValue(json['status'] as String? ?? 'PENDING'),
      warehouseLocation: json['warehouseLocation'] as String?,
      notes: json['notes'] as String?,
    );
  }

  @override
  String toString() =>
      'FulfillmentItemModel(productId: $productId, '
      'required: $requiredQty, packed: $packedQty, verified: $verifiedQty, '
      'status: ${status.displayName})';
}
