import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class CustomerSegmentationTargetingScreen extends StatefulWidget {
  const CustomerSegmentationTargetingScreen({Key? key}) : super(key: key);

  @override
  State<CustomerSegmentationTargetingScreen> createState() =>
      _CustomerSegmentationTargetingScreenState();
}

class _CustomerSegmentationTargetingScreenState
    extends State<CustomerSegmentationTargetingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, dynamic>> _segments = [
    {
      'id': 'seg_001',
      'name': 'High-Value Customers',
      'description': 'Total spend > ₹50,000',
      'criteria': ['Total Spend > ₹50,000'],
      'size': 234,
      'lastOrder': '2 days ago',
      'avgValue': 8500,
      'frequency': 'Weekly',
    },
    {
      'id': 'seg_002',
      'name': 'At-Risk Customers',
      'description': 'No purchase in 60 days',
      'criteria': ['Last Order > 60 days ago'],
      'size': 156,
      'lastOrder': '45 days ago',
      'avgValue': 3200,
      'frequency': 'Monthly',
    },
    {
      'id': 'seg_003',
      'name': 'New Customers',
      'description': 'Signed up < 30 days ago',
      'criteria': ['Account Age < 30 days'],
      'size': 89,
      'lastOrder': '5 days ago',
      'avgValue': 2100,
      'frequency': 'Occasional',
    },
    {
      'id': 'seg_004',
      'name': 'Subscription Users',
      'description': 'Active subscriptions',
      'criteria': ['Has Active Subscription'],
      'size': 342,
      'lastOrder': '1 day ago',
      'avgValue': 1200,
      'frequency': 'Regular',
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
          'Customer Segmentation',
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
            Tab(text: 'Segments'),
            Tab(text: 'Targeting'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSegmentsTab(),
          _buildTargetingTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSegmentDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('New Segment'),
      ),
    );
  }

  Widget _buildSegmentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats
          _buildSegmentStats(),
          const SizedBox(height: 20),

          // Segments List
          const Text(
            'All Segments',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._segments
              .map((segment) => _buildSegmentCard(segment))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildSegmentStats() {
    final totalCustomers = _segments.fold<int>(0, (sum, s) => sum + (s['size'] as int));

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Total Segments',
            value: _segments.length.toString(),
            icon: Icons.filter_list,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Total Customers',
            value: totalCustomers.toString(),
            icon: Icons.people,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Avg Segment Size',
            value: (totalCustomers ~/ _segments.length).toString(),
            icon: Icons.trending_up,
            color: Colors.blue,
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
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
                fontSize: 10,
                color: AppTheme.grey500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentCard(Map<String, dynamic> segment) {
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
                      Text(
                        segment['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        segment['description'],
                        style: const TextStyle(
                          fontSize: 12,
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
                      '${segment['size']} customers',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Avg: ₹${segment['avgValue']}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Criteria badges
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...( (segment['criteria'] as List<String>)
                    .map((criterion) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        criterion,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.primary,
                        ),
                      ),
                    ))
                    .toList()),
              ],
            ),
            const SizedBox(height: 12),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const Text(
                      'Last Order',
                      style: TextStyle(fontSize: 10, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      segment['lastOrder'],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text(
                      'Frequency',
                      style: TextStyle(fontSize: 10, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      segment['frequency'],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.mail_outline, size: 16),
                    label: const Text('Target'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Campaign Targeting',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create Targeting Campaign',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Campaign Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select Segments',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._segments
                      .map((seg) => _buildSegmentCheckbox(seg['name']))
                      .toList(),
                  const SizedBox(height: 16),
                  const Text(
                    'Campaign Type',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildCampaignTypeChip('Promotion'),
                      _buildCampaignTypeChip('Email'),
                      _buildCampaignTypeChip('Push Notification'),
                      _buildCampaignTypeChip('SMS'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                      child: const Text('Create Campaign'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent Campaigns',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._buildRecentCampaigns(),
        ],
      ),
    );
  }

  Widget _buildSegmentCheckbox(String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Checkbox(
            value: false,
            onChanged: (value) {},
            activeColor: AppTheme.primary,
          ),
          Text(name),
        ],
      ),
    );
  }

  Widget _buildCampaignTypeChip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: AppTheme.grey100,
      onDeleted: null,
    );
  }

  List<Widget> _buildRecentCampaigns() {
    return [
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mail,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Summer Sale - High Value Customers',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Email Campaign • 234 recipients',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '45%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.success,
                    ),
                  ),
                  Text(
                    'Open Rate',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.grey600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Win-Back - At Risk Customers',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Push Notification • 156 recipients',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '28%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.success,
                    ),
                  ),
                  Text(
                    'Click Rate',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.grey600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
  }

  void _showCreateSegmentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Segment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Segment Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Criteria',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildCriteriaChip('Total Spend'),
                  _buildCriteriaChip('Last Order'),
                  _buildCriteriaChip('Order Frequency'),
                  _buildCriteriaChip('Account Age'),
                ],
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

  Widget _buildCriteriaChip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: AppTheme.grey100,
    );
  }
}
