import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_theme.dart';

class VendorOrdersScreen extends StatefulWidget {
  final String vendorId;

  const VendorOrdersScreen({Key? key, required this.vendorId}) : super(key: key);

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  final _supabase = Supabase.instance;
  List<VendorOrder> _orders = [];
  bool _isLoading = true;
  String _filterStatus = 'all';
  int _selectedTabIndex = 0;

  final List<String> _tabs = ['All', 'Pending', 'Confirmed', 'Processing', 'Delivered'];
  final List<String> _statusFilters = ['all', 'pending', 'confirmed', 'processing', 'delivered'];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      var query = _supabase.client
          .from('orders')
          .select()
          .eq('vendor_id', widget.vendorId)
          .order('created_at', ascending: false);

      final response = await query;
      if (mounted) {
        setState(() {
          _orders = (response as List).map((o) => VendorOrder.fromJson(o)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  List<VendorOrder> _getFilteredOrders() {
    final status = _statusFilters[_selectedTabIndex];
    if (status == 'all') return _orders;
    return _orders.where((o) => o.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildTabBar(),
                    Expanded(
                      child: _getFilteredOrders().isEmpty
                          ? Center(
                              child: Text(
                                'No ${_tabs[_selectedTabIndex].toLowerCase()} orders',
                                style: const TextStyle(color: AppTheme.grey600),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _getFilteredOrders().length,
                              itemBuilder: (_, index) =>
                                  _buildOrderCard(_getFilteredOrders()[index]),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            const Text(
              'No Orders Yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text(
              'Orders from your products will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.grey600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(
            _tabs.length,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                selected: _selectedTabIndex == index,
                onSelected: (_) => setState(() => _selectedTabIndex = index),
                label: Text(_tabs[index]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(VendorOrder order) {
    final statusColor = _getStatusColor(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      'Order #${order.id.substring(0, 8)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(order.createdAt),
                      style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    order.status.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer',
                      style: TextStyle(fontSize: 11, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 11, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (order.itemCount > 0)
              Text(
                '${order.itemCount} item${order.itemCount > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewOrderDetails(order),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 12),
                if (order.status == 'confirmed')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateOrderStatus(order, 'processing'),
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Mark Processing'),
                    ),
                  )
                else if (order.status == 'processing')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateOrderStatus(order, 'delivered'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Delivered'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewOrderDetails(VendorOrder order) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Order Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Order ID', order.id.substring(0, 12)),
            _buildDetailRow('Customer', order.customerName),
            _buildDetailRow('Total Amount', '₹${order.totalAmount.toStringAsFixed(2)}'),
            _buildDetailRow('Items', order.itemCount.toString()),
            _buildDetailRow('Status', order.status.toUpperCase()),
            _buildDetailRow('Created', _formatDate(order.createdAt)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.grey600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _updateOrderStatus(VendorOrder order, String newStatus) async {
    try {
      await _supabase.client
          .from('orders')
          .update({'status': newStatus}).eq('id', order.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated to ${newStatus.toUpperCase()}')),
        );
        _loadOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class VendorOrder {
  final String id;
  final String vendorId;
  final String customerId;
  final String customerName;
  final double totalAmount;
  final int itemCount;
  final String status;
  final DateTime createdAt;
  final DateTime? deliveredAt;

  VendorOrder({
    required this.id,
    required this.vendorId,
    required this.customerId,
    required this.customerName,
    required this.totalAmount,
    required this.itemCount,
    required this.status,
    required this.createdAt,
    this.deliveredAt,
  });

  factory VendorOrder.fromJson(Map<String, dynamic> json) {
    return VendorOrder(
      id: json['id'] ?? '',
      vendorId: json['vendor_id'] ?? '',
      customerId: json['customer_id'] ?? '',
      customerName: json['customer_name'] ?? 'Unknown',
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
      itemCount: json['item_count'] ?? 0,
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'])
          : null,
    );
  }
}
