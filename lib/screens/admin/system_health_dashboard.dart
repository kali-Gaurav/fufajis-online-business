import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/system_health_service.dart';
import '../../utils/app_theme.dart';

class SystemHealthDashboard extends StatefulWidget {
  const SystemHealthDashboard({super.key});

  @override
  State<SystemHealthDashboard> createState() => _SystemHealthDashboardState();
}

class _SystemHealthDashboardState extends State<SystemHealthDashboard> {
  final SystemHealthService _healthService = SystemHealthService();
  Timer? _refreshTimer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _healthService.addListener(_onHealthChanged);
    _runDiagnostics();
    // Auto refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _runDiagnostics();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _healthService.removeListener(_onHealthChanged);
    _healthService.dispose();
    super.dispose();
  }

  void _onHealthChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _runDiagnostics() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    await _healthService.runFullDiagnostic();
    if (mounted) setState(() => _isLoading = false);
  }

  Color _getStatusColor(ServiceStatus status) {
    switch (status) {
      case ServiceStatus.healthy:
        return AppTheme.success;
      case ServiceStatus.degraded:
        return AppTheme.warning;
      case ServiceStatus.down:
        return AppTheme.error;
      case ServiceStatus.unknown:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(ServiceStatus status) {
    switch (status) {
      case ServiceStatus.healthy:
        return Icons.check_circle;
      case ServiceStatus.degraded:
        return Icons.warning;
      case ServiceStatus.down:
        return Icons.error;
      case ServiceStatus.unknown:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final healthStates = _healthService.healthStates.values.toList();

    int healthyCount = healthStates.where((s) => s.status == ServiceStatus.healthy).length;
    int degradedCount = healthStates.where((s) => s.status == ServiceStatus.degraded).length;
    int downCount = healthStates.where((s) => s.status == ServiceStatus.down).length;

    bool systemHealthy = downCount == 0 && degradedCount == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Health NOC', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _runDiagnostics,
              tooltip: 'Run Full Diagnostic',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Status Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: systemHealthy
                    ? AppTheme.success.withAlpha((255 * 0.1).toInt())
                    : (downCount > 0
                          ? AppTheme.error.withAlpha((255 * 0.1).toInt())
                          : AppTheme.warning.withAlpha((255 * 0.1).toInt())),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: systemHealthy
                      ? AppTheme.success
                      : (downCount > 0 ? AppTheme.error : AppTheme.warning),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    systemHealthy
                        ? Icons.verified_user
                        : (downCount > 0 ? Icons.error : Icons.warning),
                    color: systemHealthy
                        ? AppTheme.success
                        : (downCount > 0 ? AppTheme.error : AppTheme.warning),
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          systemHealthy
                              ? 'All Systems Operational'
                              : (downCount > 0 ? 'System Outage Detected' : 'System Degraded'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$healthyCount healthy, $degradedCount degraded, $downCount down',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'External Services',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Service List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: healthStates.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final status = healthStates[index];
                return ListTile(
                  leading: Icon(
                    _getStatusIcon(status.status),
                    color: _getStatusColor(status.status),
                    size: 32,
                  ),
                  title: Text(
                    status.serviceName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(status.message),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (status.latency != null)
                        Text(
                          '${status.latency!.inMilliseconds} ms',
                          style: TextStyle(
                            color: status.latency!.inMilliseconds > 500
                                ? AppTheme.warning
                                : AppTheme.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      Text(
                        'Last checked: ${status.lastChecked.hour.toString().padLeft(2, '0')}:${status.lastChecked.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
