import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/subscription_model.dart';
import '../../providers/subscription_provider.dart';
import '../../utils/app_theme.dart';

class SubscriptionDetailScreen extends StatefulWidget {
  final String subscriptionId;

  const SubscriptionDetailScreen({
    required this.subscriptionId,
    Key? key,
  }) : super(key: key);

  @override
  State<SubscriptionDetailScreen> createState() =>
      _SubscriptionDetailScreenState();
}

class _SubscriptionDetailScreenState extends State<SubscriptionDetailScreen> {
  late SubscriptionModel _subscription;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionDetails();
  }

  Future<void> _loadSubscriptionDetails() async {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    final subscription = subscriptionProvider.subscriptions.firstWhere(
      (s) => s.id == widget.subscriptionId,
      orElse: () => SubscriptionModel.empty(),
    );

    if (mounted) {
      setState(() {
        _subscription = subscription;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSubscriptionStatus() async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);
    try {
      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      final newStatus = _subscription.status == SubscriptionStatus.active
          ? SubscriptionStatus.paused
          : SubscriptionStatus.active;

      await subscriptionProvider.updateSubscriptionStatus(_subscription.id, newStatus);

      if (mounted) {
        _loadSubscriptionDetails();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Subscription ${newStatus == SubscriptionStatus.active ? 'resumed' : 'paused'} successfully',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _cancelSubscription() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: Text(
          'Are you sure you want to cancel your subscription to ${_subscription.productName}? You can reactivate it anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep It'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isUpdating = true);
              try {
                final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
                await subscriptionProvider.updateSubscriptionStatus(
                  _subscription.id,
                  SubscriptionStatus.cancelled,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Subscription cancelled')),
                  );
                  context.pop();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isUpdating = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Subscription Details'),
          backgroundColor: AppTheme.cream,
          foregroundColor: AppTheme.grey900,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_subscription.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Subscription Details'),
          backgroundColor: AppTheme.cream,
          foregroundColor: AppTheme.grey900,
          elevation: 0,
        ),
        body: const Center(child: Text('Subscription not found')),
      );
    }

    final nextDelivery = _subscription.nextDeliveryDate ?? DateTime.now().add(const Duration(days: 7));
    final daysUntilDelivery = nextDelivery.difference(DateTime.now()).inDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Details'),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Card
              Card(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.left(
                      color: _subscription.status == SubscriptionStatus.active
                          ? AppTheme.success
                          : (_subscription.status == SubscriptionStatus.paused
                              ? AppTheme.warning
                              : AppTheme.error),
                      width: 4,
                    ),
                  ),
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
                                    _subscription.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_subscription.quantity} x ${_subscription.unit}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.grey600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _subscription.status == SubscriptionStatus.active
                                    ? AppTheme.success.withOpacity(0.1)
                                    : (_subscription.status == SubscriptionStatus.paused
                                        ? AppTheme.warning.withOpacity(0.1)
                                        : AppTheme.error.withOpacity(0.1)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _subscription.status == SubscriptionStatus.active
                                    ? 'Active'
                                    : (_subscription.status == SubscriptionStatus.paused
                                        ? 'Paused'
                                        : 'Cancelled'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _subscription.status == SubscriptionStatus.active
                                      ? AppTheme.success
                                      : (_subscription.status == SubscriptionStatus.paused
                                          ? AppTheme.warning
                                          : AppTheme.error),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Details Section
              const Text(
                'Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        'Frequency',
                        _getFrequencyLabel(_subscription.frequency),
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        'Price per ${_getFrequencyLabel(_subscription.frequency).toLowerCase()}',
                        '₹${(_subscription.price * _subscription.quantity).toStringAsFixed(0)}',
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        'Unit Price',
                        '₹${_subscription.price.toStringAsFixed(0)}',
                      ),
                      if (_subscription.status == SubscriptionStatus.active) ...[
                        const Divider(height: 16),
                        _buildDetailRow(
                          'Next Delivery',
                          daysUntilDelivery <= 0
                              ? 'Today'
                              : daysUntilDelivery == 1
                                  ? 'Tomorrow'
                                  : 'In $daysUntilDelivery days',
                          valueColor: AppTheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Actions Section
              const Text(
                'Actions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              if (_subscription.status != SubscriptionStatus.cancelled) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isUpdating ? null : _toggleSubscriptionStatus,
                    icon: Icon(
                      _subscription.status == SubscriptionStatus.active
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                    ),
                    label: Text(
                      _subscription.status == SubscriptionStatus.active ? 'Pause' : 'Resume',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isUpdating ? null : _cancelSubscription,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Cancel Subscription'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.grey600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: valueColor ?? AppTheme.grey800,
          ),
        ),
      ],
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
