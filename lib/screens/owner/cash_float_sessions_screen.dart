import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/app_theme.dart';
import '../../widgets/common/fj_card.dart';
import '../../widgets/common/empty_state.dart' show FjEmptyState;
import '../../widgets/owner/bi_widgets.dart' show kInr;

/// Owner-facing cash float / register session history (Task #56).
///
/// Every time a cashier opens a drawer (entering an opening float) and
/// later reconciles it (entering the actual counted cash), a record is
/// written to `register_sessions` by [CashRegisterScreen] with the
/// opening float, cash sales recorded during the session, the actual
/// closing cash, and the resulting variance. This screen lets the owner
/// review that history across all cashiers/days, spot drawers with
/// repeated shortages/overages, and see currently-open sessions.
class CashFloatSessionsScreen extends StatefulWidget {
  const CashFloatSessionsScreen({super.key});

  @override
  State<CashFloatSessionsScreen> createState() => _CashFloatSessionsScreenState();
}

class _CashFloatSessionsScreenState extends State<CashFloatSessionsScreen> {
  final _dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
  bool _isLoading = true;
  String? _error;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sessions = [];

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
      final snap = await FirebaseFirestore.instance
          .collection('register_sessions')
          .orderBy('openedAt', descending: true)
          .limit(100)
          .get();
      if (!mounted) return;
      setState(() {
        _sessions = snap.docs;
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
      appBar: AppBar(title: const Text('Cash Float Sessions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent))
          : _error != null
          ? Center(child: Text('Failed to load: $_error'))
          : _sessions.isEmpty
          ? const FjEmptyState(
              icon: Icons.savings_outlined,
              title: 'No register sessions yet',
              subtitle: 'Cash float open/close sessions from the Cash Register will appear here.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _sessions.length,
                itemBuilder: (context, index) =>
                    _SessionCard(data: _sessions[index].data(), dateFmt: _dateFmt),
              ),
            ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final DateFormat dateFmt;

  const _SessionCard({required this.data, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    final openingFloat = (data['openingFloat'] as num? ?? 0.0).toDouble();
    final cashSales = (data['cashSales'] as num? ?? 0.0).toDouble();
    final actualClosingCash = (data['actualClosingCash'] as num? ?? 0.0).toDouble();
    final isOpen = data['isOpen'] as bool? ?? false;
    final variance = (data['variance'] as num? ?? (actualClosingCash - (openingFloat + cashSales)))
        .toDouble();
    final userName = data['userName'] as String? ?? 'Unknown';
    final openedAt = DateTime.tryParse(data['openedAt'] as String? ?? '');
    final closedAt = data['closedAt'] != null
        ? DateTime.tryParse(data['closedAt'] as String)
        : null;
    final expectedCash = openingFloat + cashSales;

    final hasDiscrepancy = !isOpen && variance.abs() > 0.5;

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
                  userName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      (isOpen
                              ? AppTheme.warning
                              : (hasDiscrepancy ? AppTheme.error : AppTheme.success))
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOpen ? 'Open' : (hasDiscrepancy ? 'Discrepancy' : 'Balanced'),
                  style: TextStyle(
                    color: isOpen
                        ? AppTheme.warning
                        : (hasDiscrepancy ? AppTheme.error : AppTheme.success),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            openedAt != null ? 'Opened: ${dateFmt.format(openedAt)}' : 'Opened: —',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          if (closedAt != null)
            Text(
              'Closed: ${dateFmt.format(closedAt)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Opening Float: ${kInr.format(openingFloat)}',
                style: const TextStyle(fontSize: 13),
              ),
              Text('Cash Sales: ${kInr.format(cashSales)}', style: const TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Expected: ${kInr.format(expectedCash)}', style: const TextStyle(fontSize: 13)),
              if (!isOpen)
                Text(
                  'Actual: ${kInr.format(actualClosingCash)}',
                  style: const TextStyle(fontSize: 13),
                ),
            ],
          ),
          if (!isOpen) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Variance: ${variance >= 0 ? '+' : ''}${kInr.format(variance)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: hasDiscrepancy ? AppTheme.error : AppTheme.success,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
