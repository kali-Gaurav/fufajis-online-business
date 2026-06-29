/// Example integration of OfflineOrderQueueService into Fufaji Store screens
/// This file demonstrates how to use the offline queue in various screens
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/offline_order_queue_service.dart';
import '../providers/order_provider.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import '../widgets/offline_queue_status_widget.dart';
import '../utils/monetary_value.dart';

/// Example 1: CheckoutScreen Integration
class CheckoutScreenExample extends StatefulWidget {
  const CheckoutScreenExample({super.key});

  @override
  State<CheckoutScreenExample> createState() => _CheckoutScreenExampleState();
}

class _CheckoutScreenExampleState extends State<CheckoutScreenExample> {
  final bool _isOnline = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Show warning if offline
            if (!_isOnline) const OfflineCheckoutWarning(),

            // Order summary
            _buildOrderSummary(),

            // Checkout button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Consumer<OrderProvider>(
                builder: (context, orderProvider, _) {
                  return ElevatedButton(
                    onPressed: () => _handleCheckout(context),
                    child: Text(_isOnline ? 'Place Order' : 'Place Order (Will Sync)'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('Subtotal:'), Text('₹500')],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('Delivery:'), Text('₹50')],
          ),
          Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('Total:'), Text('₹550', style: TextStyle(fontWeight: FontWeight.bold))],
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckout(BuildContext context) async {
    final orderProvider = context.read<OrderProvider>();

    // Create mock order
    final order = OrderModel(
      id: 'ORD_${DateTime.now().millisecondsSinceEpoch}',
      orderNumber: '${DateTime.now().millisecondsSinceEpoch}',
      customerId: 'cust_001',
      customerName: 'John Doe',
      customerPhone: '9999999999',
      items: const [],
      subtotal: MonetaryValue(500),
      totalAmount: MonetaryValue(550),
      deliveryAddress: Address(
        id: 'addr_1',
        label: 'Home',
        fullAddress: '123 Main St, New Delhi',
        pincode: '110001',
        latitude: 28.6139,
        longitude: 77.2090,
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Place order (will queue if offline)
    final result = await orderProvider.createOrder(order);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order ${result.orderNumber} placed successfully!')),
      );
      Navigator.pop(context);
    }
  }
}

/// Example 2: HomeScreen with Queue Status Banner
class HomeScreenExample extends StatelessWidget {
  const HomeScreenExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Column(
        children: [
          // Queue status banner at top
          OfflineQueueStatusWidget(
            showDetails: true,
            onRetryTap: () => _handleRetry(context),
          ),

          // Main content
          Expanded(
            child: ListView(
              children: [
                _buildProductCard('Product 1', '₹199'),
                _buildProductCard('Product 2', '₹299'),
                _buildProductCard('Product 3', '₹399'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(String name, String price) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(price, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
            ElevatedButton(onPressed: () {}, child: const Text('Add to Cart')),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRetry(BuildContext context) async {
    final queueService = OfflineOrderQueueService();
    await queueService.syncQueuedOrders();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Syncing orders...')),
    );
  }
}

/// Example 3: OrdersScreen with Status Badge
class OrdersScreenExample extends StatelessWidget {
  const OrdersScreenExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Stack(
          children: [
            Text('My Orders'),
            OfflineOrderBadge(),
          ],
        ),
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, _) {
          return Column(
            children: [
              // Show sync status
              if (orderProvider.queuedOrderCount > 0)
                Container(
                  color: AppTheme.info,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: AppTheme.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${orderProvider.queuedOrderCount} orders pending sync',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showQueueStatus(context),
                        child: const Text('Details'),
                      ),
                    ],
                  ),
                ),

              // Orders list
              Expanded(
                child: ListView.builder(
                  itemCount: orderProvider.orders.length,
                  itemBuilder: (context, index) {
                    final order = orderProvider.orders[index];
                    return _buildOrderTile(order, context);
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _manualSync(context),
        child: const Icon(Icons.sync),
      ),
    );
  }

  Widget _buildOrderTile(OrderModel order, BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text('Order #${order.orderNumber}'),
        subtitle: Text('₹${order.totalAmount.toStringAsFixed(2)}'),
        trailing: Chip(
          label: Text(order.status.displayName),
          backgroundColor: order.status.color.withValues(alpha: 0.2),
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order details: ${order.id}')),
          );
        },
      ),
    );
  }

  Future<void> _showQueueStatus(BuildContext context) async {
    final queueService = OfflineOrderQueueService();
    showDialog(
      context: context,
      builder: (_) => QueueStatusDialog(queueService: queueService),
    );
  }

  Future<void> _manualSync(BuildContext context) async {
    final orderProvider = context.read<OrderProvider>();
    await orderProvider.syncOfflineOrders();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sync triggered')),
    );
  }
}

/// Example 4: Settings Screen with Queue Management
class SettingsScreenExample extends StatelessWidget {
  const SettingsScreenExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Offline Orders'),
            onTap: () => _showQueueManager(context),
          ),
          ListTile(
            title: const Text('Clear Queue'),
            subtitle: const Text('Delete all offline orders'),
            onTap: () => _showClearConfirmation(context),
          ),
          ListTile(
            title: const Text('Sync Now'),
            onTap: () => _triggerSync(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showQueueManager(BuildContext context) async {
    final queueService = OfflineOrderQueueService();
    final stats = await queueService.getQueueStats();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Queue Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Queued: ${stats.queuedCount}'),
            Text('Failed: ${stats.failedCount}'),
            Text('Synced: ${stats.syncedCount}'),
            Text('Size: ${(stats.totalSize / 1024).toStringAsFixed(2)} KB'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showClearConfirmation(BuildContext context) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Queue?'),
        content: const Text('This will delete all offline orders. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final queueService = OfflineOrderQueueService();
              await queueService.clearQueue();
              Navigator.pop(_);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Queue cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerSync(BuildContext context) async {
    final orderProvider = context.read<OrderProvider>();
    await orderProvider.syncOfflineOrders();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sync triggered')),
    );
  }
}

/// Example 5: Dio Interceptor for Queue Monitoring
class OrderQueueInterceptor {
  final OfflineOrderQueueService _queueService = OfflineOrderQueueService();

  /// Log all orders entering queue
  Future<void> logQueuedOrder(OrderModel order) async {
    debugPrint('[OrderQueue] Order ${order.id} queued at ${DateTime.now()}');
  }

  /// Monitor sync progress
  Future<void> monitorSync() async {
    final stats = await _queueService.getQueueStats();
    debugPrint('[OrderQueue] Sync Status: $stats');
  }

  /// Auto-cleanup on app start
  Future<void> initializeCleanup() async {
    await _queueService.cleanupOldSyncedOrders();
  }
}

/// Example 6: ProviderBinding for DI
class OrderQueueBinding {
  static Future<void> initialize() async {
    final queueService = OfflineOrderQueueService();
    await queueService.init();

    // Set up listeners
    queueService.isSyncing.addListener(() {
      debugPrint('[Queue] Syncing: ${queueService.isSyncing.value}');
    });

    queueService.queuedCount.addListener(() {
      debugPrint('[Queue] Pending: ${queueService.queuedCount.value}');
    });

    queueService.lastSyncError.addListener(() {
      if (queueService.lastSyncError.value != null) {
        debugPrint('[Queue] Error: ${queueService.lastSyncError.value}');
      }
    });
  }
}

// Usage in main.dart:
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await OrderQueueBinding.initialize();
//   runApp(const MyApp());
// }
