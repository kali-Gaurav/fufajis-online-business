import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../utils/app_theme.dart';
import '../../providers/business_intelligence_provider.dart';
import '../../widgets/owner/bi_widgets.dart';

/// Business Intelligence hub — single entry point that previews headline
/// numbers and routes into the Financial, Business, and Franchise dashboards.
class BiAnalyticsHubScreen extends StatefulWidget {
  const BiAnalyticsHubScreen({super.key});

  @override
  State<BiAnalyticsHubScreen> createState() => _BiAnalyticsHubScreenState();
}

class _BiAnalyticsHubScreenState extends State<BiAnalyticsHubScreen> {
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
      appBar: AppBar(title: const Text('Business Intelligence')),
      body: Consumer<BusinessIntelligenceProvider>(
        builder: (context, p, _) {
          return RefreshIndicator(
            onRefresh: p.refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                BiRangeSelector(selected: p.range, onSelected: (r) => p.setRange(r)),
                const SizedBox(height: 16),
                if (p.isLoading && p.data == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent)),
                  )
                else ...[
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
                        value: kInr.format(p.financial.netRevenue),
                        icon: Icons.account_balance_wallet_outlined,
                        color: AppTheme.primary,
                        growth: p.financial.revenueGrowth,
                      ),
                      BiKpiCard(
                        label: 'Gross Profit',
                        value: kInr.format(p.financial.grossProfit),
                        icon: Icons.savings_outlined,
                        color: AppTheme.success,
                        subtitle: '${p.financial.profitMargin.toStringAsFixed(1)}% margin',
                      ),
                      BiKpiCard(
                        label: 'Orders',
                        value: '${p.business.totalOrders}',
                        icon: Icons.receipt_long_outlined,
                        color: AppTheme.info,
                        growth: p.business.orderGrowth,
                      ),
                      BiKpiCard(
                        label: 'Retention',
                        value: '${p.business.retentionRate.toStringAsFixed(1)}%',
                        icon: Icons.favorite_outline,
                        color: AppTheme.warning,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                _navCard(
                  context,
                  title: 'Financial Dashboard',
                  subtitle: 'Revenue, refunds, COGS margin, payment & category mix',
                  icon: Icons.account_balance_outlined,
                  color: AppTheme.primary,
                  route: '/owner/bi/financial',
                ),
                _navCard(
                  context,
                  title: 'Business Dashboard',
                  subtitle: 'Orders funnel, retention, churn, AOV, CLV distribution',
                  icon: Icons.insights_outlined,
                  color: AppTheme.info,
                  route: '/owner/bi/business',
                ),
                _navCard(
                  context,
                  title: 'Franchise Dashboard',
                  subtitle: 'Branch-by-branch comparison & profitability ranking',
                  icon: Icons.store_mall_directory_outlined,
                  color: AppTheme.success,
                  route: '/owner/bi/franchise',
                ),
                _navCard(
                  context,
                  title: 'Backend Analytics',
                  subtitle:
                      'Sales, vendor & delivery analytics from the Postgres reporting database',
                  icon: Icons.storage_outlined,
                  color: AppTheme.info,
                  route: '/owner/analytics/postgres',
                ),
                _navCard(
                  context,
                  title: 'AI Business Intelligence',
                  subtitle:
                      '7d/30d sales forecasts, dynamic pricing suggestions, and marketing prompts',
                  icon: Icons.psychology_outlined,
                  color: Colors.purple,
                  route: '/owner/bi/ai-dashboard',
                ),
                _navCard(
                  context,
                  title: 'AI Decision Center',
                  subtitle:
                      'Root cause analysis, business health AI scoring, and auto-reorder actions',
                  icon: Icons.gavel_outlined,
                  color: AppTheme.ownerAccent,
                  route: '/owner/bi/decision-center',
                ),
                _navCard(
                  context,
                  title: 'Postcode Delivery Heatmap',
                  subtitle: 'Interactive delivery density maps and zip code satisfaction scores',
                  icon: Icons.map_outlined,
                  color: AppTheme.warning,
                  route: '/owner/analytics/postcode',
                ),

                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: p.data == null ? null : () => p.exportPdf(),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Export full PDF report'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _navCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey900),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.grey400),
        onTap: () => context.push(route),
      ),
    );
  }
}
