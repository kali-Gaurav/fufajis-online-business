import 'package:flutter/material.dart';
import '../../services/supplier_service.dart';

class SupplierPerformanceScreen extends StatefulWidget {
  const SupplierPerformanceScreen({Key? key}) : super(key: key);

  @override
  State<SupplierPerformanceScreen> createState() =>
      _SupplierPerformanceScreenState();
}

class _SupplierPerformanceScreenState extends State<SupplierPerformanceScreen> {
  final _supplierService = SupplierService();
  late SupplierProfile? _currentSupplier;
  late SupplierMetrics? _currentMetrics;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final supplier = await _supplierService.getMySupplierProfile();
    final metrics = supplier != null ? await _supplierService.getSupplierMetrics(supplier.id) : null;
    setState(() {
      _currentSupplier = supplier;
      _currentMetrics = metrics;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentSupplier == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() => _loadData()),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final supplier = _currentSupplier!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Overall Rating Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Overall Rating',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        supplier.rating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          Row(
                            children: List.generate(
                              5,
                              (index) => Icon(
                                index < supplier.rating.toInt()
                                    ? Icons.star
                                    : index < supplier.rating
                                        ? Icons.star_half
                                        : Icons.star_outline,
                                color: Colors.amber,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${supplier.totalOrders} total orders',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Performance Metrics
          Text(
            'Performance Metrics',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildMetricCard(
            'On-Time Delivery Rate',
            '${supplier.onTimeDeliveryRate.toStringAsFixed(1)}%',
            supplier.onTimeDeliveryRate,
            Colors.teal,
          ),
          const SizedBox(height: 8),
          _buildMetricCard(
            'Quality Score',
            '${supplier.qualityScore.toStringAsFixed(1)}/100',
            supplier.qualityScore / 100,
            Colors.blue,
          ),
          const SizedBox(height: 8),
          _buildMetricCard(
            'Response Rate',
            '${supplier.responseRate.toStringAsFixed(1)}%',
            supplier.responseRate,
            Colors.purple,
          ),
          const SizedBox(height: 16),

          // Order Statistics
          Text(
            'Order Statistics',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatTile(
                'Total Orders',
                supplier.totalOrders.toString(),
                Icons.shopping_bag,
                Colors.blue,
              ),
              _buildStatTile(
                'Completed',
                supplier.completedOrders.toString(),
                Icons.check_circle,
                Colors.green,
              ),
              _buildStatTile(
                'Completion Rate',
                supplier.totalOrders > 0
                    ? '${((supplier.completedOrders / supplier.totalOrders) * 100).toStringAsFixed(1)}%'
                    : 'N/A',
                Icons.percent,
                Colors.orange,
              ),
              _buildStatTile(
                'Total Revenue',
                '₹${supplier.totalRevenue.toStringAsFixed(0)}',
                Icons.attach_money,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Monthly Metrics
          if (_currentMetrics != null) ...[
            Text(
              'Current Month Metrics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildMetricRow(
                      'Month',
                      _currentMetrics!.metricMonth.toString().split(' ')[0],
                    ),
                    const SizedBox(height: 12),
                    _buildMetricRow(
                      'Orders',
                      _currentMetrics!.totalOrders.toString(),
                    ),
                    const SizedBox(height: 12),
                    _buildMetricRow(
                      'Completed',
                      _currentMetrics!.completedOrders.toString(),
                    ),
                    const SizedBox(height: 12),
                    _buildMetricRow(
                      'On-Time Orders',
                      _currentMetrics!.onTimeOrders.toString(),
                    ),
                    const SizedBox(height: 12),
                    _buildMetricRow(
                      'Late Orders',
                      _currentMetrics!.lateOrders.toString(),
                    ),
                    const SizedBox(height: 12),
                    _buildMetricRow(
                      'Cancelled Orders',
                      _currentMetrics!.cancelledOrders.toString(),
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1),
                    const SizedBox(height: 12),
                    _buildMetricRow(
                      'Quality Score',
                      _currentMetrics!.qualityScore.toStringAsFixed(1),
                    ),
                    const SizedBox(height: 12),
                    _buildMetricRow(
                      'On-Time Rate',
                      '${_currentMetrics!.onTimeRate.toStringAsFixed(1)}%',
                    ),
                    const SizedBox(height: 12),
                    _buildMetricRow(
                      'Total Amount',
                      '₹${_currentMetrics!.totalAmount.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 12),
                    _buildMetricRow(
                      'Total Paid',
                      '₹${_currentMetrics!.totalPaid.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    double percentage,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage.clamp(0, 1).toDouble(),
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
