import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../services/replacement_service.dart';
import '../../services/whatsapp_notification_service.dart';
import '../../utils/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PackingTerminalScreen extends StatefulWidget {
  final String? orderId;
  const PackingTerminalScreen({super.key, this.orderId});

  @override
  State<PackingTerminalScreen> createState() => _PackingTerminalScreenState();
}

class _PackingTerminalScreenState extends State<PackingTerminalScreen> {
  String? _activeOrderId;
  final Map<String, bool> _packedItems = {};
  final Map<String, double> _itemWeights = {};
  final Map<String, bool> _outOfStockItems = {};
  
  // Step 29.4: Packing timer
  Stopwatch? _packingTimer;
  Timer? _uiTimer;
  String _elapsedTime = '00:00';

  @override
  void initState() {
    super.initState();
    _activeOrderId = widget.orderId;
    if (_activeOrderId != null) _startTimer();
  }

  void _startTimer() {
    _packingTimer = Stopwatch()..start();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _packingTimer != null) {
        final duration = _packingTimer!.elapsed;
        setState(() {
          _elapsedTime = '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
        });
      }
    });
  }

  void _stopTimer() {
    _packingTimer?.stop();
    _uiTimer?.cancel();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey100,
      appBar: AppBar(
        title: const Text('Order Fulfillment Terminal'),
        backgroundColor: AppTheme.grey900,
        foregroundColor: Colors.white,
        actions: [
          if (_activeOrderId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  'Timer: $_elapsedTime',
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.greenAccent),
                ),
              ),
            ),
        ],
      ),
      body: Row(
        children: [
          // Left: Order Queue
          Container(
            width: 320,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: AppTheme.grey300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('PENDING QUEUE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppTheme.grey600)),
                ),
                Expanded(child: _buildOrderQueue()),
              ],
            ),
          ),
          
          // Right: Item Check-off
          Expanded(
            child: _activeOrderId == null 
              ? _buildTerminalIdleState()
              : _buildItemChecklist(),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalIdleState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: AppTheme.grey300),
          const SizedBox(height: 16),
          const Text('Select an order from the queue to start packing', style: TextStyle(color: AppTheme.grey500)),
        ],
      ),
    );
  }

  Widget _buildOrderQueue() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'OrderStatus.processing')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) return const Center(child: Text('No orders in preparation', style: TextStyle(fontSize: 12)));

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final order = OrderModel.fromMap(docs[index].data() as Map<String, dynamic>);
            final isActive = _activeOrderId == order.id;

            return ListTile(
              selected: isActive,
              selectedTileColor: AppTheme.primary.withValues(alpha: 0.05),
              leading: CircleAvatar(
                backgroundColor: AppTheme.grey200,
                child: Text('${order.items.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.grey800)),
              ),
              title: Text('#${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('₹${order.totalAmount.round()} • ${_formatDate(order.createdAt)}', style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                setState(() {
                  _activeOrderId = order.id;
                  _packedItems.clear();
                  _itemWeights.clear();
                  _outOfStockItems.clear();
                  _stopTimer();
                  _startTimer();
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
        if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());
        final order = OrderModel.fromMap(snapshot.data!.data() as Map<String, dynamic>);
        final productProvider = Provider.of<ProductProvider>(context);

        return Column(
          children: [
            _buildPackingHeader(order),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: order.items.length,
                itemBuilder: (context, index) {
                  final item = order.items[index];
                  return _buildPackingItemTile(item, productProvider);
                },
              ),
            ),
            _buildPackingFooter(order),
          ],
        );
      },
    );
  }

  Widget _buildPackingHeader(OrderModel order) {
    final handledCount = order.items.where((item) {
      final isPacked = _packedItems[item.id] ?? false;
      final isOos = _outOfStockItems[item.id] ?? item.isOutOfStock;
      return isPacked || isOos;
    }).length;

    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Packing: #${order.orderNumber}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              Text('Customer: ${order.customerName}', style: const TextStyle(color: AppTheme.grey600)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Handled', style: TextStyle(fontSize: 12, color: AppTheme.grey500)),
              Text('$handledCount / ${order.items.length}', 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPackingItemTile(OrderItem item, ProductProvider productProvider) {
    final isPacked = _packedItems[item.id] ?? false;
    final isOos = _outOfStockItems[item.id] ?? item.isOutOfStock;
    
    final bool isWeightUnit = item.unit.toLowerCase().contains('kg') || 
                              item.unit.toLowerCase().contains('g') || 
                              item.unit.toLowerCase().contains('kilo') || 
                              item.unit.toLowerCase().contains('gm');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isOos 
            ? Colors.red.withValues(alpha: 0.05)
            : isPacked 
                ? AppTheme.success.withValues(alpha: 0.05) 
                : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOos
              ? Colors.red.withValues(alpha: 0.3)
              : isPacked 
                  ? AppTheme.success.withValues(alpha: 0.3) 
                  : AppTheme.grey200
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppTheme.grey100),
          child: item.productImage != null 
            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: item.productImage!, fit: BoxFit.cover))
            : const Icon(Icons.shopping_bag),
        ),
        title: Text(
          item.productName, 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isOos ? TextDecoration.lineThrough : null,
          )
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Qty: ${item.quantity} ${item.unit}', 
              style: TextStyle(
                color: isOos ? Colors.red : AppTheme.primary, 
                fontWeight: FontWeight.bold
              )
            ),
            if (isWeightUnit && !isOos) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Actual Wt: ', style: TextStyle(fontSize: 12, color: AppTheme.grey600)),
                  SizedBox(
                    width: 100,
                    height: 32,
                    child: TextField(
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        final wt = double.tryParse(val);
                        if (wt != null) {
                          _itemWeights[item.id] = wt;
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isPacked && !isOos)
              IconButton(
                icon: const Icon(Icons.help_outline, color: AppTheme.warning),
                onPressed: () => _showReplacementDialog(item, productProvider),
                tooltip: 'Out of Stock / Replacement',
              ),
            if (isOos)
              const Text('OUT OF STOCK', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11))
            else
              Transform.scale(
                scale: 1.2,
                child: Checkbox(
                  value: isPacked,
                  activeColor: AppTheme.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) {
                    setState(() => _packedItems[item.id] = val!);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showReplacementDialog(OrderItem item, ProductProvider provider) {
    final originalProduct = provider.getProductById(item.productId);
    if (originalProduct == null) return;

    final replacements = ReplacementService().suggestReplacements(originalProduct, provider.products);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Item Missing / Replace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sorry, ${item.productName} is out of stock.', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Suggested Replacements:', style: TextStyle(fontSize: 12, color: AppTheme.grey600)),
            const SizedBox(height: 8),
            if (replacements.isEmpty)
              const Text('No replacements found in matching category.', style: TextStyle(fontStyle: FontStyle.italic))
            else
              ...replacements.map((p) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundImage: CachedNetworkImageProvider(p.imageUrl)),
                title: Text(p.name, style: const TextStyle(fontSize: 14)),
                subtitle: Text('₹${p.price}'),
                trailing: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _applyReplacement(item, p);
                  },
                  child: const Text('Select'),
                ),
              )).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _markItemOutOfStock(item);
            },
            child: const Text('Mark OOS (No Replace)', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Future<void> _applyReplacement(OrderItem oldItem, ProductModel newProduct) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('orders').doc(_activeOrderId);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) return;
      
      final order = OrderModel.fromMap(docSnapshot.data()!);
      final updatedItems = order.items.map((it) {
        if (it.id == oldItem.id) {
          return it.copyWith(
            productId: newProduct.id,
            productName: newProduct.name,
            productImage: newProduct.imageUrl,
            price: newProduct.price,
            totalPrice: newProduct.price * it.quantity,
            isPacked: true,
          );
        }
        return it;
      }).toList();
      
      final newSubtotal = updatedItems.fold(0.0, (total, it) => total + it.totalPrice);
      final newTotal = newSubtotal + order.deliveryCharge - order.discount;

      await docRef.update({
        'items': updatedItems.map((e) => e.toMap()).toList(),
        'subtotal': newSubtotal,
        'totalAmount': newTotal,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send WhatsApp Notification to Customer
      if (order.customerPhone.isNotEmpty) {
        await WhatsAppNotificationService.sendSubstitutionNotification(
          phoneNumber: order.customerPhone,
          customerName: order.customerName,
          orderNumber: order.orderNumber,
          originalName: oldItem.productName,
          replacementName: newProduct.name,
          replacementPrice: newProduct.price,
        );
      }

      setState(() {
        _packedItems[oldItem.id] = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Replaced ${oldItem.productName} with ${newProduct.name}. Customer notified!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('[PackingTerminal] Error applying replacement: $e');
    }
  }

  Future<void> _markItemOutOfStock(OrderItem item) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('orders').doc(_activeOrderId);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) return;

      final order = OrderModel.fromMap(docSnapshot.data()!);
      final updatedItems = order.items.map((it) {
        if (it.id == item.id) {
          return it.copyWith(
            isOutOfStock: true,
            isPacked: false,
          );
        }
        return it;
      }).toList();

      await docRef.update({
        'items': updatedItems.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _outOfStockItems[item.id] = true;
        _packedItems[item.id] = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked ${item.productName} as Out of Stock.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('[PackingTerminal] Error marking item OOS: $e');
    }
  }

  Widget _buildPackingFooter(OrderModel order) {
    final allHandled = order.items.every((item) {
      final isPacked = _packedItems[item.id] ?? false;
      final isOos = _outOfStockItems[item.id] ?? item.isOutOfStock;
      return isPacked || isOos;
    });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: allHandled ? () => _finalizePacking(order) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('READY FOR PICKUP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ),
      ),
    );
  }

  Future<void> _finalizePacking(OrderModel order) async {
    _stopTimer();

    // Save actual packing weights into Firestore
    final Map<String, double> finalWeights = {};
    for (var item in order.items) {
      if (_itemWeights.containsKey(item.id)) {
        finalWeights[item.id] = _itemWeights[item.id]!;
      }
    }
    
    await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
      'status': 'OrderStatus.packed',
      'packingTimeSeconds': _packingTimer?.elapsed.inSeconds ?? 0,
      'packedWeights': finalWeights,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order #${order.orderNumber} is ready for pickup!'), backgroundColor: AppTheme.success),
      );
      setState(() {
        _activeOrderId = null;
        _packedItems.clear();
        _itemWeights.clear();
        _outOfStockItems.clear();
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
