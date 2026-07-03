// ============================================================
//  WelcomeScreen — Customer onboarding (Screen 1/4)
//
//  Design: Branding + value proposition
//  - App logo and name
//  - Key value prop: "Get fresh groceries from local shops"
//  - Call-to-action: "Continue" button
//  - Premium animations with color gradient
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/fufaji_logo.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final AnimationController _scaleCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _runAnimations();
  }

  void _initAnimations() {
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));

    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

    _scaleAnim = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut));
  }

  Future<void> _runAnimations() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _fadeCtrl.forward();
    _scaleCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_fadeCtrl, _scaleCtrl]),
          builder: (context, _) {
            return SingleChildScrollView(
              child: Container(
                height:
                    size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF1A1A1A), const Color(0xFF262626)]
                        : [Colors.white, const Color(0xFFFFF8F0)],
                  ),
                ),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // ── Logo and branding ────────────────────────
                    Opacity(
                      opacity: _fadeAnim.value,
                      child: Transform.scale(
                        scale: _scaleAnim.value,
                        child: Column(
                          children: [
                            const FufajiLogo(size: 120, onDark: true),
                            const SizedBox(height: 24),
                            Text(
                              'Fufaji Online',
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 40,
                                color: const Color(0xFFFF6B00),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'आपकी अपनी दुकान',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 1),

                    // ── Value proposition ────────────────────────
                    Opacity(
                      opacity: _fadeAnim.value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B00).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFF6B00).withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 48,
                                    color: Color(0xFFFF6B00),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Get fresh groceries from local shops',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Browse, order, and get delivered in minutes from your neighbourhood shops',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // ── Features list ────────────────────────────
                    Opacity(
                      opacity: _fadeAnim.value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            _FeatureItem(
                              icon: Icons.local_offer_outlined,
                              title: 'Exclusive Deals',
                              subtitle: 'Daily discounts from local shops',
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),
                            _FeatureItem(
                              icon: Icons.flash_on_outlined,
                              title: 'Quick Delivery',
                              subtitle: 'Orders delivered in 30 minutes',
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),
                            _FeatureItem(
                              icon: Icons.verified_outlined,
                              title: 'Quality Assured',
                              subtitle: 'Fresh products from trusted shops',
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 1),

                    // ── Continue button ──────────────────────────
                    Opacity(
                      opacity: _fadeAnim.value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () => context.go('/onboarding/location'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B00),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Continue',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFFF6B00), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
