// ============================================================
//  MfaVerificationScreen — Email-based 2FA challenge step
//
//  Shown after Google Sign-In (and, for Owner/SuperAdmin, after
//  the Security PIN step) when the signed-in user has email-based
//  two-factor authentication enabled (UserModel.mfaEnabled).
//
//  Styled consistently with PinResetScreen / SecurityPinScreen
//  (Pinput, AppTheme, FadeSlideIn animations).
// ============================================================

import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/animated_widgets.dart';

class MfaVerificationScreen extends StatefulWidget {
  const MfaVerificationScreen({super.key});

  @override
  State<MfaVerificationScreen> createState() => _MfaVerificationScreenState();
}

class _MfaVerificationScreenState extends State<MfaVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;
  String? _infoText;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _navigateHome(UserRole? role) {
    switch (role) {
      case UserRole.owner:
        context.go('/owner');
      case UserRole.superAdmin:
        context.go('/admin');
      case UserRole.employee:
        context.go('/employee');
      default:
        context.go('/customer/home');
    }
  }

  Future<void> _verify(String code) async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.verifyMfaCode(code);

    if (!mounted) return;

    if (ok) {
      setState(() => _isLoading = false);
      _navigateHome(auth.currentUser?.role);
    } else {
      setState(() {
        _isLoading = false;
        _errorText = auth.errorMessage ?? 'Incorrect code. Try again.';
      });
      _otpController.clear();
    }
  }

  Future<void> _resend() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
      _infoText = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.resendMfaChallenge();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        _infoText = 'A new code has been sent to your email.';
      } else {
        _errorText = auth.errorMessage ?? 'Failed to resend code.';
      }
    });
  }

  PinTheme _buildPinTheme(bool isDark, Color textColor) {
    return PinTheme(
      width: 50,
      height: 56,
      textStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
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
    final auth = Provider.of<AuthProvider>(context, listen: false);

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
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(Icons.shield_outlined, size: 48, color: AppTheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 100),
                child: Text(
                  'Two-Step Verification',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
              const SizedBox(height: 8),
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 150),
                child: Text(
                  'Enter the 6-digit code we emailed to '
                  '${auth.currentUser?.email ?? 'your registered email'} to finish signing in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: subTextColor, height: 1.4),
                ),
              ),
              const SizedBox(height: 40),

              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              else
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
                    onCompleted: _verify,
                    autofocus: true,
                  ),
                ),

              if (_errorText != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.error, fontSize: 13),
                ),
              ],
              if (_infoText != null) ...[
                const SizedBox(height: 16),
                Text(
                  _infoText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.primary, fontSize: 13),
                ),
              ],

              const SizedBox(height: 16),
              TextButton(
                onPressed: _isLoading ? null : _resend,
                child: const Text('Resend code', style: TextStyle(color: AppTheme.primary)),
              ),

              const Spacer(),
              TextButton(
                onPressed: () => auth.logout().then((_) {
                  if (context.mounted) context.go('/login');
                }),
                child: const Text(
                  'Log Out',
                  style: TextStyle(color: AppTheme.grey400, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
