// ============================================================
//  PinResetScreen — "Forgot PIN?" recovery flow for Owners
//
//  Step 1: Confirm email, request an OTP reset code.
//  Step 2: Enter the 6-digit OTP sent to that email.
//  Step 3: Choose + confirm a new 6-digit security PIN.
//
//  Styled consistently with SecurityPinScreen (Pinput, AppTheme,
//  FadeSlideIn animations, Warm Sunset Orange & Cream White theme).
// ============================================================

import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../services/pin_reset_service.dart';
import '../../widgets/animated_widgets.dart';

class PinResetScreen extends StatefulWidget {
  const PinResetScreen({super.key});

  @override
  State<PinResetScreen> createState() => _PinResetScreenState();
}

enum _PinResetStep { email, otp, newPin, confirmPin, success }

class _PinResetScreenState extends State<PinResetScreen> {
  final _pinResetService = PinResetService();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _pinController = TextEditingController();

  _PinResetStep _step = _PinResetStep.email;
  bool _isLoading = false;
  String? _errorText;
  String? _firstNewPin;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _emailController.text = auth.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorText = 'Enter a valid email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final result = await _pinResetService.requestReset(email);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.success) {
        _step = _PinResetStep.otp;
      } else {
        _errorText = result.message ?? 'Failed to send reset code.';
      }
    });
  }

  Future<void> _verifyOtp(String otp) async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final result = await _pinResetService.verifyOtp(_emailController.text.trim(), otp);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.success) {
        _step = _PinResetStep.newPin;
      } else {
        _errorText = result.message ?? 'Incorrect code.';
        _otpController.clear();
      }
    });
  }

  void _handleNewPinComplete(String pin) {
    setState(() {
      _firstNewPin = pin;
      _step = _PinResetStep.confirmPin;
      _pinController.clear();
      _errorText = null;
    });
  }

  Future<void> _handleConfirmPinComplete(String pin) async {
    if (pin != _firstNewPin) {
      setState(() {
        _errorText = 'PINs do not match. Try again.';
        _step = _PinResetStep.newPin;
        _firstNewPin = null;
        _pinController.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result = await _pinResetService.resetPin(
      email: _emailController.text.trim(),
      newPin: pin,
      ownerName: auth.currentUser?.name,
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _isLoading = false;
        _step = _PinResetStep.success;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorText = result.message ?? 'Failed to reset PIN.';
        _step = _PinResetStep.newPin;
        _firstNewPin = null;
        _pinController.clear();
      });
    }
  }

  PinTheme _buildPinTheme(bool isDark, Color textColor) {
    return PinTheme(
      width: 50,
      height: 56,
      textStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.grey800 : AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.grey700 : AppTheme.grey300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.grey900;
    final subTextColor = isDark ? Colors.white70 : AppTheme.grey600;
    final defaultTheme = _buildPinTheme(isDark, textColor);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: FadeSlideIn(
                  duration: AppTheme.durationMedium,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(
                      _step == _PinResetStep.success
                          ? Icons.check_circle_outline
                          : Icons.lock_reset_outlined,
                      size: 48,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 100),
                child: Text(
                  _titleForStep(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 150),
                child: Text(
                  _subtitleForStep(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: subTextColor, height: 1.4),
                ),
              ),
              const SizedBox(height: 40),

              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              else
                _buildStepBody(isDark, textColor, defaultTheme),

              if (_errorText != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.error, fontSize: 13),
                ),
              ],

              const Spacer(),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  _step == _PinResetStep.success ? 'Done' : '← Back to PIN entry',
                  style: const TextStyle(color: AppTheme.grey400, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _titleForStep() {
    switch (_step) {
      case _PinResetStep.email:
        return 'Forgot Your PIN?';
      case _PinResetStep.otp:
        return 'Enter Reset Code';
      case _PinResetStep.newPin:
        return 'Set New PIN';
      case _PinResetStep.confirmPin:
        return 'Confirm New PIN';
      case _PinResetStep.success:
        return 'PIN Reset Successful';
    }
  }

  String _subtitleForStep() {
    switch (_step) {
      case _PinResetStep.email:
        return "We'll send a verification code to your registered email to confirm it's you.";
      case _PinResetStep.otp:
        return 'Enter the 6-digit code sent to ${_emailController.text.trim()}.';
      case _PinResetStep.newPin:
        return 'Choose a new 6-digit security PIN.';
      case _PinResetStep.confirmPin:
        return 'Enter the same PIN again to confirm.';
      case _PinResetStep.success:
        return 'Your security PIN has been updated. You can now use it to unlock the app.';
    }
  }

  Widget _buildStepBody(bool isDark, Color textColor, PinTheme defaultTheme) {
    switch (_step) {
      case _PinResetStep.email:
        return Column(
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'owner@example.com',
                filled: true,
                fillColor: isDark ? AppTheme.grey800 : AppTheme.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? AppTheme.grey700 : AppTheme.grey300),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _requestReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Send Reset Code', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );

      case _PinResetStep.otp:
        return Column(
          children: [
            Center(
              child: Pinput(
                length: 6,
                controller: _otpController,
                defaultPinTheme: defaultTheme,
                focusedPinTheme: defaultTheme.copyDecorationWith(
                  border: Border.all(color: AppTheme.primary, width: 2),
                ),
                errorPinTheme: defaultTheme.copyDecorationWith(
                  border: Border.all(color: AppTheme.error, width: 2),
                ),
                onCompleted: _verifyOtp,
                autofocus: true,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _requestReset,
              child: const Text('Resend code', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        );

      case _PinResetStep.newPin:
        return Center(
          child: Pinput(
            length: 6,
            controller: _pinController,
            obscureText: true,
            obscuringWidget: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
            ),
            defaultPinTheme: defaultTheme,
            focusedPinTheme: defaultTheme.copyDecorationWith(
              border: Border.all(color: AppTheme.primary, width: 2),
            ),
            errorPinTheme: defaultTheme.copyDecorationWith(
              border: Border.all(color: AppTheme.error, width: 2),
            ),
            onCompleted: _handleNewPinComplete,
            autofocus: true,
          ),
        );

      case _PinResetStep.confirmPin:
        return Center(
          child: Pinput(
            length: 6,
            controller: _pinController,
            obscureText: true,
            obscuringWidget: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
            ),
            defaultPinTheme: defaultTheme,
            focusedPinTheme: defaultTheme.copyDecorationWith(
              border: Border.all(color: AppTheme.primary, width: 2),
            ),
            errorPinTheme: defaultTheme.copyDecorationWith(
              border: Border.all(color: AppTheme.error, width: 2),
            ),
            onCompleted: _handleConfirmPinComplete,
            autofocus: true,
          ),
        );

      case _PinResetStep.success:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go('/security-pin'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continue to PIN entry', style: TextStyle(color: Colors.white)),
          ),
        );
    }
  }
}
