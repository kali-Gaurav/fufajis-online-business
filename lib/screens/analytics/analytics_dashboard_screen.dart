import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fufaji/providers/analytics_dashboard_provider.dart';
import 'package:fufaji/providers/alerts_provider.dart';
import 'package:fufaji/models/analytics_models.dart';
import 'package:fufaji/widgets/analytics/metric_card.dart';
import 'package:fufaji/widgets/analytics/trend_chart.dart';
import 'package:fufaji/widgets/analytics/alert_widget.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<AnalyticsDashboardProvider>().loadDailyMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        elevation: 0,
        actions: [
          Consumer<AnalyticsDashboardProvider>(
            builder: (context, provider, _) {
              return PopupMenuButton<AnalyticsPeriod>(
                onSelected: (period) {
                  provider.setPeriod(period);
                },
                itemBuilder: (BuildContext context) {
                  return [
                    PopupMenuItem(
                      value: AnalyticsPeriod.today,
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: provider.selectedPeriod == AnalyticsPeriod.today
                                ? Colors.blue
                                : null,
                          ),
                          const SizedBox(width: 8),
                          const Text('Today'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: AnalyticsPeriod.week,
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_view_week,
                            size: 20,
                            color: provider.selectedPeriod == AnalyticsPeriod.week
                                ? Colors.blue
                                : null,
                          ),
                          const SizedBox(width: 8),
                          const Text('This Week'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: AnalyticsPeriod.month,
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_view_month,
                            size: 20,
                            color: provider.selectedPeriod == AnalyticsPeriod.month
                                ? Colors.blue
                                : null,
                          ),
                          const SizedBox(width: 8),
                          const Text('This Month'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: AnalyticsPeriod.year,
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: provider.selectedPeriod == AnalyticsPeriod.year
                                ? Colors.blue
                                : null,
                          ),
                          const SizedBox(width: 8),
                          const Text('This Year'),
                        ],
                      ),
                    ),
                  ];
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<AnalyticsDashboardProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading analytics',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => provider.loadDailyMetrics(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadDailyMetrics(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKPICards(context, provider),
                    const SizedBox(height: 24),
                    _buildAlertsSection(context),
                    const SizedBox(height: 24),
                    _buildRevenueChart(context, provider),
                    const SizedBox(height: 24),
                    _buildQuickActions(context),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKPICards(
    BuildContext context,
    AnalyticsDashboardProvider provider,
  ) {
    final metrics = provider.metrics;
    if (metrics == null) {
      return const SizedBox.shrink();
    }

    final comparison = provider.getComparison();
    final revenueChange = comparison['revenue'] ?? 0;
    final ordersChange = comparison['orders'] ?? 0;
    final customersChange = comparison['customers'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Performance Indicators',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            MetricCard(
              label: 'Total Revenue',
              value: metrics.totalRevenueFormatted,
              subtitle: 'for ${provider.selectedPeriod.label}',
              icon: Icons.trending_up,
              iconColor: Colors.green,
              percentageChange: revenueChange,
              isPositive: revenueChange >= 0,
            ),
            MetricCard(
              label: 'Total Orders',
              value: metrics.totalOrders.toString(),
              subtitle: 'orders placed',
              icon: Icons.shopping_bag,
              iconColor: Colors.blue,
              percentageChange: ordersChange,
              isPositive: ordersChange >= 0,
            ),
            MetricCard(
              label: 'Avg Order Value',
              value: metrics.avgOrderValueFormatted,
              subtitle: 'per order',
              icon: Icons.paid,
              iconColor: Colors.orange,
            ),
            MetricCard(
              label: 'Total Customers',
              value: metrics.totalCustomers.toString(),
              subtitle: '${metrics.newCustomers} new',
              icon: Icons.people,
              iconColor: Colors.purple,
              percentageChange: customersChange,
              isPositive: customersChange >= 0,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlertsSection(BuildContext context) {
    return Consumer<AlertsProvider>(
      builder: (context, alertsProvider, _) {
        final alerts = alertsProvider.activeAlerts;

        if (alerts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Alerts (${alerts.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (alerts.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      alertsProvider.dismissAllAlerts();
                    },
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Dismiss All'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...alerts.take(3).map(
              (alert) => AlertWidget(
                alert: alert,
                onDismiss: () {
                  alertsProvider.dismissAlert(alert.id);
                },
              ),
            ),
            if (alerts.length > 3)
              TextButton(
                onPressed: () {
                  // Navigate to full alerts screen
                },
                child: Text('View all ${alerts.length} alerts'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRevenueChart(
    BuildContext context,
    AnalyticsDashboardProvider provider,
  ) {
    final metrics = provider.metrics;
    if (metrics == null) {
      return const SizedBox.shrink();
    }

    final data = [
      ChartDataPoint(x: 0, y: metrics.totalRevenue, label: 'Today'),
      ChartDataPoint(x: 1, y: metrics.totalRevenue * 0.95, label: 'Yesterday'),
      ChartDataPoint(x: 2, y: metrics.totalRevenue * 1.1, label: '2d ago'),
      ChartDataPoint(x: 3, y: metrics.totalRevenue * 0.85, label: '3d ago'),
      ChartDataPoint(x: 4, y: metrics.totalRevenue * 1.05, label: '4d ago'),
    ];

    return TrendChart(
      title: 'Revenue Trend',
      data: data,
      lineColor: Colors.green,
      gradientStartColor: Colors.green.withOpacity(0.3),
      gradientEndColor: Colors.green.withOpacity(0.0),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildQuickActionCard(
              context,
              'Revenue Analytics',
              Icons.trending_up,
              Colors.green,
              () {
                Navigator.of(context).pushNamed('/analytics/revenue');
              },
            ),
            _buildQuickActionCard(
              context,
              'Order Analytics',
              Icons.shopping_bag,
              Colors.blue,
              () {
                Navigator.of(context).pushNamed('/analytics/orders');
              },
            ),
            _buildQuickActionCard(
              context,
              'Customer Analytics',
              Icons.people,
              Colors.purple,
              () {
                Navigator.of(context).pushNamed('/analytics/customers');
              },
            ),
            _buildQuickActionCard(
              context,
              'Delivery Performance',
              Icons.local_shipping,
              Colors.orange,
              () {
                Navigator.of(context).pushNamed('/analytics/delivery');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
