import 'package:flutter/material.dart';

class ShiftSchedulingScreen extends StatefulWidget {
  const ShiftSchedulingScreen({Key? key}) : super(key: key);

  @override
  State<ShiftSchedulingScreen> createState() => _ShiftSchedulingScreenState();
}

class _ShiftSchedulingScreenState extends State<ShiftSchedulingScreen> with TickerProviderStateMixin {
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
        title: const Text('Shift Scheduling'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Schedule'), Tab(text: 'Forecast'), Tab(text: 'Constraints'), Tab(text: 'Config')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScheduleTab(),
          _buildForecastTab(),
          _buildConstraintsTab(),
          _buildConfigTab(),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
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
                  Text('Weekly Schedule Summary', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('124', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Staff Scheduled', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('892', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Total Shifts', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('98.5%', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Coverage', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Upcoming Shifts', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildShiftCard('Monday 8:00 AM - 4:00 PM', 'Store Manager', '4 staff', Colors.green),
          _buildShiftCard('Monday 4:00 PM - 10:00 PM', 'Inventory Manager', '3 staff', Colors.green),
          _buildShiftCard('Tuesday 8:00 AM - 4:00 PM', 'Cashier Supervisor', '5 staff', Colors.green),
          _buildShiftCard('Tuesday 4:00 PM - 10:00 PM', 'Delivery Lead', '6 staff', Colors.green),
          _buildShiftCard('Wednesday 8:00 AM - 4:00 PM', 'Stock Manager', '4 staff', Colors.green),
          _buildShiftCard('Wednesday 6:00 PM - 1:00 AM', 'Night Manager', '2 staff', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildForecastTab() {
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
                  Text('Demand Forecast (Next 7 Days)', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('42.5L', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Predicted Customers', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('127', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Staff Needed', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('97.6%', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Accuracy', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Daily Forecast', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildForecastCard('Monday', '6.2L customers', '18 staff needed', '↑12%', Colors.red),
          _buildForecastCard('Tuesday', '5.8L customers', '17 staff needed', '↓8%', Colors.green),
          _buildForecastCard('Wednesday', '5.1L customers', '15 staff needed', '↓12%', Colors.green),
          _buildForecastCard('Thursday', '4.9L customers', '14 staff needed', '↓5%', Colors.green),
          _buildForecastCard('Friday', '7.2L customers', '21 staff needed', '↑47%', Colors.orange),
          _buildForecastCard('Saturday', '8.5L customers', '25 staff needed', '↑18%', Colors.orange),
          _buildForecastCard('Sunday', '9.8L customers', '29 staff needed', '↑15%', Colors.red),
        ],
      ),
    );
  }

  Widget _buildConstraintsTab() {
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
                  Text('Scheduling Constraints', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('18', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Hard Constraints', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('24', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Soft Constraints', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('99.2%', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Satisfaction', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Active Constraints', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildConstraintCard('Max 8 hours/day per staff', '24/7 enforcement', Colors.red),
          _buildConstraintCard('Min 12 hours between shifts', '24/7 enforcement', Colors.red),
          _buildConstraintCard('Min 2 days off per week', 'Soft constraint', Colors.orange),
          _buildConstraintCard('No weekend for part-time', 'Preferences', Colors.orange),
          _buildConstraintCard('Manager on duty always', 'Mandatory', Colors.red),
          _buildConstraintCard('Cashier-to-customer ratio', 'Dynamic', Colors.blue),
          _buildConstraintCard('Staff skill matching', 'Optimization', Colors.blue),
          _buildConstraintCard('Fair shift distribution', 'Equity', Colors.green),
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
          Text('Scheduling Rules', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Scheduling Algorithm', 'AI Optimization', '🤖'),
                  const Divider(),
                  _buildConfigRow('Planning Horizon', '8 weeks', '📅'),
                  const Divider(),
                  _buildConfigRow('Shift Duration', '4-8 hours', '⏱️'),
                  const Divider(),
                  _buildConfigRow('Schedule Publication', '2 weeks advance', '📢'),
                  const Divider(),
                  _buildConfigRow('Swap Requests', 'Enabled', '✓'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Staffing Policies', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Maximum Shifts/Week', '6 shifts', '📋'),
                  const Divider(),
                  _buildConfigRow('Minimum Rest Period', '12 hours', '😴'),
                  const Divider(),
                  _buildConfigRow('Overtime Policy', 'Tracked', '📊'),
                  const Divider(),
                  _buildConfigRow('Part-time Ratio', 'Max 35%', '%'),
                  const Divider(),
                  _buildConfigRow('Peak Hour Staffing', '1 per 150 customers', '👥'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftCard(String shift, String role, String count, Color color) {
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
                Text(shift, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(role, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)),
              child: Text(count, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastCard(String day, String customers, String staff, String change, Color color) {
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
                Text(day, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)),
                  child: Text(change, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(customers, style: Theme.of(context).textTheme.bodySmall),
                Text(staff, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConstraintCard(String constraint, String type, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(constraint, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)),
              child: Text(type, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
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
