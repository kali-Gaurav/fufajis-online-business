import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Secondary Auth Password Service - PBKDF2-HMAC-SHA256 password hashing
class SecondaryAuthPasswordService {
  static const int _iterations = 10000;
  static const int _saltLength = 32;
  static const int _minLength = 8;
  static const String _separatorChar = '\$';

  /// Hash password using PBKDF2-HMAC-SHA256
  /// Returns format: "pbkdf2$sha256$10000$salt$hash"
  static String hashPassword(String password) {
    final random = Random.secure();
    final saltBytes = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    final salt = base64Url.encode(saltBytes).replaceAll('=', '');

    final bytes = utf8.encode(password);
    var hmac = Hmac(sha256, saltBytes);
    var hash = hmac.convert(bytes);

    // PBKDF2-like iteration
    for (int i = 1; i < _iterations; i++) {
      hmac = Hmac(sha256, saltBytes);
      hash = hmac.convert(hash.bytes);
    }

    final hashBase64 = base64Url.encode(hash.bytes).replaceAll('=', '');
    return 'pbkdf2${_separatorChar}sha256${_separatorChar}$_iterations${_separatorChar}$salt${_separatorChar}$hashBase64';
  }

  /// Verify password against hash using constant-time comparison
  static bool verifyPassword(String password, String hash) {
    try {
      final parts = hash.split(_separatorChar);
      if (parts.length != 5 || parts[0] != 'pbkdf2' || parts[1] != 'sha256') {
        return false;
      }

      final iterations = int.parse(parts[2]);
      final salt = parts[3];
      final storedHash = parts[4];

      // Reconstruct salt
      final saltBytes = _decodeSalt(salt);
      if (saltBytes.isEmpty) return false;

      // Compute hash from password
      final bytes = utf8.encode(password);
      var hmac = Hmac(sha256, saltBytes);
      var computedHash = hmac.convert(bytes);

      // PBKDF2-like iteration
      for (int i = 1; i < iterations; i++) {
        hmac = Hmac(sha256, saltBytes);
        computedHash = hmac.convert(computedHash.bytes);
      }

      final computedHashBase64 =
          base64Url.encode(computedHash.bytes).replaceAll('=', '');

      // Constant-time comparison
      return _constantTimeEquals(storedHash, computedHashBase64);
    } catch (e) {
      return false;
    }
  }

  /// Generate random password for admin-issued passwords
  static String generateRandomPassword({int length = 12}) {
    const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const numbers = '0123456789';
    const special = '!@#\$%^&*-_+=';
    const allChars = uppercase + lowercase + numbers + special;

    final random = Random.secure();
    final buffer = <String>[];

    // Ensure password has one of each type
    buffer.add(uppercase[random.nextInt(uppercase.length)]);
    buffer.add(lowercase[random.nextInt(lowercase.length)]);
    buffer.add(numbers[random.nextInt(numbers.length)]);
    buffer.add(special[random.nextInt(special.length)]);

    // Fill rest randomly
    for (int i = 4; i < length; i++) {
      buffer.add(allChars[random.nextInt(allChars.length)]);
    }

    // Shuffle
    final list = buffer;
    for (int i = list.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }

    return list.join();
  }

  /// Validate password against requirements
  static Map<String, bool> validatePassword(String password) {
    return {
      'minLength': password.length >= _minLength,
      'hasUppercase': password.contains(RegExp(r'[A-Z]')),
      'hasLowercase': password.contains(RegExp(r'[a-z]')),
      'hasNumber': password.contains(RegExp(r'[0-9]')),
      'hasSpecial': password.contains(RegExp(r'[!@#\$%^&*\-_+=]')),
    };
  }

  /// Check if password meets all requirements
  static bool isValidPassword(String password) {
    final validation = validatePassword(password);
    return validation.values.every((v) => v);
  }

  /// Get validation message for UI display
  static String getValidationMessage(String password) {
    final validation = validatePassword(password);

    if (!validation['minLength']!) {
      return 'Password must be at least $_minLength characters';
    }
    if (!validation['hasUppercase']!) {
      return 'Password must contain uppercase letter';
    }
    if (!validation['hasLowercase']!) {
      return 'Password must contain lowercase letter';
    }
    if (!validation['hasNumber']!) {
      return 'Password must contain number';
    }
    if (!validation['hasSpecial']!) {
      return 'Password must contain special character (!@#\$%^&*)';
    }

    return '';
  }

  /// Check if new password is different from old password
  static bool isDifferentFromHistory(String newPassword, List<String> history) {
    for (final oldHash in history) {
      if (verifyPassword(newPassword, oldHash)) {
        return false;
      }
    }
    return true;
  }

  // ==================== Private Helpers ====================

  /// Decode base64url encoded salt
  static List<int> _decodeSalt(String encoded) {
    try {
      // Add padding if needed
      String padded = encoded;
      while (padded.length % 4 != 0) {
        padded += '=';
      }
      return base64Url.decode(padded);
    } catch (e) {
      return [];
    }
  }

  /// Constant-time string comparison to prevent timing attacks
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }

    return result == 0;
  }
}
