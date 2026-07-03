import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/subscription_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../utils/app_theme.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoading = true);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser != null) {
      await subscriptionProvider.fetchSubscriptions(authProvider.currentUser!.id);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('My Daily Essentials', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : subscriptionProvider.subscriptions.isEmpty
          ? _buildEmptyState()
          : _buildSubscriptionList(subscriptionProvider.subscriptions),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to product selection for new subscription
        },
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add New Item'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 80, color: AppTheme.grey300),
            const SizedBox(height: 24),
            const Text(
              'No Subscriptions Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.grey800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Subscribe to milk, bread, or vegetables to get them delivered automatically every morning.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.grey500),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Navigate to catalog
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Browse Essentials'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionList(List<SubscriptionModel> subscriptions) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: subscriptions.length,
      itemBuilder: (context, index) {
        final sub = subscriptions[index];
        return _buildSubscriptionCard(sub);
      },
    );
  }

  Widget _buildSubscriptionCard(SubscriptionModel sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    sub.productImage,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 60,
                      height: 60,
                      color: AppTheme.grey100,
                      child: const Icon(Icons.shopping_basket, color: AppTheme.grey400),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${sub.quantity} x ${sub.unit}',
                        style: const TextStyle(color: AppTheme.grey600, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getFrequencyLabel(sub.frequency),
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${sub.price * sub.quantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Switch(
                      value: sub.status == SubscriptionStatus.active,
                      onChanged: (val) {
                        // Toggle subscription status
                      },
                      activeThumbColor: AppTheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: AppTheme.grey500),
                    const SizedBox(width: 6),
                    Text(
                      'Slot: ${sub.timeSlot}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    // Edit subscription
                  },
                  child: const Text('Edit Details'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getFrequencyLabel(SubscriptionFrequency freq) {
    switch (freq) {
      case SubscriptionFrequency.daily:
        return 'DAILY';
      case SubscriptionFrequency.alternateDays:
        return 'ALTERNATE DAYS';
      case SubscriptionFrequency.weekly:
        return 'WEEKLY';
      case SubscriptionFrequency.custom:
        return 'CUSTOM';
    }
  }
}
