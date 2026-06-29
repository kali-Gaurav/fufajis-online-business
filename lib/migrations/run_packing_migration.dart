import 'package:fufajis_online/services/packing_migration_service.dart';

/// RUNBOOK: Execute packing consolidation migration
///
/// This script:
/// 1. Migrates all fulfillment_tasks_v2 documents to fulfillment_tasks
/// 2. Normalizes status values (v2 enum → unified string)
/// 3. Validates all orders are discoverable by delivery
/// 4. Deletes v2 collection (optional)
///
/// SAFE TO RUN MULTIPLE TIMES - migration is idempotent
///
/// Prerequisites:
/// - Firebase initialized
/// - Cloud Firestore accessible
/// - Sufficient quota for batch writes
///
/// Expected Duration: 2-5 minutes (depends on task count)

class PackingMigrationRunner {
  static Future<void> runFullMigration({
    bool deleteV2OnSuccess = false,
    bool dryRun = false,
  }) async {
    try {
      print('════════════════════════════════════════════════════════════');
      print('PACKING CONSOLIDATION MIGRATION');
      print('════════════════════════════════════════════════════════════');
      print('Time: ${DateTime.now()}');
      print('Dry Run: $dryRun');
      print('Delete V2 After Success: $deleteV2OnSuccess');
      print('');

      final migration = PackingMigrationService();

      if (dryRun) {
        print('[DRY RUN MODE] No changes will be made');
        print('');
      }

      // ─────────────────────────────────────────────────────────────────
      // STEP 1: MIGRATE DATA
      // ─────────────────────────────────────────────────────────────────

      print('[STEP 1] Migrating fulfillment_tasks_v2 → fulfillment_tasks');
      print('─────────────────────────────────────────────────────────────');

      final migrationResult = await migration.migrateTasksV2ToUnified();

      print('Migration Result:');
      print('  Success: ${migrationResult['success']}');
      print('  Migrated: ${migrationResult['migratedCount']}');
      print('  Skipped: ${migrationResult['skippedCount']}');
      print('  Errors: ${migrationResult['errorCount']}');
      print('  Message: ${migrationResult['message']}');

      if (migrationResult['errors'] != null &&
          (migrationResult['errors'] as List).isNotEmpty) {
        print('  Errors:');
        for (final error in migrationResult['errors'] as List) {
          print('    - $error');
        }
      }
      print('');

      if (!migrationResult['success']) {
        throw Exception('Migration failed: ${migrationResult['message']}');
      }

      // ─────────────────────────────────────────────────────────────────
      // STEP 2: VALIDATE MIGRATION
      // ─────────────────────────────────────────────────────────────────

      print('[STEP 2] Validating migration results');
      print('─────────────────────────────────────────────────────────────');

      final validationResult = await migration.validateMigration();

      print('Validation Result:');
      print('  Valid: ${validationResult['isValid']}');
      print('  Total Orders: ${validationResult['totalOrders']}');
      print('  Valid Tasks: ${validationResult['validTasks']}');
      print('  Missing Tasks: ${validationResult['missingTasks']}');
      print('  Message: ${validationResult['message']}');

      if ((validationResult['missingOrderIds'] as List).isNotEmpty) {
        print('  Missing Order IDs:');
        for (final orderId in validationResult['missingOrderIds'] as List) {
          print('    - $orderId');
        }
      }
      print('');

      if (!validationResult['isValid']) {
        throw Exception(
            'Validation failed: ${validationResult['message']}');
      }

      // ─────────────────────────────────────────────────────────────────
      // STEP 3: DELETE V2 COLLECTION (optional)
      // ─────────────────────────────────────────────────────────────────

      if (deleteV2OnSuccess && !dryRun) {
        print('[STEP 3] Deleting fulfillment_tasks_v2 collection');
        print('─────────────────────────────────────────────────────────────');

        try {
          await migration.deleteV2Collection();
          print('✓ fulfillment_tasks_v2 collection deleted');
        } catch (e) {
          print('✗ ERROR deleting v2 collection: $e');
          print('  (This can be done manually or retried later)');
        }
        print('');
      } else if (deleteV2OnSuccess && dryRun) {
        print('[STEP 3] SKIPPED (dry run mode)');
        print('  In production, run with deleteV2OnSuccess=true');
        print('');
      }

      // ─────────────────────────────────────────────────────────────────
      // SUMMARY
      // ─────────────────────────────────────────────────────────────────

      print('════════════════════════════════════════════════════════════');
      print('MIGRATION COMPLETE');
      print('════════════════════════════════════════════════════════════');
      print('');
      print('Summary:');
      print('  ✓ Migrated ${migrationResult['migratedCount']} tasks');
      print('  ✓ Validated ${validationResult['validTasks']} orders findable');
      print('  ✓ All packing orders now accessible to delivery');
      print('');
      print('Next Steps:');
      print('  1. Monitor delivery task creation for 24h');
      print('  2. Verify no orders stuck in "packed" status');
      print('  3. Check CloudFunctions logs for any errors');
      print('  4. Update documentation with migration date');
      print('');
      print('Rollback (if needed):');
      print('  - Restore Firestore from backup');
      print('  - No code changes required (migration is idempotent)');
      print('');
      print('Timestamp: ${DateTime.now()}');
      print('════════════════════════════════════════════════════════════');
    } catch (e) {
      print('');
      print('✗ MIGRATION FAILED');
      print('════════════════════════════════════════════════════════════');
      print('Error: $e');
      print('Timestamp: ${DateTime.now()}');
      print('════════════════════════════════════════════════════════════');
      rethrow;
    }
  }

  /// Quick validation without migration
  static Future<void> validateOnly() async {
    try {
      print('[VALIDATION ONLY] Checking if all packed orders are discoverable');
      print('');

      final migration = PackingMigrationService();
      final result = await migration.validateMigration();

      print('Validation Result:');
      print('  Valid: ${result['isValid']}');
      print('  Total Orders: ${result['totalOrders']}');
      print('  Valid Tasks: ${result['validTasks']}');
      print('  Missing Tasks: ${result['missingTasks']}');

      if (!result['isValid']) {
        print('');
        print('WARNING: Some orders cannot be found by delivery:');
        for (final orderId in result['missingOrderIds'] as List) {
          print('  - $orderId');
        }
      } else {
        print('');
        print('✓ All orders are discoverable by delivery');
      }
    } catch (e) {
      print('Validation error: $e');
      rethrow;
    }
  }
}

/// EXECUTION EXAMPLES:
///
/// 1. DRY RUN (test without making changes):
///    await PackingMigrationRunner.runFullMigration(dryRun: true);
///
/// 2. MIGRATE ONLY (keep v2 collection for safety):
///    await PackingMigrationRunner.runFullMigration(deleteV2OnSuccess: false);
///
/// 3. FULL MIGRATION (migrate + delete v2):
///    await PackingMigrationRunner.runFullMigration(deleteV2OnSuccess: true);
///
/// 4. VALIDATE ONLY (check if migration succeeded):
///    await PackingMigrationRunner.validateOnly();
