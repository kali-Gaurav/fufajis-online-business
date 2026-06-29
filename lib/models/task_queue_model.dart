import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart'; // For UserRole

enum TaskQueueType {
  low_stock,
  pending_settlement,
  sla_breach_risk,
  purchase_approval,
  missing_attendance,
  delivery_incident,
  pricing_approval,
  general_action
}

enum TaskQueueStatus {
  open,
  in_progress,
  blocked,
  completed,
  cancelled
}

enum TaskPriority {
  low,
  medium,
  high,
  urgent
}

class TaskQueueModel {
  final String id;
  final String title;
  final String description;
  final TaskQueueType taskType;
  final TaskQueueStatus status;
  final TaskPriority priority;
  int priorityScore; // 0-100 calculated by OperationalHealthEngine
  final bool escalated;
  
  // Who should do this?
  final UserRole? targetRole; // e.g. dispatcher
  final String? assignedUserId; // e.g. exact user ID
  final String? branchId;

  // Context
  final String? relatedEntityId; // e.g. orderId, productId
  final String? actionUrl; // e.g. /owner/inventory?productId=123

  final DateTime createdAt;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final String? completedByUserId;

  TaskQueueModel({
    required this.id,
    required this.title,
    required this.description,
    required this.taskType,
    this.status = TaskQueueStatus.open,
    this.priority = TaskPriority.medium,
    this.priorityScore = 0,
    this.escalated = false,
    this.targetRole,
    this.assignedUserId,
    this.branchId,
    this.relatedEntityId,
    this.actionUrl,
    required this.createdAt,
    this.dueDate,
    this.completedAt,
    this.completedByUserId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'taskType': taskType.name,
      'status': status.name,
      'priority': priority.name,
      'priorityScore': priorityScore,
      'escalated': escalated,
      'targetRole': targetRole?.name,
      'assignedUserId': assignedUserId,
      'branchId': branchId,
      'relatedEntityId': relatedEntityId,
      'actionUrl': actionUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'completedByUserId': completedByUserId,
    };
  }

  factory TaskQueueModel.fromMap(Map<String, dynamic> map, String docId) {
    return TaskQueueModel(
      id: docId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      taskType: TaskQueueType.values.firstWhere(
        (e) => e.name == map['taskType'] as String?,
        orElse: () => TaskQueueType.general_action,
      ),
      status: TaskQueueStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => TaskQueueStatus.open,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == map['priority'] as String?,
        orElse: () => TaskPriority.medium,
      ),
      priorityScore: map['priorityScore'] as int? ?? 0,
      escalated: map['escalated'] as bool? ?? false,
      targetRole: map['targetRole'] != null 
        ? UserRole.values.firstWhere(
            (e) => e.name == map['targetRole'] as String?,
            orElse: () => UserRole.employee,
          )
        : null,
      assignedUserId: map['assignedUserId'] as String?,
      branchId: map['branchId'] as String?,
      relatedEntityId: map['relatedEntityId'] as String?,
      actionUrl: map['actionUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (map['dueDate'] as Timestamp?)?.toDate(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      completedByUserId: map['completedByUserId'] as String?,
    );
  }
}
