/**
 * Packing Terminal Screen (v2)
 *
 * CRITICAL CHANGE: Uses backend API instead of direct Firestore writes
 *
 * Before (DANGEROUS):
 * await firestore.collection('orders').doc(order.id).update({...})
 * → No inventory locks
 * → No transaction safety
 * → Can double-pack
 *
 * After (SAFE):
 * await api.post('/admin/orders/$orderId/pack', {...})
 * → PostgreSQL atomic transactions
 * → Row-level locks
 * → Inventory validated + consumed
 * → Impossible to double-pack
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/admin_provider_v2.dart';
import '../../services/admin_api_service.dart';
import '../../models/order_model.dart';

class PackingTerminalScreenV2 extends StatefulWidget {
  final String orderId;

  const PackingTerminalScreenV2({required this.orderId});

  @override
  State<PackingTerminalScreenV2> createState() => _PackingTerminalScreenV2State();
}

class _PackingTerminalScreenV2State extends State<PackingTerminalScreenV2> {
  OrderModel? order;
  bool isLoading = false;
  String? errorMessage;
  Map<String, int> packedItems = {}; // product_id → quantity packed
  Stopwatch? _packingTimer;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  /// Load order from provider
  Future<void> _loadOrder() async {
    try {
      setState(() => isLoading = true);

      final provider = context.read<AdminProvider>();
      await provider.loadOrders(status: 'confirmed');

      final orders = provider.orders;
      final found = orders.firstWhere((o) => o.id == widget.orderId);

      setState(() {
        order = found;
        isLoading = false;
      });

      _startPackingTimer();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load order: $e';
        isLoading = false;
      });
    }
  }

  /// Start timer for packing duration
  void _startPackingTimer() {
    _packingTimer = Stopwatch()..start();
  }

  /// Pack order (via backend API, not Firestore)
  ///
  /// CRITICAL: This now goes through the backend, ensuring:
  /// 1. PostgreSQL transaction locks
  /// 2. Inventory validation + consumption
  /// 3. Atomic operation (all-or-nothing)
  /// 4. Impossible to double-pack
  Future<void> _packOrder() async {
    final currentOrder = order;
    if (currentOrder == null) return;
    try {
      setState(() => isLoading = true);
      errorMessage = null;

      // Validate that all items have been packed
      bool allPacked = true;
      for (final item in currentOrder.items) {
        if ((packedItems[item.productId] ?? 0) < item.quantity) {
          allPacked = false;
          break;
        }
      }

      if (!allPacked) {
        throw Exception('All items must be packed before submitting');
      }

      // Get current employee ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final employeeId = currentUser.uid;
      final packingDuration = _packingTimer?.elapsedMilliseconds ?? 0;

      // Prepare items for API call
      final itemsToPack = currentOrder.items
          .map((item) => {
                'productId': item.productId,
                'quantity': item.quantity,
              })
          .toList();

      // CRITICAL: Call backend API instead of Firestore
      // This ensures atomic transaction + inventory validation
      final apiService = AdminApiService();
      await apiService.packOrder(widget.orderId, itemsToPack, employeeId);

      // Success! Order packed
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order ${widget.orderId} packed successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Log analytics
      _logPackingAnalytics(
        orderId: widget.orderId,
        itemCount: currentOrder.items.length,
        packingDurationMs: packingDuration,
        employeeId: employeeId,
        success: true,
      );

      // Navigate back
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to pack order: $e';
        isLoading = false;
      });

      // Log error analytics
      _logPackingAnalytics(
        orderId: widget.orderId,
        itemCount: currentOrder.items.length,
        packingDurationMs: _packingTimer?.elapsedMilliseconds ?? 0,
        employeeId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        success: false,
        error: e.toString(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Log packing activity to analytics
  void _logPackingAnalytics({
    required String orderId,
    required int itemCount,
    required int packingDurationMs,
    required String employeeId,
    required bool success,
    String? error,
  }) {
    // Send to analytics service
    // Example: Firebase Analytics, Sentry, custom dashboard
    print('''
    [PACKING_ANALYTICS]
    orderId: $orderId
    itemCount: $itemCount
    durationSeconds: ${packingDurationMs / 1000}
    employeeId: $employeeId
    success: $success
    error: $error
    timestamp: ${DateTime.now().toIso8601String()}
    ''');
  }

  /// Cancel packing (return to order list)
  void _cancelPacking() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Packing?'),
        content: const Text('This will discard your packing progress.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Packing'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Toggle item as packed/unpacked
  void _toggleItemPacked(String productId, int maxQuantity) {
    setState(() {
      final current = packedItems[productId] ?? 0;
      if (current < maxQuantity) {
        packedItems[productId] = current + 1;
      } else {
        packedItems.remove(productId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentOrder = order;
    if (isLoading && currentOrder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Packing Terminal')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (currentOrder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Packing Terminal')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Order not found or could not be loaded.'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadOrder, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Packing Order ${widget.orderId}'),
        automaticallyImplyLeading: false,
        actions: [
          if (_packingTimer != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: StreamBuilder<int>(
                  stream: Stream.periodic(
                    const Duration(seconds: 1),
                    (_) => _packingTimer!.elapsedMilliseconds,
                  ),
                  builder: (context, snapshot) {
                    final seconds = (snapshot.data ?? 0) ~/ 1000;
                    final minutes = seconds ~/ 60;
                    final secs = seconds % 60;
                    return Text(
                      '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error message
              if (errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                ),

              // Order summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order ID: ${currentOrder.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Items: ${currentOrder.items.length}'),
                      Text('Total: ₹${currentOrder.totalAmount / 100}'),
                      Text('Status: ${currentOrder.status}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Items to pack
              const Text(
                'Items to Pack',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...currentOrder.items.map((item) {
                final packed = packedItems[item.productId] ?? 0;
                final progress = packed / item.quantity;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.productName} (₹${item.price / 100})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 8,
                                  ),
                                  const SizedBox(height: 4),
                                  Text('$packed / ${item.quantity} packed'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 48,
                              child: ElevatedButton(
                                onPressed: () => _toggleItemPacked(item.productId, item.quantity),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: progress >= 1.0 ? Colors.green : Colors.blue,
                                  padding: EdgeInsets.zero,
                                ),
                                child: Icon(
                                  progress >= 1.0 ? Icons.check : Icons.add,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),

              const SizedBox(height: 24),

              // Pack/Cancel buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : _packOrder,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('PACK ORDER'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : _cancelPacking,
                      icon: const Icon(Icons.close),
                      label: const Text('CANCEL'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to use:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Pick items from the shelf'),
                    Text('2. Tap "+" to mark each item as packed'),
                    Text('3. When all items are packed, tap "PACK ORDER"'),
                    Text('4. The system will verify inventory automatically'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _packingTimer?.stop();
    super.dispose();
  }
}
