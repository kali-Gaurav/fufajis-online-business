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
import '../../providers/location_provider.dart';
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
    final bool isMainTab =
        location == '/customer/home' ||
        location == '/customer/search' ||
        location == '/customer/cart' ||
        location == '/customer/profile';

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: !isMainTab
          ? AppBar(backgroundColor: AppTheme.cream, elevation: 0)
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
                      Consumer2<AuthProvider, LocationProvider>(
                        builder: (context, auth, location, _) {
                          // Source of truth priority: 
                          // 1. Manually selected location in current session
                          // 2. User's saved district in profile
                          // 3. Default (Baran)
                          final district = location.district.isNotEmpty 
                              ? location.district 
                              : (auth.currentUser?.district ?? 'Baran');

                          return TextButton.icon(
                            onPressed: () => context.push('/customer/addresses'),
                            icon: const Icon(
                              Icons.location_on_outlined,
                              size: 20,
                              color: AppTheme.primary,
                            ),
                            label: Text(
                              district,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.grey800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
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
              padding: EdgeInsets.only(bottom: 96 + MediaQuery.of(context).padding.bottom),
              child: widget.child,
            ),
          ),

          // Sticky Checkout Bar positioned above the floating bottom nav
          if (selectedIndex != 2)
            Positioned(
              bottom: 96 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: const StickyCheckoutBar(),
            ),

          // Floating Glassmorphic Bottom Navigation Bar
          Positioned(
            bottom: 16 + MediaQuery.of(context).padding.bottom,
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
                  AnimatedTabItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Home',
                    isSelected: selectedIndex == 0,
                    onTap: () => context.go('/customer/home'),
                  ),
                  AnimatedTabItem(
                    icon: Icons.search_outlined,
                    activeIcon: Icons.search_rounded,
                    label: 'Search',
                    isSelected: selectedIndex == 1,
                    onTap: () => context.go('/customer/search'),
                  ),
                  AnimatedTabItem(
                    icon: Icons.shopping_cart_outlined,
                    activeIcon: Icons.shopping_cart_rounded,
                    label: 'Cart',
                    isSelected: selectedIndex == 2,
                    onTap: () => context.go('/customer/cart'),
                    badgeCount: cartProvider.totalItems,
                  ),
                  AnimatedTabItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Profile',
                    isSelected: selectedIndex == 3,
                    onTap: () => context.go('/customer/profile'),
                  ),
                ],
              ),
            ),
          ),

          const AIShoppingAssistant(),
        ],
      ),
    );
  }
}
