import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class DailyBriefingModel {
  final String id;
  final UserRole role;
  final String? branchId; // null if network-wide
  final String? targetUserId; // null if role-wide
  final DateTime date;
  
  final Map<String, dynamic> metrics; // e.g. {'revenueYesterday': 82500, 'ordersPending': 23}
  final List<String> urgentActionItems; // e.g. ['7 Low Stock Items', '4 Deliveries At Risk']
  final List<String> insights; // e.g. ['Surge pricing recommended for evening']
  
  final DateTime createdAt;
  final bool isRead;

  DailyBriefingModel({
    required this.id,
    required this.role,
    this.branchId,
    this.targetUserId,
    required this.date,
    this.metrics = const {},
    this.urgentActionItems = const [],
    this.insights = const [],
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role.name,
      'branchId': branchId,
      'targetUserId': targetUserId,
      'date': Timestamp.fromDate(date),
      'metrics': metrics,
      'urgentActionItems': urgentActionItems,
      'insights': insights,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }

  factory DailyBriefingModel.fromMap(Map<String, dynamic> map, String docId) {
    return DailyBriefingModel(
      id: docId,
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'] as String?,
        orElse: () => UserRole.employee,
      ),
      branchId: map['branchId'] as String?,
      targetUserId: map['targetUserId'] as String?,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metrics: Map<String, dynamic>.from(map['metrics'] as Map? ?? {}),
      urgentActionItems: List<String>.from(map['urgentActionItems'] as Iterable? ?? []),
      insights: List<String>.from(map['insights'] as Iterable? ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] as bool? ?? false,
    );
  }
}
