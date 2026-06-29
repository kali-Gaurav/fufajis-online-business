import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../utils/app_theme.dart';
import '../../models/refund_request_model.dart';
import '../../providers/business_intelligence_provider.dart';
import '../../services/business_intelligence_service.dart';
import '../../widgets/owner/bi_widgets.dart';

/// Owner-facing Payment Analytics dashboard (Task #49).
///
/// Combines the existing [BusinessIntelligenceProvider] financial data
/// (revenue by payment method, refund totals/rate, daily revenue trend)
/// with dedicated queries against `refund_requests` (refund-method mix and
/// processing-pipeline status, including the bank-transfer fields added in
/// Task #48) and `transactions` (gateway/wallet/bank transaction volume and
/// success/failure counts) for the selected date range.
class PaymentAnalyticsScreen extends StatefulWidget {
  const PaymentAnalyticsScreen({super.key});

  @override
  State<PaymentAnalyticsScreen> createState() =>
      _PaymentAnalyticsScreenState();
}

class _PaymentAnalyticsScreenState extends State<PaymentAnalyticsScreen> {
  bool _loadingExtra = false;
  String? _extraError;

  // Refund pipeline: counts by status, amounts by refund method.
  Map<String, int> _refundStatusCounts = {};
  Map<String, double> _refundMethodAmounts = {};
  int _refundsAwaitingBankDetails = 0;

  // Transactions: counts by status, amounts by type.
  Map<String, int> _txnStatusCounts = {};
  Map<String, double> _txnTypeAmounts = {};

