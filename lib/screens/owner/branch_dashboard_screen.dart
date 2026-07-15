import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/owner_analytics_provider.dart';
import '../../models/shop_branch_model.dart';
import '../../models/alert_model.dart';
import '../../utils/app_theme.dart';

class BranchDashboardScreen extends StatefulWidget {
  const BranchDashboardScreen({super.key});

  @override
  State<BranchDashboardScreen> createState() => _BranchDashboardScreenState();
}

class _BranchDashboardScreenState extends State<BranchDashboardScreen> {
  // Mock list of branches for the UI, ideally fetched from a provider
  final List<ShopBranchModel> _mockBranches = [
    ShopBranchModel(
      id: 'global',
      branchName: 'All Branches (Global)',
      branchAddress: '',
      latitude: 0,
      longitude: 0,
      deliveryRadiusKm: 0,
      deliveryZones: [],
      isPrimary: true,
      isActive: true,
      operatingHours: {},
    ),
    ShopBranchModel(
      id: 'jodhpur_01',
      branchName: 'Jodhpur Branch',
      branchAddress: 'Sardarpura, Jodhpur',
      latitude: 26.28,
      longitude: 73.02,
      deliveryRadiusKm: 10,
      deliveryZones: [],
      isPrimary: false,
      isActive: true,
      operatingHours: {},
    ),
    ShopBranchModel(
      id: 'jaipur_01',
      branchName: 'Jaipur Branch',
      branchAddress: 'Malviya Nagar, Jaipur',
      latitude: 26.91,
      longitude: 75.78,
      deliveryRadiusKm: 12,
      deliveryZones: [],
      isPrimary: false,
      isActive: true,
      operatingHours: {},
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OwnerAnalyticsProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Franchise Analytics', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<OwnerAnalyticsProvider>().initialize();
            },
          ),
        ],
      ),
      body: Consumer<OwnerAnalyticsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.metrics == null) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
          }

          if (provider.errorMessage != null && provider.metrics == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                  const SizedBox(height: 16),
                  Text(provider.errorMessage!),
                  ElevatedButton(
                    onPressed: () => provider.initialize(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final metrics = provider.metrics;

          return RefreshIndicator(
            onRefresh: () => provider.initialize(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildBranchSelector(provider),
                const SizedBox(height: 24),
                if (metrics != null) ...[
                  _buildSummaryCards(metrics, provider.pendingOrdersCount),
                  const SizedBox(height: 24),
                  _buildAlertsSection(provider),
                  const SizedBox(height: 24),
                  _buildCustomerGrowthSection(metrics),
                ] else ...[
                  const Center(child: Text('No data available')),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBranchSelector(OwnerAnalyticsProvider provider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: provider.selectedBranchId ?? 'global',
            icon: const Icon(Icons.storefront),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            items: _mockBranches.map((branch) {
              return DropdownMenuItem<String>(value: branch.id, child: Text(branch.branchName));
            }).toList(),
            onChanged: (value) {
              if (value == 'global') {
                provider.setGlobalView();
              } else {
                provider.setSelectedBranch(value);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(dynamic metrics, int activeOrders) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      children: [
        _MetricCard(
          title: "Today's Revenue",
          value: '₹${metrics.totalRevenue.toStringAsFixed(0)}',
          icon: Icons.currency_rupee,
          color: AppTheme.success,
          trend: '+${metrics.revenueGrowth.toStringAsFixed(1)}%',
        ),
        _MetricCard(
          title: 'Active Orders',
          value: activeOrders.toString(),
          icon: Icons.shopping_bag,
          color: AppTheme.info,
          trend: 'Live',
        ),
        _MetricCard(
          title: 'Total Customers',
          value: metrics.totalCustomers.toString(),
          icon: Icons.people,
          color: Colors.purple,
          trend: '+${metrics.newCustomers} New',
        ),
        _MetricCard(
          title: 'Profit Margin',
          value: '${metrics.profitMargin.toStringAsFixed(1)}%',
          icon: Icons.trending_up,
          color: AppTheme.warning,
          trend: 'Gross',
        ),
      ],
    );
  }

  Widget _buildAlertsSection(OwnerAnalyticsProvider provider) {
    final alerts = provider.alerts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Operational Alerts',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (alerts.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No active alerts. Everything is running smoothly!')),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: alerts.take(3).length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    alert.severity == AlertSeverity.critical
                        ? Icons.error
                        : (alert.severity == AlertSeverity.warning ? Icons.warning : Icons.info),
                    color: alert.severity == AlertSeverity.critical
                        ? AppTheme.error
                        : (alert.severity == AlertSeverity.warning
                              ? AppTheme.warning
                              : AppTheme.info),
                  ),
                  title: Text(alert.message),
                  trailing: TextButton(
                    onPressed: () => provider.resolveAlert(alert.alertId),
                    child: Text(alert.action ?? 'Resolve'),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCustomerGrowthSection(dynamic metrics) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Retention',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCircularMetric(
                  'Repeat Rate',
                  '${metrics.repeatPurchaseRate.toStringAsFixed(0)}%',
                  Colors.teal,
                ),
                _buildCircularMetric('New Users', '${metrics.newCustomers}', AppTheme.ownerAccent),
                _buildCircularMetric(
                  'Avg LTV',
                  '₹${metrics.avgCustomerLTV.toStringAsFixed(0)}',
                  AppTheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularMetric(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5), width: 3),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String trend;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
