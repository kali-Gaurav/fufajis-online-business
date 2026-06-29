enum InvestigationStatus {
  open,
  in_progress,
  concluded,
  resolved,
}

class InvestigationModel {
  final String id;
  final String title;
  final String anomalyDetected; // What triggered this
  final String assignedRole; // e.g. Branch Manager, Owner
  
  // Workflow
  final List<String> evidenceAttached; // Links/URIs to logs or graphs
  final String? conclusion;
  final String? resolution;
  
  final InvestigationStatus status;
  final DateTime openedAt;
  final DateTime? closedAt;

  InvestigationModel({
    required this.id,
    required this.title,
    required this.anomalyDetected,
    required this.assignedRole,
    required this.evidenceAttached,
    this.conclusion,
    this.resolution,
    this.status = InvestigationStatus.open,
    required this.openedAt,
    this.closedAt,
  });
}
