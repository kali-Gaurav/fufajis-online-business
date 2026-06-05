import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      sessionId: map['sessionId'] ?? '',
      userId: map['userId'] ?? '',
      deviceId: map['deviceId'] ?? '',
      deviceName: map['deviceName'] ?? '',
      loginTime: map['loginTime'] != null
          ? (map['loginTime'] as Timestamp).toDate()
          : DateTime.now(),
      lastSeen: map['lastSeen'] != null
          ? (map['lastSeen'] as Timestamp).toDate()
          : DateTime.now(),
      isActive: map['isActive'] ?? false,
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
  static final _uuid = const Uuid();
  
  StreamSubscription<DocumentSnapshot>? _sessionSubscription;

  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  /// Create a new session for the logged in user
  Future<String> createSession(String userId) async {
    try {
      final String sessionId = _uuid.v4();
      final String deviceId = await DeviceSecurityService.getDeviceId();
      final String deviceName = await DeviceSecurityService.getDeviceName();

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
        final bool isActive = data['isActive'] ?? false;
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
