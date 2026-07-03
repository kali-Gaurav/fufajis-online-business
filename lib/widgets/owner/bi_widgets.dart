import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../utils/app_theme.dart';
import '../../providers/business_intelligence_provider.dart';

final NumberFormat kInr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

String compactInr(double v) {
  if (v.abs() >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
  if (v.abs() >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
  if (v.abs() >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
  return '₹${v.toStringAsFixed(0)}';
}

/// Segmented date-range selector wired to [BusinessIntelligenceProvider].
class BiRangeSelector extends StatelessWidget {
  final BiRange selected;
  final ValueChanged<BiRange> onSelected;
  const BiRangeSelector({super.key, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const ranges = [BiRange.today, BiRange.week, BiRange.month, BiRange.quarter, BiRange.year];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ranges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final r = ranges[i];
          final active = r == selected;
          return GestureDetector(
            onTap: () => onSelected(r),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: active ? AppTheme.primary : AppTheme.grey100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                r.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppTheme.grey700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Small percentage delta chip (green up / red down).
class BiGrowthChip extends StatelessWidget {
  final double pct;
  const BiGrowthChip({super.key, required this.pct});

  @override
  Widget build(BuildContext context) {
    final up = pct >= 0;
    final color = up ? AppTheme.success : AppTheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '${pct.abs().toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

/// Headline KPI tile with optional growth delta.
class BiKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? growth;
  final String? subtitle;

  const BiKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.growth,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (growth != null) BiGrowthChip(pct: growth!),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: TextStyle(fontSize: 11, color: color)),
          ],
        ],
      ),
    );
  }
}

/// Card wrapper with a section title and a chart/content body.
class BiSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const BiSectionCard({super.key, required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

/// Palette cycled through chart segments.
const List<Color> kBiPalette = [
  AppTheme.primary,
  AppTheme.info,
  AppTheme.success,
  AppTheme.warning,
  Color(0xFF9C27B0),
  Color(0xFF00BCD4),
  Color(0xFFE91E63),
  Color(0xFF795548),
];

/// Builds a donut chart from a label→value map.
class BiDonutChart extends StatelessWidget {
  final Map<String, double> data;
  final double height;
  const BiDonutChart({super.key, required this.data, this.height = 180});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No data', style: TextStyle(color: AppTheme.grey500)),
        ),
      );
    }
    final total = data.values.fold(0.0, (a, b) => a + b);
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final sections = <PieChartSectionData>[];
    for (var i = 0; i < entries.length; i++) {
      final pct = total > 0 ? (entries[i].value / total) * 100 : 0;
      sections.add(
        PieChartSectionData(
          value: entries[i].value,
          color: kBiPalette[i % kBiPalette.length],
          title: pct >= 6 ? '${pct.toStringAsFixed(0)}%' : '',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: height,
          child: PieChart(
            PieChartData(sections: sections, sectionsSpace: 2, centerSpaceRadius: 36),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (var i = 0; i < entries.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: kBiPalette[i % kBiPalette.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entries[i].key,
                    style: const TextStyle(fontSize: 11, color: AppTheme.grey700),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Smooth area line chart from a numeric series.
class BiLineChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;
  const BiLineChart({
    super.key,
    required this.values,
    this.color = AppTheme.primary,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No data', style: TextStyle(color: AppTheme.grey500)),
        ),
      );
    }
    final spots = <FlSpot>[for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])];
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vertical bar chart from a label→value map (counts or amounts).
class BiBarChart extends StatelessWidget {
  final Map<String, double> data;
  final Color color;
  final double height;
  const BiBarChart({
    super.key,
    required this.data,
    this.color = AppTheme.primary,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No data', style: TextStyle(color: AppTheme.grey500)),
        ),
      );
    }
    final entries = data.entries.toList();
    final maxV = entries.map((e) => e.value).fold(0.0, (a, b) => a > b ? a : b);
    final groups = <BarChartGroupData>[
      for (var i = 0; i < entries.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: entries[i].value,
              color: color,
              width: 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
    ];
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxV * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      entries[i].key,
                      style: const TextStyle(fontSize: 9, color: AppTheme.grey600),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: groups,
        ),
      ),
    );
  }
}
