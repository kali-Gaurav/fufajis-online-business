import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../models/ai_recommendation_model.dart';

class ExplainableAiCard extends StatelessWidget {
  final AiRecommendationModel recommendation;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onInvestigate;

  const ExplainableAiCard({
    super.key,
    required this.recommendation,
    required this.onApprove,
    required this.onReject,
    required this.onInvestigate,
  });

  @override
  Widget build(BuildContext context) {
    final confPercent = (recommendation.confidence * 100).toInt();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // WHAT
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          recommendation.recommendedAction,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(recommendation.confidence).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$confPercent% Confidence',
                    style: TextStyle(
                      color: _getConfidenceColor(recommendation.confidence),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // WHY
            const Text('WHY?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.grey600)),
            const SizedBox(height: 8),
            ...recommendation.supportingFactors.map((factor) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: AppTheme.grey600, fontWeight: FontWeight.bold)),
                  Expanded(child: Text(factor, style: TextStyle(color: Colors.grey[800]))),
                ],
              ),
            )),
            
            const SizedBox(height: 16),

            // IMPACT & RISK & ROLLBACK
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildInfoSection('EXPECTED IMPACT', recommendation.expectedOutcome, AppTheme.success),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoSection('POTENTIAL RISK', recommendation.potentialRisk, AppTheme.warning),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoSection('ROLLBACK PLAN', recommendation.rollbackStrategy, AppTheme.grey600),

            const SizedBox(height: 24),

            // ACTIONS
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: onInvestigate,
                    child: const Text('Investigate'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, String content, Color titleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: titleColor)),
        const SizedBox(height: 4),
        Text(content, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.90) return AppTheme.success;
    if (confidence >= 0.70) return AppTheme.info;
    if (confidence >= 0.50) return AppTheme.warning;
    return AppTheme.error;
  }
}
