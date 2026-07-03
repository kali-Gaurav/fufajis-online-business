import 'package:flutter/material.dart';

/// Data point for pie chart
class PieChartData {
  final String label;
  final double value;
  final Color color;
  final String? percentage;

  PieChartData({required this.label, required this.value, required this.color, this.percentage});
}

/// A simple pie chart widget for displaying categorical data
class PieChartWidget extends StatefulWidget {
  final List<PieChartData> data;
  final String title;
  final double size;
  final bool showLegend;
  final Function(int)? onSegmentTap;

  const PieChartWidget({
    super.key,
    required this.data,
    required this.title,
    this.size = 200,
    this.showLegend = true,
    this.onSegmentTap,
  });

  @override
  State<PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<PieChartWidget> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return Center(child: Text('No data available', style: Theme.of(context).textTheme.bodySmall));
    }

    final total = widget.data.fold<double>(0, (sum, item) => sum + item.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Center(
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _PieChartPainter(
              data: widget.data,
              total: total,
              selectedIndex: _selectedIndex,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (widget.showLegend) _buildLegend(total),
      ],
    );
  }

  Widget _buildLegend(double total) {
    return Column(
      children: List.generate(widget.data.length, (index) {
        final item = widget.data[index];
        final percentage = total > 0 ? (item.value / total) * 100 : 0.0;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedIndex = _selectedIndex == index ? null : index;
            });
            widget.onSegmentTap?.call(index);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(item.label, style: Theme.of(context).textTheme.bodySmall)),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${item.value.toInt()})',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Custom painter for pie chart
class _PieChartPainter extends CustomPainter {
  final List<PieChartData> data;
  final double total;
  final int? selectedIndex;

  _PieChartPainter({required this.data, required this.total, this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    double startAngle = -3.14159 / 2; // Start from top

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final sweepAngle = (item.value / total) * 2 * 3.14159;

      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;

      // Scale up selected segment
      final scaledRadius = selectedIndex == i ? radius * 1.1 : radius;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: scaledRadius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Draw border
      final borderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: scaledRadius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_PieChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.selectedIndex != selectedIndex;
  }
}
