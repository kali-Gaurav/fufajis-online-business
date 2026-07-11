import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fufaji/providers/analytics_dashboard_provider.dart';
import 'package:fufaji/widgets/analytics/metric_card.dart';

class DeliveryPerformanceScreen extends StatefulWidget {
  const DeliveryPerformanceScreen({Key? key}) : super(key: key);

  @override
  State<DeliveryPerformanceScreen> createState() =>
      _DeliveryPerformanceScreenState();
}

class _DeliveryPerformanceScreenState extends State<DeliveryPerformanceScreen> {
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
        title: const Text('Delivery Performance'),
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
                    'Error loading delivery data',
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
                    _buildDeliveryMetrics(context, provider),
                    const SizedBox(height: 24),
                    _buildAgentRankings(context, provider),
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

  Widget _buildDeliveryMetrics(
    BuildContext context,
    AnalyticsDashboardProvider provider,
  ) {
    final delivery = provider.deliveryMetrics;
    if (delivery == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Metrics',
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
              label: 'Total Deliveries',
              value: delivery.totalDeliveries.toString(),
              subtitle: 'today',
              icon: Icons.local_shipping,
              iconColor: Colors.blue,
            ),
            MetricCard(
              label: 'On-Time %',
              value: '${delivery.onTimePercentage.toStringAsFixed(1)}%',
              subtitle: 'on schedule',
              icon: Icons.check_circle,
              iconColor: Colors.green,
            ),
            MetricCard(
              label: 'Avg Delivery Time',
              value: '${delivery.avgDeliveryTime} min',
              subtitle: 'from warehouse',
              icon: Icons.timer,
              iconColor: Colors.orange,
            ),
            MetricCard(
              label: 'ETA Accuracy',
              value: '${delivery.etaAccuracy.toStringAsFixed(1)}%',
              subtitle: 'prediction accuracy',
              icon: Icons.target,
              iconColor: Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAgentRankings(
    BuildContext context,
    AnalyticsDashboardProvider provider,
  ) {
    final delivery = provider.deliveryMetrics;
    if (delivery == null || delivery.agentMetrics.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sortedAgents = delivery.agentMetrics.toList()
      ..sort((a, b) => b.avgRating.compareTo(a.avgRating));

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
            'Top Performing Agents',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ...sortedAgents.take(5).asMap().entries.map((entry) {
            final index = entry.key;
            final agent = entry.value;
            final medal = _getMedalIcon(index);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getRankColor(index).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        medal,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          agent.agentName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${agent.deliveriesCompleted} deliveries • ${agent.onTimePercentage.toStringAsFixed(1)}% on-time',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            agent.avgRating.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: agent.issuesCount == 0
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${agent.issuesCount} issues',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: agent.issuesCount == 0
                                        ? Colors.green
                                        : Colors.orange,
                                    fontSize: 10,
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

  Color _getRankColor(int index) {
    if (index == 0) return Colors.amber;
    if (index == 1) return Colors.grey;
    if (index == 2) return Colors.orange;
    return Colors.blue;
  }

  String _getMedalIcon(int index) {
    if (index == 0) return '🥇';
    if (index == 1) return '🥈';
    if (index == 2) return '🥉';
    return '${index + 1}';
  }
}
