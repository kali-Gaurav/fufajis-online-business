import 'package:flutter/material.dart';

class FinancialDashboardScreen extends StatefulWidget {
  const FinancialDashboardScreen({Key? key}) : super(key: key);

  @override
  State<FinancialDashboardScreen> createState() => _FinancialDashboardScreenState();
}

class _FinancialDashboardScreenState extends State<FinancialDashboardScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Dashboard'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Dashboard'), Tab(text: 'Cash Flow'), Tab(text: 'Profitability'), Tab(text: 'Config')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildCashFlowTab(),
          _buildProfitabilityTab(),
          _buildConfigTab(),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Executive Summary (This Month)', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('₹245.8L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Revenue', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('36.4%', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Net Margin', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('₹89.5L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Net Profit', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Key Financial Metrics', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildMetricCard('Cash Position', '₹28.5L', '↑5.2%', Colors.green),
          _buildMetricCard('Inventory Value', '₹125.3L', '↓2.1%', Colors.orange),
          _buildMetricCard('Receivables', '₹12.8L', '↑1.5%', Colors.blue),
          _buildMetricCard('Payables', '₹48.5L', '→0.0%', Colors.orange),
          _buildMetricCard('Working Capital', '₹97.3L', '↑3.8%', Colors.green),
          _buildMetricCard('Asset Turnover', '1.96x', '↑0.12x', Colors.blue),
        ],
      ),
    );
  }

  Widget _buildCashFlowTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cash Flow Summary (Q2 2026)', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('₹156.3L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Operating CF', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('₹8.2L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Investing CF', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('₹12.5L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Financing CF', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Monthly Cash Flow Trend', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildCashFlowCard('January 2026', '₹42.3L', '₹35.1L', '₹28.5L', Colors.green),
          _buildCashFlowCard('February 2026', '₹48.5L', '₹38.2L', '₹31.2L', Colors.green),
          _buildCashFlowCard('March 2026', '₹65.2L', '₹52.8L', '₹45.3L', Colors.green),
          _buildCashFlowCard('April 2026', '₹72.3L', '₹58.5L', '₹52.1L', Colors.green),
          _buildCashFlowCard('May 2026', '₹85.4L', '₹68.2L', '₹62.5L', Colors.green),
          _buildCashFlowCard('June 2026 (Forecast)', '₹78.6L', '₹65.3L', '₹58.3L', Colors.blue),
        ],
      ),
    );
  }

  Widget _buildProfitabilityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profitability Analysis (This Month)', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('₹156.3L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.red, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('COGS', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('₹63.5L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Operating Exp', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('₹12.4L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Tax Exp', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Margin Trends', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildMarginCard('Gross Margin', '36.2%', '↑1.2%', Colors.green),
          _buildMarginCard('Operating Margin', '22.8%', '↑0.8%', Colors.green),
          _buildMarginCard('Net Margin', '36.4%', '↑2.1%', Colors.green),
          const SizedBox(height: 16),
          Text('Category Breakdown', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildCategoryCard('Groceries', '₹98.5L', '42.1%', '38.2%', Colors.green),
          _buildCategoryCard('Vegetables', '₹65.3L', '27.9%', '25.6%', Colors.green),
          _buildCategoryCard('Dairy & Eggs', '₹48.2L', '20.6%', '18.9%', Colors.green),
          _buildCategoryCard('Ready Meals', '₹33.8L', '14.4%', '11.2%', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report Settings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Report Currency', 'INR (₹)', '💱'),
                  const Divider(),
                  _buildConfigRow('Fiscal Year', 'April - March', '📅'),
                  const Divider(),
                  _buildConfigRow('Reporting Period', 'Monthly', '📊'),
                  const Divider(),
                  _buildConfigRow('Auto Report Generation', 'Enabled', '🤖'),
                  const Divider(),
                  _buildConfigRow('Email Reports To', 'Owner@fufaji.com', '📧'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Data Integration', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('PostgreSQL Sync', 'Real-time', '✓'),
                  const Divider(),
                  _buildConfigRow('GL Integration', 'Automated', '✓'),
                  const Divider(),
                  _buildConfigRow('Inventory Tracking', 'Live sync', '✓'),
                  const Divider(),
                  _buildConfigRow('Payment Records', 'Linked', '✓'),
                  const Divider(),
                  _buildConfigRow('Tax Calculation', 'Auto-updated', '✓'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Export Options', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('PDF Reports', 'Monthly/Quarterly', '📄'),
                  const Divider(),
                  _buildConfigRow('Excel Export', 'All dashboards', '📊'),
                  const Divider(),
                  _buildConfigRow('Cloud Backup', 'Daily', '☁️'),
                  const Divider(),
                  _buildConfigRow('Audit Trail Export', 'Unlimited', '📋'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, String change, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(change, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildCashFlowCard(String month, String operating, String investing, String ending, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(month, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Operating: $operating'), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)), child: Text('Active', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)))]),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Investing: $investing'), Text('Financing: $ending', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))]),
          ],
        ),
      ),
    );
  }

  Widget _buildMarginCard(String metric, String percent, String change, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metric, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(change, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            Text(percent, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String category, String revenue, String percent, String margin, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(revenue), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)), child: Text('$margin margin', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)))]),
            const SizedBox(height: 4),
            Text('Market Share: $percent', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigRow(String label, String value, String icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Text(icon), const SizedBox(width: 12), Text(label)]), Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))]),
    );
  }
}
