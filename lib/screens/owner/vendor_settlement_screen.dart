import 'package:flutter/material.dart';

class VendorSettlementScreen extends StatefulWidget {
  const VendorSettlementScreen({Key? key}) : super(key: key);

  @override
  State<VendorSettlementScreen> createState() => _VendorSettlementScreenState();
}

class _VendorSettlementScreenState extends State<VendorSettlementScreen> with TickerProviderStateMixin {
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
        title: const Text('Vendor Settlement'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Payables'), Tab(text: 'Payments'), Tab(text: 'Aging'), Tab(text: 'Config')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPayablesTab(),
          _buildPaymentsTab(),
          _buildAgingTab(),
          _buildConfigTab(),
        ],
      ),
    );
  }

  Widget _buildPayablesTab() {
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
                  Text('Accounts Payable Summary', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('₹48.5L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.red, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Total AP', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('₹12.3L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Due Now', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('12', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Vendors', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Vendor Payables', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildPayableCard('Vendor #001 - ABC Wholesale', '₹8.5L', 'Overdue', Colors.red),
          _buildPayableCard('Vendor #002 - XYZ Suppliers', '₹12.3L', 'Due Today', Colors.orange),
          _buildPayableCard('Vendor #003 - Prime Foods', '₹15.2L', 'Due in 5 days', Colors.blue),
          _buildPayableCard('Vendor #004 - Quick Delivery', '₹5.8L', 'Due in 15 days', Colors.green),
          _buildPayableCard('Vendor #005 - Regional Distributors', '₹6.7L', 'Due in 20 days', Colors.green),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab() {
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
                  Text('Payment Status (This Month)', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('34', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Paid', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('₹125.3L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Total Paid', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('99.2%', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('On-time', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Recent Payments', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildPaymentCard('PAY-2026-00567', 'Vendor ABC', '₹8.5L', 'Paid', Colors.green),
          _buildPaymentCard('PAY-2026-00566', 'Vendor XYZ', '₹12.3L', 'Paid', Colors.green),
          _buildPaymentCard('PAY-2026-00565', 'Vendor Prime', '₹7.8L', 'Pending', Colors.orange),
          _buildPaymentCard('PAY-2026-00564', 'Vendor Quick', '₹5.6L', 'Paid', Colors.green),
        ],
      ),
    );
  }

  Widget _buildAgingTab() {
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
                  Text('AP Aging Report', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('33.5', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('DPO (Days)', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('↑2.1d', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('vs Last Month', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('3.2%', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Overdue %', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Aging Buckets', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildAgingBucket('Current (0-30 days)', '₹28.5L', '58%', Colors.green),
          _buildAgingBucket('31-60 days', '₹12.3L', '25%', Colors.orange),
          _buildAgingBucket('61-90 days', '₹5.2L', '11%', Colors.orange),
          _buildAgingBucket('90+ days (Overdue)', '₹2.5L', '6%', Colors.red),
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
          Text('Payment Terms', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Default Terms', 'Net 30', '📅'),
                  const Divider(),
                  _buildConfigRow('Early Payment Discount', '2% (10 days)', '💰'),
                  const Divider(),
                  _buildConfigRow('Late Payment Fee', '1.5% per month', '📈'),
                  const Divider(),
                  _buildConfigRow('Max Credit Limit', 'Vendor-specific', '🔐'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Vendor Management', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Active Vendors', '12 vendors', '📋'),
                  const Divider(),
                  _buildConfigRow('Payment Methods', 'Bank, Cheque, UPI', '💳'),
                  const Divider(),
                  _buildConfigRow('Auto-Pay Enabled', 'For 8 vendors', '🤖'),
                  const Divider(),
                  _buildConfigRow('Settlement Frequency', 'Monthly', '📊'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayableCard(String vendor, String amount, String status, Color color) {
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
                Text(vendor, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)),
                  child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            Text(amount, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(String id, String vendor, String amount, String status, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(id, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)), child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)))]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(vendor), Text(amount, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))]),
          ],
        ),
      ),
    );
  }

  Widget _buildAgingBucket(String bucket, String amount, String percent, Color color) {
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
                Text(bucket, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(amount, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)),
              child: Text(percent, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
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
