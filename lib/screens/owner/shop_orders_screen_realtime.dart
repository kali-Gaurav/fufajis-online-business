import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

/// Shop owner orders screen with real-time Firestore listeners
///
/// Features:
/// - Real-time order list (new orders appear instantly)
/// - Filters orders by shop ID
/// - Orders sorted by creation time (newest first)
/// - Shows order status badges (pending/preparing/ready/delivered)
/// - Auto-refresh when orders change
class ShopOrdersScreenRealtime extends StatefulWidget {
  final String shopId;

  const ShopOrdersScreenRealtime({super.key, required this.shopId});

  @override
  State<ShopOrdersScreenRealtime> createState() => _ShopOrdersScreenRealtimeState();
}

class _ShopOrdersScreenRealtimeState extends State<ShopOrdersScreenRealtime> {
  String _selectedFilter = 'all'; // all, pending, preparing, ready, delivered

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('all', 'All Orders'),
                _buildFilterChip('pending', 'Pending'),
                _buildFilterChip('preparing', 'Preparing'),
                _buildFilterChip('ready', 'Ready'),
                _buildFilterChip('delivered', 'Delivered'),
              ],
            ),
          ),

          // Real-time orders list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox_outlined, size: 64, color: AppTheme.grey300),
                        const SizedBox(height: 16),
                        Text('No orders found', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  );
                }

                final orders = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final orderData = orders[index].data() as Map<String, dynamic>;
                    final orderId = orders[index].id;

                    return _buildOrderCard(orderId: orderId, orderData: orderData);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build real-time orders stream filtered by shop and status
  Stream<QuerySnapshot> _buildOrdersStream() {
    Query query = FirebaseFirestore.instance
        .collection('orders')
        .where('shopId', isEqualTo: widget.shopId)
        .orderBy('createdAt', descending: true);

    // Apply status filter
    if (_selectedFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedFilter);
    }

    return query.snapshots();
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedFilter = value;
          });
        },
        selectedColor: AppTheme.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.grey900,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: AppTheme.grey50,
      ),
    );
  }

  Widget _buildOrderCard({required String orderId, required Map<String, dynamic> orderData}) {
    final orderNumber = orderData['orderNumber'] as String? ?? orderId;
    final status = orderData['status'] as String? ?? 'unknown';
    final createdAt = orderData['createdAt'];
    final customerId = orderData['customerId'] as String?;
    final totalAmount = orderData['totalAmount'] as num? ?? 0;
    final itemCount = (orderData['items'] as List?)?.length ?? 0;

    // Parse timestamp
    String timeText = '–';
    if (createdAt is Timestamp) {
      final date = createdAt.toDate();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 60) {
        timeText = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeText = '${diff.inHours}h ago';
      } else {
        timeText = DateFormat('MMM d').format(date);
      }
    }

    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          // Navigate to order detail
          Navigator.pushNamed(context, '/owner/order-detail/$orderId');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Order number and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #$orderNumber',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(timeText, style: const TextStyle(color: AppTheme.grey600, fontSize: 12)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      border: Border.all(color: statusColor.withAlpha(100)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(color: AppTheme.grey200),
              const SizedBox(height: 12),

              // Order details row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$itemCount item${itemCount != 1 ? 's' : ''}',
                        style: const TextStyle(color: AppTheme.grey700, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  // Quick action buttons
                  Row(
                    children: [
                      _buildStatusActionButton(status),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        iconSize: 16,
                        color: AppTheme.grey600,
                        onPressed: () {
                          Navigator.pushNamed(context, '/owner/order-detail/$orderId');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build quick action button based on current status
  Widget _buildStatusActionButton(String status) {
    String nextStatus;
    String buttonText;
    Color buttonColor;
    IconData buttonIcon;

    switch (status) {
      case 'pending':
        nextStatus = 'confirmed';
        buttonText = 'Confirm';
        buttonColor = Colors.blue;
        buttonIcon = Icons.done;
        break;
      case 'confirmed':
        nextStatus = 'preparing';
        buttonText = 'Prepare';
        buttonColor = Colors.orange;
        buttonIcon = Icons.done_all;
        break;
      case 'preparing':
        nextStatus = 'ready';
        buttonText = 'Ready';
        buttonColor = AppTheme.success;
        buttonIcon = Icons.check_circle;
        break;
      default:
        return const SizedBox.shrink();
    }

    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        onPressed: () {
          // Update order status
          // This should call an order service to update Firestore
          // The StreamBuilder will automatically refresh when the data changes
          _updateOrderStatus(status, nextStatus);
        },
        icon: Icon(buttonIcon, size: 12),
        label: Text(buttonText),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  /// Update order status in Firestore
  Future<void> _updateOrderStatus(String currentStatus, String nextStatus) async {
    try {
      // This is a placeholder - in real implementation,
      // this would update the Firestore order document
      // The StreamBuilder will automatically refresh when Firestore changes
      debugPrint('Update order status from $currentStatus to $nextStatus');
    } catch (e) {
      debugPrint('Error updating order status: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.red;
      case 'confirmed':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.green;
      case 'out_for_delivery':
        return Colors.purple;
      case 'delivered':
        return AppTheme.success;
      case 'cancelled':
        return Colors.grey;
      default:
        return AppTheme.grey600;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
        return Icons.done;
      case 'preparing':
        return Icons.pending;
      case 'ready':
        return Icons.check_circle;
      case 'out_for_delivery':
        return Icons.delivery_dining;
      case 'delivered':
        return Icons.home;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }
}
