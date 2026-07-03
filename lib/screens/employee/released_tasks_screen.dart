import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/task_assignment_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common/fj_button.dart';
import '../../widgets/common/fj_card.dart';

class ReleasedTasksScreen extends StatefulWidget {
  const ReleasedTasksScreen({super.key});

  @override
  State<ReleasedTasksScreen> createState() => _ReleasedTasksScreenState();
}

class _ReleasedTasksScreenState extends State<ReleasedTasksScreen> {
  final TaskAssignmentService _taskService = TaskAssignmentService();
  bool _isAutoAssigning = false;

  Future<void> _handleAutoAssign() async {
    setState(() => _isAutoAssigning = true);
    final auth = context.read<AuthProvider>();
    final shopId = auth.currentShop?.id ?? 'shop_001';
    final branchId = auth.currentBranch?.id ?? '';

    try {
      final assigned = await _taskService.autoAssignTasks(shopId: shopId, branchId: branchId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              assigned > 0
                  ? '✓ Successfully auto-assigned $assigned tasks to employees!'
                  : 'No unassigned tasks or checked-in employees found.',
            ),
            backgroundColor: assigned > 0 ? AppTheme.success : AppTheme.grey800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-assign failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isAutoAssigning = false);
    }
  }

  Future<void> _claimTask(EmployeeTask task) async {
    final auth = context.read<AuthProvider>();
    final shopId = auth.currentShop?.id ?? 'shop_001';
    final employeeId = auth.currentUser?.uid ?? '';
    final employeeName = auth.currentUser?.name ?? 'Employee';

    try {
      await _taskService.claimTask(
        shopId: shopId,
        taskId: task.id,
        employeeId: employeeId,
        employeeName: employeeName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Claimed: ${task.title}'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to claim: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final shopId = auth.currentShop?.id ?? 'shop_001';
    final branchId = auth.currentBranch?.id ?? '';

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text('Released Tasks Pool', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isAutoAssigning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                  )
                : const Icon(Icons.auto_awesome),
            tooltip: 'Run Auto-Assignment',
            onPressed: _isAutoAssigning ? null : _handleAutoAssign,
          ),
        ],
      ),
      body: StreamBuilder<List<EmployeeTask>>(
        stream: _taskService.streamReleasedTasks(shopId, branchId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: AppTheme.error),
              ),
            );
          }

          final tasks = snapshot.data ?? [];

          if (tasks.isEmpty) {
            return RefreshIndicator(
              onRefresh: _handleAutoAssign,
              child: ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_turned_in_outlined,
                          size: 64,
                          color: AppTheme.grey400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No Released Tasks!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.grey700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'All tasks are currently assigned or completed.',
                          style: TextStyle(fontSize: 14, color: AppTheme.grey500),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Pull down to refresh and run dispatcher',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.grey400,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _handleAutoAssign,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _buildTaskCard(task);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(EmployeeTask task) {
    final Color priorityColor = _getPriorityColor(task.priority);
    final IconData typeIcon = _getTypeIcon(task.type);

    return FjCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(typeIcon, color: priorityColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.grey900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Est: ${task.timeEstimateMinutes} mins · Created ${DateFormat('hh:mm a').format(task.createdAt)}',
                        style: const TextStyle(color: AppTheme.grey600, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.priority.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(task.description, style: const TextStyle(fontSize: 13, color: AppTheme.grey700)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FjButton(
                  label: 'Claim Task',
                  icon: Icons.add_circle_outline,
                  height: 36,
                  onPressed: () => _claimTask(task),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(EmployeeTaskPriority priority) {
    switch (priority) {
      case EmployeeTaskPriority.urgent:
        return AppTheme.error;
      case EmployeeTaskPriority.high:
        return AppTheme.warning;
      case EmployeeTaskPriority.medium:
        return AppTheme.info;
      case EmployeeTaskPriority.low:
        return AppTheme.success;
    }
  }

  IconData _getTypeIcon(EmployeeTaskType type) {
    switch (type) {
      case EmployeeTaskType.packing:
        return Icons.inventory_outlined;
      case EmployeeTaskType.low_stock_audit:
        return Icons.warning_amber_rounded;
      case EmployeeTaskType.return_processing:
        return Icons.assignment_return_outlined;
      case EmployeeTaskType.delivery:
        return Icons.delivery_dining;
    }
  }
}
