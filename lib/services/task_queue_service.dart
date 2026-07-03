import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_queue_model.dart';
import 'operational_health_engine.dart';

class TaskQueueService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final OperationalHealthEngine _healthEngine = OperationalHealthEngine();

  // Create a new task in the universal work queue
  Future<void> createTask(TaskQueueModel task) async {
    await _db.collection('work_queue').doc(task.id).set(task.toMap());
  }

  // Stream tasks for a specific role or branch
  Stream<List<TaskQueueModel>> streamTasks({
    String? assignedTo,
    String? assignedRole,
    String? branchId,
  }) {
    Query query = _db.collection('work_queue').where('status', isEqualTo: 'pending');

    if (assignedTo != null) {
      query = query.where('assignedTo', isEqualTo: assignedTo);
    }
    if (assignedRole != null) {
      query = query.where('assignedRole', isEqualTo: assignedRole);
    }
    if (branchId != null) {
      query = query.where('branchId', isEqualTo: branchId);
    }

    return query.snapshots().map((snapshot) {
      final tasks = snapshot.docs
          .map((doc) => TaskQueueModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Calculate dynamic priority score
      for (var task in tasks) {
        task.priorityScore = _healthEngine.calculatePriorityScore(task);
      }

      // Sort by priority score descending
      tasks.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
      return tasks;
    });
  }

  // Resolve a task
  Future<void> resolveTask(String taskId) async {
    await _db.collection('work_queue').doc(taskId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  // Escalate a task
  Future<void> escalateTask(String taskId) async {
    await _db.collection('work_queue').doc(taskId).update({
      'escalated': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
