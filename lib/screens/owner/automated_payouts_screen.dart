import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/app_theme.dart';
import '../../models/payout_request_model.dart';
import '../../services/payout_request_service.dart';
import '../../widgets/owner/bi_widgets.dart';

/// Owner review queue for automated rider/vendor payout requests (Task #53).
///
/// Requests are generated weekly by the `generatePayoutRequests` Cloud
/// Function from unpaid rider delivery earnings and unpaid vendor
/// commission dues. Nothing is transferred until the owner approves a
/// request here:
///  - Rider requests trigger [RiderPayoutService.initiateInstantPayout]
///    (Razorpay Route) immediately on approval.
///  - Vendor requests require the owner to enter a manual bank-transfer
///    reference, which is recorded in the `vendor_payouts` ledger.
class AutomatedPayoutsScreen extends StatefulWidget {
  const AutomatedPayoutsScreen({super.key});

  @override
  State<AutomatedPayoutsScreen> createState() => _AutomatedPayoutsScreenState();
}

class _AutomatedPayoutsScreenState extends State<AutomatedPayoutsScreen> {
  final _service = PayoutRequestService();
  bool _showHistory = false;
  final _processing = <String>{};
  final _dateFmt = DateFormat('dd MMM');

  String get _ownerUid => FirebaseAuth.instance.currentUser?.uid ?? 'owner';

  Future<void> _approveRider(PayoutRequestModel r) async {
    setState(() => _processing.add(r.id));
    final result = await _service.approveRiderRequest(request: r, ownerUid: _ownerUid);
    if (!mounted) return;
    setState(() => _processing.remove(r.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'Payout of ${kInr.format(r.amount)} sent to ${r.recipientName}'
              : 'Payout failed: ${result.message}',
        ),
        backgroundColor: result.success ? AppTheme.success : AppTheme.error,
      ),
    );
  }

  Future<void> _approveVendor(PayoutRequestModel r) async {
    final controller = TextEditingController();
    final notesController = TextEditingController();
    final ref = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Mark Vendor Payout as Paid',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.recipientName} • ${kInr.format(r.amount)}'),
            const SizedBox(height: 12),
            const Text(
              'Enter the bank transfer reference / UTR number after sending '
              'this amount to the vendor manually.',
              style: TextStyle(fontSize: 12, color: AppTheme.grey600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Transaction Reference / UTR',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Mark Paid'),
          ),
        ],
      ),
    );

    if (ref == null || ref.isEmpty) return;

    setState(() => _processing.add(r.id));
    try {
      await _service.approveVendorRequest(
        request: r,
        ownerUid: _ownerUid,
        transactionRef: ref,
        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked ${kInr.format(r.amount)} paid to ${r.recipientName}'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _processing.remove(r.id));
    }
  }

  Future<void> _reject(PayoutRequestModel r) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Payout Request', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.recipientName} • ${kInr.format(r.amount)}'),
            const SizedBox(height: 8),
            const Text(
              'The underlying orders will be eligible for inclusion in a '
              'future payout request.',
              style: TextStyle(fontSize: 12, color: AppTheme.grey600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processing.add(r.id));
    await _service.rejectRequest(
      request: r,
      ownerUid: _ownerUid,
      reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
    );
    if (mounted) setState(() => _processing.remove(r.id));
  }

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Automated Payouts', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: _showHistory ? 'Show pending' : 'Show history',
            icon: Icon(_showHistory ? Icons.pending_actions : Icons.history),
            onPressed: () => setState(() => _showHistory = !_showHistory),
          ),
        ],
      ),
      body: StreamBuilder<List<PayoutRequestModel>>(
        stream: _showHistory ? _service.getHistoryStream() : _service.getPendingRequestsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
          }
          if (snapshot.hasError) {
            return _ErrorBox(message: snapshot.error.toString());
          }
          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showHistory ? Icons.history : Icons.task_alt,
                      size: 48,
                      color: AppTheme.grey400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _showHistory
                          ? 'No resolved payout requests yet'
                          : 'No pending payout requests.\nThe weekly automation job will '
                                'generate new requests from unpaid rider earnings and '
                                'vendor dues.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.grey600),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final r = requests[index];
              return _PayoutRequestCard(
                request: r,
                processing: _processing.contains(r.id),
                dateFmt: _dateFmt,
                onApprove: r.type == PayoutRequestType.rider
                    ? () => _approveRider(r)
                    : () => _approveVendor(r),
                onReject: r.status == PayoutRequestStatus.pending ? () => _reject(r) : null,
              );
            },
          );
        },
      ),
    );
  }
}

class _PayoutRequestCard extends StatelessWidget {
  final PayoutRequestModel request;
  final bool processing;
  final DateFormat dateFmt;
  final VoidCallback onApprove;
  final VoidCallback? onReject;

  const _PayoutRequestCard({
    required this.request,
    required this.processing,
    required this.dateFmt,
    required this.onApprove,
    required this.onReject,
  });

  Color _statusColor() {
    switch (request.status) {
      case PayoutRequestStatus.paid:
        return AppTheme.success;
      case PayoutRequestStatus.rejected:
      case PayoutRequestStatus.failed:
        return AppTheme.error;
      case PayoutRequestStatus.approved:
        return AppTheme.info;
      case PayoutRequestStatus.pending:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRider = request.type == PayoutRequestType.rider;
    final isPending = request.status == PayoutRequestStatus.pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: (isRider ? AppTheme.info : AppTheme.primary).withOpacity(0.12,),
                  child: Icon(
                    isRider ? Icons.delivery_dining : Icons.storefront_outlined,
                    color: isRider ? AppTheme.info : AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.recipientName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isRider ? 'Rider delivery earnings' : 'Vendor commission settlement',
                        style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      kInr.format(request.amount),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor().withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        request.status.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _statusColor(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${dateFmt.format(request.periodStart)} – ${dateFmt.format(request.periodEnd)} • '
              '${request.orderCount} order(s)',
              style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
            ),
            if (request.notes != null) ...[
              const SizedBox(height: 4),
              Text(request.notes!, style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
            ],
            if (request.transactionId != null) ...[
              const SizedBox(height: 4),
              Text(
                'Ref: ${request.transactionId}',
                style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
              ),
            ],
            if (request.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                'Error: ${request.errorMessage}',
                style: const TextStyle(fontSize: 12, color: AppTheme.error),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: processing ? null : onReject,
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: processing ? null : onApprove,
                      child: processing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isRider ? 'Approve & Pay' : 'Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            const Text(
              'Could not load payout requests',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey800),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
            ),
          ],
        ),
      ),
    );
  }
}
