import 'package:flutter/material.dart';

/// Optimized metric card with better performance and memory management
class OptimizedMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final double? percentageChange;
  final bool isPositive;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const OptimizedMetricCard({
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
    return _MetricCardBody(
      label: label,
      value: value,
      subtitle: subtitle,
      icon: icon,
      iconColor: iconColor,
      percentageChange: percentageChange,
      isPositive: isPositive,
      onTap: onTap,
      backgroundColor: backgroundColor,
    );
  }
}

class _MetricCardBody extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final double? percentageChange;
  final bool isPositive;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const _MetricCardBody({
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.percentageChange,
    required this.isPositive,
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ?? (isDark ? Colors.grey[850] : Colors.grey[50]);
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[200]!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderRow(
              label: label,
              isDark: isDark,
              icon: icon,
              iconColor: iconColor,
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (subtitle != null || percentageChange != null)
              _BottomRow(
                subtitle: subtitle,
                percentageChange: percentageChange,
                isPositive: isPositive,
                isDark: isDark,
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final String label;
  final bool isDark;
  final IconData? icon;
  final Color? iconColor;

  const _HeaderRow({
    required this.label,
    required this.isDark,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _BottomRow extends StatelessWidget {
  final String? subtitle;
  final double? percentageChange;
  final bool isPositive;
  final bool isDark;

  const _BottomRow({
    required this.subtitle,
    required this.percentageChange,
    required this.isPositive,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (subtitle != null)
            Expanded(
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
              ),
            ),
          if (percentageChange != null)
            _PercentageBadge(
              percentageChange: percentageChange!,
              isPositive: isPositive,
            ),
        ],
      ),
    );
  }
}

class _PercentageBadge extends StatelessWidget {
  final double percentageChange;
  final bool isPositive;

  const _PercentageBadge({
    required this.percentageChange,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isPositive
        ? Colors.green.withOpacity(0.1)
        : Colors.red.withOpacity(0.1);
    final textColor = isPositive ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${isPositive ? '+' : '-'}${percentageChange.toStringAsFixed(1)}%',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
