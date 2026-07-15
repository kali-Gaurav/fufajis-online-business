import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/delivery_ledger_service.dart';
import '../../services/delivery_workflow_engine.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import 'rider_navigation_screen.dart';

class RiderRouteScreen extends StatefulWidget {
  const RiderRouteScreen({super.key});

  @override
  State<RiderRouteScreen> createState() => _RiderRouteScreenState();
}

class _RiderRouteScreenState extends State<RiderRouteScreen> {
  final DeliveryLedgerService _ledgerService = DeliveryLedgerService();
  final DeliveryWorkflowEngine _workflowEngine = DeliveryWorkflowEngine();

  List<Map<String, dynamic>> _routes = [];
  final Map<String, List<Map<String, dynamic>>> _routeTasks = {};
  String? _expandedRouteId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final riderUid = authProvider.currentUser?.uid;

      if (riderUid != null) {
        // Find the matching rider profile first
        final riders = await _ledgerService.getAvailableRiders();
        final riderProfile = riders.firstWhere(
          (r) =>
              r['phone'] == authProvider.currentUser?.phoneNumber ||
              r['name'] == authProvider.currentUser?.name,
          orElse: () => <String, dynamic>{},
        );

        final riderId = riderProfile['id'] as String?;
        if (riderId != null) {
          final activeRoutes = await _ledgerService.getRoutesForRider(riderId);
          setState(() {
            _routes = activeRoutes;
          });

          for (final route in activeRoutes) {
            final routeId = route['id'] as String;
            final tasks = await _ledgerService.getRouteTasks(routeId);
            setState(() {
              _routeTasks[routeId] = tasks;
            });
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading routes: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _transitionTaskStatus(Map<String, dynamic> task, String toStatus) async {
    final taskId = task['id'] as String;
    final routeId = task['route_id'] as String;
    final fromStatus = task['status'] as String;

    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final res = await _workflowEngine.transitionTask(
        taskId: taskId,
        routeId: routeId,
        fromStatus: fromStatus,
        toStatus: toStatus,
        actorId: authProvider.currentUser?.uid,
      );

      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $toStatus!'),
            backgroundColor: AppTheme.success,
          ),
        );
        // Refresh tasks and routes
        final updatedTasks = await _ledgerService.getRouteTasks(routeId);
        setState(() {
          _routeTasks[routeId] = updatedTasks;
        });
      } else {
        throw Exception(res.error ?? 'Unknown error');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Route Manifests', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRoutes)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _routes.isEmpty
          ? const Center(child: Text('No active routes assigned to you.'))
          : ListView.builder(
              itemCount: _routes.length,
              itemBuilder: (context, index) {
                final route = _routes[index];
                final routeId = route['id'] as String;
                final isExpanded = _expandedRouteId == routeId;
                final tasks = _routeTasks[routeId] ?? [];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.local_shipping,
                          color: route['status'] == 'active' ? AppTheme.success : AppTheme.info,
                        ),
                        title: Text(route['route_name'] as String? ?? 'Route Manifest'),
                        subtitle: Text(
                          'Distance: ${(route['total_distance'] as num?)?.toStringAsFixed(1) ?? '0'} km | Est. Time: ${route['estimated_duration_minutes'] ?? '0'} mins',
                        ),
                        trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                        onTap: () {
                          setState(() {
                            _expandedRouteId = isExpanded ? null : routeId;
                          });
                        },
                      ),
                      if (isExpanded) ...[
                        const Divider(height: 1),
                        ...tasks.map((task) => _buildTaskTile(task)),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final status = task['status'] as String;
    final seq = task['stop_sequence'] as int;

    Color statusColor = AppTheme.info;
    if (status == 'delivered') statusColor = AppTheme.success;
    if (status == 'failed' || status == 'cancelled') statusColor = AppTheme.error;
    if (status == 'out_for_delivery') statusColor = AppTheme.warning;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primary.withOpacity(0.1),
            child: Text(
              '$seq',
              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['customer_name'] as String? ?? 'Customer',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  task['address'] as String? ?? 'No Address',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildActionButtons(task),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> task) {
    final status = task['status'] as String;

    if (status == 'assigned') {
      return Row(
        children: [
          ElevatedButton(
            onPressed: () => _transitionTaskStatus(task, 'picked_up'),
            child: const Text('Mark Picked Up'),
          ),
        ],
      );
    } else if (status == 'picked_up') {
      return Row(
        children: [
          ElevatedButton(
            onPressed: () => _transitionTaskStatus(task, 'out_for_delivery'),
            child: const Text('Start Delivery'),
          ),
        ],
      );
    } else if (status == 'out_for_delivery') {
      return Row(
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _transitionTaskStatus(task, 'delivered'),
            child: const Text('Mark Delivered'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => _transitionTaskStatus(task, 'failed'),
            child: const Text('Mark Failed'),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.map, color: AppTheme.info),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RiderNavigationScreen(
                    destLat: task['latitude'] as double? ?? 25.1006,
                    destLng: task['longitude'] as double? ?? 76.5156,
                    orderId: task['id'] as String,
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
