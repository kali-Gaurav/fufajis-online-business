import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/intelligence/explainable_ai_card.dart';
import '../../models/ai_recommendation_model.dart';
import '../../widgets/intelligence/impact_simulation_panel.dart';
import 'package:provider/provider.dart';
import '../../providers/operational_intelligence_provider.dart';

class ExecutiveDecisionCenter extends StatefulWidget {
  const ExecutiveDecisionCenter({super.key});

  @override
  State<ExecutiveDecisionCenter> createState() => _ExecutiveDecisionCenterState();
}

class _ExecutiveDecisionCenterState extends State<ExecutiveDecisionCenter> {
  final AiRecommendationModel _mockRecommendation = AiRecommendationModel(
    id: 'ai-001',
    type: 'Replenishment',
    entityType: 'Inventory',
    entityId: 'sku-rice-5kg',
    recommendedAction: 'Approve Replenishment of Rice 5kg (500 Units)',
    supportingFactors: [
      'Sales velocity increased by 24% over last 3 days',
      'Current stock covers only 2.3 days',
      'Supplier ABC lead time is 5 days',
    ],
    confidence: 0.91,
    expectedOutcome: 'Prevents predicted stockout on Friday. Retains approx ₹48k in revenue.',
    potentialRisk: 'Ties up ₹30k in working capital. High dependency on Supplier ABC.',
    rollbackStrategy: 'Cancel PO before dispatch (within 24 hours)',
    createdAt: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OperationalIntelligenceProvider>().initOwner();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OperationalIntelligenceProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: AppTheme.cream,
          appBar: AppBar(
            title: const Text(
              'Commerce OS Executive Center',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppTheme.ownerAccent,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // WHAT CHANGED?
                const Text(
                  'WHAT CHANGED?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.grey600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricDeltaCard('Revenue', '+6%', '₹2.45L', AppTheme.success),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricDeltaCard('Orders', '+11%', '842', AppTheme.success),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // WHY? (Root Cause Analysis summary)
                const Text(
                  'WHY?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.grey600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildWhyPanel(),
                const SizedBox(height: 24),

                // RISKS
                const Text(
                  'RISKS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(height: 12),
                _buildRiskItem('2 Branches Near Stockout', 'Sector 10, Sector 15'),
                _buildRiskItem('3 SLA Breaches', 'Sector 4 (HQ) Rider Capacity full'),
                const SizedBox(height: 24),

                // RECOMMENDATIONS
                const Text(
                  'RECOMMENDATIONS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                ExplainableAiCard(
                  recommendation: _mockRecommendation,
                  onApprove: () => _showImpactSimulation(context),
                  onReject: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Recommendation Rejected')));
                  },
                  onInvestigate: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Opening Investigation Panel')));
                  },
                ),
                const SizedBox(height: 24),

                // PENDING DECISIONS
                const Text(
                  'PENDING DECISIONS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.grey600,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.warning,
                      child: Text(
                        '${provider.ownerQueue.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: const Text(
                      'Approvals Waiting',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${provider.ownerQueue.length} pending items requiring executive review',
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Opening Pending Decisions Queue')),
                        );
                      },
                      child: const Text('Review All'),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricDeltaCard(String label, String delta, String value, Color deltaColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.grey600, fontSize: 12)),
              Text(
                delta,
                style: TextStyle(color: deltaColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWhyPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.ownerAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.ownerAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights, color: AppTheme.info, size: 20),
              SizedBox(width: 8),
              Text(
                'Primary Driver: Festival Campaign',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Higher repeat customer volume (+15%) observed in the last 24 hours directly correlated to push notifications sent yesterday.',
            style: TextStyle(color: Colors.grey[800], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskItem(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.05),
        border: const Border(left: BorderSide(color: AppTheme.error, width: 4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: AppTheme.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showImpactSimulation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: ImpactSimulationPanel(
            actionTitle: 'Purchase 500 Rice Units',
            estimatedCost: 30000,
            expectedRevenueImpact: 48000,
            stockCoverageDays: 21,
            workingCapitalImpact: -30000,
            supplierDependencyRisk: 'High dependence on Supplier A. Delay probability: 15%.',
            onApprove: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Action Approved & Executed. Tracking Outcome...')),
              );
            },
            onCancel: () => Navigator.pop(context),
          ),
        );
      },
    );
  }
}
