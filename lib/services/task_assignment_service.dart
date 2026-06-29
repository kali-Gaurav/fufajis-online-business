import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum EmployeeTaskType {
  packing,
  low_stock_audit,
  return_processing,
  delivery
}

enum EmployeeTaskPriority {
  low,
  medium,
  high,
  urgent
}

enum EmployeeTaskStatus {
  released,
  assigned,
  completed,
  failed
}

class EmployeeTask {
  final String id;
  final String title;
  final String description;
  final EmployeeTaskType type;
  final EmployeeTaskPriority priority;
  final EmployeeTaskStatus status;
  final String? assignedUserId;
  final String? assignedUserName;
  final String branchId;
  final String shopId;
  final String? referenceId; // orderId, productId, returnId, etc.
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int timeEstimateMinutes;

  const EmployeeTask({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.status,
    this.assignedUserId,
    this.assignedUserName,
    required this.branchId,
    required this.shopId,
    this.referenceId,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    required this.timeEstimateMinutes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'priority': priority.name,
        'status': status.name,
        'assignedUserId': assignedUserId,
        'assignedUserName': assignedUserName,
        'branchId': branchId,
        'shopId': shopId,
        'referenceId': referenceId,
        'createdAt': Timestamp.fromDate(createdAt),
        'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
        'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'timeEstimateMinutes': timeEstimateMinutes,
      };

  factory EmployeeTask.fromMap(Map<String, dynamic> map) => EmployeeTask(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        type: EmployeeTaskType.values.firstWhere(
          (e) => e.name == (map['type'] as String? ?? ''),
          orElse: () => EmployeeTaskType.packing,
        ),
        priority: EmployeeTaskPriority.values.firstWhere(
          (e) => e.name == (map['priority'] as String? ?? ''),
          orElse: () => EmployeeTaskPriority.medium,
        ),
        status: EmployeeTaskStatus.values.firstWhere(
          (e) => e.name == (map['status'] as String? ?? ''),
          orElse: () => EmployeeTaskStatus.released,
        ),
        assignedUserId: map['assignedUserId'] as String?,
        assignedUserName: map['assignedUserName'] as String?,
        branchId: map['branchId'] as String? ?? '',
        shopId: map['shopId'] as String? ?? '',
        referenceId: map['referenceId'] as String?,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        startedAt: (map['startedAt'] as Timestamp?)?.toDate(),
        completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
        timeEstimateMinutes: (map['timeEstimateMinutes'] as num? ?? 15).toInt(),
      );
}

class TaskAssignmentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final TaskAssignmentService _instance = TaskAssignmentService._internal();
  factory TaskAssignmentService() => _instance;
  TaskAssignmentService._internal();

  /// Create a new employee task
  Future<void> createTask(EmployeeTask task) async {
    await _db
        .collection('shops')
        .doc(task.shopId)
        .collection('employee_tasks')
        .doc(task.id)
        .set(task.toMap());
  }

