import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/audit_service.dart';
import '../../../utils/app_theme.dart';

class ActivityFeedScreen extends StatelessWidget {
  const ActivityFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Feed', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: AuditService().getLogsStream(limit: 50),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('No recent activity recorded.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final logs = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (context, index) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final log = logs[index];
              return _ActivityItem(log: log);
            },
          );
        },
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final Map<String, dynamic> log;

  const _ActivityItem({required this.log});

  IconData _getIcon(String action) {
    if (action.contains('agent')) return Icons.smart_toy;
    if (action.contains('order')) return Icons.shopping_bag;
    if (action.contains('product')) return Icons.inventory_2;
    if (action.contains('price')) return Icons.price_change;
    if (action.contains('login')) return Icons.login;
    return Icons.info_outline;
  }

  Color _getColor(String action) {
    if (action.contains('Approved')) return Colors.green;
    if (action.contains('Rejected')) return Colors.red;
    if (action.contains('agent')) return AppTheme.ownerAccent;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = log['timestamp'] as dynamic;
    final date = timestamp != null
        ? (timestamp is DateTime ? timestamp : (timestamp).toDate())
        : DateTime.now();
    final dateStr = DateFormat('h:mm a • d MMM').format(date);
    final action = log['action']?.toString() ?? 'unknown';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getColor(action).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_getIcon(action), size: 18, color: _getColor(action)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    log['userName'] ?? 'System',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(dateStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 4),
              Text(log['description'] ?? '', style: const TextStyle(fontSize: 14)),
              if (log['reasoning'] != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'AI Reasoning: ${log['reasoning']}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
