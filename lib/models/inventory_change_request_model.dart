import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a bulk/single inventory change request awaiting owner review.
enum InventoryChangeRequestStatus { pending, approved, rejected }

/// The kind of bulk operation that produced this request — used purely for
/// display/grouping in the approval queue.
enum InventoryChangeType {
  fieldUpdate, // generic "set field X to value Y" for matched products
  priceChange,
  priceUpdate,
  stockAdjustment,
  stockUpdate,
  availabilityToggle,
  delete,
  other,
}

/// A single proposed change to a single product. `field` is the
/// [ProductModel]/Firestore field name (e.g. 'price', 'stockQuantity',
/// 'isAvailable', 'category'). `oldValue`/`newValue` are stored as raw
/// JSON-compatible values for diff preview and for applying the write.
class InventoryFieldChange {
  final String productId;
  final String productName;
  final String field;
  final dynamic oldValue;
  final dynamic newValue;

  const InventoryFieldChange({
    required this.productId,
    required this.productName,
    required this.field,
    required this.oldValue,
    required this.newValue,
  });

  factory InventoryFieldChange.fromMap(Map<String, dynamic> map) {
    return InventoryFieldChange(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      field: map['field'] as String? ?? '',
      oldValue: map['oldValue'],
      newValue: map['newValue'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'field': field,
      'oldValue': oldValue,
      'newValue': newValue,
    };
  }
}

/// A pending bulk (or single) inventory edit. Created by the owner/employee
/// from the Bulk Inventory Query Builder. Nothing in [changes] is written to
/// `products` until an owner calls
/// `InventoryChangeRequestService.approveRequest`.
class InventoryChangeRequestModel {
  final String id;
  final InventoryChangeType type;
  final InventoryChangeRequestStatus status;

  /// Human-readable description of the filter/query that produced this
  /// request, e.g. "category = Vegetables AND stockQuantity < 10".
  final String filterDescription;

  /// Optional free-text note from the requester describing intent.
  final String? note;

  final List<InventoryFieldChange> changes;

  final String requestedBy;
  final String requestedByName;
  final DateTime createdAt;

  final String? reviewedBy;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final String? reviewNote;

  const InventoryChangeRequestModel({
    required this.id,
    required this.type,
    required this.status,
    required this.filterDescription,
    this.note,
    required this.changes,
    required this.requestedBy,
    required this.requestedByName,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedAt,
    this.reviewNote,
  });

  int get affectedProductCount => changes.map((c) => c.productId).toSet().length;

  factory InventoryChangeRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    return InventoryChangeRequestModel(
      id: docId,
      type: InventoryChangeType.values.firstWhere(
        (e) => e.name == map['type'] as String?,
        orElse: () => InventoryChangeType.other,
      ),
      status: InventoryChangeRequestStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => InventoryChangeRequestStatus.pending,
      ),
      filterDescription: map['filterDescription'] as String? ?? '',
      note: map['note'] as String?,
      changes: ((map['changes'] as Iterable?) ?? [])
          .map((c) => InventoryFieldChange.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList(),
      requestedBy: map['requestedBy'] as String? ?? '',
      requestedByName: map['requestedByName'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedBy: map['reviewedBy'] as String?,
      reviewedByName: map['reviewedByName'] as String?,
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
      reviewNote: map['reviewNote'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'status': status.name,
      'filterDescription': filterDescription,
      'note': note,
      'changes': changes.map((c) => c.toMap()).toList(),
      'requestedBy': requestedBy,
      'requestedByName': requestedByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewedBy': reviewedBy,
      'reviewedByName': reviewedByName,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewNote': reviewNote,
    };
  }

  InventoryChangeRequestModel copyWith({
    InventoryChangeRequestStatus? status,
    String? reviewedBy,
    String? reviewedByName,
    DateTime? reviewedAt,
    String? reviewNote,
  }) {
    return InventoryChangeRequestModel(
      id: id,
      type: type,
      status: status ?? this.status,
      filterDescription: filterDescription,
      note: note,
      changes: changes,
      requestedBy: requestedBy,
      requestedByName: requestedByName,
      createdAt: createdAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedByName: reviewedByName ?? this.reviewedByName,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNote: reviewNote ?? this.reviewNote,
    );
  }
}
