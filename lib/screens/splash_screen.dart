// ============================================================
//  SplashScreen — Premium animated entry with auth resolution
//
//  Fix: ScaleTransition.scale requires Animation<double> but old
//  code passed double (.value). Now uses Transform.scale correctly.
//
//  Design: orange gradient bg, drifting blobs, sparkles,
//  glow-ring logo, typewriter brand name, slide-up tagline,
//  bouncing dots + animated progress bar.
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/guest_provider.dart';
import '../models/user_model.dart';
import '../providers/order_provider.dart';
import '../services/update_service.dart';
import '../services/lightning_deals_service.dart';
import '../services/cache_service.dart';
import '../services/permission_service.dart';
import '../widgets/fufaji_logo.dart';
import '../widgets/animated_widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Controllers
  late final AnimationController _masterCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _blobCtrl;
  late final AnimationController _progressCtrl;
  late final AnimationController _dotsCtrl;

  // Animations
  late final Animation<double> _bgFade;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _glowPulse;
  late final Animation<double> _blob1Y;
  late final Animation<double> _blob2Y;

  String _statusMessage = '';
  bool _showText = false;
  bool _showProgress = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _runAnimations();
    _bootSequence();
  }

  void _initAnimations() {
    _masterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _bgFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.0, 0.22, curve: Curves.easeIn),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.22, 0.50, curve: Curves.easeOut),
      ),
    );

    // Fix: was ScaleTransition(scale: anim.value) — wrong type.
    // We build via Transform.scale(scale: _logoScale.value) in AnimatedBuilder.
    _logoScale = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.22, 0.70, curve: Curves.elasticOut),
      ),
    );

    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.45),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.22, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.70, 1.0, curve: Curves.easeOut),
      ),
    );

    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.40),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.70, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _glowPulse = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    _blob1Y = Tween<double>(begin: -28.0, end: 28.0).animate(
      CurvedAnimation(parent: _blobCtrl, curve: Curves.easeInOut),
    );
    _blob2Y = Tween<double>(begin: 28.0, end: -28.0).animate(
      CurvedAnimation(parent: _blobCtrl, curve: Curves.easeInOut),
    );

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  Future<void> _runAnimations() async {
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    _masterCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 1060));
    if (!mounted) return;
    setState(() => _showText = true);

    await Future.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;
    setState(() => _showProgress = true);
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    _glowCtrl.dispose();
    _blobCtrl.dispose();
    _progressCtrl.dispose();
    _dotsCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootSequence() async {
    _setStatus('Checking updates...', 0.10);
    final canProceed = await UpdateService().handleVersionCheck(context);
    if (!canProceed) return;

    _setStatus('Loading catalog...', 0.30);
    LightningDealsService().fetchActiveDeals();
    await CacheService().init();

    PermissionService()
        .requestAllPermissions()
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => debugPrint('[Splash] Permission timeout'),
        )
        .catchError((e) => debugPrint('[Splash] Permission error: $e'));

    _setStatus('Preparing your experience...', 0.50);
    final guest = Provider.of<GuestProvider>(context, listen: false);
    await guest.init();

    _setStatus('Securing session...', 0.75);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = await auth.checkAuthStatus();
    if (!mounted) return;

    if (isLoggedIn) {
      _setStatus('Loading profile...', 0.90);
      int retries = 0;
      while (auth.currentUser == null && retries < 30) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        retries++;
      }

      if (auth.currentUser != null) {
        final user = auth.currentUser!;
        Provider.of<OrderProvider>(context, listen: false).loadOrders(user.id);
        if (!mounted) return;

        _setStatus('Welcome back!', 1.0);
        await Future.delayed(const Duration(milliseconds: 350));

        if (auth.isPinRequired || auth.isDeviceVerificationRequired) {
          context.go('/security-pin');
          return;
        }
        if (user.role == UserRole.customer &&
            (user.name == null || user.name!.isEmpty)) {
          context.go('/profile-creation');
          return;
        }
        _routeByRole(user.role);
      } else {
        debugPrint('[Splash] Profile load timeout');
        context.go('/login');
      }
    } else {
      _setStatus('Get ready!', 1.0);
      await Future.delayed(const Duration(milliseconds: 350));
      context.go('/login');
    }
  }

  void _setStatus(String msg, double progress) {
    if (!mounted) return;
    setState(() => _statusMessage = msg);
    _progressCtrl.animateTo(progress, curve: Curves.easeOut);
  }

  void _routeByRole(UserRole role) {
    switch (role) {
      case UserRole.owner:
        context.go('/owner');
      case UserRole.superAdmin:
        context.go('/admin');
      case UserRole.rider:
        context.go('/delivery');
      case UserRole.shopOwner:
        context.go('/owner');
      case UserRole.admin:
        context.go('/admin');
      case UserRole.deliveryAgent:
        context.go('/delivery');
      case UserRole.employee:
        context.go('/employee');
      case UserRole.customer:
        context.go('/customer/home');
      case UserRole.dispatcher:
        // TODO: Handle this case.
        throw UnimplementedError();
      case UserRole.branchManager:
        // TODO: Handle this case.
        throw UnimplementedError();
      case UserRole.supplier:
        // TODO: Handle this case.
        throw UnimplementedError();
      case UserRole.franchiseOwner:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFFF6B00),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _masterCtrl,
          _glowCtrl,
          _blobCtrl,
          _progressCtrl,
        ]),
        builder: (context, _) {
          return Stack(
            children: [
              // ── Gradient background ─────────────────────────
              Opacity(
                opacity: _bgFade.value,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFF6B00),
                        Color(0xFFFF8C42),
                        Color(0xFFE55B00),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),

              // ── Drifting blob top-right ──────────────────────
              Positioned(
                top: -90 + _blob1Y.value,
                right: -90,
                child: Opacity(
                  opacity: (_bgFade.value * 0.30).clamp(0.0, 1.0),
                  child: Container(
                    width: size.width * 0.75,
                    height: size.width * 0.75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),

              // ── Drifting blob bottom-left ────────────────────
              Positioned(
                bottom: size.height * 0.06 + _blob2Y.value,
                left: -110,
                child: Opacity(
                  opacity: (_bgFade.value * 0.22).clamp(0.0, 1.0),
                  child: Container(
                    width: size.width * 0.92,
                    height: size.width * 0.92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),

              // ── Small accent blob mid-right ──────────────────
              Positioned(
                top: size.height * 0.40,
                right: -50,
                child: Opacity(
                  opacity: (_bgFade.value * 0.18).clamp(0.0, 1.0),
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                ),
              ),

              // ── Sparkle accents ──────────────────────────────
              _buildSparkle(size, 0.12, 0.19),
              _buildSparkle(size, 0.86, 0.14),
              _buildSparkle(size, 0.50, 0.06),
              _buildSparkle(size, 0.08, 0.60),
              _buildSparkle(size, 0.90, 0.58),

              // ── Main content ─────────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 3),

                    // ── Logo with glow ring ─────────────────────
                    Opacity(
                      opacity: _logoOpacity.value,
                      child: FractionalTranslation(
                        translation: _logoSlide.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer glow bloom
                              Container(
                                width: 182,
                                height: 182,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(
                                        alpha: _glowPulse.value * 0.42,
                                      ),
                                      blurRadius: 48 * _glowPulse.value,
                                      spreadRadius: 10 * _glowPulse.value,
                                    ),
                                  ],
                                ),
                              ),
                              // Glowing ring
                              Container(
                                width: 164,
                                height: 164,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.10),
                                  border: Border.all(
                                    color: Colors.white.withValues(
                                      alpha:
                                          0.22 + _glowPulse.value * 0.18,
                                    ),
                                    width: 2,
                                  ),
                                ),
                              ),
                              // Logo card
                              const FufajiLogo(size: 136, onDark: true),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 38),

                    // ── Text section ────────────────────────────
                    if (_showText) ...[
                      const TypewriterText(
                        text: "Fufaji's Online",
                        speed: Duration(milliseconds: 44),
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.4,
                          shadows: [
                            Shadow(
                              color: Color(0x44000000),
                              blurRadius: 18,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Opacity(
                        opacity: _taglineFade.value,
                        child: FractionalTranslation(
                          translation: _taglineSlide.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.28),
                              ),
                            ),
                            child: const Text(
                              'आपकी अपनी दुकान  ·  Your own store',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 82),
                    ],

                    const Spacer(flex: 2),

                    // ── Progress section ────────────────────────
                    if (_showProgress) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 52),
                        child: Column(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: Text(
                                _statusMessage,
                                key: ValueKey(_statusMessage),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            AnimatedBuilder(
                              animation: _progressCtrl,
                              builder: (_, __) => ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: LinearProgressIndicator(
                                  value: _progressCtrl.value,
                                  minHeight: 3.5,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.22),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _BouncingDots(controller: _dotsCtrl),
                          ],
                        ),
                      ),
                    ],

                    const Spacer(flex: 1),

                    // ── Footer branding ─────────────────────────
                    Opacity(
                      opacity: (_bgFade.value * 0.50).clamp(0.0, 1.0),
                      child: const Padding(
                        padding: EdgeInsets.only(bottom: 22),
                        child: Text(
                          'Powered by Fufaji Technologies',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white54,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSparkle(Size size, double xFrac, double yFrac) {
    return Positioned(
      left: size.width * xFrac,
      top: size.height * yFrac,
      child: AnimatedBuilder(
        animation: _glowCtrl,
        builder: (_, __) => Opacity(
          opacity: (_bgFade.value * _glowPulse.value * 0.60).clamp(0.0, 1.0),
          child: const _SparkleIcon(size: 10),
        ),
      ),
    );
  }
}

// ── Sparkle icon ────────────────────────────────────────────────────────────
class _SparkleIcon extends StatelessWidget {
  final double size;
  const _SparkleIcon({this.size = 10});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 2, size * 2),
      painter: _SparklePainter(size: size),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final double size;
  const _SparklePainter({required this.size});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.80)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + math.cos(a) * size, cy + math.sin(a) * size),
        stroke,
      );
    }
    canvas.drawCircle(
      Offset(cx, cy),
      size * 0.30,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Bouncing dots ────────────────────────────────────────────────────────────
class _BouncingDots extends StatelessWidget {
  final AnimationController controller;
  const _BouncingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase = (controller.value + 1.0 - i / 3.0) % 1.0;
          final bounce = math.sin(phase * math.pi).clamp(0.0, 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: 9,
            height: 9,
            transform: Matrix4.translationValues(0, -10 * bounce, 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white
                  .withValues(alpha: 0.60 + 0.40 * bounce),
            ),
          );
        }),
      ),
    );
  }
}
