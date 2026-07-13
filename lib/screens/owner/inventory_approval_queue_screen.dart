import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/inventory_change_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/inventory_change_request_service.dart';
import '../../utils/app_theme.dart';

/// Owner-only screen: review pending bulk inventory change requests created
/// from the Bulk Inventory Query Builder, preview the exact field diffs per
/// product, and approve (writes to `products` in Firestore + Supabase) or
/// reject (no writes) each request.
class InventoryApprovalQueueScreen extends StatefulWidget {
  const InventoryApprovalQueueScreen({super.key});

  @override
  State<InventoryApprovalQueueScreen> createState() => _InventoryApprovalQueueScreenState();
}

class _InventoryApprovalQueueScreenState extends State<InventoryApprovalQueueScreen> {
  final _service = InventoryChangeRequestService();
  final Set<String> _processingIds = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text(
          'Inventory Approval Queue',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.white,
      ),
      body: StreamBuilder<List<InventoryChangeRequestModel>>(
        stream: _service.watchPendingRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fact_check_outlined, size: 56, color: AppTheme.grey400),
                  SizedBox(height: 12),
                  Text(
                    'No pending inventory changes',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Bulk edits submitted from the Query Builder will appear here for review.',
                    style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (context, i) => _buildRequestCard(requests[i]),
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(InventoryChangeRequestModel request) {
    final isProcessing = _processingIds.contains(request.id);
    // Group changes by product for a cleaner diff preview.
    final Map<String, List<InventoryFieldChange>> byProduct = {};
    for (final c in request.changes) {
      byProduct.putIfAbsent(c.productId, () => []).add(c);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _typeLabel(request.type),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${request.affectedProductCount} product(s)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  _formatDate(request.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              request.filterDescription,
              style: const TextStyle(fontSize: 12, color: AppTheme.grey700),
            ),
            const SizedBox(height: 4),
            Text(
              'Requested by ${request.requestedByName}',
              style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                shrinkWrap: true,
                children: byProduct.entries.map((entry) {
                  final changes = entry.value;
                  final productName = changes.first.productName;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        ...changes.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(left: 8, top: 2),
                            child: Row(
                              children: [
                                Text(
                                  '${c.field}: ',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                                ),
                                Text(
                                  '${c.oldValue}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.error,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward, size: 12, color: AppTheme.grey500),
                                const SizedBox(width: 6),
                                Text(
                                  '${c.newValue}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.success,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 8),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isProcessing ? null : () => _reject(request),
                    icon: const Icon(Icons.close, color: AppTheme.error),
                    label: const Text('Reject', style: TextStyle(color: AppTheme.error)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.error)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isProcessing ? null : () => _approve(request),
                    icon: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.white),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Approve & Apply'),
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

  Future<void> _approve(InventoryChangeRequestModel request) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _processingIds.add(request.id));
    try {
      await _service.approveRequest(
        requestId: request.id,
        ownerId: user.id,
        ownerName: user.name ?? 'Owner',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approved — ${request.affectedProductCount} product(s) updated.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to approve: $e')));
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(request.id));
    }
  }

  Future<void> _reject(InventoryChangeRequestModel request) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    final reason = await _promptForReason();
    if (reason == null) return; // user cancelled

    setState(() => _processingIds.add(request.id));
    try {
      await _service.rejectRequest(
        requestId: request.id,
        ownerId: user.id,
        ownerName: user.name ?? 'Owner',
        reviewNote: reason.isEmpty ? null : reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request rejected.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reject: $e')));
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(request.id));
    }
  }

  Future<String?> _promptForReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject change request', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'e.g. Prices look wrong, please re-check',
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
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  String _typeLabel(InventoryChangeType type) {
    switch (type) {
      case InventoryChangeType.fieldUpdate:
        return 'FIELD UPDATE';
      case InventoryChangeType.priceChange:
        return 'PRICE CHANGE';
      case InventoryChangeType.priceUpdate:
        return 'PRICE UPDATE';
      case InventoryChangeType.stockAdjustment:
        return 'STOCK ADJUSTMENT';
      case InventoryChangeType.stockUpdate:
        return 'STOCK UPDATE';
      case InventoryChangeType.availabilityToggle:
        return 'AVAILABILITY';
      case InventoryChangeType.delete:
        return 'DELETE';
      case InventoryChangeType.other:
        return 'OTHER';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
