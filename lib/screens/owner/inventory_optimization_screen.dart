import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class InventoryOptimizationScreen extends StatefulWidget {
  const InventoryOptimizationScreen({Key? key}) : super(key: key);

  @override
  State<InventoryOptimizationScreen> createState() =>
      _InventoryOptimizationScreenState();
}

class _InventoryOptimizationScreenState extends State<InventoryOptimizationScreen>
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
        title: const Text('Inventory Optimization'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabs: const [
            Tab(text: 'Health'),
            Tab(text: 'Optimization'),
            Tab(text: 'Turnover'),
            Tab(text: 'Insights'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHealthTab(),
          _buildOptimizationTab(),
          _buildTurnoverTab(),
          _buildInsightsTab(),
        ],
      ),
    );
  }

  Widget _buildHealthTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inventory Health Metrics',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildHealthMetricsGrid(),
          const SizedBox(height: 24),
          const Text(
            'Category Breakdown',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildCategoryBreakdown(),
        ],
      ),
    );
  }

  Widget _buildHealthMetricsGrid() {
    final metrics = [
      {
        'label': 'Total SKUs',
        'value': '2,450',
        'icon': Icons.inventory,
        'color': Colors.blue,
        'subtitle': 'Products in stock',
      },
      {
        'label': 'Inventory Value',
        'value': '₹24.5L',
        'icon': Icons.currency_rupee,
        'color': Colors.green,
        'subtitle': 'Total investment',
      },
      {
        'label': 'Turnover Ratio',
        'value': '4.2x',
        'icon': Icons.rotate_right,
        'color': Colors.orange,
        'subtitle': 'Times per year',
      },
      {
        'label': 'Health Score',
        'value': '78.5%',
        'icon': Icons.assessment,
        'color': Colors.purple,
        'subtitle': 'Overall health',
      },
      {
        'label': 'Stock-outs',
        'value': '8',
        'icon': Icons.warning,
        'color': Colors.red,
        'subtitle': 'Items out of stock',
      },
      {
        'label': 'Excess Stock',
        'value': '156',
        'icon': Icons.storage,
        'color': Colors.amber,
        'subtitle': 'Overstocked items',
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: metrics.map((metric) => _buildHealthMetricCard(metric)).toList(),
    );
  }

  Widget _buildHealthMetricCard(Map<String, dynamic> metric) {
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
                color: metric['color'].withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(metric['icon'], color: metric['color'], size: 18),
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  metric['subtitle'],
                  style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final categories = [
      {
        'category': 'Fresh Vegetables',
        'items': 245,
        'value': '₹3.2L',
        'turnover': 8.5,
        'health': 92,
        'color': Colors.green,
      },
      {
        'category': 'Dairy Products',
        'items': 156,
        'value': '₹2.8L',
        'turnover': 6.2,
        'health': 88,
        'color': Colors.blue,
      },
      {
        'category': 'Packaged Foods',
        'items': 892,
        'value': '₹8.1L',
        'turnover': 3.5,
        'health': 75,
        'color': Colors.orange,
      },
      {
        'category': 'Beverages',
        'items': 124,
        'value': '₹2.4L',
        'turnover': 5.8,
        'health': 85,
        'color': Colors.red,
      },
    ];

    return Column(
      children: categories.map((cat) => _buildCategoryCard(cat)).toList(),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final healthColor =
        category['health'] >= 85 ? Colors.green : category['health'] >= 75 ? Colors.orange : Colors.red;

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
                Text(
                  category['category'],
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: healthColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${category['health']}% Health',
                    style: TextStyle(
                      fontSize: 11,
                      color: healthColor,
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
                _buildCategoryMetric('Items', '${category['items']}'),
                _buildCategoryMetric('Value', category['value']),
                _buildCategoryMetric('Turnover', '${category['turnover']}x/yr'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (category['health'] as num) / 100,
                minHeight: 4,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(healthColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryMetric(String label, String value) {
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

  Widget _buildOptimizationTab() {
    final optimizations = [
      {
        'product': 'Tomatoes',
        'category': 'Fresh Vegetables',
        'suggestion': 'Increase stock - demand surge expected',
        'currentStock': 85,
        'recommendedStock': 120,
        'reorderPoint': 60,
        'priority': 'high',
        'potentialSavings': '₹2,400',
      },
      {
        'product': 'Full Cream Milk',
        'category': 'Dairy',
        'suggestion': 'Optimize reorder point to reduce stockouts',
        'currentStock': 45,
        'recommendedStock': 80,
        'reorderPoint': 40,
        'priority': 'high',
        'potentialSavings': '₹1,800',
      },
      {
        'product': 'Rice (10kg bag)',
        'category': 'Packaged Foods',
        'suggestion': 'Reduce stock - slow-moving item',
        'currentStock': 250,
        'recommendedStock': 120,
        'reorderPoint': 50,
        'priority': 'medium',
        'potentialSavings': '₹8,500',
      },
      {
        'product': 'Orange Juice',
        'category': 'Beverages',
        'suggestion': 'Implement batch ordering for discounts',
        'currentStock': 120,
        'recommendedStock': 150,
        'reorderPoint': 75,
        'priority': 'medium',
        'potentialSavings': '₹3,200',
      },
      {
        'product': 'Biscuits (Various)',
        'category': 'Snacks',
        'suggestion': 'Consolidate variants to reduce SKUs',
        'currentStock': 340,
        'recommendedStock': 220,
        'reorderPoint': 100,
        'priority': 'low',
        'potentialSavings': '₹5,600',
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
                  'Optimization Opportunities',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildOptSummaryStat('Total Suggestions', '${optimizations.length}'),
                    _buildOptSummaryStat('Potential Savings', '₹21.5K'),
                    _buildOptSummaryStat('High Priority', '2'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Product Recommendations',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...optimizations.map((opt) => _buildOptimizationCard(opt)).toList(),
      ],
    );
  }

  Widget _buildOptSummaryStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildOptimizationCard(Map<String, dynamic> opt) {
    final priorityColor = opt['priority'] == 'high'
        ? Colors.red
        : opt['priority'] == 'medium'
            ? Colors.orange
            : Colors.blue;

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
                        opt['product'],
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        opt['category'],
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    opt['priority'].toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      color: priorityColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              opt['suggestion'],
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Current: ${opt['currentStock']} → Recommended: ${opt['recommendedStock']} | Reorder: ${opt['reorderPoint']}',
                style: TextStyle(fontSize: 11, color: Colors.blue[800]),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Save ${opt['potentialSavings']}',
                    style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.tonal(
                  onPressed: () {},
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnoverTab() {
    final fastMoving = [
      {
        'product': 'Fresh Vegetables Mix',
        'turnover': 12.5,
        'unitsPerDay': 245,
        'daysInStock': 3.2,
        'status': 'Excellent',
        'color': Colors.green,
      },
      {
        'product': 'Milk & Yogurt',
        'turnover': 9.2,
        'unitsPerDay': 185,
        'daysInStock': 5.1,
        'status': 'Good',
        'color': Colors.blue,
      },
      {
        'product': 'Bread & Bakery',
        'turnover': 8.5,
        'unitsPerDay': 120,
        'daysInStock': 4.8,
        'status': 'Good',
        'color': Colors.blue,
      },
    ];

    final slowMoving = [
      {
        'product': 'Specialty Spices',
        'turnover': 1.2,
        'unitsPerDay': 8,
        'daysInStock': 125,
        'status': 'Critical',
        'color': Colors.red,
      },
      {
        'product': 'Premium Cereals',
        'turnover': 1.8,
        'unitsPerDay': 15,
        'daysInStock': 85,
        'status': 'Slow',
        'color': Colors.orange,
      },
      {
        'product': 'Imported Items',
        'turnover': 2.1,
        'unitsPerDay': 12,
        'daysInStock': 72,
        'status': 'Slow',
        'color': Colors.orange,
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Fast-Moving Items (High Turnover)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...fastMoving.map((item) => _buildTurnoverCard(item)).toList(),
        const SizedBox(height: 24),
        const Text(
          'Slow-Moving Items (Low Turnover)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...slowMoving.map((item) => _buildTurnoverCard(item)).toList(),
      ],
    );
  }

  Widget _buildTurnoverCard(Map<String, dynamic> item) {
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
                  child: Text(
                    item['product'],
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item['status'],
                    style: TextStyle(
                      fontSize: 11,
                      color: item['color'],
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
                _buildTurnoverMetric('Turnover', '${item['turnover']}x/yr'),
                _buildTurnoverMetric('Daily Sales', '${item['unitsPerDay']}'),
                _buildTurnoverMetric('Days in Stock', '${item['daysInStock']}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnoverMetric(String label, String value) {
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
        'type': 'Stockout Risk',
        'title': 'Full Cream Milk at critical level',
        'description': 'Current stock: 45 units, Running out in 2 days. Immediate reorder recommended.',
        'severity': 'high',
        'action': 'Reorder Now',
        'color': Colors.red,
      },
      {
        'type': 'Overstocking',
        'title': 'Rice accumulating excess inventory',
        'description': 'Stock exceeds 6-month requirement. Consider markdowns or promotions.',
        'severity': 'medium',
        'action': 'Plan Clearance',
        'color': Colors.orange,
      },
      {
        'type': 'Dead Stock',
        'title': '45 items not sold in 90 days',
        'description': 'These items are blocking capital. Recommend deep discounts or discontinuation.',
        'severity': 'medium',
        'action': 'Review',
        'color': Colors.orange,
      },
      {
        'type': 'Opportunity',
        'title': 'Tomatoes high-demand expected',
        'description': 'Forecast shows 25% demand increase next week. Stock up now for better margins.',
        'severity': 'low',
        'action': 'Bulk Order',
        'color': Colors.green,
      },
    ];

    final recommendations = [
      'Implement FIFO rotation for perishables to reduce waste',
      'Set up automated reorder alerts for critical items',
      'Consolidate slow-moving snack variants from 12 to 6 SKUs',
      'Negotiate bulk discounts for high-turnover items with suppliers',
      'Launch clearance promotion for 3-month-old packaged goods',
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Inventory Alerts',
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
