import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../models/order_model.dart';
import '../../models/delivery_type.dart';
import '../../utils/app_theme.dart';
import '../../services/order_service.dart';

/// Real-time Kanban Packing Dashboard for owners and packers.
///
/// Features:
///   - Real-time Firestore streams for each order stage.
///   - Tap-to-advance status flow.
///   - Tap card to open PackingTerminal checklist for preparation.
///   - Clean, color-coded visual indicator cards for Indian hyperlocal delivery.
class PackingDashboardScreen extends StatelessWidget {
  const PackingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey100,
      appBar: AppBar(
        title: const Text('Fulfillment Dashboard (Kanban)'),
        backgroundColor: AppTheme.grey900,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory),
            tooltip: 'Packing Terminal',
            onPressed: () => context.push('/owner/packing-terminal'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildKanbanColumn(
                context,
                title: 'New Orders',
                status: OrderStatus.pending,
                color: Colors.orange,
                icon: Icons.pending_actions,
              ),
              _buildKanbanColumn(
                context,
                title: 'Confirmed',
                status: OrderStatus.confirmed,
                color: Colors.blue,
                icon: Icons.check_circle_outline,
              ),
              _buildKanbanColumn(
                context,
                title: 'Preparing',
                status: OrderStatus.processing,
                color: Colors.indigo,
                icon: Icons.sync,
              ),
              _buildKanbanColumn(
                context,
                title: 'Packed / Ready',
                status: OrderStatus.packed,
                color: Colors.purple,
                icon: Icons.inventory_2_outlined,
              ),
              _buildKanbanColumn(
                context,
                title: 'Out for Delivery',
                status: OrderStatus.outForDelivery,
                color: Colors.cyan,
                icon: Icons.local_shipping_outlined,
              ),
              _buildKanbanColumn(
                context,
                title: 'Delivered',
                status: OrderStatus.delivered,
                color: Colors.green,
                icon: Icons.task_alt,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKanbanColumn(
    BuildContext context, {
    required String title,
    required OrderStatus status,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: 320,
      margin: const EdgeInsets.all(12),
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
          // Column Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.grey200, width: 1.5)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.grey900),
                ),
                const Spacer(),
                _buildCountBadge(status, color),
              ],
            ),
          ),
          
          // Orders Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('status', isEqualTo: status.toString())
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(fontSize: 12)));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 36, color: AppTheme.grey300),
                        const SizedBox(height: 8),
                        Text(
                          'No orders',
                          style: TextStyle(color: AppTheme.grey400, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final order = OrderModel.fromMap(docs[index].data() as Map<String, dynamic>);
                    return _buildOrderCard(context, order, color);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountBadge(OrderStatus status, Color color) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: status.toString())
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderModel order, Color themeColor) {
    return GestureDetector(
      onTap: () {
        // Tapping card opens the preparation packing checklist
        context.push('/owner/packing-terminal?orderId=${order.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.grey200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order number + delivery tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${order.orderNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey900),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: order.deliveryType == DeliveryType.sameDay 
                        ? Colors.red.withValues(alpha: 0.08) 
                        : Colors.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.deliveryType == DeliveryType.sameDay ? 'Same Day' : 'Scheduled',
                    style: TextStyle(
                      color: order.deliveryType == DeliveryType.sameDay ? Colors.red : Colors.amber.shade800,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Customer Name
            Text(
              order.customerName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.grey700),
            ),
            const SizedBox(height: 4),

            // Substitution status highlights
            if (order.items.any((item) => item.isPacked && item.productId.startsWith('p_temp_') || item.isOutOfStock)) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.swap_horiz, color: Colors.amber, size: 14),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Substitutions / OOS Pending Action',
                        style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),

            // Item count & total price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${order.items.length} items • ₹${order.totalAmount.round()}',
                  style: TextStyle(color: AppTheme.grey500, fontSize: 12),
                ),
                Text(
                  _formatTime(order.createdAt),
                  style: TextStyle(color: AppTheme.grey400, fontSize: 11),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Action: Advance Status Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(),
                if (order.status != OrderStatus.delivered && order.status != OrderStatus.cancelled)
                  TextButton.icon(
                    onPressed: () => _advanceOrderStatus(context, order),
                    icon: Icon(Icons.arrow_forward, size: 14, color: themeColor),
                    label: Text(
                      _getNextStatusActionLabel(order.status),
                      style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: themeColor.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _getNextStatusActionLabel(OrderStatus currentStatus) {
    switch (currentStatus) {
      case OrderStatus.pending:
        return 'Confirm';
      case OrderStatus.confirmed:
        return 'Start Preparing';
      case OrderStatus.processing:
        return 'Ready to Pack';
      case OrderStatus.packed:
        return 'Ship / Delivery';
      case OrderStatus.outForDelivery:
        return 'Mark Delivered';
      default:
        return 'Advance';
    }
  }

  Future<void> _advanceOrderStatus(BuildContext context, OrderModel order) async {
    final nextStatus = _getNextStatus(order.status);
    if (nextStatus == null) return;

    try {
      await OrderService().updateOrderStatus(order.id, nextStatus.toString().split('.').last);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${order.orderNumber} moved to ${nextStatus.displayName}'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order status: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  OrderStatus? _getNextStatus(OrderStatus currentStatus) {
    switch (currentStatus) {
      case OrderStatus.pending:
        return OrderStatus.confirmed;
      case OrderStatus.confirmed:
        return OrderStatus.processing;
      case OrderStatus.processing:
        return OrderStatus.packed;
      case OrderStatus.packed:
        return OrderStatus.outForDelivery;
      case OrderStatus.outForDelivery:
        return OrderStatus.delivered;
      default:
        return null;
    }
  }
}
