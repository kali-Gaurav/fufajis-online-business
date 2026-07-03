import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fulfillment_model.dart';

class FulfillmentProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<FulfillmentTask> _assignedOrders = [];
  FulfillmentTask? _currentTask;
  final List<String> _packedProductIds = [];
  EmployeeDailyStats? _todayStats;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<FulfillmentTask> get assignedOrders => _assignedOrders;
  FulfillmentTask? get currentTask => _currentTask;
  List<String> get packedProductIds => _packedProductIds;
  EmployeeDailyStats? get todayStats => _todayStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all assigned orders for an employee
  Future<void> loadAssignedOrders(String employeeId, String shopId, String branchId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final snapshot = await _db
          .collection('fulfillment_tasks')
          .where('employeeId', isEqualTo: employeeId)
          .where('shopId', isEqualTo: shopId)
          .where('branchId', isEqualTo: branchId)
          .where(
            'status',
            whereIn: [
              FulfillmentStatus.assigned.index,
              FulfillmentStatus.packing.index,
              FulfillmentStatus.ready.index,
            ],
          )
          .orderBy('createdAt', descending: true)
          .get();

      _assignedOrders = snapshot.docs
          .map((doc) => FulfillmentTask.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Stream assigned orders in real-time
  Stream<List<FulfillmentTask>> streamAssignedOrders(
    String employeeId,
    String shopId,
    String branchId,
  ) {
    return _db
        .collection('fulfillment_tasks')
        .where('employeeId', isEqualTo: employeeId)
        .where('shopId', isEqualTo: shopId)
        .where('branchId', isEqualTo: branchId)
        .where(
          'status',
          whereIn: [
            FulfillmentStatus.assigned.index,
            FulfillmentStatus.packing.index,
            FulfillmentStatus.ready.index,
          ],
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FulfillmentTask.fromMap({...doc.data(), 'id': doc.id}))
              .toList(),
        );
  }

  /// Start packing an order
  Future<void> startPacking(String taskId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final now = DateTime.now();
      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'status': FulfillmentStatus.packing.index,
        'startedAt': Timestamp.fromDate(now),
      });

      _currentTask = _currentTask?.copyWith(status: FulfillmentStatus.packing, startedAt: now);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Mark a single item as packed
  Future<void> markItemPacked(String taskId, String productId, double quantity) async {
    try {
      final task = _currentTask;
      if (task == null) throw Exception('No current task');

      // Update item in task
      final itemIndex = task.items.indexWhere((item) => item.productId == productId);
      if (itemIndex == -1) throw Exception('Item not found');

      task.items[itemIndex].packedQuantity = quantity;
      task.items[itemIndex].scannedAt = DateTime.now();

      // Update in Firestore
      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'items': task.items.map((i) => i.toMap()).toList(),
      });

      _packedProductIds.add(productId);
      _currentTask = task;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Verify an item (barcode scan)
  Future<void> verifyItem(String taskId, String productId) async {
    try {
      final task = _currentTask;
      if (task == null) throw Exception('No current task');

      final itemIndex = task.items.indexWhere((item) => item.productId == productId);
      if (itemIndex == -1) throw Exception('Item not found');

      task.items[itemIndex].verified = true;
      task.items[itemIndex].verifiedAt = DateTime.now();

      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'items': task.items.map((i) => i.toMap()).toList(),
        'itemsVerified': task.itemsVerified + 1,
      });

      _currentTask = task;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Complete packing for an order
  Future<void> completePacking(String taskId, {String? notes}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final now = DateTime.now();
      final startedAt = _currentTask?.startedAt ?? now;
      final totalSeconds = now.difference(startedAt).inSeconds;

      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'status': FulfillmentStatus.ready.index,
        'completedAt': Timestamp.fromDate(now),
        'totalTimeSeconds': totalSeconds,
        'notes': notes,
      });

      _currentTask = _currentTask?.copyWith(
        status: FulfillmentStatus.ready,
        completedAt: now,
        totalTimeSeconds: totalSeconds,
        notes: notes,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Start quality check
  Future<void> startQualityCheck(String taskId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'status': FulfillmentStatus.qualityChecked.index,
      });

      _currentTask = _currentTask?.copyWith(status: FulfillmentStatus.qualityChecked);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Approve quality check
  Future<void> approveQuality(String taskId, double qualityScore, String approvedBy) async {
    try {
      _isLoading = true;
      notifyListeners();

      final now = DateTime.now();
      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'status': FulfillmentStatus.completed.index,
        'qualityCheckedAt': Timestamp.fromDate(now),
        'qualityScore': qualityScore,
        'qualityCheckedBy': approvedBy,
      });

      _currentTask = _currentTask?.copyWith(
        status: FulfillmentStatus.completed,
        qualityCheckedAt: now,
        qualityScore: qualityScore,
        qualityCheckedBy: approvedBy,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Reject quality check
  Future<void> rejectQuality(String taskId, String reason, String rejectedBy) async {
    try {
      _isLoading = true;
      notifyListeners();

      final now = DateTime.now();
      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'status': FulfillmentStatus.rejected.index,
        'qualityCheckedAt': Timestamp.fromDate(now),
        'rejectionReason': reason,
        'qualityCheckedBy': rejectedBy,
        'qualityScore': 0,
      });

      _currentTask = _currentTask?.copyWith(
        status: FulfillmentStatus.rejected,
        qualityCheckedAt: now,
        rejectionReason: reason,
        qualityCheckedBy: rejectedBy,
        qualityScore: 0,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Get today's stats for employee
  Future<void> loadTodayStats(String employeeId, String shopId) async {
    try {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final snapshot = await _db
          .collection('employee_daily_stats')
          .doc('${employeeId}_$dateStr')
          .get();

      if (snapshot.exists) {
        _todayStats = EmployeeDailyStats.fromMap(snapshot.data()!);
      } else {
        _todayStats = EmployeeDailyStats(employeeId: employeeId, date: dateStr);
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Stream today's stats in real-time
  Stream<EmployeeDailyStats> streamTodayStats(String employeeId) {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return _db.collection('employee_daily_stats').doc('${employeeId}_$dateStr').snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists) {
        return EmployeeDailyStats.fromMap(snapshot.data()!);
      }
      return EmployeeDailyStats(employeeId: employeeId, date: dateStr);
    });
  }

  /// Update daily stats after completing a task
  Future<void> updateDailyStats(
    String employeeId,
    String shopId,
    FulfillmentTask completedTask,
  ) async {
    try {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final docId = '${employeeId}_$dateStr';

      final statsRef = _db.collection('employee_daily_stats').doc(docId);
      final snapshot = await statsRef.get();

      EmployeeDailyStats stats;
      if (snapshot.exists) {
        stats = EmployeeDailyStats.fromMap(snapshot.data()!);
      } else {
        stats = EmployeeDailyStats(employeeId: employeeId, date: dateStr);
      }

      stats.totalOrdersPacked += 1;
      stats.totalItemsPacked += completedTask.items.length;
      stats.totalTimeSeconds += completedTask.totalTimeSeconds;

      if (completedTask.status == FulfillmentStatus.completed) {
        stats.qualityChecksPassed += 1;
        stats.qualityScore =
            (stats.qualityScore * (stats.qualityChecksPassed - 1) + completedTask.qualityScore) /
            stats.qualityChecksPassed;
      } else if (completedTask.status == FulfillmentStatus.rejected) {
        stats.qualityChecksFailed += 1;
      }

      // Calculate efficiency (items packed per minute)
      if (stats.totalTimeSeconds > 0) {
        final minutesPassed = stats.totalTimeSeconds / 60;
        stats.efficiency = stats.totalItemsPacked / minutesPassed;
      }

      await statsRef.set(stats.toMap());
      _todayStats = stats;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Load a specific task by ID
  Future<FulfillmentTask?> loadTask(String taskId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _db.collection('fulfillment_tasks').doc(taskId).get();
      if (!snapshot.exists) {
        _currentTask = null;
        _isLoading = false;
        notifyListeners();
        return null;
      }

      _currentTask = FulfillmentTask.fromMap({...snapshot.data()!, 'id': snapshot.id});
      _isLoading = false;
      notifyListeners();
      return _currentTask;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Stream a specific task in real-time
  Stream<FulfillmentTask?> streamTask(String taskId) {
    return _db.collection('fulfillment_tasks').doc(taskId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return FulfillmentTask.fromMap({...snapshot.data()!, 'id': snapshot.id});
      }
      return null;
    });
  }

  /// Clear current task
  void clearCurrentTask() {
    _currentTask = null;
    _packedProductIds.clear();
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
