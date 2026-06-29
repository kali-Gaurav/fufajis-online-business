import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fulfillment_task_model.dart';
import '../models/fulfillment_model.dart';
import '../models/order_model.dart';

class PackingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // final InventoryLedgerService _ledger = InventoryLedgerService(); // Unused
  static final PackingService _instance = PackingService._internal();

  factory PackingService() => _instance;
  PackingService._internal();

  /// Assign an order to an employee for packing
  Future<FulfillmentTask> assignOrderToEmployee(
    String orderId,
    String employeeId,
    String employeeName,
    String shopId,
    String branchId,
    List<FulfillmentItem> items,
  ) async {
    try {
      final docRef = _db.collection('fulfillment_tasks').doc();
      final taskId = docRef.id;
      final now = DateTime.now();

      final task = FulfillmentTask(
        id: taskId,
        orderId: orderId,
        employeeId: employeeId,
        shopId: shopId,
        branchId: branchId,
        status: FulfillmentStatus.assigned,
        items: items,
        createdAt: now,
      );

      await docRef.set(task.toMap());

      // Update order status to 'processing'
      await _db.collection('shops').doc(shopId).collection('orders').doc(orderId).update({
        'status': 'processing',
        'fulfillmentTaskId': taskId,
        'assignedToEmployee': employeeId,
        'assignedAt': Timestamp.fromDate(now),
      });

      return task;
    } catch (e) {
      rethrow;
    }
  }

  /// Get pick list for an order (items in warehouse location order)
  Future<List<FulfillmentItem>> getPickList(
    String shopId,
    String branchId,
    String orderId,
  ) async {
    try {
      final orderSnapshot = await _db
          .collection('shops')
          .doc(shopId)
          .collection('orders')
          .doc(orderId)
          .get();

      if (!orderSnapshot.exists) {
        return [];
      }

      final orderData = orderSnapshot.data() as Map<String, dynamic>;
      final items = orderData['items'] as List? ?? [];

      final pickList = <FulfillmentItem>[];

      for (var item in items) {
        final String productId = item['productId'] as String? ?? '';
        final productSnapshot = await _db
            .collection('shops')
            .doc(shopId)
            .collection('branches')
            .doc(branchId)
            .collection('products')
            .doc(productId)
            .get();

        if (productSnapshot.exists) {
          final productData = productSnapshot.data() as Map<String, dynamic>;
          pickList.add(FulfillmentItem(
            productId: productId,
            productName: productData['name'] as String? ?? 'Unknown',
            productImage: productData['imageUrl'] as String?,
            requiredQuantity: (item['quantity'] as num? ?? 0).toDouble(),
            unit: productData['unit'] as String? ?? 'pcs',
            createdAt: DateTime.now(),
          ));
        }
      }

      // Sort by warehouse location (if available)
      // This is a simplified sort; implement actual location sorting as per your warehouse layout
      return pickList;
    } catch (e) {
      rethrow;
    }
  }

  /// Mark an item as packed
  Future<void> markItemPacked(
    String taskId,
    String productId,
    double quantity,
  ) async {
    try {
      final taskSnapshot = await _db.collection('fulfillment_tasks').doc(taskId).get();
      if (!taskSnapshot.exists) throw Exception('Task not found');

      final task = FulfillmentTask.fromMap({...taskSnapshot.data()!, 'id': taskId});
      final itemIndex = task.items.indexWhere((i) => i.productId == productId);

      if (itemIndex == -1) throw Exception('Item not found in task');

      task.items[itemIndex].packedQuantity = quantity;
      task.items[itemIndex].scannedAt = DateTime.now();

      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'items': task.items.map((i) => i.toMap()).toList(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Complete packing for an order
  Future<void> completePacking(
    String taskId,
    String orderId,
    String shopId,
  ) async {
    try {
      final now = DateTime.now();

      // Update task status
      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'status': FulfillmentStatus.ready.index,
        'completedAt': Timestamp.fromDate(now),
      });

      // Update order status
      await _db
          .collection('shops')
          .doc(shopId)
          .collection('orders')
          .doc(orderId)
          .update({
        'status': 'packed',
        'packedAt': Timestamp.fromDate(now),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Get employee stats for a specific date
  Future<EmployeeDailyStats> getEmployeeStats(
    String employeeId,
    DateTime date,
  ) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final docId = '${employeeId}_$dateStr';

      final snapshot = await _db.collection('employee_daily_stats').doc(docId).get();

      if (snapshot.exists) {
        return EmployeeDailyStats.fromMap(snapshot.data()!);
      }

      return EmployeeDailyStats(
        employeeId: employeeId,
        date: dateStr,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Get all tasks for an employee on a specific date
  Future<List<FulfillmentTask>> getEmployeeTasksForDate(
    String employeeId,
    String shopId,
    String branchId,
    DateTime date,
  ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _db
          .collection('fulfillment_tasks')
          .where('employeeId', isEqualTo: employeeId)
          .where('shopId', isEqualTo: shopId)
          .where('branchId', isEqualTo: branchId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => FulfillmentTask.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get available unassigned orders for a branch
  Future<List<OrderModel>> getUnassignedOrders(
    String shopId,
    String branchId,
  ) async {
    try {
      await _db
          .collection('shops')
          .doc(shopId)
          .collection('orders')
          .where('branchId', isEqualTo: branchId)
          .where('status', isEqualTo: 'confirmed')
          .where('fulfillmentTaskId', isNull: true)
          .orderBy('createdAt', descending: true)
          .get();

      // Note: This returns OrderModel stub data. Implement full OrderModel conversion as needed
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Reject a task (send back to queue)
  Future<void> rejectTask(
    String taskId,
    String orderId,
    String shopId,
    String reason,
  ) async {
    try {
      final now = DateTime.now();

      // Update task
      await _db.collection('fulfillment_tasks').doc(taskId).update({
        'status': FulfillmentStatus.rejected.index,
        'rejectionReason': reason,
        'qualityCheckedAt': Timestamp.fromDate(now),
      });

      // Revert order status back to confirmed
      await _db
          .collection('shops')
          .doc(shopId)
          .collection('orders')
          .doc(orderId)
          .update({
        'status': 'confirmed',
        'fulfillmentTaskId': FieldValue.delete(),
        'assignedToEmployee': FieldValue.delete(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Get quality report for a task
  Future<Map<String, dynamic>> getQualityReport(String taskId) async {
    try {
      final snapshot = await _db.collection('fulfillment_tasks').doc(taskId).get();
      if (!snapshot.exists) throw Exception('Task not found');

      final task = FulfillmentTask.fromMap({...snapshot.data()!, 'id': taskId});

      return {
        'taskId': taskId,
        'status': task.status.displayName,
        'totalItems': task.items.length,
        'verifiedItems': task.items.where((i) => i.verified).length,
        'packedItems': task.items.where((i) => i.isPacked).length,
        'qualityScore': task.qualityScore,
        'completionTime': task.totalTimeSeconds,
        'items': task.items
            .map((i) => {
                  'productName': i.productName,
                  'required': i.requiredQuantity,
                  'packed': i.packedQuantity,
                  'verified': i.verified,
                })
            .toList(),
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Get average packing time for a product in a shop
  Future<double> getAverageDuration(
    String shopId,
    String branchId,
    String productId,
  ) async {
    try {
      final snapshot = await _db
          .collection('fulfillment_tasks')
          .where('shopId', isEqualTo: shopId)
          .where('branchId', isEqualTo: branchId)
          .where('status', isEqualTo: FulfillmentStatus.completed.index)
          .get();

      if (snapshot.docs.isEmpty) return 0;

      double totalTime = 0;
      int count = 0;

      for (var doc in snapshot.docs) {
        final task = FulfillmentTask.fromMap({...doc.data(), 'id': doc.id});
        final hasProduct = task.items.any((i) => i.productId == productId);
        if (hasProduct) {
          totalTime += task.totalTimeSeconds;
          count++;
        }
      }

      return count > 0 ? totalTime / count : 0;
    } catch (e) {
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // V2 METHODS DEPRECATED - USE PackingWorkflowService INSTEAD
  // ──────────────────────────────────────────────────────────────────────────
  // These methods queried fulfillment_tasks_v2 which is being consolidated
  // into the single fulfillment_tasks collection.
  //
  // MIGRATION COMPLETE: All v2 tasks moved to fulfillment_tasks
  // fulfillment_tasks_v2 collection deleted from Firestore
  // Replaced by: PackingWorkflowService (single state machine)
  // ──────────────────────────────────────────────────────────────────────────

  @Deprecated('Use PackingWorkflowService instead')
  Future<List<FulfillmentTaskModel>> getUnassignedTasksV2() async {
    return [];
  }

  @Deprecated('Use PackingWorkflowService instead')
  Future<List<FulfillmentTaskModel>> getEmployeeWorkQueueV2(String employeeId) async {
    return [];
  }

  @Deprecated('Use PackingWorkflowService instead')
  Future<FulfillmentTaskModel?> assignTaskToEmployeeV2(
    String taskId,
    String employeeId,
    String? employeeName,
  ) async {
    return null;
  }

  @Deprecated('Use PackingWorkflowService instead')
  Future<bool> markItemPackedV2(
    String taskId,
    String itemId,
    int qtyPacked, {
    String? employeeId,
    String? shopId,
    int? qtyDamaged,
  }) async {
    return false;
  }

  @Deprecated('Use PackingWorkflowService instead')
  Future<bool> markItemVerifiedV2(String taskId, String itemId) async {
    return false;
  }

  @Deprecated('Use PackingWorkflowService instead')
  Future<bool> completePackingV2(String taskId, {String? employeeId}) async {
    return false;
  }

  @Deprecated('Use PackingWorkflowService instead')
  Future<bool> rejectPackingV2(String taskId, String reason) async {
    return false;
  }

  @Deprecated('Use PackingWorkflowService instead')
  Future<Map<String, dynamic>> getEmployeeStatsV2(
    String employeeId, {
    String period = 'today',
  }) async {
    return {};
  }

  @Deprecated('Use PackingWorkflowService instead')
  Stream<FulfillmentTaskModel?> listenToTaskUpdatesV2(String taskId) {
    return const Stream.empty();
  }

  @Deprecated('Use PackingWorkflowService instead')
  Future<bool> clockInV2(String employeeId) async {
    return false;
  }

  @Deprecated('Use PackingWorkflowService instead')
  Future<bool> clockOutV2(String employeeId) async {
    return false;
  }
}
