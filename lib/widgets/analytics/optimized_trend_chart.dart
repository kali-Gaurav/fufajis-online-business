import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fufaji/models/analytics_models.dart';
import 'package:fufaji/utils/analytics_performance.dart';

/// Optimized trend chart with improved performance
class OptimizedTrendChart extends StatelessWidget {
  final String title;
  final List<ChartDataPoint> data;
  final Color? lineColor;
  final Color? gradientStartColor;
  final Color? gradientEndColor;
  final String? yAxisLabel;
  final double? maxY;
  final bool showGrid;
  final int maxDataPoints;

  const OptimizedTrendChart({
    Key? key,
    required this.title,
    required this.data,
    this.lineColor,
    this.gradientStartColor,
    this.gradientEndColor,
    this.yAxisLabel,
    this.maxY,
    this.showGrid = true,
    this.maxDataPoints = 50,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final optimizedData = AnalyticsPerformance.optimizeChartData(
      data,
      maxPoints: maxDataPoints,
    );

    if (optimizedData.isEmpty) {
      return _EmptyChart(title: title, isDark: isDark);
    }

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
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _TrendChartBody(
              data: optimizedData,
              lineColor: lineColor ?? Colors.blue,
              gradientStartColor: gradientStartColor,
              gradientEndColor: gradientEndColor,
              maxY: maxY,
              showGrid: showGrid,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String title;
  final bool isDark;

  const _EmptyChart({
    required this.title,
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
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 60),
          Icon(
            Icons.show_chart,
            size: 48,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No data available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }
}

class _TrendChartBody extends StatelessWidget {
  final List<ChartDataPoint> data;
  final Color lineColor;
  final Color? gradientStartColor;
  final Color? gradientEndColor;
  final double? maxY;
  final bool showGrid;
  final bool isDark;

  const _TrendChartBody({
    required this.data,
    required this.lineColor,
    this.gradientStartColor,
    this.gradientEndColor,
    this.maxY,
    required this.showGrid,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = maxY ?? _calculateMaxY();
    final interval = _calculateInterval(maxValue);
    final xInterval = _calculateXInterval();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: showGrid,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.length) {
                  return Text(
                    data[index].label ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
            bottom: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
        ),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxValue,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              data.length,
              (index) => FlSpot(index.toDouble(), data[index].y),
            ),
            isCurved: true,
            color: lineColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: data.length <= 20,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: lineColor,
                  strokeWidth: 0,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  gradientStartColor ?? lineColor.withOpacity(0.3),
                  gradientEndColor ?? Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateMaxY() {
    if (data.isEmpty) return 100;
    return data.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.1;
  }

  double _calculateInterval(double maxValue) {
    if (maxValue <= 10) return 2;
    if (maxValue <= 50) return 10;
    if (maxValue <= 100) return 20;
    return 50;
  }

  double _calculateXInterval() {
    if (data.length <= 5) return 1;
    if (data.length <= 10) return 2;
    if (data.length <= 20) return 5;
    return (data.length / 5).ceilToDouble();
  }
}
