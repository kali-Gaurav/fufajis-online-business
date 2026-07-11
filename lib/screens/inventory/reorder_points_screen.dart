import 'package:flutter/material.dart';

/// Reorder Points Configuration Screen
/// Allows users to set reorder points and thresholds for products
class ReorderPointsScreen extends StatefulWidget {
  const ReorderPointsScreen({Key? key}) : super(key: key);

  @override
  State<ReorderPointsScreen> createState() => _ReorderPointsScreenState();
}

class _ReorderPointsScreenState extends State<ReorderPointsScreen> {
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reorder Points'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          // Products list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: 10, // TODO: Replace with actual products
              itemBuilder: (context, index) {
                return _ReorderPointCard(
                  productName: 'Product ${index + 1}',
                  currentStock: (100 - (index * 10)),
                  reorderPoint: 20 + index,
                  reorderQuantity: 100,
                  isDark: isDark,
                  onEdit: () => _showEditDialog(context, index),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddReorderDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => _ReorderPointDialog(
        title: 'Edit Reorder Point',
        productName: 'Product ${index + 1}',
        currentStock: 100 - (index * 10),
        onSave: (point, quantity, leadTime, maxStock) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reorder point updated')),
          );
        },
      ),
    );
  }

  void _showAddReorderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _ReorderPointDialog(
        title: 'Add Reorder Point',
      ),
    );
  }
}

// Reorder point card
class _ReorderPointCard extends StatelessWidget {
  final String productName;
  final int currentStock;
  final int reorderPoint;
  final int reorderQuantity;
  final bool isDark;
  final VoidCallback onEdit;

  const _ReorderPointCard({
    required this.productName,
    required this.currentStock,
    required this.reorderPoint,
    required this.reorderQuantity,
    required this.isDark,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final needsReorder = currentStock <= reorderPoint;
    final statusColor = needsReorder ? Colors.red : Colors.green;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                productName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  needsReorder ? 'Needs Reorder' : 'Sufficient',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stock levels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Stock',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currentStock units',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reorder Point',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$reorderPoint units',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Qty to Order',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$reorderQuantity units',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit'),
            ),
          ),
        ],
      ),
    );
  }
}

// Reorder point edit dialog
class _ReorderPointDialog extends StatefulWidget {
  final String title;
  final String? productName;
  final int? currentStock;
  final Function(int, int, int, int)? onSave;

  const _ReorderPointDialog({
    required this.title,
    this.productName,
    this.currentStock,
    this.onSave,
  });

  @override
  State<_ReorderPointDialog> createState() => _ReorderPointDialogState();
}

class _ReorderPointDialogState extends State<_ReorderPointDialog> {
  late TextEditingController _reorderPointController;
  late TextEditingController _reorderQtyController;
  late TextEditingController _leadTimeController;
  late TextEditingController _maxStockController;
  bool _autoReorder = true;

  @override
  void initState() {
    super.initState();
    _reorderPointController = TextEditingController(text: '20');
    _reorderQtyController = TextEditingController(text: '100');
    _leadTimeController = TextEditingController(text: '2');
    _maxStockController = TextEditingController(text: '200');
  }

  @override
  void dispose() {
    _reorderPointController.dispose();
    _reorderQtyController.dispose();
    _leadTimeController.dispose();
    _maxStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.productName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Product: ${widget.productName}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            TextField(
              controller: _reorderPointController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Reorder Point (units)',
                hintText: 'Trigger level for reordering',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reorderQtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Reorder Quantity (units)',
                hintText: 'Amount to order when triggered',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _leadTimeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Lead Time (days)',
                hintText: 'Days to receive from supplier',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxStockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max Stock Level (units)',
                hintText: 'Maximum inventory level',
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Enable Auto-Reorder'),
              value: _autoReorder,
              onChanged: (value) => setState(() => _autoReorder = value ?? true),
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
          onPressed: () {
            widget.onSave?.call(
              int.parse(_reorderPointController.text),
              int.parse(_reorderQtyController.text),
              int.parse(_leadTimeController.text),
              int.parse(_maxStockController.text),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
