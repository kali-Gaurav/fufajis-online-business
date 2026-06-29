import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show Platform;

enum AuditActionType {
  employeeAction,
  adminAction,
  securityEvent,
  financialEvent,
}

class AuditLog {
  final String id;
  final AuditActionType type;
  final String action;
  final String userId;
  final String role;
  final String? branchId;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final String? ipAddress; // Can be obtained via a cloud function or 3rd party API, keeping it optional
  final String deviceInfo;

  AuditLog({
    required this.id,
    required this.type,
    required this.action,
    required this.userId,
    required this.role,
    this.branchId,
    required this.timestamp,
    this.metadata,
    this.ipAddress,
    required this.deviceInfo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'action': action,
      'userId': userId,
      'role': role,
      'branchId': branchId,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
      'ipAddress': ipAddress,
      'deviceInfo': deviceInfo,
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map, String id) {
    return AuditLog(
      id: id,
      type: AuditActionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AuditActionType.employeeAction,
      ),
      action: map['action'] as String? ?? 'unknown',
      userId: map['userId'] as String? ?? 'unknown',
      role: map['role'] as String? ?? 'unknown',
      branchId: map['branchId'] as String?,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: map['metadata'] as Map<String, dynamic>?,
      ipAddress: map['ipAddress'] as String?,
      deviceInfo: map['deviceInfo'] as String? ?? 'unknown',
    );
  }
}

class AuditLoggerService {
  static final AuditLoggerService _instance = AuditLoggerService._internal();
  factory AuditLoggerService() => _instance;
  AuditLoggerService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _getDeviceInfo() {
    try {
      if (kIsWeb) return 'Web Browser';
      if (Platform.isAndroid) return 'Android Device';
      if (Platform.isIOS) return 'iOS Device';
      if (Platform.isWindows) return 'Windows App';
      if (Platform.isMacOS) return 'macOS App';
      if (Platform.isLinux) return 'Linux App';
    } catch (e) {
      // Ignored for environments where Platform isn't supported (e.g., pure web)
    }
    return 'Unknown Device';
  }

  Future<void> _logEvent(
      AuditActionType type, String action, Map<String, dynamic>? metadata, {String? targetUserId, String? role, String? branchId}) async {
    try {
      final user = _auth.currentUser;
      final userId = targetUserId ?? user?.uid ?? 'system';
      final currentRole = role ?? 'unknown';

      final logRef = _firestore.collection('audit_logs').doc();
      final log = AuditLog(
        id: logRef.id,
        type: type,
        action: action,
        userId: userId,
        role: currentRole,
        branchId: branchId,
        timestamp: DateTime.now(),
        metadata: metadata,
        deviceInfo: _getDeviceInfo(),
      );

      await logRef.set(log.toMap());
      debugPrint('[AuditLogger] Logged event: ${type.name} - $action');
    } catch (e) {
      debugPrint('[AuditLogger] Error logging event: $e');
    }
  }

  Future<void> logEmployeeAction(String action, {Map<String, dynamic>? metadata, String? branchId}) async {
    await _logEvent(AuditActionType.employeeAction, action, metadata, branchId: branchId, role: 'employee');
  }

  Future<void> logAdminAction(String action, {String? targetUserId, Map<String, dynamic>? metadata}) async {
    await _logEvent(AuditActionType.adminAction, action, metadata, targetUserId: targetUserId, role: 'admin');
  }

  Future<void> logSecurityEvent(String action, {String? targetUserId, Map<String, dynamic>? metadata}) async {
    await _logEvent(AuditActionType.securityEvent, action, metadata, targetUserId: targetUserId, role: 'system_or_user');
  }

  Future<void> logFinancialEvent(String action, {Map<String, dynamic>? metadata, String? branchId}) async {
    await _logEvent(AuditActionType.financialEvent, action, metadata, branchId: branchId, role: 'system_or_user');
  }

  /// Query audit logs for the dashboard
  Future<List<AuditLog>> getRecentLogs({int limit = 100, AuditActionType? filterType, String? branchId}) async {
    try {
      var query = _firestore.collection('audit_logs').orderBy('timestamp', descending: true);
      
      if (filterType != null) {
        query = query.where('type', isEqualTo: filterType.name);
      }
      
      if (branchId != null) {
        query = query.where('branchId', isEqualTo: branchId);
      }

      final snapshot = await query.limit(limit).get();
      return snapshot.docs.map((doc) => AuditLog.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      debugPrint('[AuditLogger] Error fetching logs: $e');
      return [];
    }
  }
}
