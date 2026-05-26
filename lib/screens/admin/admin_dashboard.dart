import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import 'user_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Admin Overview',
    'User Management',
    'Shop Moderation',
    'Product Moderation',
    'Global Analytics',
    'App Settings',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchDashboardMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
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
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Overview')),
              NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Users')),
              NavigationRailDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: Text('Shops')),
              NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Products')),
              NavigationRailDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: Text('Analytics')),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _buildPage(_selectedIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0: return _buildOverview();
      case 1: return const UserManagementScreen();
      case 2: return const Center(child: Text('Shop Moderation Screen (Coming Soon)'));
      case 3: return const Center(child: Text('Product Moderation Screen (Coming Soon)'));
      case 4: return const Center(child: Text('Global Analytics Screen (Coming Soon)'));
      case 5: return const Center(child: Text('App Global Settings Screen (Coming Soon)'));
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildOverview() {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        if (adminProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (adminProvider.error.isNotEmpty) {
          return Center(child: Text(adminProvider.error, style: const TextStyle(color: Colors.red)));
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
                    int crossAxisCount = constraints.maxWidth > 1000 ? 4 : constraints.maxWidth > 600 ? 3 : 1;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard('Total Users', '${adminProvider.totalUsers}', Icons.people, Colors.blue),
                        _buildStatCard('Active Shops', '${adminProvider.totalShops}', Icons.store, Colors.orange),
                        _buildStatCard('Active Orders', '${adminProvider.totalActiveOrders}', Icons.shopping_bag, Colors.green),
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
              Text(title, style: TextStyle(color: AppTheme.grey500, fontSize: 14)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

