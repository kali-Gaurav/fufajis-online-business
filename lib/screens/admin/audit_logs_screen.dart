import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/security_event_service.dart';
import 'package:intl/intl.dart';

import '../../utils/app_theme.dart';

class AuditLogsScreen extends StatelessWidget {
  const AuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit & Security Logs', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SecurityEventService().getSecurityEventsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.adminAccent));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading logs: ${snapshot.error}'));
          }

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return const Center(child: Text('No audit logs found.'));
          }

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final event = log['event'] as String? ?? 'Unknown';
              final userId = log['userId'] as String? ?? 'System';
              final timestamp = log['timestamp'] != null
                  ? (log['timestamp'] as Timestamp).toDate()
                  : DateTime.now();

              final isError =
                  event.toLowerCase().contains('fail') || event.toLowerCase().contains('lockout');

              return ListTile(
                leading: Icon(
                  isError ? Icons.warning : Icons.info,
                  color: isError ? AppTheme.error : AppTheme.info,
                ),
                title: Text(event.toUpperCase()),
                subtitle: Text('User: $userId | Device: ${log['deviceName']}'),
                trailing: Text(
                  DateFormat('dd MMM, HH:mm').format(timestamp),
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
