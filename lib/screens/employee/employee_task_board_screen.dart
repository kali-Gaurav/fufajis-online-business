import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class EmployeeTaskBoardScreen extends StatefulWidget {
  final String employeeId;

  const EmployeeTaskBoardScreen({Key? key, required this.employeeId})
      : super(key: key);

  @override
  State<EmployeeTaskBoardScreen> createState() =>
      _EmployeeTaskBoardScreenState();
}

class _EmployeeTaskBoardScreenState extends State<EmployeeTaskBoardScreen> {
  List<Task> _todoTasks = [];
  List<Task> _inProgressTasks = [];
  List<Task> _completedTasks = [];
  DateTime _shiftStart = DateTime.now().copyWith(hour: 8, minute: 0);
  DateTime? _breakStart;
  DateTime? _breakEnd;
  bool _onShift = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    // Simulate loading tasks
    setState(() {
      _todoTasks = [
        Task(
          id: '1',
          title: 'Stock shelves - Dairy section',
          description: 'Arrange milk packets in aisle 2',
          priority: 'high',
          estimatedDuration: 45,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        Task(
          id: '2',
          title: 'Price check vegetables',
          description: 'Verify prices match the system',
          priority: 'medium',
          estimatedDuration: 30,
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ];
      _inProgressTasks = [
        Task(
          id: '3',
          title: 'Clean checkout area',
          description: 'Wipe counters and organize bags',
          priority: 'high',
          estimatedDuration: 20,
          startedAt: DateTime.now().subtract(const Duration(minutes: 15)),
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ];
      _completedTasks = [
        Task(
          id: '4',
          title: 'Open store - morning setup',
          description: 'Turn on lights, open doors, start registers',
          priority: 'high',
          estimatedDuration: 30,
          completedAt: DateTime.now().subtract(const Duration(minutes: 120)),
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        Task(
          id: '5',
          title: 'Receive delivery',
          description: 'Check inventory from supplier',
          priority: 'high',
          estimatedDuration: 60,
          completedAt: DateTime.now().subtract(const Duration(minutes: 60)),
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('My Tasks', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          _buildShiftStatusButton(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeTrackingCard(),
            const SizedBox(height: 24),
            _buildTaskStats(),
            const SizedBox(height: 24),
            _buildKanbanBoard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftStatusButton() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: () => setState(() => _onShift = !_onShift),
          icon: Icon(_onShift ? Icons.logout : Icons.login),
          label: Text(_onShift ? 'End Shift' : 'Start Shift'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _onShift ? Colors.red : Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeTrackingCard() {
    final now = DateTime.now();
    final shiftDuration = now.difference(_shiftStart);
    final hoursWorked = shiftDuration.inMinutes / 60;

    final breakDuration = _breakStart != null && _breakEnd != null
        ? _breakEnd!.difference(_breakStart!).inMinutes
        : 0;

    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Time Tracking',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _onShift ? Colors.green[100] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _onShift ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _onShift ? 'On Shift' : 'Off Duty',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _onShift ? Colors.green[700] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shift Start',
                      style: TextStyle(fontSize: 11, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_shiftStart.hour.toString().padLeft(2, '0')}:${_shiftStart.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Worked Today',
                      style: TextStyle(fontSize: 11, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${hoursWorked.toStringAsFixed(1)}h',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _toggleBreak(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Break',
                        style: TextStyle(fontSize: 11, color: AppTheme.grey600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _breakStart != null && _breakEnd == null
                            ? 'ON BREAK'
                            : '${breakDuration}m',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _breakStart != null && _breakEnd == null
                              ? Colors.orange
                              : AppTheme.grey700,
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

  Widget _buildTaskStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'To Do',
            _todoTasks.length.toString(),
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'In Progress',
            _inProgressTasks.length.toString(),
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Completed',
            _completedTasks.length.toString(),
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String count, Color color) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKanbanBoard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kanban Board',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildKanbanColumn('To Do', _todoTasks, Colors.blue),
              const SizedBox(width: 12),
              _buildKanbanColumn('In Progress', _inProgressTasks, Colors.orange),
              const SizedBox(width: 12),
              _buildKanbanColumn('Completed', _completedTasks, Colors.green),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKanbanColumn(String title, List<Task> tasks, Color color) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tasks.length.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No tasks',
                  style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 12),
                ),
              ),
            )
          else
            Column(
              children: tasks
                  .map((task) => _buildTaskCard(task, color))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task, Color columnColor) {
    return GestureDetector(
      onTap: () => _showTaskDetails(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: columnColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: task.priority == 'high'
                        ? Colors.red[100]
                        : Colors.orange[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task.priority[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: task.priority == 'high'
                          ? Colors.red[700]
                          : Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              task.description,
              style: const TextStyle(fontSize: 11, color: AppTheme.grey600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 12, color: AppTheme.grey600),
                    const SizedBox(width: 4),
                    Text(
                      '${task.estimatedDuration}m',
                      style: const TextStyle(fontSize: 10, color: AppTheme.grey600),
                    ),
                  ],
                ),
                if (task.completedAt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '✓ Done',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
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

  void _showTaskDetails(Task task) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              task.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              task.description,
              style: const TextStyle(color: AppTheme.grey600),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Priority', style: TextStyle(fontSize: 11, color: AppTheme.grey600)),
                    Text(task.priority.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Duration', style: TextStyle(fontSize: 11, color: AppTheme.grey600)),
                    Text('${task.estimatedDuration} min', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleBreak() {
    setState(() {
      if (_breakStart == null) {
        _breakStart = DateTime.now();
        _breakEnd = null;
      } else if (_breakEnd == null) {
        _breakEnd = DateTime.now();
      } else {
        _breakStart = null;
        _breakEnd = null;
      }
    });
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final String priority; // 'high', 'medium', 'low'
  final int estimatedDuration; // in minutes
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.estimatedDuration,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });
}
