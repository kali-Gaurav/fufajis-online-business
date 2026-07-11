import 'package:flutter/material.dart';

class ComplianceDashboardScreen extends StatefulWidget {
  const ComplianceDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ComplianceDashboardScreen> createState() => _ComplianceDashboardScreenState();
}

class _ComplianceDashboardScreenState extends State<ComplianceDashboardScreen> with TickerProviderStateMixin {
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
        title: const Text('Compliance Dashboard'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Audit'), Tab(text: 'Violations'), Tab(text: 'Certifications'), Tab(text: 'Config')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAuditTab(),
          _buildViolationsTab(),
          _buildCertificationsTab(),
          _buildConfigTab(),
        ],
      ),
    );
  }

  Widget _buildAuditTab() {
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
                  Text('Audit Readiness Score', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('94.2%', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Readiness', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('156', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Requirements', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('9', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Open Items', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Compliance Areas', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildComplianceCard('GST Compliance', '100%', '12 requirements', Colors.green),
          _buildComplianceCard('TDS Compliance', '98%', '8 requirements', Colors.green),
          _buildComplianceCard('Labor Law Compliance', '92%', '22 requirements', Colors.orange),
          _buildComplianceCard('Food Safety', '96%', '18 requirements', Colors.green),
          _buildComplianceCard('Data Protection', '89%', '15 requirements', Colors.orange),
          _buildComplianceCard('Environmental', '95%', '12 requirements', Colors.green),
          _buildComplianceCard('Financial Reporting', '97%', '24 requirements', Colors.green),
          _buildComplianceCard('Retail Operations', '91%', '45 requirements', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildViolationsTab() {
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
                  Text('Violations Summary', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('9', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Open Violations', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('156', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Resolved (YTD)', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('28d avg', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Resolution Time', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Active Violations', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildViolationCard('Incomplete TDS filing Q1', 'High', 'Due: 15-Jul-2026', Colors.red),
          _buildViolationCard('2 staff members missing medical cert', 'Medium', 'Due: 25-Jul-2026', Colors.orange),
          _buildViolationCard('CCTV recording retention', 'Low', 'Due: 10-Aug-2026', Colors.orange),
          _buildViolationCard('Waste disposal protocol update', 'Medium', 'Due: 20-Jul-2026', Colors.orange),
          _buildViolationCard('Food storage temp log gap (Jun 8-10)', 'High', 'Document: Pending', Colors.red),
          _buildViolationCard('3 cash reconciliation discrepancies', 'Low', 'Under review', Colors.orange),
          _buildViolationCard('Monthly fire safety drill not conducted', 'Medium', 'Due: 18-Jul-2026', Colors.orange),
          _buildViolationCard('Staff overtime limits exceeded', 'Low', 'Under monitoring', Colors.orange),
          _buildViolationCard('Shelf safety inspection pending', 'Low', 'Scheduled: 22-Jul', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildCertificationsTab() {
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
                  Text('Certifications & Licenses', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('12', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Active', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('2', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Expiring', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('0', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Expired', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('License & Certification Status', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildCertCard('Shop License', 'Active', 'Expires: 15-Mar-2027', Colors.green),
          _buildCertCard('GST Registration', 'Active', 'Expires: 31-Dec-2027', Colors.green),
          _buildCertCard('FSSAI Food License', 'Active', 'Expires: 22-Aug-2026', Colors.orange),
          _buildCertCard('Fire Safety Certificate', 'Active', 'Expires: 18-Sep-2026', Colors.orange),
          _buildCertCard('Building Safety Cert', 'Active', 'Expires: 12-Jan-2027', Colors.green),
          _buildCertCard('Trade License', 'Active', 'Expires: 30-Apr-2027', Colors.green),
          _buildCertCard('ISO Certification', 'Active', 'Expires: 25-Nov-2026', Colors.green),
          _buildCertCard('Employee Insurance', 'Active', 'Expires: 31-Mar-2027', Colors.green),
          _buildCertCard('PAN Registration', 'Active', 'Permanent', Colors.green),
          _buildCertCard('Bank Compliance', 'Active', 'Annual Review: 30-Jun', Colors.green),
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
          Text('Compliance Monitoring', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Auto Audit Alerts', 'Enabled', '🔔'),
                  const Divider(),
                  _buildConfigRow('Violation Tracking', 'Real-time', '📊'),
                  const Divider(),
                  _buildConfigRow('Audit Trail Retention', '7 years', '📋'),
                  const Divider(),
                  _buildConfigRow('Document Management', 'Automated', '📁'),
                  const Divider(),
                  _buildConfigRow('Notification Frequency', 'Weekly digest', '📧'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Regulatory Requirements', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Primary Regulator', 'GST + FSSAI + Local', '🏛️'),
                  const Divider(),
                  _buildConfigRow('Audit Frequency', 'Quarterly Internal', '📅'),
                  const Divider(),
                  _buildConfigRow('Report Generation', 'Auto on-demand', '🤖'),
                  const Divider(),
                  _buildConfigRow('Escalation Policy', '5-tier hierarchy', '⚠️'),
                  const Divider(),
                  _buildConfigRow('Certification Support', 'ISO + FSSAI', '✓'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceCard(String area, String score, String requirements, Color color) {
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
                Text(area, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(requirements, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)),
              child: Text(score, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViolationCard(String violation, String severity, String status, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(violation, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)),
                  child: Text(severity, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(status, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildCertCard(String cert, String status, String expiry, Color color) {
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
                Text(cert, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(expiry, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
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

  Widget _buildConfigRow(String label, String value, String icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Text(icon), const SizedBox(width: 12), Text(label)]), Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))]),
    );
  }
}
