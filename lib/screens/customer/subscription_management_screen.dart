import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/subscription_model.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends State<SubscriptionManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSubscriptions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoading = true);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser != null) {
      await subscriptionProvider.fetchSubscriptions(authProvider.currentUser!.id);
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Subscriptions', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.grey600,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Paused'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadSubscriptions,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildActiveSubscriptions(subscriptionProvider.subscriptions),
                  _buildPausedSubscriptions(subscriptionProvider.subscriptions),
                  _buildCancelledSubscriptions(subscriptionProvider.subscriptions),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/customer/subscription-setup'),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('New Subscription'),
      ),
    );
  }

  Widget _buildActiveSubscriptions(List<SubscriptionModel> subscriptions) {
    final active = subscriptions
        .where((s) => s.status == SubscriptionStatus.active)
        .toList();

    if (active.isEmpty) {
      return _buildEmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'No Active Subscriptions',
        subtitle: 'Subscribe to get regular deliveries',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: active.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildSubscriptionCard(active[index], isActive: true),
    );
  }

  Widget _buildPausedSubscriptions(List<SubscriptionModel> subscriptions) {
    final paused = subscriptions
        .where((s) => s.status == SubscriptionStatus.paused)
        .toList();

    if (paused.isEmpty) {
      return _buildEmptyState(
        icon: Icons.pause_circle_outlined,
        title: 'No Paused Subscriptions',
        subtitle: 'All your subscriptions are active',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: paused.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildSubscriptionCard(paused[index], isPaused: true),
    );
  }

  Widget _buildCancelledSubscriptions(List<SubscriptionModel> subscriptions) {
    final cancelled = subscriptions
        .where((s) => s.status == SubscriptionStatus.cancelled)
        .toList();

    if (cancelled.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outlined,
        title: 'No Cancelled Subscriptions',
        subtitle: 'Keep your subscriptions active',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: cancelled.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildSubscriptionCard(cancelled[index], isCancelled: true),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: AppTheme.grey300),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.grey800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(
    SubscriptionModel subscription, {
    bool isActive = false,
    bool isPaused = false,
    bool isCancelled = false,
  }) {
    final nextDelivery = subscription.nextDeliveryDate ?? DateTime.now().add(const Duration(days: 7));
    final daysUntilDelivery = nextDelivery.difference(DateTime.now()).inDays;

    return GestureDetector(
      onTap: () => context.push(
        '/customer/subscription-detail/${subscription.id}',
        extra: subscription,
      ),
      child: Card(
        child: Container(
          decoration: BoxDecoration(
            border: Border.left(
              color: isActive
                  ? AppTheme.success
                  : (isPaused ? AppTheme.warning : AppTheme.error),
              width: 4,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subscription.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${subscription.quantity} x ${subscription.unit} • ${_getFrequencyLabel(subscription.frequency)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.grey600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.success.withValues(alpha: 0.1)
                            : (isPaused
                                ? AppTheme.warning.withValues(alpha: 0.1)
                                : AppTheme.error.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive
                            ? 'Active'
                            : (isPaused ? 'Paused' : 'Cancelled'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? AppTheme.success
                              : (isPaused
                                  ? AppTheme.warning
                                  : AppTheme.error),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                // Next delivery info
                if (isActive) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Next Delivery',
                        style: TextStyle(fontSize: 12, color: AppTheme.grey600),
                      ),
                      Text(
                        daysUntilDelivery <= 0
                            ? 'Today'
                            : daysUntilDelivery == 1
                                ? 'Tomorrow'
                                : 'In $daysUntilDelivery days',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                // Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${(subscription.price * subscription.quantity).toStringAsFixed(0)} per ${_getFrequencyLabel(subscription.frequency).toLowerCase()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.grey800,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: AppTheme.grey400,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getFrequencyLabel(String frequency) {
    switch (frequency) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'biweekly':
        return 'Bi-Weekly';
      case 'monthly':
        return 'Monthly';
      default:
        return frequency;
    }
  }
}
