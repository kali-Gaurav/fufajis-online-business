import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LockoutStatus {
  final bool isLocked;
  final int remainingMinutes;
  LockoutStatus({required this.isLocked, required this.remainingMinutes});
}

class DeviceSecurityService {
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const String _keyDeviceId = 'secure_device_id';
  static const String _keyPinHash = 'secure_pin_hash';
  static const String _keyFailedAttempts = 'failed_pin_attempts';
  static const String _keyLockedUntil = 'pin_locked_until';

  static Future<String> getDeviceId() async {
    String? storedId = await _secureStorage.read(key: _keyDeviceId);
    if (storedId != null && storedId.isNotEmpty) return storedId;

    String newId = '';
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await _deviceInfoPlugin.androidInfo;
      newId = androidInfo.id;
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await _deviceInfoPlugin.iosInfo;
      newId = iosInfo.identifierForVendor ?? DateTime.now().millisecondsSinceEpoch.toString();
    } else {
      newId = DateTime.now().millisecondsSinceEpoch.toString();
    }
    
    await _secureStorage.write(key: _keyDeviceId, value: newId);
    return newId;
  }

  static Future<String> getDeviceName() async {
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await _deviceInfoPlugin.androidInfo;
      return '${androidInfo.manufacturer} ${androidInfo.model}';
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await _deviceInfoPlugin.iosInfo;
      return iosInfo.name;
    }
    return 'Unknown Device';
  }

  // --- CRYPTOGRAPHIC HELPERS ---

  static String generateRandomSalt([int length = 16]) {
    final Random rand = Random.secure();
    final List<int> saltBytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return hexEncode(saltBytes);
  }

  static String hexEncode(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int> hexDecode(String hex) {
    final List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  static Uint8List pbkdf2(String password, List<int> salt, int iterations, int keyLength) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final key = Uint8List(keyLength);
    int keyPos = 0;
    int blockIndex = 1;

    while (keyPos < keyLength) {
      final blockIndexBytes = Uint8List(4);
      ByteData.view(blockIndexBytes.buffer).setUint32(0, blockIndex, Endian.big);

      final saltBlock = Uint8List(salt.length + 4);
      saltBlock.setRange(0, salt.length, salt);
      saltBlock.setRange(salt.length, saltBlock.length, blockIndexBytes);

      var u = hmac.convert(saltBlock).bytes;
      var xor = List<int>.from(u);

      for (int i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (int j = 0; j < u.length; j++) {
          xor[j] ^= u[j];
        }
      }

      final len = (keyLength - keyPos) < xor.length ? (keyLength - keyPos) : xor.length;
      key.setRange(keyPos, keyPos + len, xor.sublist(0, len));
      keyPos += len;
      blockIndex++;
    }

    return key;
  }

  static String hashPinPBKDF2(String pin, String saltHex, {int iterations = 10000}) {
    final salt = hexDecode(saltHex);
    final key = pbkdf2(pin, salt, iterations, 32);
    return hexEncode(key);
  }

  static String hashPinLegacy(String pin) {
    var bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  // Set up pin using PBKDF2
  static String hashPin(String pin) {
    final String saltHex = generateRandomSalt();
    final String hashHex = hashPinPBKDF2(pin, saltHex);
    return 'pbkdf2\$10000\$$saltHex\$$hashHex';
  }

  static Future<void> storePinHashLocally(String pinHash) async {
    await _secureStorage.write(key: _keyPinHash, value: pinHash);
  }

  // --- PIN RATE LIMITING & LOCKOUT ---

  static Future<LockoutStatus> getLockoutStatus() async {
    final String? lockedUntilStr = await _secureStorage.read(key: _keyLockedUntil);
    if (lockedUntilStr != null && lockedUntilStr.isNotEmpty) {
      try {
        final DateTime lockedUntil = DateTime.parse(lockedUntilStr);
        if (DateTime.now().isBefore(lockedUntil)) {
          final remainingSeconds = lockedUntil.difference(DateTime.now()).inSeconds;
          final remainingMinutes = (remainingSeconds / 60).ceil();
          return LockoutStatus(isLocked: true, remainingMinutes: remainingMinutes);
        } else {
          // Lock expired, reset failed attempts
          await _secureStorage.delete(key: _keyLockedUntil);
          await _secureStorage.write(key: _keyFailedAttempts, value: '0');
        }
      } catch (_) {
        await _secureStorage.delete(key: _keyLockedUntil);
      }
    }
    return LockoutStatus(isLocked: false, remainingMinutes: 0);
  }

  static Future<void> registerFailedPinAttempt() async {
    final String? attemptsStr = await _secureStorage.read(key: _keyFailedAttempts);
    int attempts = (attemptsStr != null) ? int.parse(attemptsStr) : 0;
    attempts++;

    if (attempts >= 5) {
      final DateTime lockedUntil = DateTime.now().add(const Duration(minutes: 30));
      await _secureStorage.write(key: _keyLockedUntil, value: lockedUntil.toIso8601String());
      await _secureStorage.write(key: _keyFailedAttempts, value: attempts.toString());
    } else {
      await _secureStorage.write(key: _keyFailedAttempts, value: attempts.toString());
    }
  }

  static Future<void> resetFailedPinAttempts() async {
    await _secureStorage.write(key: _keyFailedAttempts, value: '0');
    await _secureStorage.delete(key: _keyLockedUntil);
  }

  static Future<bool> validatePinLocally(String pin, [String? email]) async {
    // Check if device is locked
    final lockout = await getLockoutStatus();
    if (lockout.isLocked) return false;

    String? storedHash = await _secureStorage.read(key: _keyPinHash);
    
    // If not found locally (e.g. newly approved device), fetch from Firestore if email is provided
    if (storedHash == null && email != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('owners')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (snapshot.docs.isNotEmpty) {
          storedHash = snapshot.docs.first.data()['pinHash'] as String?;
          if (storedHash != null && storedHash.isNotEmpty) {
            // Write it to local secure storage for future daily offline logins
            await storePinHashLocally(storedHash);
          }
        }
      } catch (e) {
        print('Error fetching pinHash from Firestore: $e');
      }
    }

    if (storedHash == null) return false;

    bool isValid = false;
    if (storedHash.startsWith('pbkdf2\$')) {
      final parts = storedHash.split('\$');
      if (parts.length == 4) {
        final int iterations = int.parse(parts[1]);
        final String saltHex = parts[2];
        final String expectedHash = parts[3];
        final computedHash = hashPinPBKDF2(pin, saltHex, iterations: iterations);
        isValid = (computedHash == expectedHash);
      }
    } else {
      // Fallback verification for older SHA256 pins
      isValid = (hashPinLegacy(pin) == storedHash);
      
      // Auto-upgrade legacy hash to PBKDF2 locally and in Firestore upon successful login
      if (isValid && email != null) {
        final upgradedHash = hashPin(pin);
        await storePinHashLocally(upgradedHash);
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('owners')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          if (snapshot.docs.isNotEmpty) {
            await snapshot.docs.first.reference.update({
              'pinHash': upgradedHash,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          print('Error upgrading legacy pinHash in Firestore: $e');
        }
      }
    }

    if (isValid) {
      await resetFailedPinAttempts();
    } else {
      await registerFailedPinAttempt();
    }

    return isValid;
  }

  // --- BIOMETRICS ---

  static Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  static Future<bool> authenticateBiometrics(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  // --- ROOT / JAILBREAK INTEGRITY DETECTION ---

  static Future<bool> isDeviceRootedOrJailbroken() async {
    final List<String> androidPaths = [
      '/system/app/Superuser.apk',
      '/sbin/su',
      '/system/bin/su',
      '/system/xbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/data/local/su',
      '/su/bin/su',
    ];

    final List<String> iosPaths = [
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/private/var/lib/apt/',
    ];

    if (Platform.isAndroid) {
      for (final path in androidPaths) {
        if (File(path).existsSync()) return true;
      }
    } else if (Platform.isIOS) {
      for (final path in iosPaths) {
        if (File(path).existsSync()) return true;
      }

      // Sandbox write check on iOS
      try {
        final file = File('/private/jailbreak_test.txt');
        file.writeAsStringSync("Jailbreak Check");
        file.deleteSync();
        return true;
      } catch (_) {
        // sandbox active
      }
    }

    return false;
  }
}
