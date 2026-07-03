import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../utils/app_theme.dart';
import '../../services/sqlite_service.dart';
import '../../services/reconciliation_service.dart';

class SyncHealthDashboard extends StatefulWidget {
  const SyncHealthDashboard({super.key});

  @override
  State<SyncHealthDashboard> createState() => _SyncHealthDashboardState();
}

class _SyncHealthDashboardState extends State<SyncHealthDashboard> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int _conflictCount = 0;
  int _deadLetterCount = 0;
  double _averageSyncDelayMs = 0;
  int _pendingRDSWriteCount = 0;

  String _lastReconTime = 'Never';
  String _lastReconStatus = 'UNKNOWN';
  int _unresolvedAnomalies = 0;

  bool _isLoading = true;
  bool _isReconciling = false;

  @override
  void initState() {
    super.initState();
    _fetchMetrics();
  }

  Future<void> _fetchMetrics() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. Conflicts
      final conflictsSnap = await _db
          .collectionGroup('inventory_alerts')
          .where('type', isEqualTo: 'sync_conflict')
          .where('resolved', isEqualTo: false)
          .count()
          .get();
      _conflictCount = conflictsSnap.count ?? 0;

      // 2. Dead Letters & Average Delay
      final metricsSnap = await _db.collection('sync_health_metrics').get();
      int totalDeadLetters = 0;
      double totalDelay = 0;
      int deviceCount = 0;

      for (var doc in metricsSnap.docs) {
        final data = doc.data();
        totalDeadLetters += (data['deadLetterCount'] as int?) ?? 0;
        totalDelay += (data['averageSyncDelayMs'] as num?)?.toDouble() ?? 0.0;
        deviceCount++;
      }

      _deadLetterCount = totalDeadLetters;
      _averageSyncDelayMs = deviceCount > 0 ? totalDelay / deviceCount : 0.0;

      // 3. Pending RDS Writes Count from SQLite
      _pendingRDSWriteCount = await SqliteService().getPendingRDSWriteCount();

      // 4. Last Reconciliation run details
      final runSnap = await _db
          .collection('reconciliation_runs')
          .orderBy('completedAt', descending: true)
          .limit(1)
          .get();
      if (runSnap.docs.isNotEmpty) {
        final data = runSnap.docs.first.data();
        final completed = data['completedAt'] as Timestamp?;
        if (completed != null) {
          final dt = completed.toDate();
          _lastReconTime =
              "${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
        }
        _lastReconStatus = (data['status'] as String? ?? 'unknown').toUpperCase();
      }

      // 5. Unresolved anomalies count
      final anomaliesSnap = await _db
          .collection('transaction_integrity_events')
          .where('status', isEqualTo: 'UNRESOLVED')
          .count()
          .get();
      _unresolvedAnomalies = anomaliesSnap.count ?? 0;
    } catch (e) {
      debugPrint('[SyncHealthDashboard] Error fetching metrics: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerManualReconciliation() async {
    setState(() => _isReconciling = true);

    try {
      final res = await ReconciliationService().runFullNightlyReconciliation();
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reconciliation run complete! Anomalies found: ${res['anomaliesCount']}'),
            backgroundColor: res['anomaliesCount'] > 0 ? Colors.orange : Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reconciliation failed: ${res['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error triggering reconciliation: $e'), backgroundColor: Colors.red),
      );
    }

    if (mounted) {
      setState(() => _isReconciling = false);
      await _fetchMetrics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sync & Reconciliation NOC',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchMetrics)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.adminAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top NOC Summary Cards
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: [
                      _buildMetricCard(
                        title: 'Unresolved Conflicts',
                        value: _conflictCount.toString(),
                        icon: Icons.merge_type,
                        color: _conflictCount > 0 ? AppTheme.error : AppTheme.success,
                      ),
                      _buildMetricCard(
                        title: 'Dead Letters (FCM Queue)',
                        value: _deadLetterCount.toString(),
                        icon: Icons.mail_outline,
                        color: _deadLetterCount > 0 ? AppTheme.error : AppTheme.success,
                      ),
                      _buildMetricCard(
                        title: 'SQLite Pending RDS Writes',
                        value: _pendingRDSWriteCount.toString(),
                        icon: Icons.storage,
                        color: _pendingRDSWriteCount > 0 ? AppTheme.warning : AppTheme.success,
                      ),
                      _buildMetricCard(
                        title: 'Avg Sync Delay',
                        value: '${_averageSyncDelayMs.toStringAsFixed(0)} ms',
                        icon: Icons.timer,
                        color: _averageSyncDelayMs > 5000 ? AppTheme.warning : AppTheme.success,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Reconciliation Section
                  const Text(
                    'Subsystem Reconciliation Control',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Last Execution Status:',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _lastReconStatus == 'CLEAN'
                                      ? Colors.green.withAlpha((255 * 0.2).toInt())
                                      : (_lastReconStatus == 'ANOMALIES_DETECTED'
                                            ? Colors.orange.withAlpha((255 * 0.2).toInt())
                                            : Colors.grey.withAlpha((255 * 0.2).toInt())),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _lastReconStatus,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _lastReconStatus == 'CLEAN'
                                        ? Colors.green
                                        : (_lastReconStatus == 'ANOMALIES_DETECTED'
                                              ? Colors.orange
                                              : Colors.grey),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Last Completed Time:',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                _lastReconTime,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Unresolved Ledger Anomalies:',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                _unresolvedAnomalies.toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _unresolvedAnomalies > 0
                                      ? AppTheme.error
                                      : AppTheme.success,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          const Text(
                            'The reconciliation engine performs transactional audits on 5 subsystems: Orders, Payments, Inventory Stock Levels, Wallet ledgers, and Delivery COD collections.',
                            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.adminAccent,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: _isReconciling
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.psychology, color: Colors.white),
                              label: Text(
                                _isReconciling
                                    ? 'Running Subsystem Audits...'
                                    : 'Execute Reconciliation Run',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: (_isReconciling || _isLoading)
                                  ? null
                                  : _triggerManualReconciliation,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
