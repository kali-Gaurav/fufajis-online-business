// ============================================================
//  MfaService — Email-based Two-Factor Authentication (2FA)
//
//  Adds an optional second factor on top of the existing
//  Google Sign-In + (Owner-only) Security PIN flow. Available
//  to Owner, SuperAdmin, and Employee roles.
//
//  Flow:
//    1. enableMfa(user)   -> sets mfaEnabled = true on the user's
//                             Firestore doc (users/{id}, plus
//                             owners/{...} if the role is owner).
//    2. disableMfa(user)  -> reverses the above.
//    3. sendChallenge(user) -> generates a 6-digit OTP, stores its
//                             hash + timestamp on the user doc,
//                             emails it (10-min validity via
//                             OTPService).
//    4. verifyChallenge(user, code) -> validates the OTP (max 3
//                             attempts), clears it on success, and
//                             logs the result via
//                             SecurityEventService.
// ============================================================

import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:otp/otp.dart';

import '../models/user_model.dart';
import 'email_service.dart';
import 'otp_service.dart';
import 'security_event_service.dart';

enum MfaMethod { email, totp }

class MfaResult {
  final bool success;
  final String? message;
  final String? totpSecret;
  final String? otpauthUri;
  final List<String>? backupCodes;
  const MfaResult({
    required this.success,
    this.message,
    this.totpSecret,
    this.otpauthUri,
    this.backupCodes,
  });
}

class MfaService {
  static final MfaService _instance = MfaService._internal();
  factory MfaService() => _instance;
  MfaService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OTPService _otpService = OTPService();
  final EmailService _emailService = EmailService();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _deliveryPrefix = 'mfa-';
  static const String _issuer = 'Fufaji Business';
  static const int _totpDigits = 6;
  static const int _totpInterval = 30;
  static const int _backupCodeCount = 8;

  String _deliveryId(String userId) => '$_deliveryPrefix$userId';

  // ── TOTP Setup ──────────────────────────────────────────────────────────

  /// Generates a TOTP secret and returns the otpauth:// URI for QR display.
  /// Does NOT commit to Firestore until [confirmTOTPSetup] succeeds.
  Future<MfaResult> initiateTOTPSetup({required String userId, required String userEmail}) async {
    try {
      final secret = OTP.randomSecret();
      final uri =
          'otpauth://totp/${Uri.encodeComponent(_issuer)}'
          ':${Uri.encodeComponent(userEmail)}'
          '?secret=$secret'
          '&issuer=${Uri.encodeComponent(_issuer)}'
          '&algorithm=SHA1&digits=$_totpDigits&period=$_totpInterval';
      await _storage.write(key: 'mfa_pending_secret:$userId', value: secret);
      return MfaResult(success: true, totpSecret: secret, otpauthUri: uri);
    } catch (e) {
      debugPrint('[MfaService] initiateTOTPSetup error: $e');
      return const MfaResult(success: false, message: 'Failed to generate TOTP secret.');
    }
  }

