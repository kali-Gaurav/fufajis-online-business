import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Data point for line chart
class LineChartData {
  final String label;
  final double value;

  LineChartData({
    required this.label,
    required this.value,
  });
}

/// A simple line chart widget for displaying trend data
class LineChartWidget extends StatefulWidget {
  final List<LineChartData> data;
  final String title;
  final String? yAxisLabel;
  final double height;
  final Color lineColor;
  final bool showPoints;
  final Function(int)? onPointTap;

  const LineChartWidget({
    super.key,
    required this.data,
    required this.title,
    this.yAxisLabel,
    this.height = 250,
    this.lineColor = AppTheme.info,
    this.showPoints = true,
    this.onPointTap,
  });

  @override
  State<LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<LineChartWidget> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: widget.height,
          child: CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: _LineChartPainter(
              data: widget.data,
              lineColor: widget.lineColor,
              selectedIndex: _selectedIndex,
              showPoints: widget.showPoints,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildXAxisLabels(),
      ],
    );
  }

  Widget _buildXAxisLabels() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(
          widget.data.length,
          (index) {
            final item = widget.data[index];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIndex = _selectedIndex == index ? null : index;
                });
                widget.onPointTap?.call(index);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _selectedIndex == index
                      ? widget.lineColor.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: _selectedIndex == index
                      ? Border.all(color: widget.lineColor)
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item.value.toStringAsFixed(0),
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Custom painter for line chart
class _LineChartPainter extends CustomPainter {
  final List<LineChartData> data;
  final Color lineColor;
  final int? selectedIndex;
  final bool showPoints;

  _LineChartPainter({
    required this.data,
    required this.lineColor,
    this.selectedIndex,
    required this.showPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxValue = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    final minValue = data.map((d) => d.value).reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    const padding = 40.0;
    final chartHeight = size.height - padding * 2;
    final chartWidth = size.width - padding * 2;

    // Draw axes
    final axisPaint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1;

    canvas.drawLine(
      const Offset(padding, padding),
      Offset(padding, size.height - padding),
      axisPaint,
    );

    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      axisPaint,
    );

    // Draw grid
    final gridPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 5; i++) {
      final y = padding + (chartHeight / 5) * i;

      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );

      // Y-axis labels
      final value = maxValue - (range / 5) * i;
      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toStringAsFixed(0),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(padding - 30, y - 5),
      );
    }

    // Draw line
    if (data.length > 1) {
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();

      for (int i = 0; i < data.length; i++) {
        final normalizedValue = range > 0
            ? (data[i].value - minValue) / range
            : 0;
        final x = padding + (chartWidth / (data.length - 1)) * i;
        final y = size.height - padding - (normalizedValue * chartHeight);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, linePaint);
    }

    // Draw area under line
    if (data.length > 1) {
      final areaPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill;

      final path = Path();

      for (int i = 0; i < data.length; i++) {
        final normalizedValue = range > 0
            ? (data[i].value - minValue) / range
            : 0;
        final x = padding + (chartWidth / (data.length - 1)) * i;
        final y = size.height - padding - (normalizedValue * chartHeight);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      // Close path to create area
      path.lineTo(
        padding + chartWidth,
        size.height - padding,
      );
      path.lineTo(padding, size.height - padding);
      path.close();

      canvas.drawPath(path, areaPaint);
    }

    // Draw points
    if (showPoints) {
      for (int i = 0; i < data.length; i++) {
        final normalizedValue = range > 0
            ? (data[i].value - minValue) / range
            : 0;
        final x = padding + (chartWidth / (data.length - 1)) * i;
        final y = size.height - padding - (normalizedValue * chartHeight);

        final pointPaint = Paint()
          ..color = selectedIndex == i ? lineColor : lineColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.fill;

        final radius = selectedIndex == i ? 6.0 : 4.0;
        canvas.drawCircle(Offset(x, y), radius, pointPaint);

        // Draw border
        if (selectedIndex == i) {
          final borderPaint = Paint()
            ..color = Colors.white
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke;

          canvas.drawCircle(Offset(x, y), radius, borderPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.selectedIndex != selectedIndex;
  }
}
