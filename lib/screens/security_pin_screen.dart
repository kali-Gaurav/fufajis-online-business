// ============================================================
//  SecurityPinScreen — Production-grade PIN + Biometric entry
//  Redesigned with Warm Sunset Orange & Cream White theme,
//  staggered layout entrance, pulsing biometric button,
//  custom Pin theme, and ticking clock lockout screen.
// ============================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import '../services/device_security_service.dart';
import '../services/security_event_service.dart';
import '../widgets/animated_widgets.dart';

class SecurityPinScreen extends StatefulWidget {
  const SecurityPinScreen({super.key});

  @override
  State<SecurityPinScreen> createState() => _SecurityPinScreenState();
}

class _SecurityPinScreenState extends State<SecurityPinScreen> with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();

  bool _isFirstSetup = false;
  bool _isConfirming = false;
  String? _firstPin;
  bool _isDevicePending = false;
  bool _isLoading = false;
  bool _isLocked = false;
  int _lockoutRemaining = 0;
  Timer? _countdownTimer;
  String? _errorText;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _isFirstSetup = auth.currentUser?.pinHash == null;
    _isDevicePending = auth.isDeviceVerificationRequired;

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _shakeController, curve: _ShakeCurve()));

    _checkLockout();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pinController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkLockout() async {
    final status = await DeviceSecurityService.getLockoutStatus();
    if (!mounted) return;

    if (status.isLocked) {
      setState(() {
        _isLocked = true;
        _lockoutRemaining = status.remainingMinutes * 60;
      });
      _startCountdown();
    } else if (!_isFirstSetup && !_isDevicePending) {
      _tryBiometric();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _lockoutRemaining--);

      if (_lockoutRemaining <= 0) {
        t.cancel();
        final status = await DeviceSecurityService.getLockoutStatus();
        if (mounted) {
          setState(() => _isLocked = status.isLocked);
          if (!_isLocked) _tryBiometric();
        }
      }
    });
  }

  Future<void> _tryBiometric() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentUser?.biometricEnabled != true) return;

    final canBio = await DeviceSecurityService.canCheckBiometrics();
    if (!canBio) return;

    final success = await DeviceSecurityService.authenticateBiometrics(
      'Authenticate to access Fufaji Business',
    );

    if (!mounted) return;
    if (success) {
      _navigateHome(auth.currentUser?.role);
    } else {
      await SecurityEventService().logEvent(
        event: SecurityEventType.biometricFailure,
        userId: auth.currentUser?.id,
      );
    }
  }

  Future<void> _handlePinComplete(String pin) async {
    if (_isLocked) return;

    // ── FIRST-TIME SETUP ──
    if (_isFirstSetup) {
      if (!_isConfirming) {
        setState(() {
          _firstPin = pin;
          _isConfirming = true;
          _pinController.clear();
          _errorText = null;
        });
        return;
      }

      if (pin != _firstPin) {
        _shakeController.forward(from: 0.0);
        setState(() {
          _isConfirming = false;
          _firstPin = null;
          _pinController.clear();
          _errorText = 'PINs did not match. Please try again.';
        });
        return;
      }

      setState(() => _isLoading = true);
      final pinHash = DeviceSecurityService.hashPin(pin);
      await DeviceSecurityService.storePinHashLocally(pinHash);

      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser != null) {
        await auth.saveOwnerPin(auth.currentUser!.email ?? '', pinHash);
      }

      setState(() => _isLoading = false);
      if (!mounted) return;
      _navigateHome(auth.currentUser?.role);
      return;
    }

    // ── DAILY LOGIN VERIFICATION ──
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = auth.currentUser?.email;

    final valid = await DeviceSecurityService.validatePinLocally(pin, email);
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (valid) {
      await SecurityEventService().logEvent(
        event: SecurityEventType.loginSuccess,
        userId: auth.currentUser?.id,
        metadata: {'method': 'pin'},
      );
      _navigateHome(auth.currentUser?.role);
    } else {
      _pinController.clear();
      _shakeController.forward(from: 0.0);

      final status = await DeviceSecurityService.getLockoutStatus();
      if (!mounted) return;

      if (status.isLocked) {
        setState(() {
          _isLocked = true;
          _lockoutRemaining = status.remainingMinutes * 60;
          _errorText = null;
        });
        _startCountdown();

        await SecurityEventService().logEvent(
          event: SecurityEventType.pinLockout,
          userId: auth.currentUser?.id,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Too many failed attempts. Account locked for 30 minutes.'),
            backgroundColor: AppTheme.error,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        await SecurityEventService().logEvent(
          event: SecurityEventType.failedPin,
          userId: auth.currentUser?.id,
        );

        final attStr = await _readFailedAttempts();
        final remaining = 5 - attStr;
        setState(() {
          _errorText = 'Incorrect PIN. $remaining attempt(s) remaining.';
        });
      }
    }
  }

  Future<int> _readFailedAttempts() async {
    const storage = FlutterSecureStorageStub();
    return storage.readAttempts();
  }

  void _navigateHome(UserRole? role) {
    // If the user has email-based 2FA enabled, route through the
    // verification challenge before landing on their home screen.
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isMfaStepRequired) {
      context.go('/mfa-verify');
      return;
    }
    switch (role) {
      case UserRole.owner:
        context.go('/owner');
      case UserRole.superAdmin:
        context.go('/admin');
      default:
        context.go('/customer/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (auth.isDeviceVerificationRequired) {
      return _DevicePendingView(auth: auth);
    }

    if (_isLocked) {
      return _LockoutView(remainingSeconds: _lockoutRemaining);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.grey900;
    final subTextColor = isDark ? Colors.white70 : AppTheme.grey600;

    final defaultTheme = PinTheme(
      width: 50,
      height: 56,
      textStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.grey800 : AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.grey700 : AppTheme.grey300),
      ),
    );

    String title, subtitle;
    if (_isFirstSetup && !_isConfirming) {
      title = 'Create Security PIN';
      subtitle = 'Choose a 6-digit PIN to protect your business account.';
    } else if (_isFirstSetup && _isConfirming) {
      title = 'Confirm Your PIN';
      subtitle = 'Enter the same PIN again to confirm.';
    } else {
      title = 'Enter Security PIN';
      subtitle = 'Verify your identity to access the dashboard.';
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Animated icon container
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
                    child: const Icon(
                      Icons.lock_person_outlined,
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
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
              const SizedBox(height: 8),

              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 150),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: subTextColor, height: 1.4),
                ),
              ),
              const SizedBox(height: 48),

              // PIN input
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              else
                Center(
                  child: FadeSlideIn(
                    duration: AppTheme.durationMedium,
                    delay: const Duration(milliseconds: 200),
                    child: AnimatedBuilder(
                      animation: _shakeAnim,
                      builder: (context, child) {
                        final dx = _shakeAnim.value * 24.0;
                        return Transform.translate(offset: Offset(dx, 0), child: child);
                      },
                      child: Pinput(
                        length: 6,
                        controller: _pinController,
                        obscureText: true,
                        obscuringWidget: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        defaultPinTheme: defaultTheme,
                        focusedPinTheme: defaultTheme.copyDecorationWith(
                          border: Border.all(color: AppTheme.primary, width: 2),
                        ),
                        errorPinTheme: defaultTheme.copyDecorationWith(
                          border: Border.all(color: AppTheme.error, width: 2),
                        ),
                        onCompleted: _handlePinComplete,
                        autofocus: true,
                      ),
                    ),
                  ),
                ),

              // Error text
              if (_errorText != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.error, fontSize: 13),
                ),
              ],

              const SizedBox(height: 36),

              // Biometric pulse glow button
              if (!_isFirstSetup)
                Center(
                  child: FadeSlideIn(
                    duration: AppTheme.durationMedium,
                    delay: const Duration(milliseconds: 250),
                    child: Column(
                      children: [
                        PulseGlow(
                          glowColor: AppTheme.primary.withOpacity(0.2),
                          maxRadius: 10,
                          child: InkWell(
                            onTap: _tryBiometric,
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.fingerprint_rounded,
                                size: 40,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to use biometrics',
                          style: TextStyle(fontSize: 12, color: subTextColor),
                        ),
                      ],
                    ),
                  ),
                ),

              // Cancel button for setup confirmation
              if (_isFirstSetup && _isConfirming)
                TextButton(
                  onPressed: () => setState(() {
                    _isConfirming = false;
                    _firstPin = null;
                    _pinController.clear();
                    _errorText = null;
                  }),
                  child: const Text('← Back', style: TextStyle(color: AppTheme.grey500)),
                ),

              if (!_isFirstSetup)
                TextButton(
                  onPressed: () => context.push('/pin-reset'),
                  child: const Text(
                    'Forgot PIN?',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              if (!_isFirstSetup)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Email 2-Step Verification',
                        style: TextStyle(fontSize: 13, color: subTextColor),
                      ),
                      Switch(
                        value: auth.currentUser?.mfaEnabled ?? false,
                        activeThumbColor: AppTheme.primary,
                        onChanged: (value) async {
                          final ok = await auth.setMfaEnabled(value);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? (value
                                          ? 'Two-factor authentication enabled.'
                                          : 'Two-factor authentication disabled.')
                                    : (auth.errorMessage ?? 'Failed to update setting.'),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

              const Spacer(),
              TextButton(
                onPressed: () => auth.logout().then((_) => context.go('/login')),
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

// Lockout sub-widget with ticking timer
class _LockoutView extends StatefulWidget {
  final int remainingSeconds;
  const _LockoutView({required this.remainingSeconds});

  @override
  State<_LockoutView> createState() => _LockoutViewState();
}

class _LockoutViewState extends State<_LockoutView> with SingleTickerProviderStateMixin {
  late AnimationController _clockController;

  @override
  void initState() {
    super.initState();
    _clockController = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
  }

  @override
  void dispose() {
    _clockController.dispose();
    super.dispose();
  }

  String get _formatted {
    final m = widget.remainingSeconds ~/ 60;
    final s = widget.remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.grey900;
    final subTextColor = isDark ? Colors.white70 : AppTheme.grey600;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Spinning clock hand animation
              Center(
                child: RotationTransition(
                  turns: _clockController,
                  child: const Icon(Icons.lock_clock_outlined, size: 80, color: AppTheme.error),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Account Locked',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.error),
              ),
              const SizedBox(height: 12),
              Text(
                'Too many incorrect PIN attempts.\nYour account is temporarily locked for security.',
                textAlign: TextAlign.center,
                style: TextStyle(color: subTextColor, height: 1.5),
              ),
              const SizedBox(height: 36),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.grey800 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Try again in',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : AppTheme.grey500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatted,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              TextButton(
                onPressed: () {
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  auth.logout().then((_) => context.go('/login'));
                },
                child: const Text('Log Out', style: TextStyle(color: AppTheme.grey500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// New device pending sub-widget
class _DevicePendingView extends StatelessWidget {
  final AuthProvider auth;
  const _DevicePendingView({required this.auth});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.grey900;
    final subTextColor = isDark ? Colors.white70 : AppTheme.grey600;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.phonelink_lock_outlined, size: 80, color: AppTheme.warning),
              const SizedBox(height: 24),
              Text(
                'New Device Detected',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 12),
              Text(
                'This device has not been approved for Fufaji Business access.\n\n'
                'An approval request has been sent to the admin. You will receive '
                'access once it is approved.',
                textAlign: TextAlign.center,
                style: TextStyle(color: subTextColor, height: 1.5),
              ),
              const SizedBox(height: 36),
              ElevatedButton.icon(
                onPressed: auth.requestDeviceApproval,
                icon: const Icon(Icons.refresh),
                label: const Text('Resend Approval Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => auth.logout().then((_) => context.go('/login')),
                child: const Text('Log Out', style: TextStyle(color: AppTheme.grey500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FlutterSecureStorageStub {
  const FlutterSecureStorageStub();
  Future<int> readAttempts() async => 0;
}

class _ShakeCurve extends Curve {
  @override
  double transform(double t) {
    return math.sin(t * math.pi * 3 * 2);
  }
}
