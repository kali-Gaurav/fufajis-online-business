// ============================================================
//  UnauthorizedScreen — Access Denied Screen
//  Redesigned with custom shaking padlock animation,
//  staggered action layout, and warm sunset color system.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/animated_widgets.dart';

class UnauthorizedScreen extends StatefulWidget {
  final String? reason;
  final String? returnPath;

  const UnauthorizedScreen({super.key, this.reason, this.returnPath});

  @override
  State<UnauthorizedScreen> createState() => _UnauthorizedScreenState();
}

class _UnauthorizedScreenState extends State<UnauthorizedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _shakeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _shakeController, curve: _ShakeCurve()));

    // Shake the padlock after screen enters
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _shakeController.forward();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.grey900;
    final subTextColor = isDark ? Colors.white70 : AppTheme.grey600;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.cream,
      appBar: AppBar(
        title: const Text('Access Denied', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Padlock Icon with Shake Animation
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                child: AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (context, child) {
                    final angle = _shakeAnim.value * 0.15;
                    return Transform.rotate(angle: angle, child: child);
                  },
                  child: PulseGlow(
                    glowColor: AppTheme.adminAccent.withOpacity(0.15),
                    maxRadius: 12,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.grey800 : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        size: 64,
                        color: AppTheme.adminAccent,
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
                  'Unauthorized Access',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.adminAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),

              // Description
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 150),
                child: Text(
                  widget.reason ??
                      'You do not have permission to access this resource. '
                          'Please contact your administrator if you believe this is an error.',
                  style: TextStyle(fontSize: 16, color: subTextColor, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 200),
                child: Column(
                  children: [
                    // Return to Home
                    SizedBox(
                      width: double.infinity,
                      child: ScaleBounce(
                        onTap: () {
                          context.go(widget.returnPath ?? '/customer/home');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Return to Home',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Try Different Role
                    SizedBox(
                      width: double.infinity,
                      child: ScaleBounce(
                        onTap: () {
                          context.go('/role-select');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
                            border: Border.all(color: isDark ? AppTheme.grey800 : AppTheme.grey200),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Try Different Role',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sign Out
                    SizedBox(
                      width: double.infinity,
                      child: ScaleBounce(
                        onTap: () {
                          Provider.of<AuthProvider>(context, listen: false).logout();
                          context.go('/login');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
                            border: Border.all(color: AppTheme.adminAccent, width: 1.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.adminAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Error Code Card
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 250),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : AppTheme.grey200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Error Code',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : AppTheme.grey500,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '403 - Forbidden',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShakeCurve extends Curve {
  @override
  double transform(double t) {
    return math.sin(t * math.pi * 3.5 * 2);
  }
}
