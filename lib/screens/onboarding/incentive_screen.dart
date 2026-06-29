// ============================================================
//  IncentiveScreen — Customer onboarding (Screen 4/4)
//
//  Design: Welcome discount & first order incentive
//  - Display: "Welcome! Get ₹50 off your first order"
//  - Show discount code: "WELCOME50"
//  - Call-to-action: "Start Shopping" button
//  - Animate incentive reveal
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;

class IncentiveScreen extends StatefulWidget {
  const IncentiveScreen({super.key});

  @override
  State<IncentiveScreen> createState() => _IncentiveScreenState();
}

class _IncentiveScreenState extends State<IncentiveScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final AnimationController _scaleCtrl;
  late final AnimationController _bounceCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _bounceAnim;

  bool _codeCopied = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _runAnimations();
  }

  void _initAnimations() {
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
    );

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut),
    );

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );
  }

  Future<void> _runAnimations() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _fadeCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _scaleCtrl.forward();
  }

  void _copyCode() {
    setState(() => _codeCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied to clipboard!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _codeCopied = false);
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _scaleCtrl.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: AnimatedBuilder(
        animation: Listenable.merge([_fadeCtrl, _scaleCtrl, _bounceCtrl]),
        builder: (context, _) {
          return Stack(
            children: [
              // ── Background decorative elements ──────────────
              Positioned(
                top: -80,
                right: -80,
                child: Opacity(
                  opacity: (_fadeAnim.value * 0.15).clamp(0.0, 1.0),
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF6B00),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -100,
                child: Opacity(
                  opacity: (_fadeAnim.value * 0.12).clamp(0.0, 1.0),
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF6B00),
                    ),
                  ),
                ),
              ),

              // ── Main content ─────────────────────────────────
              SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        SizedBox(height: size.height * 0.08),

                        // ── Confetti effect ──────────────────────
                        Opacity(
                          opacity: _fadeAnim.value,
                          child: _ConfettiWidget(
                            size: size,
                            fadeAnim: _fadeAnim,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── Discount card ────────────────────────
                        Opacity(
                          opacity: _fadeAnim.value,
                          child: Transform.scale(
                            scale: _scaleAnim.value,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFF6B00),
                                    Color(0xFFFF8C42),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        const Color(0xFFFF6B00).withValues(alpha: 0.3),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Welcome!',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 1.2,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '₹50 Off',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontSize: 56,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -1,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Your First Order',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: Colors.white.withValues(alpha: 0.95),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── Discount code ────────────────────────
                        Opacity(
                          opacity: _fadeAnim.value,
                          child: Column(
                            children: [
                              Text(
                                'Use Code',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: _copyCode,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFFF6B00)
                                          .withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'WELCOME50',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: const Color(0xFFFF6B00),
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 2.4,
                                            ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        _codeCopied
                                            ? Icons.check_circle
                                            : Icons.content_copy,
                                        color: const Color(0xFFFF6B00),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── Details ──────────────────────────────
                        Opacity(
                          opacity: _fadeAnim.value,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1F1F1F)
                                  : const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'How to use',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1A1A),
                                      ),
                                ),
                                const SizedBox(height: 16),
                                _DetailRow(
                                  number: 1,
                                  title: 'Add items to cart',
                                  subtitle: 'Browse and select products',
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 12),
                                _DetailRow(
                                  number: 2,
                                  title: 'Apply coupon',
                                  subtitle: 'Enter code at checkout',
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 12),
                                _DetailRow(
                                  number: 3,
                                  title: 'Get ₹50 off',
                                  subtitle: 'Discount applied to total',
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // ── Start shopping button ────────────────
                        Opacity(
                          opacity: _fadeAnim.value,
                          child: Transform.translate(
                            offset: Offset(0, _bounceAnim.value),
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () =>
                                    context.go('/customer/home'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFFFF6B00),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Start Shopping',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final bool isDark;

  const _DetailRow({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFFFF6B00),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfettiWidget extends StatelessWidget {
  final Size size;
  final Animation<double> fadeAnim;

  const _ConfettiWidget({
    required this.size,
    required this.fadeAnim,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Stack(
        children: List.generate(
          12,
          (index) {
            final angle = (index / 12) * math.pi * 2;
            const distance = 60.0;
            final x = math.cos(angle) * distance;
            final y = math.sin(angle) * distance;

            return Positioned(
              left: size.width / 2 - 8 + x * fadeAnim.value,
              top: 60 - y * fadeAnim.value,
              child: Opacity(
                opacity: (1.0 - fadeAnim.value).clamp(0.0, 1.0),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: [
                      const Color(0xFFFF6B00),
                      const Color(0xFFFFB366),
                      const Color(0xFFE55B00),
                      Colors.yellow,
                    ][index % 4],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
