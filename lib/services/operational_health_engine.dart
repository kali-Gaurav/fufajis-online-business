import '../models/task_queue_model.dart';
import '../models/operational_health_model.dart';

class OperationalHealthEngine {
  /// Calculate the dynamic Priority Score for a Task Queue Item
  /// Score: 0-100
  /// Considers Urgency + Financial Impact + SLA Risk
  int calculatePriorityScore(TaskQueueModel task) {
    int score = 0;

    // 1. Base Urgency from Priority Enum
    switch (task.priority) {
      case TaskPriority.urgent:
        score += 40;
        break;
      case TaskPriority.high:
        score += 30;
        break;
      case TaskPriority.medium:
        score += 15;
        break;
      case TaskPriority.low:
        score += 5;
        break;
    }

    // 2. Escalation Multiplier
    if (task.escalated) {
      score += 20;
    }

    // 3. Task Type Impact
    switch (task.taskType) {
      case TaskQueueType.sla_breach_risk:
        score += 25;
        break;
      case TaskQueueType.delivery_incident:
        score += 30; // Direct customer impact
        break;
      case TaskQueueType.low_stock:
        score += 15; // Financial impact
        break;
      case TaskQueueType.pending_settlement:
        score += 10;
        break;
      case TaskQueueType.purchase_approval:
        score += 10;
        break;
      case TaskQueueType.pricing_approval:
        score += 15;
        break;
      default:
        break;
    }

    // 4. Due Date Proximity
    if (task.dueDate != null) {
      final now = DateTime.now();
      final diff = task.dueDate!.difference(now);
      if (diff.isNegative) {
        score += 30; // Overdue
      } else if (diff.inHours < 2) {
        score += 20; // Due very soon
      } else if (diff.inHours < 24) {
        score += 10; // Due today
      }
    }

    // Clamp score to 100
    return score.clamp(0, 100);
  }

  /// Calculates the Digital Twin Operational Health for a branch
  OperationalHealthModel calculateBranchHealth(
    String branchId, {
    required double inventoryHealth,
    required double deliveryHealth,
    required double employeeHealth,
    required double supplierHealth,
    required double customerHealth,
    required double financialHealth,
  }) {
    // In the future, this will be powered by real-time aggregation of metrics from Firestore
    return OperationalHealthModel(
      branchId: branchId,
      inventoryHealth: inventoryHealth,
      deliveryHealth: deliveryHealth,
      employeeHealth: employeeHealth,
      supplierHealth: supplierHealth,
      customerHealth: customerHealth,
      financialHealth: financialHealth,
      lastUpdated: DateTime.now(),
    );
  }
}
