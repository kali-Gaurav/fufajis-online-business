import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';
import '../../providers/shop_config_provider.dart';
import '../../widgets/whatsapp_logic_simulator.dart';
import '../../widgets/voice_command_sheet.dart';
import '../../widgets/animated_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../utils/responsive.dart';

class OwnerDashboard extends StatefulWidget {
  final Widget child;
  const OwnerDashboard({super.key, required this.child});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  int _getSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location == '/owner') return 0;
    if (location.startsWith('/owner/products')) return 1;
    if (location.startsWith('/owner/orders')) return 2;
    if (location.startsWith('/owner/inventory')) return 3;
    if (location.startsWith('/owner/analytics')) return 4;
    if (location.startsWith('/owner/whatsapp-sync')) return 5;
    if (location.startsWith('/owner/settlements')) return 6;
    if (location.startsWith('/owner/riders') || location.startsWith('/owner/fleet-tracking')) return 7;
    if (location.startsWith('/owner/attendance')) return 8;
    if (location.startsWith('/owner/rider-support')) return 9;
    if (location.startsWith('/owner/pricing-rules') || location.startsWith('/owner/pending-price-changes')) return 10;
    if (location.startsWith('/owner/reviews')) return 11;
    if (location.startsWith('/owner/vendor-request')) return 12;
    if (location.startsWith('/owner/khata')) return 13;
    if (location.startsWith('/owner/devices')) return 14;
    if (location.startsWith('/owner/scan-activity')) return 15;
    if (location.startsWith('/owner/releases')) return 16;
    if (location.startsWith('/owner/shop-settings')) return 17;
    if (location.startsWith('/owner/broadcast')) return 18;
    if (location.startsWith('/owner/mandi-pricing')) return 19;
    if (location.startsWith('/owner/smart-dispatch')) return 20;
    if (location.startsWith('/owner/barcode-inventory')) return 21;
    if (location.startsWith('/owner/campaigns')) return 22;
    if (location.startsWith('/owner/retention')) return 23;
    if (location.startsWith('/owner/logistics-command-center')) return 24;
    if (location.startsWith('/owner/failed-deliveries')) return 26;
    if (location.startsWith('/owner/mission-control')) return 27;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0: context.go('/owner'); break;
      case 1: context.go('/owner/products'); break;
      case 2: context.go('/owner/orders'); break;
      case 3: context.go('/owner/inventory'); break;
      case 4: context.go('/owner/analytics'); break;
      case 5: context.go('/owner/whatsapp-sync'); break;
      case 6: context.go('/owner/settlements'); break;
      case 7: context.go('/owner/fleet-tracking'); break;
      case 8: context.go('/owner/attendance'); break;
      case 9: context.go('/owner/rider-support'); break;
      case 10: context.go('/owner/pricing-rules'); break;
      case 11: context.go('/owner/reviews'); break;
      case 12: context.go('/owner/vendor-request'); break;
      case 13: context.go('/owner/khata'); break;
      case 14: context.go('/owner/devices'); break;
      case 15: context.go('/owner/scan-activity'); break;
      case 16: context.go('/owner/releases'); break;
      case 17: context.go('/owner/shop-settings'); break;
      case 18: context.go('/owner/broadcast'); break;
      case 19: context.go('/owner/mandi-pricing'); break;
      case 20: context.go('/owner/smart-dispatch'); break;
      case 21: context.go('/owner/barcode-inventory'); break;
      case 22: context.go('/owner/campaigns'); break;
      case 23: context.go('/owner/retention'); break;
      case 24: context.go('/owner/logistics-command-center'); break;
      case 25: context.go('/owner/bi/decision-center'); break;
      case 26: context.go('/owner/failed-deliveries'); break;
      case 27: context.go('/owner/mission-control'); break;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      orderProvider.listenToAllOrders();
    });
  }

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
    'Security & Devices',
    'Scan Activity',
    'App Releases',
    'Shop Settings',
    'Broadcast',
    'Mandi Pricing',
    'Smart Dispatch',
    'Barcode Inventory',
    'Marketing Campaigns',
    'Customer Retention',
    'Logistics Command Center',
    'AI Decision Center',
    'Failed Deliveries',
    'Mission Control',
  ];

  IconData _getIconForIndex(int index, bool isSelected) {
    switch (index) {
      case 0: return isSelected ? Icons.dashboard : Icons.dashboard_outlined;
      case 1: return isSelected ? Icons.inventory_2 : Icons.inventory_2_outlined;
      case 2: return isSelected ? Icons.shopping_bag : Icons.shopping_bag_outlined;
      case 3: return isSelected ? Icons.warehouse : Icons.warehouse_outlined;
      case 4: return isSelected ? Icons.analytics : Icons.analytics_outlined;
      case 5: return isSelected ? Icons.message : Icons.message_outlined;
      case 6: return isSelected ? Icons.handshake : Icons.handshake_outlined;
      case 7: return isSelected ? Icons.delivery_dining : Icons.delivery_dining_outlined;
      case 8: return isSelected ? Icons.people : Icons.people_outline;
      case 9: return isSelected ? Icons.chat : Icons.chat_outlined;
      case 10: return isSelected ? Icons.currency_rupee : Icons.currency_rupee_outlined;
      case 11: return isSelected ? Icons.rate_review : Icons.rate_review_outlined;
      case 12: return isSelected ? Icons.local_shipping : Icons.local_shipping_outlined;
      case 13: return isSelected ? Icons.menu_book : Icons.menu_book_outlined;
      case 14: return isSelected ? Icons.security : Icons.security_outlined;
      case 15: return isSelected ? Icons.qr_code_scanner : Icons.qr_code_scanner_outlined;
      case 16: return isSelected ? Icons.system_update : Icons.system_update_outlined;
      case 17: return isSelected ? Icons.settings : Icons.settings_outlined;
      case 18: return isSelected ? Icons.podcasts : Icons.podcasts_outlined;
      case 19: return isSelected ? Icons.trending_up : Icons.trending_up_outlined;
      case 20: return isSelected ? Icons.route : Icons.route_outlined;
      case 21: return isSelected ? Icons.document_scanner : Icons.document_scanner_outlined;
      case 22: return isSelected ? Icons.campaign : Icons.campaign_outlined;
      case 23: return isSelected ? Icons.favorite : Icons.favorite_outline;
      case 24: return isSelected ? Icons.flight_takeoff : Icons.flight_takeoff_outlined;
      case 25: return isSelected ? Icons.gavel : Icons.gavel_outlined;
      case 26: return isSelected ? Icons.report_problem : Icons.report_problem_outlined;
      case 27: return isSelected ? Icons.rocket_launch : Icons.rocket_launch_outlined;
      default: return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopConfigProvider = Provider.of<ShopConfigProvider>(context);
    final isShopOpen = shopConfigProvider.shopConfig?.isOpen ?? true;
    final useRail = Responsive.useRailNav(context);
    final selectedIndex = _getSelectedIndex(context);

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        backgroundColor: AppTheme.cream,
        elevation: 0,
        title: Text(_titles[selectedIndex], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          // More compact shop status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isShopOpen ? AppTheme.success : AppTheme.error).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: isShopOpen ? AppTheme.success : AppTheme.error),
                const SizedBox(width: 4),
                Text(
                  isShopOpen ? 'OPEN' : 'CLOSED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isShopOpen ? AppTheme.success : AppTheme.error,
                  ),
                ),
                Transform.scale(
                  scale: 0.7,
                  child: SizedBox(
                    height: 24,
                    width: 40,
                    child: Switch(
                      value: isShopOpen,
                      onChanged: (value) async {
                        await shopConfigProvider.setShopOpen(value);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'whatsapp') showWhatsAppSimulator(context);
              if (value == 'role') context.push('/role-select');
              if (value == 'notifications') context.push('/customer/notifications');
              if (value == 'logout') {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Provider.of<AuthProvider>(context, listen: false).logout();
                        },
                        child: const Text('Logout', style: TextStyle(color: AppTheme.error)),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'whatsapp',
                child: Row(children: [Icon(Icons.message, color: AppTheme.success, size: 20), SizedBox(width: 8), Text('WhatsApp Sim')]),
              ),
              const PopupMenuItem(
                value: 'role',
                child: Row(children: [Icon(Icons.swap_horiz, size: 20), SizedBox(width: 8), Text('Switch Role')]),
              ),
              const PopupMenuItem(
                value: 'notifications',
                child: Row(children: [Icon(Icons.notifications_outlined, size: 20), SizedBox(width: 8), Text('Notifications')]),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [Icon(Icons.logout, color: AppTheme.error, size: 20), SizedBox(width: 8), Text('Logout')]),
              ),
            ],
          ),
        ],
      ),
      drawer: useRail ? null : Drawer(
        backgroundColor: AppTheme.cream,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: AppTheme.heroGradient,
              ),
              child: const Center(
                child: Text(
                  'Owner Dashboard',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _titles.length,
                itemBuilder: (context, index) {
                  final isSelected = selectedIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Icon(
                          _getIconForIndex(index, isSelected),
                          color: isSelected ? AppTheme.primary : AppTheme.grey600,
                        ),
                        title: Text(
                          _titles[index],
                          style: TextStyle(
                            color: isSelected ? AppTheme.primary : AppTheme.grey800,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          _onItemTapped(index, context);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showVoiceCommandSheet(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.mic, color: Colors.white),
        label: const Text(
          'Voice',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        tooltip: 'Voice Command (Hindi)',
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
                      onDestinationSelected: (index) {
                        _onItemTapped(index, context);
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
                          icon: Icon(Icons.security_outlined),
                          selectedIcon: Icon(Icons.security),
                          label: Text('Devices'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.qr_code_scanner_outlined),
                          selectedIcon: Icon(Icons.qr_code_scanner),
                          label: Text('Scan Log'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.system_update_outlined),
                          selectedIcon: Icon(Icons.system_update),
                          label: Text('Releases'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.settings_outlined),
                          selectedIcon: Icon(Icons.settings),
                          label: Text('Settings'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.podcasts_outlined),
                          selectedIcon: Icon(Icons.podcasts),
                          label: Text('Broadcast'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.trending_up_outlined),
                          selectedIcon: Icon(Icons.trending_up),
                          label: Text('Mandi Price'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.route_outlined),
                          selectedIcon: Icon(Icons.route),
                          label: Text('Dispatch'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.document_scanner_outlined),
                          selectedIcon: Icon(Icons.document_scanner),
                          label: Text('Barcode'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.campaign_outlined),
                          selectedIcon: Icon(Icons.campaign),
                          label: Text('Campaigns'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.favorite_outline),
                          selectedIcon: Icon(Icons.favorite),
                          label: Text('Retention'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.gavel_outlined),
                          selectedIcon: Icon(Icons.gavel),
                          label: Text('AI Decisions'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.rocket_launch_outlined),
                          selectedIcon: Icon(Icons.rocket_launch),
                          label: Text('Mission Control'),
                        ),
                      ],

                    ),
                    ),
                  ),
                );
              },
            ),
          if (useRail)
            const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

