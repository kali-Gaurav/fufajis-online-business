import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class CustomerIntelligenceScreen extends StatefulWidget {
  const CustomerIntelligenceScreen({Key? key}) : super(key: key);

  @override
  State<CustomerIntelligenceScreen> createState() =>
      _CustomerIntelligenceScreenState();
}

class _CustomerIntelligenceScreenState extends State<CustomerIntelligenceScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

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
        title: const Text('Customer Intelligence'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabs: const [
            Tab(text: 'Segments'),
            Tab(text: 'Behavior'),
            Tab(text: 'Lifetime Value'),
            Tab(text: 'Insights'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSegmentsTab(),
          _buildBehaviorTab(),
          _buildLTVTab(),
          _buildInsightsTab(),
        ],
      ),
    );
  }

  Widget _buildSegmentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Segmentation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildSegmentationOverview(),
          const SizedBox(height: 24),
          const Text(
            'Segment Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildSegmentCards(),
        ],
      ),
    );
  }

  Widget _buildSegmentationOverview() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pie_chart, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Segment Distribution Chart',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _SegmentLegend(label: 'VIP', color: Colors.purple),
                _SegmentLegend(label: 'Regular', color: Colors.blue),
                _SegmentLegend(label: 'At Risk', color: Colors.red),
                _SegmentLegend(label: 'New', color: Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentCards() {
    final segments = [
      {
        'segment': 'VIP Customers',
        'description': 'High-value, frequent buyers',
        'count': 245,
        'percentage': 8.2,
        'avgOrderValue': '₹850',
        'frequency': '4.2x/week',
        'retention': 94.5,
        'color': Colors.purple,
        'icon': Icons.star,
      },
      {
        'segment': 'Regular Customers',
        'description': 'Consistent, loyal buyers',
        'count': 1850,
        'percentage': 62.1,
        'avgOrderValue': '₹420',
        'frequency': '2.1x/week',
        'retention': 72.3,
        'color': Colors.blue,
        'icon': Icons.person,
      },
      {
        'segment': 'At-Risk Customers',
        'description': 'Decreasing purchase frequency',
        'count': 680,
        'percentage': 22.8,
        'avgOrderValue': '₹280',
        'frequency': '0.6x/week',
        'retention': 35.2,
        'color': Colors.red,
        'icon': Icons.warning,
      },
      {
        'segment': 'New Customers',
        'description': 'Recently acquired users',
        'count': 225,
        'percentage': 6.9,
        'avgOrderValue': '₹350',
        'frequency': '1.1x/week',
        'retention': 58.4,
        'color': Colors.green,
        'icon': Icons.new_releases,
      },
    ];

    return Column(
      children: segments.map((segment) => _buildSegmentCard(segment)).toList(),
    );
  }

  Widget _buildSegmentCard(Map<String, dynamic> segment) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: segment['color'].withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(segment['icon'], color: segment['color'], size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        segment['segment'],
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        segment['description'],
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: segment['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${segment['count']} customers (${segment['percentage']}%)',
                style: TextStyle(
                  fontSize: 12,
                  color: segment['color'],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSegmentMetric('Avg Order', segment['avgOrderValue']),
                _buildSegmentMetric('Frequency', segment['frequency']),
                _buildSegmentMetric('Retention', '${segment['retention']}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentMetric(String label, String value) {
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

  Widget _buildBehaviorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Purchase Behavior Analysis',
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
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.show_chart, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Behavior Pattern Chart',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Purchase Frequency Trends',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildFrequencyTrends(),
          const SizedBox(height: 24),
          const Text(
            'Category Preferences',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildCategoryPreferences(),
        ],
      ),
    );
  }

  Widget _buildFrequencyTrends() {
    final trends = [
      {
        'frequency': 'Daily',
        'customers': 420,
        'percentage': 14.1,
        'avgSpend': '₹185',
        'trend': '+8%',
        'trendColor': Colors.green,
      },
      {
        'frequency': '2-3x/Week',
        'customers': 1240,
        'percentage': 41.6,
        'avgSpend': '₹450',
        'trend': '+4%',
        'trendColor': Colors.green,
      },
      {
        'frequency': 'Weekly',
        'customers': 980,
        'percentage': 32.9,
        'avgSpend': '₹520',
        'trend': '+2%',
        'trendColor': Colors.green,
      },
      {
        'frequency': 'Bi-weekly',
        'customers': 360,
        'percentage': 11.4,
        'avgSpend': '₹680',
        'trend': '-3%',
        'trendColor': Colors.red,
      },
    ];

    return Column(
      children: trends
          .map((trend) => Card(
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
                                trend['frequency'],
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${trend['customers']} customers',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: trend['trendColor'].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              trend['trend'],
                              style: TextStyle(
                                fontSize: 11,
                                color: trend['trendColor'],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${trend['percentage']}% of customer base',
                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                          ),
                          Text(
                            'Avg spend: ${trend['avgSpend']}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
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

  Widget _buildCategoryPreferences() {
    final categories = [
      {
        'category': 'Fresh Vegetables',
        'popularity': 92,
        'avgOrder': '₹245',
        'customers': 2450,
        'color': Colors.green,
      },
      {
        'category': 'Dairy Products',
        'popularity': 85,
        'avgOrder': '₹320',
        'customers': 2150,
        'color': Colors.blue,
      },
      {
        'category': 'Packaged Foods',
        'popularity': 78,
        'avgOrder': '₹180',
        'customers': 1980,
        'color': Colors.orange,
      },
      {
        'category': 'Beverages',
        'popularity': 72,
        'avgOrder': '₹95',
        'customers': 1650,
        'color': Colors.red,
      },
    ];

    return Column(
      children: categories
          .map((cat) => Card(
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
                            cat['category'],
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: cat['color'].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${cat['customers']} customers',
                              style: TextStyle(
                                fontSize: 11,
                                color: cat['color'],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (cat['popularity'] as num) / 100,
                          minHeight: 4,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(cat['color']),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Popularity: ${cat['popularity']}%',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                          Text(
                            'Avg: ${cat['avgOrder']}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
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

  Widget _buildLTVTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Lifetime Value Analysis',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LTV Overview',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLTVSummaryStat('Avg Customer LTV', '₹24,500'),
                      _buildLTVSummaryStat('Total Customer Value', '₹7.35Cr'),
                      _buildLTVSummaryStat('Projected Growth', '+12%'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'LTV by Customer Segment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildLTVSegments(),
          const SizedBox(height: 24),
          const Text(
            'Top Value Customers',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTopValueCustomers(),
        ],
      ),
    );
  }

  Widget _buildLTVSummaryStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildLTVSegments() {
    final segments = [
      {
        'segment': 'VIP Customers',
        'avgLTV': '₹145,000',
        'customers': 245,
        'totalValue': '₹35.5Cr',
        'trend': '+18%',
        'color': Colors.purple,
      },
      {
        'segment': 'Regular Customers',
        'avgLTV': '₹42,500',
        'customers': 1850,
        'totalValue': '₹78.6Cr',
        'trend': '+8%',
        'color': Colors.blue,
      },
      {
        'segment': 'At-Risk Customers',
        'avgLTV': '₹12,800',
        'customers': 680,
        'totalValue': '₹8.7Cr',
        'trend': '-15%',
        'color': Colors.red,
      },
      {
        'segment': 'New Customers',
        'avgLTV': '₹8,500',
        'customers': 225,
        'totalValue': '₹1.9Cr',
        'trend': '+25%',
        'color': Colors.green,
      },
    ];

    return Column(
      children: segments
          .map((seg) => Card(
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
                          Text(
                            seg['segment'],
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: seg['color'].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              seg['trend'],
                              style: TextStyle(
                                fontSize: 11,
                                color: seg['color'],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLTVMetric('Avg LTV', seg['avgLTV']),
                          _buildLTVMetric('Customers', '${seg['customers']}'),
                          _buildLTVMetric('Total Value', seg['totalValue']),
                        ],
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildLTVMetric(String label, String value) {
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

  Widget _buildTopValueCustomers() {
    final topCustomers = [
      {
        'rank': 1,
        'name': 'Rajesh Gupta',
        'totalSpend': '₹125,400',
        'orders': 284,
        'avgOrder': '₹442',
        'lastOrder': '2 hrs ago',
      },
      {
        'rank': 2,
        'name': 'Priya Patel',
        'totalSpend': '₹98,600',
        'orders': 212,
        'avgOrder': '₹465',
        'lastOrder': '5 hrs ago',
      },
      {
        'rank': 3,
        'name': 'Amit Kumar',
        'totalSpend': '₹87,250',
        'orders': 195,
        'avgOrder': '₹447',
        'lastOrder': '1 day ago',
      },
      {
        'rank': 4,
        'name': 'Sneha Sharma',
        'totalSpend': '₹76,800',
        'orders': 168,
        'avgOrder': '₹457',
        'lastOrder': '3 days ago',
      },
    ];

    return Column(
      children: topCustomers
          .map((customer) => Card(
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
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '#${customer['rank']}',
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
                                  customer['name'],
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Last order: ${customer['lastOrder']}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                          _buildCustomerMetric('Total Spend', customer['totalSpend']),
                          _buildCustomerMetric('Orders', '${customer['orders']}'),
                          _buildCustomerMetric('Avg Order', customer['avgOrder']),
                        ],
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCustomerMetric(String label, String value) {
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

  Widget _buildInsightsTab() {
    final alerts = [
      {
        'type': 'Churn Risk',
        'title': '245 customers at high churn risk',
        'description': '30-day inactive customers. Recommend re-engagement campaigns.',
        'severity': 'high',
        'action': 'Launch Campaign',
        'color': Colors.red,
      },
      {
        'type': 'Growth Opportunity',
        'title': 'VIP segment growing 18% YoY',
        'description': 'High engagement and retention. Invest in premium offerings.',
        'severity': 'low',
        'action': 'Plan Premium',
        'color': Colors.green,
      },
      {
        'type': 'Segment Shift',
        'title': 'Regular segment dropping from 68% to 62%',
        'description': 'Customers moving to at-risk or VIP. Investigate causes.',
        'severity': 'medium',
        'action': 'Analyze',
        'color': Colors.orange,
      },
      {
        'type': 'Opportunity',
        'title': 'Daily purchasers spend 2x more monthly',
        'description': 'Encourage frequency increase through loyalty programs.',
        'severity': 'low',
        'action': 'Create Program',
        'color': Colors.blue,
      },
    ];

    final recommendations = [
      'Launch targeted re-engagement campaign for at-risk segment',
      'Create VIP rewards program to retain high-value customers',
      'Implement personalized product recommendations based on category preferences',
      'Setup automated churn alerts for customers with 30+ days inactivity',
      'Develop frequency-based incentives to move weekly to daily customers',
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Customer Insights & Alerts',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...alerts.map((alert) => _buildAlertCard(alert)).toList(),
        const SizedBox(height: 24),
        const Text(
          'Strategic Recommendations',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...recommendations
            .asMap()
            .entries
            .map((entry) => _buildRecommendationCard(entry.key + 1, entry.value))
            .toList(),
      ],
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert['type'],
                        style: TextStyle(fontSize: 11, color: alert['color']),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alert['title'],
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: alert['color'],
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              alert['description'],
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: alert['color']),
                  foregroundColor: alert['color'],
                ),
                child: Text(alert['action']),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(int index, String recommendation) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              child: Text(
                recommendation,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentLegend extends StatelessWidget {
  final String label;
  final Color color;

  const _SegmentLegend({
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
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
