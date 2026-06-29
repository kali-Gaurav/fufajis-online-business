import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for fulfillment task status
enum FulfillmentStatus {
  assigned,
  packing,
  ready,
  qualityChecked,
  rejected,
  completed,
}

extension FulfillmentStatusExtension on FulfillmentStatus {
  String get displayName {
    switch (this) {
      case FulfillmentStatus.assigned:
        return 'Assigned';
      case FulfillmentStatus.packing:
        return 'Packing';
      case FulfillmentStatus.ready:
        return 'Ready';
      case FulfillmentStatus.qualityChecked:
        return 'Quality Checked';
      case FulfillmentStatus.rejected:
        return 'Rejected';
      case FulfillmentStatus.completed:
        return 'Completed';
    }
  }

  String get description {
    switch (this) {
      case FulfillmentStatus.assigned:
        return 'Order assigned to employee';
      case FulfillmentStatus.packing:
        return 'Currently being packed';
      case FulfillmentStatus.ready:
        return 'Packing complete, ready for QC';
      case FulfillmentStatus.qualityChecked:
        return 'Passed quality check';
      case FulfillmentStatus.rejected:
        return 'Failed quality check';
      case FulfillmentStatus.completed:
        return 'Order completed';
    }
  }
}

/// Represents an item being packed in fulfillment
class FulfillmentItem {
  final String productId;
  final String productName;
  final String? productImage;
  final double requiredQuantity;
  final String unit;
  double packedQuantity;
  bool verified;
  final DateTime createdAt;
  DateTime? scannedAt;
  DateTime? verifiedAt;

  FulfillmentItem({
    required this.productId,
    required this.productName,
    this.productImage,
    required this.requiredQuantity,
    required this.unit,
    this.packedQuantity = 0,
    this.verified = false,
    required this.createdAt,
    this.scannedAt,
    this.verifiedAt,
  });

  bool get isPacked => packedQuantity >= requiredQuantity;
  bool get isFullyVerified => verified && isPacked;
  double get progress => packedQuantity / requiredQuantity;

  factory FulfillmentItem.fromMap(Map<String, dynamic> map) {
    return FulfillmentItem(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      productImage: map['productImage'] as String?,
      requiredQuantity: (map['requiredQuantity'] as num? ?? 0).toDouble(),
      unit: map['unit'] as String? ?? '',
      packedQuantity: (map['packedQuantity'] as num? ?? 0).toDouble(),
      verified: map['verified'] as bool? ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : map['createdAt'] as DateTime,
      scannedAt: map['scannedAt'] != null
          ? map['scannedAt'] is Timestamp
              ? (map['scannedAt'] as Timestamp).toDate()
              : map['scannedAt'] as DateTime
          : null,
      verifiedAt: map['verifiedAt'] != null
          ? map['verifiedAt'] is Timestamp
              ? (map['verifiedAt'] as Timestamp).toDate()
              : map['verifiedAt'] as DateTime
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'requiredQuantity': requiredQuantity,
      'unit': unit,
      'packedQuantity': packedQuantity,
      'verified': verified,
      'createdAt': Timestamp.fromDate(createdAt),
      'scannedAt': scannedAt != null ? Timestamp.fromDate(scannedAt!) : null,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
    };
  }
}

/// Main fulfillment task model
class FulfillmentTask {
  final String id;
  final String orderId;
  final String employeeId;
  final String shopId;
  final String branchId;
  FulfillmentStatus status;
  final List<FulfillmentItem> items;
  final DateTime createdAt;
  DateTime? startedAt;
  DateTime? completedAt;
  DateTime? qualityCheckedAt;
  int totalTimeSeconds = 0;
  double qualityScore = 0;
  String? notes;
  String? rejectionReason;
  String? qualityCheckedBy;
  int itemsVerified = 0;

  FulfillmentTask({
    required this.id,
    required this.orderId,
    required this.employeeId,
    required this.shopId,
    required this.branchId,
    this.status = FulfillmentStatus.assigned,
    this.items = const [],
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.qualityCheckedAt,
    this.totalTimeSeconds = 0,
    this.qualityScore = 0,
    this.notes,
    this.rejectionReason,
    this.qualityCheckedBy,
    this.itemsVerified = 0,
  });

  /// Calculate overall progress (0.0 to 1.0)
  double get overallProgress {
    if (items.isEmpty) return 0;
    final packedItems = items.where((i) => i.isPacked).length;
    return packedItems / items.length;
  }

  /// Get count of packed items
  int get packedItemCount => items.where((i) => i.isPacked).length;

  /// Get total items count
  int get totalItemCount => items.length;

  /// Check if all items are packed
  bool get allItemsPacked => items.every((i) => i.isPacked);

  /// Check if all items are verified
  bool get allItemsVerified => items.every((i) => i.isFullyVerified);

  /// Calculate packing efficiency (items packed per minute)
  double get packingEfficiency {
    if (totalTimeSeconds == 0) return 0;
    final minutesPassed = totalTimeSeconds / 60;
    return packedItemCount / minutesPassed;
  }

