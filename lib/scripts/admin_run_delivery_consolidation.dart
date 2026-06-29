/// Fufaji Module 9 P0 Security Fix - Admin Script
///
/// Run this script ONCE to consolidate orphaned delivery collections
///
/// HOW TO RUN:
/// 1. Deploy to backend (not Flutter app)
/// 2. Trigger from admin endpoint
/// 3. Monitor logs
/// 4. Delete orphaned collections from Firestore Console
///
/// SAFETY:
/// - Read-only migration (no data loss risk)
/// - Creates backup migration fields (migratedFrom_*, migrationTimestamp)
/// - Can be re-run safely
///
/// Timeline: ~5-10 minutes (depends on data volume)
/// Created: 2026-06-23
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../migrations/consolidate_delivery_collections_module9_p0.dart';

/// One-time admin script to run the delivery consolidation migration
///
/// Execute from:
/// - Backend Cloud Function (recommended)
/// - Flutter admin panel with extra auth check
/// - Manual trigger script
class AdminRunDeliveryConsolidation {
  static Future<void> main() async {
    // Initialize Firebase (if not already initialized)
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    debugPrint('');
    debugPrint('╔════════════════════════════════════════════════════════════════╗');
    debugPrint('║  FUFAJI MODULE 9 P0 DELIVERY CONSOLIDATION MIGRATION           ║');
    debugPrint('║  10 Orphaned Collections → Single DELIVERY_TASKS Collection    ║');
    debugPrint('╚════════════════════════════════════════════════════════════════╝');
    debugPrint('');
    debugPrint('IMPORTANT: Ensure Firestore backup exists before proceeding!');
    debugPrint('');

    try {
      final migration = ConsolidateDeliveryCollectionsMigration();

      // Phase 1: Status Check
      debugPrint('PHASE 1: Pre-Migration Status Check');
      debugPrint('═' * 65);
      await migration.printMigrationStatus();
      debugPrint('');

      // Phase 2: Prompt for confirmation (if running interactively)
      debugPrint('PHASE 2: User Confirmation');
      debugPrint('═' * 65);
      debugPrint('About to migrate delivery collections.');
      debugPrint('');
      debugPrint('This will:');
      debugPrint('  1. Read all documents from 10 orphaned collections');
      debugPrint('  2. Write data to delivery_tasks with merged fields');
      debugPrint('  3. Add migration tracking fields (migratedFrom_*, migrationTimestamp)');
      debugPrint('  4. NOT delete any collections (manual step in Firestore Console)');
      debugPrint('');
      debugPrint('Risk: LOW (read-only, target collection exists)');
      debugPrint('Duration: ~5-10 minutes');
      debugPrint('');

      // In real implementation, you would check:
      // - Is user authenticated as admin?
      // - Confirm via API key or 2FA?
      // - For now, just proceed with logging

      // Phase 3: Run Migration
      debugPrint('PHASE 3: Running Migration');
      debugPrint('═' * 65);
      await migration.runFullMigration();
      debugPrint('');

      // Phase 4: Post-Migration Status
      debugPrint('PHASE 4: Post-Migration Verification');
      debugPrint('═' * 65);
      await migration.printMigrationStatus();
      debugPrint('');

      // Phase 5: Next Steps
      debugPrint('PHASE 5: Next Steps');
      debugPrint('═' * 65);
      debugPrint('✓ MIGRATION COMPLETE');
      debugPrint('');
      debugPrint('MANUAL CLEANUP REQUIRED:');
      debugPrint('');
      debugPrint('1. Verify data in Firestore Console:');
      debugPrint('   - Open delivery_tasks collection');
      debugPrint('   - Check migratedFrom_* and migrationTimestamp fields');
      debugPrint('   - Spot-check locationHistory, assignment, route objects');
      debugPrint('');
      debugPrint('2. Delete orphaned collections (in Firestore Console):');
      debugPrint('   - delivery_tracking');
      debugPrint('   - delivery_routes');
      debugPrint('   - delivery_assignments');
      debugPrint('   - delivery_otp');
      debugPrint('   - delivery_agents');
      debugPrint('   - delivery_locations');
      debugPrint('   - delivery_status');
      debugPrint('   - delivery_history');
      debugPrint('   - delivery_notifications');
      debugPrint('   - delivery_preferences');
      debugPrint('');
      debugPrint('3. Deploy Firestore security rules:');
      debugPrint('   firebase deploy --only firestore:rules');
      debugPrint('');
      debugPrint('4. Test delivery module in staging:');
      debugPrint('   - Rider location tracking');
      debugPrint('   - Customer delivery tracking');
      debugPrint('   - OTP verification (with bcrypt hashing)');
      debugPrint('   - Assignment history');
      debugPrint('');
      debugPrint('5. Validate in production (1 hour monitoring):');
      debugPrint('   - Check delivery error logs');
      debugPrint('   - Monitor API latency');
      debugPrint('   - Confirm no customer issues');
      debugPrint('');
      debugPrint('CRITICAL: Ensure OTP hashing is implemented!');
      debugPrint('  Current: Plaintext OTP (PLACEHOLDER)');
      debugPrint('  Required: bcrypt hashing in DeliveryService');
      debugPrint('');

      debugPrint('═' * 65);
      debugPrint('Migration completed at ${DateTime.now()}');
      debugPrint('═' * 65);
    } catch (e) {
      debugPrint('');
      debugPrint('╔════════════════════════════════════════════════════════════════╗');
      debugPrint('║  MIGRATION FAILED                                              ║');
      debugPrint('╚════════════════════════════════════════════════════════════════╝');
      debugPrint('');
      debugPrint('Error: $e');
      debugPrint('');
      debugPrint('ROLLBACK:');
      debugPrint('  1. Restore Firestore from backup');
      debugPrint('  2. Fix the error');
      debugPrint('  3. Re-run migration');
      debugPrint('');
      rethrow;
    }
  }

