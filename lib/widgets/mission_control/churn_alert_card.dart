import 'package:flutter/material.dart';
import 'package:fufajis_online/models/customer_models.dart';

/// Churn Alert Card Component
/// Displays individual customer at-risk alert with suggested action
class ChurnAlertCard extends StatefulWidget {
  final ChurnAlert alert;
  final Function(String) onAction;

  const ChurnAlertCard({super.key, required this.alert, required this.onAction});

  @override
  State<ChurnAlertCard> createState() => _ChurnAlertCardState();
}

class _ChurnAlertCardState extends State<ChurnAlertCard> {
  final bool _isExpanded = false;

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'CRITICAL':
        return Colors.red;
      case 'AT_RISK':
        return Colors.orange;
      case 'LOW':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  String _getRiskIcon(String riskLevel) {
    switch (riskLevel) {
      case 'CRITICAL':
        return '🚨';
      case 'AT_RISK':
        return '⚠️';
      case 'LOW':
        return '📢';
      default:
        return '❓';
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final riskColor = _getRiskColor(alert.riskLevel);
    final riskIcon = _getRiskIcon(alert.riskLevel);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: alert.riskLevel == 'CRITICAL' ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: riskColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          // ============ HEADER ============
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(riskIcon, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customer At Churn Risk',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ID: ${alert.customerId}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: riskColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(alert.riskScore * 100).toStringAsFixed(0)}% Risk',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ============ CUSTOMER METRICS ============
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Metrics Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricCard(
                      context,
                      label: 'Lifetime Value',
                      value:
                          '₹${(alert.customerMetrics['lifetimeValue'] as num?)?.toStringAsFixed(0) ?? '0'}',
                      color: Colors.blue,
                    ),
                    _buildMetricCard(
                      context,
                      label: 'Total Purchases',
                      value: '${alert.customerMetrics['totalPurchases'] ?? 0}',
                      color: Colors.green,
                    ),
                    _buildMetricCard(
                      context,
                      label: 'Days Since Purchase',
                      value: '${alert.customerMetrics['daysSinceLastPurchase'] ?? 0}',
                      color: Colors.orange,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Reason
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Why they\'re at risk',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(alert.reason, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ============ SUGGESTED ACTION ============
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(top: BorderSide(color: Colors.blue.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Suggested Action',
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: alert.suggestedAction.priority == 'HIGH'
                            ? Colors.red.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        alert.suggestedAction.priority,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: alert.suggestedAction.priority == 'HIGH'
                              ? Colors.red.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  alert.suggestedAction.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (alert.suggestedAction.offerDetails.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: alert.suggestedAction.offerDetails.entries
                          .map(
                            (e) => Text(
                              '${e.key}: ${e.value}',
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(color: Colors.green.shade700),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ============ ACTION BUTTONS ============
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onAction('DISMISSED'),
                    icon: const Icon(Icons.close),
                    label: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      widget.onAction(alert.suggestedAction.type);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ ${alert.suggestedAction.type} initiated'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.send),
                    label: Text(
                      'Send ${alert.suggestedAction.type == 'WIN_BACK_EMAIL' ? 'Email' : 'Action'}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
