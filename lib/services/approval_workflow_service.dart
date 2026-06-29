import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'rds_database_service.dart';
import 'inventory_ledger_service.dart';
import 'inventory_query_service.dart';

class ApprovalWorkflowService {
  static final ApprovalWorkflowService _instance = ApprovalWorkflowService._internal();
  factory ApprovalWorkflowService() => _instance;
  ApprovalWorkflowService._internal();

  final RDSDatabaseService _rds = RDSDatabaseService();
  final InventoryLedgerService _ledger = InventoryLedgerService();

  /// Fetches all pending change requests for owner review.
  Future<List<Map<String, dynamic>>> getPendingRequests({int limit = 50}) async {
    try {
      const sql = '''
        SELECT cr.*, u.name as submitted_by_name, u.role as submitted_by_role
        FROM change_requests cr
        LEFT JOIN users u ON cr.submitted_by = u.id
        WHERE cr.status = 'pending'
        ORDER BY cr.created_at DESC
        LIMIT \$1
      ''';
      return await _rds.rows(sql, params: [limit]);
    } catch (e) {
      debugPrint('[ApprovalWorkflow] Error fetching pending requests: $e');
      return [];
    }
  }

  /// Approves a change request. Applies the proposed changes to the entity
  /// and writes an event to the ledger.
  /// SECURITY: All field names and values are validated before use.
  Future<bool> approveRequest({
    required String requestId,
    required String ownerId,
    String? approvalNotes,
  }) async {
    try {
      // 1. Fetch the request (request_id is parameterized)
      final requestRows = await _rds.rows('SELECT * FROM change_requests WHERE request_id = \$1', params: [requestId]);
      if (requestRows.isEmpty) return false;

      final requestRes = requestRows.first;
      final entityType = requestRes['entity_type'] as String;
      final entityId = requestRes['entity_id'] as String;
      final Map<String, dynamic> proposedChange = requestRes['proposed_change'] is String
          ? jsonDecode(requestRes['proposed_change'] as String) as Map<String, dynamic>
          : requestRes['proposed_change'] as Map<String, dynamic>;

      // 2. Apply changes based on entity type
      if (entityType == 'inventory') {
        // SECURITY FIX: Use parameterized query with safe field validation
        // Validate field names against allowed inventory fields
        final allowedInventoryFields = {'current_stock', 'reorder_level', 'reserved_stock', 'damaged_units'};

        final validUpdates = <String, dynamic>{};
        for (final entry in proposedChange.entries) {
          if (!allowedInventoryFields.contains(entry.key)) {
            debugPrint('[ApprovalWorkflow] Rejected invalid inventory field: ${entry.key}');
            continue;
          }
          validUpdates[entry.key] = entry.value;
        }

        if (validUpdates.isEmpty) {
          debugPrint('[ApprovalWorkflow] No valid fields to update in inventory');
          return false;
        }

        // Build parameterized UPDATE query
        final setClauses = <String>[];
        final params = <dynamic>[];
        int paramIndex = 1;

        validUpdates.forEach((key, value) {
          setClauses.add('$key = \$${paramIndex++}');
          params.add(value);
        });

        params.add(entityId);
        final updateSql = 'UPDATE inventory SET ${setClauses.join(', ')} WHERE inventory_id = \$$paramIndex';

        await _rds.query(updateSql, params: params, allowWrite: true);

        // Find product_id for ledger (entity_id is parameterized)
        final invRows = await _rds.rows('SELECT product_id FROM inventory WHERE inventory_id = \$1', params: [entityId]);
        if (invRows.isEmpty) return false;
        final productId = invRows.first['product_id'] as String;

        // Record the event
        await _ledger.recordInventoryEvent(
          productId: productId,
          eventType: 'STOCK_ADJUSTMENT_APPROVED',
          quantityChange: (validUpdates['current_stock'] as num?)?.toInt() ?? 0,
          actorId: ownerId,
          actorRole: 'owner',
          source: 'ApprovalWorkflow',
          approvedBy: ownerId,
        );
      } else if (entityType == 'product') {
        // SECURITY FIX: Validate field names against allowed product fields
        final allowedProductFields = {'name', 'description', 'price', 'sku', 'category', 'brand'};

        final validUpdates = <String, dynamic>{};
        for (final entry in proposedChange.entries) {
          if (!allowedProductFields.contains(entry.key)) {
            debugPrint('[ApprovalWorkflow] Rejected invalid product field: ${entry.key}');
            continue;
          }
          validUpdates[entry.key] = entry.value;
        }

        if (validUpdates.isEmpty) {
          debugPrint('[ApprovalWorkflow] No valid fields to update in product');
          return false;
        }

        // Build parameterized UPDATE query
        final setClauses = <String>[];
        final params = <dynamic>[];
        int paramIndex = 1;

        validUpdates.forEach((key, value) {
          setClauses.add('$key = \$${paramIndex++}');
          params.add(value);
        });

        params.add(entityId);
        final sql = 'UPDATE products SET ${setClauses.join(', ')} WHERE id = \$$paramIndex';
        await _rds.query(sql, params: params, allowWrite: true);
      }

      // 3. Mark request as approved (all values parameterized)
      const updateSql = '''
        UPDATE change_requests
        SET status = 'approved', reviewed_by = \$1, reviewed_at = NOW(), approval_notes = \$2
        WHERE request_id = \$3
      ''';
      await _rds.query(updateSql, params: [ownerId, approvalNotes, requestId], allowWrite: true);

      return true;
    } catch (e) {
      debugPrint('[ApprovalWorkflow] Error approving request: $e');
      return false;
    }
  }

