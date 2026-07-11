import 'package:flutter/material.dart';
import 'package:fufaji/models/analytics_models.dart';

class AlertWidget extends StatelessWidget {
  final Alert alert;
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;

  const AlertWidget({
    Key? key,
    required this.alert,
    this.onDismiss,
    this.onTap,
  }) : super(key: key);

  Color _getSeverityColor() {
    switch (alert.severity) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow[700]!;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getSeverityIcon() {
    switch (alert.severity) {
      case 'critical':
        return Icons.error;
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.info;
      case 'low':
        return Icons.info_outline;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final severityColor = _getSeverityColor();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: severityColor.withOpacity(0.1),
          border: Border.all(
            color: severityColor.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _getSeverityIcon(),
              color: severityColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getAlertTitle(),
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                        ),
                      ),
                      Text(
                        _formatTime(alert.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                  ),
                  if (alert.affectedEntity != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        alert.affectedEntity!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color:
                                  isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onDismiss != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(
                  Icons.close,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  size: 18,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getAlertTitle() {
    switch (alert.type) {
      case 'low_stock':
        return 'Low Stock Alert';
      case 'delivery_failure':
        return 'Delivery Failed';
      case 'customer_churn':
        return 'Customer Churn Risk';
      case 'quality_issue':
        return 'Quality Issue';
      case 'revenue_drop':
        return 'Revenue Drop';
      default:
        return 'Alert';
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
