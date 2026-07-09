import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/secondary_auth_models.dart';

/// Secondary Auth Session Service - Session and device management
class SecondaryAuthSessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Duration _sessionTimeout = Duration(hours: 1); // 1 hour session
  static const String _sessionsCollection = 'user_secondary_auth_sessions';
  static const String _devicesCollection = 'user_secondary_auth_devices';

  /// Create new session
  Future<SecondaryAuthSession?> createSession({
    required String userId,
    required String email,
    required String role,
    required String ipAddress,
    required String userAgent,
    String? deviceId,
    String? deviceName,
    bool isRememberedDevice = false,
  }) async {
    try {
      final sessionId = const Uuid().v4();
      final now = DateTime.now();
      final expiresAt = now.add(_sessionTimeout);

      final session = SecondaryAuthSession(
        sessionId: sessionId,
        userId: userId,
        email: email,
        role: role,
        createdAt: now,
        expiresAt: expiresAt,
        lastActivityAt: now,
        deviceId: deviceId,
        deviceName: deviceName,
        ipAddress: ipAddress,
        userAgent: userAgent,
        isRememberedDevice: isRememberedDevice,
        isActive: true,
      );

      await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .set(session.toMap());

      debugPrint('[SecondaryAuth] Session created: $sessionId for user $userId');
      return session;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error creating session: $e');
      return null;
    }
  }

  /// Get active session
  Future<SecondaryAuthSession?> getSession(String sessionId) async {
    try {
      final snap = await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .get();

      if (!snap.exists) return null;

      final session = SecondaryAuthSession.fromMap(snap.data()!);
      if (!session.isValid) {
        await deactivateSession(sessionId);
        return null;
      }

      return session;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error getting session: $e');
      return null;
    }
  }

  /// Update last activity
  Future<bool> updateLastActivity(String sessionId) async {
    try {
      await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .update({'last_activity_at': FieldValue.serverTimestamp()});
      return true;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error updating last activity: $e');
      return false;
    }
  }

  /// Get all active sessions for user
  Future<List<SecondaryAuthSession>> getUserActiveSessions(String userId) async {
    try {
      final snap = await _firestore
          .collection(_sessionsCollection)
          .where('user_id', isEqualTo: userId)
          .where('is_active', isEqualTo: true)
          .get();

      final sessions = snap.docs.map((doc) => SecondaryAuthSession.fromMap(doc.data())).toList();

      // Filter out expired sessions
      return sessions.where((s) => !s.isExpired).toList();
    } catch (e) {
      debugPrint('[SecondaryAuth] Error getting user sessions: $e');
      return [];
    }
  }

  /// Deactivate single session
  Future<bool> deactivateSession(String sessionId) async {
    try {
      await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .update({'is_active': false});
      return true;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error deactivating session: $e');
      return false;
    }
  }

  /// Logout from all devices
  Future<bool> logoutAllDevices(String userId) async {
    try {
      final sessions = await getUserActiveSessions(userId);
      for (final session in sessions) {
        await deactivateSession(session.sessionId);
      }
      return true;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error logging out all devices: $e');
      return false;
    }
  }

  /// Register device as trusted
  Future<SecondaryAuthDevice?> registerDevice({
    required String userId,
    required String deviceName,
    required String deviceModel,
    required String osVersion,
    required String ipAddress,
  }) async {
    try {
      final deviceId = const Uuid().v4();
      final device = SecondaryAuthDevice(
        deviceId: deviceId,
        userId: userId,
        deviceName: deviceName,
        deviceModel: deviceModel,
        osVersion: osVersion,
        registeredAt: DateTime.now(),
        isTrusted: false, // Requires admin approval
        isRevoked: false,
        ipAddress: ipAddress,
      );

      await _firestore
          .collection(_devicesCollection)
          .doc(deviceId)
          .set(device.toMap());

      debugPrint('[SecondaryAuth] Device registered: $deviceId for user $userId');
      return device;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error registering device: $e');
      return null;
    }
  }

  /// Get device
  Future<SecondaryAuthDevice?> getDevice(String deviceId) async {
    try {
      final snap = await _firestore
          .collection(_devicesCollection)
          .doc(deviceId)
          .get();

      if (!snap.exists) return null;
      return SecondaryAuthDevice.fromMap(snap.data()!);
    } catch (e) {
      debugPrint('[SecondaryAuth] Error getting device: $e');
      return null;
    }
  }

  /// Get all trusted devices for user
  Future<List<SecondaryAuthDevice>> getUserTrustedDevices(String userId) async {
    try {
      final snap = await _firestore
          .collection(_devicesCollection)
          .where('user_id', isEqualTo: userId)
          .where('is_trusted', isEqualTo: true)
          .where('is_revoked', isEqualTo: false)
          .get();

      return snap.docs.map((doc) => SecondaryAuthDevice.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('[SecondaryAuth] Error getting user devices: $e');
      return [];
    }
  }

  /// Get all devices for user (including revoked)
  Future<List<SecondaryAuthDevice>> getUserAllDevices(String userId) async {
    try {
      final snap = await _firestore
          .collection(_devicesCollection)
          .where('user_id', isEqualTo: userId)
          .get();

      return snap.docs.map((doc) => SecondaryAuthDevice.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('[SecondaryAuth] Error getting user all devices: $e');
      return [];
    }
  }

  /// Trust device (admin action)
  Future<bool> trustDevice(String deviceId) async {
    try {
      await _firestore
          .collection(_devicesCollection)
          .doc(deviceId)
          .update({'is_trusted': true});
      return true;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error trusting device: $e');
      return false;
    }
  }

  /// Revoke device
  Future<bool> revokeDevice(String deviceId) async {
    try {
      await _firestore
          .collection(_devicesCollection)
          .doc(deviceId)
          .update({
        'is_revoked': true,
        'is_trusted': false,
      });
      return true;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error revoking device: $e');
      return false;
    }
  }

  /// Update last used time for device
  Future<bool> updateDeviceLastUsed(String deviceId) async {
    try {
      await _firestore
          .collection(_devicesCollection)
          .doc(deviceId)
          .update({'last_used_at': FieldValue.serverTimestamp()});
      return true;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error updating device last used: $e');
      return false;
    }
  }

  /// Clean up expired sessions (admin operation)
  Future<int> cleanupExpiredSessions() async {
    try {
      final snap = await _firestore
          .collection(_sessionsCollection)
          .where('is_active', isEqualTo: true)
          .get();

      int cleaned = 0;
      for (final doc in snap.docs) {
        final session = SecondaryAuthSession.fromMap(doc.data());
        if (session.isExpired) {
          await _firestore.collection(_sessionsCollection).doc(doc.id).update({
            'is_active': false,
          });
          cleaned++;
        }
      }

      debugPrint('[SecondaryAuth] Cleaned up $cleaned expired sessions');
      return cleaned;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error cleaning up sessions: $e');
      return 0;
    }
  }

  /// Get user's active session count
  Future<int> getUserActiveSessionCount(String userId) async {
    try {
      final sessions = await getUserActiveSessions(userId);
      return sessions.length;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error getting session count: $e');
      return 0;
    }
  }

  /// Check if device is remembered (trusted and not revoked)
  Future<bool> isDeviceRemembered(String deviceId) async {
    try {
      final device = await getDevice(deviceId);
      return device != null && device.isTrusted && !device.isRevoked;
    } catch (e) {
      return false;
    }
  }
}
