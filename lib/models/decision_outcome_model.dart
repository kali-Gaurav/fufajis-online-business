class DecisionOutcomeModel {
  final String id;
  final String recommendationId; // Link to AiRecommendation
  final String decisionRole; // Who made the decision
  final DateTime decidedAt;

  // Execution
  final String executionStatus; // pending, executed, failed
  final DateTime? executedAt;

  // Outcome
  final String measuredOutcome; // e.g., 'Stockout Avoided'
  final double businessValueImpact; // e.g., Revenue saved
  final bool successful;

  DecisionOutcomeModel({
    required this.id,
    required this.recommendationId,
    required this.decisionRole,
    required this.decidedAt,
    this.executionStatus = 'pending',
    this.executedAt,
    required this.measuredOutcome,
    required this.businessValueImpact,
    required this.successful,
  });
}
