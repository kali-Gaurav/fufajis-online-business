import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants/order_status.dart';
import 'notification_service.dart';
import 'audit_service.dart';

/// Complete packing/fulfillment lifecycle management
/// Consolidates multiple packing workflows into single state machine
///
/// Workflow:
/// new → assigned → picking → quality_check → verified → completed
///   ↓
/// rejected → assigned (for reassignment)
///
/// Side effects:
/// - assigned: notify employee
/// - picking: track item picks
/// - quality_check: flag for QC
/// - verified: mark as ready for delivery
/// - rejected: notify employee to redo
/// - completed: update order to 'packed'

enum PackingWorkflowStatus {
  new_task, // Just created, awaiting assignment
  assigned, // Employee assigned
  picking, // Employee picking items
  quality_check, // Awaiting QC verification
  verified, // QC passed, ready for delivery
  completed, // Fulfillment done
  rejected, // QC failed, needs rework
}

class PackingWorkflowService {
  static final PackingWorkflowService _instance = PackingWorkflowService._internal();
  factory PackingWorkflowService() => _instance;
  PackingWorkflowService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // final InventoryLedgerService _ledger = InventoryLedgerService(); // Unused
  final NotificationService _notifications = NotificationService();
  final AuditService _audit = AuditService();

  // State machine definition
  static const Map<String, Set<String>> validTransitions = {
    'new': {'assigned'},
    'assigned': {'picking', 'rejected'},
    'picking': {'quality_check', 'rejected'},
    'quality_check': {'verified', 'rejected'},
    'verified': {'completed'},
    'completed': <String>{}, // Terminal
    'rejected': {'assigned'}, // Must reassign
  };

  static const Set<String> terminalStatuses = {'completed'};

  bool isTerminal(String status) => terminalStatuses.contains(status);

  bool canTransition(String from, String to) {
    if (from == to) return false;
    return validTransitions[from]?.contains(to) ?? false;
  }

