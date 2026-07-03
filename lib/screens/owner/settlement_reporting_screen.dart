import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/app_theme.dart';
import '../../providers/business_intelligence_provider.dart';
import '../../models/cod_settlement_model.dart';
import '../../models/rider_payout_model.dart';
import '../../services/export_service.dart';
import '../../widgets/owner/bi_widgets.dart';

/// Owner-facing daily/weekly settlement reporting dashboard (Task #52).
///
/// Aggregates `cod_settlements` (rider COD cash collection vs. settlement)
/// and `rider_payouts` (Razorpay Route fleet payouts) for the selected date
/// range, grouped by day, so owners can see collection, settlement, pending
/// and payout trends at a glance. This is purely a reporting view — approve
/// / reject actions remain in [SettlementsManagementScreen].
class SettlementReportingScreen extends StatefulWidget {
  const SettlementReportingScreen({super.key});

  @override
  State<SettlementReportingScreen> createState() => _SettlementReportingScreenState();
}

class _SettlementReportingScreenState extends State<SettlementReportingScreen> {
  BiRange _range = BiRange.week;
  bool _loading = true;
  String? _error;
  bool _exporting = false;

  List<CodSettlementModel> _settlements = [];
  List<RiderPayoutModel> _payouts = [];

  final _dayFmt = DateFormat('dd MMM');

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Mirrors [BusinessIntelligenceProvider]'s preset-range resolution so the
  /// selector behaves identically across owner dashboards.
  (DateTime, DateTime) _resolveRange() {
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    DateTime from;
    switch (_range) {
      case BiRange.today:
        from = DateTime(now.year, now.month, now.day);
        break;
      case BiRange.week:
        from = to.subtract(const Duration(days: 6));
        break;
      case BiRange.month:
        from = to.subtract(const Duration(days: 29));
        break;
      case BiRange.quarter:
        from = to.subtract(const Duration(days: 89));
        break;
      case BiRange.year:
        from = to.subtract(const Duration(days: 364));
        break;
      case BiRange.custom:
        from = to.subtract(const Duration(days: 6));
        break;
    }
    return (DateTime(from.year, from.month, from.day), to);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (from, to) = _resolveRange();
      final fromTs = Timestamp.fromDate(from);
      final toTs = Timestamp.fromDate(to);

      final settlementSnap = await FirebaseFirestore.instance
          .collection('cod_settlements')
          .where('submittedAt', isGreaterThanOrEqualTo: fromTs)
          .where('submittedAt', isLessThanOrEqualTo: toTs)
          .get();

      final payoutSnap = await FirebaseFirestore.instance
          .collection('rider_payouts')
          .where('timestamp', isGreaterThanOrEqualTo: fromTs)
          .where('timestamp', isLessThanOrEqualTo: toTs)
          .get();

      if (!mounted) return;
      setState(() {
        _settlements = settlementSnap.docs
            .map((d) => CodSettlementModel.fromMap(d.data()))
            .toList();
        _payouts = payoutSnap.docs.map((d) => RiderPayoutModel.fromMap(d.data(), d.id)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Buckets a list of records into per-day totals across the selected
  /// range, keyed by a short display label (e.g. "12 Jun").
  Map<String, double> _bucketByDay(List<DateTime> dates, List<double> values) {
    final (from, to) = _resolveRange();
    final days = to.difference(from).inDays + 1;
    final buckets = <String, double>{};
    for (var i = 0; i < days; i++) {
      final day = from.add(Duration(days: i));
      buckets[_dayFmt.format(day)] = 0.0;
    }
    for (var i = 0; i < dates.length; i++) {
      final d = dates[i];
      final key = _dayFmt.format(DateTime(d.year, d.month, d.day));
      if (buckets.containsKey(key)) {
        buckets[key] = (buckets[key] ?? 0) + values[i];
      }
    }
    return buckets;
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final period = switch (_range) {
        BiRange.today => 'daily',
        BiRange.week => 'weekly',
        BiRange.month => 'monthly',
        BiRange.quarter => 'quarterly',
        BiRange.year => 'yearly',
        BiRange.custom => 'weekly',
      };
      final path = await ExportService().exportSettlementsToCSV(period: period);
      await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Settlement report ($period)'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Settlement Reports', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.ios_share),
            onPressed: _exporting ? null : _export,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BiRangeSelector(
              selected: _range,
              onSelected: (r) {
                setState(() => _range = r);
                _load();
              },
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent)),
              )
            else if (_error != null)
              _ErrorBox(message: _error!, onRetry: _load)
            else
              ..._buildContent(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    // --- COD settlement totals ---
    double totalCollected = 0;
    double totalSettled = 0;
    double pendingAmount = 0;
    int pendingCount = 0;
    int approvedCount = 0;
    int rejectedCount = 0;

    final collectedDates = <DateTime>[];
    final collectedAmounts = <double>[];
    final settledDates = <DateTime>[];
    final settledAmounts = <double>[];

    for (final s in _settlements) {
      totalCollected += s.amount;
      collectedDates.add(s.submittedAt);
      collectedAmounts.add(s.amount);

      switch (s.status) {
        case 'approved':
          approvedCount++;
          final settledAmt = s.receivedAmount > 0 ? s.receivedAmount : s.amount;
          totalSettled += settledAmt;
          settledDates.add(s.resolvedAt ?? s.submittedAt);
          settledAmounts.add(settledAmt);
          break;
        case 'rejected':
          rejectedCount++;
          break;
        default:
          pendingCount++;
          pendingAmount += s.amount;
      }
    }

    // --- Rider payouts (Razorpay Route) ---
    double totalPayouts = 0;
    int processedPayouts = 0;
    final payoutDates = <DateTime>[];
    final payoutAmounts = <double>[];
    for (final p in _payouts) {
      payoutDates.add(p.timestamp);
      payoutAmounts.add(p.amount.toDouble());
      if (p.status == PayoutStatus.processed) {
        totalPayouts += p.amount.toDouble();
        processedPayouts++;
      }
    }

    final collectedByDay = _bucketByDay(collectedDates, collectedAmounts);
    final settledByDay = _bucketByDay(settledDates, settledAmounts);
    final payoutsByDay = _bucketByDay(payoutDates, payoutAmounts);

    return [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
        children: [
          BiKpiCard(
            label: 'COD Collected',
            value: kInr.format(totalCollected),
            icon: Icons.payments_outlined,
            color: AppTheme.primary,
            subtitle: '${_settlements.length} submission(s)',
          ),
          BiKpiCard(
            label: 'Settled (Approved)',
            value: kInr.format(totalSettled),
            icon: Icons.verified_outlined,
            color: AppTheme.success,
            subtitle: '$approvedCount approved',
          ),
          BiKpiCard(
            label: 'Pending Settlement',
            value: kInr.format(pendingAmount),
            icon: Icons.hourglass_top_outlined,
            color: AppTheme.warning,
            subtitle: '$pendingCount pending • $rejectedCount rejected',
          ),
          BiKpiCard(
            label: 'Fleet Payouts (Route)',
            value: kInr.format(totalPayouts),
            icon: Icons.account_balance_outlined,
            color: AppTheme.info,
            subtitle: '$processedPayouts processed',
          ),
        ],
      ),
      const SizedBox(height: 16),
      BiSectionCard(
        title: 'Daily COD Collected',
        child: BiBarChart(data: collectedByDay, color: AppTheme.primary),
      ),
      const SizedBox(height: 16),
      BiSectionCard(
        title: 'Daily Settlements Approved',
        child: BiBarChart(data: settledByDay, color: AppTheme.success),
      ),
      const SizedBox(height: 16),
      BiSectionCard(
        title: 'Daily Fleet Payouts',
        child: BiBarChart(data: payoutsByDay, color: AppTheme.info),
      ),
      const SizedBox(height: 16),
      BiSectionCard(
        title: 'Collection vs Settlement Trend',
        child: BiLineChart(values: collectedByDay.values.toList(), color: AppTheme.primary),
      ),
      const SizedBox(height: 24),
    ];
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          const Text(
            'Could not load settlement report',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey800),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
