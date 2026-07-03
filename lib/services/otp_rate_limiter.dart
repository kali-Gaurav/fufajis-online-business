import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OtpRateLimitStatus {
  final bool allowed;
  final int attemptsRemaining;
  final int blockedUntilMinutes;

  OtpRateLimitStatus({
    required this.allowed,
    required this.attemptsRemaining,
    required this.blockedUntilMinutes,
  });
}

class OtpRateLimiter {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _keyAttempts = 'otp_attempts';
  static const String _keyLastAttempt = 'otp_last_attempt';
  static const String _keyBlockedUntil = 'otp_blocked_until';

  static const int maxAttempts = 5;
  static const int blockDurationMinutes = 60; // 1 hour block

  Future<OtpRateLimitStatus> checkRateLimit() async {
    final String? blockedUntilStr = await _secureStorage.read(key: _keyBlockedUntil);
    if (blockedUntilStr != null && blockedUntilStr.isNotEmpty) {
      final DateTime blockedUntil = DateTime.parse(blockedUntilStr);
      if (DateTime.now().isBefore(blockedUntil)) {
        final remainingMinutes = blockedUntil.difference(DateTime.now()).inMinutes;
        return OtpRateLimitStatus(
          allowed: false,
          attemptsRemaining: 0,
          blockedUntilMinutes: remainingMinutes,
        );
      } else {
        // Block expired, reset
        await _secureStorage.delete(key: _keyBlockedUntil);
        await _secureStorage.delete(key: _keyAttempts);
      }
    }

    // Check attempts rolling window
    final String? lastAttemptStr = await _secureStorage.read(key: _keyLastAttempt);
    if (lastAttemptStr != null && lastAttemptStr.isNotEmpty) {
      final DateTime lastAttempt = DateTime.parse(lastAttemptStr);
      // Reset attempts if more than 1 hour passed since last attempt
      if (DateTime.now().difference(lastAttempt).inMinutes > 60) {
        await _secureStorage.delete(key: _keyAttempts);
      }
    }

    final String? attemptsStr = await _secureStorage.read(key: _keyAttempts);
    final int attempts = attemptsStr != null ? int.parse(attemptsStr) : 0;
    final int remaining = maxAttempts - attempts;

    return OtpRateLimitStatus(
      allowed: remaining > 0,
      attemptsRemaining: remaining,
      blockedUntilMinutes: 0,
    );
  }

  Future<void> registerOtpAttempt() async {
    final String? attemptsStr = await _secureStorage.read(key: _keyAttempts);
    int attempts = attemptsStr != null ? int.parse(attemptsStr) : 0;
    attempts++;

    await _secureStorage.write(key: _keyAttempts, value: attempts.toString());
    await _secureStorage.write(key: _keyLastAttempt, value: DateTime.now().toIso8601String());

    if (attempts >= maxAttempts) {
      final DateTime blockedUntil = DateTime.now().add(
        const Duration(minutes: blockDurationMinutes),
      );
      await _secureStorage.write(key: _keyBlockedUntil, value: blockedUntil.toIso8601String());
    }
  }

  Future<void> resetLimits() async {
    await _secureStorage.delete(key: _keyAttempts);
    await _secureStorage.delete(key: _keyLastAttempt);
    await _secureStorage.delete(key: _keyBlockedUntil);
  }
}
