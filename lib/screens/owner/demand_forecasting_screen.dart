import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class DemandForecastingScreen extends StatefulWidget {
  const DemandForecastingScreen({Key? key}) : super(key: key);

  @override
  State<DemandForecastingScreen> createState() => _DemandForecastingScreenState();
}

class _DemandForecastingScreenState extends State<DemandForecastingScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedForecastDays = '7';

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
        title: const Text('Demand Forecasting'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Trends'),
            Tab(text: 'Products'),
            Tab(text: 'Insights'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildTrendsTab(),
          _buildProductsTab(),
          _buildInsightsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildForecastSelector(),
          const SizedBox(height: 16),
          const Text(
            'Forecast Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildForecastSummaryCards(),
          const SizedBox(height: 24),
          const Text(
            'Hourly Forecast',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildHourlyForecast(),
        ],
      ),
    );
  }

  Widget _buildForecastSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildDaysButton('3 Days', '3'),
        const SizedBox(width: 8),
        _buildDaysButton('7 Days', '7'),
        const SizedBox(width: 8),
        _buildDaysButton('30 Days', '30'),
      ],
    );
  }

  Widget _buildDaysButton(String label, String days) {
    final isSelected = _selectedForecastDays == days;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedForecastDays = days;
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

  Widget _buildForecastSummaryCards() {
    final summaryData = [
      {
        'label': 'Predicted Orders',
        'value': '1,245',
        'icon': Icons.shopping_cart,
        'color': Colors.blue,
        'change': '+8.5%',
        'range': '1,100 - 1,400',
      },
      {
        'label': 'Avg Order Value',
        'value': '₹285',
        'icon': Icons.trending_up,
        'color': Colors.green,
        'change': '+5.2%',
        'range': '₹260 - ₹310',
      },
      {
        'label': 'Peak Hours',
        'value': '18-20',
        'icon': Icons.schedule,
        'color': Colors.orange,
        'change': '9 PM - 11 PM',
        'range': 'High traffic period',
      },
      {
        'label': 'Confidence',
        'value': '94.2%',
        'icon': Icons.check_circle,
        'color': Colors.purple,
        'change': 'High accuracy',
        'range': 'Based on 180 days',
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: summaryData.map((data) => _buildForecastCard(data)).toList(),
    );
  }

  Widget _buildForecastCard(Map<String, dynamic> data) {
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: data['color'].withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(data['icon'], color: data['color'], size: 18),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['label'],
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  data['value'],
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  data['range'],
                  style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyForecast() {
    final hourlyData = [
      {'hour': '8 AM', 'orders': 45, 'confidence': 92},
      {'hour': '10 AM', 'orders': 62, 'confidence': 90},
      {'hour': '12 PM', 'orders': 95, 'confidence': 88},
      {'hour': '2 PM', 'orders': 58, 'confidence': 91},
      {'hour': '4 PM', 'orders': 75, 'confidence': 89},
      {'hour': '6 PM', 'orders': 120, 'confidence': 93},
      {'hour': '8 PM', 'orders': 156, 'confidence': 95},
      {'hour': '10 PM', 'orders': 134, 'confidence': 94},
    ];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expected Orders by Hour',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Hourly Chart Visualization',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: hourlyData.map((data) {
                final maxOrders = 156.0;
                final percentage = (data['orders'] as num) / maxOrders;
                return SizedBox(
                  width: (MediaQuery.of(context).size.width - 64) / 4,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(percentage.toDouble()),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['hour'],
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${data['orders']}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                );
              }).toList(),
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
            'Demand Trend Analysis',
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
                          Icon(Icons.trending_up, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Trend Chart Visualization',
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
                      _TrendLegend(label: 'Actual', color: Colors.blue),
                      _TrendLegend(label: 'Forecast', color: Colors.orange),
                      _TrendLegend(label: 'Lower Bound', color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Seasonal Patterns',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildSeasonalPatterns(),
          const SizedBox(height: 24),
          const Text(
            'Weekly Comparison',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildWeeklyComparison(),
        ],
      ),
    );
  }

  Widget _buildSeasonalPatterns() {
    final patterns = [
      {
        'day': 'Mondays',
        'pattern': 'Lowest demand',
        'avgOrders': 850,
        'variance': '-15%',
        'color': Colors.grey,
      },
      {
        'day': 'Wednesdays',
        'pattern': 'Moderate demand',
        'avgOrders': 1050,
        'variance': '+5%',
        'color': Colors.blue,
      },
      {
        'day': 'Fridays',
        'pattern': 'High demand',
        'avgOrders': 1450,
        'variance': '+22%',
        'color': Colors.orange,
      },
      {
        'day': 'Sundays',
        'pattern': 'Highest demand',
        'avgOrders': 1680,
        'variance': '+35%',
        'color': Colors.green,
      },
    ];

    return Column(
      children: patterns
          .map((pattern) => Card(
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
                                pattern['day'],
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                pattern['pattern'],
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: pattern['color'].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pattern['variance'],
                              style: TextStyle(
                                fontSize: 11,
                                color: pattern['color'],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Avg: ${pattern['avgOrders']} orders',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildWeeklyComparison() {
    final weeks = [
      {
        'week': 'This Week',
        'actual': 7850,
        'forecast': 7920,
        'accuracy': 99.1,
      },
      {
        'week': 'Last Week',
        'actual': 7420,
        'forecast': 7450,
        'accuracy': 99.6,
      },
      {
        'week': 'Two Weeks Ago',
        'actual': 8120,
        'forecast': 8050,
        'accuracy': 98.1,
      },
    ];

    return Column(
      children: weeks
          .map((week) => Card(
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
                            week['week'],
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${week['accuracy']}% accuracy',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.green,
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Actual',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                              Text(
                                '${week['actual']} orders',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Forecast',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                              Text(
                                '${week['forecast']} orders',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
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

  Widget _buildProductsTab() {
    final productForecasts = [
      {
        'product': 'Fresh Vegetables',
        'category': 'Produce',
        'forecast': 425,
        'lastWeek': 410,
        'confidence': 96,
        'trend': '+3.7%',
        'trendColor': Colors.green,
      },
      {
        'product': 'Dairy Products',
        'category': 'Dairy',
        'forecast': 320,
        'lastWeek': 305,
        'confidence': 94,
        'trend': '+4.9%',
        'trendColor': Colors.green,
      },
      {
        'product': 'Packaged Foods',
        'category': 'Grocery',
        'forecast': 580,
        'lastWeek': 610,
        'confidence': 91,
        'trend': '-4.9%',
        'trendColor': Colors.red,
      },
      {
        'product': 'Beverages',
        'category': 'Drinks',
        'forecast': 290,
        'lastWeek': 280,
        'confidence': 89,
        'trend': '+3.6%',
        'trendColor': Colors.green,
      },
      {
        'product': 'Snacks',
        'category': 'Snacks',
        'forecast': 215,
        'lastWeek': 195,
        'confidence': 87,
        'trend': '+10.3%',
        'trendColor': Colors.green,
      },
      {
        'product': 'Frozen Items',
        'category': 'Frozen',
        'forecast': 145,
        'lastWeek': 160,
        'confidence': 85,
        'trend': '-9.4%',
        'trendColor': Colors.red,
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
                  'Product Demand Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildProductSummaryStat('Total Products', '6'),
                    _buildProductSummaryStat('Avg Forecast', '496'),
                    _buildProductSummaryStat('Avg Confidence', '93.7%'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Category Forecasts',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...productForecasts
            .map((product) => _buildProductForecastCard(product))
            .toList(),
      ],
    );
  }

  Widget _buildProductSummaryStat(String label, String value) {
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

  Widget _buildProductForecastCard(Map<String, dynamic> product) {
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
                        product['product'],
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        product['category'],
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: product['trendColor'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    product['trend'],
                    style: TextStyle(
                      fontSize: 11,
                      color: product['trendColor'],
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Forecast',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                    Text(
                      '${product['forecast']} units',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Last Week',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                    Text(
                      '${product['lastWeek']} units',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Confidence',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                    Text(
                      '${product['confidence']}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

  Widget _buildInsightsTab() {
    final insights = [
      {
        'type': 'High Demand Alert',
        'title': 'Vegetables expected to surge 15% next week',
        'description': 'Based on seasonal patterns and upcoming festival, stock up accordingly',
        'severity': 'high',
        'action': 'Increase Stock',
        'color': Colors.red,
      },
      {
        'type': 'Trend Change',
        'title': 'Snacks demand trending +10.3% weekly',
        'description': 'Consistent growth detected. Consider expanding snacks inventory.',
        'severity': 'medium',
        'action': 'Plan Replenishment',
        'color': Colors.orange,
      },
      {
        'type': 'Prediction Confidence',
        'title': 'Forecast accuracy up to 94.2%',
        'description': 'Model is becoming more accurate with recent data patterns',
        'severity': 'low',
        'action': 'View Details',
        'color': Colors.green,
      },
      {
        'type': 'Anomaly Detection',
        'title': 'Frozen items showing unexpected decline',
        'description': 'Investigate supply chain or competitor activity for this category',
        'severity': 'medium',
        'action': 'Investigate',
        'color': Colors.orange,
      },
    ];

    final recommendations = [
      'Increase vegetable stock by 20% for weekend peak',
      'Optimize dairy product ordering for weekday demand',
      'Launch promotion for frozen items to reverse -9.4% decline',
      'Plan extra delivery capacity for 6-8 PM peak hours',
      'Consider bulk purchasing for packaged foods at volume discounts',
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'AI Insights & Alerts',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...insights.map((insight) => _buildInsightCard(insight)).toList(),
        const SizedBox(height: 24),
        const Text(
          'Actionable Recommendations',
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

  Widget _buildInsightCard(Map<String, dynamic> insight) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: insight['color'].withOpacity(0.05),
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
                        insight['type'],
                        style: TextStyle(fontSize: 11, color: insight['color']),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        insight['title'],
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: insight['color'],
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              insight['description'],
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: insight['color']),
                  foregroundColor: insight['color'],
                ),
                child: Text(insight['action']),
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

class _TrendLegend extends StatelessWidget {
  final String label;
  final Color color;

  const _TrendLegend({
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
