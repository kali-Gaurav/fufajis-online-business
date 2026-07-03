import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/command_center/quick_action_framework.dart';
import '../../widgets/command_center/universal_work_queue_ui.dart';
import '../../models/task_queue_model.dart';
import '../../models/operational_status.dart';

class SupplierCommandCenter extends StatefulWidget {
  const SupplierCommandCenter({super.key});

  @override
  State<SupplierCommandCenter> createState() => _SupplierCommandCenterState();
}

class _SupplierCommandCenterState extends State<SupplierCommandCenter> {
  final List<TaskQueueModel> _mockQueue = [
    TaskQueueModel(
      id: 'task-sup-1',
      title: 'Submit Quote for PR-991',
      description: 'Requested: 50x Rice 5kg. Due Today.',
      taskType: TaskQueueType.pricing_approval,
      priorityScore: 80,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      priority: TaskPriority.high,
    ),
    TaskQueueModel(
      id: 'task-sup-2',
      title: 'Dispatch PO-1022',
      description: 'Order approved. Awaiting dispatch confirmation.',
      taskType: TaskQueueType.general_action,
      priorityScore: 95,
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      priority: TaskPriority.urgent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text('Supplier Portal', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.cream,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Business Overview
            _buildBusinessOverview(),
            const SizedBox(height: 24),

            // Section 2: Quick Actions
            QuickActionFramework(
              actions: [
                QuickAction(
                  icon: Icons.local_shipping,
                  label: 'Mark Dispatched',
                  onTap: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Mark Dispatched Action')));
                  },
                ),
                QuickAction(
                  icon: Icons.request_quote,
                  label: 'Submit Quotes',
                  onTap: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Submit Quotes Action')));
                  },
                ),
                QuickAction(
                  icon: Icons.account_balance,
                  label: 'View Settlements',
                  onTap: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('View Settlements Action')));
                  },
                  color: AppTheme.info,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Section 3: Active Orders Tracking
            const Text(
              'ACTIVE ORDERS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey600),
            ),
            const SizedBox(height: 12),
            _buildOrderTrackingCard('PO-1022', 'Awaiting Dispatch', OperationalStatus.warning),
            _buildOrderTrackingCard('PO-1020', 'In Transit', OperationalStatus.healthy),
            const SizedBox(height: 32),

            // Section 4: Actionable Work Queue
            const Text(
              'ACTION REQUIRED',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey600),
            ),
            const SizedBox(height: 12),
            UniversalWorkQueueUI(
              tasks: _mockQueue,
              actionLabel: 'Respond',
              onTaskTap: (task) {},
              onTaskAction: (task) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Action selected for ${task.title}')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.ownerAccent, AppTheme.info],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.info.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pending Settlements', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          const Text(
            '₹1,45,000',
            style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat('Pending POs', '4'),
              _buildMiniStat('Quotes Needed', '2'),
              _buildMiniStat('In Transit', '1'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildOrderTrackingCard(String title, String status, OperationalStatus opStatus) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: opStatus.color.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: Icon(Icons.inventory, color: opStatus.color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(status),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Action Tapped')));
        },
      ),
    );
  }
}
