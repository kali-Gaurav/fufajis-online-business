// ============================================================
//  SecurityEventService — Threat & security event logging
//
//  Collection: security_events
//  Purpose:    Record security-specific incidents separately from
//              business audit logs. Used for threat monitoring,
//              alerting, and forensic investigation.
//
//  Events tracked:
//  • failedLogin        — Wrong credentials / unauthorised email
//  • failedPin          — Incorrect PIN attempt
//  • pinLockout         — 5 failures → 30-min lockout triggered
//  • biometricFailure   — Biometric authentication rejected
//  • newDevice          — Login from an unrecognised device
//  • deviceRevoked      — Device removed by owner
//  • sessionRevoked     — Remote session killed
//  • rootDetected       — Rooted / jailbroken device detected
//  • loginSuccess       — Successful PIN/biometric (for baseline)
//  • suspiciousActivity — Generic flag for anything unusual
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'device_security_service.dart';

enum SecurityEventType {
  failedLogin,
  failedPin,
  pinLockout,
  biometricFailure,
  newDevice,
  deviceRevoked,
  sessionRevoked,
  rootDetected,
  loginSuccess,
  suspiciousActivity,
  otpFailure,
  otpLockout,
  reauthenticationSuccess,
  reauthenticationFailed,
  pinResetRequested,
  pinResetSuccess,
  pinResetFailed,
  mfaEnabled,
  mfaDisabled,
  mfaChallengeSent,
  mfaChallengeSuccess,
  mfaChallengeFailed,
}

class SecurityEventService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final SecurityEventService _instance = SecurityEventService._internal();
  factory SecurityEventService() => _instance;
  SecurityEventService._internal();

  /// Log a security event. Fire-and-forget — never throws.
  Future<void> logEvent({
    required SecurityEventType event,
    String? userId,
    String? email,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final deviceId = await DeviceSecurityService.getDeviceId();
      final deviceName = await DeviceSecurityService.getDeviceName();

      await _db.collection('security_events').add({
        'event': event.name,
        'userId': userId,
        'email': email,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('[Security] Event: ${event.name} | user=$userId');
    } catch (e) {
      debugPrint('[Security] ERROR logging event: $e');
    }
  }

  // ── Firestore read stream for monitoring dashboard ─────────

  Stream<List<Map<String, dynamic>>> getSecurityEventsStream({
    int limit = 200,
    SecurityEventType? filterType,
    String? filterUserId,
  }) {
    Query<Map<String, dynamic>> query = _db
        .collection('security_events')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (filterType != null) {
      query = query.where('event', isEqualTo: filterType.name);
    }
    if (filterUserId != null) {
      query = query.where('userId', isEqualTo: filterUserId);
    }

    return query.snapshots().map((s) => s.docs.map((d) => d.data()).toList());
  }

  /// Count failed PIN attempts for a user in the last N hours
  Future<int> recentFailedPins(String userId, {int hours = 24}) async {
    try {
      final since = DateTime.now().subtract(Duration(hours: hours));
      final snap = await _db
          .collection('security_events')
          .where('userId', isEqualTo: userId)
          .where('event', isEqualTo: SecurityEventType.failedPin.name)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
