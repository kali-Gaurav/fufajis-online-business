// ============================================================
//  CustomerShell — Redesigned Customer Navigation Shell
//  Features floating glassmorphic bottom navigation bar,
//  role indicators, pulsing cart badge, and optimized offsets
//  for checkout bars.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/sticky_checkout_bar.dart';
import '../../widgets/ai_shopping_assistant.dart';
import '../../widgets/animated_widgets.dart';

class CustomerShell extends StatefulWidget {
  final Widget child;
  const CustomerShell({super.key, required this.child});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/customer/home')) return 0;
    if (location.startsWith('/customer/search')) return 1;
    if (location.startsWith('/customer/cart')) return 2;
    if (location.startsWith('/customer/profile')) return 3;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        orderProvider.listenToOrders(authProvider.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final selectedIndex = _calculateSelectedIndex(context);
    final String location = GoRouterState.of(context).uri.path;

    // Show AppBar only on main tabs to avoid double headers
    final bool isMainTab = location == '/customer/home' || 
                         location == '/customer/search' || 
                         location == '/customer/cart' || 
                         location == '/customer/profile';

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: !isMainTab 
          ? AppBar(
              backgroundColor: AppTheme.cream,
              elevation: 0,
            ) 
          : (selectedIndex == 0 
              ? null 
              : AppBar(
                  backgroundColor: AppTheme.cream,
                  elevation: 0,
                  centerTitle: false,
                  title: Text(
                    selectedIndex == 1 
                        ? 'Search Catalog' 
                        : (selectedIndex == 2 ? 'My Cart' : 'My Profile'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey900,
                    ),
                  ),
                  actions: [
                    // Location Selector
                    TextButton.icon(
                      onPressed: () => context.push('/customer/addresses'),
                      icon: const Icon(Icons.location_on_outlined, size: 20, color: AppTheme.primary),
                      label: const Text(
                        'Jaipur',
                        style: TextStyle(fontSize: 14, color: AppTheme.grey800, fontWeight: FontWeight.w600),
                      ),
                    ),
                    // Role Switcher
                    IconButton(
                      onPressed: () => context.push('/role-select'),
                      icon: const Icon(Icons.swap_horiz, color: AppTheme.grey700),
                      tooltip: 'Switch Role',
                    ),
                    // Notifications
                    IconButton(
                      onPressed: () => context.push('/customer/notifications'),
                      icon: const Icon(Icons.notifications_outlined, color: AppTheme.grey700),
                    ),
                  ],
                )),
      body: Stack(
        children: [
          // Screen content with bottom padding for the floating navigation bar
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 96),
              child: widget.child,
            ),
          ),
          
          // Sticky Checkout Bar positioned above the floating bottom nav
          if (selectedIndex != 2)
            const Positioned(
              bottom: 96,
              left: 0,
              right: 0,
              child: StickyCheckoutBar(),
            ),
          
          // Floating Glassmorphic Bottom Navigation Bar
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: GlassmorphicContainer(
              borderRadius: 24,
              tint: Colors.white.withValues(alpha: 0.90),
              borderColor: Colors.white.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home', selectedIndex),
                  _buildNavItem(1, Icons.search_rounded, Icons.search_rounded, 'Search', selectedIndex),
                  _buildNavItem(2, Icons.shopping_cart_outlined, Icons.shopping_cart_rounded, 'Cart', selectedIndex, badgeCount: cartProvider.totalItems),
                  _buildNavItem(3, Icons.person_outline_rounded, Icons.person_rounded, 'Profile', selectedIndex),
                ],
              ),
            ),
          ),
          
          const AIShoppingAssistant(),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, int selectedIndex, {int badgeCount = 0}) {
    final isSelected = selectedIndex == index;
    return ScaleBounce(
      onTap: () {
        switch (index) {
          case 0:
            context.go('/customer/home');
            break;
          case 1:
            context.go('/customer/search');
            break;
          case 2:
            context.go('/customer/cart');
            break;
          case 3:
            context.go('/customer/profile');
            break;
        }
      },
      child: AnimatedContainer(
        duration: AppTheme.durationFast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? AppTheme.primary : AppTheme.grey600,
                  size: 24,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: PulseGlow(
                      glowColor: AppTheme.primary.withValues(alpha: 0.3),
                      maxRadius: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        alignment: Alignment.center,
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primary : AppTheme.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
