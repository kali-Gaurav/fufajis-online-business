import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class PieChartWidget extends StatefulWidget {
  final String title;
  final Map<String, double> data;
  final List<Color>? colors;
  final bool showLegend;

  const PieChartWidget({
    Key? key,
    required this.title,
    required this.data,
    this.colors,
    this.showLegend = true,
  }) : super(key: key);

  @override
  State<PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<PieChartWidget> {
  int? touchedIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.data.isEmpty) {
      return _buildEmptyState(context, isDark);
    }

    final colors = widget.colors ??
        [
          Colors.blue,
          Colors.green,
          Colors.orange,
          Colors.red,
          Colors.purple,
          Colors.cyan,
          Colors.pink,
          Colors.amber,
        ];

    final entries = widget.data.entries.toList();
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);

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
            widget.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: List.generate(
                  entries.length,
                  (index) {
                    final isSelected = index == touchedIndex;
                    final entry = entries[index];
                    final percentage = (entry.value / total * 100);

                    return PieChartSectionData(
                      value: entry.value,
                      title: '${percentage.toStringAsFixed(1)}%',
                      color: colors[index % colors.length],
                      radius: isSelected ? 80 : 60,
                      titleStyle: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    );
                  },
                ),
                sectionsSpace: 2,
                centerSpaceRadius: 0,
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteraction) {
                        touchedIndex = -1;
                        return;
                      }
                      touchedIndex =
                          pieTouchResponse?.touchedSection?.touchedSectionIndex;
                    });
                  },
                ),
              ),
            ),
          ),
          if (widget.showLegend) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: List.generate(
                entries.length,
                (index) {
                  final entry = entries[index];
                  final percentage = (entry.value / total * 100);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors[index % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${entry.key} (${percentage.toStringAsFixed(1)}%)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
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
            widget.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 60),
          Icon(
            Icons.pie_chart,
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
