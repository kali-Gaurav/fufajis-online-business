import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../providers/order_provider.dart';
import '../providers/product_provider.dart';
import '../services/update_service.dart';
import '../services/lightning_deals_service.dart';
import '../services/cache_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _navigateToNextScreen();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigateToNextScreen() async {
    // 1. Mandatory Version & Maintenance Check (Step 1.1)
    final bool canProceed = await UpdateService().handleVersionCheck(context);
    if (!canProceed) return; // Blocked by mandatory dialog

    // 2. Background Fetch for Lightning Deals (Step 1.2)
    LightningDealsService().fetchActiveDeals();

    // 3. Ensure Cache Service is ready (Step 1.3)
    await CacheService().init();

    await Future.delayed(const Duration(seconds: 1));

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = await authProvider.checkAuthStatus();

    if (mounted) {
      if (isLoggedIn) {
        // Step 1.5: Wait for profile to load to prevent race conditions
        int retryCount = 0;
        while (authProvider.currentUser == null && retryCount < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (!mounted) return;
          retryCount++;
          debugPrint('[SplashScreen] Waiting for profile... ($retryCount)');
        }

        if (authProvider.currentUser != null) {
          if (!mounted) return;
          Provider.of<OrderProvider>(context, listen: false)
              .loadOrders(authProvider.currentUser!.id);
          
          final user = authProvider.currentUser!;
          
          // Route based on active role and profile completion
          if (user.role == UserRole.customer && 
              (user.name == null || user.name!.isEmpty || user.district == null || user.district!.isEmpty)) {
            context.go('/profile-creation');
          } else {
            context.go('/');
          }
        } else {
          // Profile failed to load after 5 seconds
          debugPrint('[SplashScreen] Profile load timeout. Routing to login.');
          if (mounted) context.go('/login');
        }
      } else {
        context.go('/login');
      }
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
                scale: _animation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shopping_bag,
                    size: 60,
                    color: Color(0xFFFF5722),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Fufaji's Online",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your District Shopping App',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
