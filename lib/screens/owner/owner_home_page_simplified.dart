import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../providers/order_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive.dart';
import '../../models/order_model.dart';

// ============================================================================
// OWNER HOME PAGE — Simplified for Professional Local Store
// ============================================================================
// Shows: Today's KPIs (Orders, Revenue, Pending, Returns) + Alerts + Quick Actions
// NO overwhelming widgets — clean, at-a-glance dashboard
// ============================================================================

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
            _buildWelcomeCard(),
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
  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  "Here's your shop status today",
                  style: TextStyle(fontSize: 14, color: Colors.white70),
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
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

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
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('createdAt',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .snapshots(),
          builder: (context, snapshot) {
            int totalOrders = 0;
            int packedOrders = 0;
            double todayRevenue = 0.0;

            if (snapshot.hasData) {
              final docs = snapshot.data!.docs;
              totalOrders = docs.length;

              for (final doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] ?? '';

                // Count packed orders
                if (status == 'packed' || status == 'dispatched') {
                  packedOrders++;
                }

                // Sum revenue (only paid orders)
                if (data['isPaid'] == true || data['paymentStatus'] == 'paid') {
                  todayRevenue += (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                }
              }
            }

            final pendingOrders = totalOrders - packedOrders;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: Responsive.kpiColumns(context),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
              children: [
                // Card 1: Total Orders
                _buildKPICard(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Orders',
                  value: totalOrders.toString(),
                  color: AppTheme.info,
                  onTap: () => context.push('/owner/orders'),
                ),

                // Card 2: Revenue
                _buildKPICard(
                  icon: Icons.currency_rupee,
                  label: 'Revenue',
                  value: '₹${todayRevenue.round()}',
                  color: AppTheme.success,
                  onTap: () => context.push('/owner/analytics'),
                ),

                // Card 3: Pending Packing
                _buildKPICard(
                  icon: Icons.pending_actions,
                  label: 'Pending Pack',
                  value: pendingOrders.toString(),
                  color: AppTheme.warning,
                  onTap: () => context.push('/owner/packing-terminal'),
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
                      value: count.toString(),
                      color: AppTheme.primary,
                      onTap: () => context.push('/owner/fleet-tracking'),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // Build individual KPI card
  Widget _buildKPICard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.grey600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
          children: [
            _buildActionTile(
              icon: Icons.inventory_2,
              label: 'Pack Orders',
              color: const Color(0xFF00897B),
              onTap: () => context.push('/owner/packing-terminal'),
              context: context,
            ),
            _buildActionTile(
              icon: Icons.analytics,
              label: 'View Sales',
              color: const Color(0xFF1976D2),
              onTap: () => context.push('/owner/analytics'),
              context: context,
            ),
            _buildActionTile(
              icon: Icons.warehouse,
              label: 'Inventory',
              color: const Color(0xFF7B1FA2),
              onTap: () => context.push('/owner/inventory'),
              context: context,
            ),
            _buildActionTile(
              icon: Icons.people,
              label: 'Employees',
              color: const Color(0xFFF57C00),
              onTap: () => context.push('/owner/employee-management'),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
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
