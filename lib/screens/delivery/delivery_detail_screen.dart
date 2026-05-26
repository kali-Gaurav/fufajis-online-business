import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';
import '../../utils/app_theme.dart';

class DeliveryDetailScreen extends StatefulWidget {
  final String orderId;
  const DeliveryDetailScreen({super.key, required this.orderId});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  final TextEditingController _otpController = TextEditingController();
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
    final orderProvider = Provider.of<OrderProvider>(context);

    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_order == null) return const Scaffold(body: Center(child: Text('Order not found')));

    final order = _order!;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Delivery')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Order #${order.orderNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              decoration: const InputDecoration(labelText: 'Enter Delivery OTP'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (orderProvider.verifyDeliveryOTP(order.id, _otpController.text)) {
                  orderProvider.updateOrderStatus(order.id, OrderStatus.delivered);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery Verified!')));
                  context.pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid OTP'), backgroundColor: AppTheme.error));
                }
              },
              child: const Text('Verify & Complete'),
            ),
          ],
        ),
      ),
    );
  }
}
