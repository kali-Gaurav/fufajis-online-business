import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/secondary_auth_models.dart';

/// Event types for audit logging
enum SecondaryAuthEventType {
  passwordCreated,
  passwordChanged,
  passwordReset,
  passwordRevoked,
  passwordExpired,
  loginSuccess,
  loginFailed,
  accountLocked,
  accountUnlocked,
  sessionCreated,
  sessionExpired,
  sessionTerminated,
  deviceRegistered,
  deviceRemoved,
  deviceTrusted,
  adminOverride,
}

extension EventTypeString on SecondaryAuthEventType {
  String toShortString() {
    return toString().split('.').last.toUpperCase();
  }

  String get displayName {
    switch (this) {
      case SecondaryAuthEventType.passwordCreated:
        return 'PASSWORD_CREATED';
      case SecondaryAuthEventType.passwordChanged:
        return 'PASSWORD_CHANGED';
      case SecondaryAuthEventType.passwordReset:
        return 'PASSWORD_RESET';
      case SecondaryAuthEventType.passwordRevoked:
        return 'PASSWORD_REVOKED';
      case SecondaryAuthEventType.passwordExpired:
        return 'PASSWORD_EXPIRED';
      case SecondaryAuthEventType.loginSuccess:
        return 'LOGIN_SUCCESS';
      case SecondaryAuthEventType.loginFailed:
        return 'LOGIN_FAILED';
      case SecondaryAuthEventType.accountLocked:
        return 'ACCOUNT_LOCKED';
      case SecondaryAuthEventType.accountUnlocked:
        return 'ACCOUNT_UNLOCKED';
      case SecondaryAuthEventType.sessionCreated:
        return 'SESSION_CREATED';
      case SecondaryAuthEventType.sessionExpired:
        return 'SESSION_EXPIRED';
      case SecondaryAuthEventType.sessionTerminated:
        return 'SESSION_TERMINATED';
      case SecondaryAuthEventType.deviceRegistered:
        return 'DEVICE_REGISTERED';
      case SecondaryAuthEventType.deviceRemoved:
        return 'DEVICE_REMOVED';
      case SecondaryAuthEventType.deviceTrusted:
        return 'DEVICE_TRUSTED';
      case SecondaryAuthEventType.adminOverride:
        return 'ADMIN_OVERRIDE';
    }
  }
}

