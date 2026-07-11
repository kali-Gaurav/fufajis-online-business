import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final double? percentageChange;
  final bool isPositive;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const MetricCard({
    Key? key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.percentageChange,
    this.isPositive = true,
    this.onTap,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor ??
              (isDark ? Colors.grey[850] : Colors.grey[50]),
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
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                if (icon != null)
                  Icon(
                    icon,
                    color: iconColor ?? Colors.blue,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (subtitle != null || percentageChange != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (subtitle != null)
                    Expanded(
                      child: Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                      ),
                    ),
                  if (percentageChange != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${isPositive ? '+' : '-'}${percentageChange!.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: isPositive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
