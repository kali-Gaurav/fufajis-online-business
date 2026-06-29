import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../utils/app_theme.dart';
import '../../providers/business_intelligence_provider.dart';
import '../../services/business_intelligence_service.dart';
import '../../widgets/owner/bi_widgets.dart';

/// Financial overview: gross/net revenue, refunds, real COGS margin,
/// payment-method & category breakdowns, daily revenue trend, PDF export.
class FinancialDashboardScreen extends StatefulWidget {
  const FinancialDashboardScreen({super.key});

  @override
  State<FinancialDashboardScreen> createState() =>
      _FinancialDashboardScreenState();
}

class _FinancialDashboardScreenState extends State<FinancialDashboardScreen> {
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
        title: const Text('Financial Dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Payment Analytics',
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => context.push('/owner/payment-analytics'),
          ),
          IconButton(
            tooltip: 'Refund Processing',
            icon: const Icon(Icons.currency_exchange),
            onPressed: () => context.push('/owner/refund-processing'),
          ),
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
                  _ErrorBox(message: p.error!, onRetry: p.refresh)
                else
                  ..._buildContent(context, p.financial),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context, FinancialReport f) {
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
            label: 'Net Revenue',
            value: kInr.format(f.netRevenue),
            icon: Icons.account_balance_wallet_outlined,
            color: AppTheme.primary,
            growth: f.revenueGrowth,
          ),
          BiKpiCard(
            label: 'Gross Revenue',
            value: kInr.format(f.grossRevenue),
            icon: Icons.trending_up,
            color: AppTheme.info,
          ),
          BiKpiCard(
            label: 'Gross Profit',
            value: kInr.format(f.grossProfit),
            icon: Icons.savings_outlined,
            color: AppTheme.success,
            subtitle: '${f.profitMargin.toStringAsFixed(1)}% margin',
          ),
          BiKpiCard(
            label: 'Refunds',
            value: kInr.format(f.refunds),
            icon: Icons.replay_outlined,
            color: AppTheme.error,
            subtitle: '${f.refundRate.toStringAsFixed(1)}% of gross',
          ),
        ],
      ),
      const SizedBox(height: 16),
      BiSectionCard(
        title: 'Daily Revenue Trend',
        child: BiLineChart(
          values: f.dailyRevenue.map((d) => d.value).toList(),
        ),
      ),
      const SizedBox(height: 16),
      BiSectionCard(
        title: 'Revenue by Payment Method',
        child: BiDonutChart(data: f.revenueByPaymentMethod),
      ),
      const SizedBox(height: 16),
      BiSectionCard(
        title: 'Revenue by Category',
        child: BiDonutChart(data: f.revenueByCategory),
      ),
      const SizedBox(height: 16),
      BiSectionCard(
        title: 'Income Statement',
        child: Column(
          children: [
            _row('Gross Revenue', kInr.format(f.grossRevenue)),
            _row('Less: Refunds', '-${kInr.format(f.refunds)}',
                color: AppTheme.error),
            const Divider(),
            _row('Net Revenue', kInr.format(f.netRevenue), bold: true),
            _row('Less: COGS', '-${kInr.format(f.cogs)}',
                color: AppTheme.error),
            const Divider(),
            _row('Gross Profit', kInr.format(f.grossProfit),
                bold: true, color: AppTheme.success),
            const SizedBox(height: 8),
            _row('Delivery Fees Collected', kInr.format(f.deliveryFeeRevenue)),
            _row('Tips Collected', kInr.format(f.tips)),
            _row('Packaging Fees', kInr.format(f.packagingFees)),
            _row('Tax Collected', kInr.format(f.taxCollected)),
            _row('Wallet Usage', kInr.format(f.walletUsage)),
            _row('Discounts Given', '-${kInr.format(f.discountsGiven)}',
                color: AppTheme.warning),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Center(
        child: Text(
          'COGS uses real product cost where available, else a 68% estimate.',
          style: TextStyle(fontSize: 11, color: AppTheme.grey500),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _row(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.grey700,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppTheme.grey900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          const Text('Could not load data',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.grey800)),
          const SizedBox(height: 4),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
