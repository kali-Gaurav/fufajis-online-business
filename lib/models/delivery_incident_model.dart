import 'package:cloud_firestore/cloud_firestore.dart';

enum IncidentSeverity { low, medium, high, critical }

enum IncidentStatus { open, investigating, resolved, closed }

class DeliveryIncidentModel {
  final String id;
  final String branchId;
  final String? deliveryTaskId;
  final String? riderId;
  final String? orderId;
  final String title;
  final String description;
  final IncidentSeverity severity;
  final IncidentStatus status;
  final DateTime createdAt;
  final String? assignedInvestigatorId;
  final DateTime? resolvedAt;
  final String? resolutionSummary;

  DeliveryIncidentModel({
    required this.id,
    required this.branchId,
    this.deliveryTaskId,
    this.riderId,
    this.orderId,
    required this.title,
    required this.description,
    this.severity = IncidentSeverity.medium,
    this.status = IncidentStatus.open,
    required this.createdAt,
    this.assignedInvestigatorId,
    this.resolvedAt,
    this.resolutionSummary,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branchId': branchId,
      'deliveryTaskId': deliveryTaskId,
      'riderId': riderId,
      'orderId': orderId,
      'title': title,
      'description': description,
      'severity': severity.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'assignedInvestigatorId': assignedInvestigatorId,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolutionSummary': resolutionSummary,
    };
  }

  factory DeliveryIncidentModel.fromMap(Map<String, dynamic> map, String docId) {
    return DeliveryIncidentModel(
      id: docId,
      branchId: map['branchId'] as String? ?? '',
      deliveryTaskId: map['deliveryTaskId'] as String?,
      riderId: map['riderId'] as String?,
      orderId: map['orderId'] as String?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      severity: IncidentSeverity.values.firstWhere(
        (e) => e.name == map['severity'] as String?,
        orElse: () => IncidentSeverity.medium,
      ),
      status: IncidentStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => IncidentStatus.open,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignedInvestigatorId: map['assignedInvestigatorId'] as String?,
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      resolutionSummary: map['resolutionSummary'] as String?,
    );
  }
}
