import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/vendor_service.dart';
import '../../utils/app_theme.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({Key? key}) : super(key: key);

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  final _vendorService = VendorService();
  final _supabase = Supabase.instance;
  Vendor? _vendor;
  VendorAnalytics? _analytics;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final vendor = await _vendorService.getMyVendorProfile();
    VendorAnalytics? analytics;
    if (vendor != null) {
      analytics = await _vendorService.getVendorAnalytics(vendor.id);
    }

    if (mounted) {
      setState(() {
        _vendor = vendor;
        _analytics = analytics;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_vendor == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Vendor Dashboard'),
          backgroundColor: AppTheme.cream,
          foregroundColor: AppTheme.grey900,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_vendor!.status == 'pending') {
      return _buildPendingStatus();
    }

    if (_vendor!.status == 'rejected') {
      return _buildRejectedStatus();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Dashboard'),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(child: Text('Settings')),
              const PopupMenuItem(child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 24),
            _buildStatusCard(),
            const SizedBox(height: 24),
            _buildMetricsGrid(),
            const SizedBox(height: 24),
            _buildPerformanceSection(),
            const SizedBox(height: 24),
            _buildPayoutSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingStatus() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Application'),
        backgroundColor: AppTheme.cream,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.schedule, size: 80, color: Colors.amber[400]),
              const SizedBox(height: 24),
              const Text(
                'Application Under Review',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your vendor application is being reviewed. We\'ll notify you within 24 hours.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.grey600),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedStatus() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Application'),
        backgroundColor: AppTheme.cream,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.close_circle, size: 80, color: Colors.red[400]),
              const SizedBox(height: 24),
              const Text(
                'Application Rejected',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 12),
              Text(
                _vendor?.rejectionReason ?? 'Please contact support for more details',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.grey600),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Navigate to support
                },
                child: const Text('Contact Support'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_vendor?.logoUrl != null)
              CircleAvatar(
                radius: 32,
                backgroundImage: NetworkImage(_vendor!.logoUrl!),
              )
            else
              CircleAvatar(
                radius: 32,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                child: Icon(Icons.store, color: AppTheme.primary, size: 32),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${_vendor?.name}!',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _vendor?.businessName ?? 'Business',
                    style: const TextStyle(color: AppTheme.grey600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border.all(color: Colors.green[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.verified, color: Colors.green[600], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account Status: Active',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Verified on ${_vendor?.verificationDate != null ? _vendor!.verificationDate.toString().split(' ')[0] : 'N/A'}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildMetricTile(
          'Total Orders',
          _vendor?.totalOrders.toString() ?? '0',
          Icons.receipt_long,
          Colors.blue,
        ),
        _buildMetricTile(
          'Rating',
          _vendor?.rating.toStringAsFixed(1) ?? '0.0',
          Icons.star,
          Colors.amber,
        ),
        _buildMetricTile(
          'Commission Rate',
          '${_vendor?.commissionPercentage.toStringAsFixed(0)}%' ?? '0%',
          Icons.percent,
          Colors.purple,
        ),
        _buildMetricTile(
          'Pending Payout',
          '₹${_analytics?.pendingPayoutAmount.toStringAsFixed(0) ?? '0'}',
          Icons.wallet,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceSection() {
    if (_analytics == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Metrics',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPerformanceRow(
                  'On-Time Delivery',
                  '${_analytics!.onTimeDeliveryRate.toStringAsFixed(1)}%',
                  _analytics!.onTimeDeliveryRate / 100,
                ),
                const SizedBox(height: 16),
                _buildPerformanceRow(
                  'Return Rate',
                  '${_analytics!.returnRate.toStringAsFixed(1)}%',
                  1 - (_analytics!.returnRate / 100),
                ),
                const SizedBox(height: 16),
                _buildPerformanceRow(
                  'Customer Satisfaction',
                  '${(_analytics!.customerSatisfactionScore * 100).toStringAsFixed(0)}%',
                  _analytics!.customerSatisfactionScore,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Vendor Health Score'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getHealthScoreColor(_analytics!.vendorHealthScore).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_analytics!.vendorHealthScore}/100',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getHealthScoreColor(_analytics!.vendorHealthScore),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceRow(String label, String value, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.grey700)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 0.7 ? Colors.green : (progress >= 0.4 ? Colors.orange : Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPayoutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Payouts',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            TextButton(
              onPressed: () {
                // Navigate to payout history
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pending Amount', style: TextStyle(color: AppTheme.grey600)),
                    Text(
                      '₹${_analytics?.pendingPayoutAmount.toStringAsFixed(2) ?? '0.00'}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _analytics?.pendingPayoutAmount ?? 0 > 0 ? _requestPayout : null,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                    child: const Text('Request Payout'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _requestPayout() async {
    if (_vendor == null || (_analytics?.pendingPayoutAmount ?? 0) <= 0) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Payout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ₹${_analytics!.pendingPayoutAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text('Select payout method:'),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: const Text('Bank Transfer'),
              value: 'bank',
              groupValue: 'bank',
              onChanged: (_) {},
            ),
            RadioListTile<String>(
              title: const Text('UPI'),
              value: 'upi',
              groupValue: 'bank',
              onChanged: (_) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payout requested successfully')),
              );
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  Color _getHealthScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.amber;
    return Colors.red;
  }
}
