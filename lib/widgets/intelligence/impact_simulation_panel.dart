import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class ImpactSimulationPanel extends StatelessWidget {
  final String actionTitle;
  final double estimatedCost;
  final double expectedRevenueImpact;
  final int stockCoverageDays;
  final double workingCapitalImpact;
  final String supplierDependencyRisk;
  final VoidCallback onApprove;
  final VoidCallback onCancel;

  const ImpactSimulationPanel({
    super.key,
    required this.actionTitle,
    required this.estimatedCost,
    required this.expectedRevenueImpact,
    required this.stockCoverageDays,
    required this.workingCapitalImpact,
    required this.supplierDependencyRisk,
    required this.onApprove,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: AppTheme.info),
              const SizedBox(width: 8),
              Text(
                'IMPACT SIMULATION: $actionTitle',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  'Estimated Cost',
                  '₹${estimatedCost.toStringAsFixed(0)}',
                  AppTheme.error,
                ),
              ),
              Expanded(
                child: _buildMetric(
                  'Expected Revenue',
                  '+₹${expectedRevenueImpact.toStringAsFixed(0)}',
                  AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  'Working Capital',
                  '${workingCapitalImpact < 0 ? "-" : "+"}₹${workingCapitalImpact.abs().toStringAsFixed(0)}',
                  AppTheme.warning,
                ),
              ),
              Expanded(
                child: _buildMetric('Stock Coverage', '$stockCoverageDays Days', AppTheme.info),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRiskBanner('Supplier Dependency', supplierDependencyRisk),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Approve Action'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.grey600,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildRiskBanner(String label, String content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(content, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
