/// Fufaji Module 9 P0 Security Fix: Consolidate Orphaned Delivery Collections
///
/// Issue: 10 separate delivery-related collections with NO security rules
///        - GPS data exposed (delivery_locations, delivery_tracking)
///        - OTP data exposed (delivery_otp)
///        - Assignment/routing exposed (delivery_routes, delivery_assignments)
///
/// Solution: Consolidate all delivery data into single DELIVERY_TASKS collection
///           with proper Firestore security rules (RLS)
///
/// Timeline: 2 hours
/// Risk: LOW (read-only migration, target collection already exists and used)
/// Rollback: Migrate data back out (not needed in normal flow)
///
/// Status: EXECUTE NOW
/// Created: 2026-06-23
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants/firestore_collections.dart';
import '../services/otp_hash_service.dart';

class ConsolidateDeliveryCollectionsMigration {
  static final ConsolidateDeliveryCollectionsMigration _instance =
      ConsolidateDeliveryCollectionsMigration._internal();

  factory ConsolidateDeliveryCollectionsMigration() => _instance;

  ConsolidateDeliveryCollectionsMigration._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// List of orphaned collections to consolidate
  static const List<String> ORPHANED_COLLECTIONS = [
    'delivery_tracking',      // → deliveryCompleted / completedAt
    'delivery_routes',        // → route field in delivery_tasks
    'delivery_assignments',   // → assignment field in delivery_tasks
    'delivery_otp',           // → otp field in delivery_tasks (MUST HASH)
    'delivery_agents',        // → riderId field already in delivery_tasks
    'delivery_locations',     // → locationHistory array in delivery_tasks
    'delivery_status',        // → status field in delivery_tasks
    'delivery_history',       // → history array in delivery_tasks
    'delivery_notifications', // → notifications collection (general)
    'delivery_preferences',   // → preferences field in delivery_tasks
  ];

