import 'package:flutter/material.dart';
import '../../services/partial_fulfillment_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/replacement_service.dart';
import '../../services/whatsapp_notification_service.dart';
import '../../services/order_service.dart';
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
  bool _isLoading = false;

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
          _elapsedTime =
              '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
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
        title: const Text(
          'Order Fulfillment Terminal',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.grey900,
        foregroundColor: Colors.white,
        actions: [
          if (_activeOrderId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  'Timer: $_elapsedTime',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent))
          : Row(
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
                        child: Text(
                          'PENDING QUEUE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: AppTheme.grey600,
                          ),
                        ),
                      ),
                      Expanded(child: _buildOrderQueue()),
                    ],
                  ),
                ),

                // Right: Item Check-off / Review
                Expanded(
                  child: _activeOrderId == null ? _buildTerminalIdleState() : _buildItemChecklist(),
                ),
              ],
            ),
    );
  }

  Widget _buildTerminalIdleState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: AppTheme.grey300),
          SizedBox(height: 16),
          Text(
            'Select an order from the queue to start packing',
            style: TextStyle(color: AppTheme.grey500),
          ),
        ],
      ),
    );
  }

  Widget _buildPackingStatusBadge(String? status) {
    Color color;
    String text;
    switch (status) {
      case 'pending_approval':
        color = AppTheme.warning;
        text = 'Awaiting Review';
        break;
      case 'rejected':
        color = AppTheme.error;
        text = 'Rejected';
        break;
      case 'packing':
        color = AppTheme.ownerAccent;
        text = 'Packing';
        break;
      case 'approved':
        color = AppTheme.success;
        text = 'Approved';
        break;
      default:
        color = Colors.grey;
        text = 'Not Started';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
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
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
        final docs = snapshot.data!.docs;

        if (docs.isEmpty)
          return const Center(
            child: Text('No orders in preparation', style: TextStyle(fontSize: 12)),
          );

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
                child: Text(
                  '${order.items.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey800,
                  ),
                ),
              ),
              title: Text(
                '#${order.orderNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${order.totalAmount.toDouble().round()} • ${_formatDate(order.createdAt)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  _buildPackingStatusBadge(order.packingStatus),
                ],
              ),
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
        if (!snapshot.hasData || !snapshot.data!.exists)
          return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
        final order = OrderModel.fromMap(snapshot.data!.data() as Map<String, dynamic>);

        if (order.packingStatus == 'pending_approval') {
          return _buildReviewPanel(order);
        }

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
              Text(
                'Packing: #${order.orderNumber}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              Text(
                'Customer: ${order.customerName}',
                style: const TextStyle(color: AppTheme.grey600),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Handled', style: TextStyle(fontSize: 12, color: AppTheme.grey500)),
              Text(
                '$handledCount / ${order.items.length}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPackingItemTile(OrderItem item, ProductProvider productProvider) {
    final isPacked = _packedItems[item.id] ?? false;
    final isOos = _outOfStockItems[item.id] ?? item.isOutOfStock;

    final bool isWeightUnit =
        item.unit.toLowerCase().contains('kg') ||
        item.unit.toLowerCase().contains('g') ||
        item.unit.toLowerCase().contains('kilo') ||
        item.unit.toLowerCase().contains('gm');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isOos
            ? AppTheme.error.withValues(alpha: 0.05)
            : isPacked
            ? AppTheme.success.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOos
              ? AppTheme.error.withValues(alpha: 0.3)
              : isPacked
              ? AppTheme.success.withValues(alpha: 0.3)
              : AppTheme.grey200,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: AppTheme.grey100,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(imageUrl: item.productImage, fit: BoxFit.cover),
          ),
        ),
        title: Text(
          item.productName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isOos ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Qty: ${item.quantity} ${item.unit}',
              style: TextStyle(
                color: isOos ? AppTheme.error : AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isWeightUnit && !isOos) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Actual Wt: ',
                    style: TextStyle(fontSize: 12, color: AppTheme.grey600),
                  ),
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
              const Text(
                'OUT OF STOCK',
                style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold, fontSize: 11),
              )
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

    final replacements = ReplacementService().suggestReplacements(
      originalProduct,
      provider.products,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Item Missing / Replace', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sorry, ${item.productName} is out of stock.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Suggested Replacements:',
              style: TextStyle(fontSize: 12, color: AppTheme.grey600),
            ),
            const SizedBox(height: 8),
            if (replacements.isEmpty)
              const Text(
                'No replacements found in matching category.',
                style: TextStyle(fontStyle: FontStyle.italic),
              )
            else
              ...replacements.map(
                (p) => ListTile(
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
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _markItemOutOfStock(item);
            },
            child: const Text('Mark OOS (No Replace)', style: TextStyle(color: AppTheme.error)),
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

      final newSubtotal = updatedItems.fold(0.0, (total, it) => total + it.totalPrice.toDouble());
      final newTotal = newSubtotal + order.deliveryCharge.toDouble() - order.discount.toDouble();

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
          replacementPrice: newProduct.price.toDouble(),
        );
      }

      setState(() {
        _packedItems[oldItem.id] = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Replaced ${oldItem.productName} with ${newProduct.name}. Customer notified!',
            ),
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
          return it.copyWith(isOutOfStock: true, isPacked: false);
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
            backgroundColor: AppTheme.warning,
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
            backgroundColor: AppTheme.info,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text(
            'READY FOR PICKUP',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
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
        SnackBar(
          content: Text('Order #${order.orderNumber} is ready for pickup!'),
          backgroundColor: AppTheme.success,
        ),
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

  Widget _buildReviewPanel(OrderModel order) {
    final proof = order.packingProof;
    final photoUrl = proof?['photoUrl'] as String?;
    final packedBy = proof?['packedBy'] as String? ?? 'Employee';
    final packedAt = proof?['packedAt'] != null
        ? (proof!['packedAt'] is Timestamp
              ? (proof['packedAt'] as Timestamp).toDate()
              : DateTime.tryParse(proof['packedAt'].toString()))
        : null;

    final formattedPackedAt = packedAt != null ? DateFormat('hh:mm a').format(packedAt) : 'N/A';

    final startedAt = order.packingStartedAt;
    final completedAt = order.packingCompletedAt;
    final duration = startedAt != null && completedAt != null
        ? completedAt.difference(startedAt)
        : null;
    final durationStr = duration != null
        ? '${duration.inMinutes}m ${duration.inSeconds % 60}s'
        : '';

    return Column(
      children: [
        // Review Header
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review Packing: #${order.orderNumber}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Packed by: $packedBy at $formattedPackedAt',
                    style: const TextStyle(color: AppTheme.grey600),
                  ),
                  if (durationStr.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Time spent: $durationStr',
                      style: const TextStyle(
                        color: AppTheme.grey600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warning, width: 1.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.rate_review, color: AppTheme.warning, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'AWAITING APPROVAL',
                      style: TextStyle(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Scrollable content area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column: Checklist & weights
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PACKED ITEMS CHECKLIST',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: AppTheme.grey600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...order.items.map((item) {
                        final isWeightUnit =
                            item.unit.toLowerCase().contains('kg') ||
                            item.unit.toLowerCase().contains('g') ||
                            item.unit.toLowerCase().contains('kilo') ||
                            item.unit.toLowerCase().contains('gm');
                        final hasCustomWeight =
                            order.toMap()['packedWeights'] != null &&
                            (order.toMap()['packedWeights'] as Map).containsKey(item.id);
                        final packedWeight = hasCustomWeight
                            ? (order.toMap()['packedWeights'] as Map)[item.id]
                            : null;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: item.isOutOfStock
                                ? AppTheme.error.withValues(alpha: 0.05)
                                : AppTheme.success.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: item.isOutOfStock
                                  ? AppTheme.error.withValues(alpha: 0.2)
                                  : AppTheme.success.withValues(alpha: 0.2),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              item.productName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: item.isOutOfStock ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Qty: ${item.quantity} ${item.unit}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if (isWeightUnit && packedWeight != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Verified Weight: $packedWeight kg',
                                    style: const TextStyle(
                                      color: AppTheme.success,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: item.isOutOfStock
                                ? const Text(
                                    'OUT OF STOCK',
                                    style: TextStyle(
                                      color: AppTheme.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  )
                                : const Icon(Icons.check_circle, color: AppTheme.success),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Right column: Photo proof
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PACKING PHOTO PROOF',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: AppTheme.grey600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (photoUrl != null && photoUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: GestureDetector(
                            onTap: () => _showFullPhotoDialog(context, photoUrl),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: photoUrl,
                                  height: 300,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const SizedBox(
                                    height: 300,
                                    child: Center(
                                      child: CircularProgressIndicator(color: AppTheme.ownerAccent),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                ),
                                Positioned(
                                  bottom: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.zoom_in, color: Colors.white, size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          'Tap to Enlarge',
                                          style: TextStyle(color: Colors.white, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text(
                                  'No photo proof submitted',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Review Actions Footer
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectionDialog(order),
                    icon: const Icon(Icons.cancel, color: AppTheme.error),
                    label: const Text(
                      'REJECT PACKING',
                      style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.error, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _showPartialFulfillmentDialog(order),
                    icon: const Icon(Icons.incomplete_circle, color: AppTheme.warning),
                    label: const Text(
                      'PARTIAL',
                      style: TextStyle(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.warning, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _approvePacking(order),
                    icon: const Icon(Icons.check_circle),
                    label: const Text(
                      'APPROVE & SHIP',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showFullPhotoDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectionDialog(OrderModel order) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Reject Packing Submission',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide the reason for rejecting this packing job:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText:
                    'e.g. Missing Item: Britannia Rusk, photo proof shows incorrect packaging...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final reason = controller.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Please enter a rejection reason')));
                return;
              }
              Navigator.pop(ctx);
              await _rejectPacking(order, reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  Future<void> _approvePacking(OrderModel order) async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final ownerId = authProvider.currentUser?.uid ?? 'owner';
      final ownerName = authProvider.currentUser?.name ?? 'Owner';

      await OrderService().approvePacking(order.id, ownerId, ownerName);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order #${order.orderNumber} approved and marked packed!'),
          backgroundColor: AppTheme.success,
        ),
      );
      setState(() {
        _activeOrderId = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve order: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _rejectPacking(OrderModel order, String reason) async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final ownerId = authProvider.currentUser?.uid ?? 'owner';
      final ownerName = authProvider.currentUser?.name ?? 'Owner';

      await OrderService().rejectPacking(order.id, ownerId, ownerName, reason);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order #${order.orderNumber} packing rejected. Sent back to packer.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      setState(() {
        _activeOrderId = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject order: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _showPartialFulfillmentDialog(OrderModel order) {
    final List<String> unavailableItemIds = [];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Partial Fulfillment', style: TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select unavailable items:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...order.items.map((item) {
                  final isChecked = unavailableItemIds.contains(item.id);
                  return CheckboxListTile(
                    dense: true,
                    title: Text(item.productName, style: const TextStyle(fontSize: 13)),
                    subtitle: Text('Qty: ${item.quantity}', style: const TextStyle(fontSize: 11)),
                    value: isChecked,
                    onChanged: (v) {
                      setDialogState(() {
                        if (v == true) {
                          unavailableItemIds.add(item.id);
                        } else {
                          unavailableItemIds.remove(item.id);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
              onPressed: unavailableItemIds.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      try {
                        final result = await PartialFulfillmentService.instance
                            .processPartialFulfillment(
                              orderId: order.id,
                              unavailableProductIds: unavailableItemIds,
                              performedBy: 'owner',
                            );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result.success
                                    ? 'Partial fulfillment applied. Customer notified.'
                                    : 'Error: ${result.error}',
                              ),
                              backgroundColor: result.success ? AppTheme.warning : AppTheme.error,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error: \$e'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Apply Partial', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
