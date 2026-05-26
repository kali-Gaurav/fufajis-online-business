import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';
import '../../models/cod_settlement_model.dart';

import '../../models/rider_payout_model.dart';
import '../../services/firestore_service.dart';
import '../../services/rider_payout_service.dart';

class SettlementsManagementScreen extends StatefulWidget {
  const SettlementsManagementScreen({super.key});

  @override
  State<SettlementsManagementScreen> createState() => _SettlementsManagementScreenState();
}

class _SettlementsManagementScreenState extends State<SettlementsManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final RiderPayoutService _payoutService = RiderPayoutService();
  int _ledgerType = 0; // 0 = Cash Settlements, 1 = Refunds, 2 = Rider Payouts
  int _selectedTab = 0; // 0 = Pending, 1 = Approved, 2 = Rejected, 3 = All
  int _selectedRefundTab = 0; // 0 = All, 1 = Pending Refund, 2 = Refunded, 3 = Rejected

  // Local state to simulate updates to mock refunds in the demo

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sub-dashboard Ledger Type Switcher
            Row(
              children: [
                _buildLedgerTypeChip(0, 'COD Cash Settlements', Icons.monetization_on_outlined),
                const SizedBox(width: 12),
                _buildLedgerTypeChip(1, 'Cancellations & Refunds Ledger', Icons.receipt_long_outlined),
                const SizedBox(width: 12),
                _buildLedgerTypeChip(2, 'Fleet Payouts (Instant)', Icons.rocket_launch_outlined),
              ],
            ),
            const SizedBox(height: 24),

            // Header Section
            if (_ledgerType == 0) _buildSettlementsHeader(),
            if (_ledgerType == 1) _buildRefundsHeader(),
            if (_ledgerType == 2) _buildPayoutsHeader(),
            const SizedBox(height: 24),

            // Main Ledger Content
            if (_ledgerType == 0) _buildCashSettlementsSection(),
            if (_ledgerType == 1) _buildCancellationsRefundsSection(),
            if (_ledgerType == 2) _buildRiderPayoutsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerTypeChip(int index, String label, IconData icon) {
    final isSelected = _ledgerType == index;
    return GestureDetector(
      onTap: () => setState(() => _ledgerType = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.grey300,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.white : AppTheme.grey700, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.white : AppTheme.grey700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COD Cash Settlements',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.grey900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Verify and reconcile Cash on Delivery collections from riders.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.grey600,
          ),
        ),
      ],
    );
  }

  Widget _buildRefundsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cancellations & Refunds Ledger',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.grey900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Process customer refunds, manage returned product catalogs, and review feedback.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.grey600,
          ),
        ),
      ],
    );
  }

  Widget _buildPayoutsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fleet Payouts (Instant)',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.grey900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Send earnings and incentives to riders via Razorpay Route. Instant bank transfers.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.grey600,
          ),
        ),
      ],
    );
  }

  Widget _buildRiderPayoutsSection() {
    return Column(
      children: [
        // Real-time Summary Card
        StreamBuilder<List<RiderPayoutModel>>(
          stream: _payoutService.getRiderPayoutsStream(),
          builder: (context, snapshot) {
            final payouts = snapshot.data ?? [];
            final totalSettled = payouts.fold(0.0, (sum, p) => sum + p.amount);

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.indigo.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 40),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Settled via Route', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('₹${totalSettled.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _showInitiatePayoutDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Payout'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.indigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ],
              ),
            );
          }
        ),
        const SizedBox(height: 24),
        
        const Text('Payout History (Bahi Khata)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        StreamBuilder<List<RiderPayoutModel>>(
          stream: _payoutService.getRiderPayoutsStream(),
          builder: (context, snapshot) {
            final payouts = snapshot.data ?? [];
            if (payouts.isEmpty) {
               return _buildEmptyState(
                 icon: Icons.history_edu,
                 title: 'No payout history yet',
                 subtitle: 'Start rewarding your fleet with instant bank transfers.',
               );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payouts.length,
              itemBuilder: (context, index) {
                final p = payouts[index];
                return _buildPayoutRecordCard(p);
              },
            );
          }
        ),
      ],
    );
  }

  void _showInitiatePayoutDialog(BuildContext context) {
    final amountController = TextEditingController();
    String? selectedRiderId;
    String? selectedRiderName;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Initiate Fleet Payout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Transfer funds instantly to a rider\'s linked bank account via Razorpay Route.'),
            const SizedBox(height: 20),
            // Rider Selector
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestoreService.getAuthorizedRidersStream(),
              builder: (context, snap) {
                final riders = snap.data ?? [];
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Select Rider', border: OutlineInputBorder()),
                  items: riders.map((r) => DropdownMenuItem(
                    value: r['phoneNumber'] as String,
                    child: Text(r['name'] as String),
                  )).toList(),
                  onChanged: (val) {
                    selectedRiderId = val;
                    selectedRiderName = riders.firstWhere((r) => r['phoneNumber'] == val)['name'];
                  },
                );
              }
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_rupee)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (selectedRiderId == null || amountController.text.isEmpty) return;
              final amount = double.tryParse(amountController.text) ?? 0;
              
              Navigator.pop(context);
              final result = await _payoutService.initiateInstantPayout(
                riderId: selectedRiderId!,
                riderName: selectedRiderName!,
                amount: amount,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.success ? 'Payout of ₹$amount successful!' : 'Error: ${result.message}'),
                    backgroundColor: result.success ? AppTheme.success : AppTheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            child: const Text('Transfer Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutRecordCard(RiderPayoutModel p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: p.status == PayoutStatus.processed ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
            child: Icon(p.status == PayoutStatus.processed ? Icons.check : Icons.priority_high, color: p.status == PayoutStatus.processed ? AppTheme.success : AppTheme.error),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.riderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Txn: ${p.transactionId ?? 'Failed'}', style: TextStyle(fontSize: 12, color: AppTheme.grey500)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${p.amount}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.indigo)),
              Text(DateFormat('MMM dd, hh:mm a').format(p.timestamp), style: TextStyle(fontSize: 10, color: AppTheme.grey400)),
            ],
          ),
        ],
      ),
    );
  }

  // --- COD Cash Settlements Section ---
  Widget _buildCashSettlementsSection() {
    return Column(
      children: [
        // Tabs
        Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.grey200),
          ),
          child: Row(
            children: [
              _buildTab(0, 'Pending'),
              _buildTab(1, 'Approved'),
              _buildTab(2, 'Rejected'),
              _buildTab(3, 'All History'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        StreamBuilder<List<CodSettlementModel>>(
          stream: _firestoreService.getAllCodSettlementsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Text('Error loading settlements: ${snapshot.error}'),
                ),
              );
            }

            var list = snapshot.data ?? [];

            // Filter lists based on tab
            if (_selectedTab == 0) {
              list = list.where((s) => s.status == 'pending').toList();
            } else if (_selectedTab == 1) {
              list = list.where((s) => s.status == 'approved').toList();
            } else if (_selectedTab == 2) {
              list = list.where((s) => s.status == 'rejected').toList();
            }

            if (list.isEmpty) {
              return _buildEmptyState(
                icon: _selectedTab == 0 ? Icons.done_all : Icons.history,
                title: _selectedTab == 0 ? 'No pending settlement requests!' : 'No matching records.',
                subtitle: 'All rider submissions have been reviewed and balanced.',
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final item = list[index];
                return _buildSettlementCard(item);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppTheme.white : AppTheme.grey600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettlementCard(CodSettlementModel item) {
    final dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(item.submittedAt);
    final resolvedStr = item.resolvedAt != null 
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(item.resolvedAt!) 
        : null;

    Color statusColor = AppTheme.warning;
    if (item.status == 'approved') {
      statusColor = AppTheme.success;
    } else if (item.status == 'rejected') {
      statusColor = AppTheme.error;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
        border: Border.all(color: AppTheme.grey100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_run,
              color: AppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.riderName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.grey900,
                      ),
                    ),
                    Text(
                      '₹${item.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Phone: ${item.riderPhone}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12, color: AppTheme.grey400),
                    const SizedBox(width: 4),
                    Text(
                      'Submitted: $dateStr',
                      style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                    ),
                  ],
                ),
                if (resolvedStr != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 12, color: AppTheme.grey400),
                      const SizedBox(width: 4),
                      Text(
                        'Resolved: $resolvedStr',
                        style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                      ),
                    ],
                  ),
                ],
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.grey50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.grey200),
                    ),
                    child: Text(
                      'Rider Note: "${item.notes}"',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.grey700,
                      ),
                    ),
                  ),
                ],

                // Action Buttons for Pending requests
                if (item.status == 'pending') ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _updateStatus(context, item, 'approved'),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Approve & Reconcile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: AppTheme.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showRejectDialog(context, item),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: const BorderSide(color: AppTheme.error),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationsRefundsSection() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getAllReturnRequestsStream(),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        
        // Computes summary stats
        final totalCancelled = requests.length;
        final pendingCount = requests.where((r) => r['status'] == 'pending').length;
        final refundedTotalAmount = requests
            .where((r) => r['status'] == 'refunded')
            .fold(0.0, (sum, r) => sum + (r['amount'] as num).toDouble());
        final pendingTotalAmount = requests
            .where((r) => r['status'] == 'pending')
            .fold(0.0, (sum, r) => sum + (r['amount'] as num).toDouble());

        // Filter based on tab
        List<Map<String, dynamic>> filtered = [...requests];
        if (_selectedRefundTab == 1) {
          filtered = filtered.where((r) => r['status'] == 'pending').toList();
        } else if (_selectedRefundTab == 2) {
          filtered = filtered.where((r) => r['status'] == 'refunded').toList();
        } else if (_selectedRefundTab == 3) {
          filtered = filtered.where((r) => r['status'] == 'rejected').toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatCard('Total Returns', totalCancelled.toString(), AppTheme.primary, Icons.cancel_outlined),
                _buildStatCard('Pending', '₹${pendingTotalAmount.toStringAsFixed(0)}', AppTheme.warning, Icons.hourglass_empty_rounded),
                _buildStatCard('Processed', '₹${refundedTotalAmount.toStringAsFixed(0)}', AppTheme.success, Icons.check_circle_outline),
                _buildStatCard('Active Cases', pendingCount.toString(), AppTheme.secondary, Icons.pending_actions_outlined),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.grey200),
              ),
              child: Row(
                children: [
                  _buildRefundFilterTab(0, 'All Refunds'),
                  _buildRefundFilterTab(1, 'Pending Approval'),
                  _buildRefundFilterTab(2, 'Processed'),
                  _buildRefundFilterTab(3, 'Rejected / Dispute'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (filtered.isEmpty)
              _buildEmptyState(
                icon: Icons.assignment_turned_in_outlined,
                title: 'No return records found',
                subtitle: 'No customer returns or cancelled items match this status.',
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final refund = filtered[index];
                  return _buildRefundCard(refund);
                },
              ),
          ],
        );
      }
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.grey100),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 10, color: AppTheme.grey500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefundFilterTab(int index, String label) {
    final isSelected = _selectedRefundTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRefundTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.secondary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppTheme.white : AppTheme.grey600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefundCard(Map<String, dynamic> refund) {
    final dateVal = refund['createdAt'] ?? refund['date'];
    final date = dateVal is! Timestamp ? DateTime.now() : dateVal.toDate();
    final dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    final status = refund['status'] as String;

    Color statusColor = AppTheme.warning;
    String statusText = 'Pending Approval';
    IconData statusIcon = Icons.hourglass_empty;

    if (status == 'refunded') {
      statusColor = AppTheme.success;
      statusText = 'Refund Processed';
      statusIcon = Icons.check_circle_outline;
    } else if (status == 'rejected') {
      statusColor = AppTheme.error;
      statusText = 'Refund Disputed/Rejected';
      statusIcon = Icons.highlight_off;
    }

    final reason = refund['reason'] as String;
    // Map cancellation reason categories
    Color reasonBadgeColor = AppTheme.primary;
    if (reason.toLowerCase().contains('freshness')) {
      reasonBadgeColor = AppTheme.error;
    } else if (reason.toLowerCase().contains('late')) {
      reasonBadgeColor = AppTheme.warning;
    } else if (reason.toLowerCase().contains('accidental')) {
      reasonBadgeColor = AppTheme.grey600;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
        border: Border.all(color: AppTheme.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order ID & status header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      refund['orderNumber'] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Customer details & Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    refund['customerName'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.grey800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    refund['customerPhone'] as String,
                    style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                  ),
                ],
              ),
              Text(
                '₹${(refund['amount'] as num).toDouble().toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.secondary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Items Returned details
          Row(
            children: [
              const Icon(Icons.assignment_return_outlined, size: 13, color: AppTheme.grey500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Returned: ${refund['items']}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Reason for cancellation tag
          Row(
            children: [
              const Icon(Icons.info_outline, size: 13, color: AppTheme.grey500),
              const SizedBox(width: 6),
              const Text('Reason: ', style: TextStyle(fontSize: 12, color: AppTheme.grey500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: reasonBadgeColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  refund['reason'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: reasonBadgeColor,
                  ),
                ),
              ),
            ],
          ),

          // Proof Images
          if (refund['proofImages'] != null && (refund['proofImages'] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Customer Proof Photos:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.grey700),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (refund['proofImages'] as List).length,
                itemBuilder: (context, idx) {
                  final imageUrl = refund['proofImages'][idx] as String;
                  return GestureDetector(
                    onTap: () => _showImageLightbox(context, imageUrl),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.grey200),
                        image: DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // Refund notes if completed/rejected
          if (refund['notes'] != null && (refund['notes'] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.grey50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.grey200),
              ),
              child: Text(
                'Refunding Log: ${refund['notes']}',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.grey700),
              ),
            ),
          ],

          // Action buttons for pending refunds
          if (status == 'pending') ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showRejectRefundDialog(refund),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Dispute / Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _processInstantRefund(refund),
                  icon: const Icon(Icons.flash_on, size: 16),
                  label: const Text('Process Instant Refund'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: AppTheme.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _processInstantRefund(Map<String, dynamic> refund) {
    setState(() {
      refund['status'] = 'refunded';
      refund['notes'] = 'Refunded instantly to Paytm Wallet on ${DateFormat('hh:mm a').format(DateTime.now())}. Transaction ID: TXN_${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Refund of ₹${refund['amount']} processed successfully for order ${refund['orderNumber']}!'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _showRejectRefundDialog(Map<String, dynamic> refund) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dispute Refund Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Input reason for rejecting refund of ₹${refund['amount']} for ${refund['customerName']}:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Dispute Reason',
                border: OutlineInputBorder(),
                hintText: 'e.g. Items were opened or not returned',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                refund['status'] = 'rejected';
                refund['notes'] = 'Disputed: ${controller.text.trim().isNotEmpty ? controller.text.trim() : 'Reason not provided.'}';
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Refund request for ${refund['orderNumber']} marked as disputed/rejected.'),
                  backgroundColor: AppTheme.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Reject Refund'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.grey200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.grey400),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.grey700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, CodSettlementModel item, String status, {String? notes}) async {
    try {
      await _firestoreService.updateCodSettlementStatus(item.id, status, notes: notes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settlement request from ${item.riderName} is $status!'),
            backgroundColor: status == 'approved' ? AppTheme.success : AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showRejectDialog(BuildContext context, CodSettlementModel item) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject Cash Submission'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to reject the submission of ₹${item.amount.toStringAsFixed(0)} by ${item.riderName}?'),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Rejection',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Amount mismatch by ₹50',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = noteController.text.trim();
                Navigator.pop(context);
                _updateStatus(
                  context,
                  item,
                  'rejected',
                  notes: reason.isNotEmpty ? 'Rejected: $reason' : 'Rejected by owner',
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              child: const Text('Reject Submission'),
            ),
          ],
        );
      },
    );
  }

  void _showImageLightbox(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(40),
                    color: Colors.white,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

