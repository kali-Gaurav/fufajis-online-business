import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fufajis_online/providers/inventory_provider.dart';
import 'package:fufajis_online/services/expiry_service.dart';

/// Expiry Management Screen
/// Displays expiry alerts, batch tracking, and disposal workflows
class ExpiryManagementScreen extends StatefulWidget {
  const ExpiryManagementScreen({Key? key}) : super(key: key);

  @override
  State<ExpiryManagementScreen> createState() => _ExpiryManagementScreenState();
}

class _ExpiryManagementScreenState extends State<ExpiryManagementScreen> {
  late ExpiryService _expiryService;
  String _filterUrgency = 'all';

  @override
  void initState() {
    super.initState();
    _expiryService = ExpiryService();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expiry Management'),
        elevation: 0,
      ),
      body: Column(
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
                    isSelected: _filterUrgency == 'all',
                    onSelected: () => setState(() => _filterUrgency = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Expired',
                    isSelected: _filterUrgency == 'expired',
                    onSelected: () => setState(() => _filterUrgency = 'expired'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Critical',
                    isSelected: _filterUrgency == 'critical',
                    onSelected: () => setState(() => _filterUrgency = 'critical'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Urgent',
                    isSelected: _filterUrgency == 'urgent',
                    onSelected: () => setState(() => _filterUrgency = 'urgent'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Caution',
                    isSelected: _filterUrgency == 'caution',
                    onSelected: () => setState(() => _filterUrgency = 'caution'),
                  ),
                ],
              ),
            ),
          ),
          // Alerts list
          Expanded(
            child: Consumer<InventoryProvider>(
              builder: (context, provider, child) {
                final alerts = _filterUrgency == 'all'
                    ? provider.expiryAlerts
                    : provider.expiryAlerts
                        .where((a) => a.urgencyLabel == _filterUrgency)
                        .toList();

                if (alerts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No items in this category',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    return _ExpiryAlertCard(
                      alert: alert,
                      onDispose: () => _showDisposeDialog(alert),
                      isDark: isDark,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDisposeDialog(expiryAlert) {
    String? selectedMethod;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Dispose Items'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product: ${expiryAlert.productName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Batch: ${expiryAlert.batchNumber}'),
              const SizedBox(height: 8),
              Text('Quantity: ${expiryAlert.quantityRemaining} units'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedMethod,
                items: const [
                  DropdownMenuItem(value: 'destroyed', child: Text('Destroyed')),
                  DropdownMenuItem(value: 'donated', child: Text('Donated')),
                  DropdownMenuItem(value: 'returned', child: Text('Returned to Supplier')),
                  DropdownMenuItem(value: 'sold_as_discount', child: Text('Sold at Discount')),
                ],
                onChanged: (value) => setState(() => selectedMethod = value),
                decoration: const InputDecoration(
                  labelText: 'Disposal Method',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedMethod == null
                  ? null
                  : () async {
                      try {
                        await _expiryService.disposeBatch(
                          batchId: expiryAlert.batchNumber,
                          disposalMethod: selectedMethod!,
                          reason: reasonController.text,
                          disposedBy: 'current_user',
                        );

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Disposed: ${expiryAlert.productName}'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              child: const Text('Dispose'),
            ),
          ],
        ),
      ),
    );
  }
}

// Expiry alert card
class _ExpiryAlertCard extends StatelessWidget {
  final expiryAlert;
  final VoidCallback onDispose;
  final bool isDark;

  const _ExpiryAlertCard({
    required this.expiryAlert,
    required this.onDispose,
    required this.isDark,
  });

  Color _getUrgencyColor(String urgency) {
    switch (urgency) {
      case 'expired':
        return Colors.red;
      case 'critical':
        return Colors.deepOrange;
      case 'urgent':
        return Colors.orange;
      case 'caution':
        return Colors.amber;
      case 'watch':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final urgencyColor = _getUrgencyColor(expiryAlert.urgencyLabel);
    final daysText = expiryAlert.daysUntilExpiry > 0
        ? '${expiryAlert.daysUntilExpiry} days'
        : expiryAlert.daysUntilExpiry == 0
            ? 'Today'
            : 'Expired';

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
                        expiryAlert.productName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Batch: ${expiryAlert.batchNumber}',
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
                    color: urgencyColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    expiryAlert.urgencyLabel.toUpperCase(),
                    style: TextStyle(
                      color: urgencyColor,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quantity',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${expiryAlert.quantityRemaining} units',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Expires in',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    Text(
                      daysText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: urgencyColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onDispose,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Dispose Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                ),
              ),
            ),
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
      selectedColor: Colors.orange.withOpacity(0.3),
      side: BorderSide(
        color: isSelected ? Colors.orange : Colors.grey,
      ),
    );
  }
}
