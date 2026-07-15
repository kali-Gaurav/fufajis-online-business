import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/subscription_service.dart';
import '../../utils/app_theme.dart';

class CustomerSubscriptionsScreen extends StatefulWidget {
  const CustomerSubscriptionsScreen({Key? key}) : super(key: key);

  @override
  State<CustomerSubscriptionsScreen> createState() =>
      _CustomerSubscriptionsScreenState();
}

class _CustomerSubscriptionsScreenState extends State<CustomerSubscriptionsScreen> {
  final _subscriptionService = SubscriptionService();
  final _supabase = Supabase.instance;
  int _selectedTab = 0;
  final List<String> _tabs = ['Active', 'Paused', 'Cancelled'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('My Subscriptions', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: StreamBuilder<List<Subscription>>(
        stream: _subscriptionService.watchCustomerSubscriptions(
          _supabase.client.auth.currentUser?.id ?? '',
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  const Text('Error loading subscriptions'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final subscriptions = snapshot.data ?? [];
          if (subscriptions.isEmpty) {
            return _buildEmptyState();
          }

          final filteredSubs = _getFilteredSubscriptions(subscriptions);

          return Column(
            children: [
              _buildTabBar(),
              Expanded(
                child: filteredSubs.isEmpty
                    ? _buildEmptyTabState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredSubs.length,
                        itemBuilder: (_, index) => _buildSubscriptionCard(
                          context,
                          filteredSubs[index],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSubscriptionDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('New Subscription'),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(
            _tabs.length,
            (index) => Padding(
              padding: EdgeInsets.only(left: index == 0 ? 16 : 8, right: 8),
              child: FilterChip(
                selected: _selectedTab == index,
                onSelected: (_) => setState(() => _selectedTab = index),
                label: Text(_tabs[index]),
                backgroundColor: Colors.white,
                selectedColor: AppTheme.primary.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: _selectedTab == index ? AppTheme.primary : AppTheme.grey600,
                  fontWeight: _selectedTab == index ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Subscription> _getFilteredSubscriptions(List<Subscription> all) {
    switch (_selectedTab) {
      case 0:
        return all.where((s) => s.status == 'active').toList();
      case 1:
        return all.where((s) => s.status == 'paused').toList();
      case 2:
        return all.where((s) => s.status == 'cancelled').toList();
      default:
        return all;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 80, color: Colors.green[200]),
            const SizedBox(height: 24),
            const Text(
              'No Subscriptions Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.grey800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Get milk, bread, and other essentials delivered every day!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.grey500),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showCreateSubscriptionDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Subscription'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTabState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No ${_tabs[_selectedTab].toLowerCase()} subscriptions',
            style: const TextStyle(color: AppTheme.grey600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, Subscription sub) {
    final statusColor = _getStatusColor(sub.status);
    final nextDelivery = sub.nextDeliveryDate;
    final daysUntilDelivery = nextDelivery?.difference(DateTime.now()).inDays ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subscription #${sub.id.substring(0, 8)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    sub.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Frequency: ${_getFrequencyLabel(sub.frequency)}',
              style: const TextStyle(color: AppTheme.grey600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (nextDelivery != null)
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Next: ${_formatDate(nextDelivery)}',
                    style: const TextStyle(fontSize: 14, color: AppTheme.grey700),
                  ),
                  if (daysUntilDelivery > 0)
                    Text(
                      ' (in $daysUntilDelivery days)',
                      style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(fontSize: 12, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${sub.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => _openDetailScreen(context, sub),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _showActionsMenu(context, sub),
                      icon: const Icon(Icons.more_vert),
                      label: const Text('More'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openDetailScreen(BuildContext context, Subscription sub) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionDetailScreen(subscription: sub),
      ),
    );
  }

  void _showActionsMenu(BuildContext context, Subscription sub) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.pause),
            title: const Text('Pause Subscription'),
            enabled: sub.status == 'active',
            onTap: sub.status == 'active'
                ? () {
                    Navigator.pop(context);
                    _pauseSubscription(sub);
                  }
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Resume Subscription'),
            enabled: sub.status == 'paused',
            onTap: sub.status == 'paused'
                ? () {
                    Navigator.pop(context);
                    _resumeSubscription(sub);
                  }
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Cancel Subscription', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showCancelDialog(sub);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _pauseSubscription(Subscription sub) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pause Subscription'),
        content: const Text('How many days would you like to pause this subscription?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 7),
            child: const Text('7 days'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 30),
            child: const Text('30 days'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        await _subscriptionService.pauseSubscription(sub.id, result);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription paused successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _resumeSubscription(Subscription sub) async {
    try {
      await _subscriptionService.resumeSubscription(sub.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription resumed')),
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

  Future<void> _showCancelDialog(Subscription sub) async {
    final reasonController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('We\'d like to know why you\'re cancelling (optional):'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tell us your reason...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Subscription'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await _subscriptionService.cancelSubscription(
          sub.id,
          reasonController.text.isEmpty ? 'No reason provided' : reasonController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription cancelled')),
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
  }

  void _showCreateSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Subscription'),
        content: const Text('Select items and frequency for your subscription'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to subscription creation flow
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'paused':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getFrequencyLabel(String frequency) {
    switch (frequency.toLowerCase()) {
      case 'weekly':
        return 'Every Week';
      case 'biweekly':
        return 'Every 2 Weeks';
      case 'monthly':
        return 'Every Month';
      default:
        return frequency;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Import required for detail screen
import 'subscription_detail_screen.dart';
