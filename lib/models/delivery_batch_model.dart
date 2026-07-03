import 'package:cloud_firestore/cloud_firestore.dart';

enum BatchStatus { created, assigned, in_progress, completed, failed }

class DeliveryBatchModel {
  final String id;
  final String? riderId;
  final String branchId;
  final List<String> deliveryTaskIds;
  final double estimatedDistance;
  final double estimatedTimeMinutes;
  final BatchStatus status;
  final DateTime createdAt;

  DeliveryBatchModel({
    required this.id,
    this.riderId,
    required this.branchId,
    required this.deliveryTaskIds,
    required this.estimatedDistance,
    required this.estimatedTimeMinutes,
    this.status = BatchStatus.created,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'riderId': riderId,
      'branchId': branchId,
      'deliveryTaskIds': deliveryTaskIds,
      'estimatedDistance': estimatedDistance,
      'estimatedTimeMinutes': estimatedTimeMinutes,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory DeliveryBatchModel.fromMap(Map<String, dynamic> map, String docId) {
    return DeliveryBatchModel(
      id: docId,
      riderId: map['riderId'] as String?,
      branchId: map['branchId'] as String? ?? '',
      deliveryTaskIds: List<String>.from(map['deliveryTaskIds'] as Iterable? ?? []),
      estimatedDistance: (map['estimatedDistance'] as num? ?? 0.0).toDouble(),
      estimatedTimeMinutes: (map['estimatedTimeMinutes'] as num? ?? 0.0).toDouble(),
      status: BatchStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => BatchStatus.created,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
