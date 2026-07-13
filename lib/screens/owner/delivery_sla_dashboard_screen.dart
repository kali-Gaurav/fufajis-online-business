import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../utils/app_theme.dart';

/// Task #74 — Delivery SLA Dashboard (Owner)
///
/// Pulls delivered orders from Firestore and computes:
///  - On-time delivery %  (target: 90%)
///  - Average delivery time (target: ≤45 min)
///  - SLA breaches (>60 min from confirmed → delivered)
///  - Breach breakdown per rider
class DeliverySLADashboardScreen extends StatefulWidget {
  const DeliverySLADashboardScreen({super.key});

  @override
  State<DeliverySLADashboardScreen> createState() => _DeliverySLADashboardScreenState();
}

class _DeliverySLADashboardScreenState extends State<DeliverySLADashboardScreen> {
  bool _loading = false;
  String? _error;
  _SLAStats? _stats;
  String _period = 'today'; // today | week | month

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final from = _period == 'today'
          ? DateTime(now.year, now.month, now.day)
          : _period == 'week'
          ? now.subtract(const Duration(days: 7))
          : now.subtract(const Duration(days: 30));

      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'OrderStatus.delivered')
          .where('confirmedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .get();

      final stats = _SLAStats.fromDocs(snap.docs);
      if (mounted)
        setState(() {
          _stats = stats;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery SLA Dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          DropdownButton<String>(
            value: _period,
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            dropdownColor: AppTheme.ownerAccent,
            items: const [
              DropdownMenuItem(value: 'today', child: Text('Today')),
              DropdownMenuItem(value: 'week', child: Text('Last 7 days')),
              DropdownMenuItem(value: 'month', child: Text('Last 30 days')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _period = v);
                _load();
              }
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent))
          : _error != null
          ? Center(child: Text(_error!))
          : _stats == null
          ? const Center(child: Text('No data'))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final s = _stats!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── KPI Cards ──────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'On-Time Rate',
                value: '${s.onTimePercent.toStringAsFixed(1)}%',
                target: '≥ 90%',
                isGood: s.onTimePercent >= 90,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                label: 'Avg Delivery',
                value: '${s.avgMinutes.toStringAsFixed(0)} min',
                target: '≤ 45 min',
                isGood: s.avgMinutes <= 45,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Total Deliveries',
                value: '${s.total}',
                target: '',
                isGood: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                label: 'SLA Breaches',
                value: '${s.breaches}',
                target: '> 60 min',
                isGood: s.breaches == 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // ── Rider Breach Table ─────────────────────────────────────────────
        if (s.byRider.isNotEmpty) ...[
          const Text(
            'SLA Breaches by Rider',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.grey900),
          ),
          const SizedBox(height: 12),
          ...s.byRider.entries.map((e) {
            final breachSeverity = e.value > 2;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.white,
                border: Border.all(
                  color: (breachSeverity ? AppTheme.error : AppTheme.warning).withOpacity(0.3,),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (breachSeverity ? AppTheme.error : AppTheme.warning).withOpacity(0.12,),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.delivery_dining,
                      color: breachSeverity ? AppTheme.error : AppTheme.warning,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.grey900,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${e.value} SLA breach${e.value > 1 ? 'es' : ''} (>60 min)',
                          style: TextStyle(
                            fontSize: 12,
                            color: breachSeverity ? AppTheme.error : AppTheme.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (breachSeverity ? AppTheme.error : AppTheme.warning).withOpacity(0.15,),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${e.value}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: breachSeverity ? AppTheme.error : AppTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String target;
  final bool isGood;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.target,
    required this.isGood,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (isGood ? AppTheme.success : AppTheme.error).withOpacity(0.08),
              AppTheme.white,
            ],
          ),
          border: Border.all(
            color: (isGood ? AppTheme.success : AppTheme.error).withOpacity(0.25),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.grey600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: isGood ? AppTheme.success : AppTheme.error,
                ),
              ),
              if (target.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Target: $target',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.grey600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SLAStats {
  final int total;
  final int onTime;
  final int breaches;
  final double avgMinutes;
  final Map<String, int> byRider;

  _SLAStats({
    required this.total,
    required this.onTime,
    required this.breaches,
    required this.avgMinutes,
    required this.byRider,
  });

  double get onTimePercent => total == 0 ? 100 : (onTime / total) * 100;

  factory _SLAStats.fromDocs(List<QueryDocumentSnapshot> docs) {
    int total = 0, onTime = 0, breaches = 0;
    double totalMin = 0;
    final byRider = <String, int>{};

    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final confirmed = (d['confirmedAt'] as Timestamp?)?.toDate();
      final delivered = (d['deliveredAt'] as Timestamp?)?.toDate();
      if (confirmed == null || delivered == null) continue;

      final mins = delivered.difference(confirmed).inMinutes.toDouble();
      total++;
      totalMin += mins;
      if (mins <= 60) {
        onTime++;
      } else {
        breaches++;
        final riderId = d['riderId'] ?? d['assignedRiderName'] ?? 'Unknown';
        byRider[riderId] = (byRider[riderId] ?? 0) + 1;
      }
    }

    return _SLAStats(
      total: total,
      onTime: onTime,
      breaches: breaches,
      avgMinutes: total == 0 ? 0 : totalMin / total,
      byRider: byRider,
    );
  }
}