  /// Create new fulfillment task from confirmed order
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
        'status': PackingWorkflowStatus.new_task.name,
        'items': items,
        'itemCount': items.length,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': [
          {
            'status': PackingWorkflowStatus.new_task.name,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': 'system',
            'reason': 'task_created',
          },
        ],
        'assignedTo': null,
        'pickedItems': [],
        'verifiedItems': [],
        'rejectionReasons': [],
      };

      await taskRef.set(taskData);

      // Update order with fulfillment task reference
      await _db.collection('orders').doc(orderId).update({
        'fulfillmentTaskId': taskId,
        'updatedAt': Timestamp.fromDate(now),
      });

      await _audit.log('fulfillment_task_created', {
        'taskId': taskId,
        'orderId': orderId,
        'shopId': shopId,
        'itemCount': items.length,
      });

      debugPrint('[PackingWorkflowService] Created fulfillment task $taskId for order $orderId');
      return taskData;
    } catch (e) {
      debugPrint('[PackingWorkflowService] Failed to create task: $e');
      rethrow;
    }
  }

  /// Assign task to employee
  Future<void> assignToEmployee({
    required String taskId,
    required String employeeId,
    String? employeeName,
  }) async {
    try {
      final taskSnap = await _db.collection('fulfillment_tasks').doc(taskId).get();
      final taskData = taskSnap.data();

      if (taskData == null) throw Exception('Task not found');

      final currentStatus = taskData['status'] as String;
      if (!canTransition(currentStatus, 'assigned')) {
        throw Exception('Cannot assign task in status: $currentStatus');
      }

      final now = DateTime.now();

      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'status': PackingWorkflowStatus.assigned.name,
        'assignedTo': employeeId,
        'assignedToName': employeeName,
        'assignedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': PackingWorkflowStatus.assigned.name,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': 'manager',
            'reason': 'assigned_to_employee',
          },
        ]),
      });

      // Notify employee
      await _notifications.notifyEmployee(employeeId, 'New packing task assigned to you', {
        'taskId': taskId,
        'itemCount': taskData['itemCount'],
        'action': 'start_packing',
      });

      await _audit.log('fulfillment_assigned', {'taskId': taskId, 'employeeId': employeeId});

      debugPrint('[PackingWorkflowService] Assigned task $taskId to employee $employeeId');
    } catch (e) {
      debugPrint('[PackingWorkflowService] Failed to assign task: $e');
      rethrow;
    }
  }

  /// Record item as picked
  /// Transitions to picking if not already in that state
  Future<void> markItemPicked({
    required String taskId,
    required String itemId,
    String? notes,
  }) async {
    try {
      final taskSnap = await _db.collection('fulfillment_tasks').doc(taskId).get();
      final taskData = taskSnap.data();

      if (taskData == null) throw Exception('Task not found');

      final currentStatus = taskData['status'] as String;

      // Can pick from 'assigned' or 'picking' states
      if (currentStatus == 'assigned') {
        // Auto-transition to picking
        await _transitionTask(taskId, 'picking', 'started_picking');
      } else if (currentStatus != 'picking') {
        throw Exception('Cannot pick items in status: $currentStatus');
      }

      final items = (taskData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final pickedItems = (taskData['pickedItems'] as List?) ?? [];
      final now = DateTime.now();

      // Find and mark item as picked
      final updatedItems = items.map((item) {
        if (item['id'] == itemId || item['productId'] == itemId) {
          return {...item, 'picked': true, 'pickedAt': now.toIso8601String()};
        }
        return item;
      }).toList();

      // Add to picked list if not already there
      if (!pickedItems.any((p) => p is Map && p['itemId'] == itemId)) {
        pickedItems.add({'itemId': itemId, 'pickedAt': Timestamp.fromDate(now), 'notes': notes});
      }

      // Check if all items are picked
      final allPicked = updatedItems.every((item) => item['picked'] == true);
      final nextStatus = allPicked ? 'quality_check' : 'picking';

      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'items': updatedItems,
        'pickedItems': pickedItems,
        'status': nextStatus,
        'pickedItemsCount': pickedItems.length,
        'pickedAt': allPicked ? Timestamp.fromDate(now) : null,
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          if (allPicked)
            {
              'status': nextStatus,
              'timestamp': Timestamp.fromDate(now),
              'changedBy': 'employee',
              'reason': 'all_items_picked',
            },
        ]),
      });

      await _audit.log('item_picked', {'taskId': taskId, 'itemId': itemId, 'notes': notes});

      debugPrint('[PackingWorkflowService] Marked item $itemId as picked in task $taskId');
    } catch (e) {
      debugPrint('[PackingWorkflowService] Failed to mark item picked: $e');
      rethrow;
    }
  }

  /// Request quality check (all items picked)
  Future<void> requestQualityCheck(String taskId) async {
    try {
      final taskSnap = await _db.collection('fulfillment_tasks').doc(taskId).get();
      final taskData = taskSnap.data();

      if (taskData == null) throw Exception('Task not found');

      final currentStatus = taskData['status'] as String;
      if (!canTransition(currentStatus, 'quality_check')) {
        throw Exception('Cannot request QC in status: $currentStatus');
      }

      await _transitionTask(taskId, 'quality_check', 'requesting_quality_check');

      // Notify QC team
      await _notifications.notifyQCTeam('Quality check needed for task: $taskId', {
        'taskId': taskId,
        'orderId': taskData['orderId'],
        'action': 'verify_packing',
      });

      debugPrint('[PackingWorkflowService] Requested QC for task $taskId');
    } catch (e) {
      debugPrint('[PackingWorkflowService] Failed to request QC: $e');
      rethrow;
    }
  }

  /// Verify items passed QC
  Future<void> verifyItems({required String taskId, String? verifiedBy, String? notes}) async {
    try {
      final taskSnap = await _db.collection('fulfillment_tasks').doc(taskId).get();
      final taskData = taskSnap.data();

      if (taskData == null) throw Exception('Task not found');

      final currentStatus = taskData['status'] as String;
      if (!canTransition(currentStatus, 'verified')) {
        throw Exception('Cannot verify in status: $currentStatus');
      }

      final items = (taskData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final now = DateTime.now();

      // Mark all items as verified
      final verifiedItems = items.map((item) {
        return {
          ...item,
          'verified': true,
          'verifiedAt': now.toIso8601String(),
          'verifiedBy': verifiedBy,
        };
      }).toList();

      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'status': PackingWorkflowStatus.verified.name,
        'items': verifiedItems,
        'verifiedItems': verifiedItems,
        'verifiedAt': Timestamp.fromDate(now),
        'verifiedBy': verifiedBy,
        'notes': notes,
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': PackingWorkflowStatus.verified.name,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': verifiedBy ?? 'qc',
            'reason': 'quality_check_passed',
          },
        ]),
      });

      // Notify employee that packing is done
      final assignedTo = taskData['assignedTo'] as String?;
      if (assignedTo != null) {
        await _notifications.notifyEmployee(
          assignedTo,
          'Your packing passed QC! Hand off for delivery.',
          {'taskId': taskId},
        );
      }

      await _audit.log('packing_verified', {
        'taskId': taskId,
        'verifiedBy': verifiedBy,
        'itemCount': items.length,
      });

      debugPrint('[PackingWorkflowService] Verified packing for task $taskId');
    } catch (e) {
      debugPrint('[PackingWorkflowService] Failed to verify items: $e');
      rethrow;
    }
  }

  /// Reject packing (QC failed)
  /// Returns task to assigned state for rework
  Future<void> rejectPacking({
    required String taskId,
    required String rejectionReason,
    String? rejectedBy,
  }) async {
    try {
      final taskSnap = await _db.collection('fulfillment_tasks').doc(taskId).get();
      final taskData = taskSnap.data();

      if (taskData == null) throw Exception('Task not found');

      final currentStatus = taskData['status'] as String;
      if (!canTransition(currentStatus, 'rejected')) {
        throw Exception('Cannot reject in status: $currentStatus');
      }

      final assignedTo = taskData['assignedTo'] as String?;
      // final rejectionReasons = (taskData['rejectionReasons'] as List?) ?? []; // Unused
      final now = DateTime.now();

      // Reset picking state
      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'status': PackingWorkflowStatus.rejected.name,
        'rejectedAt': Timestamp.fromDate(now),
        'rejectedBy': rejectedBy,
        'rejectionReason': rejectionReason,
        'rejectionReasons': FieldValue.arrayUnion([
          {
            'reason': rejectionReason,
            'rejectedBy': rejectedBy,
            'rejectedAt': Timestamp.fromDate(now),
          },
        ]),
        'items': (taskData['items'] as List?)?.map((item) {
          return {...item, 'picked': false, 'verified': false};
        }).toList(),
        'pickedItems': [],
        'verifiedItems': [],
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': PackingWorkflowStatus.rejected.name,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': rejectedBy ?? 'qc',
            'reason': 'quality_check_failed',
          },
        ]),
      });

      // Notify employee to redo
      if (assignedTo != null) {
        await _notifications.notifyEmployee(
          assignedTo,
          'Packing rejected: $rejectionReason. Please redo.',
          {'taskId': taskId, 'rejectionReason': rejectionReason, 'action': 'restart_packing'},
        );
      }

      await _audit.log('packing_rejected', {
        'taskId': taskId,
        'reason': rejectionReason,
        'rejectedBy': rejectedBy,
      });

      debugPrint('[PackingWorkflowService] Rejected packing for task $taskId: $rejectionReason');
    } catch (e) {
      debugPrint('[PackingWorkflowService] Failed to reject packing: $e');
      rethrow;
    }
  }

  /// Hand off to delivery (complete fulfillment)
  /// Transitions to completed and creates delivery task
  Future<void> markCompleted(String taskId) async {
    try {
      final taskSnap = await _db.collection('fulfillment_tasks').doc(taskId).get();
      final taskData = taskSnap.data();

      if (taskData == null) throw Exception('Task not found');

      final currentStatus = taskData['status'] as String;
      if (!canTransition(currentStatus, 'completed')) {
        throw Exception('Cannot complete in status: $currentStatus');
      }

      final orderId = taskData['orderId'] as String;
      final now = DateTime.now();

      // Complete task
      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'status': PackingWorkflowStatus.completed.name,
        'completedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': PackingWorkflowStatus.completed.name,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': 'system',
            'reason': 'handed_off_to_delivery',
          },
        ]),
      });

      // Update order status to packed (ready for delivery)
      await _db.collection('orders').doc(orderId).update({
        'status': OrderStatus.packed.firestoreValue,
        'packedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      await _audit.log('fulfillment_completed', {'taskId': taskId, 'orderId': orderId});

      debugPrint('[PackingWorkflowService] Completed fulfillment task $taskId');
    } catch (e) {
      debugPrint('[PackingWorkflowService] Failed to mark completed: $e');
      rethrow;
    }
  }

  /// Internal: generic state transition
  Future<void> _transitionTask(String taskId, String toStatus, String reason) async {
    try {
      final taskSnap = await _db.collection('fulfillment_tasks').doc(taskId).get();
      final taskData = taskSnap.data();

      if (taskData == null) throw Exception('Task not found');

      final currentStatus = taskData['status'] as String;
      if (!canTransition(currentStatus, toStatus)) {
        throw Exception('Invalid transition: $currentStatus → $toStatus');
      }

      final now = DateTime.now();

      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'status': toStatus,
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': toStatus,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': 'system',
            'reason': reason,
          },
        ]),
      });

      await _audit.log('task_status_changed', {
        'taskId': taskId,
        'fromStatus': currentStatus,
        'toStatus': toStatus,
        'reason': reason,
      });

      debugPrint('[PackingWorkflowService] Transitioned task $taskId: $currentStatus → $toStatus');
    } catch (e) {
      debugPrint('[PackingWorkflowService] Failed to transition task: $e');
      rethrow;
    }
  }

  /// Get fulfillment task
  Future<Map<String, dynamic>?> getTask(String taskId) async {
    final snap = await _db.collection('fulfillment_tasks').doc(taskId).get();
    return snap.data();
  }

  /// Get tasks by shop (for dashboard)
  Future<List<Map<String, dynamic>>> getShopTasks(
    String shopId, {
    String? statusFilter,
    int limit = 50,
  }) async {
    var query = _db
        .collection('fulfillment_tasks')
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    final snap = await query.limit(limit).get();
    return snap.docs.map((doc) => doc.data()).toList();
  }

  /// Get tasks assigned to employee
  Future<List<Map<String, dynamic>>> getEmployeeTasks(
    String employeeId, {
    String? statusFilter,
    int limit = 20,
  }) async {
    var query = _db
        .collection('fulfillment_tasks')
        .where('assignedTo', isEqualTo: employeeId)
        .orderBy('assignedAt', descending: true);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    final snap = await query.limit(limit).get();
    return snap.docs.map((doc) => doc.data()).toList();
  }
}
