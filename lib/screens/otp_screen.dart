// ============================================================
//  OTPScreen — High-Fidelity OTP Verification Screen
//  Redesigned with custom shake feedback on wrong PIN,
//  an animated unlocking icon, a circular resend timer progress,
//  and staggered entrance animations.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import 'dart:math' as math;
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import '../widgets/animated_widgets.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String? role;

  const OTPScreen({super.key, required this.phoneNumber, this.role});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> with TickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();
  int _resendTimer = 60;
  bool _canResend = false;
  bool _otpComplete = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  late AnimationController _lockController;
  late Animation<double> _lockScaleAnim;

  final GlobalKey<ParticlesBurstState> _burstKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _startResendTimer();

    _otpController.addListener(() {
      final complete = _otpController.text.length == 6;
      if (complete != _otpComplete) {
        setState(() => _otpComplete = complete);
        if (complete) {
          _lockController.forward(); // Unlock animation
        } else {
          _lockController.reverse(); // Lock back
        }
      }
    });

    // Shake animation for error state
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: _ShakeCurve(),
      ),
    );

    // Lock animation for input complete
    _lockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _lockScaleAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _lockController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    _shakeController.dispose();
    _lockController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          if (_resendTimer > 0) {
            _resendTimer--;
            _startResendTimer();
          } else {
            _canResend = true;
          }
        });
      }
    });
  }

  String _routeForRole(UserRole role) {
    switch (role) {
      case UserRole.owner:
      case UserRole.shopOwner:
      case UserRole.branchManager:
      case UserRole.franchiseOwner:
        return '/owner';
      case UserRole.superAdmin:
      case UserRole.admin:
        return '/admin';
      case UserRole.rider:
      case UserRole.deliveryAgent:
      case UserRole.dispatcher:
        return '/delivery';
      case UserRole.employee:
      case UserRole.supplier:
        return '/employee';
      case UserRole.customer:
        return '/customer/home';
    }
  }

  void _verifyOTP() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    UserRole? parsedRole;
    if (widget.role != null) {
      parsedRole = UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == widget.role,
        orElse: () => UserRole.customer,
      );
    }

    final isValid = await authProvider.verifyOTP(
      _otpController.text,
      selectedRole: parsedRole,
    );

    if (isValid) {
      if (!mounted) return;
      // Fire particle burst before routing
      _burstKey.currentState?.trigger();
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      // Feature: High-Security Owner MFA Check
      if (authProvider.isMfaStepRequired) {
        _showMfaLinkDialog(authProvider);
      } else {
        if (mounted) {
          final returnPath = GoRouterState.of(context).uri.queryParameters['returnPath'];
          if (returnPath != null && returnPath.isNotEmpty) {
            context.go(returnPath);
          } else {
            // Route directly by the verified role — no splash re-init
            final user = authProvider.currentUser;
            final role = user?.role ?? parsedRole ?? UserRole.customer;
            context.go(_routeForRole(role));
          }
        }
      }
    } else {
      _shakeController.forward(from: 0.0);
      _showError(authProvider.errorMessage ?? 'Invalid OTP. Please try again.');
    }
  }

  void _showMfaLinkDialog(AuthProvider auth) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security, color: AppTheme.ownerAccent),
            SizedBox(width: 8),
            Text('Security Hardening'),
          ],
        ),
        content: const Text(
          'This phone number is registered as a Shop Owner. \n\n'
          'For business security, please link your Google Account to complete authorization.',
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              final mfaSuccess = await auth.linkGoogleAccount();
              if (!context.mounted) return;
              if (mfaSuccess) {
                Navigator.pop(context);
                context.go('/owner');
              }
            },
            icon: const Icon(Icons.login),
            label: const Text('Link Google Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.ownerAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _resendOTP() async {
    if (!_canResend) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.sendOTP(widget.phoneNumber);

    if (authProvider.errorMessage == null) {
      setState(() {
        _resendTimer = 60;
        _canResend = false;
        _otpController.clear();
      });
      _startResendTimer();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.grey900;
    final subTextColor = isDark ? Colors.white70 : AppTheme.grey600;

    final defaultPinTheme = PinTheme(
      width: 50,
      height: 56,
      textStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.grey800 : AppTheme.white,
        border: Border.all(color: isDark ? AppTheme.grey700 : AppTheme.grey300),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppTheme.primary, width: 2),
      borderRadius: BorderRadius.circular(12),
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppTheme.error, width: 2),
      borderRadius: BorderRadius.circular(12),
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.go('/login'),
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
        ),
      ),
      body: ParticlesBurst(
        key: _burstKey,
        radius: 120,
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // Lock Icon with Unlock morph on completion
              Center(
                child: FadeSlideIn(
                  duration: AppTheme.durationMedium,
                  child: ScaleTransition(
                    scale: _lockScaleAnim,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _otpComplete 
                            ? AppTheme.success.withValues(alpha: 0.15)
                            : AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: (_otpComplete ? AppTheme.success : AppTheme.primary)
                                .withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Icon(
                        _otpComplete ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                        size: 44,
                        color: _otpComplete ? AppTheme.success : AppTheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Title
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 100),
                child: Text(
                  'Verification',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              
              // Subtitle
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 150),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(fontSize: 16, color: subTextColor, fontFamily: 'Poppins'),
                    children: [
                      const TextSpan(text: 'Enter the 6-digit code sent to \n'),
                      TextSpan(
                        text: widget.phoneNumber,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.grey900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // OTP Input with Shake Animation on wrong OTP
              Center(
                child: FadeSlideIn(
                  duration: AppTheme.durationMedium,
                  delay: const Duration(milliseconds: 200),
                  child: AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (context, child) {
                      final dx = _shakeAnim.value * 24.0;
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: child,
                      );
                    },
                    child: Pinput(
                      length: 6,
                      controller: _otpController,
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: focusedPinTheme,
                      errorPinTheme: errorPinTheme,
                      keyboardType: TextInputType.number,
                      onCompleted: (value) {
                        if (value.length == 6) {
                          _verifyOTP();
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // Verify Button with Scale Bounce
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 250),
                child: ScaleBounce(
                  onTap: _otpComplete ? _verifyOTP : null,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _otpComplete ? AppTheme.primaryGradient : null,
                      color: _otpComplete ? null : AppTheme.grey300,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _otpComplete 
                          ? [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ] 
                          : [],
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'Verify & Proceed',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _otpComplete ? Colors.white : AppTheme.grey500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Circular Timer / Resend OTP Action
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 300),
                child: Center(
                  child: _canResend
                      ? ScaleBounce(
                          onTap: _resendOTP,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Text(
                              'Resend OTP',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CountdownRing(
                              seconds: _resendTimer,
                              size: 44,
                              ringColor: AppTheme.primary,
                              trackColor: AppTheme.primary.withValues(alpha: 0.12),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                              onComplete: () {
                                if (mounted) setState(() => _canResend = true);
                              },
                            ),
                            const SizedBox(width: 12),

                            Text(
                              'Resend code in ${_resendTimer}s',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white54 : AppTheme.grey600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),

              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 350),
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    "Change Phone Number",
                    style: TextStyle(
                      fontSize: 14,
                      color: subTextColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ), // ParticlesBurst
      ),
    );
  }
}

// Shake Curve custom implementation
class _ShakeCurve extends Curve {
  @override
  double transform(double t) {
    return math.sin(t * math.pi * 3 * 2);
  }
}
