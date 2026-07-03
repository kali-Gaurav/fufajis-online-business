import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'rds_database_service.dart';

/// Service implementing Phase 13 Inventory Event Ledger and Change Requests.
/// Prevents direct modification of inventory stock; instead routes changes
/// through `change_requests` or writes directly to `inventory_events`.
class InventoryLedgerService {
  static final InventoryLedgerService _instance = InventoryLedgerService._internal();
  factory InventoryLedgerService() => _instance;
  InventoryLedgerService._internal();

  final RDSDatabaseService _rds = RDSDatabaseService();

  /// Creates a change request for approval (Owner Workflow).
  /// Used when an employee wants to bulk update stock or change reorder levels.
  Future<String?> submitChangeRequest({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> proposedChange,
    required String submittedByUserId,
  }) async {
    try {
      const sql = '''
        INSERT INTO change_requests (entity_type, entity_id, proposed_change, submitted_by, status)
        VALUES (\$1, \$2, \$3, \$4, 'pending')
        RETURNING request_id;
      ''';
      final res = await _rds.query(
        sql,
        params: [entityType, entityId, jsonEncode(proposedChange), submittedByUserId],
        allowWrite: true,
      );

      if (res.isNotEmpty) {
        return res[0]['request_id'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('[InventoryLedger] Error submitting change request: $e');
      return null;
    }
  }

  /// Submits a massive bulk operation based on a query filter, avoiding array size limits.
  Future<String?> submitBulkOperation({
    required Map<String, dynamic> filterJson,
    required Map<String, dynamic> proposedChange,
    required String submittedByUserId,
    String? queryId,
  }) async {
    try {
      final operationData = {'filter': filterJson, 'change': proposedChange};

      const sql = '''
        INSERT INTO bulk_operations (query_id, operation_type, operation_data, created_by)
        VALUES (\$1, 'UPDATE', \$2, \$3)
        RETURNING operation_id;
      ''';
      final res = await _rds.query(
        sql,
        params: [
          queryId, // Can be null
          jsonEncode(operationData),
          submittedByUserId,
        ],
        allowWrite: true,
      );

      if (res.isNotEmpty) {
        return res[0]['operation_id'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('[InventoryLedger] Error submitting bulk operation: $e');
      return null;
    }
  }

  /// Records an immutable inventory event in the ledger.
  /// Does NOT directly update the inventory table — handled by approval
  /// workflow or DB triggers.
  Future<String?> recordInventoryEvent({
    required String productId,
    required String eventType,
    required int quantityChange,
    int? oldValue,
    int? newValue,
    String? actorId,
    String? actorRole,
    String? source,
    String? approvedBy,
    String? referenceId, // order_id / task_id / request_id
    String? referenceType, // 'order' | 'bulk_op' | 'manual'
  }) async {
    try {
      const sql = '''
        INSERT INTO inventory_events
        (product_id, event_type, quantity_change, old_value, new_value,
         actor_id, actor_role, source, approved_by, reference_id, reference_type)
        VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10, \$11)
        RETURNING event_id;
      ''';
      final res = await _rds.query(
        sql,
        params: [
          productId,
          eventType,
          quantityChange,
          oldValue,
          newValue,
          actorId,
          actorRole,
          source,
          approvedBy,
          referenceId,
          referenceType,
        ],
        allowWrite: true,
      );

      if (res.isNotEmpty) {
        return res[0]['event_id'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('[InventoryLedger] Error recording event: $e');
      return null;
    }
  }

  /// Fetch history of events for a specific product.
  Future<List<Map<String, dynamic>>> getProductLedger(String productId, {int limit = 50}) async {
    try {
      const sql =
          'SELECT * FROM inventory_events WHERE product_id = \$1 ORDER BY timestamp DESC LIMIT \$2';
      return await _rds.rows(sql, params: [productId, limit]);
    } catch (e) {
      debugPrint('[InventoryLedger] Error fetching product ledger: $e');
      return [];
    }
  }

  Future<void> logOrderCreation({
    required String orderId,
    required String customerId,
    required double amount,
    required String orderType,
  }) async {
    await recordInventoryEvent(
      productId: 'N/A', // Order level event
      eventType: 'ORDER_CREATED',
      quantityChange: 0,
      referenceId: orderId,
      referenceType: 'order',
      actorId: customerId,
      source: 'app_checkout',
    );
  }

  Future<void> logOrderStatusChange({
    required String orderId,
    required String oldStatus,
    required String newStatus,
  }) async {
    await recordInventoryEvent(
      productId: 'N/A',
      eventType: 'ORDER_STATUS_CHANGE',
      quantityChange: 0,
      referenceId: orderId,
      referenceType: 'order',
      source: 'system',
      approvedBy: 'system',
    );
  }

  Future<void> logInventoryReservation({
    required String orderId,
    required String productId,
    required int quantity,
  }) async {
    await recordInventoryEvent(
      productId: productId,
      eventType: 'STOCK_RESERVED',
      quantityChange: -quantity,
      referenceId: orderId,
      referenceType: 'order',
      source: 'order_processing',
    );
  }

  Future<void> logInventoryDeduction({
    required String orderId,
    required String productId,
    required int quantity,
  }) async {
    await recordInventoryEvent(
      productId: productId,
      eventType: 'STOCK_DEDUCTED',
      quantityChange: -quantity,
      referenceId: orderId,
      referenceType: 'order',
      source: 'packing_complete',
    );
  }

  Future<void> logInventoryRestoration({
    required String orderId,
    required String productId,
    required int quantity,
  }) async {
    await recordInventoryEvent(
      productId: productId,
      eventType: 'STOCK_RESTORED',
      quantityChange: quantity,
      referenceId: orderId,
      referenceType: 'order',
      source: 'order_cancelled',
    );
  }

  Future<void> logRefund({required String orderId, required double amount, String? reason}) async {
    await recordInventoryEvent(
      productId: 'N/A',
      eventType: 'REFUND_PROCESSED',
      quantityChange: 0,
      referenceId: orderId,
      referenceType: 'order',
      source: 'refund_service',
    );
  }

  Future<void> reserve(String productId, int quantity, String orderId) async {
    await logInventoryReservation(orderId: orderId, productId: productId, quantity: quantity);
  }

  Future<void> deduct(String productId, int quantity, String orderId) async {
    await logInventoryDeduction(orderId: orderId, productId: productId, quantity: quantity);
  }

  Future<void> release(String productId, int quantity, String orderId) async {
    await logInventoryRestoration(orderId: orderId, productId: productId, quantity: quantity);
  }

  Future<void> restore(String productId, int quantity, String orderId) async {
    await logInventoryRestoration(orderId: orderId, productId: productId, quantity: quantity);
  }
}
