enum RecommendationStatus {
  pending,
  approved,
  rejected,
  investigating,
  ignored,
  executed,
}

class AiRecommendationModel {
  final String id;
  final String type; // Links to RecommendationRegistry
  final String entityType;
  final String entityId;
  
  // What
  final String recommendedAction;
  
  // Why
  final List<String> supportingFactors;
  
  // Confidence
  final double confidence; // 0.0 - 1.0
  
  // Impact & Risk
  final String expectedOutcome;
  final String potentialRisk;
  
  // Rollback
  final String rollbackStrategy;

  final RecommendationStatus status;
  final DateTime createdAt;

  AiRecommendationModel({
    required this.id,
    required this.type,
    required this.entityType,
    required this.entityId,
    required this.recommendedAction,
    required this.supportingFactors,
    required this.confidence,
    required this.expectedOutcome,
    required this.potentialRisk,
    required this.rollbackStrategy,
    this.status = RecommendationStatus.pending,
    required this.createdAt,
  });
}