class OwnerHomePage extends StatelessWidget {
  const OwnerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final stats = orderProvider.getShopStats();

    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Welcome Card
            _buildWelcomeCard(context),
            const SizedBox(height: 24),

            // 2. TODAY'S SNAPSHOT - KPI Cards (4 main metrics)
            _buildTodaySnapshot(context, stats),
            const SizedBox(height: 24),

            // 3. QUICK ALERTS - Only critical/warning items
            _buildQuickAlerts(context),
            const SizedBox(height: 24),

            // 4. QUICK ACTIONS - 4 main tiles (Pack, Sales, Inventory, Employees)
            _buildQuickActions(context),
            const SizedBox(height: 24),

            // 5. WEEKLY SUMMARY - Simple growth stats
            _buildWeeklySummary(context),
            const SizedBox(height: 24),

            // 6. RECENT ORDERS - Keep it simple
            _buildRecentOrdersSection(orderProvider.orders),
          ],
        ),
      ),
    );
  }

  // ─────────────── 1. WELCOME CARD ───────────────
  Widget _buildWelcomeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back!',
                  style: AppTheme.headlineSmall(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Here's your shop status today",
                  style: AppTheme.bodyMedium(context).copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront, size: 36, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ─────────────── 2. TODAY'S SNAPSHOT ───────────────
  Widget _buildTodaySnapshot(BuildContext context, Map<String, dynamic> stats) {
    final int totalOrders = (stats['todayOrderCount'] as num? ?? 0).toInt();
    final int pendingOrders = (stats['pendingOrderCount'] as num? ?? 0).toInt();
    final double netRevenue = (stats['todayNetRevenue'] as num? ?? 0.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TODAY\'S SNAPSHOT',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.grey700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: Responsive.kpiColumns(context),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: Responsive.isMobile(context) ? 0.8 : 1.1,
          children: [
            // Card 1: Total Orders
            _buildKPICard(
              icon: Icons.shopping_bag_outlined,
              label: 'Orders',
              value: totalOrders,
              color: AppTheme.info,
              onTap: () => context.push('/owner/orders'),
            ),

            // Card 2: Net Revenue
            _buildKPICard(
              icon: Icons.account_balance_wallet,
              label: 'Net Revenue',
              value: netRevenue.round(),
              prefix: '₹',
              color: AppTheme.success,
              onTap: () => context.push('/owner/analytics'),
            ),

            // Card 3: Pending Orders
            _buildKPICard(
              icon: Icons.pending_actions,
              label: 'Pending',
              value: pendingOrders,
              color: AppTheme.warning,
              onTap: () => context.push('/owner/orders'),
            ),

            // Card 4: Active Agents
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'deliveryAgent')
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, agentSnap) {
                final count = agentSnap.data?.docs.length ?? 0;
                return _buildKPICard(
                  icon: Icons.delivery_dining_outlined,
                  label: 'Agents Online',
                  value: count,
                  color: AppTheme.primary,
                  onTap: () => context.push('/owner/fleet-tracking'),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // Build individual KPI card
  Widget _buildKPICard({
    required IconData icon,
    required String label,
    required num value,
    String prefix = '',
    required Color color,
    required VoidCallback onTap,
  }) {
    return ScaleBounce(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedCounter(
                value: value,
                prefix: prefix,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.grey600,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── 3. QUICK ALERTS ───────────────
  Widget _buildQuickAlerts(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('alerts').snapshots(),
      builder: (context, snapshot) {
        List<Map<String, dynamic>> alerts = [];

        if (snapshot.hasData) {
          // TODO: Parse alerts from Firestore
          // For now, show mock alerts
          alerts = [
            {'type': 'danger', 'message': '3 items out of stock'},
            {'type': 'warning', 'message': '₹12,400 pending settlement'},
          ];
        }

        if (alerts.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.success.withValues(alpha: 0.2), width: 1),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.success, size: 24),
                SizedBox(width: 12),
                Text(
                  'All systems running smoothly!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ALERTS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.grey700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            ...alerts.map((alert) {
              final isWarning = alert['type'] == 'warning';
              final color = isWarning ? AppTheme.warning : AppTheme.error;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isWarning ? Icons.warning : Icons.error,
                        color: color,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          alert['message'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: color),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // ─────────────── 4. QUICK ACTIONS ───────────────
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QUICK ACTIONS',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.grey700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: Responsive.kpiColumns(context),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: Responsive.isMobile(context) ? 0.75 : 1.0,
          children: [
            _buildActionTile(
              icon: Icons.inventory_2,
              label: 'Pack Orders',
              color: AppTheme.deliveryAccent,
              onTap: () => context.push('/owner/packing-terminal'),
              context: context,
            ),
            _buildActionTile(
              icon: Icons.analytics,
              label: 'View Sales',
              color: AppTheme.ownerAccent,
              onTap: () => context.push('/owner/analytics'),
              context: context,
            ),
            _buildActionTile(
              icon: Icons.warehouse,
              label: 'Inventory',
              color: AppTheme.employeeAccent,
              onTap: () => context.push('/owner/inventory'),
              context: context,
            ),
            _buildActionTile(
              icon: Icons.people,
              label: 'Employees',
              color: AppTheme.primary,
              onTap: () => context.push('/owner/employee-management'),
              context: context,
            ),
            _buildActionTile(
              icon: Icons.segment,
              label: 'Segments',
              color: Colors.purple,
              onTap: () => context.push('/owner/customer-segments'),
              context: context,
            ),
            _buildActionTile(
              icon: Icons.timer_outlined,
              label: 'Delivery SLA',
              color: Colors.teal,
              onTap: () => context.push('/owner/delivery-sla'),
              context: context,
            ),
            _buildActionTile(
              icon: Icons.report_problem_outlined,
              label: 'Failed Deliveries',
              color: AppTheme.error,
              onTap: () => context.push('/owner/failed-deliveries'),
              context: context,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── 5. WEEKLY SUMMARY ───────────────
  Widget _buildWeeklySummary(BuildContext context) {
    final today = DateTime.now();
    final oneWeekAgo = today.subtract(const Duration(days: 7));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'THIS WEEK',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.grey700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('createdAt',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(oneWeekAgo))
              .snapshots(),
          builder: (context, snapshot) {
            int weekOrders = 0;
            double weekRevenue = 0.0;

            if (snapshot.hasData) {
              for (final doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                weekOrders++;
                if (data['isPaid'] == true || data['paymentStatus'] == 'paid') {
                  weekRevenue += (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                }
              }
            }

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.grey200),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'Total Orders',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        weekOrders.toString(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: AppTheme.grey200,
                  ),
                  Column(
                    children: [
                      const Text(
                        'Total Revenue',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${weekRevenue.round()}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: AppTheme.grey200,
                  ),
                  Column(
                    children: [
                      const Text(
                        'Daily Avg',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        weekOrders > 0
                            ? '${(weekOrders / 7).toStringAsFixed(0)} orders'
                            : '0 orders',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.info,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ─────────────── 6. RECENT ORDERS ───────────────
  Widget _buildRecentOrdersSection(List<OrderModel> orders) {
    final recentOrders = orders.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.grey200),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RECENT ORDERS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          if (recentOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No orders yet today.',
                style: TextStyle(color: AppTheme.grey500),
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
                            '${order.customerName} • ${order.items.length} items',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.grey600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${order.totalAmount.toDouble().round()}',
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
            }),
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
        return AppTheme.info;
      case 'Delivered':
        return AppTheme.success;
      default:
        return AppTheme.grey500;
    }
  }
}