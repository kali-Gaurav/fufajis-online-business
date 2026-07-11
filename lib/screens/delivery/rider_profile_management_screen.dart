import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

class RiderProfileManagementScreen extends StatefulWidget {
  const RiderProfileManagementScreen({Key? key}) : super(key: key);

  @override
  State<RiderProfileManagementScreen> createState() =>
      _RiderProfileManagementScreenState();
}

class _RiderProfileManagementScreenState
    extends State<RiderProfileManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all'; // all, active, inactive, onboarding
  final List<Map<String, dynamic>> _riders = [
    {
      'id': 'rider_001',
      'name': 'Ramesh Kumar',
      'phone': '+91 98765 43210',
      'email': 'ramesh@fufaji.com',
      'status': 'active',
      'joinDate': DateTime(2025, 6, 15),
      'avatar': 'R',
      'rating': 4.8,
      'reviews': 245,
      'totalDeliveries': 1250,
      'activeShifts': 2,
      'documents': {
        'aadhar': true,
        'pan': true,
        'dl': true,
        'insurance': true,
      },
      'availability': {
        'Monday': {'from': '06:00', 'to': '22:00', 'available': true},
        'Tuesday': {'from': '06:00', 'to': '22:00', 'available': true},
        'Wednesday': {'from': '06:00', 'to': '18:00', 'available': true},
        'Thursday': {'from': '06:00', 'to': '22:00', 'available': true},
        'Friday': {'from': '06:00', 'to': '22:00', 'available': true},
        'Saturday': {'from': '10:00', 'to': '20:00', 'available': true},
        'Sunday': {'from': 'Off', 'to': 'Off', 'available': false},
      },
      'serviceAreas': ['North', 'East', 'Central'],
      'vehicleType': 'Two-wheeler',
      'bankAccount': 'XXXX XXXX XXXX 1234',
    },
    {
      'id': 'rider_002',
      'name': 'Priya Sharma',
      'phone': '+91 97654 32109',
      'email': 'priya@fufaji.com',
      'status': 'active',
      'joinDate': DateTime(2025, 7, 1),
      'avatar': 'P',
      'rating': 4.6,
      'reviews': 189,
      'totalDeliveries': 892,
      'activeShifts': 1,
      'documents': {
        'aadhar': true,
        'pan': true,
        'dl': true,
        'insurance': false,
      },
      'availability': {
        'Monday': {'from': '08:00', 'to': '20:00', 'available': true},
        'Tuesday': {'from': '08:00', 'to': '20:00', 'available': true},
        'Wednesday': {'from': 'Off', 'to': 'Off', 'available': false},
        'Thursday': {'from': '08:00', 'to': '20:00', 'available': true},
        'Friday': {'from': '08:00', 'to': '20:00', 'available': true},
        'Saturday': {'from': '08:00', 'to': '20:00', 'available': true},
        'Sunday': {'from': 'Off', 'to': 'Off', 'available': false},
      },
      'serviceAreas': ['West', 'South'],
      'vehicleType': 'Four-wheeler',
      'bankAccount': 'XXXX XXXX XXXX 5678',
    },
    {
      'id': 'rider_003',
      'name': 'Amit Patel',
      'phone': '+91 96543 21098',
      'email': 'amit@fufaji.com',
      'status': 'onboarding',
      'joinDate': DateTime(2026, 7, 5),
      'avatar': 'A',
      'rating': 0,
      'reviews': 0,
      'totalDeliveries': 0,
      'activeShifts': 0,
      'documents': {
        'aadhar': true,
        'pan': false,
        'dl': true,
        'insurance': false,
      },
      'availability': {},
      'serviceAreas': [],
      'vehicleType': 'Two-wheeler',
      'bankAccount': null,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
          'Rider Management',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('All Riders'),
                onTap: () => setState(() => _selectedFilter = 'all'),
              ),
              PopupMenuItem(
                child: const Text('Active'),
                onTap: () => setState(() => _selectedFilter = 'active'),
              ),
              PopupMenuItem(
                child: const Text('Onboarding'),
                onTap: () => setState(() => _selectedFilter = 'onboarding'),
              ),
              PopupMenuItem(
                child: const Text('Inactive'),
                onTap: () => setState(() => _selectedFilter = 'inactive'),
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
            Tab(text: 'Profiles'),
            Tab(text: 'Documents'),
            Tab(text: 'Availability'),
            Tab(text: 'Performance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProfilesTab(),
          _buildDocumentsTab(),
          _buildAvailabilityTab(),
          _buildPerformanceTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProfilesTab() {
    final filteredRiders = _getFilteredRiders();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRiderStats(),
          const SizedBox(height: 20),
          const Text(
            'Riders',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (filteredRiders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.two_wheeler, size: 48, color: AppTheme.grey400),
                    const SizedBox(height: 12),
                    Text(
                      'No riders found',
                      style: TextStyle(color: AppTheme.grey600),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredRiders.map((rider) => _buildRiderCard(rider)).toList(),
        ],
      ),
    );
  }

  Widget _buildRiderStats() {
    final active = _riders.where((r) => r['status'] == 'active').length;
    final total = _riders.length;
    final avgRating = _riders
        .where((r) => r['rating'] > 0)
        .fold<double>(0, (sum, r) => sum + (r['rating'] as double)) /
        _riders.where((r) => r['rating'] > 0).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Total Riders',
            value: total.toString(),
            icon: Icons.two_wheeler,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Active',
            value: active.toString(),
            icon: Icons.check_circle,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Avg Rating',
            value: avgRating.toStringAsFixed(1),
            icon: Icons.star,
            color: Colors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Service Areas',
            value: '5',
            icon: Icons.location_on,
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

  Widget _buildRiderCard(Map<String, dynamic> rider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      rider['avatar'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                        rider['phone'],
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(rider['status']),
              ],
            ),
            const SizedBox(height: 12),
            if (rider['rating'] > 0)
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
                              '${rider['rating']} (${rider['reviews']})',
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
                          'Deliveries',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.grey600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rider['totalDeliveries'].toString(),
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
                          'Service Areas',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.grey600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${rider['serviceAreas'].length} zones',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Onboarding Progress',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDocumentStatus(rider['documents']),
                ],
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
                    child: const Text('View Profile', style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text('Edit', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentStatus(Map<String, dynamic> documents) {
    final total = documents.length;
    final verified = documents.values.where((v) => v == true).length;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: verified / total,
              minHeight: 6,
              backgroundColor: AppTheme.grey200,
              valueColor: AlwaysStoppedAnimation<Color>(
                verified == total ? AppTheme.success : Colors.orange,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$verified/$total',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'active':
        bgColor = AppTheme.success.withValues(alpha: 0.1);
        textColor = AppTheme.success;
        label = 'Active';
        break;
      case 'onboarding':
        bgColor = Colors.blue.withValues(alpha: 0.1);
        textColor = Colors.blue;
        label = 'Onboarding';
        break;
      case 'inactive':
        bgColor = AppTheme.grey200;
        textColor = AppTheme.grey600;
        label = 'Inactive';
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

  Widget _buildDocumentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Document Verification',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._riders.map((rider) => _buildRiderDocumentCard(rider)).toList(),
        ],
      ),
    );
  }

  Widget _buildRiderDocumentCard(Map<String, dynamic> rider) {
    final documents = rider['documents'] as Map<String, dynamic>;

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
                  child: Text(
                    rider['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: documents.values.every((v) => v == true)
                        ? AppTheme.success.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    documents.values.every((v) => v == true)
                        ? 'VERIFIED'
                        : 'PENDING',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: documents.values.every((v) => v == true)
                          ? AppTheme.success
                          : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: documents.entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: entry.value
                                  ? AppTheme.success
                                  : AppTheme.error,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                entry.value ? Icons.check : Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.key.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (!entry.value)
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                              child: const Text(
                                'Upload',
                                style: TextStyle(fontSize: 9),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shift & Availability',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._riders.where((r) => r['status'] == 'active').map((rider) => _buildRiderAvailabilityCard(rider)).toList(),
        ],
      ),
    );
  }

  Widget _buildRiderAvailabilityCard(Map<String, dynamic> rider) {
    final availability = rider['availability'] as Map<String, dynamic>;
    final workingDays =
        availability.values.where((v) => (v as Map)['available'] == true).length;

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
                        'Working $workingDays/7 days',
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
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${rider['activeShifts']} shifts',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: availability.entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              (entry.value as Map)['available'] == true
                                  ? '${(entry.value as Map)['from']} - ${(entry.value as Map)['to']}'
                                  : 'Off',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.grey600,
                              ),
                            ),
                          ),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: (entry.value as Map)['available'] == true
                                  ? AppTheme.success
                                  : AppTheme.grey400,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Overview',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._riders
              .where((r) => r['status'] == 'active')
              .map((rider) => _buildRiderPerformanceCard(rider))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildRiderPerformanceCard(Map<String, dynamic> rider) {
    final totalDeliveries = rider['totalDeliveries'] as int;
    final avgPerDay = (totalDeliveries / 30).toStringAsFixed(1);

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
                  child: Text(
                    rider['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${rider['rating']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
                        'Total Deliveries',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        totalDeliveries.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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
                        'Avg/Day',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        avgPerDay,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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
                        'Reviews',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rider['reviews'].toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rating Distribution',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.grey600,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rider['rating'] / 5,
                    minHeight: 6,
                    backgroundColor: AppTheme.grey200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rider['rating'] >= 4.5
                          ? AppTheme.success
                          : (rider['rating'] >= 3.5 ? Colors.orange : AppTheme.error),
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

  List<Map<String, dynamic>> _getFilteredRiders() {
    switch (_selectedFilter) {
      case 'active':
        return _riders.where((r) => r['status'] == 'active').toList();
      case 'onboarding':
        return _riders.where((r) => r['status'] == 'onboarding').toList();
      case 'inactive':
        return _riders.where((r) => r['status'] == 'inactive').toList();
      default:
        return _riders;
    }
  }
}