/// Secondary Auth Audit Service - Comprehensive event logging
class SecondaryAuthAuditService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _auditCollection = 'user_secondary_auth_audit';

  /// Log MFA event
  Future<bool> logSecondaryAuthEvent({
    required String userId,
    required String email,
    required SecondaryAuthEventType eventType,
    required String status,
    String? reason,
    String? actorId,
    String? ipAddress,
    String? deviceId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final logId = const Uuid().v4();
      final log = SecondaryAuthAuditLog(
        logId: logId,
        userId: userId,
        email: email,
        eventType: eventType.displayName,
        status: status,
        reason: reason,
        timestamp: DateTime.now(),
        actorId: actorId,
        ipAddress: ipAddress,
        deviceId: deviceId,
        metadata: metadata,
      );

      await _firestore
          .collection(_auditCollection)
          .doc(logId)
          .set(log.toMap());

      debugPrint('[SecondaryAuth] Event logged: ${eventType.displayName} for user $userId');
      return true;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error logging event: $e');
      return false;
    }
  }

  /// Get audit log for user
  Future<List<SecondaryAuthAuditLog>> getUserAuditLog(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final snap = await _firestore
          .collection(_auditCollection)
          .where('user_id', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snap.docs
          .map((doc) => SecondaryAuthAuditLog.fromMap(Map<String, dynamic>.from(doc.data() as Map)))
          .toList();
    } catch (e) {
      debugPrint('[SecondaryAuth] Error getting audit log: $e');
      return [];
    }
  }

  /// Get failed login attempts in last N hours
  Future<int> getFailedLoginCount(String userId, int hours) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(hours: hours));
      final snap = await _firestore
          .collection(_auditCollection)
          .where('user_id', isEqualTo: userId)
          .where('event_type', isEqualTo: 'LOGIN_FAILED')
          .where('timestamp', isGreaterThan: cutoff)
          .get();

      return snap.docs.length;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error getting failed logins: $e');
      return 0;
    }
  }

  /// Get all audit events (admin only)
  Future<List<SecondaryAuthAuditLog>> getAllAuditEvents({int limit = 100}) async {
    try {
      final snap = await _firestore
          .collection(_auditCollection)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snap.docs
          .map((doc) => SecondaryAuthAuditLog.fromMap(Map<String, dynamic>.from(doc.data() as Map)))
          .toList();
    } catch (e) {
      debugPrint('[SecondaryAuth] Error getting all events: $e');
      return [];
    }
  }

  /// Get events by type
  Future<List<SecondaryAuthAuditLog>> getEventsByType(
    SecondaryAuthEventType eventType, {
    int limit = 50,
  }) async {
    try {
      final snap = await _firestore
          .collection(_auditCollection)
          .where('event_type', isEqualTo: eventType.displayName)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snap.docs
          .map((doc) => SecondaryAuthAuditLog.fromMap(Map<String, dynamic>.from(doc.data() as Map)))
          .toList();
    } catch (e) {
      debugPrint('[SecondaryAuth] Error getting events by type: $e');
      return [];
    }
  }

  /// Get events in date range
  Future<List<SecondaryAuthAuditLog>> getEventsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    String? userId,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore
          .collection(_auditCollection)
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (userId != null) {
        query = query.where('user_id', isEqualTo: userId);
      }

      final snap = await query.get();
      return snap.docs
          .map((doc) => SecondaryAuthAuditLog.fromMap(Map<String, dynamic>.from(doc.data() as Map)))
          .toList();
    } catch (e) {
      debugPrint('[SecondaryAuth] Error getting events by date range: $e');
      return [];
    }
  }

  /// Get admin actions (events with actor_id)
  Future<List<SecondaryAuthAuditLog>> getAdminActions({int limit = 50}) async {
    try {
      final snap = await _firestore
          .collection(_auditCollection)
          .where('actor_id', isNotEqualTo: '')
          .orderBy('actor_id')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snap.docs
          .map((doc) => SecondaryAuthAuditLog.fromMap(Map<String, dynamic>.from(doc.data() as Map)))
          .toList();
    } catch (e) {
      debugPrint('[SecondaryAuth] Error getting admin actions: $e');
      return [];
    }
  }

  /// Get suspicious activity (failed logins, lockouts)
  Future<List<SecondaryAuthAuditLog>> getSuspiciousActivity({int limit = 50}) async {
    try {
      final snap = await _firestore
          .collection(_auditCollection)
          .where('status', isEqualTo: 'failed')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snap.docs
          .map((doc) => SecondaryAuthAuditLog.fromMap(Map<String, dynamic>.from(doc.data() as Map)))
          .toList();
    } catch (e) {
      debugPrint('[SecondaryAuth] Error getting suspicious activity: $e');
      return [];
    }
  }

  /// Get user's recent activity summary
  Future<Map<String, dynamic>> getUserActivitySummary(String userId) async {
    try {
      final logs = await getUserAuditLog(userId, limit: 100);

      int successLogins = 0;
      int failedLogins = 0;
      int passwordChanges = 0;
      DateTime? lastLogin;

      for (final log in logs) {
        if (log.eventType == 'LOGIN_SUCCESS') {
          successLogins++;
          if (lastLogin == null) {
            lastLogin = log.timestamp;
          }
        } else if (log.eventType == 'LOGIN_FAILED') {
          failedLogins++;
        } else if (log.eventType == 'PASSWORD_CHANGED' ||
            log.eventType == 'PASSWORD_RESET') {
          passwordChanges++;
        }
      }

      return {
        'successful_logins': successLogins,
        'failed_logins': failedLogins,
        'password_changes': passwordChanges,
        'last_login': lastLogin,
        'total_events': logs.length,
      };
    } catch (e) {
      debugPrint('[SecondaryAuth] Error getting activity summary: $e');
      return {};
    }
  }

  /// Cleanup old audit logs (retention policy)
  Future<int> cleanupOldLogs(int retentionDays) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
      final snap = await _firestore
          .collection(_auditCollection)
          .where('timestamp', isLessThan: cutoff)
          .get();

      int deleted = 0;
      for (final doc in snap.docs) {
        await doc.reference.delete();
        deleted++;
      }

      debugPrint('[SecondaryAuth] Cleaned up $deleted old audit logs');
      return deleted;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error cleaning up logs: $e');
      return 0;
    }
  }
}
