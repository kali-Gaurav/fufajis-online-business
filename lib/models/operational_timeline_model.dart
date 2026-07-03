import 'package:cloud_firestore/cloud_firestore.dart';

enum TimelineEntityType {
  order,
  delivery_task,
  purchase_order,
  supplier_quote,
  refund_request,
  other,
}

class OperationalTimelineModel {
  final String id;
  final String branchId;
  final String entityId;
  final TimelineEntityType entityType;

  final String title;
  final String description;
  final String eventKey; // e.g., 'created', 'assigned', 'picked_up'

  final String? triggeredByUserId;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  OperationalTimelineModel({
    required this.id,
    required this.branchId,
    required this.entityId,
    required this.entityType,
    required this.title,
    required this.description,
    required this.eventKey,
    this.triggeredByUserId,
    this.metadata = const {},
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branchId': branchId,
      'entityId': entityId,
      'entityType': entityType.name,
      'title': title,
      'description': description,
      'eventKey': eventKey,
      'triggeredByUserId': triggeredByUserId,
      'metadata': metadata,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory OperationalTimelineModel.fromMap(Map<String, dynamic> map, String docId) {
    return OperationalTimelineModel(
      id: docId,
      branchId: map['branchId'] as String? ?? '',
      entityId: map['entityId'] as String? ?? '',
      entityType: TimelineEntityType.values.firstWhere(
        (e) => e.name == map['entityType'] as String?,
        orElse: () => TimelineEntityType.other,
      ),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      eventKey: map['eventKey'] as String? ?? '',
      triggeredByUserId: map['triggeredByUserId'] as String?,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
