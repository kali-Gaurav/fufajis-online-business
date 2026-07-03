import 'package:cloud_firestore/cloud_firestore.dart';

enum ApprovalTargetType {
  purchase_order,
  pricing_change,
  refund,
  ai_action,
  inventory_adjustment,
  other,
}

enum ApprovalStatus { pending, approved, rejected, escalated, cancelled }

class ApprovalRequestModel {
  final String id;
  final ApprovalTargetType targetType;
  final String targetId;
  final String requesterId;
  final String branchId;
  final String title;
  final String description;
  final Map<String, dynamic> metadata; // Arbitrary payload to execute on approval

  final String? approverId;
  final ApprovalStatus status;
  final String? resolutionNotes;

  final DateTime createdAt;
  final DateTime? resolvedAt;

  ApprovalRequestModel({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.requesterId,
    required this.branchId,
    required this.title,
    required this.description,
    this.metadata = const {},
    this.approverId,
    this.status = ApprovalStatus.pending,
    this.resolutionNotes,
    required this.createdAt,
    this.resolvedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'targetType': targetType.name,
      'targetId': targetId,
      'requesterId': requesterId,
      'branchId': branchId,
      'title': title,
      'description': description,
      'metadata': metadata,
      'approverId': approverId,
      'status': status.name,
      'resolutionNotes': resolutionNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }

  factory ApprovalRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    return ApprovalRequestModel(
      id: docId,
      targetType: ApprovalTargetType.values.firstWhere(
        (e) => e.name == map['targetType'] as String?,
        orElse: () => ApprovalTargetType.other,
      ),
      targetId: map['targetId'] as String? ?? '',
      requesterId: map['requesterId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      approverId: map['approverId'] as String?,
      status: ApprovalStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => ApprovalStatus.pending,
      ),
      resolutionNotes: map['resolutionNotes'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }
}
