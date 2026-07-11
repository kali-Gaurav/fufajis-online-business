import 'package:equatable/equatable.dart';

// Stock level data
class StockLevel with EquatableMixin {
  final String id;
  final String productId;
  final String productName;
  final int availableQuantity;
  final int reservedQuantity;
  final int damagedQuantity;
  final String? batchNumber;
  final DateTime? expiryDate;
  final DateTime lastCountedAt;
  final DateTime updatedAt;

  StockLevel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.availableQuantity,
    required this.reservedQuantity,
    required this.damagedQuantity,
    this.batchNumber,
    this.expiryDate,
    required this.lastCountedAt,
    required this.updatedAt,
  });

  int get totalQuantity => availableQuantity + reservedQuantity + damagedQuantity;

  bool get isLowStock => availableQuantity < 10;
  bool get isOutOfStock => availableQuantity == 0;
  bool get isExpirySoon => expiryDate != null &&
    DateTime.now().add(Duration(days: 7)).isAfter(expiryDate!);

  String get statusLabel {
    if (isOutOfStock) return 'Out of Stock';
    if (isLowStock) return 'Low Stock';
    if (isExpirySoon) return 'Expiring Soon';
    return 'In Stock';
  }

  String get availableFormatted => '$availableQuantity units';
  String get lastCountedFormatted => _formatTime(lastCountedAt);

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'product_id': productId,
    'product_name': productName,
    'available_quantity': availableQuantity,
    'reserved_quantity': reservedQuantity,
    'damaged_quantity': damagedQuantity,
    'batch_number': batchNumber,
    'expiry_date': expiryDate?.toIso8601String(),
    'last_counted_at': lastCountedAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory StockLevel.fromJson(Map<String, dynamic> json) {
    return StockLevel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      availableQuantity: json['available_quantity'] as int? ?? 0,
      reservedQuantity: json['reserved_quantity'] as int? ?? 0,
      damagedQuantity: json['damaged_quantity'] as int? ?? 0,
      batchNumber: json['batch_number'] as String?,
      expiryDate: json['expiry_date'] != null ? DateTime.parse(json['expiry_date'] as String) : null,
      lastCountedAt: DateTime.parse(json['last_counted_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id, productId, availableQuantity, reservedQuantity,
    damagedQuantity, expiryDate, updatedAt
  ];
}

// Stock movement (audit trail)
class StockMovement with EquatableMixin {
  final String id;
  final String productId;
  final String productName;
  final String movementType;
  final int quantityChange;
  final String? reason;
  final String? notes;
  final String referenceId;
  final String referenceType;
  final String createdBy;
  final DateTime createdAt;

  StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.movementType,
    required this.quantityChange,
    this.reason,
    this.notes,
    required this.referenceId,
    required this.referenceType,
    required this.createdBy,
    required this.createdAt,
  });

  String get movementLabel {
    switch (movementType) {
      case 'in': return 'Stock In';
      case 'out': return 'Stock Out';
      case 'adjustment': return 'Adjustment';
      case 'damage': return 'Damaged';
      default: return movementType;
    }
  }

  String get createdAtFormatted => _formatTime(createdAt);

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'product_id': productId,
    'product_name': productName,
    'movement_type': movementType,
    'quantity_change': quantityChange,
    'reason': reason,
    'notes': notes,
    'reference_id': referenceId,
    'reference_type': referenceType,
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
  };

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      movementType: json['movement_type'] as String,
      quantityChange: json['quantity_change'] as int,
      reason: json['reason'] as String?,
      notes: json['notes'] as String?,
      referenceId: json['reference_id'] as String? ?? '',
      referenceType: json['reference_type'] as String? ?? '',
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, productId, movementType, quantityChange, createdAt];
}

// Supplier information
class Supplier with EquatableMixin {
  final String id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final int leadTimeDays;
  final String? paymentTerms;
  final double rating;
  final int totalOrders;
  final double onTimeDeliveryRate;
  final bool active;
  final DateTime createdAt;

  Supplier({
    required this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.city,
    required this.leadTimeDays,
    this.paymentTerms,
    required this.rating,
    required this.totalOrders,
    required this.onTimeDeliveryRate,
    required this.active,
    required this.createdAt,
  });

  String get ratingFormatted => '${rating.toStringAsFixed(1)}/5';
  String get onTimeFormatted => '${onTimeDeliveryRate.toStringAsFixed(0)}%';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'contact_person': contactPerson,
    'phone': phone,
    'email': email,
    'address': address,
    'city': city,
    'lead_time_days': leadTimeDays,
    'payment_terms': paymentTerms,
    'rating': rating,
    'total_orders': totalOrders,
    'on_time_delivery_rate': onTimeDeliveryRate,
    'active': active,
    'created_at': createdAt.toIso8601String(),
  };

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as String,
      name: json['name'] as String,
      contactPerson: json['contact_person'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      leadTimeDays: json['lead_time_days'] as int? ?? 2,
      paymentTerms: json['payment_terms'] as String?,
      rating: (json['rating'] as num? ?? 0).toDouble(),
      totalOrders: json['total_orders'] as int? ?? 0,
      onTimeDeliveryRate: (json['on_time_delivery_rate'] as num? ?? 0).toDouble(),
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, name, rating, active];
}

