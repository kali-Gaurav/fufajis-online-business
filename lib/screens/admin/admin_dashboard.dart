import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../services/firestore_seeder.dart';
import '../../utils/responsive.dart';

class AdminDashboard extends StatefulWidget {
  final Widget child;
  const AdminDashboard({super.key, required this.child});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _getSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location == '/admin') return 0;
    if (location.startsWith('/admin/users')) return 1;
    if (location.startsWith('/admin/shops')) return 2;
    if (location.startsWith('/admin/products')) return 3;
    if (location.startsWith('/admin/orders')) return 4;
    if (location.startsWith('/admin/coupons')) return 5;
    if (location.startsWith('/admin/analytics')) return 6;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0: context.go('/admin'); break;
      case 1: context.go('/admin/users'); break;
      case 2: context.go('/admin/shops'); break;
      case 3: context.go('/admin/products'); break;
      case 4: context.go('/admin/orders'); break;
      case 5: context.go('/admin/coupons'); break;
      case 6: context.go('/admin/analytics'); break;
    }
  }

  final List<String> _titles = [
    'Admin Overview',
    'User Management',
    'Shop Moderation',
    'Product Moderation',
    'Global Orders',
    'Promo Coupons',
    'Global Analytics',
  ];

  IconData _getIconForIndex(int index, bool isSelected) {
    switch (index) {
      case 0: return isSelected ? Icons.dashboard : Icons.dashboard_outlined;
      case 1: return isSelected ? Icons.people : Icons.people_outline;
      case 2: return isSelected ? Icons.storefront : Icons.storefront_outlined;
      case 3: return isSelected ? Icons.inventory_2 : Icons.inventory_2_outlined;
      case 4: return isSelected ? Icons.shopping_bag : Icons.shopping_bag_outlined;
      case 5: return isSelected ? Icons.confirmation_number : Icons.confirmation_number_outlined;
      case 6: return isSelected ? Icons.analytics : Icons.analytics_outlined;
      default: return Icons.circle;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchDashboardMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final useRail = Responsive.useRailNav(context);
    final selectedIndex = _getSelectedIndex(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[selectedIndex]),
        actions: [
          IconButton(
            onPressed: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const Center(child: CircularProgressIndicator(color: AppTheme.adminAccent)),
              );
              await FirestoreSeeder.seedDatabase();
              if (mounted) Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Catalog & Price History Seeded Successfully!'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            icon: const Icon(Icons.settings_backup_restore),
            tooltip: 'Seed Demo Catalog',
          ),
          IconButton(
            onPressed: () => context.push('/role-select'),
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch Role',
          ),
          IconButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: useRail ? null : Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: AppTheme.primary),
              child: Center(
                child: Text(
                  'Admin Dashboard',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _titles.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Icon(
                      _getIconForIndex(index, selectedIndex == index),
                      color: selectedIndex == index ? AppTheme.primary : AppTheme.grey600,
                    ),
                    title: Text(
                      _titles[index],
                      style: TextStyle(
                        color: selectedIndex == index ? AppTheme.primary : AppTheme.grey800,
                        fontWeight: selectedIndex == index ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: selectedIndex == index,
                    onTap: () {
                      _onItemTapped(index, context);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: Row(
        children: [
          if (useRail)
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (index) => _onItemTapped(index, context),
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Overview')),
                        NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Users')),
                        NavigationRailDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: Text('Shops')),
                        NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Products')),
                        NavigationRailDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: Text('Orders')),
                        NavigationRailDestination(icon: Icon(Icons.confirmation_number_outlined), selectedIcon: Icon(Icons.confirmation_number), label: Text('Coupons')),
                        NavigationRailDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: Text('Analytics')),
                      ],
                    ),
                    ),
                  ),
                );
              },
            ),
          if (useRail)
            const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class AdminOverviewPage extends StatelessWidget {
  const AdminOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        if (adminProvider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.adminAccent));
        }
        if (adminProvider.error.isNotEmpty) {
          return Center(child: Text(adminProvider.error, style: const TextStyle(color: AppTheme.error)));
        }

        return RefreshIndicator(
          onRefresh: () => adminProvider.fetchDashboardMetrics(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Platform Statistics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = Responsive.kpiColumns(context);
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard('Total Users', '${adminProvider.totalUsers}', Icons.people, AppTheme.info),
                        _buildStatCard('Active Shops', '${adminProvider.totalShops}', Icons.store, AppTheme.warning),
                        _buildStatCard('Active Orders', '${adminProvider.totalActiveOrders}', Icons.shopping_bag, AppTheme.success),
                        _buildStatCard('Revenue', '₹${adminProvider.totalRevenue.toStringAsFixed(0)}', Icons.currency_rupee, Colors.purple),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: AppTheme.grey500, fontSize: 14)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}


