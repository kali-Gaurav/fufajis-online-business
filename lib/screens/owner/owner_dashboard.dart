import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../providers/shop_config_provider.dart';
import 'shop_settings_screen.dart';
import 'rider_management_screen.dart';
import 'orders_management.dart';
import 'inventory_screen.dart';
import 'analytics_screen.dart';
import 'settlements_management.dart';
import 'attendance_management.dart';
import 'rider_support_console.dart';
import 'dynamic_pricing_console.dart';
import 'reviews_moderation_screen.dart';
import 'bahi_khata_screen.dart';
import 'whatsapp_sync_setup_screen.dart';
import 'products_management.dart';
import 'vendor_request_screen.dart';
import '../../widgets/dashboard_widgets.dart';
import '../../widgets/intelligent_insights.dart';
import '../../widgets/weather_stock_assistant.dart';
import '../../widgets/customer_retention_bot.dart';
import '../../widgets/whatsapp_logic_simulator.dart';
import '../../widgets/voice_to_stock_dialog.dart';
import '../../widgets/dashboard/revenue_analytics_widget.dart';
import '../../widgets/dashboard/inventory_automation_widget.dart';
import '../../widgets/dashboard/system_status_widget.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/common/role_restricted_widget.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      orderProvider.listenToAllOrders();
    });
  }

  final List<Widget> _pages = [
    const OwnerHomePage(),
    const ProductsManagementScreen(),
    const OrdersManagementScreen(),
    const InventoryScreen(),
    const AnalyticsScreen(),
    const WhatsAppSyncSetupScreen(),
    const SettlementsManagementScreen(),
    const RiderManagementScreen(),
    const AttendanceManagementScreen(),
    const RiderSupportConsole(),
    const DynamicPricingConsole(),
    const ReviewsModerationScreen(),
    const VendorRequestScreen(),
    const BahiKhataScreen(),
    const ShopSettingsScreen(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Products',
    'Orders',
    'Inventory',
    'Analytics',
    'WhatsApp Sync',
    'COD Settlements',
    'Fleet Management',
    'Rider Attendance',
    'Rider Support',
    'Dynamic Pricing',
    'Customer Reviews',
    'Vendor Orders',
    'Bahi-Khata (Credit)',
    'Shop Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final shopConfigProvider = Provider.of<ShopConfigProvider>(context);
    final isShopOpen = shopConfigProvider.shopConfig?.isOpen ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          Row(
            children: [
              Text(
                isShopOpen ? 'OPEN' : 'CLOSED',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isShopOpen ? AppTheme.success : AppTheme.error,
                ),
              ),
              Switch(
                value: isShopOpen,
                onChanged: (value) async {
                  await shopConfigProvider.setShopOpen(value);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(value
                            ? 'Shop is now OPEN for orders'
                            : 'Shop is now CLOSED for orders'),
                        backgroundColor: value ? AppTheme.success : AppTheme.error,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                activeThumbColor: AppTheme.success,
                activeTrackColor: AppTheme.success.withOpacity(0.3),
                inactiveThumbColor: AppTheme.error,
                inactiveTrackColor: AppTheme.error.withOpacity(0.3),
              ),
            ],
          ),
          const VerticalDivider(width: 8, color: Colors.transparent),
          IconButton(
            onPressed: () => showWhatsAppSimulator(context),
            icon: const Icon(Icons.message, color: Colors.green),
            tooltip: 'WhatsApp Command Simulator',
          ),
          RoleRestrictedWidget(
            allowedRoles: [UserRole.admin, UserRole.shopOwner],
            child: IconButton(
              onPressed: () => context.push('/role-select'),
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Switch Role',
            ),
          ),
          IconButton(
            onPressed: () => context.push('/customer/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Products'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                selectedIcon: Icon(Icons.shopping_bag),
                label: Text('Orders'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.warehouse_outlined),
                selectedIcon: Icon(Icons.warehouse),
                label: Text('Inventory'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: Text('Analytics'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.message_outlined),
                selectedIcon: Icon(Icons.message),
                label: Text('WhatsApp'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.handshake_outlined),
                selectedIcon: Icon(Icons.handshake),
                label: Text('Settlements'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.delivery_dining_outlined),
                selectedIcon: Icon(Icons.delivery_dining),
                label: Text('Fleet'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Attendance'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.chat_outlined),
                selectedIcon: Icon(Icons.chat),
                label: Text('Support'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.currency_rupee_outlined),
                selectedIcon: Icon(Icons.currency_rupee),
                label: Text('Pricing'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.rate_review_outlined),
                selectedIcon: Icon(Icons.rate_review),
                label: Text('Reviews'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping),
                label: Text('Vendors'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: Text('Khata'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }

  void _showWhatsAppSimulator(BuildContext context) {
    showWhatsAppSimulator(context);
  }
}

class OwnerHomePage extends StatelessWidget {
  const OwnerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final stats = orderProvider.getShopStats();

    return RefreshIndicator(
      onRefresh: () async {
        // Simulate a data fetch
        await Future.delayed(const Duration(seconds: 1));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 24),
            const SystemStatusWidget(),
            const SizedBox(height: 24),
            _buildStatsGrid(stats, productProvider.products.length),
            const SizedBox(height: 24),
            const GaonIntelligentInsights(),
            const SizedBox(height: 24),
            const WeatherStockAssistant(),
            const SizedBox(height: 24),
            const CustomerRetentionBot(),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(flex: 1, child: InventoryHealthScoreWidget()),
                const SizedBox(width: 24),
                const Expanded(flex: 1, child: RevenueAnalyticsWidget()),
                const SizedBox(width: 24),
                const Expanded(flex: 1, child: InventoryAutomationWidget()),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(flex: 1, child: LowStockAlertWidget()),
                const SizedBox(width: 24),
                const Expanded(flex: 1, child: ExpiringSoonWidget()),
                const SizedBox(width: 24),
                const Expanded(flex: 1, child: PendingPriceChangesWidget()),
              ],
            ),
            const SizedBox(height: 24),
            _buildRecentOrdersSection(orderProvider.orders),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Welcome back!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Here's what's happening in your shop today",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storefront,
              size: 40,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats, int totalProducts) {
    final statsList = [
      {
        'title': "Today's Orders",
        'value': stats['todayOrderCount'].toString(),
        'change': '+${stats['todayOrderCount']}',
        'icon': Icons.shopping_bag
      },
      {
        'title': 'Revenue',
        'value': '₹${stats['todayRevenue'].round()}',
        'change': '+${stats['todayRevenue'] > 0 ? '8%' : '0%'}',
        'icon': Icons.currency_rupee
      },
      {
        'title': 'Products',
        'value': totalProducts.toString(),
        'change': '+0',
        'icon': Icons.inventory_2
      },
      {
        'title': 'Pending',
        'value': stats['pendingOrderCount'].toString(),
        'change': stats['pendingOrderCount'] > 5 ? '+5' : '0',
        'icon': Icons.pending_actions
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: statsList.length,
      itemBuilder: (context, index) {
        final stat = statsList[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      stat['icon'] as IconData,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  Text(
                    stat['change'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: (stat['change'] as String).startsWith('+')
                          ? AppTheme.success
                          : AppTheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                stat['value'] as String,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stat['title'] as String,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.grey500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentOrdersSection(List<OrderModel> orders) {
    final recentOrders = orders.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Orders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All',
                    style: TextStyle(color: AppTheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentOrders.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('No orders yet today.'),
              ),
            )
          else
            ...recentOrders.map((order) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shopping_bag,
                          color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${order.orderNumber}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.grey900,
                            ),
                          ),
                          Text(
                            '${order.customerName} - ${order.items.length} items',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.grey500),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${order.totalAmount.round()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order.status.displayName)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            order.status.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              color: _getStatusColor(order.status.displayName),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  static Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return AppTheme.warning;
      case 'Processing':
        return AppTheme.info;
      case 'Packed':
        return AppTheme.secondary;
      case 'Delivered':
        return AppTheme.success;
      default:
        return AppTheme.grey500;
    }
  }
}

// ProductsManagementScreen is now imported from products_management.dart
