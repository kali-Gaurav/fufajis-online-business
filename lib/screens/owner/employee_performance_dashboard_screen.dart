import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

class EmployeePerformanceDashboardScreen extends StatefulWidget {
  const EmployeePerformanceDashboardScreen({Key? key}) : super(key: key);

  @override
  State<EmployeePerformanceDashboardScreen> createState() =>
      _EmployeePerformanceDashboardScreenState();
}

class _EmployeePerformanceDashboardScreenState
    extends State<EmployeePerformanceDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'month';
  final List<Map<String, dynamic>> _employees = [
    {
      'id': 'emp_001',
      'name': 'Rajesh Kumar',
      'role': 'Packing Specialist',
      'department': 'Warehouse',
      'avatar': 'R',
      'rating': 4.8,
      'tasksCompleted': 156,
      'accuracy': 98.5,
      'efficiency': 92.3,
      'attendance': 96,
      'status': 'active',
    },
    {
      'id': 'emp_002',
      'name': 'Priya Singh',
      'role': 'Customer Service',
      'department': 'Support',
      'avatar': 'P',
      'rating': 4.6,
      'tasksCompleted': 234,
      'accuracy': 97.2,
      'efficiency': 89.5,
      'attendance': 98,
      'status': 'active',
    },
    {
      'id': 'emp_003',
      'name': 'Amit Patel',
      'role': 'Inventory Manager',
      'department': 'Operations',
      'avatar': 'A',
      'rating': 4.5,
      'tasksCompleted': 89,
      'accuracy': 96.8,
      'efficiency': 88.2,
      'attendance': 94,
      'status': 'active',
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
          'Employee Performance',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('This Week'),
                onTap: () => setState(() => _selectedPeriod = 'week'),
              ),
              PopupMenuItem(
                child: const Text('This Month'),
                onTap: () => setState(() => _selectedPeriod = 'month'),
              ),
              PopupMenuItem(
                child: const Text('This Quarter'),
                onTap: () => setState(() => _selectedPeriod = 'quarter'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.grey600,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Details'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildDetailsTab(),
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
          // Team Stats
          _buildTeamStatsGrid(),
          const SizedBox(height: 20),

          // Top Performers
          _buildTopPerformersSection(),
          const SizedBox(height: 20),

          // Department Breakdown
          _buildDepartmentBreakdown(),
        ],
      ),
    );
  }

  Widget _buildTeamStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Total Employees',
            value: _employees.length.toString(),
            icon: Icons.people,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Avg Rating',
            value: '4.6★',
            icon: Icons.star,
            color: Colors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Attendance',
            value: '96%',
            icon: Icons.check_circle,
            color: AppTheme.success,
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
            Icon(icon, color: color, size: 18),
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

  Widget _buildTopPerformersSection() {
    final sorted = List<Map<String, dynamic>>.from(_employees)
      ..sort((a, b) => (b['rating'] as double).compareTo(a['rating'] as double));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Performers',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: sorted
                  .take(3)
                  .asMap()
                  .entries
                  .map((entry) => _buildPerformerTile(
                        entry.value,
                        entry.key + 1,
                        entry.key < 2,
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformerTile(
    Map<String, dynamic> employee,
    int rank,
    bool showDivider,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: rank == 1
                    ? Colors.amber
                    : (rank == 2 ? Colors.grey : Colors.orange),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    employee['role'],
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.grey600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      '${employee['rating']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${employee['tasksCompleted']} tasks',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
      ],
    );
  }

  Widget _buildDepartmentBreakdown() {
    final departments = <String, List<Map<String, dynamic>>>{};
    for (var emp in _employees) {
      departments.putIfAbsent(emp['department'], () => []).add(emp);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Department Breakdown',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        ...departments.entries
            .map((entry) => _buildDepartmentCard(entry.key, entry.value))
            .toList(),
      ],
    );
  }

  Widget _buildDepartmentCard(
    String department,
    List<Map<String, dynamic>> employees,
  ) {
    final avgRating = employees.fold<double>(0, (sum, e) => sum + (e['rating'] as double)) /
        employees.length;
    final avgAttendance = employees.fold<double>(0, (sum, e) => sum + (e['attendance'] as int)) /
        employees.length;

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
                  department,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${employees.length} members',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.grey600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Avg Rating',
                        style: TextStyle(fontSize: 10, color: AppTheme.grey600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${avgRating.toStringAsFixed(1)}★',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Attendance',
                        style: TextStyle(fontSize: 10, color: AppTheme.grey600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${avgAttendance.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Tasks Completed',
                        style: TextStyle(fontSize: 10, color: AppTheme.grey600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${employees.fold<int>(0, (sum, e) => sum + (e['tasksCompleted'] as int))}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Employee Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._employees
              .map((employee) => _buildEmployeeDetailCard(employee))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildEmployeeDetailCard(Map<String, dynamic> employee) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      employee['avatar'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppTheme.primary,
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
                        employee['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        employee['role'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          '${employee['rating']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Performance Metrics
            _buildMetricRow(
              'Accuracy',
              '${employee['accuracy']}%',
              employee['accuracy'] / 100,
            ),
            const SizedBox(height: 8),
            _buildMetricRow(
              'Efficiency',
              '${employee['efficiency']}%',
              employee['efficiency'] / 100,
            ),
            const SizedBox(height: 8),
            _buildMetricRow(
              'Attendance',
              '${employee['attendance']}%',
              employee['attendance'] / 100,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tasks: ${employee['tasksCompleted']}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.grey600),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppTheme.grey200,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 0.9
                  ? AppTheme.success
                  : (progress >= 0.7 ? Colors.orange : AppTheme.error),
            ),
          ),
        ),
      ],
    );
  }
}
