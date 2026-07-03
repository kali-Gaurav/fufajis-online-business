import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Data point for bar chart
class BarChartData {
  final String label;
  final double value;
  final Color color;

  BarChartData({required this.label, required this.value, this.color = AppTheme.info});
}

/// A simple bar chart widget for displaying comparative data
class BarChartWidget extends StatefulWidget {
  final List<BarChartData> data;
  final String title;
  final String? yAxisLabel;
  final double height;
  final bool showValues;
  final Function(int)? onBarTap;

  const BarChartWidget({
    super.key,
    required this.data,
    required this.title,
    this.yAxisLabel,
    this.height = 250,
    this.showValues = true,
    this.onBarTap,
  });

  @override
  State<BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<BarChartWidget> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return Center(child: Text('No data available', style: Theme.of(context).textTheme.bodySmall));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: widget.height,
          child: CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: _BarChartPainter(
              data: widget.data,
              selectedIndex: _selectedIndex,
              showValues: widget.showValues,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildXAxisLabels(),
      ],
    );
  }

  Widget _buildXAxisLabels() {
    // final maxValue = widget.data.isNotEmpty
    //     ? widget.data.map((d) => d.value).reduce((a, b) => a > b ? a : b)
    //     : 0.0; // Unused

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(widget.data.length, (index) {
          final item = widget.data[index];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = _selectedIndex == index ? null : index;
              });
              widget.onBarTap?.call(index);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _selectedIndex == index
                    ? item.color.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: _selectedIndex == index ? Border.all(color: item.color) : null,
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
                  if (widget.showValues)
                    Text(
                      item.value.toStringAsFixed(0),
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Custom painter for bar chart
class _BarChartPainter extends CustomPainter {
  final List<BarChartData> data;
  final int? selectedIndex;
  final bool showValues;

  _BarChartPainter({required this.data, this.selectedIndex, required this.showValues});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxValue = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    const padding = 40.0;
    final chartHeight = size.height - padding * 2;
    final chartWidth = size.width - padding * 2;
    final barWidth = chartWidth / data.length * 0.7;
    final spacing = chartWidth / data.length;

    // Draw Y-axis
    final axisPaint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1;

    canvas.drawLine(
      const Offset(padding, padding),
      Offset(padding, size.height - padding),
      axisPaint,
    );

    // Draw X-axis
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      axisPaint,
    );

    // Draw bars
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final barHeight = (item.value / maxValue) * chartHeight;
      final x = padding + (i * spacing) + (spacing - barWidth) / 2;
      // final y = size.height - padding - barHeight; // Unused

      final barPaint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;

      // Scale up selected bar
      final scaledHeight = selectedIndex == i ? barHeight * 1.05 : barHeight;
      final scaledY = size.height - padding - scaledHeight;

      // Draw bar with rounded top
      final barRect = RRect.fromLTRBR(
        x,
        scaledY,
        x + barWidth,
        size.height - padding,
        const Radius.circular(4),
      );

      canvas.drawRRect(barRect, barPaint);

      // Draw value on top of bar if enabled
      if (showValues) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: item.value.toStringAsFixed(0),
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x + (barWidth - textPainter.width) / 2, scaledY - 12));
      }
    }

    // Draw Y-axis labels
    final gridPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 5; i++) {
      final y = padding + (chartHeight / 5) * i;
      final value = maxValue * (1 - i / 5);

      // Draw grid line
      canvas.drawLine(Offset(padding, y), Offset(size.width - padding, y), gridPaint);

      // Draw label
      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toStringAsFixed(0),
          style: const TextStyle(color: Colors.grey, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(padding - 30, y - 5));
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.selectedIndex != selectedIndex;
  }
}
