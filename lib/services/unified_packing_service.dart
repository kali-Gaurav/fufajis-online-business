import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// UnifiedPackingService consolidates 3 packing workflows:
/// - PackingService v1 (legacy)
/// - PackingService v2 (modern)
/// - Orphaned workflow (integrated)
///
/// Unified status machine for fulfillment:
/// new → assigned → picking → quality_check → verified → completed
///   ↓
/// rejected (returns to new)
class UnifiedPackingService {
  static final UnifiedPackingService _instance = UnifiedPackingService._internal();
  factory UnifiedPackingService() => _instance;
  UnifiedPackingService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // final InventoryLedgerService _ledger = InventoryLedgerService(); // Unused

  // ──────────────────────────────────────────────────────────────
  // PACKING STATUS STATE MACHINE
  // ──────────────────────────────────────────────────────────────

  /// Unified packing workflow statuses
  static const Map<String, Set<String>> validTransitions = {
    'new': {'assigned'},
    'assigned': {'picking', 'rejected'},
    'picking': {'quality_check', 'rejected'},
    'quality_check': {'verified', 'rejected'},
    'verified': {'completed', 'rejected'},
    'completed': <String>{}, // Terminal
    'rejected': {'assigned'}, // Goes back for reassignment
  };

  static const Set<String> terminalStatuses = {'completed'};

  bool isTerminal(String status) => terminalStatuses.contains(status);

  bool canTransition(String from, String to) {
    if (from == to) return false;
    return validTransitions[from]?.contains(to) ?? false;
  }

  // ──────────────────────────────────────────────────────────────
  // FULFILLMENT TASK CREATION
  // ──────────────────────────────────────────────────────────────

