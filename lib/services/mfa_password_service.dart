import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Service for MFA password hashing and verification
///
/// Uses PBKDF2-HMAC-SHA256 for secure password storage
class MFAPasswordService {
  static const int iterations = 10000;
  static const int saltLength = 32;
  static const int keyLength = 32;
  static const String algorithm = 'pbkdf2';
  static const String hashFunction = 'sha256';

  /// Hash a password using PBKDF2-HMAC-SHA256
  ///
  /// Returns: "pbkdf2$sha256$10000$salt$hash"
  static String hashPassword(String password) {
    try {
      final random = Random.secure();
      final saltBytes = List<int>.generate(saltLength, (i) => random.nextInt(256));
      final salt = base64Url.encode(saltBytes).replaceAll('=', '');

      // PBKDF2 implementation
      final hash = _pbkdf2(utf8.encode(password), saltBytes, iterations, keyLength);
      final hashBase64 = base64Url.encode(hash).replaceAll('=', '');

      return '$algorithm\$$hashFunction\$$iterations\$$salt\$$hashBase64';
    } catch (e) {
      debugPrint('[MFAPasswordService] Error hashing password: $e');
      return '';
    }
  }

  /// Verify a password against a hash
  static bool verifyPassword(String password, String hash) {
    try {
      final parts = hash.split('\$');
      if (parts.length != 5) return false;

      final algo = parts[0];
      final hashFunc = parts[1];
      final iters = int.tryParse(parts[2]) ?? 0;
      final saltStr = parts[3];
      final expectedHash = parts[4];

      if (algo != algorithm || hashFunc != hashFunction) return false;

      // Decode salt
      final saltStr2 = saltStr + '=' * (4 - saltStr.length % 4);
      final saltBytes = base64Url.decode(saltStr2);

      // Hash the input password
      final computedHash = _pbkdf2(utf8.encode(password), saltBytes, iters, keyLength);
      final computedHashStr = base64Url.encode(computedHash).replaceAll('=', '');

      // Constant-time comparison
      return _constantTimeCompare(computedHashStr, expectedHash);
    } catch (e) {
      debugPrint('[MFAPasswordService] Error verifying password: $e');
      return false;
    }
  }

  /// PBKDF2 key derivation using HMAC-SHA256
  static List<int> _pbkdf2(List<int> password, List<int> salt, int iterations, int keyLength) {
    var result = List<int>.filled(keyLength, 0);
    var hmac = Hmac(sha256, password);

    // Generate U1
    var input = <int>[...salt, 0, 0, 0, 1];
    var u = hmac.convert(input).bytes.toList();
    var result_i = List<int>.from(u);

    // Generate U2 through Un
    for (int i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes.toList();
      for (int j = 0; j < result_i.length; j++) {
        result_i[j] ^= u[j];
      }
    }

    // Copy to result
    for (int i = 0; i < keyLength && i < result_i.length; i++) {
      result[i] = result_i[i];
    }

    return result;
  }

  /// Constant-time string comparison
  static bool _constantTimeCompare(String a, String b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Generate random password for admin to issue
  ///
  /// Format: 12 characters mix of uppercase, lowercase, numbers, special chars
  static String generateRandomPassword({int length = 12}) {
    const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const numbers = '0123456789';
    const special = '!@#\$%^&*-_=+';
    const allChars = uppercase + lowercase + numbers + special;

    final random = Random.secure();
    final password = <String>[];

    // Ensure at least one of each type
    password.add(uppercase[random.nextInt(uppercase.length)]);
    password.add(lowercase[random.nextInt(lowercase.length)]);
    password.add(numbers[random.nextInt(numbers.length)]);
    password.add(special[random.nextInt(special.length)]);

    // Fill rest with random chars
    while (password.length < length) {
      password.add(allChars[random.nextInt(allChars.length)]);
    }

    // Shuffle
    password.shuffle(random);
    return password.join();
  }

  /// Validate password complexity
  ///
  /// Requirements:
  /// - At least 8 characters
  /// - At least 1 uppercase letter
  /// - At least 1 lowercase letter
  /// - At least 1 number
  /// - At least 1 special character
  static Map<String, bool> validatePassword(String password) {
    return {
      'minLength': password.length >= 8,
      'hasUppercase': password.contains(RegExp(r'[A-Z]')),
      'hasLowercase': password.contains(RegExp(r'[a-z]')),
      'hasNumber': password.contains(RegExp(r'[0-9]')),
      'hasSpecial': password.contains(RegExp(r'[!@#\$%^&*()\-_=+]')),
    };
  }

  /// Check if all requirements are met
  static bool isValidPassword(String password) {
    final validation = validatePassword(password);
    return validation.values.every((element) => element);
  }

  /// Get validation message for password
  static String getValidationMessage(String password) {
    final validation = validatePassword(password);
    final missing = <String>[];

    if (!validation['minLength']!) missing.add('8+ characters');
    if (!validation['hasUppercase']!) missing.add('uppercase letter');
    if (!validation['hasLowercase']!) missing.add('lowercase letter');
    if (!validation['hasNumber']!) missing.add('number');
    if (!validation['hasSpecial']!) missing.add('special character (!@#\$%^&*)');

    if (missing.isEmpty) return '';
    return 'Password must have: ${missing.join(", ")}';
  }
}
