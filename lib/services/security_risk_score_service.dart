import 'package:cloud_firestore/cloud_firestore.dart';
import 'security_event_service.dart';

class SecurityRiskScoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int BASE_SCORE = 100;
  static const int PENALTY_FAILED_LOGIN = 5;
  static const int PENALTY_FAILED_PIN = 10;
  static const int PENALTY_PIN_LOCKOUT = 25;
  static const int PENALTY_NEW_DEVICE = 15;
  static const int PENALTY_ROOT_DETECTED = 50;
  static const int PENALTY_SESSION_REVOKED = 30;
  static const int PENALTY_REAUTH_FAILED = 20;

  /// Calculates the current system-wide security risk score (0 to 100).
  /// 100 is perfectly secure. Lower score means higher risk.
  Future<int> calculateSystemRiskScore({int hours = 24}) async {
    final since = DateTime.now().subtract(Duration(hours: hours));
    
    try {
      final snap = await _db
          .collection('security_events')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .get();

      int penalty = 0;

      for (var doc in snap.docs) {
        final data = doc.data();
        final eventName = data['event'] as String?;
        
        if (eventName == SecurityEventType.failedLogin.name) penalty += PENALTY_FAILED_LOGIN;
        if (eventName == SecurityEventType.failedPin.name) penalty += PENALTY_FAILED_PIN;
        if (eventName == SecurityEventType.pinLockout.name) penalty += PENALTY_PIN_LOCKOUT;
        if (eventName == SecurityEventType.newDevice.name) penalty += PENALTY_NEW_DEVICE;
        if (eventName == SecurityEventType.rootDetected.name) penalty += PENALTY_ROOT_DETECTED;
        if (eventName == SecurityEventType.sessionRevoked.name) penalty += PENALTY_SESSION_REVOKED;
        if (eventName == SecurityEventType.reauthenticationFailed.name) penalty += PENALTY_REAUTH_FAILED;
        if (eventName == SecurityEventType.otpFailure.name) penalty += PENALTY_FAILED_LOGIN;
        if (eventName == SecurityEventType.otpLockout.name) penalty += PENALTY_PIN_LOCKOUT;
      }

      int score = BASE_SCORE - penalty;
      return score < 0 ? 0 : score;
    } catch (e) {
      // Fallback
      return 100; 
    }
  }

  /// Calculates a user-specific risk score
  Future<int> calculateUserRiskScore(String userId, {int hours = 24}) async {
    final since = DateTime.now().subtract(Duration(hours: hours));
    
    try {
      final snap = await _db
          .collection('security_events')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .get();

      int penalty = 0;

      for (var doc in snap.docs) {
        final data = doc.data();
        final eventName = data['event'] as String?;
        
        if (eventName == SecurityEventType.failedLogin.name) penalty += PENALTY_FAILED_LOGIN;
        if (eventName == SecurityEventType.failedPin.name) penalty += PENALTY_FAILED_PIN;
        if (eventName == SecurityEventType.pinLockout.name) penalty += PENALTY_PIN_LOCKOUT;
        if (eventName == SecurityEventType.newDevice.name) penalty += PENALTY_NEW_DEVICE;
        if (eventName == SecurityEventType.rootDetected.name) penalty += PENALTY_ROOT_DETECTED;
        if (eventName == SecurityEventType.sessionRevoked.name) penalty += PENALTY_SESSION_REVOKED;
        if (eventName == SecurityEventType.reauthenticationFailed.name) penalty += PENALTY_REAUTH_FAILED;
      }

      int score = BASE_SCORE - penalty;
      return score < 0 ? 0 : score;
    } catch (e) {
      return 100;
    }
  }
}
