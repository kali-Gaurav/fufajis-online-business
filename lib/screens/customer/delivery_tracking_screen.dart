import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../utils/app_theme.dart';
import '../../constants/app_typography.dart';
import '../../constants/app_spacing.dart';

/// Customer delivery tracking screen. Shows live order status and
/// estimated arrival for active orders.
class DeliveryTrackingScreen extends StatelessWidget {
  final String orderId;
  const DeliveryTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final order = orderProvider.orders.where((o) => o.id == orderId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Order', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: order == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatusCard(status: order.status.name),
                const SizedBox(height: 16),
                _StepTimeline(status: order.status.name),
                const SizedBox(height: 16),
                _OrderSummaryCard(
                  orderId: order.id,
                  total: order.total.toDouble(),
                  itemCount: order.items.length,
                ),
              ],
            ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 40),
          const SizedBox(height: 8),
          Text(
            status.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your order is on its way',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StepTimeline extends StatelessWidget {
  final String status;
  const _StepTimeline({required this.status});

  static const _steps = [
    ('Order Placed', Icons.check_circle_outline),
    ('Confirmed', Icons.storefront_outlined),
    ('Packed', Icons.inventory_2_outlined),
    ('Out for Delivery', Icons.delivery_dining_outlined),
    ('Delivered', Icons.home_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _steps.indexed.map((entry) {
            final i = entry.$1;
            final step = entry.$2;
            final isLast = i == _steps.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.8),
                      child: Icon(step.$2, size: 14, color: Colors.white),
                    ),
                    if (!isLast) Container(width: 2, height: 30, color: AppTheme.grey200),
                  ],
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    step.$1,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final String orderId;
  final double total;
  final int itemCount;
  const _OrderSummaryCard({required this.orderId, required this.total, required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Row('Order ID', orderId.length > 12 ? '${orderId.substring(0, 12)}...' : orderId),
            _Row('Items', '$itemCount items'),
            _Row('Total', 'Rs. ${total.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
