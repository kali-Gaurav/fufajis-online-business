import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/vendor_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import 'package:go_router/go_router.dart';

class VendorCommissionDashboardScreen extends StatefulWidget {
  const VendorCommissionDashboardScreen({Key? key}) : super(key: key);

  @override
  State<VendorCommissionDashboardScreen> createState() =>
      _VendorCommissionDashboardScreenState();
}

class _VendorCommissionDashboardScreenState
    extends State<VendorCommissionDashboardScreen> {
  final _vendorService = VendorService();
  VendorProfile? _vendor;
  Map<String, dynamic>? _commissionData;
  List<Map<String, dynamic>> _payoutHistory = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final vendorId = authProvider.currentUser?.id;

      if (vendorId == null) {
        setState(() => _error = 'Unable to load vendor information');
        return;
      }

      // Load vendor profile
      final vendor = await _vendorService.getVendorProfile(vendorId);

      // Simulate loading commission data (would come from backend in production)
      final commissionData = {
        'totalEarnings': 45230.50,
        'commissionPercentage': vendor?.commissionPercentage ?? 15.0,
        'netPayable': 38445.93,
        'platformCommission': 6784.57,
        'pendingAmount': 5230.50,
        'lastPayoutDate': DateTime.now().subtract(const Duration(days: 7)),
        'thisMonthEarnings': 12500.00,
      };

      // Simulate payout history
      final payoutHistory = [
        {
          'date': DateTime.now().subtract(const Duration(days: 7)),
          'amount': 8500.00,
          'status': 'completed',
          'method': 'bank',
        },
        {
          'date': DateTime.now().subtract(const Duration(days: 14)),
          'amount': 7230.50,
          'status': 'completed',
          'method': 'upi',
        },
        {
          'date': DateTime.now().subtract(const Duration(days: 21)),
          'amount': 9215.00,
          'status': 'completed',
          'method': 'bank',
        },
      ];

      if (mounted) {
        setState(() {
          _vendor = vendor;
          _commissionData = commissionData;
          _payoutHistory = payoutHistory;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commission Dashboard'),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEarningsSummaryCard(),
                      const SizedBox(height: 24),
                      _buildCommissionBreakdownCard(),
                      const SizedBox(height: 24),
                      _buildPayoutSection(),
                      const SizedBox(height: 24),
                      _buildPayoutHistorySection(),
                      const SizedBox(height: 24),
                      _buildSettingsCard(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEarningsSummaryCard() {
    final data = _commissionData ?? {};
    final totalEarnings = (data['totalEarnings'] as num?)?.toDouble() ?? 0.0;
    final netPayable = (data['netPayable'] as num?)?.toDouble() ?? 0.0;
    final pendingAmount = (data['pendingAmount'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withOpacity(0.9), AppTheme.primary.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Earnings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '₹${totalEarnings.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Net Payable',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${netPayable.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pending Amount',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${pendingAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionBreakdownCard() {
    final data = _commissionData ?? {};
    final commissionPercent = (data['commissionPercentage'] as num?)?.toDouble() ?? 0.0;
    final platformCommission = (data['platformCommission'] as num?)?.toDouble() ?? 0.0;
    final totalEarnings = (data['totalEarnings'] as num?)?.toDouble() ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Commission Breakdown',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildBreakdownRow(
              label: 'Your Commission Rate',
              value: '${commissionPercent.toStringAsFixed(1)}%',
              color: AppTheme.primary,
            ),
            const SizedBox(height: 12),
            _buildBreakdownRow(
              label: 'Platform Commission',
              value: '₹${platformCommission.toStringAsFixed(2)}',
              color: AppTheme.warning,
            ),
            const SizedBox(height: 12),
            _buildBreakdownRow(
              label: 'This Month Earnings',
              value: '₹${(data['thisMonthEarnings'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}',
              color: AppTheme.success,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.grey50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.grey200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600], size: 18),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Commission is calculated on delivered orders and deducted from your payable amount',
                      style: TextStyle(fontSize: 12, color: AppTheme.grey700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow({
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.grey700, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPayoutSection() {
    final data = _commissionData ?? {};
    final pendingAmount = (data['pendingAmount'] as num?)?.toDouble() ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Next Payout',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pending Payout',
                        style: TextStyle(color: AppTheme.grey600, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${pendingAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 120,
                    child: ElevatedButton(
                      onPressed: pendingAmount > 0 ? _handleRequestPayout : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                      child: const Text('Request Now'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.grey50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.amber[700], size: 18),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Payouts are processed every week if auto-payout is enabled',
                      style: TextStyle(fontSize: 12, color: AppTheme.grey700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payout History',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        if (_payoutHistory.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.grey200),
            ),
            child: const Center(
              child: Text(
                'No payouts yet',
                style: TextStyle(color: AppTheme.grey600),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _payoutHistory.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final payout = _payoutHistory[index];
              final date = payout['date'] as DateTime;
              final amount = (payout['amount'] as num).toDouble();
              final status = payout['status'] as String;
              final method = payout['method'] as String;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.grey200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: AppTheme.success,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormat('dd MMM yyyy').format(date)} • ${method.toUpperCase()}',
                            style: const TextStyle(
                              color: AppTheme.grey600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.success,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.settings, color: AppTheme.primary),
              title: const Text('Auto-Payout Settings'),
              subtitle: const Text('Manage automatic payout frequency'),
              trailing: const Icon(Icons.arrow_forward, color: AppTheme.grey600),
              onTap: () => context.push('/vendor/payout-settings'),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.receipt, color: AppTheme.primary),
              title: const Text('Download Reports'),
              subtitle: const Text('Get commission and payout reports'),
              trailing: const Icon(Icons.arrow_forward, color: AppTheme.grey600),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report download coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRequestPayout() async {
    final data = _commissionData ?? {};
    final pendingAmount = (data['pendingAmount'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Payout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Amount to be paid out:'),
            const SizedBox(height: 8),
            Text(
              '₹${pendingAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Processing may take 1-2 business days'),
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
                const SnackBar(
                  content: Text('Payout requested successfully'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
