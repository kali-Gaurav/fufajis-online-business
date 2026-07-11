import 'package:flutter/material.dart';
import '../../services/supplier_service.dart';
import 'supplier_order_detail_screen.dart';

class SupplierOrderFeedScreen extends StatefulWidget {
  const SupplierOrderFeedScreen({Key? key}) : super(key: key);

  @override
  State<SupplierOrderFeedScreen> createState() => _SupplierOrderFeedScreenState();
}

class _SupplierOrderFeedScreenState extends State<SupplierOrderFeedScreen> {
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

    return StreamBuilder<List<SupplierOrder>>(
      stream: _supplierService.watchSupplierOrders(_currentSupplier!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Error loading orders'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() => _loadCurrentSupplier()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No orders yet',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pending orders will appear here',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildOrderCard(context, order);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, SupplierOrder order) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SupplierOrderDetailScreen(order: order),
          ),
        );
      },
      child: Card(
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
                        'PO #${order.poNumber}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Created: ${order.createdAt.toString().split(' ')[0]}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  _buildStatusBadge(order.status),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                '${order.items.length} item(s) - ₹${order.finalAmount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Expected Delivery: ${order.expectedDeliveryDate.toString().split(' ')[0]}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              if (order.status == 'confirmed')
                ElevatedButton(
                  onPressed: () async {
                    await _supplierService.markOrderDispatched(order.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order marked as dispatched')),
                      );
                    }
                  },
                  child: const Text('Mark Dispatched'),
                )
              else if (order.status == 'draft')
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await _supplierService.acceptSupplierOrder(order.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Order accepted')),
                            );
                          }
                        },
                        child: const Text('Accept'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await _showRejectDialog(context, order.id);
                        },
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final statusConfig = {
      'draft': (Colors.grey, '📋 Draft'),
      'confirmed': (Colors.blue, '✅ Confirmed'),
      'dispatched': (Colors.orange, '🚚 Dispatched'),
      'received': (Colors.green, '📦 Received'),
      'cancelled': (Colors.red, '❌ Cancelled'),
    };

    final (color, label) = statusConfig[status] ?? (Colors.grey, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Future<void> _showRejectDialog(BuildContext context, String orderId) async {
    final reasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Order'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Why are you rejecting this order?',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _supplierService.rejectSupplierOrder(
                orderId,
                reasonController.text,
              );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Order rejected')),
                );
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
