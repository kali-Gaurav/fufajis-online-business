import 'package:flutter/material.dart';
import '../../models/task_queue_model.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../utils/app_theme.dart';

class UniversalWorkQueueUI extends StatelessWidget {
  final List<TaskQueueModel> tasks;
  final Function(TaskQueueModel) onTaskTap;
  final Function(TaskQueueModel) onTaskAction;
  final String actionLabel;

  const UniversalWorkQueueUI({
    super.key,
    required this.tasks,
    required this.onTaskTap,
    required this.onTaskAction,
    this.actionLabel = 'Action',
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, size: 48, color: AppTheme.success),
                SizedBox(height: 16),
                Text(
                  'No pending tasks in your queue.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('You are fully caught up.'),
              ],
            ),
          ),
        ),
      );
    }

    // Sort by priority score (descending)
    final sortedTasks = List<TaskQueueModel>.from(tasks);
    sortedTasks.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedTasks.length,
      itemBuilder: (context, index) {
        final task = sortedTasks[index];
        return _buildTaskCard(context, task);
      },
    );
  }

  Widget _buildTaskCard(BuildContext context, TaskQueueModel task) {
    Color priorityColor;
    if (task.priorityScore >= 80) {
      priorityColor = AppTheme.error;
    } else if (task.priorityScore >= 50) {
      priorityColor = AppTheme.warning;
    } else {
      priorityColor = AppTheme.info;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: task.priorityScore >= 80 ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: priorityColor.withValues(alpha: task.priorityScore >= 80 ? 0.5 : 0.0),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => onTaskTap(task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Score: ${task.priorityScore}',
                          style: TextStyle(
                            color: priorityColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (task.escalated) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning, size: 12, color: AppTheme.error),
                              SizedBox(width: 4),
                              Text(
                                'Escalated',
                                style: TextStyle(
                                  color: AppTheme.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    timeago.format(task.createdAt),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(task.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(task.description, style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => onTaskAction(task),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: priorityColor,
                      side: BorderSide(color: priorityColor),
                    ),
                    child: Text(actionLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