// Purchase order
class PurchaseOrder with EquatableMixin {
  final String id;
  final String poNumber;
  final String supplierId;
  final String supplierName;
  final String status;
  final double totalAmount;
  final double? taxAmount;
  final double? discountAmount;
  final DateTime? expectedDeliveryDate;
  final DateTime? actualDeliveryDate;
  final String? notes;
  final String createdBy;
  final String? approvedBy;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final List<PurchaseOrderItem> items;

  PurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.supplierId,
    required this.supplierName,
    required this.status,
    required this.totalAmount,
    this.taxAmount,
    this.discountAmount,
    this.expectedDeliveryDate,
    this.actualDeliveryDate,
    this.notes,
    required this.createdBy,
    this.approvedBy,
    required this.createdAt,
    this.approvedAt,
    this.items = const [],
  });

  String get statusLabel {
    switch (status) {
      case 'draft': return 'Draft';
      case 'sent': return 'Sent';
      case 'confirmed': return 'Confirmed';
      case 'received': return 'Received';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }

  int get itemCount => items.length;
  double get grandTotal => totalAmount + (taxAmount ?? 0) - (discountAmount ?? 0);

  String get grandTotalFormatted => '₹${grandTotal.toStringAsFixed(2)}';
  String get createdAtFormatted => _formatDate(createdAt);

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'po_number': poNumber,
    'supplier_id': supplierId,
    'supplier_name': supplierName,
    'status': status,
    'total_amount': totalAmount,
    'tax_amount': taxAmount,
    'discount_amount': discountAmount,
    'expected_delivery_date': expectedDeliveryDate?.toIso8601String(),
    'actual_delivery_date': actualDeliveryDate?.toIso8601String(),
    'notes': notes,
    'created_by': createdBy,
    'approved_by': approvedBy,
    'created_at': createdAt.toIso8601String(),
    'approved_at': approvedAt?.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      id: json['id'] as String,
      poNumber: json['po_number'] as String,
      supplierId: json['supplier_id'] as String,
      supplierName: json['supplier_name'] as String,
      status: json['status'] as String? ?? 'draft',
      totalAmount: (json['total_amount'] as num? ?? 0).toDouble(),
      taxAmount: json['tax_amount'] != null ? (json['tax_amount'] as num).toDouble() : null,
      discountAmount: json['discount_amount'] != null ? (json['discount_amount'] as num).toDouble() : null,
      expectedDeliveryDate: json['expected_delivery_date'] != null ? DateTime.parse(json['expected_delivery_date'] as String) : null,
      actualDeliveryDate: json['actual_delivery_date'] != null ? DateTime.parse(json['actual_delivery_date'] as String) : null,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String,
      approvedBy: json['approved_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at'] as String) : null,
      items: (json['items'] as List<dynamic>?)?.map((i) => PurchaseOrderItem.fromJson(i as Map<String, dynamic>)).toList() ?? [],
    );
  }

  @override
  List<Object?> get props => [id, poNumber, supplierId, status, createdAt];
}

// Purchase order item
class PurchaseOrderItem with EquatableMixin {
  final String id;
  final String poId;
  final String productId;
  final String productName;
  final int quantity;
  final double unitCost;
  final int quantityReceived;

  PurchaseOrderItem({
    required this.id,
    required this.poId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    this.quantityReceived = 0,
  });

