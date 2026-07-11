import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fufajis_online/providers/inventory_provider.dart';
import 'package:fufajis_online/services/stock_adjustment_service.dart';

/// Stock Adjustment Screen
/// Manages manual inventory adjustments with approval workflow
class StockAdjustmentScreen extends StatefulWidget {
  const StockAdjustmentScreen({Key? key}) : super(key: key);

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  late StockAdjustmentService _adjustmentService;
  final List<Stream<dynamic>> _subscriptions = [];
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _adjustmentService = StockAdjustmentService();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {});
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      // Stream cleanup
    }
    super.dispose();
  }

  void _showCreateAdjustmentDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateAdjustmentDialog(
        onAdjustmentCreated: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Adjustments'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateAdjustmentDialog,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _adjustmentService.streamStockAdjustments(
          status: _filterStatus == 'all' ? null : _filterStatus,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final adjustments = snapshot.data ?? [];

          return Column(
            children: [
              // Filter tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: _filterStatus == 'all',
                        onSelected: () => setState(() => _filterStatus = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Pending',
                        isSelected: _filterStatus == 'pending',
                        onSelected: () => setState(() => _filterStatus = 'pending'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Approved',
                        isSelected: _filterStatus == 'approved',
                        onSelected: () => setState(() => _filterStatus = 'approved'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Rejected',
                        isSelected: _filterStatus == 'rejected',
                        onSelected: () => setState(() => _filterStatus = 'rejected'),
                      ),
                    ],
                  ),
                ),
              ),
              // Adjustments list
              Expanded(
                child: adjustments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 48,
                              color: isDark ? Colors.grey[700] : Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No adjustments found',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: adjustments.length,
                        itemBuilder: (context, index) {
                          final adjustment = adjustments[index];
                          return _AdjustmentCard(
                            adjustment: adjustment,
                            onApprove: _filterStatus == 'pending'
                                ? () => _showApproveDialog(adjustment)
                                : null,
                            onReject: _filterStatus == 'pending'
                                ? () => _showRejectDialog(adjustment)
                                : null,
                            isDark: isDark,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showApproveDialog(Map<String, dynamic> adjustment) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Adjustment?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product: ${adjustment['product_name']}'),
            const SizedBox(height: 8),
            Text('Type: ${adjustment['adjustment_type']}'),
            const SizedBox(height: 8),
            Text('Quantity: ${adjustment['quantity']} units'),
            const SizedBox(height: 8),
            Text('Reason: ${adjustment['reason']}'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Approval Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _adjustmentService.approveAdjustment(
                  adjustmentId: adjustment['id'],
                  productId: adjustment['product_id'],
                  quantity: adjustment['quantity'],
                  adjustmentType: adjustment['adjustment_type'],
                  approvedBy: 'current_user',
                  notes: notesController.text,
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Adjustment approved')),
                  );
                  _loadData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> adjustment) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Adjustment?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product: ${adjustment['product_name']}'),
            const SizedBox(height: 8),
            Text('Type: ${adjustment['adjustment_type']}'),
            const SizedBox(height: 8),
            Text('Quantity: ${adjustment['quantity']} units'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _adjustmentService.rejectAdjustment(
                  adjustmentId: adjustment['id'],
                  rejectionReason: reasonController.text,
                  rejectedBy: 'current_user',
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Adjustment rejected')),
                  );
                  _loadData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

// Create adjustment dialog
class _CreateAdjustmentDialog extends StatefulWidget {
  final VoidCallback onAdjustmentCreated;

  const _CreateAdjustmentDialog({required this.onAdjustmentCreated});

  @override
  State<_CreateAdjustmentDialog> createState() => _CreateAdjustmentDialogState();
}

class _CreateAdjustmentDialogState extends State<_CreateAdjustmentDialog> {
  late StockAdjustmentService _adjustmentService;
  final _productIdController = TextEditingController();
  final _productNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  final _batchNumberController = TextEditingController();

  String _selectedType = 'damage';

  @override
  void initState() {
    super.initState();
    _adjustmentService = StockAdjustmentService();
  }

  @override
  void dispose() {
    _productIdController.dispose();
    _productNameController.dispose();
    _quantityController.dispose();
    _reasonController.dispose();
    _batchNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Stock Adjustment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _productIdController,
              decoration: const InputDecoration(
                labelText: 'Product ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _productNameController,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedType,
              items: const [
                DropdownMenuItem(value: 'damage', child: Text('Damage')),
                DropdownMenuItem(value: 'loss', child: Text('Loss')),
                DropdownMenuItem(value: 'theft', child: Text('Theft')),
                DropdownMenuItem(value: 'recount_correction', child: Text('Recount Correction')),
                DropdownMenuItem(value: 'expiry', child: Text('Expiry')),
              ],
              onChanged: (value) => setState(() => _selectedType = value ?? 'damage'),
              decoration: const InputDecoration(
                labelText: 'Adjustment Type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _batchNumberController,
              decoration: const InputDecoration(
                labelText: 'Batch Number (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              final quantity = int.parse(_quantityController.text);
              if (quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Quantity must be positive')),
                );
                return;
              }

              await _adjustmentService.adjustStock(
                productId: _productIdController.text,
                productName: _productNameController.text,
                adjustmentType: _selectedType,
                quantity: quantity,
                reason: _reasonController.text,
                batchNumber: _batchNumberController.text.isNotEmpty
                    ? _batchNumberController.text
                    : null,
                createdBy: 'current_user',
              );

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Adjustment created')),
                );
                widget.onAdjustmentCreated();
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

// Adjustment card
class _AdjustmentCard extends StatelessWidget {
  final Map<String, dynamic> adjustment;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool isDark;

  const _AdjustmentCard({
    required this.adjustment,
    required this.onApprove,
    required this.onReject,
    required this.isDark,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = adjustment['status'] as String;
    final statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adjustment['product_name'] ?? 'Unknown',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        adjustment['adjustment_type'],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Qty: ${adjustment['quantity']} units',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Reason: ${adjustment['reason']}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Created by: ${adjustment['created_by'] ?? "unknown"}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ] else if (status == 'approved') ...[
              const SizedBox(height: 8),
              Text(
                'Approved by: ${adjustment['approved_by'] ?? "unknown"}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.green,
                ),
              ),
              if (adjustment['notes']?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  'Notes: ${adjustment['notes']}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ] else if (status == 'rejected') ...[
              const SizedBox(height: 8),
              Text(
                'Rejection: ${adjustment['rejection_reason'] ?? "no reason provided"}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.red[400],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Filter chip
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: Colors.transparent,
      selectedColor: Colors.blue.withOpacity(0.3),
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.grey,
      ),
    );
  }
}
