import 'user_model.dart';

class RecommendationRegistryModel {
  final String id;
  final String type; // e.g., 'Inventory Replenishment'
  final UserRole ownerRole;
  final UserRole approvalRole;
  final String impactCategory; // e.g., 'Financial', 'Operational'
  final String standardRollbackProcedure;

  RecommendationRegistryModel({
    required this.id,
    required this.type,
    required this.ownerRole,
    required this.approvalRole,
    required this.impactCategory,
    required this.standardRollbackProcedure,
  });
}
