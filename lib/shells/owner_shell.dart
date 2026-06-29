import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';

import '../l10n/app_localizations.dart';

/// Shop owner shell with drawer navigation.
///
/// Features:
/// - Left drawer with navigation menu
/// - Top AppBar with shop name/info
/// - Shop switcher for multi-shop owners
/// - Menu items: Dashboard, Orders, Products, Inventory, Analytics, Employees, Settings
class OwnerShell extends StatefulWidget {
  final Widget child;
  const OwnerShell({super.key, required this.child});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Get current owner's shop name
  String _getShopName(BuildContext context) {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      return authProvider.currentUser?.name ?? 'My Shop';
    } catch (_) {
      return 'My Shop';
    }
  }

  /// Determine if current route matches drawer item
  bool _isRouteSelected(String route) {
    final location = GoRouterState.of(context).uri.path;
    return location.startsWith(route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        elevation: 1,
        title: Text(_getShopName(context)),
        actions: [
          // Shop switcher (for multi-shop owners)
          PopupMenuButton<String>(
            onSelected: (value) {
              // Handle shop selection
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Selected shop: $value')),
              );
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'shop1',
                child: Text('Shop 1'),
              ),
              const PopupMenuItem(
                value: 'shop2',
                child: Text('Shop 2'),
              ),
            ],
            icon: const Icon(Icons.store),
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
              decoration: const BoxDecoration(
                color: AppTheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _getShopName(context),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Shop Owner',
                    style: TextStyle(
                      color: Colors.white.withAlpha((255 * 0.8).toInt()),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Dashboard
            _buildDrawerItem(
              context,
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard,
              label: l10n.translate('dashboard') ?? 'Dashboard',
              route: '/owner',
            ),

            // Orders
            _buildDrawerItem(
              context,
              icon: Icons.assignment_outlined,
              selectedIcon: Icons.assignment,
              label: l10n.translate('orders') ?? 'Orders',
              route: '/owner/orders',
            ),

            // Products
            _buildDrawerItem(
              context,
              icon: Icons.shopping_bag_outlined,
              selectedIcon: Icons.shopping_bag,
              label: l10n.translate('products') ?? 'Products',
              route: '/owner/products',
            ),

            // Inventory
            _buildDrawerItem(
              context,
              icon: Icons.inventory_2_outlined,
              selectedIcon: Icons.inventory_2,
              label: l10n.translate('inventory') ?? 'Inventory',
              route: '/owner/inventory',
            ),

            // Analytics
            _buildDrawerItem(
              context,
              icon: Icons.analytics_outlined,
              selectedIcon: Icons.analytics,
              label: l10n.translate('analytics') ?? 'Analytics',
              route: '/owner/analytics',
            ),

            // Employees
            _buildDrawerItem(
              context,
              icon: Icons.people_outlined,
              selectedIcon: Icons.people,
              label: l10n.translate('employees') ?? 'Employees',
              route: '/owner/employees',
            ),

            const Divider(height: 24),

            // AI Business Intelligence
            _buildDrawerItem(
              context,
              icon: Icons.auto_awesome_outlined,
              selectedIcon: Icons.auto_awesome,
              label: 'AI Business Intel',
              route: '/owner/ai-dashboard',
            ),

            // Executive AI Assistant
            _buildDrawerItem(
              context,
              icon: Icons.chat_bubble_outline,
              selectedIcon: Icons.chat_bubble,
              label: 'Executive AI',
              route: '/owner/ai-assistant',
            ),

            // Enterprise Command Center
            _buildDrawerItem(
              context,
              icon: Icons.monitor_heart_outlined,
              selectedIcon: Icons.monitor_heart,
              label: 'System Health',
              route: '/owner/system-health',
            ),

            // Audit Logs
            _buildDrawerItem(
              context,
              icon: Icons.security_outlined,
              selectedIcon: Icons.security,
              label: 'Audit Logs',
              route: '/owner/audit-logs',
            ),

            const Divider(height: 24),

            // Packing
            _buildDrawerItem(
              context,
              icon: Icons.local_shipping_outlined,
              selectedIcon: Icons.local_shipping,
              label: 'Packing',
              route: '/owner/packing-dashboard',
            ),

            // Khata
            _buildDrawerItem(
              context,
              icon: Icons.receipt_long_outlined,
              selectedIcon: Icons.receipt_long,
              label: 'Khata',
              route: '/owner/khata',
            ),

            // Riders
            _buildDrawerItem(
              context,
              icon: Icons.two_wheeler_outlined,
              selectedIcon: Icons.two_wheeler,
              label: 'Delivery Riders',
              route: '/owner/riders',
            ),

            const Divider(height: 24),

            // Settings
            _buildDrawerItem(
              context,
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              label: l10n.translate('settings') ?? 'Settings',
              route: '/owner/shop-settings',
            ),

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
      leading: Icon(
        isSelected ? selectedIcon : icon,
        color: isSelected ? AppTheme.primary : null,
      ),
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
