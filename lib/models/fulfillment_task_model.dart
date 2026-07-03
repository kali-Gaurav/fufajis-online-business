import 'package:cloud_firestore/cloud_firestore.dart';
import 'fulfillment_item_model.dart';

/// Status enum for fulfillment tasks
enum FulfillmentTaskStatus { new_, inProgress, qualityCheck, completed, rejected }

extension FulfillmentTaskStatusExtension on FulfillmentTaskStatus {
  String get displayName {
    switch (this) {
      case FulfillmentTaskStatus.new_:
        return 'New';
      case FulfillmentTaskStatus.inProgress:
        return 'In Progress';
      case FulfillmentTaskStatus.qualityCheck:
        return 'Quality Check';
      case FulfillmentTaskStatus.completed:
        return 'Completed';
      case FulfillmentTaskStatus.rejected:
        return 'Rejected';
    }
  }

  String get apiValue {
    switch (this) {
      case FulfillmentTaskStatus.new_:
        return 'NEW';
      case FulfillmentTaskStatus.inProgress:
        return 'IN_PROGRESS';
      case FulfillmentTaskStatus.qualityCheck:
        return 'QUALITY_CHECK';
      case FulfillmentTaskStatus.completed:
        return 'COMPLETED';
      case FulfillmentTaskStatus.rejected:
        return 'REJECTED';
    }
  }

  static FulfillmentTaskStatus fromApiValue(String value) {
    switch (value.toUpperCase()) {
      case 'NEW':
        return FulfillmentTaskStatus.new_;
      case 'IN_PROGRESS':
        return FulfillmentTaskStatus.inProgress;
      case 'QUALITY_CHECK':
        return FulfillmentTaskStatus.qualityCheck;
      case 'COMPLETED':
        return FulfillmentTaskStatus.completed;
      case 'REJECTED':
        return FulfillmentTaskStatus.rejected;
      default:
        return FulfillmentTaskStatus.new_;
    }
  }

  bool get isActive {
    return this == FulfillmentTaskStatus.new_ ||
        this == FulfillmentTaskStatus.inProgress ||
        this == FulfillmentTaskStatus.qualityCheck;
  }

  bool get isTerminal {
    return this == FulfillmentTaskStatus.completed || this == FulfillmentTaskStatus.rejected;
  }
}

/// Represents a fulfillment task assigned to an employee
class FulfillmentTaskModel {
  final String taskId;
  final String orderId;
  final int orderNumber;
  final String? assignedToEmployeeId;
  final String? assignedToEmployeeName;
  final List<FulfillmentItemModel> items;
  final FulfillmentTaskStatus status;
  final String? notes; // Special instructions like "fragile", "cold"
  final DateTime? assignedAt;
  final DateTime? packedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final String? rejectionReason;
  final String? shippingLabelUrl;

  FulfillmentTaskModel({
    required this.taskId,
    required this.orderId,
    required this.orderNumber,
    this.assignedToEmployeeId,
    this.assignedToEmployeeName,
    required this.items,
    this.status = FulfillmentTaskStatus.new_,
    this.notes,
    this.assignedAt,
    this.packedAt,
    this.completedAt,
    required this.createdAt,
    this.rejectionReason,
    this.shippingLabelUrl,
  });

  /// Calculate total items required
  int get totalItemsRequired => items.fold(0, (sum, item) => sum + item.requiredQty);

  /// Calculate total items packed
  int get totalItemsPacked => items.fold(0, (sum, item) => sum + item.packedQty);

  /// Calculate total items verified
  int get totalItemsVerified => items.fold(0, (sum, item) => sum + item.verifiedQty);

  /// Check if all items are packed
  bool get allItemsPacked =>
      items.isNotEmpty && items.every((item) => item.packedQty == item.requiredQty);

  /// Check if all items are verified
  bool get allItemsVerified =>
      items.isNotEmpty && items.every((item) => item.status == FulfillmentItemStatus.verified);

