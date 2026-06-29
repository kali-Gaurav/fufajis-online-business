class BusinessMemoryModel {
  final String id;
  final String memoryType; // e.g., 'IncidentResolution', 'RecommendationOutcome'
  
  // Context
  final String description; // e.g., 'How we resolved Diwali surge delays'
  final String originalEntityId; // Link to the Incident or Recommendation
  
  // Memory
  final String whatWorked;
  final String whatFailed;
  final String extractedRule; // e.g., 'If Orders > 50/hr, preemptively reassign riders'

  final DateTime recordedAt;

  BusinessMemoryModel({
    required this.id,
    required this.memoryType,
    required this.description,
    required this.originalEntityId,
    required this.whatWorked,
    required this.whatFailed,
    required this.extractedRule,
    required this.recordedAt,
  });
}
