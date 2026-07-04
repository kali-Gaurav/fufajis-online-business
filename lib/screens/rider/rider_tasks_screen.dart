import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/command_center/daily_briefing_ui.dart';
import '../../models/daily_briefing_model.dart';
import '../../models/user_model.dart';
import 'package:provider/provider.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/auth_provider.dart';

class RiderTasksScreen extends StatefulWidget {
  const RiderTasksScreen({super.key});

  @override
  State<RiderTasksScreen> createState() => _RiderTasksScreenState();
}

class _RiderTasksScreenState extends State<RiderTasksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        context.read<DeliveryProvider>().loadTodayDeliveryTasks(auth.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeliveryProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final stats = provider.todayStats;
        final deliveries = provider.assignedDeliveries;
        final currentDelivery = provider.currentDelivery;

        final briefing = DailyBriefingModel(
          id: '1',
          role: UserRole.rider,
          date: DateTime.now(),
          createdAt: DateTime.now(),
          metrics: {
            'todaysDeliveries': stats?.completedDeliveries ?? 0,
            'currentBatch': deliveries.length,
            'expectedEarnings': '₹${stats!.totalEarnings.toStringAsFixed(0)}',
            'acceptanceRate': '${(stats.acceptanceRate) * 100}%',
          },
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Today's Briefing
              DailyBriefingUI(briefing: briefing, onDismiss: () {}),

              const SizedBox(height: 24),

              // Section 2: Current Active Task
              if (currentDelivery != null) ...[
                const Text(
                  'CURRENT ACTIVE TASK',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.grey600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildActiveTaskCard(context, currentDelivery),
                const SizedBox(height: 24),
              ] else if (deliveries.isNotEmpty) ...[
                const Text(
                  'NEXT ACTIVE TASK',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.grey600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildActiveTaskCard(context, deliveries.first),
                const SizedBox(height: 24),
              ],

              // Section 3: Work Queue
              const Text(
                'UPCOMING IN BATCH',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.grey600,
                ),
              ),
              const SizedBox(height: 12),
              ...deliveries.skip(currentDelivery != null ? 0 : 1).map((d) {
                return _buildUpcomingTaskCard(
                  'Task #${d.orderId}',
                  d.customerName ?? 'Unknown Customer',
                  '${((d.estimatedDistance ?? 0.0) / 1000).toStringAsFixed(1)} km',
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveTaskCard(BuildContext context, dynamic delivery) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'PICKUP',
                  style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold),
                ),
              ),
              const Text(
                'Before 10:25 AM',
                style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Order #${delivery.orderId}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Customer: ${delivery.customerName}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Distance: ${(delivery.estimatedDistance / 1000).toStringAsFixed(1)} km',
            style: const TextStyle(color: AppTheme.grey600),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                  onPressed: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Starting Navigation')));
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    context.read<DeliveryProvider>().completeDeliveryTask(delivery.id as String);
                    _handleTaskAction('Delivered');
                  },
                  child: const Text('Mark Complete'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: () => _showIncidentReportingSheet(context, delivery),
                  child: const Text('Report Issue', style: TextStyle(color: AppTheme.error)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingTaskCard(String title, String customer, String distance) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppTheme.grey200,
          child: Icon(Icons.location_on, color: AppTheme.grey600),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$customer • $distance'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Viewing $title')));
        },
      ),
    );
  }

  void _handleTaskAction(String action) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('⏳ Pending Sync: $action...')));

    // Simulate network delay then sync
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✓ Synced: $action')));
      }
    });
  }

  void _showIncidentReportingSheet(BuildContext context, dynamic delivery) {
    final categories = [
      'Customer Unreachable',
      'Wrong Address',
      'Item Missing',
      'Vehicle Issue',
      'Payment Issue',
      'Safety Concern',
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report Incident',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...categories.map(
                  (cat) => ListTile(
                    leading: const Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
                    title: Text(cat),
                    onTap: () {
                      Navigator.pop(context);
                      context.read<DeliveryProvider>().failDeliveryTask(delivery.id as String, cat);
                      _handleTaskAction('Incident: $cat');
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