  DateTime? _lastFrom;
  DateTime? _lastTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<BusinessIntelligenceProvider>();
      await p.load();
      await _loadExtra();
    });
  }

  Future<void> _loadExtra() async {
    final p = context.read<BusinessIntelligenceProvider>();
    final from = p.from;
    final to = p.to;
    if (_lastFrom == from && _lastTo == to && !_loadingExtra) {
      // already loaded for this range
      if (_refundStatusCounts.isNotEmpty || _txnStatusCounts.isNotEmpty) {
        return;
      }
    }
    setState(() {
      _loadingExtra = true;
      _extraError = null;
    });
    try {
      final fromTs = Timestamp.fromDate(from);
      final toTs = Timestamp.fromDate(to);

      // --- Refund requests in range ---
      final refundSnap = await FirebaseFirestore.instance
          .collection('refund_requests')
          .where('createdAt', isGreaterThanOrEqualTo: fromTs)
          .where('createdAt', isLessThanOrEqualTo: toTs)
          .get();

      final statusCounts = <String, int>{};
      final methodAmounts = <String, double>{};
      var awaitingBankDetails = 0;
      for (final doc in refundSnap.docs) {
        final r = RefundRequest.fromMap(doc.data(), doc.id);
        final statusLabel = _statusLabel(r.status.name);
        statusCounts[statusLabel] = (statusCounts[statusLabel] ?? 0) + 1;
        final methodLabel = _refundMethodLabel(r.refundMethod.name);
        methodAmounts[methodLabel] = (methodAmounts[methodLabel] ?? 0) + r.amount.toDouble();
        if (r.refundMethod == RefundMethod.bank &&
            !r.hasBankDetails &&
            r.status != RefundStatus.completed &&
            r.status != RefundStatus.failed) {
          awaitingBankDetails++;
        }
      }

      // --- Transactions in range ---
      final txnSnap = await FirebaseFirestore.instance
          .collection('transactions')
          .where('createdAt', isGreaterThanOrEqualTo: fromTs)
          .where('createdAt', isLessThanOrEqualTo: toTs)
          .get();

      final txnStatus = <String, int>{};
      final txnType = <String, double>{};
      for (final doc in txnSnap.docs) {
        final data = doc.data();
        final status = _statusLabel(
          (data['status'] as String? ?? 'unknown').split('.').last,
        );
        txnStatus[status] = (txnStatus[status] ?? 0) + 1;

        final type = _statusLabel(
          (data['type'] as String? ?? 'other').split('.').last,
        );
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        txnType[type] = (txnType[type] ?? 0) + amount;
      }

      if (!mounted) return;
      setState(() {
        _refundStatusCounts = statusCounts;
        _refundMethodAmounts = methodAmounts;
        _refundsAwaitingBankDetails = awaitingBankDetails;
        _txnStatusCounts = txnStatus;
        _txnTypeAmounts = txnType;
        _lastFrom = from;
        _lastTo = to;
        _loadingExtra = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _extraError = e.toString();
        _loadingExtra = false;
      });
    }
  }

  String _statusLabel(String raw) {
    if (raw.isEmpty) return 'Unknown';
    return raw[0].toUpperCase() + raw.substring(1);
  }

  String _refundMethodLabel(String raw) {
    switch (raw) {
      case 'wallet':
        return 'Wallet';
      case 'upi':
        return 'UPI';
      case 'gateway':
        return 'Gateway';
      case 'bank':
        return 'Bank Transfer';
      default:
        return _statusLabel(raw);
    }
  }

  Map<String, double> _countsAsDouble(Map<String, int> m) =>
      m.map((k, v) => MapEntry(k, v.toDouble()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Payment Analytics', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Payment Disputes',
            icon: const Icon(Icons.gavel_outlined),
            onPressed: () => context.push('/owner/payment-disputes'),
          ),
          IconButton(
            tooltip: 'COD Limits',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => context.push('/owner/cod-limits'),
          ),
          Consumer<BusinessIntelligenceProvider>(
            builder: (context, p, _) => IconButton(
              tooltip: 'Refund Processing',
              icon: const Icon(Icons.currency_exchange),
              onPressed: () => context.push('/owner/refund-processing'),
            ),
          ),
        ],
      ),
      body: Consumer<BusinessIntelligenceProvider>(
        builder: (context, p, _) {
          return RefreshIndicator(
            onRefresh: () async {
              await p.refresh();
              await _loadExtra();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                BiRangeSelector(
                  selected: p.range,
                  onSelected: (r) async {
                    await p.setRange(r);
                    await _loadExtra();
                  },
                ),
                const SizedBox(height: 16),
                if (p.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent)),
                  )
                else if (p.error != null)
                  _ErrorBox(message: p.error!, onRetry: () async {
                    await p.refresh();
                    await _loadExtra();
                  })
                else
                  ..._buildContent(context, p.financial),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context, FinancialReport f) {
    return [
      // --- Top-level KPIs (reused from financial dashboard data) ---
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
        children: [
          BiKpiCard(
            label: 'Gross Revenue',
            value: kInr.format(f.grossRevenue),
            icon: Icons.account_balance_wallet_outlined,
            color: AppTheme.primary,
          ),
          BiKpiCard(
            label: 'Total Refunds',
            value: kInr.format(f.refunds),
            icon: Icons.replay_outlined,
            color: AppTheme.error,
            subtitle: '${f.refundRate.toStringAsFixed(1)}% of gross',
          ),
          BiKpiCard(
            label: 'Refund Requests',
            value: '${_refundStatusCounts.values.fold(0, (a, b) => a + b)}',
            icon: Icons.receipt_long_outlined,
            color: AppTheme.info,
            subtitle: '${_refundStatusCounts['Pending'] ?? 0} pending action',
          ),
          BiKpiCard(
            label: 'Txn Records',
            value: '${_txnStatusCounts.values.fold(0, (a, b) => a + b)}',
            icon: Icons.swap_horiz,
            color: AppTheme.success,
            subtitle:
                '${_txnStatusCounts['Failed'] ?? 0} failed',
          ),
        ],
      ),
      const SizedBox(height: 16),
      BiSectionCard(
        title: 'Revenue by Payment Method',
        child: BiDonutChart(data: f.revenueByPaymentMethod),
      ),
      const SizedBox(height: 16),
      BiSectionCard(
        title: 'Daily Revenue Trend',
        child: BiLineChart(
          values: f.dailyRevenue.map((d) => d.value).toList(),
        ),
      ),
      const SizedBox(height: 16),
      if (_loadingExtra)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent)),
        )
      else if (_extraError != null)
        _ErrorBox(message: _extraError!, onRetry: _loadExtra)
      else ...[
        if (_refundsAwaitingBankDetails > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_outlined,
                    color: AppTheme.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$_refundsAwaitingBankDetails bank-transfer refund(s) need account details before processing.',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.grey800),
                  ),
                ),
              ],
            ),
          ),
        BiSectionCard(
          title: 'Refund Pipeline Status',
          child: BiBarChart(
            data: _countsAsDouble(_refundStatusCounts),
            color: AppTheme.error,
          ),
        ),
        const SizedBox(height: 16),
        BiSectionCard(
          title: 'Refunds by Method',
          child: BiDonutChart(data: _refundMethodAmounts),
        ),
        const SizedBox(height: 16),
        BiSectionCard(
          title: 'Transaction Status (Gateway Success/Failure)',
          child: BiBarChart(
            data: _countsAsDouble(_txnStatusCounts),
            color: AppTheme.info,
          ),
        ),
        const SizedBox(height: 16),
        BiSectionCard(
          title: 'Transaction Volume by Type',
          child: BiDonutChart(data: _txnTypeAmounts),
        ),
      ],
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
          const Text('Could not load data',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.grey800)),
          const SizedBox(height: 4),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
