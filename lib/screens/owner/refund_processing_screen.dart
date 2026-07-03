import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/refund_request_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_api_service.dart';
import '../../services/refund_status_engine.dart';
import '../../utils/app_theme.dart';

/// Owner-only screen: review pending/approved/processing refund requests,
/// select multiple, and advance them through the refund state machine
/// (pending → approved → processing → completed) or mark them failed.
///
/// For [RefundMethod.gateway] refunds, advancing approved → processing also
/// attempts to trigger the `initiateRazorpayRefund` Cloud Function (best
/// effort — failure does not block the local status transition, since the
/// owner may also process the gateway refund manually from the payment
/// provider's dashboard).
class RefundProcessingScreen extends StatefulWidget {
  const RefundProcessingScreen({super.key});

  @override
  State<RefundProcessingScreen> createState() => _RefundProcessingScreenState();
}

class _RefundProcessingScreenState extends State<RefundProcessingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  final _engine = RefundStatusEngine();
  final Set<String> _selectedIds = {};
  final Set<String> _processingIds = {};

  Stream<List<RefundRequest>> _watchActionableRefunds() {
    return FirebaseFirestore.instance
        .collection('refund_requests')
        .where('status', whereIn: ['pending', 'approved', 'processing'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => RefundRequest.fromMap(d.data(), d.id)).toList());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text('Refund Processing', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.white,
      ),
      body: StreamBuilder<List<RefundRequest>>(
        stream: _watchActionableRefunds(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final refunds = snapshot.data ?? [];
          if (refunds.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.currency_exchange, size: 56, color: AppTheme.grey400),
                  SizedBox(height: 12),
                  Text(
                    'No refunds awaiting action',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Pending, approved, or in-progress refund requests will appear here.',
                    style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Drop any selections for refunds no longer in the actionable list.
          final visibleIds = refunds.map((r) => r.id).toSet();
          _selectedIds.removeWhere((id) => !visibleIds.contains(id));

          return Column(
            children: [
              if (_selectedIds.isNotEmpty) _buildBatchActionBar(refunds),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: refunds.length,
                  itemBuilder: (context, i) => _buildRefundCard(refunds[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBatchActionBar(List<RefundRequest> refunds) {
    final selected = refunds.where((r) => _selectedIds.contains(r.id)).toList();
    final anyProcessing = selected.any((r) => _processingIds.contains(r.id));

    return Container(
      width: double.infinity,
      color: AppTheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_selectedIds.length} selected',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
            ),
          ),
          TextButton(
            onPressed: anyProcessing ? null : () => _batchFail(selected),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Mark Failed'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: anyProcessing ? null : () => _batchAdvance(selected),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: AppTheme.white,
            ),
            child: const Text('Advance Selected'),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundCard(RefundRequest refund) {
    final isProcessing = _processingIds.contains(refund.id);
    final isSelected = _selectedIds.contains(refund.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? AppTheme.primary.withValues(alpha: 0.06) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: isProcessing
                      ? null
                      : (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedIds.add(refund.id);
                            } else {
                              _selectedIds.remove(refund.id);
                            }
                          });
                        },
                ),
                _statusChip(refund.status),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order ${refund.orderId}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  refund.amount.toDisplayString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer: ${refund.customerId}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                  ),
                  Text(
                    'Method: ${_methodLabel(refund.refundMethod)}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                  ),
                  if (refund.refundMethod == RefundMethod.bank)
                    Text(
                      refund.hasBankDetails
                          ? 'Bank: ${refund.bankAccountHolderName ?? ''} • ****${_lastFour(refund.bankAccountNumber)} • ${refund.bankIfsc}'
                          : 'Bank details not yet captured',
                      style: TextStyle(
                        fontSize: 11,
                        color: refund.hasBankDetails ? AppTheme.grey500 : AppTheme.error,
                      ),
                    ),
                  if (refund.refundMethod == RefundMethod.bank && refund.payoutId != null)
                    Text(
                      'Transfer ref: ${refund.payoutId}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                    ),
                  Text(
                    'Requested: ${_formatDate(refund.createdAt)}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isProcessing ? null : () => _failOne(refund),
                    icon: const Icon(Icons.close, color: AppTheme.error),
                    label: const Text('Mark Failed', style: TextStyle(color: AppTheme.error)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.error)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isProcessing ? null : () => _advanceOne(refund),
                    icon: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.white),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(_advanceLabel(refund.status)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: AppTheme.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // ACTIONS
  // ──────────────────────────────────────────────────────────────

  RefundStatus? _nextStatus(RefundStatus current) {
    switch (current) {
      case RefundStatus.pending:
        return RefundStatus.approved;
      case RefundStatus.approved:
        return RefundStatus.processing;
      case RefundStatus.processing:
        return RefundStatus.completed;
      case RefundStatus.completed:
      case RefundStatus.failed:
        return null;
    }
  }

  Future<void> _advanceOne(RefundRequest refund) async {
    final next = _nextStatus(refund.status);
    if (next == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _processingIds.add(refund.id));
    try {
      await _transitionRefund(
        refund: refund,
        newStatus: next,
        actorId: user.id,
        actorRole: _actorRole(user),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refund ${refund.id} moved to ${next.name}.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update refund: $e')));
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(refund.id));
    }
  }

  Future<void> _failOne(RefundRequest refund) async {
    final reason = await _promptForReason();
    if (reason == null) return; // cancelled

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _processingIds.add(refund.id));
    try {
      await _engine.transitionRefundStatus(
        refundId: refund.id,
        newStatus: RefundStatus.failed,
        actorId: user.id,
        actorRole: _actorRole(user),
        reason: reason.isEmpty ? null : reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Refund marked failed.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update refund: $e')));
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(refund.id));
    }
  }

  Future<void> _batchAdvance(List<RefundRequest> refunds) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _processingIds.addAll(refunds.map((r) => r.id)));

    var succeeded = 0;
    var failed = 0;
    for (final refund in refunds) {
      final next = _nextStatus(refund.status);
      if (next == null) continue;
      try {
        await _transitionRefund(
          refund: refund,
          newStatus: next,
          actorId: user.id,
          actorRole: _actorRole(user),
        );
        succeeded++;
      } catch (_) {
        failed++;
      }
    }

    if (mounted) {
      setState(() {
        _processingIds.removeAll(refunds.map((r) => r.id));
        _selectedIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failed == 0 ? '$succeeded refund(s) advanced.' : '$succeeded advanced, $failed failed.',
          ),
          backgroundColor: failed == 0 ? AppTheme.success : AppTheme.error,
        ),
      );
    }
  }

  Future<void> _batchFail(List<RefundRequest> refunds) async {
    final reason = await _promptForReason();
    if (reason == null) return; // cancelled

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _processingIds.addAll(refunds.map((r) => r.id)));

    var succeeded = 0;
    var failed = 0;
    for (final refund in refunds) {
      try {
        await _engine.transitionRefundStatus(
          refundId: refund.id,
          newStatus: RefundStatus.failed,
          actorId: user.id,
          actorRole: _actorRole(user),
          reason: reason.isEmpty ? null : reason,
        );
        succeeded++;
      } catch (_) {
        failed++;
      }
    }

    if (mounted) {
      setState(() {
        _processingIds.removeAll(refunds.map((r) => r.id));
        _selectedIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failed == 0
                ? '$succeeded refund(s) marked failed.'
                : '$succeeded marked failed, $failed failed to update.',
          ),
          backgroundColor: failed == 0 ? AppTheme.success : AppTheme.error,
        ),
      );
    }
  }

  /// Performs the status transition via [RefundStatusEngine].
  ///
  /// For [RefundMethod.gateway] refunds moving into `processing`, attempts
  /// to trigger the Razorpay refund Cloud Function (best-effort).
  ///
  /// For [RefundMethod.bank] refunds (Task #48):
  ///  - moving into `processing`: ensures bank account details are captured
  ///    (prompting the owner if missing, prefilled from the customer's saved
  ///    bank details), then attempts an automated RazorpayX payout via
  ///    `initiateBankTransferRefund` (best-effort — if RazorpayX payouts
  ///    aren't configured, the function returns success:false and the owner
  ///    falls back to a manual transfer).
  ///  - moving into `completed`: if no automated payout reference was
  ///    recorded, requires the owner to confirm a manual NEFT/IMPS transfer
  ///    reference (UTR) before the refund can be marked complete.
  Future<void> _transitionRefund({
    required RefundRequest refund,
    required RefundStatus newStatus,
    required String actorId,
    required String actorRole,
  }) async {
    RefundRequest current = refund;

    if (current.refundMethod == RefundMethod.gateway && newStatus == RefundStatus.processing) {
      try {
        await FirebaseFunctions.instance.httpsCallable('initiateRazorpayRefund').call(
          <String, dynamic>{
            'orderId': current.orderId,
            'refundId': current.id,
            'amount': current.amount,
          },
        );
      } catch (e) {
        debugPrint('[RefundProcessing] Gateway refund call failed (non-blocking): $e');
      }
    }

    if (current.refundMethod == RefundMethod.bank) {
      if (newStatus == RefundStatus.processing) {
        if (!current.hasBankDetails) {
          final details = await _promptBankDetails(current);
          if (details == null) {
            throw Exception('Bank details are required before processing this refund.');
          }

          // CRITICAL: Use backend API instead of direct Firestore writes
          // Backend will:
          // 1. Validate bank details
          // 2. Update refund_requests atomically
          // 3. Create audit log
          // 4. Sync to Firestore eventually
          try {
            final apiService = AdminApiService();
            await apiService.post('/admin/payments/${current.orderId}/refund', {
              'reason': 'customer_requested',
              'bankAccountHolderName': details['name'],
              'bankAccountNumber': details['account'],
              'bankIfsc': details['ifsc'],
              'idempotencyKey': '${current.id}_bank_details_${const Uuid().v4()}',
            });
          } catch (e) {
            debugPrint('[RefundProcessing] Failed to save bank details via backend: $e');
            rethrow;
          }

          current = current.copyWith(
            bankAccountHolderName: details['name'],
            bankAccountNumber: details['account'],
            bankIfsc: details['ifsc'],
          );
        }

        // Best-effort automated payout via RazorpayX. If not configured or
        // it fails, the owner can complete the transfer manually and record
        // a reference when advancing to `completed`.
        try {
          final result = await FirebaseFunctions.instance
              .httpsCallable('initiateBankTransferRefund')
              .call(<String, dynamic>{
                'refundId': current.id,
                'orderId': current.orderId,
                'customerId': current.customerId,
                'amount': current.amount,
                'accountHolderName': current.bankAccountHolderName,
                'accountNumber': current.bankAccountNumber,
                'ifsc': current.bankIfsc,
              });
          final data = result.data;
          if (data is Map && data['success'] == true && data['payoutId'] != null) {
            // CRITICAL: Do NOT write directly to Firestore
            // The Cloud Function (initiateBankTransferRefund) has already initiated the payout
            // Backend reconciliation will sync the payoutId to Firestore eventually
            // DO NOT call Firestore.update() here — it bypasses backend validation

            debugPrint('[RefundProcessing] Bank payout initiated with ID: ${data['payoutId']}');
            current = current.copyWith(payoutId: data['payoutId'] as String);
          } else if (data is Map) {
            debugPrint('[RefundProcessing] Bank transfer payout not automated: ${data['error']}');
          }
        } catch (e) {
          debugPrint(
            '[RefundProcessing] Bank transfer Cloud Function call failed (non-blocking): $e',
          );
        }
      } else if (newStatus == RefundStatus.completed) {
        if (current.payoutId == null || current.payoutId!.isEmpty) {
          final ref = await _promptReference(
            title: 'Confirm bank transfer',
            label: 'Transfer reference / UTR number',
            hint: 'Enter the UTR after completing the NEFT/IMPS transfer',
          );
          if (ref == null || ref.isEmpty) {
            throw Exception('A transfer reference is required to mark this refund completed.');
          }

          // CRITICAL: Use backend API instead of direct Firestore writes
          // Backend will:
          // 1. Validate UTR format
          // 2. Update refund_requests atomically
          // 3. Create audit log with manual transfer reference
          // 4. Sync to Firestore eventually
          try {
            final apiService = AdminApiService();
            await apiService.post('/admin/payments/${current.orderId}/refund', {
              'reason': 'manual_bank_transfer_confirmed',
              'manualTransferReference': ref,
              'idempotencyKey': '${current.id}_utr_${ref}',
            });
          } catch (e) {
            debugPrint('[RefundProcessing] Failed to record transfer reference via backend: $e');
            rethrow;
          }
        }
      }
    }

    await _engine.transitionRefundStatus(
      refundId: current.id,
      newStatus: newStatus,
      actorId: actorId,
      actorRole: actorRole,
    );
  }

  /// Prompts the owner for the customer's bank account details, prefilled
  /// from `users/{customerId}` if the customer has saved bank info.
  Future<Map<String, String>?> _promptBankDetails(RefundRequest refund) async {
    String name = '';
    String account = '';
    String ifsc = '';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(refund.customerId)
          .get();
      final data = userDoc.data();
      if (data != null) {
        name = (data['name'] as String?) ?? (data['fullName'] as String?) ?? '';
        account = (data['bankAccountNumber'] as String?) ?? '';
        ifsc = (data['bankIfsc'] as String?) ?? '';
      }
    } catch (_) {
      // Ignore — owner can fill in manually.
    }

    final nameCtrl = TextEditingController(text: name);
    final accountCtrl = TextEditingController(text: account);
    final ifscCtrl = TextEditingController(text: ifsc);

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bank details for refund', style: TextStyle(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Account holder name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: accountCtrl,
                decoration: const InputDecoration(labelText: 'Account number'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ifscCtrl,
                decoration: const InputDecoration(labelText: 'IFSC code'),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty ||
                  accountCtrl.text.trim().isEmpty ||
                  ifscCtrl.text.trim().isEmpty) {
                return;
              }
              Navigator.of(context).pop({
                'name': nameCtrl.text.trim(),
                'account': accountCtrl.text.trim(),
                'ifsc': ifscCtrl.text.trim().toUpperCase(),
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: AppTheme.white,
            ),
            child: const Text('Save & Continue'),
          ),
        ],
      ),
    );
  }

  /// Generic single-line text prompt, used for the bank-transfer reference
  /// (UTR) entry.
  Future<String?> _promptReference({
    required String title,
    required String label,
    String? hint,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label, hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: AppTheme.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptForReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Mark refund(s) as failed',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'e.g. Gateway refund rejected, customer notified',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: AppTheme.white,
            ),
            child: const Text('Mark Failed'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // LABELS & FORMATTING
  // ──────────────────────────────────────────────────────────────

  Widget _statusChip(RefundStatus status) {
    Color color;
    switch (status) {
      case RefundStatus.pending:
        color = AppTheme.grey500;
        break;
      case RefundStatus.approved:
        color = AppTheme.primary;
        break;
      case RefundStatus.processing:
        color = AppTheme.warning;
        break;
      case RefundStatus.completed:
        color = AppTheme.success;
        break;
      case RefundStatus.failed:
        color = AppTheme.error;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  String _advanceLabel(RefundStatus status) {
    switch (status) {
      case RefundStatus.pending:
        return 'Approve';
      case RefundStatus.approved:
        return 'Start Processing';
      case RefundStatus.processing:
        return 'Mark Completed';
      case RefundStatus.completed:
      case RefundStatus.failed:
        return 'Done';
    }
  }

  String _methodLabel(RefundMethod method) {
    switch (method) {
      case RefundMethod.wallet:
        return 'Wallet Credit';
      case RefundMethod.upi:
        return 'UPI';
      case RefundMethod.gateway:
        return 'Payment Gateway';
      case RefundMethod.bank:
        return 'Bank Transfer';
    }
  }

  String _lastFour(String? account) {
    if (account == null || account.length < 4) return '****';
    return account.substring(account.length - 4);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _actorRole(UserModel user) {
    switch (user.role) {
      case UserRole.owner:
      case UserRole.shopOwner:
        return 'owner';
      case UserRole.superAdmin:
      case UserRole.admin:
        return 'admin';
      case UserRole.employee:
      case UserRole.branchManager:
        return 'manager';
      default:
        return 'system';
    }
  }
}
