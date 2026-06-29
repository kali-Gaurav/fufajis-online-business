import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../utils/app_theme.dart';

/// Admin screen to review and manually retry failed RDS sync operations.
/// Shows docs from the [dead_letter_rds_sync] Firestore collection.
class DeadLetterDashboardScreen extends StatelessWidget {
  const DeadLetterDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RDS Sync Failures', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.error,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('dead_letter_rds_sync')
            .orderBy('failedAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.adminAccent));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, color: AppTheme.success, size: 64),
                  SizedBox(height: 16),
                  Text('No pending RDS sync failures',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }
          final docs = snap.data!.docs;
          return Column(
            children: [
              Container(
                color: AppTheme.primaryLight,
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                child: Text(
                  '${docs.length} pending failure(s) — the background retry job runs every 15 min.',
                  style: const TextStyle(fontSize: 13, color: AppTheme.warning),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final failedAt = (d['failedAt'] as Timestamp?)?.toDate();
                    final retryCount = d['retryCount'] ?? 0;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: retryCount >= 4 ? AppTheme.error : AppTheme.warning,
                          child: Text('$retryCount',
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        title: Text('Order #${d['orderNumber'] ?? d['orderId']}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: ${d['status']} | ₹${d['totalAmount']}'),
                            Text(d['error'] ?? 'Unknown error',
                                style: const TextStyle(color: AppTheme.error, fontSize: 11),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            if (failedAt != null)
                              Text('Failed: ${DateFormat('dd MMM HH:mm').format(failedAt)}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        trailing: retryCount >= 5
                            ? const Chip(label: Text('Exhausted'),
                                backgroundColor: AppTheme.error, labelStyle: TextStyle(color: Colors.white))
                            : null,
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
