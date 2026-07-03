import 'package:cloud_firestore/cloud_firestore.dart';

enum ExceptionType {
  customer_unreachable,
  wrong_address,
  vehicle_breakdown,
  weather_delay,
  item_missing,
  payment_failure,
  customer_rejected_order,
  other,
}

enum ExceptionStatus { open, under_review, resolved }

class DeliveryExceptionModel {
  final String id;
  final String deliveryTaskId;
  final String riderId;
  final String branchId;
  final ExceptionType type;
  final String description;
  final ExceptionStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolutionNotes;
  final String? resolvedByUserId;

  DeliveryExceptionModel({
    required this.id,
    required this.deliveryTaskId,
    required this.riderId,
    required this.branchId,
    required this.type,
    required this.description,
    this.status = ExceptionStatus.open,
    required this.createdAt,
    this.resolvedAt,
    this.resolutionNotes,
    this.resolvedByUserId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deliveryTaskId': deliveryTaskId,
      'riderId': riderId,
      'branchId': branchId,
      'type': type.name,
      'description': description,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolutionNotes': resolutionNotes,
      'resolvedByUserId': resolvedByUserId,
    };
  }

  factory DeliveryExceptionModel.fromMap(Map<String, dynamic> map, String docId) {
    return DeliveryExceptionModel(
      id: docId,
      deliveryTaskId: map['deliveryTaskId'] as String? ?? '',
      riderId: map['riderId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      type: ExceptionType.values.firstWhere(
        (e) => e.name == map['type'] as String?,
        orElse: () => ExceptionType.other,
      ),
      description: map['description'] as String? ?? '',
      status: ExceptionStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => ExceptionStatus.open,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      resolutionNotes: map['resolutionNotes'] as String?,
      resolvedByUserId: map['resolvedByUserId'] as String?,
    );
  }
}
