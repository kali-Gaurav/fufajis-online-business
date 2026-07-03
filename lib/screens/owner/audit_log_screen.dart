import 'package:flutter/material.dart';
import '../../services/audit_logger.dart';
import 'package:intl/intl.dart';

import '../../utils/app_theme.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final AuditLoggerService _auditService = AuditLoggerService();
  List<AuditLog> _logs = [];
  bool _isLoading = true;
  AuditActionType? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await _auditService.getRecentLogs(limit: 100, filterType: _selectedFilter);
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Audit Logs', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Events', style: TextStyle(fontWeight: FontWeight.w700)),
              leading: Radio<AuditActionType?>(
                value: null,
                groupValue: _selectedFilter,
                onChanged: (val) {
                  setState(() => _selectedFilter = val);
                  Navigator.pop(context);
                  _loadLogs();
                },
              ),
            ),
            ...AuditActionType.values.map(
              (type) => ListTile(
                title: Text(_formatEnumName(type.name)),
                leading: Radio<AuditActionType?>(
                  value: type,
                  groupValue: _selectedFilter,
                  onChanged: (val) {
                    setState(() => _selectedFilter = val);
                    Navigator.pop(context);
                    _loadLogs();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEnumName(String name) {
    return name.replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}').toUpperCase();
  }

  Color _getLogColor(AuditActionType type) {
    switch (type) {
      case AuditActionType.securityEvent:
        return AppTheme.error.withValues(alpha: 0.15);
      case AuditActionType.financialEvent:
        return AppTheme.success.withValues(alpha: 0.15);
      case AuditActionType.adminAction:
        return Colors.purple.shade100;
      case AuditActionType.employeeAction:
        return AppTheme.info.withValues(alpha: 0.15);
    }
  }

  IconData _getLogIcon(AuditActionType type) {
    switch (type) {
      case AuditActionType.securityEvent:
        return Icons.security;
      case AuditActionType.financialEvent:
        return Icons.attach_money;
      case AuditActionType.adminAction:
        return Icons.admin_panel_settings;
      case AuditActionType.employeeAction:
        return Icons.badge;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log Center', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilterDialog),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent))
          : _logs.isEmpty
          ? const Center(child: Text('No audit logs found'))
          : ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: _getLogColor(log.type),
                  child: ExpansionTile(
                    leading: Icon(_getLogIcon(log.type)),
                    title: Text(log.action, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${DateFormat('MMM dd, yyyy HH:mm').format(log.timestamp)} • User: ${log.userId}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Role', log.role),
                            _buildDetailRow('Branch ID', log.branchId ?? 'N/A'),
                            _buildDetailRow('Device', log.deviceInfo),
                            _buildDetailRow('IP Address', log.ipAddress ?? 'N/A'),
                            if (log.metadata != null && log.metadata!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Metadata:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  log.metadata.toString(),
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
