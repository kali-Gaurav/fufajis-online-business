import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_tracking_model.dart';
import '../../providers/order_tracking_provider.dart';
import 'package:intl/intl.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({Key? key}) : super(key: key);

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Load order history
    Future.microtask(() {
      context.read<OrderTrackingProvider>().loadOrderHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        elevation: 0,
      ),
      body: Consumer<OrderTrackingProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.orderHistory.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No orders yet',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start shopping to see your orders here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.orderHistory.length,
            itemBuilder: (context, index) {
              final order = provider.orderHistory[index];
              return _OrderHistoryCard(order: order);
            },
          );
        },
      ),
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  final OrderTracking order;

  const _OrderHistoryCard({Key? key, required this.order}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final now = DateTime.now();
    final orderDate = order.createdAt;

    String getRelativeDate(DateTime date) {
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return 'Today, ${timeFormat.format(date)}';
      } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
        return 'Yesterday, ${timeFormat.format(date)}';
      } else {
        return dateFormat.format(date);
      }
    }

    Color getStatusColor() {
      switch (order.status) {
        case 'confirmed':
        case 'processing':
        case 'packed':
          return Colors.orange;
        case 'shipped':
          return Colors.blue;
        case 'delivered':
          return Colors.green;
        case 'cancelled':
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    String getStatusIcon() {
      switch (order.status) {
        case 'confirmed':
          return '📋';
        case 'processing':
          return '🔄';
        case 'packed':
          return '📦';
        case 'shipped':
          return '🚗';
        case 'delivered':
          return '✓';
        case 'cancelled':
          return '✗';
        default:
          return '•';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Order number and date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.orderNumber}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        getRelativeDate(orderDate),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${order.amount?.toStringAsFixed(2) ?? '0.00'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    getStatusIcon(),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    order.status.replaceAll('_', ' ').toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: getStatusColor(),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Items summary
            Text(
              '${order.itemCount ?? 0} items',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Navigate to tracking screen
                      Navigator.of(context).pushNamed(
                        '/order-tracking',
                        arguments: order.orderId,
                      );
                    },
                    icon: const Icon(Icons.place, size: 18),
                    label: const Text('Track'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Show reorder dialog
                      _showReorderDialog(context, order);
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reorder'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Navigate to rating screen
                      Navigator.of(context).pushNamed(
                        '/rate-order',
                        arguments: order.orderId,
                      );
                    },
                    icon: const Icon(Icons.star, size: 18),
                    label: const Text('Rate'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReorderDialog(BuildContext context, OrderTracking order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reorder Items?'),
        content: Text(
          'Add the same ${order.itemCount ?? 0} items from this order to your cart?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Add items to cart
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Items added to cart')),
              );
            },
            child: const Text('Reorder'),
          ),
        ],
      ),
    );
  }
}

extension on OrderTracking {
  double? get amount => null; // TODO: Get from order model
  int? get itemCount => statusHistory.length > 0 ? 1 : null; // TODO: Get actual item count
}
