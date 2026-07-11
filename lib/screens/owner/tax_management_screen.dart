import 'package:flutter/material.dart';

class TaxManagementScreen extends StatefulWidget {
  const TaxManagementScreen({Key? key}) : super(key: key);

  @override
  State<TaxManagementScreen> createState() => _TaxManagementScreenState();
}

class _TaxManagementScreenState extends State<TaxManagementScreen> with TickerProviderStateMixin {
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
        title: const Text('Tax Management'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Dashboard'), Tab(text: 'GST'), Tab(text: 'TDS'), Tab(text: 'Config')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildGSTTab(),
          _buildTDSTab(),
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
                  Text('Tax Compliance Status', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('100%', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Compliance', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('₹12.4L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Tax Payable', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('0', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Violations', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Filing Status', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildStatusCard('GST Monthly Filing (June)', 'Submitted', Colors.green),
          _buildStatusCard('GST Quarterly (Q1)', 'Submitted', Colors.green),
          _buildStatusCard('TDS Deduction (June)', 'Submitted', Colors.green),
          _buildStatusCard('Annual Tax Return (2025-26)', 'Pending', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildGSTTab() {
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
                  Text('GST Summary (Q2 2026)', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('₹245.8L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Taxable Sales', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('₹25.6L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('GST Collected', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('₹8.3L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('GST Paid', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Net GST Payable: ₹17.3L', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.blue)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('GST Breakdown', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildGSTBreakdown('5% Products', '₹8.5L sales', '₹0.42L GST'),
          _buildGSTBreakdown('12% Products', '₹125.3L sales', '₹15.04L GST'),
          _buildGSTBreakdown('18% Products', '₹98.5L sales', '₹17.73L GST'),
          _buildGSTBreakdown('28% Products', '₹13.5L sales', '₹3.78L GST'),
        ],
      ),
    );
  }

  Widget _buildTDSTab() {
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
                  Text('TDS Summary (Q2 2026)', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('₹45.3L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('TDS Payments', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('₹4.8L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('TDS Deducted', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('10.6%', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Avg Rate', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('TDS Details', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildTDSCard('Section 194H (Freight)', '₹2.1L paid', '₹0.21L TDS (10%)'),
          _buildTDSCard('Section 194J (Professional Fees)', '₹5.6L paid', '₹0.56L TDS (10%)'),
          _buildTDSCard('Section 194O (Online Payments)', '₹37.6L paid', '₹3.76L TDS (10%)'),
          _buildTDSCard('Section 193 (Interest)', '₹0 paid', '₹0 TDS'),
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
          Text('Tax Configuration', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('GST Registration', 'Registered', '✓'),
                  const Divider(),
                  _buildConfigRow('GST Number', '18AABCT1234H1Z0', '📝'),
                  const Divider(),
                  _buildConfigRow('Tax Year', 'FY 2025-26', '📅'),
                  const Divider(),
                  _buildConfigRow('Filing Frequency', 'Monthly', '📊'),
                  const Divider(),
                  _buildConfigRow('Auto Filing', 'Enabled', '🤖'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Compliance Rules', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('GST Rate Validation', 'Auto-checked', '✓'),
                  const Divider(),
                  _buildConfigRow('IGST/SGST Calculation', 'Automatic', '✓'),
                  const Divider(),
                  _buildConfigRow('Input Credit Tracking', 'Enabled', '✓'),
                  const Divider(),
                  _buildConfigRow('TDS Deduction Rules', 'Section based', '✓'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String item, String status, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(item, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)),
              child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGSTBreakdown(String rate, String sales, String gst) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rate, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(sales), Text(gst, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))]),
          ],
        ),
      ),
    );
  }

  Widget _buildTDSCard(String section, String paid, String tds) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(paid, style: Theme.of(context).textTheme.bodySmall), Text(tds, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))]),
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
