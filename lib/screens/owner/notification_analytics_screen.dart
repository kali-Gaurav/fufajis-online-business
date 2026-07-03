import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../widgets/common/fj_card.dart';

/// Owner-facing notification delivery / open-rate analytics (Task #61).
///
/// Pulls fast aggregate `count()` queries (no document downloads) across:
///  - `users/*/notifications` (collectionGroup) — total delivered + read,
///    broken down by `type` (orderUpdate, promotion, priceDrop, shopUpdate,
///    systemMessage, stapleRefill, scheduled).
///  - `scheduled_notifications` — pending / sent / failed counts for the
///    delayed-notification pipeline (Task #59).
///  - `broadcast_notifications` — pending / sent / failed counts for
///    shop-wide broadcasts.
class NotificationAnalyticsScreen extends StatefulWidget {
  const NotificationAnalyticsScreen({super.key});

  @override
  State<NotificationAnalyticsScreen> createState() => _NotificationAnalyticsScreenState();
}

class _NotificationTypeStat {
  final String type;
  final int total;
  final int read;
  _NotificationTypeStat({required this.type, required this.total, required this.read});
  double get openRate => total == 0 ? 0 : read / total;
}

class _NotificationAnalyticsScreenState extends State<NotificationAnalyticsScreen> {
  static const _types = [
    'orderUpdate',
    'promotion',
    'priceDrop',
    'shopUpdate',
    'systemMessage',
    'stapleRefill',
  ];

  bool _isLoading = true;
  String? _error;

  int _totalDelivered = 0;
  int _totalRead = 0;
  List<_NotificationTypeStat> _typeStats = [];

  Map<String, int> _scheduledCounts = {};
  Map<String, int> _broadcastCounts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<int> _count(Query<Map<String, dynamic>> query) async {
    final agg = await query.count().get();
    return agg.count ?? 0;
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final db = FirebaseFirestore.instance;
      final notifGroup = db.collectionGroup('notifications');

      // Overall totals across all notification types.
      final total = await _count(notifGroup);
      final totalRead = await _count(notifGroup.where('isRead', isEqualTo: true));

      // Per-type breakdown (sequential to stay within typical Firestore
      // concurrent-query limits and keep this screen simple/robust).
      final stats = <_NotificationTypeStat>[];
      for (final type in _types) {
        final typeTotal = await _count(notifGroup.where('type', isEqualTo: type));
        if (typeTotal == 0) continue;
        final typeRead = await _count(
          notifGroup.where('type', isEqualTo: type).where('isRead', isEqualTo: true),
        );
        stats.add(_NotificationTypeStat(type: type, total: typeTotal, read: typeRead));
      }
      stats.sort((a, b) => b.total.compareTo(a.total));

      // Scheduled-notification pipeline status counts (Task #59).
      final scheduledRef = db.collection('scheduled_notifications');
      final scheduledCounts = <String, int>{};
      for (final status in ['pending', 'sent', 'failed']) {
        scheduledCounts[status] = await _count(scheduledRef.where('status', isEqualTo: status));
      }

      // Broadcast notification status counts.
      final broadcastRef = db.collection('broadcast_notifications');
      final broadcastCounts = <String, int>{};
      for (final status in ['pending', 'sent', 'failed']) {
        broadcastCounts[status] = await _count(broadcastRef.where('status', isEqualTo: status));
      }

      if (!mounted) return;
      setState(() {
        _totalDelivered = total;
        _totalRead = totalRead;
        _typeStats = stats;
        _scheduledCounts = scheduledCounts;
        _broadcastCounts = broadcastCounts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(title: const Text('Notification Analytics')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent))
          : _error != null
          ? Center(child: Text('Failed to load: $_error'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildOverviewCard(),
                  const SizedBox(height: 16),
                  const Text(
                    'By Notification Type',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  if (_typeStats.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No notifications delivered yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._typeStats.map((s) => _TypeStatCard(stat: s)),
                  const SizedBox(height: 16),
                  const Text(
                    'Scheduled Notifications',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  _buildStatusCard(_scheduledCounts, Icons.schedule_send_outlined),
                  const SizedBox(height: 16),
                  const Text(
                    'Broadcast Notifications',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  _buildStatusCard(_broadcastCounts, Icons.campaign_outlined),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCard() {
    final openRate = _totalDelivered == 0 ? 0.0 : _totalRead / _totalDelivered;
    return FjCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricBlock(
                  label: 'Delivered',
                  value: _totalDelivered.toString(),
                  color: AppTheme.info,
                ),
              ),
              Expanded(
                child: _MetricBlock(
                  label: 'Opened',
                  value: _totalRead.toString(),
                  color: AppTheme.success,
                ),
              ),
              Expanded(
                child: _MetricBlock(
                  label: 'Open Rate',
                  value: '${(openRate * 100).toStringAsFixed(1)}%',
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Map<String, int> counts, IconData icon) {
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return FjCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.grey600),
              const SizedBox(width: 8),
              Text('Total: $total', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MetricBlock(
                label: 'Pending',
                value: (counts['pending'] ?? 0).toString(),
                color: AppTheme.warning,
              ),
              _MetricBlock(
                label: 'Sent',
                value: (counts['sent'] ?? 0).toString(),
                color: AppTheme.success,
              ),
              _MetricBlock(
                label: 'Failed',
                value: (counts['failed'] ?? 0).toString(),
                color: AppTheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricBlock({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}

class _TypeStatCard extends StatelessWidget {
  final _NotificationTypeStat stat;
  const _TypeStatCard({required this.stat});

  static const _labels = {
    'orderUpdate': 'Order Updates',
    'promotion': 'Promotions',
    'priceDrop': 'Price Drops',
    'shopUpdate': 'Shop Updates',
    'systemMessage': 'System Messages',
    'stapleRefill': 'Smart Kitchen Reminders',
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[stat.type] ?? stat.type;
    final pct = (stat.openRate * 100).clamp(0, 100).toDouble();
    return FjCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(
                '${pct.toStringAsFixed(1)}% opened',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stat.total == 0 ? 0 : stat.read / stat.total,
              minHeight: 6,
              backgroundColor: AppTheme.grey200,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${stat.read} of ${stat.total} opened',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}
