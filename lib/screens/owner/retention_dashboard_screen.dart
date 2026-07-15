import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../providers/retention_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

class RetentionDashboardScreen extends StatefulWidget {
  const RetentionDashboardScreen({super.key});

  @override
  State<RetentionDashboardScreen> createState() => _RetentionDashboardScreenState();
}

class _RetentionDashboardScreenState extends State<RetentionDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RetentionProvider>().loadRetentionData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Customer Retention', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<RetentionProvider>().loadRetentionData();
            },
          ),
        ],
      ),
      body: Consumer<RetentionProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.atRiskCustomers.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load retention data',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(provider.error!, style: const TextStyle(color: AppTheme.grey600)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadRetentionData(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRecoveryKPIs(provider.recoveryStats),
                  const SizedBox(height: 24),

                  const Text(
                    'At-Risk Customers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'These customers haven\'t ordered in over 14 days. Send them a wallet top-up to reactivate them.',
                    style: TextStyle(color: AppTheme.grey600),
                  ),
                  const SizedBox(height: 16),

                  if (provider.atRiskCustomers.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: AppTheme.success,
                            ),
                            const SizedBox(height: 16),
                            Text('Great Retention!', style: Theme.of(context).textTheme.titleLarge),
                            const Text(
                              'No customers are currently at risk of churning.',
                              style: TextStyle(color: AppTheme.grey600),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...provider.atRiskCustomers.map((c) => _AtRiskCustomerCard(customer: c)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecoveryKPIs(Map<String, dynamic> stats) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.grey200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up, color: AppTheme.primary),
                SizedBox(width: 8),
                Text(
                  'Recovery Performance (Last 30 Days)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatBlock(
                  'Incentives Sent',
                  stats['totalIncentivized'].toString(),
                  AppTheme.grey800,
                ),
                _StatBlock('Recovered', stats['successfullyRecovered'].toString(), AppTheme.info),
                _StatBlock(
                  'Win-back %',
                  '${(stats['recoveryRate'] as num).toStringAsFixed(1)}%',
                  AppTheme.success,
                ),
                _StatBlock(
                  'Revenue',
                  '₹${(stats['recoveredRevenue'] as num).toStringAsFixed(0)}',
                  AppTheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatBlock(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: valueColor),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.grey600,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _AtRiskCustomerCard extends StatelessWidget {
  final Map<String, dynamic> customer;

  const _AtRiskCustomerCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    // Safely parse Firestore Timestamps
    final lastOrderDynamic = customer['lastOrderAt'];
    final createdAtDynamic = customer['createdAt'];

    DateTime? lastOrderDate;
    if (lastOrderDynamic != null && lastOrderDynamic is Timestamp) {
      lastOrderDate = lastOrderDynamic.toDate();
    }

    DateTime accountCreatedDate = DateTime.now();
    if (createdAtDynamic != null && createdAtDynamic is Timestamp) {
      accountCreatedDate = createdAtDynamic.toDate();
    }

    final daysSinceLastOrder = lastOrderDate != null
        ? DateTime.now().difference(lastOrderDate).inDays
        : accountCreatedDate.difference(DateTime.now()).inDays.abs();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.warning.withOpacity(0.2),
                  child: const Icon(Icons.person, color: AppTheme.warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (customer['name'] as String?) ?? 'Unknown Customer',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        (customer['phone'] as String?) ?? 'No Phone',
                        style: const TextStyle(color: AppTheme.grey600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$daysSinceLastOrder days ago',
                    style: const TextStyle(
                      color: AppTheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showReactivationDialog(context, customer),
                icon: const Icon(Icons.card_giftcard),
                label: const Text('Send Reactivation Offer (₹50)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReactivationDialog(BuildContext context, Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Send Reactivation Incentive',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will add ₹50 to ${(customer['name'] as String?) ?? 'this customer'}\'s wallet and send them a push notification.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = context.read<AuthProvider>();
              final adminId = auth.currentUser?.id ?? 'admin';
              final adminName = auth.currentUser?.name ?? 'Admin';

              try {
                await context.read<RetentionProvider>().sendIncentiveToCustomer(
                  userId: customer['id'] as String,
                  amount: 50.0,
                  message:
                      'We miss you! Here is ₹50 in your Fufaji Wallet to use on your next order.',
                  adminId: adminId,
                  adminName: adminName,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Offer sent successfully')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Failed to send offer: $e')));
                }
              }
            },
            child: const Text('Send ₹50'),
          ),
        ],
      ),
    );
  }
}