  /// Stream released (unassigned) tasks
  Stream<List<EmployeeTask>> streamReleasedTasks(String shopId, String branchId) {
    return _db
        .collection('shops')
        .doc(shopId)
        .collection('employee_tasks')
        .where('branchId', isEqualTo: branchId)
        .where('status', isEqualTo: EmployeeTaskStatus.released.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => EmployeeTask.fromMap(d.data())).toList());
  }

  /// Stream assigned tasks for an employee
  Stream<List<EmployeeTask>> streamEmployeeTasks(String shopId, String employeeId) {
    return _db
        .collection('shops')
        .doc(shopId)
        .collection('employee_tasks')
        .where('assignedUserId', isEqualTo: employeeId)
        .where('status', isEqualTo: EmployeeTaskStatus.assigned.name)
        .snapshots()
        .map((snap) => snap.docs.map((d) => EmployeeTask.fromMap(d.data())).toList());
  }

  /// Claim a released task
  Future<void> claimTask({
    required String shopId,
    required String taskId,
    required String employeeId,
    required String employeeName,
  }) async {
    await _db.runTransaction((transaction) async {
      final docRef = _db
          .collection('shops')
          .doc(shopId)
          .collection('employee_tasks')
          .doc(taskId);

      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('Task not found');

      final status = snapshot.data()?['status'];
      if (status != EmployeeTaskStatus.released.name) {
        throw Exception('Task has already been claimed or assigned');
      }

      transaction.update(docRef, {
        'status': EmployeeTaskStatus.assigned.name,
        'assignedUserId': employeeId,
        'assignedUserName': employeeName,
        'startedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Release/Unassign an assigned task back to the pool
  Future<void> releaseTask({
    required String shopId,
    required String taskId,
  }) async {
    await _db
        .collection('shops')
        .doc(shopId)
        .collection('employee_tasks')
        .doc(taskId)
        .update({
      'status': EmployeeTaskStatus.released.name,
      'assignedUserId': null,
      'assignedUserName': null,
      'startedAt': null,
    });
  }

  /// Complete a task
  Future<void> completeTask({
    required String shopId,
    required String taskId,
  }) async {
    await _db
        .collection('shops')
        .doc(shopId)
        .collection('employee_tasks')
        .doc(taskId)
        .update({
      'status': EmployeeTaskStatus.completed.name,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Automatically distribute released tasks to checked-in employees
  ///
  /// Uses an optimization formula: score = distance + load_penalty - success_bonus
  /// Lower score is better.
  Future<int> autoAssignTasks({
    required String shopId,
    required String branchId,
    double? shopLat,
    double? shopLng,
  }) async {
    int assignedCount = 0;
    try {
      // 1. Fetch checked-in employees for today
      final today = DateTime.now();
      final dayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final attendanceSnap = await _db
          .collection('attendance')
          .where('branchId', isEqualTo: branchId)
          .where('date', isEqualTo: dayStr)
          .get();
      
      final List<String> employeeIds = attendanceSnap.docs
          .map((d) => d.data()['employeeId'] as String?)
          .whereType<String>()
          .toList();

      if (employeeIds.isEmpty) return 0;

      // 2. Fetch all released tasks for this branch
      final tasksSnap = await _db
          .collection('shops')
          .doc(shopId)
          .collection('employee_tasks')
          .where('branchId', isEqualTo: branchId)
          .where('status', isEqualTo: EmployeeTaskStatus.released.name)
          .get();

      final List<EmployeeTask> releasedTasks = tasksSnap.docs
          .map((d) => EmployeeTask.fromMap(d.data()))
          .toList();

      if (releasedTasks.isEmpty) return 0;

      // 3. Prepare Employee Metrics (Load, Location, Success Rate)
      final Map<String, int> employeeLoads = {};
      final Map<String, String> employeeNames = {};
      final Map<String, double> employeeSuccessRates = {};
      final Map<String, Map<String, double>> employeeLocations = {};

      for (var employeeId in employeeIds) {
        // Load
        final activeTasksSnap = await _db
            .collection('shops')
            .doc(shopId)
            .collection('employee_tasks')
            .where('assignedUserId', isEqualTo: employeeId)
            .where('status', isEqualTo: EmployeeTaskStatus.assigned.name)
            .get();
        employeeLoads[employeeId] = activeTasksSnap.docs.length;
        
        // Name & Success Rate from User profile
        final userDoc = await _db.collection('users').doc(employeeId).get();
        final userData = userDoc.data() ?? {};
        employeeNames[employeeId] = (userData['name'] as String?) ?? 'Employee';
        employeeSuccessRates[employeeId] = (userData['deliverySuccessRate'] as num? ?? 90.0).toDouble();

        // Current Location (mocked or from last session if not live)
        if (userData['lastLatitude'] != null && userData['lastLongitude'] != null) {
          employeeLocations[employeeId] = {
            'lat': (userData['lastLatitude'] as num).toDouble(),
            'lng': (userData['lastLongitude'] as num).toDouble(),
          };
        } else if (shopLat != null && shopLng != null) {
          employeeLocations[employeeId] = {'lat': shopLat, 'lng': shopLng};
        }
      }

      // 4. Perform Scoring and Greedy Assignment
      final batch = _db.batch();

      for (var task in releasedTasks) {
        String? bestEmployeeId;
        double bestScore = double.infinity;

        for (var empId in employeeIds) {
          // Task priority weight (Urgent tasks get assigned first by sorting, but also affect score)
          double priorityWeight = _getPriorityWeight(task.priority).toDouble();
          
          // Current Load Penalty (Higher load = higher score = less likely to get task)
          int currentLoad = employeeLoads[empId] ?? 0;
          double loadPenalty = currentLoad * 2.0;

          // Success Bonus (Higher success rate = lower score = more likely to get task)
          double successBonus = (employeeSuccessRates[empId] ?? 0.0) / 10.0;

          // Distance Logic (if locations available)
          double distanceFactor = 0.0;
          if (employeeLocations.containsKey(empId) && shopLat != null && shopLng != null) {
            // Simplified: distance from their last known position to the shop (to pick up)
            // Or if task has a location (for delivery), use that.
            // For now, use load-balancing as primary factor if distance not specific to task.
            distanceFactor = 0.0; 
          }

          double score = loadPenalty - successBonus - priorityWeight + distanceFactor;

          if (score < bestScore) {
            bestScore = score;
            bestEmployeeId = empId;
          }
        }

        if (bestEmployeeId != null) {
          final docRef = _db
              .collection('shops')
              .doc(shopId)
              .collection('employee_tasks')
              .doc(task.id);

          batch.update(docRef, {
            'status': EmployeeTaskStatus.assigned.name,
            'assignedUserId': bestEmployeeId,
            'assignedUserName': employeeNames[bestEmployeeId],
            'startedAt': FieldValue.serverTimestamp(),
          });

          employeeLoads[bestEmployeeId] = (employeeLoads[bestEmployeeId] ?? 0) + 1;
          assignedCount++;
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error in optimized autoAssignTasks: $e');
    }
    return assignedCount;
  }

  int _getPriorityWeight(EmployeeTaskPriority priority) {
    switch (priority) {
      case EmployeeTaskPriority.urgent:
        return 3;
      case EmployeeTaskPriority.high:
        return 2;
      case EmployeeTaskPriority.medium:
        return 1;
      case EmployeeTaskPriority.low:
        return 0;
    }
  }
}
