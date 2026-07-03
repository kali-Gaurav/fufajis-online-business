class SystemReadinessModel {
  final double workflowCoverage; // 0.0 - 100.0
  final double auditCoverage;
  final double offlineCoverage;
  final double permissionCoverage;
  final double testCoverage;

  final DateTime assessedAt;

  SystemReadinessModel({
    required this.workflowCoverage,
    required this.auditCoverage,
    required this.offlineCoverage,
    required this.permissionCoverage,
    required this.testCoverage,
    required this.assessedAt,
  });

  double get overallReadinessScore {
    return (workflowCoverage +
            auditCoverage +
            offlineCoverage +
            permissionCoverage +
            testCoverage) /
        5;
  }
}
