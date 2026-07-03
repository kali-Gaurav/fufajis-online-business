import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class ExplainableKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String trend; // e.g., '+5%' or '-2%'
  final bool isTrendPositive;
  final Map<String, String>
  contributors; // e.g., {'Late Deliveries': '+12', 'Traffic Delays': '+6'}
  final String recommendedAction;

  const ExplainableKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.trend,
    required this.isTrendPositive,
    required this.contributors,
    required this.recommendedAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.grey600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isTrendPositive ? AppTheme.success : AppTheme.error).withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isTrendPositive ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: isTrendPositive ? AppTheme.success : AppTheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trend,
                        style: TextStyle(
                          color: isTrendPositive ? AppTheme.success : AppTheme.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const Divider(height: 24),

            // Contributors
            const Text(
              'CONTRIBUTORS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.grey600),
            ),
            const SizedBox(height: 8),
            ...contributors.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 12)),
                    Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: e.value.startsWith('+') ? AppTheme.error : AppTheme.success,
                      ),
                    ), // Assuming + is bad for things like delays, but this logic can be parameterized. For simplicity, we just display it.
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RECOMMENDED ACTION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.info,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recommendedAction,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
