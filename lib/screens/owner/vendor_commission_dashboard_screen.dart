import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/commission_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common/fj_card.dart';
import '../../widgets/common/empty_state.dart' show FjEmptyState;
import '../../widgets/owner/bi_widgets.dart' show kInr;

/// Owner-facing vendor commission dashboard (Task #55).
///
/// For a chosen date range, shows every vendor's delivered-order sales,
/// their commission percentage ([ShopModel.commissionPercent]), the
/// platform's commission earned, and the amount payable to the vendor.
/// This is a live, read-only preview of the same split Task #53's
/// `generatePayoutRequests` job uses when generating vendor payout
/// requests — no writes happen here.
class VendorCommissionDashboardScreen extends StatefulWidget {
  const VendorCommissionDashboardScreen({super.key});

  @override
  State<VendorCommissionDashboardScreen> createState() => _VendorCommissionDashboardScreenState();
}

class _VendorCommissionDashboardScreenState extends State<VendorCommissionDashboardScreen> {
  final _service = CommissionService();
  final _dateFmt = DateFormat('dd MMM yyyy');

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  bool _isLoading = true;
  String? _error;
  List<VendorCommissionSummary> _summaries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final summaries = await _service.getCommissionSummaries(
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      setState(() {
        _summaries = summaries;
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

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Vendor Commission Dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Choose date range',
            onPressed: _pickDateRange,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent))
          : _error != null
              ? Center(child: Text('Failed to load: $_error'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        '${_dateFmt.format(_startDate)} – ${_dateFmt.format(_endDate)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      if (_summaries.isEmpty)
                        const FjEmptyState(
                          icon: Icons.storefront_outlined,
                          title: 'No vendor data',
                          subtitle: 'No shops or delivered orders found for this date range.',
                        )
                      else ...[
                        _buildTotalsCard(),
                        const SizedBox(height: 16),
                        const Text(
                          'Per-Vendor Breakdown',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        ..._summaries.map((s) => _VendorCommissionCard(summary: s)),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildTotalsCard() {
    final totals = _service.totals(_summaries);
    return FjCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Platform Totals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          _TotalsRow(label: 'Total Vendor Sales', value: kInr.format(totals.grossSales)),
          const Divider(),
          _TotalsRow(label: 'Platform Commission Earned', value: kInr.format(totals.commissionAmount)),
          const Divider(),
          _TotalsRow(
            label: 'Total Payable to Vendors',
            value: kInr.format(totals.vendorPayable),
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _TotalsRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _VendorCommissionCard extends StatelessWidget {
  final VendorCommissionSummary summary;
  const _VendorCommissionCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return FjCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  summary.shopName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${summary.commissionPercent.toStringAsFixed(1)}% commission',
                  style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${summary.orderCount} delivered orders', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gross Sales: ${kInr.format(summary.grossSales)}', style: const TextStyle(fontSize: 13)),
              Text('Commission: ${kInr.format(summary.commissionAmount)}', style: const TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Payable to vendor: ${kInr.format(summary.vendorPayable)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
