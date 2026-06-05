import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';

class OrderPackingScreen extends StatefulWidget {
  final String orderId;
  const OrderPackingScreen({super.key, required this.orderId});

  @override
  State<OrderPackingScreen> createState() => _OrderPackingScreenState();
}

class _OrderPackingScreenState extends State<OrderPackingScreen> {
  OrderModel? _order;
  bool _isLoading = true;
  final Map<String, bool> _packedItems = {};

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
        if (order != null) {
          for (var item in order.items) {
            _packedItems[item.id] = false;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_order == null) {
      return const Scaffold(body: Center(child: Text('Order not found')));
    }

    final order = _order!;

    return Scaffold(
      appBar: AppBar(title: Text('Pack Order #${order.orderNumber}')),
      body: ListView(
        children: [
          ...order.items.map(
            (item) => CheckboxListTile(
              title: Text(item.productName),
              subtitle: Text('${item.quantity} x ${item.unit}'),
              value: _packedItems[item.id] ?? false,
              onChanged: (val) {
                setState(() {
                  _packedItems[item.id] = val ?? false;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _packedItems.values.every((v) => v)
                  ? () async {
                      await orderProvider.updateOrderStatus(
                        order.id,
                        OrderStatus.packed,
                      );
                      if (mounted) context.pop();
                    }
                  : null,
              child: const Text('Mark as Packed'),
            ),
          ),
        ],
      ),
    );
  }
}
