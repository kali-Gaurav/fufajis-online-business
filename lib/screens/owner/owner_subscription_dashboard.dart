import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/subscription_service.dart';
import '../../utils/app_theme.dart';

class OwnerSubscriptionDashboard extends StatefulWidget {
  const OwnerSubscriptionDashboard({Key? key}) : super(key: key);

  @override
  State<OwnerSubscriptionDashboard> createState() =>
      _OwnerSubscriptionDashboardState();
}

class _OwnerSubscriptionDashboardState extends State<OwnerSubscriptionDashboard> {
  final _subscriptionService = SubscriptionService();
  final _supabase = Supabase.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Analytics'),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricsGrid(),
            const SizedBox(height: 24),
            _buildChurnRiskSection(),
            const SizedBox(height: 24),
            _buildSubscriptionTrendsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return FutureBuilder<List<Subscription>>(
      future: _loadAllSubscriptions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final subscriptions = snapshot.data ?? [];
        final activeCount = subscriptions.where((s) => s.status == 'active').length;
        final pausedCount = subscriptions.where((s) => s.status == 'paused').length;
        final totalRevenue = subscriptions.fold<double>(0, (sum, s) => sum + s.totalAmount);
        final avgValue = subscriptions.isEmpty ? 0.0 : totalRevenue / subscriptions.length;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildMetricCard(
              'Total Subscriptions',
              subscriptions.length.toString(),
              Colors.blue,
              Icons.calendar_today,
            ),
            _buildMetricCard(
              'Active',
              activeCount.toString(),
              Colors.green,
              Icons.check_circle,
            ),
            _buildMetricCard(
              'Paused',
              pausedCount.toString(),
              Colors.orange,
              Icons.pause_circle,
            ),
            _buildMetricCard(
              'Total Revenue',
              '₹${totalRevenue.toStringAsFixed(0)}',
              Colors.purple,
              Icons.trending_up,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: AppTheme.grey900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChurnRiskSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'At-Risk Subscriptions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Subscription>>(
          future: _subscriptionService.getHighRiskSubscriptions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final atRiskSubs = snapshot.data ?? [];
            if (atRiskSubs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[600], size: 32),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'No at-risk subscriptions detected',
                        style: TextStyle(color: AppTheme.grey600),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: atRiskSubs.take(10).map((sub) {
                return _buildChurnRiskCard(sub);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildChurnRiskCard(Subscription sub) {
    final riskPercentage = (sub.churnRisk * 100).toStringAsFixed(0);
    final riskColor = _getRiskColor(sub.churnRisk);

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
                        'Subscription #${sub.id.substring(0, 8)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customer: ${sub.customerId.substring(0, 8)}',
                        style: const TextStyle(color: AppTheme.grey600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$riskPercentage% Risk',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: riskColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: sub.churnRisk,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(riskColor),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ₹${sub.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.grey600),
                ),
                ElevatedButton(
                  onPressed: () => _showRetentionOffer(sub),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Send Offer', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRetentionOffer(Subscription sub) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Retention Offer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select offer type:'),
            const SizedBox(height: 16),
            _buildOfferButton('Discount', Icons.local_offer, () {
              Navigator.pop(context);
              _createOffer(sub, 'discount');
            }),
            const SizedBox(height: 8),
            _buildOfferButton('Free Delivery', Icons.local_shipping, () {
              Navigator.pop(context);
              _createOffer(sub, 'free_delivery');
            }),
            const SizedBox(height: 8),
            _buildOfferButton('Extended Pause', Icons.pause_circle, () {
              Navigator.pop(context);
              _createOffer(sub, 'extended_pause');
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.grey200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      ),
    );
  }

  Future<void> _createOffer(Subscription sub, String offerType) async {
    try {
      await _subscriptionService.createRetentionOffer(
        subscriptionId: sub.id,
        offerType: offerType,
        discountPercentage: offerType == 'discount' ? 10.0 : null,
        description: 'Retention offer to prevent churn',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer created and sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildSubscriptionTrendsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Subscription Trends',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTrendRow('New Subscriptions (30d)', '12', Colors.green),
                const SizedBox(height: 12),
                _buildTrendRow('Cancelled (30d)', '3', Colors.red),
                const SizedBox(height: 12),
                _buildTrendRow('Paused (30d)', '5', Colors.orange),
                const SizedBox(height: 12),
                _buildTrendRow('Avg. Customer Value', '₹2,450', Colors.blue),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.grey600)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<List<Subscription>> _loadAllSubscriptions() async {
    // This would need to be implemented in the service to fetch all subscriptions for the shop
    return [];
  }

  Color _getRiskColor(double risk) {
    if (risk > 0.8) return Colors.red;
    if (risk > 0.6) return Colors.orange;
    if (risk > 0.4) return Colors.amber;
    return Colors.green;
  }
}
