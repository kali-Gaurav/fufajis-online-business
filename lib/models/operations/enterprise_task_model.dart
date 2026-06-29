import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskCategory { inventory, warehouse, delivery, admin }

enum TaskPriority { low, normal, high, urgent }

enum TaskStatus { pending, assigned, inProgress, completed, failed, cancelled }

class EnterpriseTaskModel {
  final String id;
  final String shopId;
  final String branchId;
  final String title;
  final String description;
  final TaskCategory category;
  final TaskPriority priority;
  final TaskStatus status;
  final String? assignedTo; // employeeId
  final String? orderId;
  final String? relatedEntityId; // e.g. productId, productId
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final List<String> requiredSkills;

  EnterpriseTaskModel({
    required this.id,
    required this.shopId,
    required this.branchId,
    required this.title,
    required this.description,
    required this.category,
    this.priority = TaskPriority.normal,
    this.status = TaskStatus.pending,
    this.assignedTo,
    this.orderId,
    this.relatedEntityId,
    this.metadata = const {},
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.requiredSkills = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'branchId': branchId,
      'title': title,
      'description': description,
      'category': category.name,
      'priority': priority.name,
      'status': status.name,
      'assignedTo': assignedTo,
      'orderId': orderId,
      'relatedEntityId': relatedEntityId,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'requiredSkills': requiredSkills,
    };
  }

  factory EnterpriseTaskModel.fromMap(Map<String, dynamic> map) {
    return EnterpriseTaskModel(
      id: map['id'] as String? ?? '',
      shopId: map['shopId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: TaskCategory.values.firstWhere(
        (e) => e.name == (map['category'] as String? ?? ''),
        orElse: () => TaskCategory.warehouse,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == (map['priority'] as String? ?? ''),
        orElse: () => TaskPriority.normal,
      ),
      status: TaskStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? ''),
        orElse: () => TaskStatus.pending,
      ),
      assignedTo: map['assignedTo'] as String?,
      orderId: map['orderId'] as String?,
      relatedEntityId: map['relatedEntityId'] as String?,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      requiredSkills: List<String>.from(map['requiredSkills'] as Iterable? ?? []),
    );
  }

  EnterpriseTaskModel copyWith({
    TaskPriority? priority,
    TaskStatus? status,
    String? assignedTo,
    Map<String, dynamic>? metadata,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return EnterpriseTaskModel(
      id: id,
      shopId: shopId,
      branchId: branchId,
      title: title,
      description: description,
      category: category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      orderId: orderId,
      relatedEntityId: relatedEntityId,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      requiredSkills: requiredSkills,
    );
  }
}
