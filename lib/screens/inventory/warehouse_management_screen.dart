import 'package:flutter/material.dart';
import 'package:fufajis_online/services/warehouse_service.dart';

/// Warehouse Management Screen
/// Manages bin locations, utilization, and stock counting
class WarehouseManagementScreen extends StatefulWidget {
  const WarehouseManagementScreen({Key? key}) : super(key: key);

  @override
  State<WarehouseManagementScreen> createState() => _WarehouseManagementScreenState();
}

class _WarehouseManagementScreenState extends State<WarehouseManagementScreen> {
  late WarehouseService _warehouseService;
  String? _selectedWarehouse;
  Map<String, dynamic>? _warehouseStats;

  @override
  void initState() {
    super.initState();
    _warehouseService = WarehouseService();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Warehouse Management'),
        elevation: 0,
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            onPressed: () => _showCreateWarehouseDialog(),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            onPressed: () => _showStockCountDialog(),
            child: const Icon(Icons.fact_check),
          ),
        ],
      ),
      body: Column(
        children: [
          // Warehouse selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Warehouse',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _warehouseService.getWarehouses(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final warehouses = snapshot.data ?? [];
                    if (warehouses.isEmpty) {
                      return Text(
                        'No warehouses. Create one to get started.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: warehouses.map((warehouse) {
                          final warehouseId = warehouse['id'] as String;
                          final isSelected = _selectedWarehouse == warehouseId;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(warehouse['warehouse_name'] ?? 'Warehouse'),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _selectedWarehouse = warehouseId),
                              backgroundColor: Colors.transparent,
                              selectedColor: Colors.blue.withOpacity(0.3),
                              side: BorderSide(
                                color: isSelected ? Colors.blue : Colors.grey,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Warehouse stats
          if (_selectedWarehouse != null)
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _warehouseService.getWarehouseUtilization(_selectedWarehouse!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final stats = snapshot.data ?? {};
                  final binUtilization = (stats['bin_utilization_percentage'] as num?)?.toDouble() ?? 0;
                  final capacityUtilization =
                      (stats['capacity_utilization_percentage'] as num?)?.toDouble() ?? 0;

                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Utilization cards
                          Row(
                            children: [
                              Expanded(
                                child: _UtilizationCard(
                                  label: 'Bin Utilization',
                                  value: '${binUtilization.toStringAsFixed(1)}%',
                                  percentage: binUtilization,
                                  color: Colors.blue,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _UtilizationCard(
                                  label: 'Capacity Utilization',
                                  value: '${capacityUtilization.toStringAsFixed(1)}%',
                                  percentage: capacityUtilization,
                                  color: Colors.green,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Bins list
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: _warehouseService.getWarehouseBins(_selectedWarehouse!),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const CircularProgressIndicator();
                              }

                              final bins = snapshot.data ?? [];
                              if (bins.isEmpty) {
                                return Text(
                                  'No bins configured',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bins (${bins.length})',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...bins.map((bin) => _BinCard(
                                    bin: bin,
                                    onPick: () => _showPickDialog(bin),
                                    isDark: isDark,
                                  )),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Expanded(
              child: Center(
                child: Text(
                  'Select a warehouse',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showCreateWarehouseDialog() {
    final nameController = TextEditingController();
    final zoneController = TextEditingController();
    final binsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Warehouse'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Warehouse Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: zoneController,
              decoration: const InputDecoration(
                labelText: 'Zone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: binsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of Bins',
                border: OutlineInputBorder(),
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
            onPressed: () async {
              try {
                await _warehouseService.createWarehouse(
                  warehouseName: nameController.text,
                  zone: zoneController.text,
                  temperature: null,
                  humidity: null,
                  totalBins: int.parse(binsController.text),
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Warehouse created')),
                  );
                  setState(() {});
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
      ),
    );
  }

  void _showStockCountDialog() {
    if (_selectedWarehouse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a warehouse first')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Perform Stock Count'),
        content: Text(
          'Mark current time as physical inventory verification for warehouse?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _warehouseService.performStockCount(
                  warehouseId: _selectedWarehouse!,
                  countedBy: 'current_user',
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Stock count recorded')),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showPickDialog(Map<String, dynamic> bin) {
    final quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick Items'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bin: ${bin['bin_id']}'),
            const SizedBox(height: 8),
            Text('Available: ${bin['quantity']} units'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity to Pick',
                border: OutlineInputBorder(),
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
            onPressed: () async {
              try {
                final quantity = int.parse(quantityController.text);
                await _warehouseService.removeBinLocation(
                  binLocationId: bin['id'],
                  quantityPicked: quantity,
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Picked: $quantity units')),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Pick'),
          ),
        ],
      ),
    );
  }
}

// Utilization card
class _UtilizationCard extends StatelessWidget {
  final String label;
  final String value;
  final double percentage;
  final Color color;
  final bool isDark;

  const _UtilizationCard({
    required this.label,
    required this.value,
    required this.percentage,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 6,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Bin card
class _BinCard extends StatelessWidget {
  final Map<String, dynamic> bin;
  final VoidCallback onPick;
  final bool isDark;

  const _BinCard({
    required this.bin,
    required this.onPick,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final quantity = bin['quantity'] as int? ?? 0;
    final isEmpty = quantity == 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  bin['bin_id'] ?? 'Bin',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isEmpty ? Colors.grey[300] : Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isEmpty ? 'Empty' : 'In Stock',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isEmpty ? Colors.grey[700] : Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Product: ${bin['product_id'] ?? "unknown"}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Quantity: $quantity units',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (bin['batch_number'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Batch: ${bin['batch_number']}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isEmpty ? null : onPick,
                icon: const Icon(Icons.shopping_basket, size: 18),
                label: const Text('Pick'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
