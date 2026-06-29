import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/owner_analytics_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/owner/dashboard_widgets.dart' hide AlertCard;
import '../../widgets/alert_card.dart';
import '../../models/dashboard_metrics.dart';

/// Owner Command Center - Main dashboard screen
class OwnerCommandCenter extends StatefulWidget {
  const OwnerCommandCenter({super.key});

  @override
  State<OwnerCommandCenter> createState() => _OwnerCommandCenterState();
}

class _OwnerCommandCenterState extends State<OwnerCommandCenter> {
  String _selectedPeriod = 'Today';

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  void _loadMetrics() {
    final now = DateTime.now();
    DateTime from, to = now;

    switch (_selectedPeriod) {
      case 'Today':
        from = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        from = now.subtract(const Duration(days: 7));
        break;
      case 'Month':
        from = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'Year':
        from = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        from = DateTime(now.year, now.month, now.day);
    }

    context.read<OwnerAnalyticsProvider>().loadMetrics(from, to);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black87 : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Owner Command Center', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              // Navigate to alerts
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time Period Selector
            TimePeriodSelector(
              initialPeriod: _selectedPeriod,
              onSelected: (period) {
                setState(() => _selectedPeriod = period);
                _loadMetrics();
              },
            ),

            // KPI Cards
            _buildKPISection(),

            // Quick Actions
            _buildQuickActionsSection(),

            // Charts Section
            _buildChartsSection(),

            // Alerts Section
            _buildAlertsSection(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildKPISection() {
    return Consumer<OwnerAnalyticsProvider>(
      builder: (context, provider, _) {
        final metrics = provider.metrics;

        if (provider.isLoading) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(4, (_) => const SkeletonCard()),
            ),
          );
        }

        if (metrics == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: EmptyState(
              icon: Icons.analytics,
              title: 'No Data Available',
              subtitle: 'Start receiving orders to see analytics',
            ),
          );
        }

        final currencyFormatter = NumberFormat.currency(
          symbol: '₹',
          decimalDigits: 0,
        );

        return Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              KPICard(
                label: 'Today\'s Revenue',
                value: currencyFormatter.format(metrics.totalRevenue),
                trend: metrics.revenueGrowth,
                icon: Icons.trending_up,
                color: AppTheme.success,
              ),
              KPICard(
                label: 'Orders Today',
                value: metrics.totalOrders.toString(),
                trend: metrics.orderGrowth,
                icon: Icons.shopping_cart,
                color: AppTheme.info,
              ),
              KPICard(
                label: 'Pending Orders',
                value: metrics.pendingOrders.toString(),
                trend: null,
                icon: Icons.pending_actions,
                color: AppTheme.warning,
              ),
              KPICard(
                label: 'Active Deliveries',
                value: metrics.shippedOrders.toString(),
                trend: null,
                icon: Icons.local_shipping,
                color: Colors.purple,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Quick Actions'),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'View Orders',
                  icon: Icons.assignment,
                  onTap: () {
                    // Navigate to orders management
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  label: 'Low Stock',
                  icon: Icons.warning_amber,
                  onTap: () {
                    // Navigate to inventory
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'Manage Staff',
                  icon: Icons.people,
                  onTap: () {
                    // Navigate to employees
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  label: 'View Analytics',
                  icon: Icons.bar_chart,
                  onTap: () {
                    // Navigate to full analytics
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppTheme.info),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[200] : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    return Consumer<OwnerAnalyticsProvider>(
      builder: (context, provider, _) {
        final metrics = provider.metrics;

        if (metrics == null) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Analytics',
              subtitle: 'Performance overview',
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[850]
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[700]!
                        : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue Breakdown',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    _buildRevenueChart(metrics),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[850]
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[700]!
                        : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Status Distribution',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    _buildOrderStatusChart(metrics),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[850]
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[700]!
                        : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Products',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    _buildTopProductsList(metrics),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRevenueChart(DashboardMetrics metrics) {
    final entries = metrics.revenueByCategory.entries.toList();

    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          sections: entries
              .asMap()
              .entries
              .map((entry) {
                final category = entry.value.key;
                final value = entry.value.value;
                final colors = [
                  AppTheme.info,
                  AppTheme.success,
                  AppTheme.warning,
                  Colors.purple,
                  Colors.pink,
                ];

                return PieChartSectionData(
                  color: colors[entry.key % colors.length],
                  value: value.toDouble(),
                  title: '$category\n₹${NumberFormat('#,##0', 'en_IN').format(value)}',
                  radius: 80,
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              })
              .toList(),
          centerSpaceRadius: 40,
          sectionsSpace: 2,
        ),
      ),
    );
  }

  Widget _buildOrderStatusChart(DashboardMetrics metrics) {
    final data = [
      ('Pending', metrics.pendingOrders.toDouble(), AppTheme.warning),
      ('Packing', metrics.packingOrders.toDouble(), AppTheme.info),
      ('Shipped', metrics.shippedOrders.toDouble(), Colors.purple),
      ('Delivered', metrics.deliveredOrders.toDouble(), AppTheme.success),
      ('Cancelled', metrics.cancelledOrders.toDouble(), AppTheme.error),
    ];

    final total = data.fold<double>(0, (sum, item) => sum + item.$2);

    return Column(
      children: data.map((item) {
        final percentage = total > 0 ? (item.$2 / total) * 100 : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ProgressBar(
            label: item.$1,
            progress: percentage,
            color: item.$3,
            percentage: '${item.$2.toInt()} (${percentage.toStringAsFixed(1)}%)',
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopProductsList(DashboardMetrics metrics) {
    if (metrics.topSellers.isEmpty) {
      return const EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'No Products',
        subtitle: 'No sales data available',
      );
    }

    final currencyFormatter = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 0,
    );

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.topSellers.take(5).length,
      itemBuilder: (context, index) {
        final product = metrics.topSellers[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.unitsSold} units sold',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormatter.format(product.revenue),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: AppTheme.warning),
                      const SizedBox(width: 2),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertsSection() {
    return Consumer<OwnerAnalyticsProvider>(
      builder: (context, provider, _) {
        if (provider.alerts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Alerts & Notifications',
              subtitle: 'Critical system alerts',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: provider.alerts.map((alert) {
                  return AlertCard(
                    alert: alert,
                    onResolve: () {
                      provider.resolveAlert(alert.alertId);
                    },
                    onDismiss: () {
                      provider.dismissAlert(alert.alertId);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}
