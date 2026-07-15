import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fufajis_online/providers/inventory_provider.dart';
import 'package:fufajis_online/models/inventory_models.dart';

/// Purchase Order Screen
/// Displays list of purchase orders with status tracking and creation capability
class PurchaseOrderScreen extends StatefulWidget {
  const PurchaseOrderScreen({Key? key}) : super(key: key);

  @override
  State<PurchaseOrderScreen> createState() => _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends State<PurchaseOrderScreen> {
  String _selectedStatus = 'all';
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Status filter tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _StatusChip(
                  label: 'All',
                  value: 'all',
                  isSelected: _selectedStatus == 'all',
                  onTap: () => setState(() => _selectedStatus = 'all'),
                ),
                _StatusChip(
                  label: 'Draft',
                  value: 'draft',
                  isSelected: _selectedStatus == 'draft',
                  onTap: () => setState(() => _selectedStatus = 'draft'),
                ),
                _StatusChip(
                  label: 'Sent',
                  value: 'sent',
                  isSelected: _selectedStatus == 'sent',
                  onTap: () => setState(() => _selectedStatus = 'sent'),
                ),
                _StatusChip(
                  label: 'Confirmed',
                  value: 'confirmed',
                  isSelected: _selectedStatus == 'confirmed',
                  onTap: () => setState(() => _selectedStatus = 'confirmed'),
                ),
                _StatusChip(
                  label: 'Received',
                  value: 'received',
                  isSelected: _selectedStatus == 'received',
                  onTap: () => setState(() => _selectedStatus = 'received'),
                ),
              ],
            ),
          ),
          // POs list
          Expanded(
            child: Consumer<InventoryProvider>(
              builder: (context, inventoryProvider, child) {
                final filteredPOs = _selectedStatus == 'all'
                    ? inventoryProvider.purchaseOrders
                    : inventoryProvider.getFilteredPOs(status: _selectedStatus);

                if (filteredPOs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No purchase orders found',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredPOs.length,
                  itemBuilder: (context, index) {
                    final po = filteredPOs[index];
                    return _POCard(po: po, isDark: isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePODialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreatePODialog() {
    showDialog(
      context: context,
      builder: (context) => const _CreatePODialog(),
    );
  }
}

// PO card widget
class _POCard extends StatelessWidget {
  final PurchaseOrder po;
  final bool isDark;

  const _POCard({required this.po, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(po.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PO number and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      po.poNumber,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      po.supplierName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  po.statusLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // PO details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      po.grandTotalFormatted,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Items',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${po.itemCount} products',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Created',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      po.createdAtFormatted,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (po.expectedDeliveryDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Expected: ${po.expectedDeliveryDate!.day}/${po.expectedDeliveryDate!.month}/${po.expectedDeliveryDate!.year}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

          // Actions
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showPODetails(context),
                  icon: const Icon(Icons.info, size: 18),
                  label: const Text('Details'),
                ),
              ),
              const SizedBox(width: 8),
              if (po.status == 'draft')
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approvePO(context),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Send'),
                  ),
                ),
              if (po.status == 'sent' || po.status == 'confirmed')
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _receivePO(context),
                    icon: const Icon(Icons.unarchive, size: 18),
                    label: const Text('Receive'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.blue;
      case 'confirmed':
        return Colors.orange;
      case 'received':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showPODetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(po.poNumber),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow(label: 'Supplier', value: po.supplierName),
              _DetailRow(label: 'Status', value: po.statusLabel),
              _DetailRow(label: 'Amount', value: po.grandTotalFormatted),
              _DetailRow(label: 'Items', value: '${po.itemCount} products'),
              _DetailRow(label: 'Created', value: po.createdAtFormatted),
              if (po.expectedDeliveryDate != null)
                _DetailRow(
                  label: 'Expected Delivery',
                  value: '${po.expectedDeliveryDate!.day}/${po.expectedDeliveryDate!.month}/${po.expectedDeliveryDate!.year}',
                ),
              if (po.notes != null)
                _DetailRow(label: 'Notes', value: po.notes!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _approvePO(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PO approved and sent to supplier')),
    );
  }

  void _receivePO(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receive Purchase Order'),
        content: const Text('Mark items as received?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PO received successfully')),
              );
            },
            child: const Text('Receive'),
          ),
        ],
      ),
    );
  }
}

// Status chip widget
class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

// Detail row widget
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// Create PO dialog
class _CreatePODialog extends StatefulWidget {
  const _CreatePODialog();

  @override
  State<_CreatePODialog> createState() => _CreatePODialogState();
}

class _CreatePODialogState extends State<_CreatePODialog> {
  String? _selectedSupplierId;
  final List<Map<String, dynamic>> _items = [];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Purchase Order'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedSupplierId,
              decoration: const InputDecoration(labelText: 'Select Supplier'),
              items: const [
                DropdownMenuItem(value: 'supplier1', child: Text('Supplier 1')),
                DropdownMenuItem(value: 'supplier2', child: Text('Supplier 2')),
              ],
              onChanged: (value) => setState(() => _selectedSupplierId = value),
            ),
            const SizedBox(height: 12),
            if (_items.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return ListTile(
                    title: Text(item['product_name'] as String),
                    subtitle: Text('${item['quantity']} x ₹${item['unit_cost']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => setState(() => _items.removeAt(index)),
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
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
          onPressed: _selectedSupplierId != null && _items.isNotEmpty
              ? () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Purchase order created successfully')),
                  );
                }
              : null,
          child: const Text('Create'),
        ),
      ],
    );
  }

  void _addItem() {
    // TODO: Implement add item dialog
  }
}