  /// Calculate packing efficiency percentage
  double get packingEfficiency {
    if (totalItemsRequired == 0) return 0;
    return (totalItemsPacked / totalItemsRequired) * 100;
  }

  /// Time in queue (in minutes)
  int? get minutesInQueue {
    if (assignedAt == null) return null;
    return DateTime.now().difference(createdAt).inMinutes;
  }

  /// Create a copy with modifications
  FulfillmentTaskModel copyWith({
    String? taskId,
    String? orderId,
    int? orderNumber,
    String? assignedToEmployeeId,
    String? assignedToEmployeeName,
    List<FulfillmentItemModel>? items,
    FulfillmentTaskStatus? status,
    String? notes,
    DateTime? assignedAt,
    DateTime? packedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    String? rejectionReason,
    String? shippingLabelUrl,
  }) {
    return FulfillmentTaskModel(
      taskId: taskId ?? this.taskId,
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      assignedToEmployeeId: assignedToEmployeeId ?? this.assignedToEmployeeId,
      assignedToEmployeeName: assignedToEmployeeName ?? this.assignedToEmployeeName,
      items: items ?? this.items,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      assignedAt: assignedAt ?? this.assignedAt,
      packedAt: packedAt ?? this.packedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      shippingLabelUrl: shippingLabelUrl ?? this.shippingLabelUrl,
    );
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'assignedToEmployeeId': assignedToEmployeeId,
      'assignedToEmployeeName': assignedToEmployeeName,
      'items': items.map((item) => item.toJson()).toList(),
      'status': status.apiValue,
      'notes': notes,
      'assignedAt': assignedAt,
      'packedAt': packedAt,
      'completedAt': completedAt,
      'createdAt': createdAt,
      'rejectionReason': rejectionReason,
      'shippingLabelUrl': shippingLabelUrl,
    };
  }

  /// Create from Firestore JSON
  factory FulfillmentTaskModel.fromJson(Map<String, dynamic> json) {
    return FulfillmentTaskModel(
      taskId: json['taskId'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      orderNumber: json['orderNumber'] as int? ?? 0,
      assignedToEmployeeId: json['assignedToEmployeeId'] as String?,
      assignedToEmployeeName: json['assignedToEmployeeName'] as String?,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => FulfillmentItemModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      status: FulfillmentTaskStatusExtension.fromApiValue(json['status'] as String? ?? 'NEW'),
      notes: json['notes'] as String?,
      assignedAt: json['assignedAt'] != null
          ? (json['assignedAt'] is Timestamp
                ? (json['assignedAt'] as Timestamp).toDate()
                : DateTime.parse(json['assignedAt'].toString()))
          : null,
      packedAt: json['packedAt'] != null
          ? (json['packedAt'] is Timestamp
                ? (json['packedAt'] as Timestamp).toDate()
                : DateTime.parse(json['packedAt'].toString()))
          : null,
      completedAt: json['completedAt'] != null
          ? (json['completedAt'] is Timestamp
                ? (json['completedAt'] as Timestamp).toDate()
                : DateTime.parse(json['completedAt'].toString()))
          : null,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is Timestamp
                ? (json['createdAt'] as Timestamp).toDate()
                : DateTime.parse(json['createdAt'].toString()))
          : DateTime.now(),
      rejectionReason: json['rejectionReason'] as String?,
      shippingLabelUrl: json['shippingLabelUrl'] as String?,
    );
  }

  /// Create from Firestore DocumentSnapshot
  factory FulfillmentTaskModel.fromFirestore(DocumentSnapshot doc) {
    return FulfillmentTaskModel.fromJson(doc.data() as Map<String, dynamic>);
  }

  @override
  String toString() =>
      'FulfillmentTaskModel(taskId: $taskId, '
      'orderId: $orderId, status: ${status.displayName}, '
      'assignedTo: $assignedToEmployeeId, '
      'items: ${items.length}, packed: $totalItemsPacked/$totalItemsRequired)';
}
