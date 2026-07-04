import 'package:cloud_firestore/cloud_firestore.dart';

class StaffCredentialModel {
  final String userId;
  final String loginId; // e.g. EMP001, AGT001
  final String pinHash;
  final int failedAttempts;
  final DateTime? lockedUntil;

  StaffCredentialModel({
    required this.userId,
    required this.loginId,
    required this.pinHash,
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  factory StaffCredentialModel.fromMap(Map<String, dynamic> map) {
    return StaffCredentialModel(
      userId: map['userId'] ?? '',
      loginId: map['loginId'] ?? '',
      pinHash: map['pinHash'] ?? '',
      failedAttempts: map['failedAttempts'] ?? 0,
      lockedUntil: (map['lockedUntil'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'loginId': loginId,
      'pinHash': pinHash,
      'failedAttempts': failedAttempts,
      'lockedUntil': lockedUntil != null ? Timestamp.fromDate(lockedUntil!) : null,
    };
  }
}
