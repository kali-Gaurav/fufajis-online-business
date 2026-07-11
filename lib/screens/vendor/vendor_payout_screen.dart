import 'package:flutter/material.dart';
import '../../services/vendor_service.dart';
import '../../utils/app_theme.dart';

class VendorPayoutScreen extends StatefulWidget {
  final String vendorId;

  const VendorPayoutScreen({Key? key, required this.vendorId}) : super(key: key);

  @override
  State<VendorPayoutScreen> createState() => _VendorPayoutScreenState();
}

class _VendorPayoutScreenState extends State<VendorPayoutScreen> {
  final _vendorService = VendorService();
  List<VendorPayout> _payouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayouts();
  }

  Future<void> _loadPayouts() async {
    setState(() => _isLoading = true);
    final payouts = await _vendorService.getVendorPayouts(widget.vendorId);
    if (mounted) {
      setState(() {
        _payouts = payouts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout History'),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _payouts.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 24),
                      _buildPayoutsList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            const Text(
              'No Payouts Yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your payouts will appear here once you earn commissions',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.grey600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalPaid =
        _payouts.where((p) => p.status == 'completed').fold<double>(0, (sum, p) => sum + p.totalAmount);
    final totalPending =
        _payouts.where((p) => p.status == 'pending').fold<double>(0, (sum, p) => sum + p.totalAmount);
    final totalProcessing =
        _payouts.where((p) => p.status == 'processing').fold<double>(0, (sum, p) => sum + p.totalAmount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payout Summary',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Paid', '₹${totalPaid.toStringAsFixed(2)}'.toUpperCase()),
              _buildSummaryItem('Pending', '₹${totalPending.toStringAsFixed(2)}'),
              _buildSummaryItem('Processing', '₹${totalProcessing.toStringAsFixed(2)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Payouts',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _payouts.length,
          itemBuilder: (_, index) => _buildPayoutCard(_payouts[index]),
        ),
      ],
    );
  }

  Widget _buildPayoutCard(VendorPayout payout) {
    final statusColor = _getStatusColor(payout.status);
    final statusLabel = _getStatusLabel(payout.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payout #${payout.id.substring(0, 8)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${payout.commissionCount} commission(s)',
                        style: const TextStyle(color: AppTheme.grey600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Amount',
                  style: const TextStyle(color: AppTheme.grey600, fontSize: 13),
                ),
                Text(
                  '₹${payout.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getDateLabel(payout.status),
                  style: const TextStyle(color: AppTheme.grey600, fontSize: 12),
                ),
                Text(
                  _formatDate(payout.status == 'completed'
                      ? payout.processedAt
                      : (payout.status == 'failed' ? payout.failedAt : payout.requestedAt)),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            if (payout.failureReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[600], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          payout.failureReason!,
                          style: TextStyle(fontSize: 12, color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (payout.razorpayPayoutId != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Razorpay ID: ${payout.razorpayPayoutId}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.grey500, fontFamily: 'monospace'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'processing':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'refunded':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'PAID';
      case 'processing':
        return 'PROCESSING';
      case 'pending':
        return 'PENDING';
      case 'failed':
        return 'FAILED';
      case 'refunded':
        return 'REFUNDED';
      default:
        return status.toUpperCase();
    }
  }

  String _getDateLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Paid on';
      case 'failed':
        return 'Failed on';
      default:
        return 'Requested on';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }
}
