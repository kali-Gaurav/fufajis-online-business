import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/fulfillment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/packing_widgets.dart';
import 'order_queue_screen.dart';
import 'packing_screen.dart';
import 'quality_check_screen.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final auth = context.read<AuthProvider>();
    final fulfillment = context.read<FulfillmentProvider>();

    final shopId = auth.currentShop?.id ?? '';
    final branchId = auth.currentBranch?.id ?? '';
    final employeeId = auth.currentUser?.uid ?? '';

    if (shopId.isNotEmpty && branchId.isNotEmpty && employeeId.isNotEmpty) {
      try {
        await Future.wait([
          fulfillment.loadAssignedOrders(employeeId, shopId, branchId),
          fulfillment.loadTodayStats(employeeId, shopId),
        ]);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load data: $e'), backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                "Today's Orders",
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Order status cards
              _OrderStatusSection(),

              const SizedBox(height: 32),

              // Quick stats
              Text(
                'Quick Stats',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              _StatsGrid(),

              const SizedBox(height: 32),

              // Action buttons
              Text(
                'Quick Actions',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              _ActionButtons(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderStatusSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<FulfillmentProvider>(
      builder: (context, fulfillment, child) {
        final new_ = fulfillment.assignedOrders
            .where((o) => o.status.index == 0) // assigned
            .length;
        final packing = fulfillment.assignedOrders
            .where((o) => o.status.index == 1) // packing
            .length;
        final ready = fulfillment.assignedOrders
            .where((o) => o.status.index == 2) // ready
            .length;

        return Column(
          children: [
            _StatusCard(
              title: 'New',
              count: new_,
              color: AppTheme.warning,
              icon: Icons.new_releases,
            ),
            const SizedBox(height: 12),
            _StatusCard(
              title: 'Packing',
              count: packing,
              color: AppTheme.info,
              icon: Icons.local_shipping,
            ),
            const SizedBox(height: 12),
            _StatusCard(
              title: 'Ready',
              count: ready,
              color: AppTheme.success,
              icon: Icons.check_circle,
            ),
          ],
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;

  const _StatusCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const Spacer(),
          Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<FulfillmentProvider>(
      builder: (context, fulfillment, child) {
        final stats = fulfillment.todayStats;
        final efficiency = stats?.efficiency ?? 0;
        final quality = stats?.qualityScore ?? 0;
        final itemsPacked = stats?.totalItemsPacked ?? 0;

        return GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            StatsCard(
              label: 'Efficiency',
              value: efficiency.toStringAsFixed(1),
              unit: 'items/min',
              icon: Icons.speed,
            ),
            StatsCard(
              label: 'Quality',
              value: quality.toStringAsFixed(0),
              unit: '%',
              icon: Icons.check_circle,
            ),
            StatsCard(
              label: 'Items Packed',
              value: itemsPacked.toString(),
              unit: 'today',
              icon: Icons.inventory,
            ),
          ],
        );
      },
    );
  }
}

class _ActionButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 12,
      children: [
        _ActionButton(
          title: 'Accept New Order',
          subtitle: 'View and accept pending orders',
          icon: Icons.add_circle_outline,
          color: AppTheme.info,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrderQueueScreen()));
          },
        ),
        _ActionButton(
          title: 'View Packing Queue',
          subtitle: 'Continue with assigned orders',
          icon: Icons.list,
          color: AppTheme.warning,
          onTap: () {
            final fulfillment = context.read<FulfillmentProvider>();
            if (fulfillment.assignedOrders.isNotEmpty) {
              final order = fulfillment.assignedOrders.first;
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => PackingScreen(taskId: order.id)));
            } else {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('No orders assigned')));
            }
          },
        ),
        _ActionButton(
          title: 'Quality Check',
          subtitle: 'Review packed orders',
          icon: Icons.verified,
          color: AppTheme.success,
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const QualityCheckScreen()));
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }
}
