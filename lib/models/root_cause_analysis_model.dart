class RootCauseAnalysisModel {
  final String id;
  final String anomalyDetected; // e.g., 'Revenue Down 12%'

  // Root Cause
  final String primaryCause; // e.g., 'Rice Stockout'
  final double confidenceScore; // 0.0 - 100.0

  // Evidence
  final List<String> contributingFactors;
  final List<String> evidenceLinks; // Links to logs, events, data points

  final DateTime analyzedAt;

  RootCauseAnalysisModel({
    required this.id,
    required this.anomalyDetected,
    required this.primaryCause,
    required this.confidenceScore,
    required this.contributingFactors,
    required this.evidenceLinks,
    required this.analyzedAt,
  });
}
