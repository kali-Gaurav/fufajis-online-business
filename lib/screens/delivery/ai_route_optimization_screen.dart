import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class AIRouteOptimizationScreen extends StatefulWidget {
  const AIRouteOptimizationScreen({Key? key}) : super(key: key);

  @override
  State<AIRouteOptimizationScreen> createState() => _AIRouteOptimizationScreenState();
}

class _AIRouteOptimizationScreenState extends State<AIRouteOptimizationScreen>
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
        title: const Text('AI Route Optimization'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabs: const [
            Tab(text: 'Active Routes'),
            Tab(text: 'Optimization'),
            Tab(text: 'Traffic'),
            Tab(text: 'Performance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveRoutesTab(),
          _buildOptimizationTab(),
          _buildTrafficAnalysisTab(),
          _buildPerformanceMetricsTab(),
        ],
      ),
    );
  }

  Widget _buildActiveRoutesTab() {
    final activeRoutes = [
      {
        'routeId': 'ROUTE-001',
        'riderId': 'RIDER-001',
        'riderName': 'Ramesh Kumar',
        'deliveries': 8,
        'completed': 3,
        'remaining': 5,
        'distance': '12.5 km',
        'eta': '45 mins',
        'efficiency': 92.5,
        'waypoints': ['Loc A', 'Loc B', 'Loc C', 'Loc D', 'Loc E'],
        'status': 'in_progress',
      },
      {
        'routeId': 'ROUTE-002',
        'riderId': 'RIDER-002',
        'riderName': 'Priya Sharma',
        'deliveries': 6,
        'completed': 2,
        'remaining': 4,
        'distance': '8.3 km',
        'eta': '32 mins',
        'efficiency': 88.0,
        'waypoints': ['Loc F', 'Loc G', 'Loc H'],
        'status': 'in_progress',
      },
      {
        'routeId': 'ROUTE-003',
        'riderId': 'RIDER-003',
        'riderName': 'Amit Patel',
        'deliveries': 7,
        'completed': 1,
        'remaining': 6,
        'distance': '14.2 km',
        'eta': '58 mins',
        'efficiency': 85.0,
        'waypoints': ['Loc I', 'Loc J', 'Loc K'],
        'status': 'in_progress',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Routes Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryItem('Active Routes', '${activeRoutes.length}', Colors.blue),
                    _buildSummaryItem('Total Deliveries', '21', Colors.orange),
                    _buildSummaryItem('Avg Efficiency', '88.5%', Colors.green),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...activeRoutes.map((route) => _buildRouteCard(route)).toList(),
      ],
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    final progress = route['completed'] / route['deliveries'];
    final efficiencyColor = route['efficiency'] >= 90
        ? Colors.green
        : route['efficiency'] >= 80
            ? Colors.orange
            : Colors.red;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      Text(
                        '${route['routeId']} • ${route['riderName']}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${route['deliveries']} deliveries',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: efficiencyColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${route['efficiency']}% Efficient',
                    style: TextStyle(fontSize: 12, color: efficiencyColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 0.75 ? Colors.green : progress >= 0.5 ? Colors.orange : Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${route['completed']}/${route['deliveries']} completed',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  'ETA: ${route['eta']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Distance: ${route['distance']} • Waypoints: ${route['waypoints'].length}',
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.tonal(
                onPressed: () {},
                child: const Text('View Route Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimizationTab() {
    final optimizationSuggestions = [
      {
        'type': 'Route Reordering',
        'description': 'Reorder waypoints 3→4→2 for 15% time savings',
        'impact': '+15% faster',
        'priority': 'high',
        'route': 'ROUTE-001',
      },
      {
        'type': 'Stop Consolidation',
        'description': 'Combine 2 nearby stops in zone C',
        'impact': '+2 min saved',
        'priority': 'medium',
        'route': 'ROUTE-002',
      },
      {
        'type': 'Traffic Avoidance',
        'description': 'Use alternate route to avoid peak traffic',
        'impact': '+8 min saved',
        'priority': 'high',
        'route': 'ROUTE-003',
      },
      {
        'type': 'Delivery Window Optimization',
        'description': 'Adjust delivery sequence for time windows',
        'impact': '+12% compliance',
        'priority': 'medium',
        'route': 'ROUTE-001',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Optimization Algorithm Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildAlgorithmToggle('Real-time Optimization', true),
                const SizedBox(height: 12),
                _buildAlgorithmToggle('Traffic-Aware Routing', true),
                const SizedBox(height: 12),
                _buildAlgorithmToggle('Delivery Window Compliance', true),
                const SizedBox(height: 12),
                _buildAlgorithmToggle('Driver Preference Learning', false),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Active Suggestions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...optimizationSuggestions.map((suggestion) => _buildSuggestionCard(suggestion)).toList(),
      ],
    );
  }

  Widget _buildAlgorithmToggle(String label, bool value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Switch(
          value: value,
          onChanged: (val) {
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> suggestion) {
    final priorityColor = suggestion['priority'] == 'high' ? Colors.red : Colors.orange;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      Text(
                        suggestion['type'],
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        suggestion['route'],
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                    suggestion['priority'].toUpperCase(),
                    style: TextStyle(fontSize: 11, color: priorityColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              suggestion['description'],
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Impact: ${suggestion['impact']}',
                style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrafficAnalysisTab() {
    final trafficZones = [
      {
        'zone': 'Zone A (Downtown)',
        'congestion': 'High',
        'level': 85,
        'color': Colors.red,
        'avgDelay': '12 mins',
        'affectedDeliveries': 3,
      },
      {
        'zone': 'Zone B (Suburbs)',
        'congestion': 'Medium',
        'level': 55,
        'color': Colors.orange,
        'avgDelay': '4 mins',
        'affectedDeliveries': 2,
      },
      {
        'zone': 'Zone C (Residential)',
        'congestion': 'Low',
        'level': 25,
        'color': Colors.green,
        'avgDelay': '1 min',
        'affectedDeliveries': 0,
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Network Congestion Map',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on, size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'Map View (Placeholder)',
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
        const SizedBox(height: 16),
        const Text(
          'Traffic by Zone',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...trafficZones.map((zone) => _buildTrafficZoneCard(zone)).toList(),
      ],
    );
  }

  Widget _buildTrafficZoneCard(Map<String, dynamic> zone) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      Text(
                        zone['zone'],
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Avg Delay: ${zone['avgDelay']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: zone['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    zone['congestion'],
                    style: TextStyle(
                      fontSize: 12,
                      color: zone['color'],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: zone['level'] / 100,
                minHeight: 6,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(zone['color']),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Congestion: ${zone['level']}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  'Affected: ${zone['affectedDeliveries']} deliveries',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetricsTab() {
    final performanceData = [
      {
        'metric': 'Avg Completion Time',
        'value': '42 mins',
        'target': '45 mins',
        'status': 'on_track',
        'change': '↓ 5% from last week',
      },
      {
        'metric': 'On-Time Delivery Rate',
        'value': '94.2%',
        'target': '95%',
        'status': 'on_track',
        'change': '↑ 2.1% from last week',
      },
      {
        'metric': 'Route Efficiency',
        'value': '88.5%',
        'target': '90%',
        'status': 'below_target',
        'change': '↓ 1.2% from last week',
      },
      {
        'metric': 'Avg Distance per Delivery',
        'value': '1.8 km',
        'target': '1.5 km',
        'status': 'below_target',
        'change': '↑ 0.2 km from last week',
      },
    ];

    final riderPerformance = [
      {
        'riderName': 'Ramesh Kumar',
        'efficiency': 92.5,
        'onTime': 96.0,
        'avgTime': 40,
        'deliveriesCompleted': 215,
      },
      {
        'riderName': 'Priya Sharma',
        'efficiency': 88.0,
        'onTime': 93.0,
        'avgTime': 44,
        'deliveriesCompleted': 187,
      },
      {
        'riderName': 'Amit Patel',
        'efficiency': 85.0,
        'onTime': 91.0,
        'avgTime': 46,
        'deliveriesCompleted': 156,
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Key Performance Indicators',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...performanceData.map((data) => _buildKpiCard(data)).toList(),
        const SizedBox(height: 24),
        const Text(
          'Rider Performance Ranking',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...riderPerformance.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          return _buildRiderPerformanceCard(index + 1, data);
        }).toList(),
      ],
    );
  }

  Widget _buildKpiCard(Map<String, dynamic> data) {
    final isOnTrack = data['status'] == 'on_track';
    final statusColor = isOnTrack ? Colors.green : Colors.orange;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  child: Text(
                    data['metric'],
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isOnTrack ? 'On Track' : 'Below Target',
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
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
                      'Current',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      data['value'],
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Target',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      data['target'],
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              data['change'],
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderPerformanceCard(int rank, Map<String, dynamic> data) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: rank == 1 ? Colors.amber : rank == 2 ? Colors.grey : Colors.orange,
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
                  child: Text(
                    data['riderName'],
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricColumn('Efficiency', '${data['efficiency']}%'),
                _buildMetricColumn('On-Time', '${data['onTime']}%'),
                _buildMetricColumn('Avg Time', '${data['avgTime']} min'),
                _buildMetricColumn('Total', '${data['deliveriesCompleted']}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value) {
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

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              value.split(' ')[0],
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
