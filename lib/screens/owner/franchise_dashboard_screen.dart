import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/app_theme.dart';
import '../../providers/business_intelligence_provider.dart';
import '../../services/business_intelligence_service.dart';
import '../../widgets/owner/bi_widgets.dart';

/// Multi-branch comparison: revenue ranking, branch share, and a sortable
/// performance table (orders, AOV, rating, estimated profit).
class FranchiseDashboardScreen extends StatefulWidget {
  const FranchiseDashboardScreen({super.key});

  @override
  State<FranchiseDashboardScreen> createState() =>
      _FranchiseDashboardScreenState();
}

class _FranchiseDashboardScreenState extends State<FranchiseDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<BusinessIntelligenceProvider>();
      // Franchise view aggregates across all branches.
      p.setAllBranches(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Franchise Dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
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
                  ..._buildContent(p.franchise),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildContent(FranchiseReport fr) {
    if (fr.branches.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(
            child: Text('No branch data for this period',
                style: TextStyle(color: AppTheme.grey500)),
          ),
        ),
      ];
    }

    final revenueByBranch = {
      for (final b in fr.branches) b.branchName: b.revenue,
    };
    final top = fr.branches.first;

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
            label: 'Active Branches',
            value: '${fr.branches.length}',
            icon: Icons.store_mall_directory_outlined,
            color: AppTheme.primary,
          ),
          BiKpiCard(
            label: 'Total Revenue',
            value: kInr.format(fr.totalRevenue),
            icon: Icons.payments_outlined,
            color: AppTheme.success,
          ),
          BiKpiCard(
            label: 'Top Branch',
            value: top.branchName,
            icon: Icons.emoji_events_outlined,
            color: AppTheme.warning,
            subtitle: kInr.format(top.revenue),
          ),
          BiKpiCard(
            label: 'Est. Total Profit',
            value: kInr.format(
              fr.branches.fold(0.0, (s, b) => s + b.estimatedProfit),
            ),
            icon: Icons.savings_outlined,
            color: AppTheme.info,
          ),
        ],
      ),
      const SizedBox(height: 16),
      BiSectionCard(
        title: 'Revenue Share by Branch',
        child: BiDonutChart(data: revenueByBranch),
      ),
      const SizedBox(height: 16),
      BiSectionCard(
        title: 'Branch Performance Ranking',
        child: Column(
          children: [
            for (var i = 0; i < fr.branches.length; i++)
              _branchRow(i + 1, fr.branches[i]),
          ],
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _branchRow(int rank, BranchPerformance b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.grey50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey100),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank == 1
                  ? AppTheme.warning
                  : AppTheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: rank == 1 ? Colors.white : AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.branchName,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${b.orders} orders · AOV ${kInr.format(b.avgOrderValue)} · '
                  '★ ${b.avgRating.toStringAsFixed(1)}',
                  style:
                      const TextStyle(fontSize: 11, color: AppTheme.grey600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                kInr.format(b.revenue),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey900),
              ),
              Text(
                '~${kInr.format(b.estimatedProfit)} profit',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.success),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
