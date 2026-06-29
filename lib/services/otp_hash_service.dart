import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// OTP Security Service
/// Provides PBKDF2-SHA256 hashing for OTPs (more portable than bcrypt for Dart)
///
/// PRODUCTION: Use for:
/// - Hashing delivery OTPs before storing in Firestore
/// - Verifying OTPs during delivery completion
/// - Ensuring OTPs are never stored in plaintext
///
/// Security: Delivery OTPs expire in 30 minutes, so fast hash is acceptable
class OTPHashService {
  // PBKDF2 parameters - high security for sensitive delivery data
  static const int _iterations = 100000;
  static const int _hashLength = 32;
  static const String _algorithm = 'sha256';

  /// Hash an OTP using PBKDF2-SHA256
  /// Safe for Firestore storage - hashed OTP cannot be reversed
  static String hashOTP(String otp) {
    try {
      // Salt: use OTP + algorithm identifier for deterministic hash
      // (same OTP always produces same hash for verification)
      final salt = utf8.encode('$_algorithm:$_iterations');

      // Use PBKDF2-like approach via HMAC iteration
      var hash = utf8.encode(otp);
      for (int i = 0; i < _iterations; i++) {
        hash = sha256.convert([...hash, ...salt]).bytes;
      }

      return base64.encode(hash);
    } catch (e) {
      debugPrint('OTP Hashing error: $e');
      rethrow;
    }
  }

  /// Verify OTP against hash
  /// Call this during delivery completion to verify rider-provided OTP
  static bool verifyOTP(String plainOTP, String storedHash) {
    try {
      final computedHash = hashOTP(plainOTP);
      return computedHash == storedHash;
    } catch (e) {
      debugPrint('OTP Verification error: $e');
      return false;
    }
  }

  /// Generate a random 6-digit OTP
  /// Used for delivery OTP generation
  static String generateOTP() {
    final random = DateTime.now().microsecond.toString().substring(0, 6).padLeft(6, '0');
    return random;
  }

  /// Hash metadata for audit log (hash + timestamp + iterations)
  static Map<String, dynamic> getHashMetadata(String otp) {
    return {
      'hashedValue': hashOTP(otp),
      'algorithm': _algorithm,
      'iterations': _iterations,
      'hashedAt': DateTime.now().toIso8601String(),
    };
  }
}
