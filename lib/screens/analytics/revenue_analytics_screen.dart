import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fufaji/providers/analytics_dashboard_provider.dart';
import 'package:fufaji/widgets/analytics/pie_chart_widget.dart';
import 'package:fufaji/widgets/analytics/metric_card.dart';

class RevenueAnalyticsScreen extends StatefulWidget {
  const RevenueAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<RevenueAnalyticsScreen> createState() => _RevenueAnalyticsScreenState();
}

class _RevenueAnalyticsScreenState extends State<RevenueAnalyticsScreen> {
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
        title: const Text('Revenue Analytics'),
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
                    'Error loading revenue data',
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
                    _buildRevenueOverview(context, provider),
                    const SizedBox(height: 24),
                    _buildCategoryBreakdown(context, provider),
                    const SizedBox(height: 24),
                    _buildPaymentMethodBreakdown(context, provider),
                    const SizedBox(height: 24),
                    _buildDetailedBreakdown(context, provider),
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

  Widget _buildRevenueOverview(
    BuildContext context,
    AnalyticsDashboardProvider provider,
  ) {
    final metrics = provider.metrics;
    if (metrics == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revenue Overview',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        MetricCard(
          label: 'Total Revenue',
          value: metrics.totalRevenueFormatted,
          subtitle: 'for ${provider.selectedPeriod.label}',
          icon: Icons.trending_up,
          iconColor: Colors.green,
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdown(
    BuildContext context,
    AnalyticsDashboardProvider provider,
  ) {
    final revenue = provider.revenueBreakdown;
    if (revenue == null || revenue.byCategory.isEmpty) {
      return const SizedBox.shrink();
    }

    return PieChartWidget(
      title: 'Revenue by Category',
      data: revenue.byCategory,
      colors: [
        Colors.blue,
        Colors.green,
        Colors.orange,
        Colors.red,
        Colors.purple,
        Colors.cyan,
      ],
      showLegend: true,
    );
  }

  Widget _buildPaymentMethodBreakdown(
    BuildContext context,
    AnalyticsDashboardProvider provider,
  ) {
    final revenue = provider.revenueBreakdown;
    if (revenue == null || revenue.byPaymentMethod.isEmpty) {
      return const SizedBox.shrink();
    }

    return PieChartWidget(
      title: 'Revenue by Payment Method',
      data: revenue.byPaymentMethod,
      colors: [Colors.blue, Colors.green, Colors.orange, Colors.red],
      showLegend: true,
    );
  }

  Widget _buildDetailedBreakdown(
    BuildContext context,
    AnalyticsDashboardProvider provider,
  ) {
    final revenue = provider.revenueBreakdown;
    if (revenue == null || revenue.byCategory.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = revenue.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
            'Top Categories',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ...categories.map((entry) {
            final total = revenue.totalRevenue;
            final percentage = (entry.value / total * 100);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value / revenue.byCategory.values.reduce((a, b) => a > b ? a : b),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
