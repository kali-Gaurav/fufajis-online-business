import 'package:cloud_firestore/cloud_firestore.dart';

class GroupOrderModel {
  final String id;
  final String shopId;
  final String district; // Hyperlocal grouping
  final String village; // Hyperlocal grouping
  final List<String> memberIds;
  final Map<String, double> memberContributions;
  final double totalAmount;
  final double goalAmount;
  final double discountPercentage; // Benefit for hitting goal
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime expiresAt;

  GroupOrderModel({
    required this.id,
    required this.shopId,
    required this.district,
    required this.village,
    required this.memberIds,
    this.memberContributions = const {},
    required this.totalAmount,
    required this.goalAmount,
    this.discountPercentage = 20.0,
    this.isCompleted = false,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  double get progress => (totalAmount / goalAmount).clamp(0.0, 1.0);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'district': district,
      'village': village,
      'memberIds': memberIds,
      'memberContributions': memberContributions,
      'totalAmount': totalAmount,
      'goalAmount': goalAmount,
      'discountPercentage': discountPercentage,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  factory GroupOrderModel.fromMap(Map<String, dynamic> map) {
    return GroupOrderModel(
      id: map['id'] as String? ?? '',
      shopId: map['shopId'] as String? ?? '',
      district: map['district'] as String? ?? '',
      village: map['village'] as String? ?? '',
      memberIds: List<String>.from(map['memberIds'] as Iterable? ?? []),
      memberContributions: (map['memberContributions'] as Map?)?.map(
        (key, value) => MapEntry(key as String, (value as num).toDouble()),
      ) ?? {},
      totalAmount: (map['totalAmount'] as num? ?? 0.0).toDouble(),
      goalAmount: (map['goalAmount'] as num? ?? 0.0).toDouble(),
      discountPercentage: (map['discountPercentage'] as num? ?? 20.0).toDouble(),
      isCompleted: map['isCompleted'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      expiresAt: (map['expiresAt'] as Timestamp).toDate(),
    );
  }
}
