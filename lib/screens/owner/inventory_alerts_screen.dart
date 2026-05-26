import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/product_provider.dart';
import '../../providers/product_provider_extensions.dart';
import '../../models/low_stock_alert_model.dart';

/// Inventory Alerts Screen
/// Displays low-stock alerts with predictions and reorder recommendations
class InventoryAlertsScreen extends StatefulWidget {
  const InventoryAlertsScreen({Key? key}) : super(key: key);

  @override
  State<InventoryAlertsScreen> createState() => _InventoryAlertsScreenState();
}

class _InventoryAlertsScreenState extends State<InventoryAlertsScreen> {
  late TextEditingController _searchController;
  String _selectedSeverity = 'All';
  bool _isLoading = false;
  List<LowStockAlert> _filteredAlerts = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadAlerts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ProductProvider>();
      final alerts = provider.lowStockAlerts;
      
      _filterAlerts(alerts);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading alerts: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterAlerts(List<LowStockAlert> alerts) {
    List<LowStockAlert> filtered = alerts;

    // Filter by severity
    if (_selectedSeverity != 'All') {
      filtered = filtered
          .where((alert) => alert.severity == _selectedSeverity)
          .toList();
    }

    // Filter by search query
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered
          .where((alert) => alert.productName.toLowerCase().contains(query))
          .toList();
    }

    setState(() => _filteredAlerts = filtered);
  }

  Future<void> _dismissAlert(LowStockAlert alert) async {
    try {
      final provider = context.read<ProductProvider>();
      await provider.dismissInventoryAlert(alert.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert dismissed')),
      );
      
      await _loadAlerts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error dismissing alert: $e')),
      );
    }
  }

  Future<void> _reorderNow(LowStockAlert alert) async {
    // Navigate to reorder screen or show reorder dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reorder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product: ${alert.productName}'),
            const SizedBox(height: 8),
            Text('Recommended Quantity: ${alert.recommendedReorderQuantity}'),
            const SizedBox(height: 8),
            Text('Current Stock: ${alert.currentStock}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reorder initiated')),
              );
            },
            child: const Text('Confirm Reorder'),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'Critical':
        return Colors.red;
      case 'High':
        return Colors.orange;
      case 'Medium':
        return Colors.amber;
      case 'Low':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Alerts'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search and Filter
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        onChanged: (_) {
                          final provider = context.read<ProductProvider>();
                          _filterAlerts(provider.lowStockAlerts);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Severity Filter
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            'All',
                            'Critical',
                            'High',
                            'Medium',
                            'Low',
                          ]
                              .map((severity) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text(severity),
                                      selected: _selectedSeverity == severity,
                                      onSelected: (_) {
                                        setState(() => _selectedSeverity = severity);
                                        final provider =
                                            context.read<ProductProvider>();
                                        _filterAlerts(provider.lowStockAlerts);
                                      },
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Alerts List
                Expanded(
                  child: _filteredAlerts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 64,
                                color: Colors.green[300],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No alerts',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your inventory is healthy!',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredAlerts.length,
                          itemBuilder: (context, index) {
                            final alert = _filteredAlerts[index];
                            return _buildAlertCard(alert);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildAlertCard(LowStockAlert alert) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with severity badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${alert.productId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(alert.severity).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    alert.severity,
                    style: TextStyle(
                      color: _getSeverityColor(alert.severity),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stock Information
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn(
                  'Current Stock',
                  '${alert.currentStock}',
                  Colors.blue,
                ),
                _buildInfoColumn(
                  'Daily Sales',
                  '${alert.averageDailySales.toStringAsFixed(1)}',
                  Colors.orange,
                ),
                _buildInfoColumn(
                  'Days Until Stockout',
                  '${alert.daysUntilStockout}',
                  alert.daysUntilStockout <= 3 ? Colors.red : Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Recommendation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reorder ${alert.recommendedReorderQuantity} units to maintain ${alert.recommendedStockDays} days of stock',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _dismissAlert(alert),
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _reorderNow(alert),
                    child: const Text('Reorder Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
