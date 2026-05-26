import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';
import '../../utils/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/invoice_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderModel? _order;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final order = await orderProvider.getOrderById(widget.orderId);
    if (mounted) {
      setState(() {
        _order = order;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: Text('Order not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: Text('Order #${_order!.orderNumber}'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => InvoiceService.generateAndPrintInvoice(_order!),
            icon: const Icon(Icons.download),
            tooltip: 'Download Invoice',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStatusHeader(),
            _buildItemsList(),
            _buildShopSection(),
            _buildDeliverySection(),
            _buildPriceDetails(),
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _order!.statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _order!.status.displayName.toUpperCase(),
              style: TextStyle(
                color: _order!.statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDateTime(_order!.createdAt),
            style: const TextStyle(color: AppTheme.grey600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
          const Divider(),
          ..._order!.items.map((item) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: item.productImage,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const Icon(Icons.image),
              ),
            ),
            title: Text(item.productName),
            subtitle: Text('${item.quantity} x ₹${item.price.round()}'),
            trailing: Text('₹${item.totalPrice.round()}', style: const TextStyle(fontWeight: FontWeight.bold)),
          )),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isBold = false, Color color = AppTheme.grey900}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: AppTheme.grey700)),
          Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: color)),
        ],
      ),
    );
  }

  Widget _buildPriceDetails() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildPriceRow('Subtotal', _order!.subtotal),
          if (_order!.deliveryCharge > 0) _buildPriceRow('Delivery Fee', _order!.deliveryCharge),
          const Divider(),
          _buildPriceRow('Total', _order!.totalAmount, isBold: true, color: AppTheme.primary),
        ],
      ),
    );
  }

  Widget _buildShopSection() {
    if (_order!.shopId == null) return const SizedBox();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.store, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(_order!.shopName ?? 'Shop', style: const TextStyle(fontWeight: FontWeight.bold))),
          if (_order!.shopPhone != null)
            IconButton(icon: const Icon(Icons.phone, color: AppTheme.primary), onPressed: () => launchUrl(Uri.parse('tel:${_order!.shopPhone}'))),
        ],
      ),
    );
  }

  Widget _buildDeliverySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_order!.deliveryAddress.fullAddress, style: const TextStyle(color: AppTheme.grey700)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (_order!.canCancel)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showCancelDialog,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
                child: const Text('Cancel Order'),
              ),
            ),
          if (_order!.canReturn)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showReturnDialog,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning, foregroundColor: Colors.white),
                  child: const Text('Return Order'),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push('/customer/support-chat/${_order!.id}'),
              child: const Text('Contact Support'),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelOrder();
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _showReturnDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return Order'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'Enter reason for return'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _requestReturn(reasonController.text);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final success = await orderProvider.cancelOrder(_order!.id, 'Cancelled by user');
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Cancelled')));
      _loadOrder();
    }
  }

  Future<void> _requestReturn(String reason) async {
    if (reason.isEmpty) return;
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final success = await orderProvider.createReturnRequest(
      orderId: _order!.id,
      reason: reason,
      itemIds: _order!.items.map((i) => i.id).toList(),
    );
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return Requested')));
      _loadOrder();
    }
  }

  String _formatDateTime(DateTime dt) => '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
}
