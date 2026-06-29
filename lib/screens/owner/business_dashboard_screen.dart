import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/app_theme.dart';
import '../../providers/business_intelligence_provider.dart';
import '../../services/business_intelligence_service.dart';
import '../../widgets/owner/bi_widgets.dart';

/// Business KPIs: orders funnel, new vs returning, retention/churn,
/// AOV trend, growth, and customer lifetime-value distribution.
class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BusinessIntelligenceProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Business Dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          Consumer<BusinessIntelligenceProvider>(
            builder: (context, p, _) => IconButton(
              tooltip: 'Export PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: p.data == null ? null : () => p.exportPdf(),
            ),
          ),
        ],
      ),
      body: Consumer<BusinessIntelligenceProvider>(
        builder: (context, p, _) {
          return RefreshIndicator(
            onRefresh: p.refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                BiRangeSelector(
                  selected: p.range,
                  onSelected: (r) => p.setRange(r),
                ),
                const SizedBox(height: 16),
                if (p.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent)),
                  )
                else if (p.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Text(p.error!,
                          style: const TextStyle(color: AppTheme.error)),
                    ),
                  )
                else
                  ..._buildContent(b: p.business),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildContent({required BusinessReport b}) {
    final clv = b.clvDistribution
        .map((k, v) => MapEntry(k, v.toDouble()));
    return [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
        children: [
          BiKpiCard(
            label: 'Total Orders',
            value: '${b.totalOrders}',
            icon: Icons.receipt_long_outlined,
            color: AppTheme.primary,
            growth: b.orderGrowth,
          ),
          BiKpiCard(
            label: 'Avg Order Value',
            value: kInr.format(b.avgOrderValue),
            icon: Icons.shopping_bag_outlined,
            color: AppTheme.info,
          ),
          BiKpiCard(
            label: 'Retention Rate',
            value: '${b.retentionRate.toStringAsFixed(1)}%',
            icon: Icons.favorite_outline,
            color: AppTheme.success,
            subtitle: '${b.returningCustomers} returning',
          ),
          BiKpiCard(
            label: 'Churn Rate',
            value: '${b.churnRate.toStringAsFixed(1)}%',
            icon: Icons.person_off_outlined,
            color: AppTheme.error,
            subtitle: 'inactive > 30 days',
          ),
        ],
      ),
      const SizedBox(height: 16),
      BiSectionCard(
        title: 'Order Fulfilment Funnel',
        child: Column(
          children: [
            _funnelBar('Placed / Processing', b.ordersPlaced, b.totalOrders,
                AppTheme.info),
            _funnelBar('Packed', b.ordersPacked, b.totalOrders,
                const Color(0xFF9C27B0)),
            _funnelBar('Out for Delivery', b.ordersShipped, b.totalOrders,
                const Color(0xFF00BCD4)),
            _funnelBar(
                'Delivered', b.ordersDelivered, b.totalOrders, AppTheme.success),
            _funnelBar('Cancelled', b.ordersCancelled, b.totalOrders,
                AppTheme.error),
            _funnelBar('Returned / Refunded', b.ordersReturned, b.totalOrders,
                AppTheme.warning),
          ],
        ),
      ),
      const SizedBox(height: 16),
      BiSectionCard(
        title: 'New vs Returning Customers',
        child: BiDonutChart(
          data: {
            'New': b.newCustomers.toDouble(),
            'Returning': b.returningCustomers.toDouble(),
          },
          height: 170,
        ),
      ),
      const SizedBox(height: 16),
      BiSectionCard(
        title: 'Average Order Value Trend',
        child: BiLineChart(
          values: b.aovTrend.map((d) => d.value).toList(),
          color: AppTheme.info,
        ),
      ),
      const SizedBox(height: 16),
      BiSectionCard(
        title: 'Customer Lifetime-Value Distribution',
        child: BiBarChart(data: clv, color: AppTheme.success),
      ),
      const SizedBox(height: 16),
      BiSectionCard(
        title: 'Customer Snapshot',
        child: Column(
          children: [
            _stat('Total Customers', '${b.totalCustomers}'),
            _stat('New Customers', '${b.newCustomers}'),
            _stat('Returning Customers', '${b.returningCustomers}'),
            _stat('Avg Customer LTV', kInr.format(b.avgCustomerLtv)),
          ],
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _funnelBar(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.grey700)),
              Text('$count',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppTheme.grey100,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppTheme.grey700)),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.grey900)),
        ],
      ),
    );
  }
}
