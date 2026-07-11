import 'package:flutter/material.dart';

class CustomerEngagementAutomationScreen extends StatefulWidget {
  const CustomerEngagementAutomationScreen({Key? key}) : super(key: key);

  @override
  State<CustomerEngagementAutomationScreen> createState() => _CustomerEngagementAutomationScreenState();
}

class _CustomerEngagementAutomationScreenState extends State<CustomerEngagementAutomationScreen>
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Engagement Automation'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Campaigns'),
            Tab(text: 'Segments'),
            Tab(text: 'Analytics'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'New Campaign',
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Active Campaigns
          _buildCampaignsTab(colorScheme),
          // Tab 2: Customer Segments
          _buildSegmentsTab(colorScheme),
          // Tab 3: Campaign Analytics
          _buildAnalyticsTab(colorScheme),
          // Tab 4: Configuration
          _buildSettingsTab(colorScheme),
        ],
      ),
    );
  }

  Widget _buildCampaignsTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campaign Overview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campaign Overview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '12',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Active Campaigns',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '1.2M',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Messages Sent',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '38.5%',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Avg Engagement',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Active Campaigns
          Text(
            'Active Campaigns',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildCampaignCard(
            'Flash Sale: Weekend Offers',
            'High-value segment',
            '45,234 targeted',
            '42.3% open rate',
            Colors.blue,
          ),
          _buildCampaignCard(
            'Loyalty Rewards Program',
            'Repeat customers',
            '12,450 targeted',
            '55.8% open rate',
            Colors.purple,
          ),
          _buildCampaignCard(
            'Welcome New Customers',
            'New users (0-30 days)',
            '8,234 targeted',
            '68.5% open rate',
            Colors.green,
          ),
          _buildCampaignCard(
            'Win-back Inactive Users',
            'Inactive >90 days',
            '3,456 targeted',
            '28.3% open rate',
            Colors.orange,
          ),
          _buildCampaignCard(
            'Referral Bonus Campaign',
            'All segments',
            '89,234 targeted',
            '32.1% open rate',
            Colors.teal,
          ),
          const SizedBox(height: 16),

          // Scheduled Campaigns
          Text(
            'Upcoming Scheduled Campaigns',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
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
                        'Monsoon Season Sale',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Scheduled',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Send on: Jul 15, 2026 at 10:00 AM',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentsTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segment Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Segments',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '18',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Active Segments',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '1.8M',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total Customers',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '24h',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Auto Refresh',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Customer Segments
          Text(
            'Defined Segments',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildSegmentCard('High-Value Customers', '₹5,000+ lifetime', '12,450 customers', Colors.green),
          _buildSegmentCard('New Customers', 'Joined last 30 days', '8,234 customers', Colors.blue),
          _buildSegmentCard('Inactive Customers', 'No purchase >90 days', '3,456 customers', Colors.orange),
          _buildSegmentCard('Repeat Buyers', '5+ purchases', '45,234 customers', Colors.purple),
          _buildSegmentCard('Trending Interest', 'Viewed similar items', '78,234 customers', Colors.teal),
          _buildSegmentCard('Churn Risk', 'Activity declining', '2,123 customers', Colors.red),
          _buildSegmentCard('Bulk Buyers', '₹1,000+ avg order', '34,567 customers', Colors.indigo),
          _buildSegmentCard('Budget Conscious', 'Below ₹500 avg order', '156,234 customers', Colors.amber),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Analytics Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campaign Performance (This Month)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '38.5%',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Open Rate',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '8.2%',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Click Rate',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '2.3%',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Conversion',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Campaign Performance
          Text(
            'Top Performing Campaigns',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildPerformanceCard('Welcome New Customers', '68.5%', '15.3%', '₹124,567', Colors.green),
          _buildPerformanceCard('Loyalty Rewards Program', '55.8%', '12.1%', '₹89,234', Colors.purple),
          _buildPerformanceCard('Flash Sale: Weekend Offers', '42.3%', '9.8%', '₹234,567', Colors.blue),
          _buildPerformanceCard('Referral Bonus Campaign', '32.1%', '5.4%', '₹67,890', Colors.teal),
          const SizedBox(height: 16),

          // Channel Performance
          Text(
            'Performance by Channel',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('WhatsApp'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '45.2% open rate',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('SMS'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '32.1% open rate',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Email'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '28.5% open rate',
                          style: TextStyle(
                            color: Colors.purple.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Push Notification'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '18.3% open rate',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Channel Configuration
          Text(
            'Channel Configuration',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildChannelRow('WhatsApp Business', 'Connected', Icons.check_circle, Colors.green),
                  const Divider(),
                  _buildChannelRow('SMS Provider', 'Connected', Icons.check_circle, Colors.green),
                  const Divider(),
                  _buildChannelRow('Email Service', 'Connected', Icons.check_circle, Colors.green),
                  const Divider(),
                  _buildChannelRow('Push Notifications', 'Enabled', Icons.check_circle, Colors.green),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Frequency Caps
          Text(
            'Frequency Caps (Anti-Spam)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCapRow('Daily Limit per Customer', '5 messages'),
                  const Divider(),
                  _buildCapRow('Weekly Limit per Customer', '20 messages'),
                  const Divider(),
                  _buildCapRow('Campaign Frequency', '1 per customer per day'),
                  const Divider(),
                  _buildCapRow('Unsubscribe Respect', 'Automatic removal'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Personalization Settings
          Text(
            'Personalization',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCapRow('Dynamic Content', 'Enabled'),
                  const Divider(),
                  _buildCapRow('Customer Name In Message', 'Enabled'),
                  const Divider(),
                  _buildCapRow('Recommendation Engine', 'Product-based'),
                  const Divider(),
                  _buildCapRow('Best Send Time Optimization', 'Enabled'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Compliance
          Text(
            'Compliance & Privacy',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCapRow('GDPR Compliance', 'Enabled'),
                  const Divider(),
                  _buildCapRow('Opt-in Tracking', 'Required'),
                  const Divider(),
                  _buildCapRow('Unsubscribe Option', 'Every message'),
                  const Divider(),
                  _buildCapRow('Data Retention', '90 days'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignCard(
    String title,
    String segment,
    String targeted,
    String engagement,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(segment, style: Theme.of(context).textTheme.bodySmall),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    engagement,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(targeted, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentCard(
    String name,
    String criteria,
    String count,
    Color color,
  ) {
    return Card(
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
                  name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(criteria, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              count,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard(
    String campaign,
    String open,
    String click,
    String revenue,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              campaign,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Open: $open', style: Theme.of(context).textTheme.labelSmall),
                Text('Click: $click', style: Theme.of(context).textTheme.labelSmall),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    revenue,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  Widget _buildChannelRow(String channel, String status, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(channel),
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                status,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