  /// Rejects a change request.
  Future<bool> rejectRequest({
    required String requestId,
    required String ownerId,
    String? rejectionNotes,
  }) async {
    try {
      const updateSql = '''
        UPDATE change_requests 
        SET status = 'rejected', reviewed_by = \$1, reviewed_at = NOW(), approval_notes = \$2
        WHERE request_id = \$3
      ''';
      await _rds.query(updateSql, params: [ownerId, rejectionNotes, requestId], allowWrite: true);
      return true;
    } catch (e) {
      debugPrint('[ApprovalWorkflow] Error rejecting request: $e');
      return false;
    }
  }

  /// Approves a massive Bulk Operation.
  /// Reconstructs the dynamic SQL WHERE clause, applies the update,
  /// and writes the corresponding events into `inventory_events` via an INSERT INTO ... SELECT
  /// SECURITY: Field names and values are validated, WHERE clause comes from parameterized service
  Future<bool> approveBulkOperation({
    required String operationId,
    required String ownerId,
  }) async {
    try {
      // 1. Fetch the bulk operation (operationId is parameterized)
      final rows = await _rds.rows('SELECT * FROM bulk_operations WHERE operation_id = \$1', params: [operationId]);
      if (rows.isEmpty) return false;

      final opRes = rows.first;
      final opData = (opRes['operation_data'] is String)
          ? jsonDecode(opRes['operation_data'] as String) as Map<String, dynamic>
          : opRes['operation_data'] as Map<String, dynamic>;

      final filterJson = opData['filter'] as Map<String, dynamic>;
      final proposedChange = opData['change'] as Map<String, dynamic>;

      // 2. Reconstruct WHERE clause (delegated to InventoryQueryService which should parameterize)
      final logicStr = filterJson['logic'] as String? ?? 'and';
      final logic = logicStr == 'or' ? FilterLogic.or : FilterLogic.and;
      final conditionsList = (filterJson['conditions'] as List).map((c) => FilterCondition.fromMap(c as Map<String, dynamic>)).toList();

      final queryService = InventoryQueryService();
      final whereResult = queryService.buildWhereClause(conditionsList, logic: logic, startParamIndex: 1);
      final whereSql = whereResult['sql'] as String;
      final params = whereResult['params'] as List<dynamic>;
      int nextParamIndex = whereResult['nextParamIndex'] as int;

      // 3. Build safe UPDATE with validated field names
      // SECURITY FIX: Validate target field against whitelist before using
      final targetField = proposedChange.keys.first;
      final newValue = proposedChange.values.first;

      // Whitelist of allowed fields for bulk updates
      final allowedInventoryFields = {'current_stock', 'reorder_level', 'reserved_stock', 'damaged_units'};
      final allowedProductFields = {'price', 'category', 'brand'};

      bool isInventoryField = allowedInventoryFields.contains(targetField);
      bool isProductField = allowedProductFields.contains(targetField);

      if (!isInventoryField && !isProductField) {
        debugPrint('[ApprovalWorkflow] Rejected invalid bulk update field: $targetField');
        return false;
      }

      String targetTable = isInventoryField ? 'inventory' : 'products';
      String joinTable = isInventoryField ? 'products p' : 'inventory i';
      String joinCondition = isInventoryField ? 'p.id = i.product_id' : 'p.id = i.product_id';

      String updateAlias = isInventoryField ? 'i' : 'p';
      // SECURITY FIX: Field name is validated above, parameterized value here
      String setClause = '$targetField = \$$nextParamIndex';
      params.add(newValue);

      // The safe UPDATE syntax for Postgres with JOIN uses parameterized values
      final updateSql = '''
        UPDATE $targetTable $updateAlias
        SET $setClause
        FROM $joinTable
        WHERE $joinCondition $whereSql
      ''';

      await _rds.query(updateSql, params: params, allowWrite: true);

      // 4. Record Audit Events via bulk INSERT INTO ... SELECT
      // SECURITY: Field and value are now validated, ownerId is parameterized
      int eventParamIndex = nextParamIndex + 1;
      final eventSql = '''
        INSERT INTO inventory_events (product_id, event_type, quantity_change, actor_id, actor_role, source, approved_by)
        SELECT p.id, 'BULK_UPDATE_APPROVED', 0, \$$eventParamIndex, 'owner', 'BulkOperations', \$$eventParamIndex
        FROM products p
        LEFT JOIN inventory i ON p.id = i.product_id
        WHERE 1=1 $whereSql
      ''';

      final eventParams = List<dynamic>.from(whereResult['params'] as List<dynamic>);
      eventParams.add(ownerId); // for actor_id / approved_by

      await _rds.query(eventSql, params: eventParams, allowWrite: true);

      // 5. Mark as executed (all values parameterized)
      const markSql = '''
        UPDATE bulk_operations
        SET executed_at = NOW(), approved_by = \$1
        WHERE operation_id = \$2
      ''';
      await _rds.query(markSql, params: [ownerId, operationId], allowWrite: true);

      return true;
    } catch (e) {
      debugPrint('[ApprovalWorkflow] Error approving bulk operation: $e');
      return false;
    }
  }
}
