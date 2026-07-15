import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class DeliveryPerformanceAnalyticsScreen extends StatefulWidget {
  const DeliveryPerformanceAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<DeliveryPerformanceAnalyticsScreen> createState() =>
      _DeliveryPerformanceAnalyticsScreenState();
}

class _DeliveryPerformanceAnalyticsScreenState
    extends State<DeliveryPerformanceAnalyticsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'week';

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
      appBar: AppBar(
        title: const Text('Delivery Performance Analytics'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabs: const [
            Tab(text: 'Metrics'),
            Tab(text: 'Trends'),
            Tab(text: 'Riders'),
            Tab(text: 'Zones'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMetricsTab(),
          _buildTrendsTab(),
          _buildRidersTab(),
          _buildZonesTab(),
        ],
      ),
    );
  }

  Widget _buildMetricsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: 16),
          const Text(
            'Today\'s Performance',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildMetricsGrid(),
          const SizedBox(height: 24),
          const Text(
            'Detailed Metrics',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildDetailedMetricsList(),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildPeriodButton('Today', 'today'),
        const SizedBox(width: 8),
        _buildPeriodButton('Week', 'week'),
        const SizedBox(width: 8),
        _buildPeriodButton('Month', 'month'),
      ],
    );
  }

  Widget _buildPeriodButton(String label, String period) {
    final isSelected = _selectedPeriod == period;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        elevation: 0,
      ),
      child: Text(label),
    );
  }

  Widget _buildMetricsGrid() {
    final metrics = [
      {
        'label': 'Total Deliveries',
        'value': '156',
        'icon': Icons.local_shipping,
        'color': Colors.blue,
        'change': '+12.5%',
      },
      {
        'label': 'On-Time Rate',
        'value': '94.2%',
        'icon': Icons.access_time,
        'color': Colors.green,
        'change': '+2.1%',
      },
      {
        'label': 'Avg Completion',
        'value': '42 min',
        'icon': Icons.timer,
        'color': Colors.orange,
        'change': '-5%',
      },
      {
        'label': 'Customer Rating',
        'value': '4.7★',
        'icon': Icons.star,
        'color': Colors.amber,
        'change': '+0.2★',
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: metrics.map((metric) => _buildMetricCard(metric)).toList(),
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> metric) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: metric['color'].withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(metric['icon'], color: metric['color'], size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric['label'],
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  metric['value'],
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  metric['change'],
                  style: TextStyle(
                    fontSize: 11,
                    color: metric['change'].startsWith('+') ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedMetricsList() {
    final detailedMetrics = [
      {
        'name': 'Successful Deliveries',
        'value': '147',
        'percentage': 94.2,
        'color': Colors.green,
      },
      {
        'name': 'Cancelled Deliveries',
        'value': '5',
        'percentage': 3.2,
        'color': Colors.red,
      },
      {
        'name': 'Failed/Retry Deliveries',
        'value': '4',
        'percentage': 2.6,
        'color': Colors.orange,
      },
      {
        'name': 'Avg Distance per Delivery',
        'value': '1.8 km',
        'percentage': 90.0,
        'color': Colors.blue,
      },
      {
        'name': 'Avg Revenue per Delivery',
        'value': '₹42',
        'percentage': 85.0,
        'color': Colors.purple,
      },
      {
        'name': 'Return Rate',
        'value': '0.8%',
        'percentage': 15.0,
        'color': Colors.red,
      },
    ];

    return Column(
      children: detailedMetrics.map((metric) => _buildDetailedMetricRow(metric)).toList(),
    );
  }

  Widget _buildDetailedMetricRow(Map<String, dynamic> metric) {
    return Card(
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
                Text(
                  metric['name'],
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  metric['value'],
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (metric['percentage'] as num) / 100,
                minHeight: 4,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(metric['color']),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Trend',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: _buildTrendChart(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      _TrendLegendItem(label: 'Deliveries', color: Colors.blue),
                      _TrendLegendItem(label: 'On-Time %', color: Colors.green),
                      _TrendLegendItem(label: 'Avg Time', color: Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Performance Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTrendSummary(),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Trend Chart Visualization',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendSummary() {
    final summaryData = [
      {
        'period': 'This Week',
        'deliveries': '892',
        'onTime': '93.8%',
        'avgTime': '43 min',
        'rating': '4.6★',
      },
      {
        'period': 'Last Week',
        'deliveries': '814',
        'onTime': '91.2%',
        'avgTime': '45 min',
        'rating': '4.5★',
      },
      {
        'period': 'This Month',
        'deliveries': '3654',
        'onTime': '92.1%',
        'avgTime': '44 min',
        'rating': '4.6★',
      },
    ];

    return Column(
      children: summaryData
          .map((data) => _buildSummaryCard(data))
          .toList(),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> data) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['period'],
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryMetric('Deliveries', data['deliveries']),
                _buildSummaryMetric('On-Time', data['onTime']),
                _buildSummaryMetric('Avg Time', data['avgTime']),
                _buildSummaryMetric('Rating', data['rating']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildRidersTab() {
    final riderStats = [
      {
        'rank': 1,
        'name': 'Ramesh Kumar',
        'deliveries': 215,
        'onTime': 96.2,
        'rating': 4.8,
        'earnings': '₹18,450',
        'efficiency': 92.5,
        'status': 'Top Performer',
        'statusColor': Colors.green,
      },
      {
        'rank': 2,
        'name': 'Priya Sharma',
        'deliveries': 187,
        'onTime': 93.5,
        'rating': 4.6,
        'earnings': '₹15,890',
        'efficiency': 88.0,
        'status': 'Good Performer',
        'statusColor': Colors.blue,
      },
      {
        'rank': 3,
        'name': 'Amit Patel',
        'deliveries': 156,
        'onTime': 91.8,
        'rating': 4.5,
        'earnings': '₹13,240',
        'efficiency': 85.0,
        'status': 'Consistent',
        'statusColor': Colors.orange,
      },
      {
        'rank': 4,
        'name': 'Vijay Singh',
        'deliveries': 142,
        'onTime': 89.2,
        'rating': 4.3,
        'earnings': '₹12,100',
        'efficiency': 82.0,
        'status': 'Need Support',
        'statusColor': Colors.red,
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Riders Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildRiderSummaryStat('Active Riders', '4'),
                    _buildRiderSummaryStat('Avg Rating', '4.6★'),
                    _buildRiderSummaryStat('Avg Efficiency', '87.1%'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Rider Rankings',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...riderStats.map((rider) => _buildRiderCard(rider)).toList(),
      ],
    );
  }

  Widget _buildRiderSummaryStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildRiderCard(Map<String, dynamic> rider) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: rider['statusColor'].withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '#${rider['rank']}',
                      style: TextStyle(
                        color: rider['statusColor'],
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
                        rider['name'],
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        rider['status'],
                        style: TextStyle(fontSize: 11, color: rider['statusColor']),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        '${rider['rating']}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildRiderMetric('Deliveries', '${rider['deliveries']}'),
                _buildRiderMetric('On-Time', '${rider['onTime']}%'),
                _buildRiderMetric('Efficiency', '${rider['efficiency']}%'),
                _buildRiderMetric('Earnings', rider['earnings']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildZonesTab() {
    final zoneStats = [
      {
        'zone': 'Zone A - Downtown',
        'deliveries': 245,
        'onTime': 95.2,
        'avgTime': 38,
        'rating': 4.7,
        'efficiency': 91.5,
        'activeRiders': 3,
        'trend': '+12%',
      },
      {
        'zone': 'Zone B - Suburbs',
        'deliveries': 189,
        'onTime': 92.1,
        'avgTime': 42,
        'rating': 4.6,
        'efficiency': 88.2,
        'activeRiders': 2,
        'trend': '+8%',
      },
      {
        'zone': 'Zone C - Residential',
        'deliveries': 156,
        'onTime': 93.8,
        'avgTime': 40,
        'rating': 4.8,
        'efficiency': 89.5,
        'activeRiders': 2,
        'trend': '+15%',
      },
      {
        'zone': 'Zone D - Industrial',
        'deliveries': 92,
        'onTime': 90.5,
        'avgTime': 35,
        'rating': 4.4,
        'efficiency': 85.2,
        'activeRiders': 1,
        'trend': '+5%',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Zone Coverage',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildZoneSummaryStat('Active Zones', '4'),
                    _buildZoneSummaryStat('Total Deliveries', '682'),
                    _buildZoneSummaryStat('Avg Rating', '4.6★'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Zone Performance',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...zoneStats.map((zone) => _buildZoneCard(zone)).toList(),
      ],
    );
  }

  Widget _buildZoneSummaryStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildZoneCard(Map<String, dynamic> zone) {
    final trendIsPositive = zone['trend'].startsWith('+');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                      Text(
                        zone['zone'],
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${zone['activeRiders']} active riders',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: trendIsPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    zone['trend'],
                    style: TextStyle(
                      fontSize: 11,
                      color: trendIsPositive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildZoneMetric('Deliveries', '${zone['deliveries']}'),
                _buildZoneMetric('On-Time', '${zone['onTime']}%'),
                _buildZoneMetric('Avg Time', '${zone['avgTime']} min'),
                _buildZoneMetric('Rating', '${zone['rating']}★'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (zone['efficiency'] as num) / 100,
                minHeight: 4,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _TrendLegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _TrendLegendItem({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
