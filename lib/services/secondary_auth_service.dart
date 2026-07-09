import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/secondary_auth_models.dart';
import '../models/user_model.dart';
import 'secondary_auth_password_service.dart';
import 'secondary_auth_audit_service.dart';
import 'secondary_auth_session_service.dart';
import 'secondary_auth_rate_limiter.dart';

/// Secondary Auth Service - Complete privileged access authentication
///
/// IMPORTANT BUSINESS LOGIC:
/// - ONLY Admin/Owner can authorize employees/delivery agents
/// - Employees/agents CANNOT create their own passwords
/// - On forgotten password, employee must contact admin
/// - Admin can revoke and reissue passwords
class SecondaryAuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SecondaryAuthAuditService _auditService = SecondaryAuthAuditService();
  final SecondaryAuthSessionService _sessionService = SecondaryAuthSessionService();

  static const String _secretsCollection = 'user_secondary_auth_secrets';

  /// Verify password on login with progressive rate limiting
  Future<Map<String, dynamic>> verifyPassword({
    required String userId,
    required String password,
    String? ipAddress,
    String? deviceId,
    String? userAgent,
  }) async {
    try {
      final secretSnap =
          await _firestore.collection(_secretsCollection).doc(userId).get();

      if (!secretSnap.exists) {
        await _auditService.logSecondaryAuthEvent(
          userId: userId,
          email: 'unknown',
          eventType: SecondaryAuthEventType.loginFailed,
          status: 'failed',
          reason: 'secret_not_found',
        );
        return {'success': false, 'error': 'Account not found'};
      }

      final secret = SecondaryAuthSecret.fromMap(secretSnap.data()!);

      // Check if password is active
      if (!secret.isActive) {
        await _auditService.logSecondaryAuthEvent(
          userId: userId,
          email: secret.email,
          eventType: SecondaryAuthEventType.loginFailed,
          status: 'failed',
          reason: 'password_revoked',
        );
        return {
          'success': false,
          'error': 'Password revoked. Contact admin to reset.'
        };
      }

      // Check if password is expired
      if (secret.passwordExpired) {
        await _auditService.logSecondaryAuthEvent(
          userId: userId,
          email: secret.email,
          eventType: SecondaryAuthEventType.passwordExpired,
          status: 'failed',
          reason: 'password_expired',
        );
        return {
          'success': false,
          'error': 'Password expired. Contact admin for reset.'
        };
      }

      // Check rate limiting
      final rateLimitStatus =
          SecondaryAuthRateLimiter.calculateStatus(secret.failedAttempts, secret.lockedUntil);

      if (!SecondaryAuthRateLimiter.isAttemptAllowed(
          secret.failedAttempts, secret.lockedUntil)) {
        await _auditService.logSecondaryAuthEvent(
          userId: userId,
          email: secret.email,
          eventType: SecondaryAuthEventType.accountLocked,
          status: 'failed',
          reason: 'rate_limit_exceeded',
          metadata: SecondaryAuthRateLimiter.getRateLimitAuditMetadata(
            rateLimitStatus,
            secret.failedAttempts,
          ),
        );

        return {
          'success': false,
          'error': SecondaryAuthRateLimiter.getStatusMessage(rateLimitStatus),
          'rate_limit_status': rateLimitStatus.status,
          'requires_admin_approval': rateLimitStatus.requiresAdminApproval,
        };
      }

      // Verify password
      final isMatch =
          SecondaryAuthPasswordService.verifyPassword(password, secret.passwordHash);

      if (!isMatch) {
        // Failed attempt - increment and apply progressive rate limiting
        final newFailedAttempts = secret.failedAttempts + 1;
        final newLockTime =
            SecondaryAuthRateLimiter.calculateLockTime(newFailedAttempts);

        await _firestore.collection(_secretsCollection).doc(userId).update({
          'failed_attempts': newFailedAttempts,
          'locked_until': newLockTime,
        });

        final newStatus =
            SecondaryAuthRateLimiter.calculateStatus(newFailedAttempts, newLockTime);

        await _auditService.logSecondaryAuthEvent(
          userId: userId,
          email: secret.email,
          eventType: SecondaryAuthEventType.loginFailed,
          status: 'failed',
          reason: 'incorrect_password',
          ipAddress: ipAddress,
          deviceId: deviceId,
          metadata: {
            'failed_attempts': newFailedAttempts,
            'rate_limit_status': newStatus.status,
          },
        );

        return {
          'success': false,
          'error': SecondaryAuthRateLimiter.getStatusMessage(newStatus),
          'rate_limit_status': newStatus.status,
          'attempts_remaining': SecondaryAuthRateLimiter.getAttemptsBeforeLock(
            newFailedAttempts,
          ),
          'requires_admin_approval': newStatus.requiresAdminApproval,
        };
      }

      // Password correct - reset attempts, create session
      final newSession = await _sessionService.createSession(
        userId: userId,
        email: secret.email,
        role: secret.role,
        ipAddress: ipAddress ?? '',
        userAgent: userAgent ?? '',
        deviceId: deviceId,
        isRememberedDevice: false,
      );

      if (newSession == null) {
        return {'success': false, 'error': 'Failed to create session'};
      }

      // Reset failed attempts
      await _firestore.collection(_secretsCollection).doc(userId).update({
        'failed_attempts': 0,
        'locked_until': null,
        'last_login_at': FieldValue.serverTimestamp(),
        'login_attempts': FieldValue.increment(1),
      });

      await _auditService.logSecondaryAuthEvent(
        userId: userId,
        email: secret.email,
        eventType: SecondaryAuthEventType.loginSuccess,
        status: 'success',
        ipAddress: ipAddress,
        deviceId: deviceId,
      );

      return {
        'success': true,
        'session_id': newSession.sessionId,
        'session': newSession,
      };
    } catch (e) {
      debugPrint('[SecondaryAuth] Error verifying password: $e');
      return {'success': false, 'error': 'Verification failed'};
    }
  }

  /// Initialize secondary auth for first login (admin/owner only - self-service)
  Future<bool> initializeForFirstLogin({
    required String userId,
    required String email,
    required UserRole role,
  }) async {
    try {
      final existing =
          await _firestore.collection(_secretsCollection).doc(userId).get();

      if (existing.exists) {
        return true;
      }

      final secret = SecondaryAuthSecret(
        userId: userId,
        email: email,
        role: role.toString(),
        passwordHash: '',
        status: 'active',
        isFirstLogin: true,
        requiresPasswordChange: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        loginAttempts: 0,
        failedAttempts: 0,
      );

      await _firestore
          .collection(_secretsCollection)
          .doc(userId)
          .set(secret.toMap());

      debugPrint('[SecondaryAuth] Initialized secondary auth for user: $userId');
      return true;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error initializing: $e');
      return false;
    }
  }

  /// Complete first-time password setup (admin/owner only)
  Future<bool> completeFirstLoginSetup({
    required String userId,
    required String newPassword,
  }) async {
    try {
      final secretSnap =
          await _firestore.collection(_secretsCollection).doc(userId).get();

      if (!secretSnap.exists) {
        return false;
      }

      final secret = SecondaryAuthSecret.fromMap(secretSnap.data()!);

      // Only allow first-time setup
      if (!secret.isFirstLogin) {
        return false;
      }

      // Validate password
      if (!SecondaryAuthPasswordService.isValidPassword(newPassword)) {
        return false;
      }

      final hash = SecondaryAuthPasswordService.hashPassword(newPassword);

      await _firestore.collection(_secretsCollection).doc(userId).update({
        'password_hash': hash,
        'is_first_login': false,
        'requires_password_change': false,
        'last_password_change_at': FieldValue.serverTimestamp(),
        'failed_attempts': 0,
        'locked_until': null,
      });

      await _auditService.logSecondaryAuthEvent(
        userId: userId,
        email: secret.email,
        eventType: SecondaryAuthEventType.passwordCreated,
        status: 'success',
        reason: 'first_login_setup',
      );

      debugPrint('[SecondaryAuth] First login setup completed for user: $userId');
      return true;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error completing setup: $e');
      return false;
    }
  }

  /// ADMIN ONLY: Issue password to employee/delivery agent
  /// CRITICAL: Employees/agents CANNOT issue their own passwords
  Future<String?> adminIssuePassword({
    required String targetUserId,
    required String targetEmail,
    required UserRole targetRole,
    required String adminId,
    String? customPassword,
  }) async {
    try {
      // Validate target role (only employees and delivery agents)
      if (targetRole == UserRole.customer) {
        debugPrint('[SecondaryAuth] Cannot issue password to customer');
        return null;
      }

      // Generate or use provided password
      final password = customPassword ?? SecondaryAuthPasswordService.generateRandomPassword();

      // Validate password if custom
      if (customPassword != null && !SecondaryAuthPasswordService.isValidPassword(password)) {
        return null;
      }

      final hash = SecondaryAuthPasswordService.hashPassword(password);

      // Create or update secret
      final secret = SecondaryAuthSecret(
        userId: targetUserId,
        email: targetEmail,
        role: targetRole.toString(),
        passwordHash: hash,
        status: 'active',
        isFirstLogin: false,
        requiresPasswordChange: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        loginAttempts: 0,
        failedAttempts: 0,
        createdBy: adminId,
      );

      await _firestore
          .collection(_secretsCollection)
          .doc(targetUserId)
          .set(secret.toMap());

      await _auditService.logSecondaryAuthEvent(
        userId: targetUserId,
        email: targetEmail,
        eventType: SecondaryAuthEventType.passwordCreated,
        status: 'success',
        actorId: adminId,
        reason: 'issued_by_admin',
      );

      debugPrint('[SecondaryAuth] Password issued by admin $adminId to user: $targetUserId');
      return password;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error issuing password: $e');
      return null;
    }
  }

  /// ADMIN ONLY: Reset password for employee/delivery agent
  Future<String?> adminResetPassword({
    required String targetUserId,
    required String adminId,
  }) async {
    try {
      final newPassword = SecondaryAuthPasswordService.generateRandomPassword();
      final hash = SecondaryAuthPasswordService.hashPassword(newPassword);

      await _firestore.collection(_secretsCollection).doc(targetUserId).update({
        'password_hash': hash,
        'status': 'active',
        'failed_attempts': 0,
        'locked_until': null,
        'last_password_change_at': FieldValue.serverTimestamp(),
      });

      final secret = await getSecondaryAuthSecret(targetUserId);

      await _auditService.logSecondaryAuthEvent(
        userId: targetUserId,
        email: secret?.email ?? 'unknown',
        eventType: SecondaryAuthEventType.passwordReset,
        status: 'success',
        actorId: adminId,
      );

      debugPrint('[SecondaryAuth] Password reset by admin $adminId for user: $targetUserId');
      return newPassword;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error resetting password: $e');
      return null;
    }
  }

  /// ADMIN ONLY: Revoke password
  Future<bool> adminRevokePassword({
    required String targetUserId,
    required String adminId,
  }) async {
    try {
      final secret = await getSecondaryAuthSecret(targetUserId);
      if (secret == null) return false;

      await _firestore.collection(_secretsCollection).doc(targetUserId).update({
        'status': 'revoked',
        'revoked_at': FieldValue.serverTimestamp(),
        'revoked_by': adminId,
      });

      await _auditService.logSecondaryAuthEvent(
        userId: targetUserId,
        email: secret.email,
        eventType: SecondaryAuthEventType.passwordRevoked,
        status: 'success',
        actorId: adminId,
      );

      debugPrint('[SecondaryAuth] Password revoked by admin $adminId for user: $targetUserId');
      return true;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error revoking password: $e');
      return false;
    }
  }

  /// ADMIN ONLY: Unlock account
  Future<bool> adminUnlockAccount({
    required String targetUserId,
    required String adminId,
  }) async {
    try {
      await _firestore.collection(_secretsCollection).doc(targetUserId).update({
        'failed_attempts': 0,
        'locked_until': null,
      });

      final secret = await getSecondaryAuthSecret(targetUserId);

      await _auditService.logSecondaryAuthEvent(
        userId: targetUserId,
        email: secret?.email ?? 'unknown',
        eventType: SecondaryAuthEventType.accountUnlocked,
        status: 'success',
        actorId: adminId,
      );

      debugPrint('[SecondaryAuth] Account unlocked by admin $adminId for user: $targetUserId');
      return true;
    } catch (e) {
      debugPrint('[SecondaryAuth] Error unlocking account: $e');
      return false;
    }
  }

  /// Get secondary auth secret
  Future<SecondaryAuthSecret?> getSecondaryAuthSecret(String userId) async {
    try {
      final snap =
          await _firestore.collection(_secretsCollection).doc(userId).get();

      if (!snap.exists) return null;
      return SecondaryAuthSecret.fromMap(snap.data()!);
    } catch (e) {
      debugPrint('[SecondaryAuth] Error getting secret: $e');
      return null;
    }
  }

  /// Check if user requires secondary auth
  bool userRequiresSecondaryAuth(UserRole role) => role != UserRole.customer;

  /// Check if secondary auth is setup complete
  Future<bool> isSecondaryAuthSetupComplete(String userId) async {
    try {
      final secret = await getSecondaryAuthSecret(userId);
      return secret != null && !secret.isFirstLogin;
    } catch (e) {
      return false;
    }
  }

  /// Logout from all devices
  Future<bool> logoutAllDevices(String userId) async {
    try {
      return await _sessionService.logoutAllDevices(userId);
    } catch (e) {
      debugPrint('[SecondaryAuth] Error logging out: $e');
      return false;
    }
  }

  /// Get user's active sessions
  Future<List<SecondaryAuthSession>> getUserActiveSessions(String userId) async {
    try {
      return await _sessionService.getUserActiveSessions(userId);
    } catch (e) {
      return [];
    }
  }

  /// Get user's audit log
  Future<List<SecondaryAuthAuditLog>> getUserAuditLog(String userId) async {
    try {
      return await _auditService.getUserAuditLog(userId);
    } catch (e) {
      return [];
    }
  }
}
