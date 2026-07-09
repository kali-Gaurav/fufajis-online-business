import '../models/secondary_auth_models.dart';

/// Secondary Auth Rate Limiter - Progressive rate limiting logic
///
/// Progression:
/// Attempt 1-2: Allowed
/// Attempt 3: 5 minute delay
/// Attempt 4-6: 15 minute lock
/// Attempt 7+: Requires admin approval
class SecondaryAuthRateLimiter {
  // Progressive delay thresholds
  static const int _firstDelayThreshold = 3; // 3 attempts trigger 5-min delay
  static const int _lockThreshold = 6; // 6 attempts trigger 15-min lock
  static const int _adminApprovalThreshold = 10; // 10+ attempts need admin

  // Delay durations
  static const Duration _firstDelay = Duration(minutes: 5);
  static const Duration _lockDuration = Duration(minutes: 15);

  /// Calculate rate limit status based on failed attempts
  static RateLimitStatus calculateStatus(int failedAttempts, DateTime? lockedUntil) {
    // Check if currently in lock period
    if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
      final remainingSeconds = lockedUntil.difference(DateTime.now()).inSeconds;
      return RateLimitStatus(
        failedAttempts: failedAttempts,
        lockedUntil: lockedUntil,
        delaySeconds: remainingSeconds,
        requiresAdminApproval: failedAttempts >= _adminApprovalThreshold,
        status: 'locked',
      );
    }

    // Check if requires admin approval
    if (failedAttempts >= _adminApprovalThreshold) {
      return RateLimitStatus(
        failedAttempts: failedAttempts,
        lockedUntil: null,
        delaySeconds: 0,
        requiresAdminApproval: true,
        status: 'admin_approval_required',
      );
    }

    // Check if in lock phase
    if (failedAttempts >= _lockThreshold) {
      final newLockTime = DateTime.now().add(_lockDuration);
      return RateLimitStatus(
        failedAttempts: failedAttempts,
        lockedUntil: newLockTime,
        delaySeconds: _lockDuration.inSeconds,
        requiresAdminApproval: false,
        status: 'locked',
      );
    }

    // Check if in delay phase
    if (failedAttempts >= _firstDelayThreshold) {
      return RateLimitStatus(
        failedAttempts: failedAttempts,
        lockedUntil: null,
        delaySeconds: _firstDelay.inSeconds,
        requiresAdminApproval: false,
        status: 'delayed',
      );
    }

    // Allowed
    return RateLimitStatus(
      failedAttempts: failedAttempts,
      lockedUntil: null,
      delaySeconds: 0,
      requiresAdminApproval: false,
      status: 'allowed',
    );
  }

  /// Check if login attempt is allowed
  static bool isAttemptAllowed(int failedAttempts, DateTime? lockedUntil) {
    // If in lock period, not allowed
    if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
      return false;
    }

    // If requires admin approval, not allowed
    if (failedAttempts >= _adminApprovalThreshold) {
      return false;
    }

    return true;
  }

  /// Get delay in seconds before next attempt
  static int getDelaySeconds(int failedAttempts, DateTime? lockedUntil) {
    // If in lock, return remaining lock time
    if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
      return lockedUntil.difference(DateTime.now()).inSeconds;
    }

    // If in delay phase, return delay
    if (failedAttempts >= _firstDelayThreshold && failedAttempts < _lockThreshold) {
      return _firstDelay.inSeconds;
    }

    return 0;
  }

  /// Get status message for UI
  static String getStatusMessage(RateLimitStatus status) {
    switch (status.status) {
      case 'allowed':
        return 'Attempt ${status.failedAttempts + 1} of 10';
      case 'delayed':
        return 'Too many attempts. Please wait ${status.delaySeconds} seconds before trying again.';
      case 'locked':
        return 'Account locked. Please try again in ${status.remainingLockSeconds} seconds or contact admin.';
      case 'admin_approval_required':
        return 'Account locked. Contact admin to reset password.';
      default:
        return '';
    }
  }

  /// Log rate limit event for audit
  static Map<String, dynamic> getRateLimitAuditMetadata(
    RateLimitStatus status,
    int newFailedAttempts,
  ) {
    return {
      'rate_limit_status': status.status,
      'failed_attempts': newFailedAttempts,
      'delay_seconds': status.delaySeconds,
      'requires_admin_approval': status.requiresAdminApproval,
      'locked_until': status.lockedUntil?.toIso8601String(),
    };
  }

  /// Reset failed attempts
  static int resetFailedAttempts() {
    return 0;
  }

  /// Increment failed attempts with progressive consequences
  static int incrementFailedAttempts(int current) {
    return current + 1;
  }

  /// Calculate new lock time based on attempts
  static DateTime? calculateLockTime(int failedAttempts) {
    if (failedAttempts >= _lockThreshold) {
      return DateTime.now().add(_lockDuration);
    }
    return null;
  }

  /// Get progression stage (for UI display)
  static String getProgressionStage(int failedAttempts) {
    if (failedAttempts >= _adminApprovalThreshold) {
      return 'admin_approval_required';
    } else if (failedAttempts >= _lockThreshold) {
      return '15_minute_lock';
    } else if (failedAttempts >= _firstDelayThreshold) {
      return '5_minute_delay';
    } else {
      return 'normal';
    }
  }

  /// Get remaining attempts before lock
  static int getAttemptsBeforeLock(int failedAttempts) {
    final remaining = _lockThreshold - failedAttempts;
    return remaining > 0 ? remaining : 0;
  }

  /// Get remaining attempts before admin approval required
  static int getAttemptsBeforeAdminApproval(int failedAttempts) {
    final remaining = _adminApprovalThreshold - failedAttempts;
    return remaining > 0 ? remaining : 0;
  }

  /// Should show rate limit warning
  static bool shouldShowWarning(int failedAttempts) {
    return failedAttempts > 0 && failedAttempts < _lockThreshold;
  }

  /// Detailed progression info for debugging
  static Map<String, dynamic> getProgressionInfo(int failedAttempts, DateTime? lockedUntil) {
    return {
      'current_attempts': failedAttempts,
      'stage': getProgressionStage(failedAttempts),
      'is_locked': lockedUntil != null && DateTime.now().isBefore(lockedUntil),
      'lock_remaining_seconds': lockedUntil != null && DateTime.now().isBefore(lockedUntil)
          ? lockedUntil.difference(DateTime.now()).inSeconds
          : 0,
      'attempts_before_lock': getAttemptsBeforeLock(failedAttempts),
      'attempts_before_admin_approval': getAttemptsBeforeAdminApproval(failedAttempts),
      'thresholds': {
        'first_delay': _firstDelayThreshold,
        'lock': _lockThreshold,
        'admin_approval': _adminApprovalThreshold,
      },
    };
  }
}
