import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/fulfillment_provider.dart';
import '../../models/fulfillment_model.dart';
import '../../services/packing_service.dart';
import '../../utils/app_theme.dart';
import 'packing_screen.dart';

class OrderQueueScreen extends StatefulWidget {
  const OrderQueueScreen({super.key});

  @override
  State<OrderQueueScreen> createState() => _OrderQueueScreenState();
}

class _OrderQueueScreenState extends State<OrderQueueScreen> {
  final _searchController = TextEditingController();
  String _selectedSort = 'oldest_first';
  String _searchQuery = '';
  List<Map<String, dynamic>> _availableOrders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final shopId = auth.currentShop?.id ?? '';
      final branchId = auth.currentBranch?.id ?? '';

      if (shopId.isEmpty || branchId.isEmpty) return;

      // For demonstration, we'll create mock data
      _availableOrders = [
        {
          'id': 'ORD001',
          'customerName': 'Rajesh Kumar',
          'phone': '8765432109',
          'address': 'Sector 5, Delhi',
          'items': 5,
          'total': 450,
          'createdAt': DateTime.now().subtract(const Duration(minutes: 15)),
          'priority': 'high',
        },
        {
          'id': 'ORD002',
          'customerName': 'Priya Singh',
          'phone': '9876543210',
          'address': 'Sector 8, Delhi',
          'items': 3,
          'total': 280,
          'createdAt': DateTime.now().subtract(const Duration(minutes: 25)),
          'priority': 'normal',
        },
        {
          'id': 'ORD003',
          'customerName': 'Amit Patel',
          'phone': '7654321098',
          'address': 'Sector 12, Delhi',
          'items': 8,
          'total': 620,
          'createdAt': DateTime.now().subtract(const Duration(minutes: 5)),
          'priority': 'high',
        },
      ];

      _applyFilters();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading orders: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _applyFilters() {
    var filtered = _availableOrders;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (order) =>
                order['id'].toString().contains(_searchQuery) ||
                order['customerName'].toString().toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    // Apply sort
    switch (_selectedSort) {
      case 'oldest_first':
        filtered.sort((a, b) => (a['createdAt'] as DateTime).compareTo(b['createdAt'] as DateTime));
        break;
      case 'highest_value':
        filtered.sort((a, b) => (b['total'] as num).compareTo(a['total'] as num));
        break;
      case 'customer_name':
        filtered.sort(
          (a, b) => (a['customerName'] as String).compareTo(b['customerName'] as String),
        );
        break;
      case 'priority':
        final priorityOrder = {'high': 0, 'normal': 1, 'low': 2};
        filtered.sort(
          (a, b) => (priorityOrder[a['priority'] as String] ?? 999).compareTo(
            priorityOrder[b['priority'] as String] ?? 999,
          ),
        );
        break;
    }

    setState(() {
      _availableOrders = filtered;
    });
  }

  Future<void> _acceptOrder(Map<String, dynamic> order) async {
    try {
      final auth = context.read<AuthProvider>();
      final fulfillment = context.read<FulfillmentProvider>();

      final shopId = auth.currentShop?.id ?? '';
      final branchId = auth.currentBranch?.id ?? '';
      final employeeId = auth.currentUser?.uid ?? '';
      final employeeName = auth.currentUser?.name ?? 'Employee';

      if (shopId.isEmpty || employeeId.isEmpty) return;

      // Create fulfillment items from order
      final items = List<dynamic>.generate(
        order['items'] as int,
        (i) => {
          'productId': 'PROD_${i + 1}',
          'productName': 'Product ${i + 1}',
          'requiredQuantity': 1,
          'unit': 'pcs',
        },
      );

      final packingService = PackingService();
      await packingService.assignOrderToEmployee(
        order['id'] as String,
        employeeId,
        employeeName,
        shopId,
        branchId,
        items
            .map(
              (i) => FulfillmentItem(
                productId: i['productId'] as String,
                productName: i['productName'] as String,
                requiredQuantity: (i['requiredQuantity'] as num).toDouble(),
                unit: i['unit'] as String,
                createdAt: DateTime.now(),
              ),
            )
            .toList(),
      );

      // Reload assigned orders
      await fulfillment.loadAssignedOrders(employeeId, shopId, branchId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order ${order['id']} accepted'), backgroundColor: AppTheme.success),
      );

      // Navigate to packing screen
      if (mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => PackingScreen(taskId: order['id'] as String)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting order: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Queue', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and filter bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    _searchQuery = value;
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search order #, customer name',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                // Sort dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedSort,
                  onChanged: (value) {
                    if (value != null) {
                      _selectedSort = value;
                      _applyFilters();
                    }
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'oldest_first', child: Text('Oldest First')),
                    DropdownMenuItem(value: 'priority', child: Text('By Priority')),
                    DropdownMenuItem(value: 'highest_value', child: Text('Highest Value')),
                    DropdownMenuItem(value: 'customer_name', child: Text('Customer Name')),
                  ],
                ),
              ],
            ),
          ),

          // Order list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _availableOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No orders available', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _availableOrders.length,
                    itemBuilder: (context, index) {
                      final order = _availableOrders[index];
                      return _OrderQueueCard(order: order, onTap: () => _acceptOrder(order));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrderQueueCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _OrderQueueCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final createdAt = order['createdAt'] as DateTime;
    final minutesOld = DateTime.now().difference(createdAt).inMinutes;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? Colors.grey[800] : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with order ID and priority
              Row(
                children: [
                  Text(
                    'Order #${order['id'] as String}',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if ((order['priority'] as String) == 'high')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.error,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'HIGH PRIORITY',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Customer info
              Row(
                children: [
                  Icon(Icons.person, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    (order['customerName'] as String?) ?? 'Unknown',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Address
              Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (order['address'] as String?) ?? 'Unknown address',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Footer with items, price, and time
              Row(
                children: [
                  const Icon(Icons.inventory, size: 16, color: AppTheme.info),
                  const SizedBox(width: 4),
                  Text('${order['items']} items', style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  Text(
                    '₹${order['total']}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$minutesOld min ago',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
