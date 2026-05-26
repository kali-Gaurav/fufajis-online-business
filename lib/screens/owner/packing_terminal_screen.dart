import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';
import '../../utils/app_theme.dart';

class PackingTerminalScreen extends StatefulWidget {
  final String? orderId;
  const PackingTerminalScreen({super.key, this.orderId});

  @override
  State<PackingTerminalScreen> createState() => _PackingTerminalScreenState();
}

class _PackingTerminalScreenState extends State<PackingTerminalScreen> {
  String? _activeOrderId;
  final Map<String, bool> _packedItems = {};

  @override
  void initState() {
    super.initState();
    _activeOrderId = widget.orderId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Packing Terminal (Split Screen)'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // Left: Order Queue
          Expanded(
            flex: 2,
            child: _buildOrderQueue(),
          ),
          const VerticalDivider(width: 1),
          // Right: Item Check-off
          Expanded(
            flex: 3,
            child: _activeOrderId == null 
              ? const Center(child: Text('Select an order to start packing'))
              : _buildItemChecklist(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderQueue() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final order = OrderModel.fromMap(docs[index].data() as Map<String, dynamic>);
            final isActive = _activeOrderId == order.id;

            return ListTile(
              selected: isActive,
              selectedTileColor: AppTheme.primary.withValues(alpha: 0.1),
              title: Text('#${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${order.items.length} items • ₹${order.totalAmount}'),
              onTap: () {
                setState(() {
                  _activeOrderId = order.id;
                  _packedItems.clear();
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildItemChecklist() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').doc(_activeOrderId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final order = OrderModel.fromMap(snapshot.data!.data() as Map<String, dynamic>);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Packing Order #${order.orderNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: order.items.length,
                itemBuilder: (context, index) {
                  final item = order.items[index];
                  final isPacked = _packedItems[item.id] ?? false;

                  return CheckboxListTile(
                    value: isPacked,
                    title: Text(item.productName),
                    subtitle: Text('${item.quantity} x ${item.unit}'),
                    onChanged: (val) {
                      setState(() => _packedItems[item.id] = val!);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _packedItems.length == order.items.length && _packedItems.values.every((v) => v)
                    ? () async {
                        await FirebaseFirestore.instance.collection('orders').doc(order.id).update({'status': 'packed'});
                        setState(() => _activeOrderId = null);
                      }
                    : null,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary, foregroundColor: Colors.white),
                  child: const Text('MARK AS PACKED', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
