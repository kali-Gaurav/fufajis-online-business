// ============================================================
//  LoginScreen — Premium split-layout auth screen
//
//  Design:
//    • Top 42%: vivid orange hero with logo, brand name,
//      drifting blobs, and sparkle accents
//    • Bottom 58%: bright white curved panel for the form
//    • Animated role selector chips with role-colour accent
//    • Google button with coloured icon
//    • Phone input with +91 prefix
//    • Guest shortcut with subtle pulse
// ============================================================

import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/guest_provider.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import '../services/device_security_service.dart';
import '../services/security_event_service.dart';
import '../widgets/fufaji_logo.dart';
import '../widgets/animated_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _phoneFocus = FocusNode();

  UserRole _selectedRole = UserRole.customer;
  bool _isLoading = false;

  late final AnimationController _heroCtrl;
  late final AnimationController _formCtrl;
  late final AnimationController _blobCtrl;

  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _blobDrift;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _checkDeviceIntegrity();
  }

  void _initAnimations() {
    _heroCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _formCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _blobCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);

    _heroFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut));
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic));

    _formFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _formCtrl, curve: Curves.easeOut));
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _formCtrl, curve: Curves.easeOutCubic));

    _blobDrift = Tween<double>(
      begin: -18.0,
      end: 18.0,
    ).animate(CurvedAnimation(parent: _blobCtrl, curve: Curves.easeInOut));

    // Stagger hero before form
    _heroCtrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) _formCtrl.forward();
      });
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    _heroCtrl.dispose();
    _formCtrl.dispose();
    _blobCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkDeviceIntegrity() async {
    final isCompromised = await DeviceSecurityService.isDeviceRootedOrJailbroken();
    if (!mounted || !isCompromised) return;
    await SecurityEventService().logEvent(event: SecurityEventType.rootDetected);
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 28),
            SizedBox(width: 8),
            Text('Security Warning'),
          ],
        ),
        content: const Text(
          'This device appears to be rooted or jailbroken.\n\n'
          'Running Fufaji on a compromised device disables critical security controls.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleLogin() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!success && auth.errorMessage != null) {
      _showError(auth.errorMessage!);
    }
  }

  Future<void> _handleAppleLogin() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.signInWithApple();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!success && auth.errorMessage != null) {
      _showError(auth.errorMessage!);
    }
  }

  Future<void> _handlePhoneLogin() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final contact = '+91${_phoneController.text.trim()}';
    await auth.sendOTP(contact);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (auth.errorMessage == null) {
      final returnPath = GoRouterState.of(context).uri.queryParameters['returnPath'];
      String route = '/otp/${Uri.encodeComponent(contact)}?role=${_selectedRole.name}';
      if (returnPath != null && returnPath.isNotEmpty) {
        route += '&returnPath=${Uri.encodeComponent(returnPath)}';
      }
      context.push(route);
    } else {
      _showError(auth.errorMessage!);
    }
  }

  Future<void> _continueAsGuest() async {
    HapticFeedback.lightImpact();
    final guest = Provider.of<GuestProvider>(context, listen: false);
    await guest.enterGuestMode();
    if (!mounted) return;
    context.go('/customer/home');
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 28),
            SizedBox(width: 12),
            Text('Sign In Failed'),
          ],
        ),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleGoogleLogin();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final heroH = math.max(260.0, size.height * 0.36);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.white,
      body: Stack(
        children: [
          // ── Hero orange section ─────────────────────────────
          FadeTransition(
            opacity: _heroFade,
            child: SlideTransition(
              position: _heroSlide,
              child: AnimatedBuilder(
                animation: _blobCtrl,
                builder: (_, __) => Stack(
                  children: [
                    // Gradient bg
                    Container(
                      height: heroH + 60,
                      decoration: BoxDecoration(
                        gradient: isDark
                            ? const LinearGradient(
                                colors: [Color(0xFF1E1E1E), Color(0xFF252525)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFF6B00), Color(0xFFFF8C42), Color(0xFFE55B00)],
                                stops: [0.0, 0.55, 1.0],
                              ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(38),
                          bottomRight: Radius.circular(38),
                        ),
                      ),
                    ),

                    // Blob top-right
                    if (!isDark)
                      Positioned(
                        top: -60 + _blobDrift.value,
                        right: -60,
                        child: Opacity(
                          opacity: 0.28,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                        ),
                      ),

                    // Blob bottom-left
                    if (!isDark)
                      Positioned(
                        top: heroH - 80 - _blobDrift.value,
                        left: -50,
                        child: Opacity(
                          opacity: 0.20,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                      ),

                    // Hero content: logo + brand name
                    SizedBox(
                      height: heroH,
                      child: SafeArea(
                        bottom: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 8),
                              const FufajiLogo(size: 84, onDark: true),
                              const SizedBox(height: 14),
                              Text(
                                "Fufaji's Online",
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppTheme.primary : Colors.white,
                                  letterSpacing: 0.3,
                                  shadows: isDark
                                      ? null
                                      : const [
                                          Shadow(
                                            color: Color(0x44000000),
                                            blurRadius: 12,
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.primaryLight.withValues(alpha: 0.15)
                                      : Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark
                                        ? AppTheme.primary.withValues(alpha: 0.30)
                                        : Colors.white.withValues(alpha: 0.30),
                                  ),
                                ),
                                child: const Text(
                                  'आपकी अपनी दुकान',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Form panel (white card) ─────────────────────────
          Positioned(
            top: heroH - 20,
            left: 0,
            right: 0,
            bottom: 0,
            child: FadeTransition(
              opacity: _formFade,
              child: SlideTransition(
                position: _formSlide,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                        blurRadius: 24,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Role selector
                        _RoleSectionHeader(isDark: isDark),
                        const SizedBox(height: 12),
                        _RoleSelector(
                          selected: _selectedRole,
                          onChanged: (r) => setState(() => _selectedRole = r),
                        ),
                        const SizedBox(height: 24),

                        // Google sign-in
                        ScaleBounce(
                          onTap: _isLoading ? null : _handleGoogleLogin,
                          child: _GoogleButton(isDark: isDark, isLoading: _isLoading),
                        ),

                        // Apple sign-in (iOS only, per Apple guidelines)
                        if (Platform.isIOS) ...[
                          const SizedBox(height: 12),
                          ScaleBounce(
                            onTap: _isLoading ? null : _handleAppleLogin,
                            child: _AppleButton(isDark: isDark, isLoading: _isLoading),
                          ),
                        ],

                        const SizedBox(height: 12),
                        ScaleBounce(
                          onTap: _isLoading
                              ? null
                              : () => context.push('/auth/phone-login?role=${_selectedRole.name}'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.phone_android_rounded,
                                  color: AppTheme.primary,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Sign in with Phone',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : AppTheme.grey900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        ScaleBounce(
                          onTap: _isLoading
                              ? null
                              : () => context.push('/auth/email-login?role=${_selectedRole.name}'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.email_outlined,
                                  color: AppTheme.primary,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Sign in with Email',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : AppTheme.grey900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Phone section (customer only)
                        if (_selectedRole == UserRole.customer) ...[
                          const SizedBox(height: 20),
                          _OrDivider(isDark: isDark),
                          const SizedBox(height: 20),
                          _PhoneSection(
                            controller: _phoneController,
                            formKey: _formKey,
                            focusNode: _phoneFocus,
                            isDark: isDark,
                            isLoading: _isLoading,
                            onSubmit: _handlePhoneLogin,
                          ),
                          const SizedBox(height: 16),
                          _GuestButton(
                            isDark: isDark,
                            isLoading: _isLoading,
                            onTap: _continueAsGuest,
                          ),
                        ],

                        const SizedBox(height: 28),
                        _SecurityBadge(isDark: isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Role selector header ──────────────────────────────────────────────────────
class _RoleSectionHeader extends StatelessWidget {
  final bool isDark;
  const _RoleSectionHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      'I am signing in as:',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? AppTheme.grey300 : AppTheme.grey700,
        letterSpacing: 0.1,
      ),
    );
  }
}

// ── Role selector row ─────────────────────────────────────────────────────────
class _RoleSelector extends StatelessWidget {
  final UserRole selected;
  final ValueChanged<UserRole> onChanged;

  const _RoleSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Row 1: Customer & Rider
        Row(
          children: [
            Expanded(
              child: _RoleChip(
                label: 'Customer',
                labelHi: 'ग्राहक',
                icon: Icons.person_rounded,
                accentColor: AppTheme.primary,
                selected: selected == UserRole.customer,
                onTap: () => onChanged(UserRole.customer),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RoleChip(
                label: 'Rider',
                labelHi: 'डिलीवरी',
                icon: Icons.delivery_dining_rounded,
                accentColor: AppTheme.deliveryAccent,
                selected: selected == UserRole.rider,
                onTap: () => onChanged(UserRole.rider),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: Employee & Owner
        Row(
          children: [
            Expanded(
              child: _RoleChip(
                label: 'Employee',
                labelHi: 'कर्मचारी',
                icon: Icons.badge_rounded,
                accentColor: AppTheme.employeeAccent,
                selected: selected == UserRole.employee,
                onTap: () => onChanged(UserRole.employee),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RoleChip(
                label: 'Owner',
                labelHi: 'मालिक',
                icon: Icons.admin_panel_settings_rounded,
                accentColor: AppTheme.ownerAccent,
                selected: selected == UserRole.owner,
                onTap: () => onChanged(UserRole.owner),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final String labelHi;
  final IconData icon;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.labelHi,
    required this.icon,
    required this.accentColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScaleBounce(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accentColor, Color.lerp(accentColor, Colors.black, 0.18) ?? accentColor],
                )
              : null,
          color: selected ? null : (isDark ? const Color(0xFF2C2C2E) : AppTheme.grey50),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? accentColor
                : (isDark ? accentColor.withValues(alpha: 0.25) : AppTheme.grey200),
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected
                  ? Colors.white
                  : (isDark ? accentColor.withValues(alpha: 0.80) : AppTheme.grey600),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : (isDark ? Colors.white : AppTheme.grey900),
                  ),
                ),
                Text(
                  labelHi,
                  style: TextStyle(
                    fontSize: 10,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.80)
                        : (isDark ? accentColor.withValues(alpha: 0.70) : AppTheme.grey500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Google sign-in button ─────────────────────────────────────────────────────
class _GoogleButton extends StatelessWidget {
  final bool isDark;
  final bool isLoading;
  const _GoogleButton({required this.isDark, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF333333) : AppTheme.grey200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.06 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? Colors.white : AppTheme.grey900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Signing in...',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.grey900,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Coloured Google G icon drawn with CustomPaint
                const CustomPaint(size: Size(22, 22), painter: _GoogleGPainter()),
                const SizedBox(width: 12),
                Text(
                  'Continue with Google',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.grey900,
                  ),
                ),
              ],
            ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width / 2;
    final center = Offset(r, r);

    // Full circle clip
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));

    // Quadrant colours approximating the Google G
    const blue = Color(0xFF4285F4);
    const red = Color(0xFFEA4335);
    const yellow = Color(0xFFFBBC05);
    const green = Color(0xFF34A853);

    void drawQuadrant(Color c, double startAngle, double sweepAngle) {
      final p = Paint()..color = c;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), startAngle, sweepAngle, true, p);
    }

    drawQuadrant(blue, -math.pi / 2, math.pi / 2); // top
    drawQuadrant(red, -math.pi, math.pi / 2); // left
    drawQuadrant(yellow, math.pi / 2, math.pi / 2); // bottom
    drawQuadrant(green, 0, math.pi / 2); // right

    // White centre circle
    canvas.drawCircle(center, r * 0.62, Paint()..color = Colors.white);

    // Blue "G" stroke hint on right side
    final gPaint = Paint()
      ..color = blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.28
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r * 0.38),
      -math.pi / 6,
      -math.pi * 1.2,
      false,
      gPaint,
    );
    // Horizontal bar of G
    canvas.drawLine(Offset(r, r), Offset(r + r * 0.38, r), gPaint..strokeWidth = r * 0.24);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Apple sign-in button ──────────────────────────────────────────────────────
class _AppleButton extends StatelessWidget {
  final bool isDark;
  final bool isLoading;
  const _AppleButton({required this.isDark, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: isDark ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.06 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? Colors.black : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Signing in...',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apple, size: 22, color: isDark ? Colors.black : Colors.white),
                const SizedBox(width: 12),
                Text(
                  'Continue with Apple',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ],
            ),
    );
  }
}

// ── OR divider ────────────────────────────────────────────────────────────────
class _OrDivider extends StatelessWidget {
  final bool isDark;
  const _OrDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final c = isDark ? AppTheme.grey700 : AppTheme.grey300;
    return Row(
      children: [
        Expanded(child: Divider(color: c, thickness: 1.2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.grey600 : AppTheme.grey400,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Expanded(child: Divider(color: c, thickness: 1.2)),
      ],
    );
  }
}

// ── Phone section ─────────────────────────────────────────────────────────────
class _PhoneSection extends StatelessWidget {
  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final FocusNode focusNode;
  final bool isDark;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _PhoneSection({
    required this.controller,
    required this.formKey,
    required this.focusNode,
    required this.isDark,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mobile Number',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.grey300 : AppTheme.grey700,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: TextStyle(
              fontSize: 20,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.grey900,
            ),
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      '+91',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.grey300 : AppTheme.grey700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 1.2,
                      height: 22,
                      color: isDark ? AppTheme.grey700 : AppTheme.grey300,
                    ),
                  ],
                ),
              ),
              hintText: '00000 00000',
              hintStyle: TextStyle(
                color: isDark ? AppTheme.grey600 : AppTheme.grey400,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w400,
                fontSize: 18,
              ),
            ),
            validator: (v) => (v == null || v.length != 10) ? 'Enter valid 10-digit number' : null,
          ),
          const SizedBox(height: 18),
          // Get OTP button
          ScaleBounce(
            onTap: isLoading ? null : onSubmit,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B00), Color(0xFFFF8C42)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.38),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Get OTP',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Guest browse button ───────────────────────────────────────────────────────
class _GuestButton extends StatelessWidget {
  final bool isDark;
  final bool isLoading;
  final VoidCallback onTap;

  const _GuestButton({required this.isDark, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ScaleBounce(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : AppTheme.primaryLight.withValues(alpha: 0.18),
          border: Border.all(
            color: isDark ? AppTheme.grey800 : AppTheme.primary.withValues(alpha: 0.25),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.explore_rounded, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browse as Guest',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark ? Colors.white : AppTheme.grey900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No account needed — verify when ordering',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.grey500 : AppTheme.grey500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? AppTheme.grey600 : AppTheme.grey400),
          ],
        ),
      ),
    );
  }
}

// ── Security badge ────────────────────────────────────────────────────────────
class _SecurityBadge extends StatelessWidget {
  final bool isDark;
  const _SecurityBadge({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 14,
          color: isDark ? AppTheme.grey600 : AppTheme.grey400,
        ),
        const SizedBox(width: 6),
        Text(
          'Secure login · No password required',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppTheme.grey600 : AppTheme.grey400,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
