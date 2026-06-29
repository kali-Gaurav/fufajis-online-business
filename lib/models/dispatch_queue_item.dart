import 'package:cloud_firestore/cloud_firestore.dart';

enum DispatchPriority { low, medium, high, emergency }

class DispatchQueueItem {
  final String id;
  final String orderId;
  final String branchId;
  final DispatchPriority priority;
  final bool autoAssigned;
  final String? assignmentReason;
  final DateTime queuedAt;
  final String? overrideByUserId;

  DispatchQueueItem({
    required this.id,
    required this.orderId,
    required this.branchId,
    this.priority = DispatchPriority.medium,
    this.autoAssigned = true,
    this.assignmentReason,
    required this.queuedAt,
    this.overrideByUserId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'branchId': branchId,
      'priority': priority.name,
      'autoAssigned': autoAssigned,
      'assignmentReason': assignmentReason,
      'queuedAt': Timestamp.fromDate(queuedAt),
      'overrideByUserId': overrideByUserId,
    };
  }

  factory DispatchQueueItem.fromMap(Map<String, dynamic> map, String docId) {
    return DispatchQueueItem(
      id: docId,
      orderId: map['orderId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      priority: DispatchPriority.values.firstWhere(
        (e) => e.name == map['priority'] as String?,
        orElse: () => DispatchPriority.medium,
      ),
      autoAssigned: map['autoAssigned'] as bool? ?? true,
      assignmentReason: map['assignmentReason'] as String?,
      queuedAt: (map['queuedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      overrideByUserId: map['overrideByUserId'] as String?,
    );
  }
}