  /// Create new fulfillment task from order
  Future<Map<String, dynamic>> createFulfillmentTask({
    required String orderId,
    required String shopId,
    required String branchId,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final now = DateTime.now();
      final taskRef = _db.collection('fulfillment_tasks').doc();
      final taskId = taskRef.id;

      final taskData = {
        'id': taskId,
        'orderId': orderId,
        'shopId': shopId,
        'branchId': branchId,
        'status': 'new',
        'items': items,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': [
          {'status': 'new', 'timestamp': Timestamp.fromDate(now)},
        ],
        'pickedItems': [],
        'verifiedItems': [],
      };

      await taskRef.set(taskData);

      // Update order with fulfillment task reference
      await _db.collection('orders').doc(orderId).update({
        'fulfillmentTaskId': taskId,
        'updatedAt': Timestamp.fromDate(now),
      });

      debugPrint('[UnifiedPackingService] Created fulfillment task $taskId for order $orderId');
      return taskData;
    } catch (e) {
      debugPrint('[UnifiedPackingService] Failed to create task: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // TASK ASSIGNMENT
  // ──────────────────────────────────────────────────────────────

  /// Assign fulfillment task to employee
  Future<void> assignToEmployee({
    required String taskId,
    required String employeeId,
    required String employeeName,
  }) async {
    try {
      await _transitionTask(
        taskId: taskId,
        toStatus: 'assigned',
        updates: {
          'assignedToEmployeeId': employeeId,
          'assignedToEmployeeName': employeeName,
          'assignedAt': Timestamp.fromDate(DateTime.now()),
        },
      );

      debugPrint('[UnifiedPackingService] Assigned task $taskId to employee $employeeId');
    } catch (e) {
      debugPrint('[UnifiedPackingService] Failed to assign task: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // PICKING WORKFLOW
  // ──────────────────────────────────────────────────────────────

  /// Start picking items for order
  Future<void> startPicking(String taskId) async {
    try {
      await _transitionTask(
        taskId: taskId,
        toStatus: 'picking',
        updates: {'pickingStartedAt': Timestamp.fromDate(DateTime.now())},
      );

      debugPrint('[UnifiedPackingService] Started picking for task $taskId');
    } catch (e) {
      debugPrint('[UnifiedPackingService] Failed to start picking: $e');
      rethrow;
    }
  }

  /// Mark item as picked
  Future<void> markItemPicked({
    required String taskId,
    required String itemId,
    required int quantity,
    String? batchNumber,
    String? expiryDate,
  }) async {
    try {
      final taskSnap = await _db.collection('fulfillment_tasks').doc(taskId).get();
      if (!taskSnap.exists) {
        throw Exception('Task not found: $taskId');
      }

      final taskData = taskSnap.data() as Map<String, dynamic>;
      final pickedItems = List<Map<String, dynamic>>.from((taskData['pickedItems'] as List?) ?? []);

      // Add to picked items
      pickedItems.add({
        'itemId': itemId,
        'quantity': quantity,
        'batchNumber': batchNumber,
        'expiryDate': expiryDate,
        'pickedAt': Timestamp.fromDate(DateTime.now()),
      });

      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'pickedItems': pickedItems,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('[UnifiedPackingService] Marked item $itemId picked in task $taskId');
    } catch (e) {
      debugPrint('[UnifiedPackingService] Failed to mark item picked: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // QUALITY CHECK
  // ──────────────────────────────────────────────────────────────

  /// Request quality check for packed items
  Future<void> requestQualityCheck(String taskId) async {
    try {
      await _transitionTask(
        taskId: taskId,
        toStatus: 'quality_check',
        updates: {'qualityCheckRequestedAt': Timestamp.fromDate(DateTime.now())},
      );

      debugPrint('[UnifiedPackingService] Requested QC for task $taskId');
    } catch (e) {
      debugPrint('[UnifiedPackingService] Failed to request QC: $e');
      rethrow;
    }
  }

  /// Mark item as verified (passed QC)
  Future<void> markItemVerified({
    required String taskId,
    required String itemId,
    String? notes,
  }) async {
    try {
      final taskSnap = await _db.collection('fulfillment_tasks').doc(taskId).get();
      if (!taskSnap.exists) {
        throw Exception('Task not found: $taskId');
      }

      final taskData = taskSnap.data() as Map<String, dynamic>;
      final verifiedItems = List<Map<String, dynamic>>.from(
        (taskData['verifiedItems'] as List?) ?? [],
      );

      verifiedItems.add({
        'itemId': itemId,
        'verifiedAt': Timestamp.fromDate(DateTime.now()),
        if (notes != null) 'notes': notes,
      });

      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'verifiedItems': verifiedItems,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('[UnifiedPackingService] Verified item $itemId in task $taskId');
    } catch (e) {
      debugPrint('[UnifiedPackingService] Failed to verify item: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // COMPLETION
  // ──────────────────────────────────────────────────────────────

  /// Complete fulfillment task - ready for shipment
  /// CRITICAL: This MUST have all items verified to prevent shipping incomplete orders
  Future<void> completePacking({required String taskId, String? packageTrackingNumber}) async {
    try {
      final taskSnap = await _db.collection('fulfillment_tasks').doc(taskId).get();
      if (!taskSnap.exists) {
        throw Exception('Task not found: $taskId');
      }

      final taskData = taskSnap.data() as Map<String, dynamic>;
      final items = taskData['items'] as List? ?? [];
      final verifiedItems = taskData['verifiedItems'] as List? ?? [];

      // Validation: all items must be verified before completion
      if (verifiedItems.length != items.length) {
        throw Exception(
          'Cannot complete: ${items.length - verifiedItems.length} items not verified',
        );
      }

      // Transition to completed (bypassing verified if needed for backward compat)
      final currentStatus = taskData['status'] as String;
      if (currentStatus == 'verified' || currentStatus == 'quality_check') {
        await _transitionTask(
          taskId: taskId,
          toStatus: 'completed',
          updates: {
            'packageTrackingNumber': packageTrackingNumber,
            'completedAt': Timestamp.fromDate(DateTime.now()),
          },
        );
      } else {
        throw Exception('Invalid status for completion: $currentStatus');
      }

      // Update order status to 'shipped'
      final orderId = taskData['orderId'] as String;
      await _db.collection('orders').doc(orderId).update({
        'status': 'shipped',
        'packageTrackingNumber': packageTrackingNumber,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('[UnifiedPackingService] Completed packing for task $taskId');
    } catch (e) {
      debugPrint('[UnifiedPackingService] Failed to complete packing: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // REJECTION / REWORK
  // ──────────────────────────────────────────────────────────────

  /// Reject packing and send back for rework
  /// Clears picked and verified items, resets to new/assigned
  Future<void> rejectPacking({
    required String taskId,
    required String reason,
    String? rejectedBy,
  }) async {
    try {
      final taskSnap = await _db.collection('fulfillment_tasks').doc(taskId).get();
      if (!taskSnap.exists) {
        throw Exception('Task not found: $taskId');
      }

      final taskData = taskSnap.data() as Map<String, dynamic>;

      // Add rejection to history
      final statusHistory = List<Map<String, dynamic>>.from(
        (taskData['statusHistory'] as List?) ?? [],
      );
      statusHistory.add({
        'status': 'rejected',
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'reason': reason,
        'rejectedBy': rejectedBy,
      });

      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'status': 'assigned', // Go back to assigned for re-picking
        'pickedItems': [], // Clear picked items
        'verifiedItems': [], // Clear verified items
        'rejectionCount': FieldValue.increment(1),
        'lastRejectionReason': reason,
        'lastRejectedBy': rejectedBy,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'statusHistory': statusHistory,
      });

      debugPrint('[UnifiedPackingService] Rejected task $taskId: $reason');
    } catch (e) {
      debugPrint('[UnifiedPackingService] Failed to reject packing: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // QUERIES
  // ──────────────────────────────────────────────────────────────

  /// Get fulfillment task
  Future<Map<String, dynamic>?> getTask(String taskId) async {
    try {
      final snap = await _db.collection('fulfillment_tasks').doc(taskId).get();
      if (!snap.exists) return null;
      return snap.data();
    } catch (e) {
      debugPrint('[UnifiedPackingService] Failed to get task: $e');
      return null;
    }
  }

  /// Get tasks by status
  Future<List<Map<String, dynamic>>> getTasksByStatus(String status) async {
    try {
      final snap = await _db
          .collection('fulfillment_tasks')
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('[UnifiedPackingService] Failed to get tasks by status: $e');
      return [];
    }
  }

  /// Get tasks assigned to employee
  Future<List<Map<String, dynamic>>> getEmployeeTasks(String employeeId) async {
    try {
      final snap = await _db
          .collection('fulfillment_tasks')
          .where('assignedToEmployeeId', isEqualTo: employeeId)
          .where('status', whereIn: ['assigned', 'picking', 'quality_check'])
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('[UnifiedPackingService] Failed to get employee tasks: $e');
      return [];
    }
  }

  /// Get tasks for order
  Future<Map<String, dynamic>?> getOrderFulfillmentTask(String orderId) async {
    try {
      final snap = await _db
          .collection('fulfillment_tasks')
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data();
    } catch (e) {
      debugPrint('[UnifiedPackingService] Failed to get fulfillment task: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // INTERNAL HELPERS
  // ──────────────────────────────────────────────────────────────

  /// Transition task with validation
  Future<void> _transitionTask({
    required String taskId,
    required String toStatus,
    Map<String, dynamic>? updates,
  }) async {
    try {
      final taskSnap = await _db.collection('fulfillment_tasks').doc(taskId).get();
      if (!taskSnap.exists) {
        throw Exception('Task not found: $taskId');
      }

      final taskData = taskSnap.data() as Map<String, dynamic>;
      final currentStatus = taskData['status'] as String;

      // Validate transition
      if (!canTransition(currentStatus, toStatus)) {
        throw Exception('Invalid transition: $currentStatus → $toStatus for task $taskId');
      }

      final now = DateTime.now();
      final updateData = {
        'status': toStatus,
        'updatedAt': Timestamp.fromDate(now),
        if (updates != null) ...updates,
      };

      // Add to status history
      final statusHistory = List<Map<String, dynamic>>.from(
        (taskData['statusHistory'] as List?) ?? [],
      );
      statusHistory.add({'status': toStatus, 'timestamp': Timestamp.fromDate(now)});
      updateData['statusHistory'] = statusHistory;

      await _db.collection('fulfillment_tasks').doc(taskId).update(updateData);

      debugPrint('[UnifiedPackingService] Task $taskId transitioned: $currentStatus → $toStatus');
    } catch (e) {
      debugPrint('[UnifiedPackingService] Transition failed: $e');
      rethrow;
    }
  }
}
