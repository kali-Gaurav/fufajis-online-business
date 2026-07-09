import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/mfa_models.dart';

/// Service for logging MFA audit events
///
/// Records all MFA activities for security and compliance:
/// - Password creation/revocation/reset
/// - Login attempts (success/failed)
/// - Admin actions
class MFAAuditService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Log an MFA event
  Future<void> logMFAEvent({
    required String userId,
    required String eventType, // password_created, password_revoked, login_success, etc.
    required String status, // success or failed
    String? actorId, // Who performed the action
    String? reason, // For failures
    String? ipAddress,
    String? deviceId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final event = MFAAuditLog(
        id: '', // Firestore will generate
        userId: userId,
        eventType: eventType,
        actorId: actorId,
        status: status,
        reason: reason,
        ipAddress: ipAddress,
        deviceId: deviceId,
        timestamp: DateTime.now(),
        metadata: metadata,
      );

      await _firestore.collection('user_mfa_audit').add(event.toMap());
    } catch (e) {
      debugPrint('[MFAAuditService] Error logging event: $e');
    }
  }

  /// Get audit log for a user
  Future<List<MFAAuditLog>> getUserAuditLog(String userId, {int limit = 50}) async {
    try {
      final snap = await _firestore
          .collection('user_mfa_audit')
          .where('user_id', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snap.docs
          .map((doc) => MFAAuditLog.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[MFAAuditService] Error getting audit log: $e');
      return [];
    }
  }

  /// Get failed login attempts for a user (last N hours)
  Future<int> getFailedLoginCount(String userId, {int lastHours = 1}) async {
    try {
      final since = DateTime.now().subtract(Duration(hours: lastHours));

      final snap = await _firestore
          .collection('user_mfa_audit')
          .where('user_id', isEqualTo: userId)
          .where('event_type', isEqualTo: 'login_failed')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .get();

      return snap.size;
    } catch (e) {
      debugPrint('[MFAAuditService] Error getting failed login count: $e');
      return 0;
    }
  }

  /// Get all MFA events for admin viewing (last N events)
  Future<List<MFAAuditLog>> getAllMFAEvents({int limit = 100}) async {
    try {
      final snap = await _firestore
          .collection('user_mfa_audit')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snap.docs
          .map((doc) => MFAAuditLog.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[MFAAuditService] Error getting all events: $e');
      return [];
    }
  }
}
