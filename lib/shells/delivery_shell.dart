import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/app_theme.dart';
import '../l10n/app_localizations.dart';

/// Delivery agent shell with emphasis on map/navigation.
///
/// Tabs:
/// 0. Map - Real-time delivery routes, location tracking, cluster view
/// 1. Orders - Active deliveries, trip sheet, order details
/// 2. Earnings - Daily/weekly earnings, trip earnings breakdown
/// 3. Profile - Rider info, chat, settings
///
/// The Map tab takes prominence with full-width top positioning.
class DeliveryShell extends StatefulWidget {
  final Widget child;
  const DeliveryShell({super.key, required this.child});

  @override
  State<DeliveryShell> createState() => _DeliveryShellState();
}

class _DeliveryShellState extends State<DeliveryShell> {
  /// Calculate selected tab based on route path.
  /// Map/navigation routes grouped together.
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;

    // Map tab: smart route, cluster view, trip sheet
    if (location.startsWith('/delivery/smart-route') || location.startsWith('/delivery/cluster/')) {
      return 0;
    }

    // Orders tab: orders, order details, scanner
    if (location.startsWith('/delivery/orders') ||
        location.startsWith('/delivery/detail/') ||
        location.startsWith('/delivery/scanner')) {
      return 1;
    }

    // Earnings tab: earnings dashboard
    if (location.startsWith('/delivery/earnings')) {
      return 2;
    }

    // Profile tab: chat
    if (location.startsWith('/delivery/chat')) {
      return 3;
    }

    // Default to home (Map)
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final String location = GoRouterState.of(context).uri.path;
    final l10n = AppLocalizations.of(context)!;

    // Hide nav on detail screens
    final isMainTab = location == '/delivery' || location == '/delivery/smart-route';

    return Scaffold(
      appBar: isMainTab ? null : AppBar(elevation: 1, automaticallyImplyLeading: true),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        destinations: [
          // Map Tab - most prominent
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map, color: AppTheme.primary),
            label: l10n.translate('map') ?? 'Map',
          ),
          // Orders Tab
          NavigationDestination(
            icon: const Icon(Icons.assignment_outlined),
            selectedIcon: const Icon(Icons.assignment, color: AppTheme.primary),
            label: l10n.translate('orders') ?? 'Orders',
          ),
          // Earnings Tab
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet, color: AppTheme.primary),
            label: l10n.translate('earnings') ?? 'Earnings',
          ),
          // Profile Tab
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person, color: AppTheme.primary),
            label: l10n.translate('profile') ?? 'Profile',
          ),
        ],
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/delivery/smart-route');
              break;
            case 1:
              context.go('/delivery/orders');
              break;
            case 2:
              context.go('/delivery/earnings');
              break;
            case 3:
              context.go('/delivery/chat');
              break;
          }
        },
      ),
    );
  }
}
