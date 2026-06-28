import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'device_security_service.dart';
import 'audit_service.dart';

class SessionModel {
  final String sessionId;
  final String userId;
  final String deviceId;
  final String deviceName;
  final DateTime loginTime;
  final DateTime lastSeen;
  final bool isActive;

  SessionModel({
    required this.sessionId,
    required this.userId,
    required this.deviceId,
    required this.deviceName,
    required this.loginTime,
    required this.lastSeen,
    required this.isActive,
  });

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    return SessionModel(
      sessionId: map['sessionId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      deviceId: map['deviceId'] as String? ?? '',
      deviceName: map['deviceName'] as String? ?? '',
      loginTime: map['loginTime'] != null
          ? (map['loginTime'] as Timestamp).toDate()
          : DateTime.now(),
      lastSeen: map['lastSeen'] != null
          ? (map['lastSeen'] as Timestamp).toDate()
          : DateTime.now(),
      isActive: map['isActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'loginTime': loginTime,
      'lastSeen': lastSeen,
      'isActive': isActive,
    };
  }
}

class SessionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  StreamSubscription<DocumentSnapshot>? _sessionSubscription;
  Timer? _heartbeatTimer;

  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  /// Max concurrent active sessions per user (Task 35).
  static const int maxConcurrentSessions = 3;

  /// Inactivity timeout before a session is considered expired (Task 36).
  static const Duration sessionTimeout = Duration(minutes: 30);

  /// Create a new session, enforcing the concurrent-session limit.
  /// If the limit is reached, the oldest session is revoked automatically.
  Future<String> createSession(String userId) async {
    try {
      final String sessionId = _uuid.v4();
      final String deviceId = await DeviceSecurityService.getDeviceId();
      final String deviceName = await DeviceSecurityService.getDeviceName();

      // Enforce concurrent session limit
      await _enforceSessionLimit(userId);

      final session = SessionModel(
        sessionId: sessionId,
        userId: userId,
        deviceId: deviceId,
        deviceName: deviceName,
        loginTime: DateTime.now(),
        lastSeen: DateTime.now(),
        isActive: true,
      );

      await _firestore
          .collection('active_sessions')
          .doc(sessionId)
          .set(session.toMap());

      return sessionId;
    } catch (e) {
      print('Error creating session: $e');
      rethrow;
    }
  }

  /// Revoke the oldest sessions if count exceeds [maxConcurrentSessions].
  Future<void> _enforceSessionLimit(String userId) async {
    try {
      final snap = await _firestore
          .collection('active_sessions')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('loginTime')
          .get();

      final sessions = snap.docs;
      if (sessions.length >= maxConcurrentSessions) {
        final excess = sessions.length - maxConcurrentSessions + 1;
        final batch = _firestore.batch();
        for (int i = 0; i < excess; i++) {
          batch.update(sessions[i].reference, {
            'isActive': false,
            'revokedAt': FieldValue.serverTimestamp(),
            'revokeReason': 'session_limit_exceeded',
          });
        }
        await batch.commit();
        print('[Session] Revoked $excess session(s) to enforce limit of $maxConcurrentSessions');
      }
    } catch (e) {
      print('[Session] Error enforcing session limit: $e');
    }
  }

  /// Start heartbeat timer to keep session alive and detect timeout.
  void startHeartbeat(String sessionId, {VoidCallback? onTimeout}) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await updateLastSeen(sessionId);
    });
  }

  /// Stop heartbeat.
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Returns true if [lastSeen] is older than [sessionTimeout].
  bool isSessionExpired(DateTime lastSeen) {
    return DateTime.now().difference(lastSeen) > sessionTimeout;
  }

  /// Update last active time for the current session (heartbeat)
  Future<void> updateLastSeen(String sessionId) async {
    try {
      await _firestore
          .collection('active_sessions')
          .doc(sessionId)
          .update({'lastSeen': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Error updating last seen: $e');
    }
  }

  /// Listen to the current session document. Trigger onRevoked if session is deactivated.
  void listenToSession(String sessionId, Function() onRevoked) {
    _sessionSubscription?.cancel();
    _sessionSubscription = _firestore
        .collection('active_sessions')
        .doc(sessionId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        onRevoked();
        return;
      }
      final data = snapshot.data();
      if (data != null) {
        final bool isActive = data['isActive'] as bool? ?? false;
        if (!isActive) {
          onRevoked();
        }
      }
    }, onError: (err) {
      print('Error listening to session: $err');
    });
  }

  /// Stop listening to session state
  void stopSessionListener() {
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
  }

  /// Query all active sessions for a user
  Stream<List<SessionModel>> streamActiveSessions(String userId) {
    return _firestore
        .collection('active_sessions')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionModel.fromMap(doc.data()))
            .toList());
  }

  /// Revoke an active session remotely
  Future<void> revokeSession(String sessionId, String revokedByUserId, String revokedByUserName) async {
    try {
      // Fetch session details for logging
      final doc = await _firestore.collection('active_sessions').doc(sessionId).get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final targetUserId = data['userId'];
      final deviceName = data['deviceName'];

      await _firestore.collection('active_sessions').doc(sessionId).update({
        'isActive': false,
        'revokedAt': FieldValue.serverTimestamp(),
      });

      // Audit Log
      await AuditService().logAction(
        userId: revokedByUserId,
        userName: revokedByUserName,
        action: AuditAction.adminAction,
        description: 'Revoked active session for user $targetUserId on device "$deviceName"',
        metadata: {
          'sessionId': sessionId,
          'targetUserId': targetUserId,
          'deviceName': deviceName,
        },
      );
    } catch (e) {
      print('Error revoking session: $e');
    }
  }
}