  /// Verifies the first TOTP code from the authenticator and, on success,
  /// commits the secret and backup codes to Firestore.
  Future<MfaResult> confirmTOTPSetup({
    required String userId,
    required String userEmail,
    required String code,
  }) async {
    try {
      final pending = await _storage.read(key: 'mfa_pending_secret:$userId');
      if (pending == null) {
        return const MfaResult(success: false, message: 'No pending setup. Start again.');
      }
      if (!_verifyTOTP(pending, code)) {
        return const MfaResult(success: false, message: 'Invalid code. Try again.');
      }
      final backupCodes = _generateBackupCodes();
      await _firestore.collection('users').doc(userId).update({
        'mfaEnabled': true,
        'mfaMethod': MfaMethod.totp.name,
        'mfaTotpSecret': pending,
        'mfaBackupCodes': backupCodes.map(_hashCode).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _storage.write(key: 'mfa_secret:$userId', value: pending);
      await _storage.delete(key: 'mfa_pending_secret:$userId');
      await SecurityEventService().logEvent(
        event: SecurityEventType.mfaEnabled,
        userId: userId,
        email: userEmail,
        metadata: const {'method': 'totp'},
      );
      return MfaResult(
        success: true,
        backupCodes: backupCodes,
        message: 'Authenticator app connected. Save your backup codes!',
      );
    } catch (e) {
      debugPrint('[MfaService] confirmTOTPSetup error: $e');
      return MfaResult(success: false, message: 'Setup failed: $e');
    }
  }

  /// Verify a TOTP code (or backup code) at login time.
  Future<MfaResult> verifyTOTPChallenge({required UserModel user, required String code}) async {
    try {
      final doc = await _firestore.collection('users').doc(user.id).get();
      final data = doc.data() ?? {};
      final secret = data['mfaTotpSecret'] as String?;
      if (secret == null) {
        return const MfaResult(success: false, message: 'TOTP not configured.');
      }
      if (_verifyTOTP(secret, code)) {
        return const MfaResult(success: true);
      }
      // Check backup codes
      final backups = List<String>.from(data['mfaBackupCodes'] as Iterable? ?? []);
      final hashed = _hashCode(code.trim());
      if (backups.contains(hashed)) {
        backups.remove(hashed);
        await _firestore.collection('users').doc(user.id).update({'mfaBackupCodes': backups});
        return const MfaResult(success: true, message: 'Backup code used.');
      }
      return const MfaResult(success: false, message: 'Invalid code.');
    } catch (e) {
      debugPrint('[MfaService] verifyTOTPChallenge error: $e');
      return const MfaResult(success: false, message: 'Verification failed.');
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  bool _verifyTOTP(String secret, String code) {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final offset in [-1, 0, 1]) {
      final ts = nowSec + offset * _totpInterval;
      final expected = OTP.generateTOTPCodeString(
        secret,
        ts,
        interval: _totpInterval,
        length: _totpDigits,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      if (expected == code.trim()) return true;
    }
    return false;
  }

  List<String> _generateBackupCodes() {
    final rng = Random.secure();
    return List.generate(_backupCodeCount, (_) {
      final a = rng.nextInt(100000).toString().padLeft(5, '0');
      final b = rng.nextInt(100000).toString().padLeft(5, '0');
      return '$a-$b';
    });
  }

  String _hashCode(String code) => sha256.convert(utf8.encode(code.trim())).toString();

  /// Enable email-based 2FA for [user]. Writes mfaEnabled=true to
  /// `users/{id}` and (for owner/superAdmin) to their `owners` doc.
  Future<MfaResult> enableMfa(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).update({
        'mfaEnabled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (user.role == UserRole.owner || user.role == UserRole.superAdmin) {
        await _updateOwnerDoc(user.email, {'mfaEnabled': true});
      }

      await SecurityEventService().logEvent(
        event: SecurityEventType.mfaEnabled,
        userId: user.id,
        email: user.email,
      );

      return const MfaResult(success: true, message: 'Two-factor authentication enabled.');
    } catch (e) {
      debugPrint('[MfaService] enableMfa error: $e');
      return const MfaResult(
        success: false,
        message: 'Failed to enable two-factor authentication.',
      );
    }
  }

  /// Disable email-based 2FA for [user].
  Future<MfaResult> disableMfa(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).update({
        'mfaEnabled': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (user.role == UserRole.owner || user.role == UserRole.superAdmin) {
        await _updateOwnerDoc(user.email, {'mfaEnabled': false});
      }

      await SecurityEventService().logEvent(
        event: SecurityEventType.mfaDisabled,
        userId: user.id,
        email: user.email,
      );

      return const MfaResult(success: true, message: 'Two-factor authentication disabled.');
    } catch (e) {
      debugPrint('[MfaService] disableMfa error: $e');
      return const MfaResult(
        success: false,
        message: 'Failed to disable two-factor authentication.',
      );
    }
  }

  Future<void> _updateOwnerDoc(String? email, Map<String, dynamic> data) async {
    if (email == null || email.isEmpty) return;
    try {
      final snap = await _firestore
          .collection('owners')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.update({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('[MfaService] _updateOwnerDoc error: $e');
    }
  }

  /// Step 1 of login-time MFA: generate + email a fresh OTP challenge.
  Future<MfaResult> sendChallenge(UserModel user) async {
    try {
      final deliveryId = _deliveryId(user.id);
      await _otpService.resetOTP(deliveryId);

      final otp = _otpService.generateOTP();
      final otpHash = _otpService.hashOTP(otp);
      final generatedAt = DateTime.now();

      await _firestore.collection('users').doc(user.id).update({
        'mfaOtpHash': otpHash,
        'mfaOtpGeneratedAt': Timestamp.fromDate(generatedAt),
      });

      final email = user.email;
      if (email != null && email.isNotEmpty) {
        await _emailService.sendEmail(
          to: email,
          subject: 'Fufaji Business — Your sign-in verification code',
          html:
              '''
            <p>Hi ${user.name ?? 'there'},</p>
            <p>Use the code below to finish signing in to your Fufaji Business account.</p>
            <p style="font-size:28px;font-weight:bold;letter-spacing:4px;">$otp</p>
            <p>This code is valid for ${OTPService.otpValidityMinutes} minutes. If you didn't try to sign in, you can ignore this email and consider changing your PIN.</p>
          ''',
          text:
              'Your Fufaji Business sign-in verification code is $otp. '
              'It is valid for ${OTPService.otpValidityMinutes} minutes.',
          categories: const ['mfa_challenge'],
        );
      }

      await SecurityEventService().logEvent(
        event: SecurityEventType.mfaChallengeSent,
        userId: user.id,
        email: user.email,
      );

      return const MfaResult(success: true, message: 'Verification code sent to your email.');
    } catch (e) {
      debugPrint('[MfaService] sendChallenge error: $e');
      return const MfaResult(
        success: false,
        message: 'Failed to send verification code. Try again.',
      );
    }
  }

  /// Step 2 of login-time MFA: verify the OTP entered by the user.
  Future<MfaResult> verifyChallenge(UserModel user, String code) async {
    final deliveryId = _deliveryId(user.id);

    if (await _otpService.isLocked(deliveryId)) {
      return const MfaResult(
        success: false,
        message: 'Too many incorrect attempts. Please request a new code.',
      );
    }

    try {
      final doc = await _firestore.collection('users').doc(user.id).get();
      final data = doc.data();
      final storedHash = data?['mfaOtpHash'] as String?;
      final generatedAtTs = data?['mfaOtpGeneratedAt'] as Timestamp?;

      if (storedHash == null || generatedAtTs == null) {
        return const MfaResult(
          success: false,
          message: 'No verification code was requested. Please request a new one.',
        );
      }

      final isValid = _otpService.verifyOTP(
        storedOtpHash: storedHash,
        userEnteredOtp: code,
        otpGeneratedAt: generatedAtTs.toDate(),
      );

      await _otpService.recordAttempt(deliveryId, isValid);

      if (!isValid) {
        await SecurityEventService().logEvent(
          event: SecurityEventType.mfaChallengeFailed,
          userId: user.id,
          email: user.email,
        );

        if (await _otpService.isLocked(deliveryId)) {
          await SecurityEventService().logEvent(
            event: SecurityEventType.otpLockout,
            userId: user.id,
            email: user.email,
            metadata: const {'context': 'mfa'},
          );
          return const MfaResult(
            success: false,
            message: 'Too many incorrect attempts. Please request a new code.',
          );
        }

        final remaining = await _otpService.getAttemptsRemaining(deliveryId);
        return MfaResult(
          success: false,
          message: 'Incorrect code. $remaining attempt(s) remaining.',
        );
      }

      // Clear the stored OTP now that it has been used.
      await _firestore.collection('users').doc(user.id).update({
        'mfaOtpHash': FieldValue.delete(),
        'mfaOtpGeneratedAt': FieldValue.delete(),
      });
      await _otpService.resetOTP(deliveryId);

      await SecurityEventService().logEvent(
        event: SecurityEventType.mfaChallengeSuccess,
        userId: user.id,
        email: user.email,
      );

      return const MfaResult(success: true);
    } catch (e) {
      debugPrint('[MfaService] verifyChallenge error: $e');
      return const MfaResult(success: false, message: 'Failed to verify code. Try again.');
    }
  }
}
