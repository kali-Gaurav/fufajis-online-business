import 'package:flutter/material.dart';

class GLAccountingSystemScreen extends StatefulWidget {
  const GLAccountingSystemScreen({Key? key}) : super(key: key);

  @override
  State<GLAccountingSystemScreen> createState() => _GLAccountingSystemScreenState();
}

class _GLAccountingSystemScreenState extends State<GLAccountingSystemScreen>
    with TickerProviderStateMixin {
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
        title: const Text('GL & Accounting System'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Journal'),
            Tab(text: 'Ledger'),
            Tab(text: 'Config'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildJournalTab(),
          _buildLedgerTab(),
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
                  Text('GL Summary (This Month)', style: Theme.of(context).textTheme.titleLarge),
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
                          Text('₹156.3L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.red, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Expenses', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('₹89.5L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Profit', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('GL Accounts', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildAccountCard('1000 - Cash & Bank', '₹12.3L', 'Asset'),
          _buildAccountCard('1100 - Accounts Receivable', '₹8.5L', 'Asset'),
          _buildAccountCard('1200 - Inventory', '₹45.2L', 'Asset'),
          _buildAccountCard('2000 - Accounts Payable', '₹18.7L', 'Liability'),
          _buildAccountCard('3000 - Revenue', '₹245.8L', 'Income'),
          _buildAccountCard('4000 - COGS', '₹125.4L', 'Expense'),
          _buildAccountCard('4100 - Staff Salary', '₹18.5L', 'Expense'),
          _buildAccountCard('4200 - Utilities', '₹5.2L', 'Expense'),
        ],
      ),
    );
  }

  Widget _buildJournalTab() {
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
                  Text('Journal Entries (Today)', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('234', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Entries', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('₹485.2L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Total', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('✓', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Balanced', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Recent Entries', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildJournalEntry('DR: Cash', '₹45,234', 'CR: Revenue', '₹45,234', '2:45 PM'),
          _buildJournalEntry('DR: COGS', '₹23,450', 'CR: Inventory', '₹23,450', '2:38 PM'),
          _buildJournalEntry('DR: Expense', '₹8,900', 'CR: Cash', '₹8,900', '2:32 PM'),
          _buildJournalEntry('DR: AP', '₹12,567', 'CR: Cash', '₹12,567', '1:15 PM'),
        ],
      ),
    );
  }

  Widget _buildLedgerTab() {
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
                  Text('Reconciliation Status', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('98.5%', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Automated', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('2 hrs', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Close Time', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('0', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Errors', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Account Balances', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildLedgerCard('Cash & Bank', '₹12.3L', 'Debit', Colors.blue),
          _buildLedgerCard('Inventory', '₹45.2L', 'Debit', Colors.blue),
          _buildLedgerCard('Accounts Payable', '₹18.7L', 'Credit', Colors.red),
          _buildLedgerCard('Revenue', '₹245.8L', 'Credit', Colors.red),
          _buildLedgerCard('COGS', '₹125.4L', 'Debit', Colors.blue),
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
          Text('Chart of Accounts', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Total Accounts', '45 accounts', '📊'),
                  const Divider(),
                  _buildConfigRow('Assets', '12 accounts', '💰'),
                  const Divider(),
                  _buildConfigRow('Liabilities', '8 accounts', '📋'),
                  const Divider(),
                  _buildConfigRow('Income', '6 accounts', '📈'),
                  const Divider(),
                  _buildConfigRow('Expenses', '19 accounts', '📉'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Accounting Rules', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Double-Entry', 'Enforced', '✓'),
                  const Divider(),
                  _buildConfigRow('Reconciliation', 'Auto 95%', '🔄'),
                  const Divider(),
                  _buildConfigRow('Trial Balance', 'Always balanced', '⚖️'),
                  const Divider(),
                  _buildConfigRow('Audit Trail', '100% logged', '📋'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(String name, String balance, String type) {
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
                Text(name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(type, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            Text(balance, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalEntry(String debit, String drAmount, String credit, String crAmount, String time) {
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
                Text(debit, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                Text(drAmount, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(credit, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                Text(crAmount, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(time, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerCard(String account, String balance, String side, Color color) {
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
                Text(account, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)),
                  child: Text(side, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            Text(balance, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigRow(String label, String value, String icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [Text(icon), const SizedBox(width: 12), Text(label)]),
          Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
