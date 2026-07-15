import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

class TaskAssignmentTrackingScreen extends StatefulWidget {
  const TaskAssignmentTrackingScreen({Key? key}) : super(key: key);

  @override
  State<TaskAssignmentTrackingScreen> createState() =>
      _TaskAssignmentTrackingScreenState();
}

class _TaskAssignmentTrackingScreenState
    extends State<TaskAssignmentTrackingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all'; // all, assigned, in_progress, completed, overdue
  final List<Map<String, dynamic>> _tasks = [
    {
      'id': 'task_001',
      'title': 'Morning Inventory Count',
      'description': 'Complete daily inventory count for warehouse',
      'category': 'Inventory',
      'assignedTo': 'Rajesh Kumar',
      'assignedToId': 'emp_001',
      'priority': 'high',
      'status': 'in_progress',
      'dueDate': DateTime(2026, 7, 12),
      'createdDate': DateTime(2026, 7, 10),
      'completedDate': null,
      'progress': 65,
      'subtasks': [
        {'title': 'Count warehouse section A', 'completed': true},
        {'title': 'Count warehouse section B', 'completed': true},
        {'title': 'Count warehouse section C', 'completed': false},
        {'title': 'Verify totals', 'completed': false},
      ],
      'checklist': 4,
      'checklistCompleted': 2,
    },
    {
      'id': 'task_002',
      'title': 'Process Customer Returns',
      'description': 'Handle and process all pending customer returns',
      'category': 'Customer Service',
      'assignedTo': 'Priya Singh',
      'assignedToId': 'emp_002',
      'priority': 'medium',
      'status': 'assigned',
      'dueDate': DateTime(2026, 7, 13),
      'createdDate': DateTime(2026, 7, 11),
      'completedDate': null,
      'progress': 0,
      'subtasks': [],
      'checklist': 0,
      'checklistCompleted': 0,
    },
    {
      'id': 'task_003',
      'title': 'Stock Replenishment',
      'description': 'Replenish shelves for high-demand items',
      'category': 'Warehouse',
      'assignedTo': 'Amit Patel',
      'assignedToId': 'emp_003',
      'priority': 'high',
      'status': 'completed',
      'dueDate': DateTime(2026, 7, 11),
      'createdDate': DateTime(2026, 7, 9),
      'completedDate': DateTime(2026, 7, 11, 14, 30),
      'progress': 100,
      'subtasks': [
        {'title': 'Order stock', 'completed': true},
        {'title': 'Receive goods', 'completed': true},
        {'title': 'Stock shelves', 'completed': true},
      ],
      'checklist': 3,
      'checklistCompleted': 3,
    },
    {
      'id': 'task_004',
      'title': 'Quality Audit',
      'description': 'Conduct quality check on packed items',
      'category': 'Quality',
      'assignedTo': 'Rajesh Kumar',
      'assignedToId': 'emp_001',
      'priority': 'high',
      'status': 'overdue',
      'dueDate': DateTime(2026, 7, 10),
      'createdDate': DateTime(2026, 7, 8),
      'completedDate': null,
      'progress': 30,
      'subtasks': [
        {'title': 'Prepare audit checklist', 'completed': true},
        {'title': 'Inspect items', 'completed': false},
      ],
      'checklist': 2,
      'checklistCompleted': 1,
    },
    {
      'id': 'task_005',
      'title': 'Training Session',
      'description': 'Conduct staff training on new system',
      'category': 'Training',
      'assignedTo': 'Priya Singh',
      'assignedToId': 'emp_002',
      'priority': 'medium',
      'status': 'completed',
      'dueDate': DateTime(2026, 7, 11),
      'createdDate': DateTime(2026, 7, 5),
      'completedDate': DateTime(2026, 7, 11, 16, 0),
      'progress': 100,
      'subtasks': [],
      'checklist': 0,
      'checklistCompleted': 0,
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
          'Task Management',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('All Tasks'),
                onTap: () => setState(() => _selectedFilter = 'all'),
              ),
              PopupMenuItem(
                child: const Text('Assigned'),
                onTap: () => setState(() => _selectedFilter = 'assigned'),
              ),
              PopupMenuItem(
                child: const Text('In Progress'),
                onTap: () => setState(() => _selectedFilter = 'in_progress'),
              ),
              PopupMenuItem(
                child: const Text('Completed'),
                onTap: () => setState(() => _selectedFilter = 'completed'),
              ),
              PopupMenuItem(
                child: const Text('Overdue'),
                onTap: () => setState(() => _selectedFilter = 'overdue'),
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
            Tab(text: 'Tasks'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTasksTab(),
          _buildAnalyticsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTasksTab() {
    final filteredTasks = _getFilteredTasks();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTaskStats(),
          const SizedBox(height: 20),
          const Text(
            'Tasks',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (filteredTasks.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.task_alt, size: 48, color: AppTheme.grey400),
                    const SizedBox(height: 12),
                    Text(
                      'No tasks found',
                      style: TextStyle(color: AppTheme.grey600),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredTasks.map((task) => _buildTaskCard(task)).toList(),
        ],
      ),
    );
  }

  Widget _buildTaskStats() {
    final assigned = _tasks.where((t) => t['status'] == 'assigned').length;
    final inProgress = _tasks.where((t) => t['status'] == 'in_progress').length;
    final completed = _tasks.where((t) => t['status'] == 'completed').length;
    final overdue = _tasks.where((t) => t['status'] == 'overdue').length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Total Tasks',
            value: _tasks.length.toString(),
            icon: Icons.task,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'In Progress',
            value: inProgress.toString(),
            icon: Icons.hourglass_top,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Completed',
            value: completed.toString(),
            icon: Icons.check_circle,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Overdue',
            value: overdue.toString(),
            icon: Icons.error,
            color: AppTheme.error,
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
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.grey500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['title'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task['description'],
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(task['status']),
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
                        'Assigned to',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task['assignedTo'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
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
                        'Priority',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task['priority'].toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: _getPriorityColor(task['priority']),
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
                        'Due Date',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM dd').format(task['dueDate']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (task['checklist'] > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtasks (${task['checklistCompleted']}/${task['checklist']})',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.grey600,
                        ),
                      ),
                      Text(
                        '${((task['checklistCompleted'] / task['checklist']) * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: task['checklistCompleted'] / task['checklist'],
                      minHeight: 4,
                      backgroundColor: AppTheme.grey200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getProgressColor(task['checklistCompleted'] / task['checklist']),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text('View', style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text('Edit', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'assigned':
        bgColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        label = 'Assigned';
        break;
      case 'in_progress':
        bgColor = Colors.amber.withOpacity(0.1);
        textColor = Colors.amber[700]!;
        label = 'In Progress';
        break;
      case 'completed':
        bgColor = AppTheme.success.withOpacity(0.1);
        textColor = AppTheme.success;
        label = 'Completed';
        break;
      case 'overdue':
        bgColor = AppTheme.error.withOpacity(0.1);
        textColor = AppTheme.error;
        label = 'Overdue';
        break;
      default:
        bgColor = AppTheme.grey200;
        textColor = AppTheme.grey600;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final completed = _tasks.where((t) => t['status'] == 'completed').length;
    final total = _tasks.length;
    final avgProgress =
        _tasks.fold(0.0, (sum, t) => sum + (t['progress'] as int)) / total;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsCard(
            title: 'Task Completion Rate',
            value: '${((completed / total) * 100).toStringAsFixed(1)}%',
            subtitle: '$completed of $total tasks completed',
            icon: Icons.trending_up,
          ),
          const SizedBox(height: 12),
          _buildAnalyticsCard(
            title: 'Average Progress',
            value: '${avgProgress.toStringAsFixed(1)}%',
            subtitle: 'Across all active tasks',
            icon: Icons.bar_chart,
          ),
          const SizedBox(height: 20),
          const Text(
            'Tasks by Category',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildCategoryBreakdown(),
          const SizedBox(height: 20),
          const Text(
            'Tasks by Employee',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildEmployeeStats(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, color: AppTheme.primary, size: 24),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.grey600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.grey500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final categories = <String, int>{};
    for (var task in _tasks) {
      final category = task['category'] as String;
      categories[category] = (categories[category] ?? 0) + 1;
    }

    return Column(
      children: categories.entries
          .map((entry) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value} tasks',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildEmployeeStats() {
    final employees = <String, int>{};
    for (var task in _tasks) {
      final emp = task['assignedTo'] as String;
      employees[emp] = (employees[emp] ?? 0) + 1;
    }

    return Column(
      children: employees.entries
          .map((entry) => Card(
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
                            entry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${entry.value} tasks',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: entry.value / _tasks.length,
                          minHeight: 6,
                          backgroundColor: AppTheme.grey200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getProgressColor(entry.value / _tasks.length),
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

  List<Map<String, dynamic>> _getFilteredTasks() {
    switch (_selectedFilter) {
      case 'assigned':
        return _tasks.where((t) => t['status'] == 'assigned').toList();
      case 'in_progress':
        return _tasks.where((t) => t['status'] == 'in_progress').toList();
      case 'completed':
        return _tasks.where((t) => t['status'] == 'completed').toList();
      case 'overdue':
        return _tasks.where((t) => t['status'] == 'overdue').toList();
      default:
        return _tasks;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return AppTheme.error;
      case 'medium':
        return Colors.amber[700]!;
      case 'low':
        return AppTheme.success;
      default:
        return AppTheme.grey600;
    }
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.9) return AppTheme.success;
    if (progress >= 0.5) return Colors.orange;
    return AppTheme.error;
  }
}
