import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

enum DiscountType { percentage, fixed, bogo, bundleOffer }

class PromotionDiscountManagementScreen extends StatefulWidget {
  const PromotionDiscountManagementScreen({Key? key}) : super(key: key);

  @override
  State<PromotionDiscountManagementScreen> createState() =>
      _PromotionDiscountManagementScreenState();
}

class _PromotionDiscountManagementScreenState
    extends State<PromotionDiscountManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, dynamic>> _promotions = [
    {
      'id': 'SUMMER20',
      'title': 'Summer Sale 20%',
      'type': 'percentage',
      'value': 20,
      'startDate': DateTime.now(),
      'endDate': DateTime.now().add(const Duration(days: 30)),
      'status': 'active',
      'usageCount': 245,
      'targetAmount': 500,
    },
    {
      'id': 'FLAT100',
      'title': 'Flat ₹100 Off',
      'type': 'fixed',
      'value': 100,
      'startDate': DateTime.now().subtract(const Duration(days: 5)),
      'endDate': DateTime.now().add(const Duration(days: 10)),
      'status': 'active',
      'usageCount': 128,
      'targetAmount': 500,
    },
    {
      'id': 'BOGO25',
      'title': 'Buy 1 Get 1 25%',
      'type': 'bogo',
      'value': 25,
      'startDate': DateTime.now(),
      'endDate': DateTime.now().add(const Duration(days: 15)),
      'status': 'scheduled',
      'usageCount': 0,
      'targetAmount': 1000,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          'Promotions & Discounts',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.grey600,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'All Promotions'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPromotionsTab(),
          _buildAnalyticsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePromotionDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('New Promotion'),
      ),
    );
  }

  Widget _buildPromotionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          _buildStatsRow(),
          const SizedBox(height: 20),

          // Active Promotions
          const Text(
            'Active Promotions',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._promotions
              .where((p) => p['status'] == 'active')
              .map((promotion) => _buildPromotionCard(promotion))
              .toList(),
          const SizedBox(height: 20),

          // Scheduled
          const Text(
            'Scheduled',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._promotions
              .where((p) => p['status'] == 'scheduled')
              .map((promotion) => _buildPromotionCard(promotion))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Active',
            value: '${_promotions.where((p) => p['status'] == 'active').length}',
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Scheduled',
            value: '${_promotions.where((p) => p['status'] == 'scheduled').length}',
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Total Usage',
            value: '${_promotions.fold<int>(0, (sum, p) => sum + (p['usageCount'] as int))}',
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.trending_up, color: color, size: 16),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.grey500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionCard(Map<String, dynamic> promotion) {
    final startDate = DateFormat('MMM d').format(promotion['startDate']);
    final endDate = DateFormat('MMM d').format(promotion['endDate']);
    final isActive = promotion['status'] == 'active';
    final statusColor = isActive ? AppTheme.success : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              promotion['title'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              promotion['status'].toString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Code: ${promotion['id']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey500,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Discount',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.grey600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      promotion['type'] == 'percentage'
                          ? '${promotion['value']}%'
                          : '₹${promotion['value']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Period',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.grey600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$startDate - $endDate',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Usage',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.grey600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${promotion['usageCount']}x',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Min purchase requirement
            Row(
              children: [
                Icon(
                  Icons.shopping_cart,
                  size: 14,
                  color: AppTheme.grey500,
                ),
                const SizedBox(width: 4),
                Text(
                  'Min. purchase: ₹${promotion['targetAmount']}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.grey600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.analytics, size: 16),
                    label: const Text('Analytics'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.more_vert, size: 16),
                    label: const Text('More'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Promotion Performance',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._promotions.map((promotion) => _buildAnalyticsCard(promotion)).toList(),
          const SizedBox(height: 20),
          const Text(
            'Top Performing Promotions',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._buildTopPerformingList(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(Map<String, dynamic> promotion) {
    final revenue = promotion['usageCount'] * 500;
    final conversionRate = (promotion['usageCount'] / 1000 * 100).toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              promotion['title'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Usage',
                      style: TextStyle(fontSize: 11, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${promotion['usageCount']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Revenue Generated',
                      style: TextStyle(fontSize: 11, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹$revenue',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.success,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Conversion Rate',
                      style: TextStyle(fontSize: 11, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$conversionRate%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTopPerformingList() {
    final sorted = List<Map<String, dynamic>>.from(_promotions)
      ..sort((a, b) => (b['usageCount'] as int).compareTo(a['usageCount'] as int));

    return sorted.take(3).map((promo) {
      final rank = sorted.indexOf(promo) + 1;
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: rank == 1
                      ? Colors.amber
                      : (rank == 2 ? Colors.grey : Colors.orange),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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
                      promo['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${promo['usageCount']} uses • Revenue: ₹${promo['usageCount'] * 500}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.trending_up,
                color: AppTheme.success,
                size: 20,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _showCreatePromotionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Promotion'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Promotion Type',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _buildTypeChip('Percentage Off'),
                  _buildTypeChip('Fixed Amount'),
                  _buildTypeChip('BOGO'),
                  _buildTypeChip('Bundle'),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Promotion Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Coupon Code',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Discount Value',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: AppTheme.grey100,
      onDeleted: null,
    );
  }
}