  factory FulfillmentTask.fromMap(Map<String, dynamic> map) {
    return FulfillmentTask(
      id: map['id'] as String? ?? '',
      orderId: map['orderId'] as String? ?? '',
      employeeId: map['employeeId'] as String? ?? '',
      shopId: map['shopId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      status: FulfillmentStatus.values[map['status'] as int? ?? 0],
      items: (map['items'] as List?)?.map((i) => FulfillmentItem.fromMap(i as Map<String, dynamic>)).toList() ?? [],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : map['createdAt'] as DateTime,
      startedAt: map['startedAt'] != null
          ? map['startedAt'] is Timestamp
              ? (map['startedAt'] as Timestamp).toDate()
              : map['startedAt'] as DateTime
          : null,
      completedAt: map['completedAt'] != null
          ? map['completedAt'] is Timestamp
              ? (map['completedAt'] as Timestamp).toDate()
              : map['completedAt'] as DateTime
          : null,
      qualityCheckedAt: map['qualityCheckedAt'] != null
          ? map['qualityCheckedAt'] is Timestamp
              ? (map['qualityCheckedAt'] as Timestamp).toDate()
              : map['qualityCheckedAt'] as DateTime
          : null,
      totalTimeSeconds: map['totalTimeSeconds'] as int? ?? 0,
      qualityScore: (map['qualityScore'] as num? ?? 0).toDouble(),
      notes: map['notes'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
      qualityCheckedBy: map['qualityCheckedBy'] as String?,
      itemsVerified: map['itemsVerified'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'employeeId': employeeId,
      'shopId': shopId,
      'branchId': branchId,
      'status': status.index,
      'items': items.map((i) => i.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'qualityCheckedAt': qualityCheckedAt != null ? Timestamp.fromDate(qualityCheckedAt!) : null,
      'totalTimeSeconds': totalTimeSeconds,
      'qualityScore': qualityScore,
      'notes': notes,
      'rejectionReason': rejectionReason,
      'qualityCheckedBy': qualityCheckedBy,
      'itemsVerified': itemsVerified,
    };
  }

  FulfillmentTask copyWith({
    String? id,
    String? orderId,
    String? employeeId,
    String? shopId,
    String? branchId,
    FulfillmentStatus? status,
    List<FulfillmentItem>? items,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? qualityCheckedAt,
    int? totalTimeSeconds,
    double? qualityScore,
    String? notes,
    String? rejectionReason,
    String? qualityCheckedBy,
    int? itemsVerified,
  }) {
    return FulfillmentTask(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      employeeId: employeeId ?? this.employeeId,
      shopId: shopId ?? this.shopId,
      branchId: branchId ?? this.branchId,
      status: status ?? this.status,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      qualityCheckedAt: qualityCheckedAt ?? this.qualityCheckedAt,
      totalTimeSeconds: totalTimeSeconds ?? this.totalTimeSeconds,
      qualityScore: qualityScore ?? this.qualityScore,
      notes: notes ?? this.notes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      qualityCheckedBy: qualityCheckedBy ?? this.qualityCheckedBy,
      itemsVerified: itemsVerified ?? this.itemsVerified,
    );
  }
}

/// Daily stats for employees
class EmployeeDailyStats {
  final String employeeId;
  final String date;
  int totalOrdersPacked;
  int totalItemsPacked;
  double qualityScore;
  double efficiency;
  int totalTimeSeconds;
  int qualityChecksPassed;
  int qualityChecksFailed;

  EmployeeDailyStats({
    required this.employeeId,
    required this.date,
    this.totalOrdersPacked = 0,
    this.totalItemsPacked = 0,
    this.qualityScore = 100.0,
    this.efficiency = 0,
    this.totalTimeSeconds = 0,
    this.qualityChecksPassed = 0,
    this.qualityChecksFailed = 0,
  });

  factory EmployeeDailyStats.fromMap(Map<String, dynamic> map) {
    return EmployeeDailyStats(
      employeeId: map['employeeId'] as String? ?? '',
      date: map['date'] as String? ?? '',
      totalOrdersPacked: map['totalOrdersPacked'] as int? ?? 0,
      totalItemsPacked: map['totalItemsPacked'] as int? ?? 0,
      qualityScore: (map['qualityScore'] as num? ?? 100.0).toDouble(),
      efficiency: (map['efficiency'] as num? ?? 0).toDouble(),
      totalTimeSeconds: map['totalTimeSeconds'] as int? ?? 0,
      qualityChecksPassed: map['qualityChecksPassed'] as int? ?? 0,
      qualityChecksFailed: map['qualityChecksFailed'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'date': date,
      'totalOrdersPacked': totalOrdersPacked,
      'totalItemsPacked': totalItemsPacked,
      'qualityScore': qualityScore,
      'efficiency': efficiency,
      'totalTimeSeconds': totalTimeSeconds,
      'qualityChecksPassed': qualityChecksPassed,
      'qualityChecksFailed': qualityChecksFailed,
    };
  }
}
