import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fufaji/providers/inventory_provider.dart';
import 'package:fufaji/models/inventory_models.dart';
import 'package:fufaji/widgets/analytics/optimized_metric_card.dart';
import 'package:fufaji/utils/analytics_performance.dart';

/// Inventory Dashboard Screen
/// Displays real-time stock overview, alerts, and quick actions
class InventoryDashboardScreen extends StatefulWidget {
  const InventoryDashboardScreen({Key? key}) : super(key: key);

  @override
  State<InventoryDashboardScreen> createState() => _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends State<InventoryDashboardScreen> {
  late InventoryProvider _inventoryProvider;
  final List<Stream<dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _inventoryProvider = context.read<InventoryProvider>();
    _subscriptions.addAll([
      _inventoryProvider.watchMetrics().listen((_) => setState(() {})),
      _inventoryProvider.watchExpiryAlerts().listen((_) => setState(() {})),
    ]);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      // Streams handle their own lifecycle
    }
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await _inventoryProvider.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, inventoryProvider, child) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Loading state
                    if (inventoryProvider.isLoading && inventoryProvider.metrics == null)
                      const _LoadingState()
                    else if (inventoryProvider.error != null && inventoryProvider.metrics == null)
                      _ErrorState(error: inventoryProvider.error!, onRetry: _onRefresh)
                    else ...[
                      // KPI Cards
                      _KPICardsSection(inventoryProvider: inventoryProvider, isDark: isDark),
                      const SizedBox(height: 24),

                      // Critical Alerts
                      _CriticalAlertsSection(inventoryProvider: inventoryProvider, isDark: isDark),
                      const SizedBox(height: 24),

                      // Quick Actions
                      _QuickActionsSection(isDark: isDark, context: context),
                      const SizedBox(height: 24),

                      // Stock Status Summary
                      _StockStatusSection(inventoryProvider: inventoryProvider, isDark: isDark),
                      const SizedBox(height: 24),

                      // Reorder Suggestions
                      if (inventoryProvider.reorderSuggestions.isNotEmpty)
                        _ReorderSuggestionsSection(inventoryProvider: inventoryProvider, isDark: isDark),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// KPI Cards section
class _KPICardsSection extends StatelessWidget {
  final InventoryProvider inventoryProvider;
  final bool isDark;

  const _KPICardsSection({
    required this.inventoryProvider,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = inventoryProvider.metrics;

    if (metrics == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Inventory Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            OptimizedMetricCard(
              label: 'Stock Value',
              value: metrics.totalStockValueFormatted,
              icon: Icons.inventory_2,
              iconColor: Colors.blue,
              subtitle: '${metrics.totalItemsInStock} items',
            ),
            OptimizedMetricCard(
              label: 'Low Stock',
              value: inventoryProvider.lowStockCount.toString(),
              icon: Icons.warning,
              iconColor: Colors.orange,
              subtitle: 'Needs attention',
            ),
            OptimizedMetricCard(
              label: 'Out of Stock',
              value: inventoryProvider.outOfStockCount.toString(),
              icon: Icons.remove_circle,
              iconColor: Colors.red,
              subtitle: 'Critical!',
            ),
            OptimizedMetricCard(
              label: 'Expiring Soon',
              value: inventoryProvider.expiringCount.toString(),
              icon: Icons.schedule,
              iconColor: Colors.deepOrange,
              subtitle: '< 7 days',
            ),
          ],
        ),
      ],
    );
  }
}

// Critical alerts section
class _CriticalAlertsSection extends StatelessWidget {
  final InventoryProvider inventoryProvider;
  final bool isDark;

  const _CriticalAlertsSection({
    required this.inventoryProvider,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final criticalAlerts = <String>[];

    if (inventoryProvider.outOfStockCount > 0) {
      criticalAlerts.add('⚠️ ${inventoryProvider.outOfStockCount} items out of stock');
    }

    if (inventoryProvider.expiringCount > 0) {
      criticalAlerts.add('⏰ ${inventoryProvider.expiringCount} items expiring within 7 days');
    }

    if (inventoryProvider.reorderSuggestions
        .where((r) => r.needsReorder)
        .isNotEmpty) {
      criticalAlerts.add('📦 ${inventoryProvider.reorderSuggestions.where((r) => r.needsReorder).length} items need reordering');
    }

    if (criticalAlerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Critical Alerts',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          ...criticalAlerts.map((alert) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              alert,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.red[200] : Colors.red[700],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// Quick actions section
class _QuickActionsSection extends StatelessWidget {
  final bool isDark;
  final BuildContext context;

  const _QuickActionsSection({required this.isDark, required this.context});

  void _handleAction(String action) {
    switch (action) {
      case 'adjustment':
        context.push('/owner/inventory');
        break;
      case 'count':
        context.push('/owner/inventory');
        break;
      case 'po':
        _showNewPOModal(context);
        break;
      case 'suppliers':
        context.push('/inventory/suppliers');
        break;
    }
  }

  void _showNewPOModal(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('New Purchase Order'),
        content: const Text(
          'Select a supplier to create a new purchase order',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/inventory/suppliers');
            },
            child: const Text('View Suppliers'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2,
          children: [
            _ActionButton(
              label: 'Manual Adjustment',
              icon: Icons.edit,
              onPressed: () => _handleAction('adjustment'),
            ),
            _ActionButton(
              label: 'Stock Count',
              icon: Icons.playlist_add_check,
              onPressed: () => _handleAction('count'),
            ),
            _ActionButton(
              label: 'New Purchase Order',
              icon: Icons.add_shopping_cart,
              onPressed: () => _handleAction('po'),
            ),
            _ActionButton(
              label: 'View Suppliers',
              icon: Icons.people,
              onPressed: () => _handleAction('suppliers'),
            ),
          ],
        ),
      ],
    );
  }
}

// Stock status section
class _StockStatusSection extends StatelessWidget {
  final InventoryProvider inventoryProvider;
  final bool isDark;

  const _StockStatusSection({
    required this.inventoryProvider,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                'Stock Status',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Updated ${inventoryProvider.metrics?.lastUpdatedFormatted ?? "recently"}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StatusRow(
            label: 'In Stock',
            value: '${inventoryProvider.metrics?.totalItemsInStock ?? 0}',
            valueColor: Colors.green,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            label: 'Low Stock',
            value: inventoryProvider.lowStockCount.toString(),
            valueColor: Colors.orange,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            label: 'Out of Stock',
            value: inventoryProvider.outOfStockCount.toString(),
            valueColor: Colors.red,
          ),
        ],
      ),
    );
  }
}

// Reorder suggestions section
class _ReorderSuggestionsSection extends StatelessWidget {
  final InventoryProvider inventoryProvider;
  final bool isDark;

  const _ReorderSuggestionsSection({
    required this.inventoryProvider,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final needsReorder = inventoryProvider.reorderSuggestions
        .where((r) => r.needsReorder)
        .toList();

    if (needsReorder.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recommended Reorders',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${needsReorder.length} items',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...needsReorder.take(3).map((suggestion) => _ReorderCard(
          suggestion: suggestion,
          isDark: isDark,
        )),
        if (needsReorder.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'View all ${needsReorder.length} reorder suggestions →',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

// Helper widgets
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Colors.blue),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatusRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ReorderCard extends StatelessWidget {
  final ReorderSuggestion suggestion;
  final bool isDark;

  const _ReorderCard({
    required this.suggestion,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggestion.productName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current: ${suggestion.currentStock} → Order: ${suggestion.reorderQuantity}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              Text(
                suggestion.estimatedCostFormatted,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading inventory data...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading inventory',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
