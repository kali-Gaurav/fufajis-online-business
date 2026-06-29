import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/inventory_alert_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

/// Low Stock Alerts Card for Shopkeeper Dashboard
/// Displays critical and warning inventory alerts with quick reorder actions
class LowStockAlertsCard extends StatefulWidget {
  final String? shopId;

  const LowStockAlertsCard({
    super.key,
    this.shopId,
  });

  @override
  State<LowStockAlertsCard> createState() => _LowStockAlertsCardState();
}

class _LowStockAlertsCardState extends State<LowStockAlertsCard> {
  late InventoryAlertService _alertService;
  late String _activeShopId;

  @override
  void initState() {
    super.initState();
    _alertService = InventoryAlertService();

    // Get shop ID from widget parameter or from auth provider
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _activeShopId = widget.shopId ?? auth.currentShop?.id ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (_activeShopId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _alertService.getActiveAlerts(_activeShopId),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? [];

        if (!snapshot.hasData) {
          return _buildLoadingCard();
        }

        if (alerts.isEmpty) {
          return _buildHealthyCard();
        }

        // Separate critical and warning alerts
        final criticalAlerts = alerts.where((a) => (a['severity'] as num? ?? 0) >= 4).toList();
        final warningAlerts = alerts.where((a) => (a['severity'] as num? ?? 0) < 4).toList();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: criticalAlerts.isNotEmpty
                      ? AppTheme.error.withValues(alpha: 0.08)
                      : AppTheme.warning.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          criticalAlerts.isNotEmpty
                              ? Icons.priority_high
                              : Icons.warning_amber,
                          color: criticalAlerts.isNotEmpty
                              ? AppTheme.error
                              : AppTheme.warning,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              criticalAlerts.isNotEmpty
                                  ? 'Critical Stock Alert!'
                                  : 'Low Stock Warning',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: criticalAlerts.isNotEmpty
                                    ? AppTheme.error
                                    : AppTheme.warning,
                              ),
                            ),
                            Text(
                              '${alerts.length} item${alerts.length > 1 ? 's' : ''} need attention',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.grey600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: criticalAlerts.isNotEmpty
                            ? AppTheme.error
                            : AppTheme.warning,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${alerts.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Critical Alerts
              if (criticalAlerts.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'CRITICAL - Reorder Immediately (${criticalAlerts.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.error,
                    ),
                  ),
                ),
                ...criticalAlerts.map((alert) => _buildAlertItem(
                  alert,
                  isCritical: true,
                )),
              ],

              // Warning Alerts
              if (warningAlerts.isNotEmpty) ...[
                if (criticalAlerts.isNotEmpty)
                  const Divider(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'WARNING - Reorder Soon (${warningAlerts.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.warning,
                    ),
                  ),
                ),
                ...warningAlerts.map((alert) => _buildAlertItem(
                  alert,
                  isCritical: false,
                )),
              ],

              // Quick Actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showReorderDialog(context, alerts),
                        icon: const Icon(Icons.shopping_cart),
                        label: const Text('Create PO'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showContactSupplierDialog(context),
                        icon: const Icon(Icons.phone),
                        label: const Text('Contact'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.info,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertItem(
    Map<String, dynamic> alert, {
    required bool isCritical,
  }) {
    final currentStock = alert['currentStock'] as int? ?? 0;
    final daysUntilStockout = alert['daysUntilStockout'] as int? ?? 999;
    final dailyVelocity = alert['dailyVelocity'] as int? ?? 0;
    final recommendedQuantity = alert['reorderQuantity'] as int? ?? 0;
    final trend = alert['trend'] as String? ?? 'stable';

    Color statusColor = AppTheme.grey500;
    String statusLabel = 'Normal';

    if (isCritical) {
      statusColor = AppTheme.error;
      statusLabel = 'CRITICAL';
    } else if (daysUntilStockout <= 3) {
      statusColor = AppTheme.warning;
      statusLabel = 'WARNING';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(12),
        color: statusColor.withValues(alpha: 0.04),
      ),
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
                      (alert['productName'] as String?) ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (trend == 'increasing')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.info.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.trending_up,
                                  size: 12,
                                  color: AppTheme.info,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Trending Up',
                                  style: TextStyle(
                                    color: AppTheme.info,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$currentStock',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      'in stock',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildMetricBadge(
                  '${daysUntilStockout}d',
                  'Until Stockout',
                  daysUntilStockout <= 2 ? AppTheme.error : AppTheme.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricBadge(
                  '$dailyVelocity/d',
                  'Daily Sales',
                  AppTheme.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricBadge(
                  '+$recommendedQuantity',
                  'Recommend',
                  AppTheme.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBadge(
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: AppTheme.grey600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: const Center(
        child: SizedBox(
          height: 40,
          width: 40,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildHealthyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        border: Border.all(
          color: AppTheme.success.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.success,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory Healthy',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'All items are sufficiently stocked',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReorderDialog(
    BuildContext context,
    List<Map<String, dynamic>> alerts,
  ) {
    final recommendedOrders = alerts.map((alert) {
      return {
        'productName': alert['productName'],
        'quantity': alert['reorderQuantity'],
        'productId': alert['productId'],
      };
    }).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Purchase Order'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recommended restocking quantities:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...recommendedOrders.map((order) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        order['productName'] as String,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${order['quantity']} units',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PO created. Send to supplier via WhatsApp/Email'),
                ),
              );
            },
            child: const Text('Create PO'),
          ),
        ],
      ),
    );
  }

  void _showContactSupplierDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Supplier'),
        content: const Text(
          'Send restocking request to your supplier through:',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening WhatsApp...'),
                ),
              );
            },
            child: const Text('WhatsApp'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening Email...'),
                ),
              );
            },
            child: const Text('Email'),
          ),
        ],
      ),
    );
  }
}
