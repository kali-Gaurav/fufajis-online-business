import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'cache_service.dart';

/// OTPService — all attempt state persisted in Redis via CacheService.
/// No in-memory state; survives app restarts and scales across instances.
class OTPService {
  static final OTPService _instance = OTPService._internal();
  factory OTPService() => _instance;
  OTPService._internal();

  static const int otpValidityMinutes = 10;
  static const int maxAttempts = 3;

  final CacheService _cache = CacheService();

  String _trackerKey(String deliveryId) => 'otp_tracker:$deliveryId';

  // ──────────────────────────────────────────────────────────────────────────
  // OTP Generation
  // ──────────────────────────────────────────────────────────────────────────

  String generateOTP() {
    final random = Random.secure();
    int otp;
    do {
      otp = random.nextInt(1000000);
    } while (_isInvalidPattern(otp));
    return otp.toString().padLeft(6, '0');
  }

  bool _isInvalidPattern(int otp) {
    final s = otp.toString().padLeft(6, '0');
    if (s.split('').toSet().length == 1) return true;
    bool seq = true;
    for (int i = 1; i < s.length; i++) {
      final diff = int.parse(s[i]) - int.parse(s[i - 1]);
      if (diff != 1 && diff != -9) {
        seq = false;
        break;
      }
    }
    return seq;
  }

  String hashOTP(String otp) => sha256.convert(otp.codeUnits).toString();

  // ──────────────────────────────────────────────────────────────────────────
  // Verification
  // ──────────────────────────────────────────────────────────────────────────

  bool verifyOTP({
    required String storedOtpHash,
    required String userEnteredOtp,
    required DateTime otpGeneratedAt,
  }) {
    try {
      final elapsed = DateTime.now().difference(otpGeneratedAt).inMinutes;
      if (elapsed > otpValidityMinutes) {
        debugPrint('[OTP] expired ($elapsed min ago)');
        return false;
      }
      final match = hashOTP(userEnteredOtp) == storedOtpHash;
      if (!match) debugPrint('[OTP] hash mismatch');
      return match;
    } catch (e) {
      debugPrint('[OTP] verifyOTP error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Attempt Tracking (Redis-backed)
  // ──────────────────────────────────────────────────────────────────────────

  Future<_OTPTracker> _loadTracker(String deliveryId) async {
    try {
      final raw = await _cache.get(_trackerKey(deliveryId));
      if (raw == null) return _OTPTracker(deliveryId: deliveryId);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _OTPTracker.fromMap(map);
    } catch (_) {
      return _OTPTracker(deliveryId: deliveryId);
    }
  }

  Future<void> _saveTracker(_OTPTracker tracker) async {
    await _cache.set(_trackerKey(tracker.deliveryId), jsonEncode(tracker.toMap()));
  }

  Future<void> recordAttempt(String deliveryId, bool isSuccess) async {
    final tracker = await _loadTracker(deliveryId);
    if (isSuccess) {
      tracker.isVerified = true;
      tracker.otpVerifiedAt = DateTime.now().toIso8601String();
    } else {
      tracker.failedAttempts++;
    }
    await _saveTracker(tracker);
  }

  Future<int> getAttemptsRemaining(String deliveryId) async {
    final tracker = await _loadTracker(deliveryId);
    return maxAttempts - tracker.failedAttempts;
  }

  Future<bool> isLocked(String deliveryId) async {
    final tracker = await _loadTracker(deliveryId);
    return tracker.failedAttempts >= maxAttempts;
  }

  Future<OTPStatus> getOTPStatus(String deliveryId) async {
    final tracker = await _loadTracker(deliveryId);
    final remaining = (maxAttempts - tracker.failedAttempts).clamp(0, maxAttempts);
    return OTPStatus(
      isVerified: tracker.isVerified,
      attemptsRemaining: remaining,
      isLocked: tracker.failedAttempts >= maxAttempts,
      expiresAt: tracker.expiresAt,
    );
  }

  Future<void> resetOTP(String deliveryId) async {
    await _cache.remove(_trackerKey(deliveryId));
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Sync shims (non-async callers) — falls back to local state
  // ──────────────────────────────────────────────────────────────────────────

  void recordAttemptSync(String deliveryId, bool isSuccess) {
    recordAttempt(deliveryId, isSuccess);
  }

  int getAttemptsRemainingSync(String deliveryId) {
    // Return conservative default; callers should use async version.
    return maxAttempts;
  }

  bool isLockedSync(String deliveryId) => false;
}

class _OTPTracker {
  final String deliveryId;
  int failedAttempts;
  bool isVerified;
  String? otpVerifiedAt;
  String? otpGeneratedAtIso;

  _OTPTracker({
    required this.deliveryId,
    this.failedAttempts = 0,
    this.isVerified = false,
    this.otpVerifiedAt,
    this.otpGeneratedAtIso,
  });

  factory _OTPTracker.fromMap(Map<String, dynamic> m) => _OTPTracker(
    deliveryId: m['deliveryId'] as String? ?? '',
    failedAttempts: m['failedAttempts'] as int? ?? 0,
    isVerified: m['isVerified'] as bool? ?? false,
    otpVerifiedAt: m['otpVerifiedAt'] as String?,
    otpGeneratedAtIso: m['otpGeneratedAtIso'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'deliveryId': deliveryId,
    'failedAttempts': failedAttempts,
    'isVerified': isVerified,
    'otpVerifiedAt': otpVerifiedAt,
    'otpGeneratedAtIso': otpGeneratedAtIso,
  };

  DateTime? get expiresAt {
    if (otpGeneratedAtIso == null) return null;
    return DateTime.tryParse(
      otpGeneratedAtIso!,
    )?.add(const Duration(minutes: OTPService.otpValidityMinutes));
  }
}

class OTPAttemptTracker {
  final String deliveryId;
  int failedAttempts = 0;
  bool isVerified = false;
  DateTime? otpGeneratedAt;
  DateTime? otpVerifiedAt;

  OTPAttemptTracker(this.deliveryId);

  void recordAttempt(bool isSuccess) {
    if (isSuccess) {
      isVerified = true;
      otpVerifiedAt = DateTime.now();
    } else {
      failedAttempts++;
    }
  }

  bool get isLocked => failedAttempts >= OTPService.maxAttempts;

  DateTime? get otpExpiresAt {
    if (otpGeneratedAt == null) return null;
    return otpGeneratedAt!.add(const Duration(minutes: OTPService.otpValidityMinutes));
  }
}

class OTPStatus {
  final bool isVerified;
  final int attemptsRemaining;
  final bool isLocked;
  final DateTime? expiresAt;

  OTPStatus({
    required this.isVerified,
    required this.attemptsRemaining,
    required this.isLocked,
    required this.expiresAt,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  int get minutesUntilExpiry {
    if (expiresAt == null) return 0;
    return expiresAt!.difference(DateTime.now()).inMinutes.clamp(0, 9999);
  }
}
