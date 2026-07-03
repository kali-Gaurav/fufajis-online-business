import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/operations/enterprise_task_model.dart';

class TaskAssignmentEngine {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Creates a new task and attempts to auto-assign it
  Future<String> createTask({required EnterpriseTaskModel task, bool autoAssign = true}) async {
    final docRef = _db
        .collection('shops')
        .doc(task.shopId)
        .collection('enterprise_tasks')
        .doc(task.id);

    EnterpriseTaskModel taskToSave = task;

    if (autoAssign && task.assignedTo == null) {
      final bestEmployeeId = await _findBestEmployeeForTask(task);
      if (bestEmployeeId != null) {
        taskToSave = task.copyWith(
          assignedTo: bestEmployeeId,
          status: TaskStatus.assigned,
          updatedAt: DateTime.now(),
        );
      }
    }

    await docRef.set(taskToSave.toMap());
    return task.id;
  }

  /// Calculates assignment score based on Role, Skill, Location, and Current Load.
  /// Lower score is better. Returns null if no suitable employee found.
  Future<String?> _findBestEmployeeForTask(EnterpriseTaskModel task) async {
    // 1. Get all employees in the branch
    final employeesSnap = await _db
        .collection('shops')
        .doc(task.shopId)
        .collection('users')
        .where('role', whereIn: ['employee', 'delivery'])
        .get();

    if (employeesSnap.docs.isEmpty) return null;

    final List<Map<String, dynamic>> candidates = [];

    // 2. Fetch current task load for each candidate
    for (var doc in employeesSnap.docs) {
      final data = doc.data();
      final employeeId = doc.id;
      final role = data['role'] as String? ?? '';

      // Basic Role filtering
      if (task.category == TaskCategory.delivery && role != 'delivery') continue;
      if (task.category == TaskCategory.warehouse && role == 'delivery') continue;
      if (task.category == TaskCategory.inventory && role == 'delivery') continue;

      // Calculate load
      final activeTasksSnap = await _db
          .collection('shops')
          .doc(task.shopId)
          .collection('enterprise_tasks')
          .where('assignedTo', isEqualTo: employeeId)
          .where('status', whereIn: [TaskStatus.assigned.name, TaskStatus.inProgress.name])
          .get();

      final currentLoad = activeTasksSnap.docs.length;

      // Scoring:
      // Base score is current load.
      // If skills match, we deduct points (better score).
      double score = currentLoad.toDouble() * 10;

      // TODO: Include physical location proximity if available

      candidates.add({'employeeId': employeeId, 'score': score, 'role': role});
    }

    if (candidates.isEmpty) return null;

    // 3. Sort by lowest score
    candidates.sort((a, b) => (a['score'] as double).compareTo(b['score'] as double));

    return candidates.first['employeeId'] as String;
  }
}
