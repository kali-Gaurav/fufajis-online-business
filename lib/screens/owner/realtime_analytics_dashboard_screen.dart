import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class RealtimeAnalyticsDashboardScreen extends StatefulWidget {
  const RealtimeAnalyticsDashboardScreen({Key? key}) : super(key: key);

  @override
  State<RealtimeAnalyticsDashboardScreen> createState() =>
      _RealtimeAnalyticsDashboardScreenState();
}

class _RealtimeAnalyticsDashboardScreenState
    extends State<RealtimeAnalyticsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isPaused = false;
  final DateTime _dashboardStartTime = DateTime.now();

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

  String _getElapsedTime() {
    final now = DateTime.now();
    final diff = now.difference(_dashboardStartTime);
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    return '${diff.inMinutes}m ${diff.inSeconds % 60}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text(
          'Real-time Analytics',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isPaused ? Colors.grey : AppTheme.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isPaused ? 'Paused' : 'Live',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isPaused ? Colors.grey : AppTheme.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.grey600,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Orders'),
            Tab(text: 'Activity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayTab(),
          _buildOrdersTab(),
          _buildActivityTab(),
        ],
      ),
    );
  }

  Widget _buildTodayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Metrics Cards
          _buildLiveMetricsGrid(),
          const SizedBox(height: 20),

          // Hourly Performance
          _buildHourlyPerformance(),
          const SizedBox(height: 20),

          // Top Products
          _buildTopProductsSection(),
          const SizedBox(height: 20),

          // Traffic Sources
          _buildTrafficSourcesSection(),
        ],
      ),
    );
  }

  Widget _buildLiveMetricsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildLiveMetricCard(
                label: 'Today\'s Revenue',
                value: '₹12,450',
                change: '+₹2,100',
                isPositive: true,
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLiveMetricCard(
                label: 'Orders Today',
                value: '42',
                change: '+8 since noon',
                isPositive: true,
                icon: Icons.shopping_cart,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildLiveMetricCard(
                label: 'Active Users',
                value: '187',
                change: '+23 browsing',
                isPositive: true,
                icon: Icons.people,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLiveMetricCard(
                label: 'Avg Order Value',
                value: '₹2,960',
                change: '+₹120 vs avg',
                isPositive: true,
                icon: Icons.attach_money,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLiveMetricCard({
    required String label,
    required String value,
    required String change,
    required bool isPositive,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: AppTheme.primary, size: 18),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isPositive ? AppTheme.success : AppTheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.grey600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              change,
              style: TextStyle(
                fontSize: 10,
                color: isPositive ? AppTheme.success : AppTheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyPerformance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Performance by Hour',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  height: 120,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildBarChart(height: 40, label: '6am', value: '₹800'),
                          _buildBarChart(height: 60, label: '9am', value: '₹1.2K'),
                          _buildBarChart(height: 80, label: '12pm', value: '₹1.8K'),
                          _buildBarChart(height: 95, label: '3pm', value: '₹2.1K'),
                          _buildBarChart(height: 75, label: '6pm', value: '₹1.9K'),
                          _buildBarChart(height: 50, label: '9pm', value: '₹1.2K'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Peak Hour: 3 PM',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '₹2,100 revenue',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart({
    required double height,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20,
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: AppTheme.grey600),
        ),
      ],
    );
  }

  Widget _buildTopProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Products (Today)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildTopProductTile(
                  rank: 1,
                  name: 'Fresh Milk 1L',
                  sales: 24,
                  revenue: 480,
                ),
                const Divider(height: 16),
                _buildTopProductTile(
                  rank: 2,
                  name: 'Whole Wheat Bread',
                  sales: 18,
                  revenue: 360,
                ),
                const Divider(height: 16),
                _buildTopProductTile(
                  rank: 3,
                  name: 'Organic Vegetables',
                  sales: 15,
                  revenue: 450,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopProductTile({
    required int rank,
    required String name,
    required int sales,
    required int revenue,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
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
                fontSize: 11,
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
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$sales sales',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.grey600,
                ),
              ),
            ],
          ),
        ),
        Text(
          '₹$revenue',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildTrafficSourcesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Traffic Sources',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTrafficSourceCard(
                label: 'Direct',
                percentage: 45,
                count: 85,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTrafficSourceCard(
                label: 'Search',
                percentage: 30,
                count: 56,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTrafficSourceCard(
                label: 'Social',
                percentage: 25,
                count: 47,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrafficSourceCard({
    required String label,
    required int percentage,
    required int count,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$percentage%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count visitors',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.grey600,
              ),
            ),
          ],
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
            'Live Orders',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ..._buildLiveOrdersList(),
        ],
      ),
    );
  }

  List<Widget> _buildLiveOrdersList() {
    final orders = [
      {'id': '#12485', 'customer': 'Rajesh Kumar', 'amount': 2450, 'status': 'Delivered', 'time': 'now'},
      {'id': '#12484', 'customer': 'Priya Singh', 'amount': 1820, 'status': 'In Transit', 'time': '2 min ago'},
      {'id': '#12483', 'customer': 'Amit Patel', 'amount': 3240, 'status': 'Packed', 'time': '5 min ago'},
      {'id': '#12482', 'customer': 'Neha Sharma', 'amount': 1560, 'status': 'Processing', 'time': '8 min ago'},
    ];

    return orders
        .map((order) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                order['id'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                order['time'],
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.grey600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${order['amount']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order['status']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            order['status'],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(order['status']),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ))
        .toList();
  }

  Widget _buildActivityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity Feed',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ..._buildActivityFeed(),
        ],
      ),
    );
  }

  List<Widget> _buildActivityFeed() {
    final activities = [
      {'type': 'order', 'message': 'New order #12485 placed', 'time': 'just now', 'icon': Icons.shopping_cart},
      {'type': 'customer', 'message': 'Rajesh Kumar placed first order', 'time': '2 min ago', 'icon': Icons.person_add},
      {'type': 'inventory', 'message': 'Milk stock is running low (5 units)', 'time': '5 min ago', 'icon': Icons.warning},
      {'type': 'payment', 'message': 'Payment received: ₹8,500', 'time': '8 min ago', 'icon': Icons.check_circle},
      {'type': 'order', 'message': 'Order #12483 delivered', 'time': '12 min ago', 'icon': Icons.done_all},
    ];

    return activities
        .map((activity) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        activity['icon'] as IconData,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity['message'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activity['time'],
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.grey600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ))
        .toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Delivered':
        return AppTheme.success;
      case 'In Transit':
        return Colors.blue;
      case 'Packed':
        return Colors.orange;
      case 'Processing':
        return Colors.orange;
      default:
        return AppTheme.grey600;
    }
  }
}
