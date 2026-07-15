import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../models/operational_status.dart';
import '../../models/operational_health_model.dart';
import '../../widgets/command_center/quick_action_framework.dart';
import '../../widgets/command_center/universal_work_queue_ui.dart';
import '../../widgets/command_center/daily_briefing_ui.dart';
import '../../models/daily_briefing_model.dart';
import '../../models/user_model.dart';
import 'package:provider/provider.dart';
import '../../providers/operational_intelligence_provider.dart';
import '../../providers/auth_provider.dart';

class BranchManagerCommandCenter extends StatefulWidget {
  const BranchManagerCommandCenter({super.key});

  @override
  State<BranchManagerCommandCenter> createState() => _BranchManagerCommandCenterState();
}

class _BranchManagerCommandCenterState extends State<BranchManagerCommandCenter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      final branchId = user?.branchId ?? 'default_branch';
      context.read<OperationalIntelligenceProvider>().initBranchManager(branchId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text('Branch Manager Center', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.cream,
        elevation: 0,
      ),
      body: Consumer<OperationalIntelligenceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (provider.errorMessage != null) {
            return Center(child: Text(provider.errorMessage!));
          }

          final health = provider.branchHealth;
          final queue = provider.branchManagerQueue;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Morning Briefing
                DailyBriefingUI(briefing: _mockBriefing, onDismiss: () {}),
                const SizedBox(height: 24),

                // Section 2: Quick Actions
                QuickActionFramework(
                  actions: [
                    QuickAction(
                      icon: Icons.shopping_cart,
                      label: 'Create Purchase Request',
                      onTap: () {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('Create Purchase Request')));
                      },
                    ),
                    QuickAction(
                      icon: Icons.person,
                      label: 'Assign Employee',
                      onTap: () {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('Assign Employee')));
                      },
                    ),
                    QuickAction(
                      icon: Icons.fact_check,
                      label: 'Approve PO',
                      onTap: () {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('Approve PO')));
                      },
                      color: AppTheme.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Section 3: Branch Health Snapshot
                const Text(
                  'BRANCH HEALTH SNAPSHOT',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.grey600,
                  ),
                ),
                const SizedBox(height: 12),
                if (health != null) _buildBranchHealthSnapshot(health),
                const SizedBox(height: 32),

                // Section 4: Inventory Action Center
                const Text(
                  'INVENTORY ACTION CENTER',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.grey600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInventoryActionCard(
                  'Rice 5kg',
                  '7 Units',
                  '2 Days',
                  OperationalStatus.warning,
                ),
                _buildInventoryActionCard(
                  'Sunflower Oil 1L',
                  '2 Units',
                  '1 Day',
                  OperationalStatus.critical,
                ),
                const SizedBox(height: 32),

                // Section 5: Workforce Control Panel
                const Text(
                  'WORKFORCE CONTROL',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.grey600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildWorkforcePanel(),
                const SizedBox(height: 32),

                // Section 6: Actionable Work Queue
                const Text(
                  'MY WORK QUEUE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.grey600,
                  ),
                ),
                const SizedBox(height: 12),
                UniversalWorkQueueUI(
                  tasks: queue,
                  actionLabel: 'Review',
                  onTaskTap: (task) {},
                  onTaskAction: (task) {
                    provider.resolveTask(task.id);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Action selected for ${task.title}')));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBranchHealthSnapshot(OperationalHealthModel health) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${health.overallScore.toInt()}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Text('/ 100\nScore', style: TextStyle(color: AppTheme.grey600, fontSize: 16)),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHealthIndicator('Inventory', health.inventoryHealth),
              _buildHealthIndicator('Delivery', health.deliveryHealth),
              _buildHealthIndicator('Staff', health.employeeHealth),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthIndicator(String label, double health) {
    Color color = OperationalStatus.healthy.color;
    if (health < 70) {
      color = OperationalStatus.critical.color;
    } else if (health < 90)
      color = OperationalStatus.warning.color;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: health / 100,
                color: color,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            Text(
              '${health.toInt()}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
      ],
    );
  }

  Widget _buildInventoryActionCard(
    String item,
    String remaining,
    String stockout,
    OperationalStatus status,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: status.color.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Icon(status.icon, color: status.color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text('Remaining: $remaining', style: const TextStyle(color: AppTheme.grey600)),
            Text(
              'Predicted Stockout: $stockout',
              style: TextStyle(color: status.color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Purchase Request Executed')));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Purchase Request'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Transfer Initiated')));
                    },
                    child: const Text('Transfer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkforcePanel() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Present', '14', AppTheme.success),
                _buildStatItem('Late', '1', AppTheme.warning),
                _buildStatItem('Absent', '0', AppTheme.error),
                _buildStatItem('On Leave', '1', AppTheme.info),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.contact_phone, size: 18),
                label: const Text('Contact Late Employee'),
                onPressed: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Contacting Employee')));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.warning,
                  side: const BorderSide(color: AppTheme.warning),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  static final _mockBriefing = DailyBriefingModel(
    id: 'mock-briefing',
    role: UserRole.branchManager,
    date: DateTime.now(),
    createdAt: DateTime.now(),
    metrics: {'revenueYesterday': 82500, 'ordersPending': 23},
    urgentActionItems: [
      'Check stock levels for Milk and Bread by 10 AM.',
      'Rider Amit and Sunil are on leave. Re-assign routes.',
    ],
    insights: [
      'High demand expected for dairy and produce today.',
      'New inventory arriving at 2 PM.',
    ],
  );
}
