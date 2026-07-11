import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fufaji/providers/analytics_dashboard_provider.dart';

class InventoryInsightsScreen extends StatefulWidget {
  const InventoryInsightsScreen({Key? key}) : super(key: key);

  @override
  State<InventoryInsightsScreen> createState() =>
      _InventoryInsightsScreenState();
}

class _InventoryInsightsScreenState extends State<InventoryInsightsScreen> {
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
        title: const Text('Inventory Insights'),
        elevation: 0,
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
                    'Error loading inventory data',
                    style: Theme.of(context).textTheme.titleMedium,
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
                    _buildAlertsSummary(context, provider),
                    const SizedBox(height: 24),
                    _buildLowStockAlerts(context, provider),
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

  Widget _buildAlertsSummary(
    BuildContext context,
    AnalyticsDashboardProvider provider,
  ) {
    final lowStock = provider.lowStockAlerts;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final outOfStock = lowStock?.where((e) => e.alertStatus == 'out_of_stock').length ?? 0;
    final lowStockCount = lowStock?.where((e) => e.alertStatus == 'low_stock').length ?? 0;
    final nearExpiry = lowStock?.where((e) => e.alertStatus == 'near_expiry').length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stock Status Summary',
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error,
                    color: Colors.red,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    outOfStock.toString(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Out of Stock',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning,
                    color: Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lowStockCount.toString(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Low Stock',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.yellow.withOpacity(0.1),
                border: Border.all(
                  color: Colors.yellow.withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule,
                    color: Colors.yellow[700],
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nearExpiry.toString(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.yellow[700],
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Near Expiry',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Healthy',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'in stock',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLowStockAlerts(
    BuildContext context,
    AnalyticsDashboardProvider provider,
  ) {
    final alerts = provider.lowStockAlerts;
    if (alerts == null || alerts.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sortedAlerts = alerts.toList()
      ..sort((a, b) {
        final priorityA =
            a.alertStatus == 'out_of_stock' ? 0 : (a.alertStatus == 'low_stock' ? 1 : 2);
        final priorityB =
            b.alertStatus == 'out_of_stock' ? 0 : (b.alertStatus == 'low_stock' ? 1 : 2);
        return priorityA.compareTo(priorityB);
      });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stock Alerts (${alerts.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ...sortedAlerts.take(10).map((alert) {
            final color = _getAlertColor(alert.alertStatus);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.productName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${alert.stockLevel} units in stock',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getAlertLabel(alert.alertStatus),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: color,
                            fontSize: 10,
                          ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (alerts.length > 10) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {},
              child: Text('View all ${alerts.length} alerts'),
            ),
          ],
        ],
      ),
    );
  }

  Color _getAlertColor(String status) {
    switch (status) {
      case 'out_of_stock':
        return Colors.red;
      case 'low_stock':
        return Colors.orange;
      case 'near_expiry':
        return Colors.yellow[700]!;
      default:
        return Colors.grey;
    }
  }

  String _getAlertLabel(String status) {
    switch (status) {
      case 'out_of_stock':
        return 'Out of Stock';
      case 'low_stock':
        return 'Low Stock';
      case 'near_expiry':
        return 'Expiring Soon';
      default:
        return 'Alert';
    }
  }
}
