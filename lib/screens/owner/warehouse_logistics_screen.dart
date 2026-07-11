import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

class WarehouseLogisticsScreen extends StatefulWidget {
  const WarehouseLogisticsScreen({Key? key}) : super(key: key);

  @override
  State<WarehouseLogisticsScreen> createState() =>
      _WarehouseLogisticsScreenState();
}

class _WarehouseLogisticsScreenState
    extends State<WarehouseLogisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedView = 'realtime';
  final List<Map<String, dynamic>> _zones = [
    {
      'id': 'zone_001',
      'name': 'Zone A - Produce',
      'capacity': 1000,
      'occupied': 720,
      'items': 156,
      'status': 'optimal',
      'temperature': 12,
      'humidity': 65,
      'lastAudit': DateTime(2026, 7, 11, 10, 30),
    },
    {
      'id': 'zone_002',
      'name': 'Zone B - Dairy',
      'capacity': 800,
      'occupied': 680,
      'items': 124,
      'status': 'optimal',
      'temperature': 4,
      'humidity': 50,
      'lastAudit': DateTime(2026, 7, 11, 11, 0),
    },
    {
      'id': 'zone_003',
      'name': 'Zone C - Dry Goods',
      'capacity': 1200,
      'occupied': 1080,
      'items': 234,
      'status': 'warning',
      'temperature': 22,
      'humidity': 45,
      'lastAudit': DateTime(2026, 7, 11, 9, 15),
    },
  ];

  final List<Map<String, dynamic>> _shipments = [
    {
      'id': 'ship_001',
      'orderCount': 12,
      'itemCount': 45,
      'destination': 'North Bangalore',
      'status': 'packed',
      'estimatedDeparture': DateTime(2026, 7, 11, 15, 0),
      'driver': 'Rajesh Kumar',
      'vehicle': 'KA-01-AB-1234',
      'weight': 245,
    },
    {
      'id': 'ship_002',
      'orderCount': 8,
      'itemCount': 32,
      'destination': 'East Bangalore',
      'status': 'in_transit',
      'estimatedDeparture': DateTime(2026, 7, 11, 13, 0),
      'driver': 'Priya Singh',
      'vehicle': 'KA-01-CD-5678',
      'weight': 180,
    },
    {
      'id': 'ship_003',
      'orderCount': 15,
      'itemCount': 58,
      'destination': 'West Bangalore',
      'status': 'delivered',
      'estimatedDeparture': DateTime(2026, 7, 11, 10, 0),
      'driver': 'Amit Patel',
      'vehicle': 'KA-01-EF-9012',
      'weight': 310,
    },
  ];

  final List<Map<String, dynamic>> _pickPackOperations = [
    {
      'id': 'op_001',
      'orderId': 'ORD-001234',
      'status': 'picking',
      'items': 5,
      'pickedItems': 3,
      'employee': 'Rajesh Kumar',
      'startTime': DateTime(2026, 7, 11, 9, 30),
      'estimatedCompletion': DateTime(2026, 7, 11, 10, 15),
    },
    {
      'id': 'op_002',
      'orderId': 'ORD-001235',
      'status': 'packing',
      'items': 3,
      'pickedItems': 3,
      'employee': 'Priya Singh',
      'startTime': DateTime(2026, 7, 11, 9, 0),
      'estimatedCompletion': DateTime(2026, 7, 11, 10, 0),
    },
    {
      'id': 'op_003',
      'orderId': 'ORD-001236',
      'status': 'quality_check',
      'items': 4,
      'pickedItems': 4,
      'employee': 'Amit Patel',
      'startTime': DateTime(2026, 7, 11, 8, 45),
      'estimatedCompletion': DateTime(2026, 7, 11, 9, 45),
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
          'Warehouse & Logistics',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Real-time View'),
                onTap: () => setState(() => _selectedView = 'realtime'),
              ),
              PopupMenuItem(
                child: const Text('Zone Map'),
                onTap: () => setState(() => _selectedView = 'map'),
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
            Tab(text: 'Zones'),
            Tab(text: 'Shipments'),
            Tab(text: 'Operations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildZonesTab(),
          _buildShipmentsTab(),
          _buildOperationsTab(),
        ],
      ),
    );
  }

  Widget _buildZonesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWarehouseStats(),
          const SizedBox(height: 20),
          const Text(
            'Storage Zones',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._zones.map((zone) => _buildZoneCard(zone)).toList(),
        ],
      ),
    );
  }

  Widget _buildWarehouseStats() {
    final totalCapacity =
        _zones.fold<int>(0, (sum, z) => sum + (z['capacity'] as int));
    final totalOccupied =
        _zones.fold<int>(0, (sum, z) => sum + (z['occupied'] as int));
    final occupancyRate = (totalOccupied / totalCapacity * 100).toStringAsFixed(1);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Total Capacity',
            value: '${(totalCapacity / 1000).toStringAsFixed(1)}K',
            icon: Icons.storage,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Occupied',
            value: '${(totalOccupied / 1000).toStringAsFixed(1)}K',
            icon: Icons.inventory_2,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Occupancy',
            value: '$occupancyRate%',
            icon: Icons.trending_up,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Zones',
            value: _zones.length.toString(),
            icon: Icons.layers,
            color: Colors.purple,
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

  Widget _buildZoneCard(Map<String, dynamic> zone) {
    final occupancyPercent = (zone['occupied'] / zone['capacity'] * 100).toStringAsFixed(1);
    final isOptimal = zone['status'] == 'optimal';
    final statusColor = isOptimal ? AppTheme.success : Colors.orange;

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
                        zone['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${zone['items']} items stored',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    zone['status'].toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Occupancy',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.grey600,
                      ),
                    ),
                    Text(
                      '$occupancyPercent%',
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
                    value: zone['occupied'] / zone['capacity'],
                    minHeight: 6,
                    backgroundColor: AppTheme.grey200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getOccupancyColor(double.parse(occupancyPercent)),
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
                        'Temperature',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.thermostat, size: 12, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${zone['temperature']}°C',
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
                        'Humidity',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.water_drop, size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            '${zone['humidity']}%',
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
                        'Last Audit',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('HH:mm').format(zone['lastAudit']),
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
          ],
        ),
      ),
    );
  }

  Widget _buildShipmentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShipmentStats(),
          const SizedBox(height: 20),
          const Text(
            'Active Shipments',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._shipments.map((shipment) => _buildShipmentCard(shipment)).toList(),
        ],
      ),
    );
  }

  Widget _buildShipmentStats() {
    final packed = _shipments.where((s) => s['status'] == 'packed').length;
    final inTransit = _shipments.where((s) => s['status'] == 'in_transit').length;
    final delivered = _shipments.where((s) => s['status'] == 'delivered').length;
    final totalOrders = _shipments.fold<int>(0, (sum, s) => sum + (s['orderCount'] as int));

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Total Orders',
            value: totalOrders.toString(),
            icon: Icons.shopping_cart,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'In Transit',
            value: inTransit.toString(),
            icon: Icons.local_shipping,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Delivered',
            value: delivered.toString(),
            icon: Icons.check_circle,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Packed',
            value: packed.toString(),
            icon: Icons.done_all,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildShipmentCard(Map<String, dynamic> shipment) {
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
                        shipment['destination'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Shipment ID: ${shipment['id']}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildShipmentStatusBadge(shipment['status']),
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
                        'Orders',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${shipment['orderCount']} orders',
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
                        '${shipment['itemCount']} items',
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
                        'Weight',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${shipment['weight']} kg',
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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Driver',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shipment['driver'],
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
                        'Vehicle',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shipment['vehicle'],
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
          ],
        ),
      ),
    );
  }

  Widget _buildShipmentStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'packed':
        bgColor = Colors.blue.withValues(alpha: 0.1);
        textColor = Colors.blue;
        label = 'Packed';
        break;
      case 'in_transit':
        bgColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange[700]!;
        label = 'In Transit';
        break;
      case 'delivered':
        bgColor = AppTheme.success.withValues(alpha: 0.1);
        textColor = AppTheme.success;
        label = 'Delivered';
        break;
      default:
        bgColor = AppTheme.grey200;
        textColor = AppTheme.grey600;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildOperationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOperationStats(),
          const SizedBox(height: 20),
          const Text(
            'Pick & Pack Operations',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._pickPackOperations.map((op) => _buildOperationCard(op)).toList(),
        ],
      ),
    );
  }

  Widget _buildOperationStats() {
    final picking = _pickPackOperations.where((o) => o['status'] == 'picking').length;
    final packing = _pickPackOperations.where((o) => o['status'] == 'packing').length;
    final qualityCheck = _pickPackOperations.where((o) => o['status'] == 'quality_check').length;
    final totalOps = _pickPackOperations.length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Total Ops',
            value: totalOps.toString(),
            icon: Icons.work,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Picking',
            value: picking.toString(),
            icon: Icons.select_all,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Packing',
            value: packing.toString(),
            icon: Icons.inventory,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'QC',
            value: qualityCheck.toString(),
            icon: Icons.verified,
            color: AppTheme.success,
          ),
        ),
      ],
    );
  }

  Widget _buildOperationCard(Map<String, dynamic> operation) {
    final progress = (operation['pickedItems'] / operation['items']).toStringAsFixed(2);
    final progressPercent = (double.parse(progress) * 100).toStringAsFixed(0);

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
                        operation['orderId'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        operation['employee'],
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildOperationStatusBadge(operation['status']),
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
                  '${operation['pickedItems']}/${operation['items']} ($progressPercent%)',
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
                value: double.parse(progress),
                minHeight: 6,
                backgroundColor: AppTheme.grey200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getProgressColor(double.parse(progress)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Started: ${DateFormat('HH:mm').format(operation['startTime'])}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppTheme.grey600,
                  ),
                ),
                Text(
                  'Est: ${DateFormat('HH:mm').format(operation['estimatedCompletion'])}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppTheme.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'picking':
        bgColor = Colors.blue.withValues(alpha: 0.1);
        textColor = Colors.blue;
        label = 'Picking';
        break;
      case 'packing':
        bgColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange[700]!;
        label = 'Packing';
        break;
      case 'quality_check':
        bgColor = AppTheme.success.withValues(alpha: 0.1);
        textColor = AppTheme.success;
        label = 'QC';
        break;
      default:
        bgColor = AppTheme.grey200;
        textColor = AppTheme.grey600;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Color _getOccupancyColor(double occupancy) {
    if (occupancy <= 70) return AppTheme.success;
    if (occupancy <= 85) return Colors.orange;
    return AppTheme.error;
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.9) return AppTheme.success;
    if (progress >= 0.5) return Colors.orange;
    return AppTheme.error;
  }
}
