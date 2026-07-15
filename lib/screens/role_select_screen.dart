// ============================================================
//  RoleSelectScreen — Interactive Role Selection Screen
//  Redesigned with staggered right-to-left slide-in cards,
//  waving hand title, unique role-specific accents,
//  and bounce tap feedback.
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import '../widgets/animated_widgets.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    // Waving hand controller
    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _selectRole(String roleStr) async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      switch (roleStr) {
        case 'shopOwner':
          if (mounted) context.push('/auth/owner-login');
          break;
        case 'deliveryAgent':
          if (mounted) context.push('/auth/staff-login?role=deliveryAgent');
          break;
        case 'employee':
          if (mounted) context.push('/auth/staff-login?role=employee');
          break;
        case 'customer':
          if (mounted) context.push('/auth/phone-login'); // Use existing phone login or OTP entry for customer
          break;
        case 'guest':
          await authProvider.requestRoleUpdate(authProvider.currentUser?.id ?? 'guest', UserRole.customer);
          if (mounted) context.go('/');
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.grey900;
    final subTextColor = isDark ? Colors.white70 : AppTheme.grey600;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),

              // Animated Icon Header
              Center(
                child: FadeSlideIn(
                  duration: AppTheme.durationMedium,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person_pin_rounded, size: 48, color: AppTheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Title with waving hand emoji
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 100),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Select Your Role ',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        final angle = math.sin(_waveController.value * math.pi * 2) * 0.15;
                        return Transform.rotate(
                          angle: angle,
                          alignment: Alignment.bottomRight,
                          child: const Text('👋', style: TextStyle(fontSize: 30)),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 150),
                child: Text(
                  'Choose how you want to use the app',
                  style: TextStyle(fontSize: 16, color: subTextColor),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),

              // Customer Card (Slide in from right)
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 200),
                offset: const Offset(0.2, 0.0),
                child: _buildRoleCard(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Customer',
                  description: 'Shop from local stores and get delivery at home',
                  tooltip: 'Best for daily groceries and home essentials',
                  color: AppTheme.primary,
                  onTap: () => _selectRole('customer'),
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 16),

              // Shop Owner Card
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 280),
                offset: const Offset(0.2, 0.0),
                child: _buildRoleCard(
                  icon: Icons.storefront_rounded,
                  title: 'Shop Owner',
                  description: 'Manage your shop, products, and orders',
                  tooltip: 'For local merchants wanting to sell online',
                  color: AppTheme.ownerAccent,
                  onTap: () => _selectRole('shopOwner'),
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 16),

              // Delivery Partner Card
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 360),
                offset: const Offset(0.2, 0.0),
                child: _buildRoleCard(
                  icon: Icons.delivery_dining_rounded,
                  title: 'Delivery Partner',
                  description: 'Deliver orders and earn money',
                  tooltip: 'For agents with a vehicle ready to deliver',
                  color: AppTheme.deliveryAccent,
                  onTap: () => _selectRole('deliveryAgent'),
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 16),

              // Store Staff Card
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 440),
                offset: const Offset(0.2, 0.0),
                child: _buildRoleCard(
                  icon: Icons.badge_outlined,
                  title: 'Store Staff / Employee',
                  description: 'Perform operational tasks, scanning, audits, etc.',
                  tooltip: 'For store managers, packing, and inventory staff',
                  color: AppTheme.employeeAccent,
                  onTap: () => _selectRole('employee'),
                  isDark: isDark,
                ),
              ),

              // Guest Mode Card
              FadeSlideIn(
                duration: AppTheme.durationMedium,
                delay: const Duration(milliseconds: 520),
                offset: const Offset(0.2, 0.0),
                child: _buildRoleCard(
                  icon: Icons.travel_explore_rounded,
                  title: 'Continue as Guest',
                  description: 'Browse the shop catalog without logging in',
                  tooltip: 'Quick access to see what we offer',
                  color: AppTheme.primary,
                  onTap: () => _selectRole('guest'),
                  isDark: isDark,
                ),
              ),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String description,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ScaleBounce(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF2C2C2C) : AppTheme.grey200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Highlighted role icon container
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 30, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.grey900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppTheme.grey400 : AppTheme.grey600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? AppTheme.grey600 : AppTheme.grey400,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
