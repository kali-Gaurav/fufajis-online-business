import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../models/operational_status.dart';
import '../../models/operational_health_model.dart';
import '../../widgets/command_center/quick_action_framework.dart';
import '../../widgets/command_center/universal_work_queue_ui.dart';
import '../../models/task_queue_model.dart';

class OwnerLogisticsCommandCenter extends StatefulWidget {
  const OwnerLogisticsCommandCenter({super.key});

  @override
  State<OwnerLogisticsCommandCenter> createState() => _OwnerLogisticsCommandCenterState();
}

class _OwnerLogisticsCommandCenterState extends State<OwnerLogisticsCommandCenter> {
  final List<OperationalHealthModel> _mockBranches = [
    OperationalHealthModel(branchId: 'Sector 4 (HQ)', inventoryHealth: 92, deliveryHealth: 88, employeeHealth: 95, customerHealth: 90, financialHealth: 96, lastUpdated: DateTime.now()),
    OperationalHealthModel(branchId: 'Sector 10', inventoryHealth: 65, deliveryHealth: 70, employeeHealth: 80, customerHealth: 85, financialHealth: 88, lastUpdated: DateTime.now()), // Needs attention
    OperationalHealthModel(branchId: 'Sector 15', inventoryHealth: 85, deliveryHealth: 92, employeeHealth: 90, customerHealth: 88, financialHealth: 90, lastUpdated: DateTime.now()),
  ];

  final List<TaskQueueModel> _mockEscalations = [
    TaskQueueModel(
      id: 'esc-1',
      title: 'Sector 10: Critical Stockout',
      description: 'Rice inventory below 1 day supply. Immediate PO required.',
      taskType: TaskQueueType.purchase_approval,
      priorityScore: 98,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      priority: TaskPriority.urgent,
      escalated: true,
    ),
    TaskQueueModel(
      id: 'esc-2',
      title: 'HQ: SLA Breaches Spike',
      description: '7 orders exceeded SLA in the last hour.',
      taskType: TaskQueueType.sla_breach_risk,
      priorityScore: 85,
      createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
      priority: TaskPriority.high,
      escalated: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text('Enterprise Logistics Control', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.cream,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Enterprise Overview
            _buildEnterpriseOverview(),
            const SizedBox(height: 24),

            // Section 2: Quick Actions
            QuickActionFramework(
              actions: [
                QuickAction(icon: Icons.store, label: 'Add Branch', onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add Branch Action')));
                }),
                QuickAction(icon: Icons.inventory, label: 'Global Purchase', onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Global Purchase Action')));
                }),
                QuickAction(icon: Icons.trending_up, label: 'Financials', onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Financials Action')));
                }, color: AppTheme.success),
              ],
            ),
            const SizedBox(height: 32),

            // Section 3: Branch Health Matrix
            const Text('MULTI-BRANCH HEALTH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey600)),
            const SizedBox(height: 12),
            ..._mockBranches.map((b) => _buildBranchHealthRow(b)),
            const SizedBox(height: 32),

            // Section 4: Enterprise Escalations
            const Text('ENTERPRISE ESCALATIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey600)),
            const SizedBox(height: 12),
            UniversalWorkQueueUI(
              tasks: _mockEscalations,
              actionLabel: 'Intervene',
              onTaskTap: (task) {},
              onTaskAction: (task) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Intervening: ${task.title}')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnterpriseOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Revenue Today', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          const Text('₹2,45,000', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat('Active Branches', '3'),
              _buildMiniStat('Total Riders', '45'),
              _buildMiniStat('Pending POs', '12'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildBranchHealthRow(OperationalHealthModel branch) {
    final score = branch.overallScore;
    OperationalStatus status = OperationalStatus.healthy;
    if (score < 70) {
      status = OperationalStatus.critical;
    } else if (score < 85) status = OperationalStatus.warning;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: status.color.withValues(alpha: 0.5), width: 2),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: status.color.withValues(alpha: 0.2),
          child: Text(score.toInt().toString(), style: TextStyle(color: status.color, fontWeight: FontWeight.bold)),
        ),
        title: Text(branch.branchId, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'Inv: ${branch.inventoryHealth.toInt()}% | Del: ${branch.deliveryHealth.toInt()}% | Staff: ${branch.employeeHealth.toInt()}%',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
          onPressed: () {
            // Navigate to detailed Branch Health Dashboard
          },
        ),
      ),
    );
  }
}
