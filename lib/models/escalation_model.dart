import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

enum EscalationStatus { active, resolved, dismissed }

class EscalationModel {
  final String id;
  final String branchId;
  final String sourceId; // e.g. task_queue id or purchase_order id
  final String sourceType; // e.g. 'task_queue', 'purchase_order', 'delivery_incident'
  final int escalationLevel; // 1 = Manager, 2 = Franchise Owner, 3 = SuperAdmin
  final UserRole escalatedToRole;
  final String title;
  final String description;
  final DateTime deadline;
  final EscalationStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedByUserId;
  final String? resolutionNotes;

  EscalationModel({
    required this.id,
    required this.branchId,
    required this.sourceId,
    required this.sourceType,
    this.escalationLevel = 1,
    required this.escalatedToRole,
    required this.title,
    required this.description,
    required this.deadline,
    this.status = EscalationStatus.active,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedByUserId,
    this.resolutionNotes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branchId': branchId,
      'sourceId': sourceId,
      'sourceType': sourceType,
      'escalationLevel': escalationLevel,
      'escalatedToRole': escalatedToRole.name,
      'title': title,
      'description': description,
      'deadline': Timestamp.fromDate(deadline),
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolvedByUserId': resolvedByUserId,
      'resolutionNotes': resolutionNotes,
    };
  }

  factory EscalationModel.fromMap(Map<String, dynamic> map, String docId) {
    return EscalationModel(
      id: docId,
      branchId: map['branchId'] as String? ?? '',
      sourceId: map['sourceId'] as String? ?? '',
      sourceType: map['sourceType'] as String? ?? '',
      escalationLevel: map['escalationLevel'] as int? ?? 1,
      escalatedToRole: UserRole.values.firstWhere(
        (e) => e.name == map['escalatedToRole'] as String?,
        orElse: () => UserRole.branchManager,
      ),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      deadline: (map['deadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: EscalationStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => EscalationStatus.active,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      resolvedByUserId: map['resolvedByUserId'] as String?,
      resolutionNotes: map['resolutionNotes'] as String?,
    );
  }
}
