import 'package:flutter/material.dart';

class StaffPerformanceScreen extends StatefulWidget {
  const StaffPerformanceScreen({Key? key}) : super(key: key);

  @override
  State<StaffPerformanceScreen> createState() => _StaffPerformanceScreenState();
}

class _StaffPerformanceScreenState extends State<StaffPerformanceScreen> with TickerProviderStateMixin {
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
        title: const Text('Staff Performance'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'KPIs'), Tab(text: 'Reviews'), Tab(text: 'Development'), Tab(text: 'Config')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildKPIsTab(),
          _buildReviewsTab(),
          _buildDevelopmentTab(),
          _buildConfigTab(),
        ],
      ),
    );
  }

  Widget _buildKPIsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Team Performance Summary', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('124', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Team Members', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('4.2/5.0', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Avg Rating', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('92.5%', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Attendance', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Top Performers', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildStaffCard('Priya Sharma', 'Store Manager', '4.8/5.0', 'Q2 2026', Colors.green),
          _buildStaffCard('Rajesh Kumar', 'Cashier', '4.7/5.0', 'Q2 2026', Colors.green),
          _buildStaffCard('Anjali Verma', 'Inventory', '4.6/5.0', 'Q2 2026', Colors.green),
          _buildStaffCard('Vikram Singh', 'Delivery Lead', '4.5/5.0', 'Q2 2026', Colors.green),
          _buildStaffCard('Deepak Patel', 'Stock Handler', '4.4/5.0', 'Q2 2026', Colors.blue),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Performance Reviews', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('58', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Completed', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('22', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Pending', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('44', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Scheduled', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Recent Reviews', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildReviewCard('Priya Sharma', 'Store Manager', 'Excellent performance, strong leadership', 'Completed', Colors.green),
          _buildReviewCard('Rajesh Kumar', 'Cashier', 'Good customer service, needs improvement in speed', 'Completed', Colors.green),
          _buildReviewCard('Anjali Verma', 'Inventory', 'Review in progress, feedback collection ongoing', 'In Progress', Colors.orange),
          _buildReviewCard('Vikram Singh', 'Delivery Lead', 'Scheduled for next week', 'Pending', Colors.orange),
          _buildReviewCard('Deepak Patel', 'Stock Handler', 'Scheduled for next week', 'Pending', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildDevelopmentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Development Programs', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('8', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Active Programs', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('56', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Participants', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('78.5%', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Completion Rate', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Training Programs', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildDevProgramCard('Customer Service Excellence', '12 participants', '85% complete', Colors.green),
          _buildDevProgramCard('Inventory Management', '8 participants', '60% complete', Colors.blue),
          _buildDevProgramCard('Leadership Skills', '6 participants', '45% complete', Colors.orange),
          _buildDevProgramCard('POS System Mastery', '15 participants', '92% complete', Colors.green),
          _buildDevProgramCard('Safety & Compliance', '18 participants', '78% complete', Colors.green),
          _buildDevProgramCard('Digital Marketing Basics', '10 participants', '30% complete', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Performance Metrics', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Evaluation Frequency', 'Quarterly', '📅'),
                  const Divider(),
                  _buildConfigRow('Rating Scale', '1-5 Points', '⭐'),
                  const Divider(),
                  _buildConfigRow('KPI Categories', '6 dimensions', '📊'),
                  const Divider(),
                  _buildConfigRow('Goal Setting', 'Annual + Quarterly', '🎯'),
                  const Divider(),
                  _buildConfigRow('Feedback System', ' 360-degree', '💬'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Development Settings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Training Budget', '₹15L annually', '💰'),
                  const Divider(),
                  _buildConfigRow('Certification Support', 'Enabled', '✓'),
                  const Divider(),
                  _buildConfigRow('Mentorship Program', 'Active', '✓'),
                  const Divider(),
                  _buildConfigRow('Career Pathing', 'Automated', '📈'),
                  const Divider(),
                  _buildConfigRow('Reward Recognition', 'Monthly', '🏆'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(String name, String role, String rating, String period, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(role, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)),
                  child: Text(rating, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 4),
                Text(period, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(String name, String role, String feedback, String status, Color color) {
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(role, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)),
                  child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(feedback, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildDevProgramCard(String program, String participants, String progress, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(program, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(participants, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)),
              child: Text(progress, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigRow(String label, String value, String icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Text(icon), const SizedBox(width: 12), Text(label)]), Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))]),
    );
  }
}
