import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/app_theme.dart';
import '../l10n/app_localizations.dart';

/// Admin shell with sidebar navigation and system health indicators.
///
/// Features:
/// - Left sidebar with navigation
/// - Top AppBar with system status indicator
/// - Menu: Users, Shops, Products, Orders, Compliance, Audit Logs, Settings
/// - Real-time system health display
class AdminShell extends StatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Determine if current route matches menu item
  bool _isRouteSelected(String route) {
    final location = GoRouterState.of(context).uri.path;
    return location.startsWith(route);
  }

  /// Get system health status (mock implementation)
  String get _systemStatus => 'Healthy';
  Color get _systemStatusColor => AppTheme.success;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        elevation: 2,
        title: const Text('Admin Control Panel'),
        actions: [
          // System Status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _systemStatusColor.withAlpha((255 * 0.1).toInt()),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _systemStatusColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: _systemStatusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _systemStatus,
                      style: TextStyle(
                        color: _systemStatusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Notifications
          IconButton(
            onPressed: () => context.push('/customer/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Drawer Header
            DrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'System Administrator',
                    style: TextStyle(
                      color: Colors.white.withAlpha((255 * 0.8).toInt()),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Dashboard / Overview
            _buildDrawerItem(
              context,
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard,
              label: l10n.translate('dashboard'),
              route: '/admin',
            ),

            // Users Management
            _buildDrawerItem(
              context,
              icon: Icons.people_outline,
              selectedIcon: Icons.people,
              label: 'Users',
              route: '/admin/users',
            ),

            // Shop Management
            _buildDrawerItem(
              context,
              icon: Icons.store_outlined,
              selectedIcon: Icons.store,
              label: 'Shops',
              route: '/admin/shops',
            ),

            // Product Moderation
            _buildDrawerItem(
              context,
              icon: Icons.shopping_bag_outlined,
              selectedIcon: Icons.shopping_bag,
              label: 'Products',
              route: '/admin/products',
            ),

            // Order Management
            _buildDrawerItem(
              context,
              icon: Icons.assignment_outlined,
              selectedIcon: Icons.assignment,
              label: l10n.translate('orders') ?? 'Orders',
              route: '/admin/orders',
            ),

            const Divider(height: 24),

            // Coupons / Promotions
            _buildDrawerItem(
              context,
              icon: Icons.local_offer_outlined,
              selectedIcon: Icons.local_offer,
              label: 'Coupons',
              route: '/admin/coupons',
            ),

            // Analytics
            _buildDrawerItem(
              context,
              icon: Icons.analytics_outlined,
              selectedIcon: Icons.analytics,
              label: l10n.translate('analytics') ?? 'Analytics',
              route: '/admin/analytics',
            ),

            const Divider(height: 24),

            // Audit Logs
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('Audit Logs'),
              onTap: () {
                Navigator.pop(context);
                context.go('/admin/audit-logs');
              },
            ),

            // Security NOC
            ListTile(
              leading: const Icon(Icons.security_outlined),
              title: const Text('Security NOC'),
              onTap: () {
                Navigator.pop(context);
                context.go('/admin/security-noc');
              },
            ),

            // Sync Health NOC
            ListTile(
              leading: const Icon(Icons.sync_problem_outlined),
              title: const Text('Sync Health NOC'),
              onTap: () {
                Navigator.pop(context);
                context.go('/admin/sync-noc');
              },
            ),

            // System Health NOC
            ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: const Text('System Health NOC'),
              onTap: () {
                Navigator.pop(context);
                context.go('/admin/system-health-noc');
              },
            ),

            // System Settings (future)
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              enabled: false,
              onTap: () {
                // TODO: Implement admin settings
              },
            ),

            const Divider(height: 24),

            // Role Switcher
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Switch Role'),
              onTap: () {
                Navigator.pop(context);
                context.push('/role-select');
              },
            ),
          ],
        ),
      ),
      body: widget.child,
    );
  }

  /// Build a drawer menu item with active state highlight
  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required String route,
  }) {
    final isSelected = _isRouteSelected(route);
    return ListTile(
      leading: Icon(isSelected ? selectedIcon : icon, color: isSelected ? AppTheme.primary : null),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppTheme.primary : null,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}
