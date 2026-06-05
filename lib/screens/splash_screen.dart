// ============================================================
//  SplashScreen — App entry point with full auth resolution
//
//  BOOT SEQUENCE:
//  1. Version & maintenance check
//  2. Background tasks (lightning deals, cache)
//  3. Check Firebase auth token validity
//  4. If token valid: validate Firestore session liveness
//  5. Auto-login → route to correct role dashboard
//  6. If no valid session: route to /login (not /customer/home)
//     so user explicitly chooses Guest or Login
//
//  QUICK-LOGIN USERS:
//  Guest mode is now purely local (GuestProvider).
//  Splash never creates a Firebase user for guests.
// ============================================================

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

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _bootSequence();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootSequence() async {
    // ── Step 1: Mandatory version / maintenance gate ──────────
    final canProceed = await UpdateService().handleVersionCheck(context);
    if (!canProceed) return;

    // ── Step 2: Background prefetch (non-blocking) ────────────
    LightningDealsService().fetchActiveDeals();
    await CacheService().init();

    // ── Step 3: Initialise guest state ────────────────────────
    final guest = Provider.of<GuestProvider>(context, listen: false);
    await guest.init();

    // ── Step 4: Minimum splash display ────────────────────────
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // ── Step 5: Check Firebase auth ───────────────────────────
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = await auth.checkAuthStatus();

    if (!mounted) return;

    if (isLoggedIn) {
      // ── Step 6: Wait for Firestore user profile ─────────────
      int retries = 0;
      while (auth.currentUser == null && retries < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        retries++;
      }

      if (auth.currentUser != null) {
        final user = auth.currentUser!;

        // Preload orders
        Provider.of<OrderProvider>(context, listen: false)
            .loadOrders(user.id);

        // ── Step 7: Route by role ────────────────────────────
        if (!mounted) return;

        // Owner/Admin → PIN screen (handled by router redirect)
        if (auth.isPinRequired || auth.isDeviceVerificationRequired) {
          context.go('/security-pin');
          return;
        }

        // Customer profile incomplete
        if (user.role == UserRole.customer &&
            (user.name == null || user.name!.isEmpty)) {
          context.go('/profile-creation');
          return;
        }

        _routeByRole(user.role);
      } else {
        // Profile timed out — go to login
        debugPrint('[Splash] Profile load timeout → /login');
        context.go('/login');
      }
    } else {
      // ── Not logged in — go to login screen ──────────────────
      // Login screen offers both "Login" and "Continue as Guest"
      context.go('/login');
    }
  }

  void _routeByRole(UserRole role) {
    switch (role) {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    size: 62,
                    color: Color(0xFFFF5722),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                "Fufaji's Online",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'आपकी अपनी दुकान',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 56),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