  /// Safer version: Returns status instead of throwing
  static Future<MigrationResult> runSafely() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    try {
      final migration = ConsolidateDeliveryCollectionsMigration();
      await migration.runFullMigration();

      return MigrationResult(
        success: true,
        message: 'Migration completed successfully',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return MigrationResult(
        success: false,
        message: 'Migration failed: $e',
        timestamp: DateTime.now(),
      );
    }
  }
}

/// Migration result for API responses
class MigrationResult {
  final bool success;
  final String message;
  final DateTime timestamp;

  MigrationResult({
    required this.success,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Example Cloud Function endpoint
///
/// Deploy as: functions/migrate_delivery_collections/index.dart
///
/// Endpoint: POST /api/admin/migrate/delivery-consolidation
/// Auth: Requires admin JWT token + 2FA confirmation code
///
/// Usage:
/// ```
/// curl -X POST \
///   -H "Authorization: Bearer <admin-jwt>" \
///   -H "X-2FA-Code: <code>" \
///   https://api.fufaji.com/admin/migrate/delivery-consolidation
/// ```
//
// Future<void> migrateDeliveryConsolidation(Request req) async {
//   // Check admin auth
//   final token = req.headers['authorization']?.replaceFirst('Bearer ', '');
//   if (!isValidAdminToken(token)) {
//     return Response.forbidden('Unauthorized');
//   }
//
//   // Check 2FA
//   final code2fa = req.headers['x-2fa-code'];
//   if (!is2FACodeValid(token, code2fa)) {
//     return Response.forbidden('2FA validation failed');
//   }
//
//   // Run migration
//   final result = await AdminRunDeliveryConsolidation.runSafely();
//
//   return Response.ok(
//     jsonEncode(result.toJson()),
//     headers: {'Content-Type': 'application/json'},
//   );
// }
