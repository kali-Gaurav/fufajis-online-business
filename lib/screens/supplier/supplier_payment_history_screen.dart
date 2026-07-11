import 'package:flutter/material.dart';
import '../../services/supplier_service.dart';

class SupplierPaymentHistoryScreen extends StatefulWidget {
  const SupplierPaymentHistoryScreen({Key? key}) : super(key: key);

  @override
  State<SupplierPaymentHistoryScreen> createState() =>
      _SupplierPaymentHistoryScreenState();
}

class _SupplierPaymentHistoryScreenState
    extends State<SupplierPaymentHistoryScreen> {
  final _supplierService = SupplierService();
  late SupplierProfile? _currentSupplier;

  @override
  void initState() {
    super.initState();
    _loadCurrentSupplier();
  }

  Future<void> _loadCurrentSupplier() async {
    final supplier = await _supplierService.getMySupplierProfile();
    setState(() => _currentSupplier = supplier);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentSupplier == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return StreamBuilder<List<SupplierPayment>>(
      stream: _supplierService.watchPendingPayments(_currentSupplier!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final pendingPayments = snapshot.data ?? [];

        return FutureBuilder<List<SupplierPayment>>(
          future: _supplierService.getPaymentHistory(_currentSupplier!.id),
          builder: (context, historySnapshot) {
            if (historySnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allPayments = historySnapshot.data ?? [];
            final succeededPayments = allPayments.where((p) => p.status == 'success').toList();
            final totalEarned = succeededPayments.fold<double>(
              0,
              (sum, payment) => sum + payment.amount,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Summary Card
                  Card(
                    color: Colors.green,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Earned',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹${totalEarned.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'From ${succeededPayments.length} successful payments',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pending Payments
                  if (pendingPayments.isNotEmpty) ...[
                    Text(
                      'Pending Payments (${pendingPayments.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pendingPayments.length,
                      itemBuilder: (_, index) => _buildPaymentCard(
                        pendingPayments[index],
                        isPending: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Payment History
                  Text(
                    'Payment History',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (allPayments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No payments yet',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: allPayments.length,
                      itemBuilder: (_, index) => _buildPaymentCard(allPayments[index]),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentCard(SupplierPayment payment, {bool isPending = false}) {
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${payment.amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (payment.description != null)
                      Text(
                        payment.description!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
                _buildStatusBadge(payment.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Date: ${payment.createdAt.toString().split(' ')[0]}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            if (payment.razorpayPaymentId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Razorpay ID: ${payment.razorpayPaymentId}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (payment.failureReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Reason: ${payment.failureReason}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final statusConfig = {
      'pending': (Colors.orange, '⏳'),
      'processing': (Colors.blue, '🔄'),
      'success': (Colors.green, '✅'),
      'failed': (Colors.red, '❌'),
    };

    final (color, icon) = statusConfig[status] ?? (Colors.grey, '❓');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$icon ${status.toUpperCase()}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