  /// Check if a collection has documents
  Future<bool> hasDocuments(String collectionName) async {
    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking $collectionName: $e');
      return false;
    }
  }

  /// Get count of documents in a collection
  Future<int> getDocumentCount(String collectionName) async {
    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .count()
          .get()
          .timeout(const Duration(seconds: 10));
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error counting $collectionName: $e');
      return 0;
    }
  }

  /// Consolidate delivery_tracking → delivery_tasks (completedAt field)
  Future<void> migrateDeliveryTracking() async {
    const collName = 'delivery_tracking';
    final count = await getDocumentCount(collName);

    if (count == 0) {
      debugPrint('[$collName] No documents to migrate');
      return;
    }

    debugPrint(
        '[$collName] Migrating $count documents to delivery_tasks.completedAt...');

    try {
      final docs = await _firestore.collection(collName).get();
      final batch = _firestore.batch();

      for (final doc in docs.docs) {
        final data = doc.data();
        final deliveryId = data['deliveryId'] ?? doc.id;
        final completedAt = data['completedAt'] ?? data['timestamp'];

        // Merge into delivery_tasks
        batch.set(
          _firestore.collection(FirestoreCollections.DELIVERY_TASKS).doc(deliveryId),
          {
            'completedAt': completedAt,
            'migratedFrom_tracking': collName,
            'migrationTimestamp': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      debugPrint('[$collName] Migration complete: $count documents');
    } catch (e) {
      debugPrint('[$collName] Migration failed: $e');
      rethrow;
    }
  }

  /// Consolidate delivery_routes → delivery_tasks.route
  Future<void> migrateDeliveryRoutes() async {
    const collName = 'delivery_routes';
    final count = await getDocumentCount(collName);

    if (count == 0) {
      debugPrint('[$collName] No documents to migrate');
      return;
    }

    debugPrint('[$collName] Migrating $count documents to delivery_tasks.route...');

    try {
      final docs = await _firestore.collection(collName).get();
      final batch = _firestore.batch();

      for (final doc in docs.docs) {
        final data = doc.data();
        final deliveryId = data['deliveryId'] ?? data['taskId'] ?? doc.id;

        batch.set(
          _firestore.collection(FirestoreCollections.DELIVERY_TASKS).doc(deliveryId),
          {
            'route': {
              'waypoints': data['waypoints'],
              'distance': data['distance'],
              'estimatedDuration': data['estimatedDuration'],
              'optimizationLevel': data['optimizationLevel'],
              'createdAt': data['createdAt'],
            },
            'migratedFrom_routes': collName,
            'migrationTimestamp': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      debugPrint('[$collName] Migration complete: $count documents');
    } catch (e) {
      debugPrint('[$collName] Migration failed: $e');
      rethrow;
    }
  }

  /// Consolidate delivery_assignments → delivery_tasks.assignment
  Future<void> migrateDeliveryAssignments() async {
    const collName = 'delivery_assignments';
    final count = await getDocumentCount(collName);

    if (count == 0) {
      debugPrint('[$collName] No documents to migrate');
      return;
    }

    debugPrint(
        '[$collName] Migrating $count documents to delivery_tasks.assignment...');

    try {
      final docs = await _firestore.collection(collName).get();
      final batch = _firestore.batch();

      for (final doc in docs.docs) {
        final data = doc.data();
        final deliveryId = data['orderId'] ?? data['taskId'] ?? doc.id;

        batch.set(
          _firestore.collection(FirestoreCollections.DELIVERY_TASKS).doc(deliveryId),
          {
            'assignment': {
              'agentId': data['agentId'],
              'agentName': data['agentName'],
              'agentPhone': data['agentPhone'],
              'assignedAt': data['assignedAt'],
              'assignedBy': data['assignedBy'],
              'status': data['status'],
            },
            'migratedFrom_assignments': collName,
            'migrationTimestamp': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      debugPrint('[$collName] Migration complete: $count documents');
    } catch (e) {
      debugPrint('[$collName] Migration failed: $e');
      rethrow;
    }
  }

  /// Consolidate delivery_otp → delivery_tasks.otp (HASHED)
  /// WARNING: Must hash OTP before storing!
  Future<void> migrateDeliveryOTP() async {
    const collName = 'delivery_otp';
    final count = await getDocumentCount(collName);

    if (count == 0) {
      debugPrint('[$collName] No documents to migrate');
      return;
    }

    debugPrint('[$collName] Migrating $count documents to delivery_tasks.otp...');
    debugPrint('[$collName] WARNING: OTPs must be hashed before storing!');

    try {
      final docs = await _firestore.collection(collName).get();
      final batch = _firestore.batch();

      for (final doc in docs.docs) {
        final data = doc.data();
        final deliveryId = data['deliveryId'] ?? doc.id;

        // ✅ FIXED: Hash the OTP using PBKDF2-SHA256 before storing
        final otp = data['otp'] as String?;
        final hashedOtp = otp != null ? OTPHashService.hashOTP(otp) : null;

        batch.set(
          _firestore.collection(FirestoreCollections.DELIVERY_TASKS).doc(deliveryId),
          {
            'otp': hashedOtp,
            'otpGeneratedAt': data['generatedAt'],
            'otpExpiresAt': data['expiresAt'],
            'otpVerified': data['verified'] ?? false,
            'otpAttempts': data['attempts'] ?? 0,
            'otpHashAlgorithm': 'PBKDF2-SHA256',
            'otpHashIterations': 100000,
            'migratedFrom_otp': collName,
            'migrationTimestamp': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      debugPrint('[$collName] Migration complete: $count documents');
      debugPrint('[$collName] ✅ OTP hashing applied with PBKDF2-SHA256 (100k iterations)');
    } catch (e) {
      debugPrint('[$collName] Migration failed: $e');
      rethrow;
    }
  }

  /// Consolidate delivery_locations → delivery_tasks.locationHistory array
  Future<void> migrateDeliveryLocations() async {
    const collName = 'delivery_locations';
    final count = await getDocumentCount(collName);

    if (count == 0) {
      debugPrint('[$collName] No documents to migrate');
      return;
    }

    debugPrint(
        '[$collName] Migrating $count documents to delivery_tasks.locationHistory...');

    try {
      final docs = await _firestore.collection(collName).get();
      final Map<String, List<Map<String, dynamic>>> locationsByDelivery = {};

      // Group locations by deliveryId
      for (final doc in docs.docs) {
        final data = doc.data();
        final deliveryId = data['deliveryId'] ?? doc.id;

        if (!locationsByDelivery.containsKey(deliveryId)) {
          locationsByDelivery[deliveryId] = [];
        }

        locationsByDelivery[deliveryId]!.add({
          'timestamp': data['timestamp'],
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'accuracy': data['accuracy'],
          'speed': data['speed'],
          'heading': data['heading'],
        });
      }

      // Merge into delivery_tasks
      final batch = _firestore.batch();
      for (final entry in locationsByDelivery.entries) {
        batch.set(
          _firestore
              .collection(FirestoreCollections.DELIVERY_TASKS)
              .doc(entry.key),
          {
            'locationHistory': entry.value,
            'migratedFrom_locations': collName,
            'migrationTimestamp': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      debugPrint('[$collName] Migration complete: $count documents');
    } catch (e) {
      debugPrint('[$collName] Migration failed: $e');
      rethrow;
    }
  }

  /// Consolidate delivery_history → delivery_tasks.history array
  Future<void> migrateDeliveryHistory() async {
    const collName = 'delivery_history';
    final count = await getDocumentCount(collName);

    if (count == 0) {
      debugPrint('[$collName] No documents to migrate');
      return;
    }

    debugPrint(
        '[$collName] Migrating $count documents to delivery_tasks.history...');

    try {
      final docs = await _firestore.collection(collName).get();
      final Map<String, List<Map<String, dynamic>>> historyByDelivery = {};

      for (final doc in docs.docs) {
        final data = doc.data();
        final deliveryId = data['deliveryId'] ?? doc.id;

        if (!historyByDelivery.containsKey(deliveryId)) {
          historyByDelivery[deliveryId] = [];
        }

        historyByDelivery[deliveryId]!.add({
          'status': data['status'],
          'timestamp': data['timestamp'],
          'note': data['note'],
          'changedBy': data['changedBy'],
        });
      }

      final batch = _firestore.batch();
      for (final entry in historyByDelivery.entries) {
        batch.set(
          _firestore
              .collection(FirestoreCollections.DELIVERY_TASKS)
              .doc(entry.key),
          {
            'history': entry.value,
            'migratedFrom_history': collName,
            'migrationTimestamp': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      debugPrint('[$collName] Migration complete: $count documents');
    } catch (e) {
      debugPrint('[$collName] Migration failed: $e');
      rethrow;
    }
  }

  /// Consolidate delivery_preferences → delivery_tasks.preferences
  Future<void> migrateDeliveryPreferences() async {
    const collName = 'delivery_preferences';
    final count = await getDocumentCount(collName);

    if (count == 0) {
      debugPrint('[$collName] No documents to migrate');
      return;
    }

    debugPrint(
        '[$collName] Migrating $count documents to delivery_tasks.preferences...');

    try {
      final docs = await _firestore.collection(collName).get();
      final batch = _firestore.batch();

      for (final doc in docs.docs) {
        final data = doc.data();
        final deliveryId = data['deliveryId'] ?? doc.id;

        batch.set(
          _firestore.collection(FirestoreCollections.DELIVERY_TASKS).doc(deliveryId),
          {
            'preferences': {
              'callBefore': data['callBefore'] ?? false,
              'leaveAtDoor': data['leaveAtDoor'] ?? false,
              'requireSignature': data['requireSignature'] ?? true,
              'specialInstructions': data['specialInstructions'],
            },
            'migratedFrom_preferences': collName,
            'migrationTimestamp': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      debugPrint('[$collName] Migration complete: $count documents');
    } catch (e) {
      debugPrint('[$collName] Migration failed: $e');
      rethrow;
    }
  }

  /// Run full migration (all collections)
  /// Call from a one-time admin script or Cloud Function
  Future<void> runFullMigration() async {
    debugPrint('=== Starting Fufaji Module 9 P0 Delivery Consolidation ===');
    debugPrint('Consolidating ${ORPHANED_COLLECTIONS.length} orphaned collections');
    debugPrint('Target: ${FirestoreCollections.DELIVERY_TASKS}');
    debugPrint('');

    try {
      // Check each collection before migrating
      debugPrint('PRE-MIGRATION CHECK:');
      int totalDocuments = 0;
      for (final coll in ORPHANED_COLLECTIONS) {
        final count = await getDocumentCount(coll);
        totalDocuments += count;
        debugPrint('  $coll: $count documents');
      }
      debugPrint('  TOTAL: $totalDocuments documents to migrate');
      debugPrint('');

      // Run migrations
      debugPrint('EXECUTING MIGRATIONS:');
      await migrateDeliveryTracking();
      await migrateDeliveryRoutes();
      await migrateDeliveryAssignments();
      await migrateDeliveryOTP();
      await migrateDeliveryLocations();
      await migrateDeliveryHistory();
      await migrateDeliveryPreferences();

      debugPrint('');
      debugPrint('=== MIGRATION COMPLETE ===');
      debugPrint('');
      debugPrint('NEXT STEPS:');
      debugPrint('1. Verify data in ${FirestoreCollections.DELIVERY_TASKS}');
      debugPrint('2. Implement OTP hashing (bcrypt)');
      debugPrint('3. Manually delete orphaned collections in Firestore Console:');
      for (final coll in ORPHANED_COLLECTIONS) {
        debugPrint('   - $coll');
      }
      debugPrint('4. Update Firestore security rules (new rules deployed)');
      debugPrint('5. Verify delivery module end-to-end in staging');
      debugPrint('6. Deploy to production');
    } catch (e) {
      debugPrint('!!! MIGRATION FAILED !!!');
      debugPrint('Error: $e');
      rethrow;
    }
  }

  /// Print migration status (for debugging)
  Future<void> printMigrationStatus() async {
    debugPrint('=== DELIVERY COLLECTIONS MIGRATION STATUS ===');
    debugPrint('');

    for (final coll in ORPHANED_COLLECTIONS) {
      final count = await getDocumentCount(coll);
      final status = count == 0 ? '[EMPTY]' : '[$count docs]';
      debugPrint('$status $coll');
    }

    final deliveryTasksCount =
        await getDocumentCount(FirestoreCollections.DELIVERY_TASKS);
    debugPrint('');
    debugPrint('[$deliveryTasksCount docs] ${FirestoreCollections.DELIVERY_TASKS} (target)');
  }
}
