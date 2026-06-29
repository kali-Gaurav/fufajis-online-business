import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../models/operational_status.dart';
import '../../widgets/command_center/quick_action_framework.dart';
import '../../widgets/command_center/universal_work_queue_ui.dart';
import 'package:provider/provider.dart';
import '../../providers/operational_intelligence_provider.dart';
import '../../providers/auth_provider.dart';

class DispatcherCommandCenter extends StatefulWidget {
  const DispatcherCommandCenter({super.key});

  @override
  State<DispatcherCommandCenter> createState() => _DispatcherCommandCenterState();
}

class _DispatcherCommandCenterState extends State<DispatcherCommandCenter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      final branchId = user?.branchId ?? 'default_branch';
      context.read<OperationalIntelligenceProvider>().initDispatcher(branchId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text('Dispatcher Control', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.cream,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search tapped')));
          }),
        ],
      ),
      body: Consumer<OperationalIntelligenceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (provider.errorMessage != null) {
            return Center(child: Text(provider.errorMessage!));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Quick Actions
                QuickActionFramework(
                  actions: [
                    QuickAction(icon: Icons.person_add, label: 'Assign Rider', onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assign Rider Action')));
                    }),
                    QuickAction(icon: Icons.map, label: 'Create Batch', onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create Batch Action')));
                    }),
                    QuickAction(icon: Icons.warning, label: 'Resolve Incident', onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resolve Incident Action')));
                    }, color: AppTheme.warning),
                  ],
                ),
                const SizedBox(height: 24),

                // Section 2: Operational Health
                const Text('LIVE OPERATIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey600)),
                const SizedBox(height: 12),
                _buildOperationalHealthPanel(provider),
                
                const SizedBox(height: 32),

                // Section 3: Rider Capacity (Heat Map)
                const Text('RIDER CAPACITY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey600)),
                const SizedBox(height: 12),
                _buildRiderCapacityList(),

                const SizedBox(height: 32),

                // Section 4: Dispatch & SLA Queue (Universal Work Queue)
                const Text('DISPATCH & RISK QUEUE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey600)),
                const SizedBox(height: 12),
                UniversalWorkQueueUI(
                  tasks: provider.dispatchQueue,
                  actionLabel: 'Assign / Resolve',
                  onTaskTap: (task) {},
                  onTaskAction: (task) {
                    provider.resolveTask(task.id);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Resolved ${task.title}')));
                  },
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildOperationalHealthPanel(OperationalIntelligenceProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Unassigned', provider.unassignedOrdersCount.toString(), AppTheme.error),
              _buildStatItem('Active Riders', provider.activeRidersCount.toString(), AppTheme.info),
              _buildStatItem('SLA Risks', provider.slaRisksCount.toString(), AppTheme.warning),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Available', '7', AppTheme.success),
              _buildStatItem('Busy', '11', Colors.grey.shade700),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto-Assign executed')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                  child: const Text('Auto-Assign Available'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rebalance triggered')));
                  },
                  child: const Text('Rebalance Load'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildRiderCapacityList() {
    return Column(
      children: [
        _buildRiderCapacityBar('Rider A (Available)', 1, 5, OperationalStatus.healthy),
        _buildRiderCapacityBar('Rider B (Busy)', 5, 5, OperationalStatus.critical),
        _buildRiderCapacityBar('Rider C (Busy)', 4, 5, OperationalStatus.warning),
      ],
    );
  }

  Widget _buildRiderCapacityBar(String name, int current, int max, OperationalStatus status) {
    final percent = current / max;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: Colors.grey[200],
                color: status.color,
                minHeight: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 40, child: Text('$current / $max', style: TextStyle(color: status.color, fontWeight: FontWeight.bold, fontSize: 12))),
        ],
      ),
    );
  }
}