  double get totalCost => quantity * unitCost;
  String get totalCostFormatted => '₹${totalCost.toStringAsFixed(2)}';
  String get quantityLabel => '$quantity units @ ₹${unitCost.toStringAsFixed(2)}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'po_id': poId,
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
    'unit_cost': unitCost,
    'quantity_received': quantityReceived,
  };

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItem(
      id: json['id'] as String,
      poId: json['po_id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      quantity: json['quantity'] as int,
      unitCost: (json['unit_cost'] as num).toDouble(),
      quantityReceived: json['quantity_received'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, poId, productId, quantity, unitCost];
}

// Reorder suggestion
class ReorderSuggestion with EquatableMixin {
  final String productId;
  final String productName;
  final int currentStock;
  final int reorderPoint;
  final int reorderQuantity;
  final int maxStockLevel;
  final String? preferredSupplierId;
  final String? preferredSupplierName;
  final int leadTimeDays;
  final double estimatedCost;
  final DateTime? lastOrderedAt;
  final bool autoReorder;

  ReorderSuggestion({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.reorderPoint,
    required this.reorderQuantity,
    required this.maxStockLevel,
    this.preferredSupplierId,
    this.preferredSupplierName,
    required this.leadTimeDays,
    required this.estimatedCost,
    this.lastOrderedAt,
    required this.autoReorder,
  });

  bool get needsReorder => currentStock <= reorderPoint;
  String get needsReorderLabel => needsReorder ? 'Yes - Order Now' : 'No - Sufficient Stock';
  String get estimatedCostFormatted => '₹${estimatedCost.toStringAsFixed(2)}';
  String get daysToStockout => ((currentStock / reorderQuantity) * leadTimeDays).ceil().toString();

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_name': productName,
    'current_stock': currentStock,
    'reorder_point': reorderPoint,
    'reorder_quantity': reorderQuantity,
    'max_stock_level': maxStockLevel,
    'preferred_supplier_id': preferredSupplierId,
    'preferred_supplier_name': preferredSupplierName,
    'lead_time_days': leadTimeDays,
    'estimated_cost': estimatedCost,
    'last_ordered_at': lastOrderedAt?.toIso8601String(),
    'auto_reorder': autoReorder,
  };

  factory ReorderSuggestion.fromJson(Map<String, dynamic> json) {
    return ReorderSuggestion(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      currentStock: json['current_stock'] as int,
      reorderPoint: json['reorder_point'] as int,
      reorderQuantity: json['reorder_quantity'] as int,
      maxStockLevel: json['max_stock_level'] as int? ?? 999,
      preferredSupplierId: json['preferred_supplier_id'] as String?,
      preferredSupplierName: json['preferred_supplier_name'] as String?,
      leadTimeDays: json['lead_time_days'] as int? ?? 2,
      estimatedCost: (json['estimated_cost'] as num? ?? 0).toDouble(),
      lastOrderedAt: json['last_ordered_at'] != null ? DateTime.parse(json['last_ordered_at'] as String) : null,
      autoReorder: json['auto_reorder'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [productId, currentStock, reorderPoint];
}

// Expiry alert
class ExpiryAlert with EquatableMixin {
  final String id;
  final String productId;
  final String productName;
  final String batchNumber;
  final DateTime expiryDate;
  final int quantityRemaining;
  final String status;
  final String location;
  final int daysUntilExpiry;

  ExpiryAlert({
    required this.id,
    required this.productId,
    required this.productName,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantityRemaining,
    required this.status,
    required this.location,
    required this.daysUntilExpiry,
  });

  String get urgencyLabel {
    if (daysUntilExpiry < 0) return 'Expired';
    if (daysUntilExpiry == 0) return 'Expiring Today';
    if (daysUntilExpiry < 3) return 'Critical';
    if (daysUntilExpiry < 7) return 'Urgent';
    if (daysUntilExpiry < 30) return 'Caution';
    return 'Watch';
  }

  String get expiryDateFormatted => '${expiryDate.day}/${expiryDate.month}/${expiryDate.year}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'product_id': productId,
    'product_name': productName,
    'batch_number': batchNumber,
    'expiry_date': expiryDate.toIso8601String(),
    'quantity_remaining': quantityRemaining,
    'status': status,
    'location': location,
    'days_until_expiry': daysUntilExpiry,
  };

  factory ExpiryAlert.fromJson(Map<String, dynamic> json) {
    return ExpiryAlert(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      batchNumber: json['batch_number'] as String,
      expiryDate: DateTime.parse(json['expiry_date'] as String),
      quantityRemaining: json['quantity_remaining'] as int,
      status: json['status'] as String,
      location: json['location'] as String? ?? 'Unknown',
      daysUntilExpiry: json['days_until_expiry'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, productId, expiryDate, daysUntilExpiry];
}

// Inventory dashboard metrics
class InventoryMetrics with EquatableMixin {
  final double totalStockValue;
  final int totalItemsInStock;
  final int lowStockAlerts;
  final int expiringItems;
  final int outOfStockItems;
  final int suggestedReorders;
  final DateTime lastUpdated;

  InventoryMetrics({
    required this.totalStockValue,
    required this.totalItemsInStock,
    required this.lowStockAlerts,
    required this.expiringItems,
    required this.outOfStockItems,
    required this.suggestedReorders,
    required this.lastUpdated,
  });

  String get totalStockValueFormatted => '₹${(totalStockValue).toStringAsFixed(0)}';
  String get lastUpdatedFormatted => _formatTime(lastUpdated);

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Map<String, dynamic> toJson() => {
    'total_stock_value': totalStockValue,
    'total_items_in_stock': totalItemsInStock,
    'low_stock_alerts': lowStockAlerts,
    'expiring_items': expiringItems,
    'out_of_stock_items': outOfStockItems,
    'suggested_reorders': suggestedReorders,
    'last_updated': lastUpdated.toIso8601String(),
  };

  factory InventoryMetrics.fromJson(Map<String, dynamic> json) {
    return InventoryMetrics(
      totalStockValue: (json['total_stock_value'] as num? ?? 0).toDouble(),
      totalItemsInStock: json['total_items_in_stock'] as int? ?? 0,
      lowStockAlerts: json['low_stock_alerts'] as int? ?? 0,
      expiringItems: json['expiring_items'] as int? ?? 0,
      outOfStockItems: json['out_of_stock_items'] as int? ?? 0,
      suggestedReorders: json['suggested_reorders'] as int? ?? 0,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  @override
  List<Object?> get props => [
    totalStockValue, totalItemsInStock, lowStockAlerts,
    expiringItems, outOfStockItems, suggestedReorders
  ];
}
