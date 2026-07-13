import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

class VendorSupplierManagementScreen extends StatefulWidget {
  const VendorSupplierManagementScreen({Key? key}) : super(key: key);

  @override
  State<VendorSupplierManagementScreen> createState() =>
      _VendorSupplierManagementScreenState();
}

class _VendorSupplierManagementScreenState
    extends State<VendorSupplierManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all'; // all, active, inactive, pending
  final List<Map<String, dynamic>> _vendors = [
    {
      'id': 'vendor_001',
      'name': 'Fresh Farms Cooperative',
      'category': 'Produce',
      'status': 'active',
      'rating': 4.8,
      'reviews': 24,
      'accountHolder': 'Rajesh Sharma',
      'phone': '+91 98765 43210',
      'email': 'contact@freshfarms.com',
      'location': 'Bangalore, KA',
      'joinDate': DateTime(2025, 6, 15),
      'totalOrders': 156,
      'totalSpent': 450000,
      'averageDelivery': 2.1,
      'qualityScore': 95,
    },
    {
      'id': 'vendor_002',
      'name': 'Quality Dairy Supplies',
      'category': 'Dairy',
      'status': 'active',
      'rating': 4.5,
      'reviews': 18,
      'accountHolder': 'Priya Mehta',
      'phone': '+91 97654 32109',
      'email': 'sales@qualitydairy.com',
      'location': 'Bangalore, KA',
      'joinDate': DateTime(2025, 7, 1),
      'totalOrders': 89,
      'totalSpent': 320000,
      'averageDelivery': 1.8,
      'qualityScore': 92,
    },
    {
      'id': 'vendor_003',
      'name': 'Premium Spices Ltd',
      'category': 'Spices',
      'status': 'pending',
      'rating': 0,
      'reviews': 0,
      'accountHolder': 'Amit Kumar',
      'phone': '+91 96543 21098',
      'email': 'contact@premiumspices.com',
      'location': 'Delhi, DL',
      'joinDate': DateTime(2026, 7, 5),
      'totalOrders': 0,
      'totalSpent': 0,
      'averageDelivery': 0,
      'qualityScore': 0,
    },
    {
      'id': 'vendor_004',
      'name': 'Wholesale Beverages Co',
      'category': 'Beverages',
      'status': 'active',
      'rating': 4.2,
      'reviews': 12,
      'accountHolder': 'Sanjay Gupta',
      'phone': '+91 95432 10987',
      'email': 'admin@wholesale.com',
      'location': 'Bangalore, KA',
      'joinDate': DateTime(2025, 8, 20),
      'totalOrders': 67,
      'totalSpent': 220000,
      'averageDelivery': 2.5,
      'qualityScore': 88,
    },
  ];

  final List<Map<String, dynamic>> _recentOrders = [
    {
      'id': 'order_001',
      'vendorName': 'Fresh Farms Cooperative',
      'items': 12,
      'amount': 25000,
      'date': DateTime(2026, 7, 10),
      'status': 'delivered',
      'expectedDelivery': DateTime(2026, 7, 12),
    },
    {
      'id': 'order_002',
      'vendorName': 'Quality Dairy Supplies',
      'items': 5,
      'amount': 15000,
      'date': DateTime(2026, 7, 11),
      'status': 'pending',
      'expectedDelivery': DateTime(2026, 7, 13),
    },
    {
      'id': 'order_003',
      'vendorName': 'Wholesale Beverages Co',
      'items': 8,
      'amount': 18000,
      'date': DateTime(2026, 7, 9),
      'status': 'in_transit',
      'expectedDelivery': DateTime(2026, 7, 12),
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
          'Vendor Management',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('All Vendors'),
                onTap: () => setState(() => _selectedFilter = 'all'),
              ),
              PopupMenuItem(
                child: const Text('Active'),
                onTap: () => setState(() => _selectedFilter = 'active'),
              ),
              PopupMenuItem(
                child: const Text('Pending'),
                onTap: () => setState(() => _selectedFilter = 'pending'),
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
            Tab(text: 'Vendors'),
            Tab(text: 'Orders'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVendorsTab(),
          _buildOrdersTab(),
          _buildAnalyticsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildVendorsTab() {
    final filteredVendors = _getFilteredVendors();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVendorStats(),
          const SizedBox(height: 20),
          const Text(
            'Vendors',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (filteredVendors.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.business, size: 48, color: AppTheme.grey400),
                    const SizedBox(height: 12),
                    Text(
                      'No vendors found',
                      style: TextStyle(color: AppTheme.grey600),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredVendors.map((vendor) => _buildVendorCard(vendor)).toList(),
        ],
      ),
    );
  }

  Widget _buildVendorStats() {
    final active = _vendors.where((v) => v['status'] == 'active').length;
    final total = _vendors.length;
    final avgRating = _vendors
            .where((v) => v['rating'] > 0)
            .fold<double>(0, (sum, v) => sum + (v['rating'] as double)) /
        _vendors.where((v) => v['rating'] > 0).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Total Vendors',
            value: total.toString(),
            icon: Icons.business,
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
            label: 'Categories',
            value: '4',
            icon: Icons.category,
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

  Widget _buildVendorCard(Map<String, dynamic> vendor) {
    final isPending = vendor['status'] == 'pending';

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
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      vendor['name'][0],
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
                        vendor['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        vendor['category'],
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(vendor['status']),
              ],
            ),
            const SizedBox(height: 12),
            if (!isPending) ...[
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
                              '${vendor['rating']} (${vendor['reviews']} reviews)',
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
                          'Orders',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.grey600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vendor['totalOrders'].toString(),
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
                          'Delivery Time',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.grey600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${vendor['averageDelivery']}d avg',
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quality Score',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.grey600,
                        ),
                      ),
                      Text(
                        '${vendor['qualityScore']}%',
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
                      value: vendor['qualityScore'] / 100,
                      minHeight: 6,
                      backgroundColor: AppTheme.grey200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        vendor['qualityScore'] >= 90
                            ? AppTheme.success
                            : (vendor['qualityScore'] >= 80 ? Colors.orange : AppTheme.error),
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Details',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    vendor['accountHolder'],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    vendor['email'],
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.grey600,
                    ),
                  ),
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
                    child: const Text('View', style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text('Contact', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'active':
        bgColor = AppTheme.success.withOpacity(0.1);
        textColor = AppTheme.success;
        label = 'Active';
        break;
      case 'pending':
        bgColor = Colors.amber.withOpacity(0.1);
        textColor = Colors.amber[700]!;
        label = 'Pending';
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

  Widget _buildOrdersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Vendor Orders',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._recentOrders.map((order) => _buildOrderCard(order)).toList(),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
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
                        order['vendorName'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Order ID: ${order['id']}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildOrderStatusBadge(order['status']),
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
                        'Items',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${order['items']} items',
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
                        'Amount',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${(order['amount'] as int).toStringAsFixed(0)}',
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
                        'Expected Delivery',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM dd').format(order['expectedDelivery']),
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

  Widget _buildOrderStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'delivered':
        bgColor = AppTheme.success.withOpacity(0.1);
        textColor = AppTheme.success;
        label = 'Delivered';
        break;
      case 'pending':
        bgColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        label = 'Pending';
        break;
      case 'in_transit':
        bgColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange[700]!;
        label = 'In Transit';
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

  Widget _buildAnalyticsTab() {
    final totalSpent =
        _vendors.fold<int>(0, (sum, v) => sum + (v['totalSpent'] as int));
    final avgQuality = _vendors
        .where((v) => v['qualityScore'] > 0)
        .fold<double>(0, (sum, v) => sum + (v['qualityScore'] as int)) /
        _vendors.where((v) => v['qualityScore'] > 0).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsCard(
            title: 'Total Spent',
            value: '₹${(totalSpent / 100000).toStringAsFixed(1)}L',
            subtitle: 'Across all vendors',
            icon: Icons.attach_money,
          ),
          const SizedBox(height: 12),
          _buildAnalyticsCard(
            title: 'Avg Quality Score',
            value: avgQuality.toStringAsFixed(1),
            subtitle: 'Overall vendor quality',
            icon: Icons.verified,
          ),
          const SizedBox(height: 20),
          const Text(
            'Vendor Performance',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildVendorPerformanceList(),
          const SizedBox(height: 20),
          const Text(
            'Vendor Categories',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildCategoryBreakdown(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, color: AppTheme.primary, size: 24),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.grey600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.grey500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorPerformanceList() {
    final sorted = List<Map<String, dynamic>>.from(_vendors.where((v) => v['qualityScore'] > 0))
      ..sort((a, b) => (b['qualityScore'] as int).compareTo(a['qualityScore'] as int));

    return Column(
      children: sorted
          .map((vendor) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vendor['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${vendor['totalOrders']} orders | ₹${(vendor['totalSpent'] / 1000).toStringAsFixed(0)}K',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.grey600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${vendor['qualityScore']}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: vendor['qualityScore'] / 100,
                                minHeight: 4,
                                backgroundColor: AppTheme.grey200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  vendor['qualityScore'] >= 90
                                      ? AppTheme.success
                                      : Colors.orange,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCategoryBreakdown() {
    final categories = <String, int>{};
    for (var vendor in _vendors) {
      final cat = vendor['category'] as String;
      categories[cat] = (categories[cat] ?? 0) + 1;
    }

    return Column(
      children: categories.entries
          .map((entry) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value} vendor${entry.value > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  List<Map<String, dynamic>> _getFilteredVendors() {
    switch (_selectedFilter) {
      case 'active':
        return _vendors.where((v) => v['status'] == 'active').toList();
      case 'pending':
        return _vendors.where((v) => v['status'] == 'pending').toList();
      case 'inactive':
        return _vendors.where((v) => v['status'] == 'inactive').toList();
      default:
        return _vendors;
    }
  }
}
