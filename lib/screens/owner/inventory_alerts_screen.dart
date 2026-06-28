import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/product_provider_extensions.dart';
import '../../models/low_stock_alert_model.dart';
import '../../utils/app_theme.dart';

/// Inventory Alerts Screen
/// Displays low-stock alerts with predictions and reorder recommendations
class InventoryAlertsScreen extends StatefulWidget {
  const InventoryAlertsScreen({super.key});

  @override
  State<InventoryAlertsScreen> createState() => _InventoryAlertsScreenState();
}

class _InventoryAlertsScreenState extends State<InventoryAlertsScreen> with SingleTickerProviderStateMixin {
  late TextEditingController _searchController;
  late TabController _tabController;
  String _selectedSeverity = 'All';
  bool _isLoading = false;
  List<LowStockAlert> _filteredAlerts = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadAlerts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ProductProvider>();
      final alerts = provider.lowStockAlerts;
      _filterAlerts(alerts);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading alerts: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runDiagnostics() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ProductProvider>();
      await provider.checkAllProductsLowStock();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diagnostics run successfully! Stock metrics updated.'), backgroundColor: AppTheme.success),
      );
      _loadAlerts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error running diagnostics: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterAlerts(List<LowStockAlert> alerts) {
    List<LowStockAlert> filtered = alerts;

    // Filter by Tab: 0 = Current Low Stock (below minimum stock), 1 = Predicted Stockout (stockout predicted within 7 days)
    if (_tabController.index == 0) {
      filtered = filtered.where((alert) => alert.currentStock <= alert.minimumStock).toList();
    } else {
      filtered = filtered.where((alert) => alert.daysUntilStockout > 0 && alert.daysUntilStockout <= 7).toList();
    }

    // Filter by severity
    if (_selectedSeverity != 'All') {
      filtered = filtered
          .where((alert) => alert.severity.toLowerCase() == _selectedSeverity.toLowerCase())
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
        SnackBar(content: Text('Error dismissing alert: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _reorderNow(LowStockAlert alert) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shopping_cart_checkout, color: AppTheme.info),
            SizedBox(width: 8),
            Text('Confirm Reorder'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product: ${alert.productName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Current Stock: ${alert.currentStock} units'),
            Text('Average Daily Sales: ${alert.averageDailySales.toStringAsFixed(1)} units/day'),
            const Divider(height: 24),
            Text('Recommended Restock: ${alert.recommendedReorderQuantity} units', style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('This quantity covers ${alert.recommendedStockDays > 0 ? alert.recommendedStockDays : 14} days of future sales velocity.', style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
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
                SnackBar(content: Text('Purchase Order for ${alert.recommendedReorderQuantity} units sent to distributor!'), backgroundColor: AppTheme.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.info),
            child: const Text('Confirm Order'),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return AppTheme.error;
      case 'high':
        return AppTheme.warning;
      case 'medium':
        return AppTheme.warning;
      case 'low':
        return AppTheme.info;
      default:
        return AppTheme.grey500;
    }
  }

  Color _getDaysRemainingColor(int days) {
    if (days <= 1) return AppTheme.error;
    if (days <= 3) return AppTheme.warning;
    if (days <= 7) return AppTheme.warning;
    return AppTheme.success;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Forecast & Alerts', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: _runDiagnostics,
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Run Inventory Predictions',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.info,
          labelColor: AppTheme.info,
          unselectedLabelColor: AppTheme.grey600,
          tabs: const [
            Tab(text: 'Low Stock / कम स्टॉक'),
            Tab(text: 'Predicted Stockouts / संभावित कमी'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent))
          : Column(
              children: [
                // Search and Filter
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => _filterAlerts(provider.lowStockAlerts),
                        decoration: InputDecoration(
                          hintText: 'Search products by name...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.grey800 : AppTheme.grey100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
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
                                      selectedColor: AppTheme.info.withValues(alpha: 0.15),
                                      checkmarkColor: AppTheme.info,
                                      labelStyle: TextStyle(
                                        color: _selectedSeverity == severity ? AppTheme.info : AppTheme.grey700,
                                        fontWeight: _selectedSeverity == severity ? FontWeight.bold : FontWeight.normal,
                                      ),
                                      onSelected: (_) {
                                        setState(() => _selectedSeverity = severity);
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
                                size: 80,
                                color: AppTheme.success.withValues(alpha: 0.2),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'All clear! No alerts here.',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.grey800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Your inventory is fully stocked & healthy.',
                                style: TextStyle(color: AppTheme.grey500),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    final severityColor = _getSeverityColor(alert.severity);
    final daysColor = _getDaysRemainingColor(alert.daysUntilStockout);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with severity badge & Title
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
                          color: AppTheme.grey900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${alert.productId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    alert.severity.toUpperCase(),
                    style: TextStyle(
                      color: severityColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Main Info Block
            Row(
              children: [
                _buildMetricBlock(
                  'Current Stock',
                  '${alert.currentStock}',
                  Icons.inventory_2,
                  AppTheme.info,
                ),
                _buildMetricBlock(
                  'Daily Velocity',
                  '${alert.averageDailySales.toStringAsFixed(1)} /day',
                  Icons.trending_up,
                  AppTheme.info,
                ),
                _buildMetricBlock(
                  _tabController.index == 1 ? 'Days Left' : 'Min Required',
                  _tabController.index == 1 ? '${alert.daysUntilStockout} days' : '${alert.minimumStock}',
                  _tabController.index == 1 ? Icons.hourglass_bottom : Icons.warning_amber,
                  _tabController.index == 1 ? daysColor : AppTheme.warning,
                  boldText: _tabController.index == 1,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Smart Recommendation Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: AppTheme.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reorder ${alert.recommendedReorderQuantity} units to keep ${alert.recommendedStockDays > 0 ? alert.recommendedStockDays : 14} days safety buffer.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.info,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _dismissAlert(alert),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Dismiss'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.grey700,
                      side: const BorderSide(color: AppTheme.grey300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _reorderNow(alert),
                    icon: const Icon(Icons.local_shipping, size: 16),
                    label: const Text('Reorder Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.info,
                      foregroundColor: AppTheme.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
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

  Widget _buildMetricBlock(String label, String value, IconData icon, Color color, {bool boldText = false}) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.grey500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: boldText ? color : AppTheme.grey900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
