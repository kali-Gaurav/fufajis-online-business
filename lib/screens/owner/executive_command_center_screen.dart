import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class ExecutiveCommandCenterScreen extends StatefulWidget {
  const ExecutiveCommandCenterScreen({Key? key}) : super(key: key);

  @override
  State<ExecutiveCommandCenterScreen> createState() =>
      _ExecutiveCommandCenterScreenState();
}

class _ExecutiveCommandCenterScreenState extends State<ExecutiveCommandCenterScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Executive Command Center'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Operations'),
            Tab(text: 'Business Intelligence'),
            Tab(text: 'Alerts'),
            Tab(text: 'Quick Actions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildOperationsTab(),
          _buildBusinessIntelligenceTab(),
          _buildAlertsTab(),
          _buildQuickActionsTab(),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Performance',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildMainKPIGrid(),
          const SizedBox(height: 24),
          const Text(
            'Real-Time Status',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildRealtimeStatus(),
          const SizedBox(height: 24),
          const Text(
            'Executive Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildExecutiveSummary(),
        ],
      ),
    );
  }

  Widget _buildMainKPIGrid() {
    final kpis = [
      {
        'label': 'Revenue Today',
        'value': '₹48,500',
        'icon': Icons.trending_up,
        'color': Colors.green,
        'change': '+12.5%',
        'subtitle': 'vs yesterday',
      },
      {
        'label': 'Total Orders',
        'value': '156',
        'icon': Icons.shopping_cart,
        'color': Colors.blue,
        'change': '+8.3%',
        'subtitle': 'active orders',
      },
      {
        'label': 'Delivery Rate',
        'value': '94.2%',
        'icon': Icons.local_shipping,
        'color': Colors.orange,
        'change': '+2.1%',
        'subtitle': 'on-time',
      },
      {
        'label': 'Customers Active',
        'value': '2,345',
        'icon': Icons.group,
        'color': Colors.purple,
        'change': '+5.8%',
        'subtitle': 'today',
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: kpis.map((kpi) => _buildKPICard(kpi)).toList(),
    );
  }

  Widget _buildKPICard(Map<String, dynamic> kpi) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kpi['color'].withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(kpi['icon'], color: kpi['color'], size: 18),
                ),
                Text(
                  kpi['change'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kpi['label'],
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  kpi['value'],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  kpi['subtitle'],
                  style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeStatus() {
    final status = [
      {
        'system': 'Order Processing',
        'status': 'Optimal',
        'color': Colors.green,
        'metric': '0.2s avg',
        'icon': Icons.done_all,
      },
      {
        'system': 'Delivery Network',
        'status': 'Healthy',
        'color': Colors.green,
        'metric': '18 active',
        'icon': Icons.local_shipping,
      },
      {
        'system': 'Inventory Levels',
        'status': 'Good',
        'color': Colors.orange,
        'metric': '8 low stock',
        'icon': Icons.inventory,
      },
      {
        'system': 'Payment Gateway',
        'status': 'Active',
        'color': Colors.green,
        'metric': '99.9% uptime',
        'icon': Icons.payment,
      },
    ];

    return Column(
      children: status.map((s) => _buildStatusCard(s)).toList(),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> status) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: status['color'].withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(status['icon'], color: status['color'], size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status['system'],
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      status['metric'],
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status['status'],
                style: TextStyle(
                  fontSize: 11,
                  color: status['color'],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveSummary() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Week-over-Week Comparison',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Revenue', '₹3.25Cr', '₹2.98Cr', '+9.1%', Colors.green),
            const SizedBox(height: 12),
            _buildSummaryRow('Orders', '1,085', '942', '+15.2%', Colors.green),
            const SizedBox(height: 12),
            _buildSummaryRow('Avg Order Value', '₹2,995', '₹3,160', '-5.2%', Colors.red),
            const SizedBox(height: 12),
            _buildSummaryRow('Customer Satisfaction', '4.6★', '4.5★', '+2.2%', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String current, String previous, String change, Color changeColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                'This week: $current | Last week: $previous',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: changeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            change,
            style: TextStyle(
              fontSize: 11,
              color: changeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOperationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Management',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildOrderMetrics(),
          const SizedBox(height: 24),
          const Text(
            'Delivery Operations',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildDeliveryMetrics(),
          const SizedBox(height: 24),
          const Text(
            'Inventory Health',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildInventoryMetrics(),
        ],
      ),
    );
  }

  Widget _buildOrderMetrics() {
    final metrics = [
      {'label': 'Pending Orders', 'value': '24', 'target': '< 50', 'icon': Icons.pending, 'color': Colors.blue},
      {'label': 'Processing', 'value': '42', 'target': '< 100', 'icon': Icons.schedule, 'color': Colors.orange},
      {'label': 'Packed', 'value': '38', 'target': '< 80', 'icon': Icons.inventory_2, 'color': Colors.green},
      {'label': 'Shipped', 'value': '52', 'target': '< 150', 'icon': Icons.local_shipping, 'color': Colors.purple},
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: metrics.map((m) => _buildMetricCard(m)).toList(),
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> metric) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: metric['color'].withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(metric['icon'], color: metric['color'], size: 16),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric['label'],
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  metric['value'],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Target: ${metric['target']}',
                  style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryMetrics() {
    final deliveryInfo = [
      {
        'title': 'Active Deliveries',
        'value': '18 riders',
        'subtitle': '156 orders in transit',
        'efficiency': 92,
        'icon': Icons.location_on,
      },
      {
        'title': 'Avg Delivery Time',
        'value': '42 minutes',
        'subtitle': 'vs target 45 min',
        'efficiency': 95,
        'icon': Icons.timer,
      },
      {
        'title': 'On-Time Rate',
        'value': '94.2%',
        'subtitle': 'Last 7 days average',
        'efficiency': 94,
        'icon': Icons.check_circle,
      },
    ];

    return Column(
      children: deliveryInfo
          .map((info) => Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.grey[50],
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                info['title'],
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                info['subtitle'],
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          Icon(info['icon'], color: Colors.blue, size: 24),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        info['value'],
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildInventoryMetrics() {
    final invMetrics = [
      {'label': 'Total SKUs', 'value': '2,450', 'status': 'Normal'},
      {'label': 'Low Stock Items', 'value': '8', 'status': 'Alert'},
      {'label': 'Excess Stock', 'value': '156', 'status': 'Action'},
      {'label': 'Stock Health', 'value': '78.5%', 'status': 'Good'},
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: invMetrics.map((m) => _buildInvCard(m)).toList(),
    );
  }

  Widget _buildInvCard(Map<String, dynamic> metric) {
    final statusColor =
        metric['status'] == 'Alert' ? Colors.red : metric['status'] == 'Action' ? Colors.orange : Colors.green;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                metric['status'],
                style: TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.bold),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric['label'],
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  metric['value'],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessIntelligenceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales & Revenue',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildSalesMetrics(),
          const SizedBox(height: 24),
          const Text(
            'Customer Metrics',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildCustomerMetrics(),
          const SizedBox(height: 24),
          const Text(
            'Business KPIs',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildBusinessKPIs(),
        ],
      ),
    );
  }

  Widget _buildSalesMetrics() {
    final sales = [
      {'label': 'Daily Revenue', 'value': '₹48,500', 'change': '+12.5%', 'color': Colors.green},
      {'label': 'Weekly Revenue', 'value': '₹3.25Cr', 'change': '+9.1%', 'color': Colors.green},
      {'label': 'Monthly Revenue', 'value': '₹13.8Cr', 'change': '+6.4%', 'color': Colors.green},
      {'label': 'GMV (Gross)', 'value': '₹15.2Cr', 'change': '+8.2%', 'color': Colors.blue},
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: sales.map((s) => _buildSalesCard(s)).toList(),
    );
  }

  Widget _buildSalesCard(Map<String, dynamic> sale) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              sale['label'],
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale['value'],
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    sale['change'],
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
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

  Widget _buildCustomerMetrics() {
    final customers = [
      {'label': 'Active Customers', 'value': '2,345', 'subtitle': 'Today'},
      {'label': 'New Customers', 'value': '145', 'subtitle': 'Last 7 days'},
      {'label': 'Avg CLV', 'value': '₹24,500', 'subtitle': 'Lifetime value'},
      {'label': 'Churn Rate', 'value': '3.2%', 'subtitle': '30-day inactive'},
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: customers.map((c) => _buildCustomerCard(c)).toList(),
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              customer['label'],
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer['value'],
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  customer['subtitle'],
                  style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessKPIs() {
    final kpis = [
      {
        'title': 'Profit Margin',
        'value': '28.5%',
        'subtitle': 'vs target 30%',
        'status': 'Good',
      },
      {
        'title': 'Operational Efficiency',
        'value': '82.3%',
        'subtitle': 'vs target 85%',
        'status': 'Good',
      },
      {
        'title': 'Market Share',
        'value': '12.4%',
        'subtitle': 'vs competitor avg',
        'status': 'Growing',
      },
      {
        'title': 'Customer Satisfaction',
        'value': '4.6★',
        'subtitle': 'NPS Score: 72',
        'status': 'Excellent',
      },
    ];

    return Column(
      children: kpis
          .map((kpi) => Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.grey[50],
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kpi['title'],
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            kpi['subtitle'],
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            kpi['value'],
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            kpi['status'],
                            style: TextStyle(fontSize: 10, color: Colors.green),
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

  Widget _buildAlertsTab() {
    final alerts = [
      {
        'severity': 'High',
        'title': 'Full Cream Milk stock critical',
        'description': 'Running out in 2 hours. Immediate reorder needed.',
        'color': Colors.red,
        'icon': Icons.warning,
        'action': 'Reorder Now',
      },
      {
        'severity': 'High',
        'title': '8 customers at churn risk',
        'description': '30+ days inactive. Launch re-engagement campaign.',
        'color': Colors.red,
        'icon': Icons.people,
        'action': 'Launch Campaign',
      },
      {
        'severity': 'Medium',
        'title': 'Delivery performance below target',
        'description': 'On-time rate: 88.5% (target: 95%)',
        'color': Colors.orange,
        'icon': Icons.local_shipping,
        'action': 'Review',
      },
      {
        'severity': 'Medium',
        'title': 'Payment gateway latency',
        'description': 'Average response time: 0.8s (target: 0.2s)',
        'color': Colors.orange,
        'icon': Icons.payment,
        'action': 'Investigate',
      },
    ];

    final actionItems = [
      'Approve pending bulk purchase order',
      'Review demand forecast for next week',
      'Process 5 pending refund requests',
      'Approve vendor price changes',
      'Review weekly performance report',
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Critical Alerts',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...alerts.map((alert) => _buildAlertItem(alert)).toList(),
        const SizedBox(height: 24),
        const Text(
          'Pending Actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...actionItems
            .asMap()
            .entries
            .map((entry) => _buildActionItem(entry.key + 1, entry.value))
            .toList(),
      ],
    );
  }

  Widget _buildAlertItem(Map<String, dynamic> alert) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: alert['color'].withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(alert['icon'], color: alert['color'], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      alert['severity'],
                      style: TextStyle(
                        fontSize: 11,
                        color: alert['color'],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: alert['color'],
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: Text(
                    alert['action'],
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              alert['title'],
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              alert['description'],
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(int index, String action) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                action,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsTab() {
    final quickActions = [
      {
        'title': 'Create Order',
        'subtitle': 'Manually create customer order',
        'icon': Icons.add_shopping_cart,
        'color': Colors.blue,
      },
      {
        'title': 'Dispatch Delivery',
        'subtitle': 'Assign order to rider',
        'icon': Icons.local_shipping,
        'color': Colors.orange,
      },
      {
        'title': 'Reorder Inventory',
        'subtitle': 'Create purchase order',
        'icon': Icons.add_circle,
        'color': Colors.green,
      },
      {
        'title': 'Issue Refund',
        'subtitle': 'Process customer refund',
        'icon': Icons.undo,
        'color': Colors.red,
      },
      {
        'title': 'Send Promo',
        'subtitle': 'Create & send promotion',
        'icon': Icons.send,
        'color': Colors.purple,
      },
      {
        'title': 'Generate Report',
        'subtitle': 'Export analytics report',
        'icon': Icons.assessment,
        'color': Colors.teal,
      },
      {
        'title': 'View Analytics',
        'subtitle': 'Access detailed dashboard',
        'icon': Icons.show_chart,
        'color': Colors.indigo,
      },
      {
        'title': 'Manage Staff',
        'subtitle': 'Add/edit employees',
        'icon': Icons.group_add,
        'color': Colors.pink,
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: quickActions.map((action) => _buildQuickActionCard(action)).toList(),
    );
  }

  Widget _buildQuickActionCard(Map<String, dynamic> action) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: action['color'].withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(action['icon'], color: action['color'], size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                action['title'],
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                action['subtitle'],
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
