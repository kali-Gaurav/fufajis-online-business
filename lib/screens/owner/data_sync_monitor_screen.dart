import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class DataSyncMonitorScreen extends StatefulWidget {
  const DataSyncMonitorScreen({Key? key}) : super(key: key);

  @override
  State<DataSyncMonitorScreen> createState() => _DataSyncMonitorScreenState();
}

class _DataSyncMonitorScreenState extends State<DataSyncMonitorScreen>
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
        title: const Text('Data Sync Monitor'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabs: const [
            Tab(text: 'Status'),
            Tab(text: 'Divergence'),
            Tab(text: 'Audit'),
            Tab(text: 'Config'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatusTab(),
          _buildDivergenceTab(),
          _buildAuditTab(),
          _buildConfigTab(),
        ],
      ),
    );
  }

  Widget _buildStatusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHealthScoreCard(),
          const SizedBox(height: 24),
          const Text(
            'Entity Sync Status',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildEntitySyncCards(),
          const SizedBox(height: 24),
          const Text(
            'System Status',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildSystemStatusCards(),
          const SizedBox(height: 24),
          const Text(
            'Failed Syncs Queue',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildFailedSyncsQueue(),
        ],
      ),
    );
  }

  Widget _buildHealthScoreCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sync Health Score',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '✓ OPTIMAL',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: 0.985,
                          strokeWidth: 8,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                          backgroundColor: Colors.grey[300],
                        ),
                      ),
                      Column(
                        children: const [
                          Text(
                            '98.5%',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Health',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Last updated: ${DateFormat('hh:mm:ss').format(DateTime.now())}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHealthMetric('Uptime', '99.92%'),
                _buildHealthMetric('Latency', '0.8s'),
                _buildHealthMetric('Success Rate', '99.98%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthMetric(String label, String value) {
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

  Widget _buildEntitySyncCards() {
    final entities = [
      {
        'name': 'Orders',
        'lastSync': '2 seconds ago',
        'latency': '0.6s',
        'count': '847',
        'status': 'synced',
        'color': Colors.blue,
      },
      {
        'name': 'Inventory',
        'lastSync': '1 second ago',
        'latency': '0.4s',
        'count': '2,450',
        'status': 'synced',
        'color': Colors.green,
      },
      {
        'name': 'Customers',
        'lastSync': '5 seconds ago',
        'latency': '1.2s',
        'count': '2,985',
        'status': 'synced',
        'color': Colors.orange,
      },
      {
        'name': 'Products',
        'lastSync': '3 seconds ago',
        'latency': '0.6s',
        'count': '1,240',
        'status': 'synced',
        'color': Colors.purple,
      },
    ];

    return Column(
      children: entities.map((entity) => _buildEntityCard(entity)).toList(),
    );
  }

  Widget _buildEntityCard(Map<String, dynamic> entity) {
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: entity['color'],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entity['name'],
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '✓ Synced',
                    style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildEntityMetric('Last Sync', entity['lastSync']),
                _buildEntityMetric('Latency', entity['latency']),
                _buildEntityMetric('Records', entity['count']),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 1.0,
                minHeight: 4,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(entity['color']),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntityMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _buildSystemStatusCards() {
    final systems = [
      {
        'name': 'PostgreSQL',
        'status': 'Connected',
        'uptime': '99.98%',
        'icon': Icons.storage,
        'color': Colors.blue,
      },
      {
        'name': 'Firestore',
        'status': 'Connected',
        'uptime': '99.95%',
        'icon': Icons.cloud,
        'color': Colors.orange,
      },
      {
        'name': 'Sync Service',
        'status': 'Running',
        'uptime': '99.92%',
        'icon': Icons.sync,
        'color': Colors.green,
      },
      {
        'name': 'Queue',
        'status': 'Empty',
        'uptime': 'Ready',
        'icon': Icons.queue,
        'color': Colors.purple,
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: systems.map((system) => _buildSystemStatusCard(system)).toList(),
    );
  }

  Widget _buildSystemStatusCard(Map<String, dynamic> system) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
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
                color: system['color'].withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(system['icon'], color: system['color'], size: 18),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  system['name'],
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  system['status'],
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Uptime: ${system['uptime']}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedSyncsQueue() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Failed Syncs',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Queue Empty',
                    style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle, size: 48, color: Colors.green.withOpacity(0.3)),
                  const SizedBox(height: 8),
                  Text(
                    'No failed syncs',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  Text(
                    'All data synchronized successfully',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivergenceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    'Divergence Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDivergenceStat('Total Divergence', '0', Colors.green),
                      _buildDivergenceStat('Critical', '0', Colors.red),
                      _buildDivergenceStat('Warnings', '0', Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Divergence Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.blue.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle, size: 48, color: Colors.green.withOpacity(0.3)),
                    const SizedBox(height: 8),
                    Text(
                      'Perfect Synchronization',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    Text(
                      'PostgreSQL and Firestore are in complete sync',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Impact Assessment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildImpactAssessmentCards(),
        ],
      ),
    );
  }

  Widget _buildDivergenceStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildImpactAssessmentCards() {
    final impacts = [
      {
        'feature': 'Order Processing',
        'status': 'Healthy',
        'risk': 'None',
        'color': Colors.green,
      },
      {
        'feature': 'Inventory Management',
        'status': 'Healthy',
        'risk': 'None',
        'color': Colors.green,
      },
      {
        'feature': 'Payment Processing',
        'status': 'Healthy',
        'risk': 'None',
        'color': Colors.green,
      },
      {
        'feature': 'Customer Data',
        'status': 'Healthy',
        'risk': 'None',
        'color': Colors.green,
      },
    ];

    return Column(
      children: impacts
          .map((impact) => Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.grey[50],
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              impact['feature'],
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Risk: ${impact['risk']}',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: impact['color'].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          impact['status'],
                          style: TextStyle(
                            fontSize: 11,
                            color: impact['color'],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildAuditTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    'Sync Audit Trail',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildAuditStat('Today', '847', Colors.blue),
                      _buildAuditStat('This Week', '5,240', Colors.green),
                      _buildAuditStat('This Month', '23,450', Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recent Sync Events',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildAuditEventsList(),
        ],
      ),
    );
  }

  Widget _buildAuditStat(String label, String count, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          count,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          'syncs',
          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildAuditEventsList() {
    final events = [
      {
        'time': '14:32:45',
        'entity': 'Orders',
        'action': 'Sync Complete',
        'records': '12 records',
        'duration': '0.6s',
        'status': 'success',
      },
      {
        'time': '14:32:43',
        'entity': 'Inventory',
        'action': 'Sync Complete',
        'records': '45 records',
        'duration': '0.4s',
        'status': 'success',
      },
      {
        'time': '14:32:41',
        'entity': 'Customers',
        'action': 'Sync Complete',
        'records': '8 records',
        'duration': '1.2s',
        'status': 'success',
      },
      {
        'time': '14:32:38',
        'entity': 'Products',
        'action': 'Sync Complete',
        'records': '3 records',
        'duration': '0.6s',
        'status': 'success',
      },
      {
        'time': '14:32:35',
        'entity': 'Orders',
        'action': 'Sync Complete',
        'records': '7 records',
        'duration': '0.5s',
        'status': 'success',
      },
    ];

    return Column(
      children: events
          .map((event) => Card(
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
                                '${event['entity']} • ${event['action']}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                event['records'],
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              event['status'].toUpperCase(),
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
                          Text(
                            'Duration: ${event['duration']}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                          Text(
                            event['time'],
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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

  Widget _buildConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sync Configuration',
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
                  _buildConfigRow('Sync Mode', 'Real-time (< 5 seconds)'),
                  const Divider(height: 16),
                  _buildConfigRow('Batch Size', '1000 records per batch'),
                  const Divider(height: 16),
                  _buildConfigRow('Max Retries', '3 attempts'),
                  const Divider(height: 16),
                  _buildConfigRow('Retry Delay', 'Exponential backoff (2s, 4s, 8s)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Alert Thresholds',
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
                  _buildThresholdRow('Latency Warning', '> 2 seconds', Colors.orange),
                  const Divider(height: 16),
                  _buildThresholdRow('Latency Critical', '> 5 seconds', Colors.red),
                  const Divider(height: 16),
                  _buildThresholdRow('Sync Failure Rate', '> 1%', Colors.red),
                  const Divider(height: 16),
                  _buildThresholdRow('Divergence Limit', '> 0 records', Colors.red),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Entity-Specific Rules',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildEntityRulesCards(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Save Configuration'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildThresholdRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildEntityRulesCards() {
    final rules = [
      {
        'entity': 'Orders',
        'priority': 'Critical',
        'frequency': 'Real-time (5s)',
        'color': Colors.red,
      },
      {
        'entity': 'Inventory',
        'priority': 'Critical',
        'frequency': 'Real-time (2s)',
        'color': Colors.red,
      },
      {
        'entity': 'Customers',
        'priority': 'High',
        'frequency': 'Real-time (10s)',
        'color': Colors.orange,
      },
      {
        'entity': 'Products',
        'priority': 'Medium',
        'frequency': 'Every 30s',
        'color': Colors.blue,
      },
    ];

    return Column(
      children: rules
          .map((rule) => Card(
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
                            rule['entity'],
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            rule['frequency'],
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: rule['color'].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          rule['priority'],
                          style: TextStyle(
                            fontSize: 11,
                            color: rule['color'],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}
