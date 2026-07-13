import 'package:flutter/material.dart';
import '../../models/daily_briefing_model.dart';
import 'package:intl/intl.dart';

import '../../utils/app_theme.dart';

class DailyBriefingUI extends StatelessWidget {
  final DailyBriefingModel briefing;
  final VoidCallback onDismiss;

  const DailyBriefingUI({super.key, required this.briefing, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    if (briefing.isRead) {
      return const SizedBox.shrink(); // Hide if already read
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.info, AppTheme.info],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.info.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.wb_sunny, color: Colors.yellow, size: 24),
                    SizedBox(width: 8),
                    Text(
                      "Today's Briefing",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(briefing.date),
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Metrics Row
            if (briefing.metrics.isNotEmpty) ...[
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: briefing.metrics.entries
                    .map((e) => _buildMetric(e.key, e.value.toString()))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Urgent Action Items
            if (briefing.urgentActionItems.isNotEmpty) ...[
              const Text(
                'URGENT ACTIONS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              ...briefing.urgentActionItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        item,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Insights
            if (briefing.insights.isNotEmpty) ...[
              const Text(
                'AI INSIGHTS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              ...briefing.insights.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.yellowAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Acknowledge Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.info,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Acknowledge'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    // Basic human-readable formatter for camelCase keys
    final formattedLabel = label
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}')
        .trim();
    final capitalizedLabel = formattedLabel[0].toUpperCase() + formattedLabel.substring(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          capitalizedLabel,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
