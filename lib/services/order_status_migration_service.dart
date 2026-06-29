import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants/order_status.dart';

/// Migration service to normalize order status values across all orders
///
/// PROBLEM FIXED:
/// Before: Orders had inconsistent status values:
/// - 'pending', 'confirmed', 'processing', 'packed', 'shipped', 'delivered'
/// - 'OrderStatus.pending', 'OrderStatus.packed', 'OrderStatus.outForDelivery'
/// - 'preparing', 'ready_for_pickup', 'outForDelivery', 'completed'
///
/// AFTER MIGRATION:
/// All orders use unified enum values from OrderStatus enum:
/// - pending, confirmed, processing, packed, shipped, delivered, cancelled, refunded
///
/// This migration is safe and idempotent - can be run multiple times.
class OrderStatusMigrationService {
  static final OrderStatusMigrationService _instance = OrderStatusMigrationService._internal();
  factory OrderStatusMigrationService() => _instance;
  OrderStatusMigrationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Run full migration on all orders in Firestore
  /// Returns count of orders migrated
  Future<int> migrateAllOrders() async {
    try {
      int migratedCount = 0;
      int pageSize = 100;
      DocumentSnapshot? lastDoc;

      while (true) {
        Query query = _db.collection('orders').limit(pageSize);

        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }

        final snap = await query.get();
        if (snap.docs.isEmpty) break;

        final batch = _db.batch();

        for (final doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final currentStatus = data['status'] as String?;

          if (currentStatus != null) {
            final normalizedStatus = OrderStatus.fromString(currentStatus).firestoreValue;

            // Only update if it changed
            if (currentStatus != normalizedStatus) {
              batch.update(doc.reference, {
                'status': normalizedStatus,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              migratedCount++;

              debugPrint('[OrderStatusMigration] Migrating order ${doc.id}: $currentStatus → $normalizedStatus');
            }
          }
        }

        if (migratedCount > 0) {
          await batch.commit();
        }

        lastDoc = snap.docs.last;

        // Stop if we got fewer results than page size
        if (snap.docs.length < pageSize) break;
      }

      debugPrint('[OrderStatusMigration] Migration complete. Total migrated: $migratedCount');
      return migratedCount;
    } catch (e) {
      debugPrint('[OrderStatusMigration] Migration failed: $e');
      rethrow;
    }
  }

  /// Migrate status history entries for a single order
  Future<int> migrateOrderStatusHistory(String orderId) async {
    try {
      final orderSnap = await _db.collection('orders').doc(orderId).get();
      if (!orderSnap.exists) {
        throw Exception('Order not found: $orderId');
      }

      final data = orderSnap.data() as Map<String, dynamic>;
      final statusHistory = data['statusHistory'] as List? ?? [];

      int migratedCount = 0;
      final updatedHistory = <Map<String, dynamic>>[];

      for (final entry in statusHistory) {
        final entryMap = entry as Map<String, dynamic>;
        final oldStatus = entryMap['status'] as String?;

        if (oldStatus != null) {
          final normalizedStatus = OrderStatus.fromString(oldStatus).firestoreValue;

          if (oldStatus != normalizedStatus) {
            migratedCount++;
            debugPrint('[OrderStatusMigration] Migrating history entry: $oldStatus → $normalizedStatus');
          }

          updatedHistory.add({
            ...entryMap,
            'status': normalizedStatus,
          });
        }
      }

      if (migratedCount > 0) {
        await _db.collection('orders').doc(orderId).update({
          'statusHistory': updatedHistory,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('[OrderStatusMigration] Migrated $migratedCount history entries for order $orderId');
      }

      return migratedCount;
    } catch (e) {
      debugPrint('[OrderStatusMigration] Failed to migrate history for $orderId: $e');
      rethrow;
    }
  }

  /// Verify migration was successful
  /// Returns list of any orders with invalid statuses
  Future<List<String>> verifyMigration() async {
    try {
      final invalidOrders = <String>[];
      int pageSize = 100;
      DocumentSnapshot? lastDoc;

      while (true) {
        Query query = _db.collection('orders').limit(pageSize);

        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }

        final snap = await query.get();
        if (snap.docs.isEmpty) break;

        for (final doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final currentStatus = data['status'] as String?;

          if (currentStatus != null) {
            // Try to parse as OrderStatus enum
            try {
              OrderStatus.fromString(currentStatus);
            } catch (e) {
              invalidOrders.add('${doc.id}: $currentStatus');
              debugPrint('[OrderStatusMigration] Invalid status in order ${doc.id}: $currentStatus');
            }
          }
        }

        lastDoc = snap.docs.last;

        if (snap.docs.length < pageSize) break;
      }

      if (invalidOrders.isEmpty) {
        debugPrint('[OrderStatusMigration] Verification passed - all orders have valid statuses');
      } else {
        debugPrint('[OrderStatusMigration] Verification FAILED - ${invalidOrders.length} orders have invalid statuses');
      }

      return invalidOrders;
    } catch (e) {
      debugPrint('[OrderStatusMigration] Verification failed: $e');
      rethrow;
    }
  }

  /// Get migration statistics
  Future<Map<String, int>> getMigrationStats() async {
    try {
      final stats = <String, int>{};
      final snap = await _db.collection('orders').get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final status = data['status'] as String?;

        if (status != null) {
          stats[status] = (stats[status] ?? 0) + 1;
        }
      }

      debugPrint('[OrderStatusMigration] Status distribution: $stats');
      return stats;
    } catch (e) {
      debugPrint('[OrderStatusMigration] Failed to get stats: $e');
      rethrow;
    }
  }
}
