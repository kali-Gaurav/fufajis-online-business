// ============================================================
//  PinResetService — "Forgot PIN?" recovery workflow for Owners
//
//  The app has no traditional password — Owners authenticate with
//  Google Sign-In + a locally-stored 6-digit security PIN
//  (see DeviceSecurityService / SecurityPinScreen). If an owner
//  forgets that PIN, this service lets them reset it via an
//  email-delivered OTP, without losing access to their account.
//
//  Flow:
//    1. requestReset(email)        -> generates OTP, stores hash on
//                                      the owner's Firestore doc,
//                                      emails the code.
//    2. verifyOtp(email, otp)      -> checks the OTP (10 min validity,
//                                      max 3 attempts via OTPService).
//    3. resetPin(email, newPin)    -> hashes + stores the new PIN
//                                      (local secure storage + Firestore),
//                                      clears the OTP, sends a
//                                      confirmation email, and logs a
//                                      security event.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'device_security_service.dart';
import 'email_service.dart';
import 'otp_service.dart';
import 'security_event_service.dart';

class PinResetResult {
  final bool success;
  final String? message;
  const PinResetResult({required this.success, this.message});
}

class PinResetService {
  static final PinResetService _instance = PinResetService._internal();
  factory PinResetService() => _instance;
  PinResetService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OTPService _otpService = OTPService();
  final EmailService _emailService = EmailService();

  static const String _resetDeliveryPrefix = 'pin-reset-';

  /// Look up the owner document for [email]. Returns null if not found.
  Future<DocumentSnapshot<Map<String, dynamic>>?> _findOwnerDoc(String email) async {
    final snapshot = await _firestore
        .collection('owners')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first;
  }

  /// Step 1: Generate a fresh OTP, store its hash on the owner's record,
  /// and email it to the owner's registered address.
  Future<PinResetResult> requestReset(String email) async {
    try {
      final ownerDoc = await _findOwnerDoc(email);
      if (ownerDoc == null) {
        return const PinResetResult(
          success: false,
          message: 'No owner account found for this email.',
        );
      }

      // Reset any previous attempt tracking for this email.
      _otpService.resetOTP(_resetDeliveryPrefix + email);

      final otp = _otpService.generateOTP();
      final otpHash = _otpService.hashOTP(otp);
      final generatedAt = DateTime.now();

      await ownerDoc.reference.update({
        'pinResetOtpHash': otpHash,
        'pinResetOtpGeneratedAt': Timestamp.fromDate(generatedAt),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final ownerName = (ownerDoc.data()?['name'] as String?) ?? 'Owner';

      await _emailService.sendEmail(
        to: email,
        subject: 'Fufaji Business — Reset your security PIN',
        html: '''
          <p>Hi $ownerName,</p>
          <p>We received a request to reset the security PIN for your Fufaji Business owner account.</p>
          <p style="font-size:28px;font-weight:bold;letter-spacing:4px;">$otp</p>
          <p>This code is valid for ${OTPService.otpValidityMinutes} minutes. If you didn't request this, you can safely ignore this email — your PIN will not change.</p>
        ''',
        text: 'Your Fufaji Business PIN reset code is $otp. It is valid for '
            '${OTPService.otpValidityMinutes} minutes.',
        categories: const ['pin_reset'],
      );

      await SecurityEventService().logEvent(
        event: SecurityEventType.pinResetRequested,
        email: email,
      );

      return const PinResetResult(success: true, message: 'Reset code sent to your email.');
    } catch (e) {
      debugPrint('[PinResetService] requestReset error: $e');
      return const PinResetResult(success: false, message: 'Failed to send reset code. Try again.');
    }
  }

  /// Step 2: Verify the OTP entered by the owner.
  Future<PinResetResult> verifyOtp(String email, String otp) async {
    final deliveryId = _resetDeliveryPrefix + email;

    if (await _otpService.isLocked(deliveryId)) {
      return const PinResetResult(
        success: false,
        message: 'Too many incorrect attempts. Please request a new code.',
      );
    }

    try {
      final ownerDoc = await _findOwnerDoc(email);
      if (ownerDoc == null) {
        return const PinResetResult(success: false, message: 'No owner account found for this email.');
      }

      final data = ownerDoc.data();
      final storedHash = data?['pinResetOtpHash'] as String?;
      final generatedAtTs = data?['pinResetOtpGeneratedAt'] as Timestamp?;

      if (storedHash == null || generatedAtTs == null) {
        return const PinResetResult(
          success: false,
          message: 'No reset code was requested. Please request a new one.',
        );
      }

      final isValid = _otpService.verifyOTP(
        storedOtpHash: storedHash,
        userEnteredOtp: otp,
        otpGeneratedAt: generatedAtTs.toDate(),
      );

      _otpService.recordAttempt(deliveryId, isValid);

      if (!isValid) {
        await SecurityEventService().logEvent(
          event: SecurityEventType.otpFailure,
          email: email,
          metadata: const {'context': 'pin_reset'},
        );

        if (await _otpService.isLocked(deliveryId)) {
          await SecurityEventService().logEvent(
            event: SecurityEventType.otpLockout,
            email: email,
            metadata: const {'context': 'pin_reset'},
          );
          return const PinResetResult(
            success: false,
            message: 'Too many incorrect attempts. Please request a new code.',
          );
        }

        final remaining = await _otpService.getAttemptsRemaining(deliveryId);
        return PinResetResult(
          success: false,
          message: 'Incorrect code. $remaining attempt(s) remaining.',
        );
      }

      return const PinResetResult(success: true);
    } catch (e) {
      debugPrint('[PinResetService] verifyOtp error: $e');
      return const PinResetResult(success: false, message: 'Failed to verify code. Try again.');
    }
  }

  /// Step 3: After OTP verification, set the new PIN — locally and in
  /// Firestore — and clear the reset OTP.
  Future<PinResetResult> resetPin({
    required String email,
    required String newPin,
    String? ownerName,
  }) async {
    final deliveryId = _resetDeliveryPrefix + email;

    if (!(await _otpService.getOTPStatus(deliveryId)).isVerified) {
      return const PinResetResult(
        success: false,
        message: 'OTP not verified. Please verify your reset code first.',
      );
    }

    try {
      final ownerDoc = await _findOwnerDoc(email);
      if (ownerDoc == null) {
        return const PinResetResult(success: false, message: 'No owner account found for this email.');
      }

      final newPinHash = DeviceSecurityService.hashPin(newPin);

      await ownerDoc.reference.update({
        'pinHash': newPinHash,
        'pinResetOtpHash': FieldValue.delete(),
        'pinResetOtpGeneratedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update this device's locally-stored PIN hash and clear lockouts.
      await DeviceSecurityService.storePinHashLocally(newPinHash);
      await DeviceSecurityService.resetFailedPinAttempts();

      _otpService.resetOTP(deliveryId);

      await _emailService.sendPasswordChangedEmail(email: email, name: ownerName);

      await SecurityEventService().logEvent(
        event: SecurityEventType.pinResetSuccess,
        email: email,
      );

      return const PinResetResult(success: true, message: 'Your security PIN has been reset.');
    } catch (e) {
      debugPrint('[PinResetService] resetPin error: $e');
      await SecurityEventService().logEvent(
        event: SecurityEventType.pinResetFailed,
        email: email,
        metadata: {'error': e.toString()},
      );
      return const PinResetResult(success: false, message: 'Failed to reset PIN. Try again.');
    }
  }
}
