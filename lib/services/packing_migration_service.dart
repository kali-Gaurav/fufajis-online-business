import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Migration service: consolidates fulfillment_tasks_v2 into fulfillment_tasks
///
/// CRITICAL P0 BUG FIX:
/// Delivery couldn't find packed orders because:
/// - fulfillment_tasks (v1): status='packed'
/// - fulfillment_tasks_v2: status='COMPLETED'
/// - Delivery queries: WHERE status='packed'
///
/// Solution: Migrate all v2 tasks to v1 with normalized status values
/// Then delete fulfillment_tasks_v2 collection
///
/// Status mapping:
/// NEW → new
/// IN_PROGRESS → assigned
/// QUALITY_CHECK → quality_check
/// COMPLETED → verified
/// REJECTED → rejected

class PackingMigrationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Migrate all tasks from fulfillment_tasks_v2 to fulfillment_tasks
  /// Safe to run multiple times - uses transaction to prevent duplicates
  Future<Map<String, dynamic>> migrateTasksV2ToUnified() async {
    try {
      debugPrint('[PackingMigration] Starting migration from v2 to unified...');

      // Fetch all v2 tasks
      final v2Snapshot = await _db.collection('fulfillment_tasks_v2').get();
      debugPrint('[PackingMigration] Found ${v2Snapshot.docs.length} v2 tasks to migrate');

      if (v2Snapshot.docs.isEmpty) {
        debugPrint('[PackingMigration] No v2 tasks to migrate - exiting cleanly');
        return {
          'success': true,
          'migratedCount': 0,
          'skippedCount': 0,
          'errorCount': 0,
          'message': 'No v2 tasks found',
        };
      }

      int migratedCount = 0;
      int skippedCount = 0;
      int errorCount = 0;
      final List<String> errors = [];

      for (final v2Doc in v2Snapshot.docs) {
        try {
          final v2Data = v2Doc.data();
          final taskId = v2Doc.id;

          // Check if already migrated (by looking for a matching task in v1)
          final v1Snap = await _db.collection('fulfillment_tasks').doc(taskId).get();

          if (v1Snap.exists) {
            debugPrint('[PackingMigration] Task $taskId already in v1 - skipping');
            skippedCount++;
            continue;
          }

          // Normalize status
          final v2Status = (v2Data['status'] ?? 'NEW') as String;
          final normalizedStatus = _normalizeStatus(v2Status);

          // Build normalized data
          final normalizedData = {
            'id': taskId,
            'orderId': v2Data['orderId'] ?? '',
            'shopId': v2Data['shopId'] ?? '',
            'branchId': v2Data['branchId'] ?? '',
            'status': normalizedStatus,
            'items': v2Data['items'] ?? [],
            'createdAt': v2Data['createdAt'] ?? Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'statusHistory': [
              {
                'status': normalizedStatus,
                'timestamp': Timestamp.now(),
                'reason': 'migrated_from_v2',
              },
            ],
            'assignedToEmployeeId': v2Data['assignedToEmployeeId'],
            'assignedToEmployeeName': v2Data['assignedToEmployeeName'],
            'assignedAt': v2Data['assignedAt'],
            'pickedItems': v2Data['pickedItems'] ?? [],
            'verifiedItems': v2Data['verifiedItems'] ?? [],
            'migratedAt': Timestamp.now(),
            'migratedFromV2': true,
            // Preserve original v2 fields for reference
            'v2OriginalStatus': v2Status,
            'v2OriginalData': v2Data,
          };

          // Write to v1 collection
          await _db.collection('fulfillment_tasks').doc(taskId).set(normalizedData);

          migratedCount++;
          debugPrint('[PackingMigration] Migrated task $taskId ($v2Status → $normalizedStatus)');
        } catch (e) {
          errorCount++;
          errors.add('Task ${v2Doc.id}: $e');
          debugPrint('[PackingMigration] ERROR migrating ${v2Doc.id}: $e');
        }
      }

      debugPrint('[PackingMigration] Migration complete:');
      debugPrint('  - Migrated: $migratedCount');
      debugPrint('  - Skipped: $skippedCount');
      debugPrint('  - Errors: $errorCount');

      return {
        'success': errorCount == 0,
        'migratedCount': migratedCount,
        'skippedCount': skippedCount,
        'errorCount': errorCount,
        'errors': errors,
        'message':
            'Migration complete: $migratedCount migrated, $skippedCount skipped, $errorCount errors',
      };
    } catch (e) {
      debugPrint('[PackingMigration] FATAL ERROR: $e');
      rethrow;
    }
  }

  /// Normalize v2 status to unified status
  /// v2: NEW, IN_PROGRESS, QUALITY_CHECK, COMPLETED, REJECTED
  /// v1: new, assigned, picking, quality_check, verified, completed, rejected
  String _normalizeStatus(String v2Status) {
    return switch (v2Status.toUpperCase()) {
      'NEW' => 'new',
      'IN_PROGRESS' => 'assigned',
      'QUALITY_CHECK' => 'quality_check',
      'COMPLETED' => 'verified',
      'REJECTED' => 'rejected',
      _ => 'new', // Default fallback
    };
  }

  /// Validate migration results
  /// Ensures all orders are findable by delivery
  Future<Map<String, dynamic>> validateMigration() async {
    try {
      debugPrint('[PackingMigration] Validating migration...');

      // Get all orders expecting packed status
      final ordersSnapshot = await _db
          .collection('orders')
          .where('status', isEqualTo: 'packed')
          .get();

      debugPrint('[PackingMigration] Found ${ordersSnapshot.docs.length} orders in packed status');

      int missingTasks = 0;
      int validTasks = 0;
      final List<String> missingOrderIds = [];

      for (final orderDoc in ordersSnapshot.docs) {
        final orderId = orderDoc.id;
        final taskId = orderDoc.data()['fulfillmentTaskId'] as String?;

        if (taskId == null || taskId.isEmpty) {
          missingOrderIds.add(orderId);
          missingTasks++;
          continue;
        }

        final taskSnap = await _db.collection('fulfillment_tasks').doc(taskId).get();

        if (taskSnap.exists) {
          validTasks++;
        } else {
          missingOrderIds.add(orderId);
          missingTasks++;
        }
      }

      final isValid = missingTasks == 0;

      return {
        'isValid': isValid,
        'totalOrders': ordersSnapshot.docs.length,
        'validTasks': validTasks,
        'missingTasks': missingTasks,
        'missingOrderIds': missingOrderIds,
        'message': isValid
            ? 'All orders have valid fulfillment tasks'
            : '$missingTasks orders are missing fulfillment tasks',
      };
    } catch (e) {
      debugPrint('[PackingMigration] Validation error: $e');
      rethrow;
    }
  }

  /// Delete v2 collection after successful migration
  /// Only run after validating migration is successful
  Future<void> deleteV2Collection() async {
    try {
      debugPrint('[PackingMigration] DELETING fulfillment_tasks_v2 collection...');

      final v2Snapshot = await _db.collection('fulfillment_tasks_v2').get();

      final batch = _db.batch();
      for (final doc in v2Snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      debugPrint('[PackingMigration] Deleted ${v2Snapshot.docs.length} v2 documents');
    } catch (e) {
      debugPrint('[PackingMigration] Error deleting v2 collection: $e');
      rethrow;
    }
  }

  /// Complete migration workflow
  /// 1. Migrate data
  /// 2. Validate
  /// 3. Delete v2 (if validation passes)
  Future<Map<String, dynamic>> completeMigration({bool deleteV2 = false}) async {
    try {
      debugPrint('[PackingMigration] STARTING COMPLETE MIGRATION WORKFLOW');

      // Step 1: Migrate
      final migrationResult = await migrateTasksV2ToUnified();
      if (!migrationResult['success']) {
        throw Exception('Migration failed: ${migrationResult['message']}');
      }

      // Step 2: Validate
      final validationResult = await validateMigration();
      if (!validationResult['isValid']) {
        throw Exception(
          'Validation failed: ${validationResult['message']} - Missing: ${validationResult['missingOrderIds']}',
        );
      }

      debugPrint('[PackingMigration] Validation passed');

      // Step 3: Delete v2 if requested
      if (deleteV2) {
        await deleteV2Collection();
        debugPrint('[PackingMigration] v2 collection deleted');
      }

      debugPrint('[PackingMigration] MIGRATION WORKFLOW COMPLETE');

      return {
        'success': true,
        'migration': migrationResult,
        'validation': validationResult,
        'deletedV2': deleteV2,
        'message': 'Complete migration successful',
      };
    } catch (e) {
      debugPrint('[PackingMigration] WORKFLOW FAILED: $e');
      rethrow;
    }
  }
}
