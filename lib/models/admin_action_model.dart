import 'package:cloud_firestore/cloud_firestore.dart';

enum AdminActionType {
  blockUser,
  unblockUser,
  refund,
  changeOrderStatus,
  forceStatusChange,
  approveDispute,
  rejectDispute,
  deleteAccount,
  manualPaymentApproval,
  fraudAlert,
  other
}

extension AdminActionTypeExtension on AdminActionType {
  String get displayName {
    switch (this) {
      case AdminActionType.blockUser:
        return 'Block User';
      case AdminActionType.unblockUser:
        return 'Unblock User';
      case AdminActionType.refund:
        return 'Refund';
      case AdminActionType.changeOrderStatus:
        return 'Change Order Status';
      case AdminActionType.forceStatusChange:
        return 'Force Status Change';
      case AdminActionType.approveDispute:
        return 'Approve Dispute';
      case AdminActionType.rejectDispute:
        return 'Reject Dispute';
      case AdminActionType.deleteAccount:
        return 'Delete Account';
      case AdminActionType.manualPaymentApproval:
        return 'Manual Payment Approval';
      case AdminActionType.fraudAlert:
        return 'Fraud Alert';
      case AdminActionType.other:
        return 'Other';
    }
  }

  String get apiValue {
    return toString().split('.').last;
  }
}

class AdminAction {
  final String actionId;
  final String adminId;
  final AdminActionType action;
  final String targetId;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final String reason;
  final DateTime timestamp;
  final String ipAddress;
  final String adminEmail;
  final String? branchId;

  AdminAction({
    required this.actionId,
    required this.adminId,
    required this.action,
    required this.targetId,
    this.before,
    this.after,
    required this.reason,
    required this.timestamp,
    required this.ipAddress,
    required this.adminEmail,
    this.branchId,
  });

  Map<String, dynamic> toMap() {
    return {
      'actionId': actionId,
      'adminId': adminId,
      'action': action.apiValue,
      'targetId': targetId,
      'before': before,
      'after': after,
      'reason': reason,
      'timestamp': Timestamp.fromDate(timestamp),
      'ipAddress': ipAddress,
      'adminEmail': adminEmail,
      'branchId': branchId,
    };
  }

  factory AdminAction.fromMap(Map<String, dynamic> map) {
    return AdminAction(
      actionId: map['actionId'] as String? ?? '',
      adminId: map['adminId'] as String? ?? '',
      action: AdminActionType.values.firstWhere(
        (e) => e.apiValue == map['action'] as String?,
        orElse: () => AdminActionType.other,
      ),
      targetId: map['targetId'] as String? ?? '',
      before: map['before'] != null ? Map<String, dynamic>.from(map['before'] as Map) : null,
      after: map['after'] != null ? Map<String, dynamic>.from(map['after'] as Map) : null,
      reason: map['reason'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      ipAddress: map['ipAddress'] as String? ?? '',
      adminEmail: map['adminEmail'] as String? ?? '',
      branchId: map['branchId'] as String?,
    );
  }

  factory AdminAction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminAction.fromMap({...data, 'actionId': doc.id});
  }
}
