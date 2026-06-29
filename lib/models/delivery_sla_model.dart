import 'package:cloud_firestore/cloud_firestore.dart';

class DeliverySLAModel {
  final String id;
  final String zoneName;
  final String branchId;
  final int maxDeliveryMinutes;
  final DateTime createdAt;
  final String createdByUserId;

  DeliverySLAModel({
    required this.id,
    required this.zoneName,
    required this.branchId,
    required this.maxDeliveryMinutes,
    required this.createdAt,
    required this.createdByUserId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'zoneName': zoneName,
      'branchId': branchId,
      'maxDeliveryMinutes': maxDeliveryMinutes,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdByUserId': createdByUserId,
    };
  }

  factory DeliverySLAModel.fromMap(Map<String, dynamic> map, String docId) {
    return DeliverySLAModel(
      id: docId,
      zoneName: map['zoneName'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      maxDeliveryMinutes: map['maxDeliveryMinutes'] as int? ?? 45,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdByUserId: map['createdByUserId'] as String? ?? '',
    );
  }
}
