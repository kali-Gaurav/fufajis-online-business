import 'package:flutter/material.dart';
import 'package:fufajis_online/models/customer_models.dart';

/// Customer Segment Card Component
/// Displays customer segment with metrics and recommended actions
class CustomerSegmentCard extends StatefulWidget {
  final CustomerSegment segment;

  const CustomerSegmentCard({super.key, required this.segment});

  @override
  State<CustomerSegmentCard> createState() => _CustomerSegmentCardState();
}

class _CustomerSegmentCardState extends State<CustomerSegmentCard> {
  final bool _isExpanded = false;

  Color _getSegmentColor(String segmentType) {
    switch (segmentType) {
      case 'HIGH_VALUE':
        return Colors.amber;
      case 'NEW':
        return Colors.green;
      case 'REPEAT':
        return Colors.blue;
      case 'AT_RISK':
        return Colors.red;
      case 'ONE_TIME':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getSegmentIcon(String segmentType) {
    switch (segmentType) {
      case 'HIGH_VALUE':
        return '👑';
      case 'NEW':
        return '✨';
      case 'REPEAT':
        return '🔄';
      case 'AT_RISK':
        return '⚠️';
      case 'ONE_TIME':
        return '👤';
      default:
        return '❓';
    }
  }

  String _getSegmentLabel(String segmentType) {
    switch (segmentType) {
      case 'HIGH_VALUE':
        return 'High-Value Customers';
      case 'NEW':
        return 'New Customers';
      case 'REPEAT':
        return 'Repeat Customers';
      case 'AT_RISK':
        return 'At-Risk Customers';
      case 'ONE_TIME':
        return 'One-Time Buyers';
      default:
        return 'Unknown Segment';
    }
  }

  @override
  Widget build(BuildContext context) {
    final segment = widget.segment;
    final segmentColor = _getSegmentColor(segment.segmentType);
    final segmentIcon = _getSegmentIcon(segment.segmentType);
    final segmentLabel = _getSegmentLabel(segment.segmentType);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // ============ HEADER ============
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: segmentColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
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
                          Text(segmentIcon, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              segmentLabel,
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${segment.count} customers',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: segmentColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(segment.metrics.avgLifetimeValue / 1000).toStringAsFixed(1)}K avg LTV',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ============ KEY METRICS ============
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Metrics Grid
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.2,
                  children: [
                    _buildMetricTile(
                      context,
                      label: 'Avg LTV',
                      value: '₹${segment.metrics.avgLifetimeValue.toStringAsFixed(0)}',
                      color: Colors.blue,
                    ),
                    _buildMetricTile(
                      context,
                      label: 'Avg AOV',
                      value: '₹${segment.metrics.avgOrderValue.toStringAsFixed(0)}',
                      color: Colors.green,
                    ),
                    _buildMetricTile(
                      context,
                      label: 'Frequency',
                      value: '${segment.metrics.purchaseFrequency.toStringAsFixed(1)}/mo',
                      color: Colors.purple,
                    ),
                    _buildMetricTile(
                      context,
                      label: 'Retention',
                      value: '${(segment.metrics.retentionRate * 100).toStringAsFixed(0)}%',
                      color: Colors.orange,
                    ),
                    _buildMetricTile(
                      context,
                      label: 'Churn Risk',
                      value: '${(segment.metrics.churnRisk * 100).toStringAsFixed(0)}%',
                      color: Colors.red,
                    ),
                    _buildMetricTile(
                      context,
                      label: 'Total Revenue',
                      value: '₹${(segment.metrics.totalRevenue / 1000).toStringAsFixed(0)}K',
                      color: Colors.teal,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ============ RECOMMENDATIONS ============
          if (segment.recommendations.isNotEmpty)
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
                    children: [
                      const Icon(Icons.lightbulb_outline, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Recommended Actions',
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: segment.recommendations.asMap().entries.map((entry) {
                      final index = entry.key;
                      final rec = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < segment.recommendations.length - 1 ? 8 : 0,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rec['description'] ?? '',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  if (rec['priority'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: rec['priority'] == 'HIGH'
                                              ? Colors.red.shade100
                                              : Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          rec['priority'],
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: rec['priority'] == 'HIGH'
                                                ? Colors.red.shade700
                                                : Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // ============ ACTION BUTTON ============
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✅ Campaign queued for ${segment.count} ${segment.segmentType.toLowerCase()} customers',
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.mail_outline),
                label: const Text('Send Campaign'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey.shade700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
