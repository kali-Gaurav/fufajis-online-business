import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// A card widget to display Key Performance Indicator (KPI) metrics
/// Shows title, value, unit, change percentage, and trend
class KPICard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final double? changePercent;
  final bool isPositive;
  final IconData icon;
  final Color? backgroundColor;
  final Color? accentColor;
  final List<double>? sparklineData;
  final VoidCallback? onTap;

  const KPICard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    this.changePercent,
    this.isPositive = true,
    required this.icon,
    this.backgroundColor,
    this.accentColor,
    this.sparklineData,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.white;
    final accentCol = accentColor ?? (isPositive ? AppTheme.success : AppTheme.error);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: bgColor,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with title and icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentCol.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: accentCol, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Main value
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Change indicator
              if (changePercent != null)
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      color: accentCol,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${changePercent!.abs().toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: accentCol,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'vs yesterday',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),

              // Sparkline (if data provided)
              if (sparklineData != null && sparklineData!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  height: 30,
                  color: Colors.transparent,
                  child: _MiniSparkline(data: sparklineData!, color: accentCol),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Mini sparkline chart for KPI card trend visualization
class _MiniSparkline extends StatelessWidget {
  final List<double> data;
  final Color color;

  const _MiniSparkline({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    return CustomPaint(
      painter: _SparklinePainter(
        data: data,
        color: color,
        maxValue: maxValue,
        minValue: minValue,
        range: range,
      ),
      size: const Size(double.infinity, 30),
    );
  }
}

/// Custom painter for sparkline visualization
class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double maxValue;
  final double minValue;
  final double range;

  _SparklinePainter({
    required this.data,
    required this.color,
    required this.maxValue,
    required this.minValue,
    required this.range,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();

    final xStep = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * xStep;
      final normalizedY = range > 0 ? (maxValue - data[i]) / range : 0;
      final y = normalizedY * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.color != color ||
        oldDelegate.maxValue != maxValue;
  }
}
