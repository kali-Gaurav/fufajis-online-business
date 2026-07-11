import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

class IntelligentDispatcherScreen extends StatefulWidget {
  const IntelligentDispatcherScreen({Key? key}) : super(key: key);

  @override
  State<IntelligentDispatcherScreen> createState() =>
      _IntelligentDispatcherScreenState();
}

class _IntelligentDispatcherScreenState
    extends State<IntelligentDispatcherScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedAssignmentStrategy = 'auto'; // auto, nearest, rating, availability
  final List<Map<String, dynamic>> _pendingOrders = [
    {
      'id': 'order_001',
      'orderNumber': 'ORD-001001',
      'customer': 'Rajesh Kumar',
      'destination': 'North Bangalore',
      'distance': 5.2,
      'items': 12,
      'weight': 3.5,
      'paymentMethod': 'Card',
      'status': 'ready_for_dispatch',
      'priority': 'high',
      'createdAt': DateTime(2026, 7, 11, 10, 0),
      'slaTime': DateTime(2026, 7, 11, 12, 0),
    },
    {
      'id': 'order_002',
      'orderNumber': 'ORD-001002',
      'customer': 'Priya Singh',
      'destination': 'East Bangalore',
      'distance': 8.1,
      'items': 8,
      'weight': 2.1,
      'paymentMethod': 'Wallet',
      'status': 'ready_for_dispatch',
      'priority': 'medium',
      'createdAt': DateTime(2026, 7, 11, 10, 15),
      'slaTime': DateTime(2026, 7, 11, 13, 0),
    },
    {
      'id': 'order_003',
      'orderNumber': 'ORD-001003',
      'customer': 'Amit Patel',
      'destination': 'West Bangalore',
      'distance': 6.5,
      'items': 5,
      'weight': 1.8,
      'paymentMethod': 'Card',
      'status': 'ready_for_dispatch',
      'priority': 'low',
      'createdAt': DateTime(2026, 7, 11, 10, 30),
      'slaTime': DateTime(2026, 7, 11, 14, 0),
    },
  ];

  final List<Map<String, dynamic>> _availableRiders = [
    {
      'id': 'rider_001',
      'name': 'Ramesh Kumar',
      'rating': 4.8,
      'currentLocation': 'Central Hub',
      'distance': 3.2,
      'status': 'available',
      'deliveriesInBatch': 0,
      'capacity': 5,
      'efficiency': 95,
      'onTimePercentage': 98,
    },
    {
      'id': 'rider_002',
      'name': 'Priya Sharma',
      'rating': 4.6,
      'currentLocation': 'North Area',
      'distance': 4.1,
      'status': 'available',
      'deliveriesInBatch': 0,
      'capacity': 4,
      'efficiency': 88,
      'onTimePercentage': 92,
    },
    {
      'id': 'rider_003',
      'name': 'Karthik Reddy',
      'rating': 4.4,
      'currentLocation': 'East Area',
      'distance': 5.5,
      'status': 'busy',
      'deliveriesInBatch': 3,
      'capacity': 5,
      'efficiency': 82,
      'onTimePercentage': 87,
    },
  ];

  final List<Map<String, dynamic>> _activeAssignments = [
    {
      'id': 'assign_001',
      'orderId': 'order_101',
      'riderId': 'rider_001',
      'riderName': 'Ramesh Kumar',
      'status': 'in_transit',
      'assignedAt': DateTime(2026, 7, 11, 9, 0),
      'estimatedDelivery': DateTime(2026, 7, 11, 11, 30),
      'deliveriesInBatch': 2,
      'progress': 0.4,
    },
    {
      'id': 'assign_002',
      'orderId': 'order_102',
      'riderId': 'rider_002',
      'riderName': 'Priya Sharma',
      'status': 'picking_up',
      'assignedAt': DateTime(2026, 7, 11, 9, 30),
      'estimatedDelivery': DateTime(2026, 7, 11, 12, 0),
      'deliveriesInBatch': 1,
      'progress': 0.15,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text(
          'Intelligent Dispatcher',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Auto Assign All'),
                onTap: () {},
              ),
              PopupMenuItem(
                child: const Text('Batch Delivery'),
                onTap: () {},
              ),
              PopupMenuItem(
                child: const Text('SLA Settings'),
                onTap: () {},
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.grey600,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Available Riders'),
            Tab(text: 'Active Assignments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingOrdersTab(),
          _buildAvailableRidersTab(),
          _buildActiveAssignmentsTab(),
        ],
      ),
    );
  }

  Widget _buildPendingOrdersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDispatcherStats(),
          const SizedBox(height: 20),
          _buildAssignmentStrategySelector(),
          const SizedBox(height: 20),
          const Text(
            'Orders Ready for Dispatch',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._pendingOrders.map((order) => _buildPendingOrderCard(order)).toList(),
        ],
      ),
    );
  }

  Widget _buildDispatcherStats() {
    final pending = _pendingOrders.length;
    final highPriority = _pendingOrders.where((o) => o['priority'] == 'high').length;
    final avgDistance =
        _pendingOrders.fold<double>(0, (sum, o) => sum + (o['distance'] as double)) /
            _pendingOrders.length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Pending Orders',
            value: pending.toString(),
            icon: Icons.pending_actions,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'High Priority',
            value: highPriority.toString(),
            icon: Icons.priority_high,
            color: AppTheme.error,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Avg Distance',
            value: avgDistance.toStringAsFixed(1),
            icon: Icons.distance,
            color: Colors.purple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Available Riders',
            value: '2',
            icon: Icons.two_wheeler,
            color: AppTheme.success,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.grey500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentStrategySelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assignment Strategy',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStrategyButton('auto', 'Auto Assign',
                      Icons.auto_awesome, AppTheme.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStrategyButton('nearest', 'Nearest Rider',
                      Icons.location_on, Colors.orange),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStrategyButton('rating', 'Top Rated',
                      Icons.star, Colors.amber),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStrategyButton('availability', 'Available',
                      Icons.check_circle, AppTheme.success),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyButton(
    String strategy,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedAssignmentStrategy == strategy;

    return GestureDetector(
      onTap: () => setState(() => _selectedAssignmentStrategy = strategy),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppTheme.grey200,
          border: Border.all(
            color: isSelected ? color : AppTheme.grey300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : AppTheme.grey600),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : AppTheme.grey600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingOrderCard(Map<String, dynamic> order) {
    final timeUntilSLA = order['slaTime'].difference(DateTime.now()).inMinutes;
    final isSLAAtRisk = timeUntilSLA < 30;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order['orderNumber'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order['customer'],
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: order['priority'] == 'high'
                        ? AppTheme.error.withValues(alpha: 0.1)
                        : (order['priority'] == 'medium'
                            ? Colors.orange.withValues(alpha: 0.1)
                            : AppTheme.grey200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    order['priority'].toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: order['priority'] == 'high'
                          ? AppTheme.error
                          : (order['priority'] == 'medium'
                              ? Colors.orange
                              : AppTheme.grey600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Destination',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order['destination'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Distance',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${order['distance']} km',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Items',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order['items'].toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSLAAtRisk ? AppTheme.error.withValues(alpha: 0.05) : AppTheme.grey50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 14,
                        color: isSLAAtRisk ? AppTheme.error : AppTheme.grey600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'SLA: ${DateFormat('HH:mm').format(order['slaTime'])}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSLAAtRisk ? AppTheme.error : AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                  if (isSLAAtRisk)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.error,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text(
                        'AT RISK',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text('Auto Assign', style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text('Manual', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableRidersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Riders',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._availableRiders.map((rider) => _buildRiderSelectionCard(rider)).toList(),
        ],
      ),
    );
  }

  Widget _buildRiderSelectionCard(Map<String, dynamic> rider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rider['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rider['currentLocation'],
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: rider['status'] == 'available'
                        ? AppTheme.success.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    rider['status'].replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: rider['status'] == 'available'
                          ? AppTheme.success
                          : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rating',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 12, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '${rider['rating']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Efficiency',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${rider['efficiency']}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'On Time %',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${rider['onTimePercentage']}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Capacity: ${rider['deliveriesInBatch']}/${rider['capacity']}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rider['deliveriesInBatch'] / rider['capacity'],
                    minHeight: 4,
                    backgroundColor: AppTheme.grey200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      (rider['deliveriesInBatch'] / rider['capacity']) > 0.8
                          ? AppTheme.error
                          : AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAssignmentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Assignments',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._activeAssignments.map((assignment) => _buildAssignmentCard(assignment)).toList(),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment['riderName'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        assignment['orderId'],
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: assignment['status'] == 'in_transit'
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    assignment['status'].replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: assignment['status'] == 'in_transit'
                          ? Colors.blue
                          : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Progress',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.grey600,
                  ),
                ),
                Text(
                  '${(assignment['progress'] * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: assignment['progress'],
                minHeight: 6,
                backgroundColor: AppTheme.grey200,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assigned',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('HH:mm').format(assignment['assignedAt']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ETA',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('HH:mm').format(assignment['estimatedDelivery']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'In Batch',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${assignment['deliveriesInBatch']} deliveries',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
