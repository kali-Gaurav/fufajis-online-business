import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import 'sqlite_service.dart';

/// Queue Status Enum
enum QueueItemStatus {
  queued,      // Waiting to sync
  syncing,     // Currently being uploaded
  synced,      // Successfully synced to Firestore
  failed,      // Sync failed, waiting for retry
  conflicted,  // Conflict resolution needed
}

/// Offline Order Queue Service
/// Manages local SQLite storage of orders created while offline
/// and syncs them to Firestore when connectivity is restored.
///
/// Features:
/// - Local SQLite persistence (offline_orders table)
/// - Auto-sync on network reconnect
/// - Exponential backoff retry strategy (1s → 2s → 4s → give up)
/// - Conflict resolution (server-wins merge strategy)
/// - Queue stats and monitoring
/// - Automatic cleanup of synced orders after 7 days
class OfflineOrderQueueService {
  static final OfflineOrderQueueService _instance =
      OfflineOrderQueueService._internal();
  factory OfflineOrderQueueService() => _instance;
  OfflineOrderQueueService._internal();

  SqliteService? _sqliteOverride;
  Connectivity? _connectivityOverride;
  FirebaseFirestore? _firestoreOverride;

  SqliteService get _sqlite => _sqliteOverride ??= SqliteService();
  Connectivity get _connectivity => _connectivityOverride ??= Connectivity();
  FirebaseFirestore get _firestore => _firestoreOverride ??= FirebaseFirestore.instance;

  set firestore(FirebaseFirestore value) => _firestoreOverride = value;
  set sqlite(SqliteService value) => _sqliteOverride = value;
  set connectivity(Connectivity value) => _connectivityOverride = value;

  bool _isInitialized = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _autoSyncTimer;

  // Observable status for UI
  final ValueNotifier<int> queuedCount = ValueNotifier<int>(0);
  final ValueNotifier<int> failedCount = ValueNotifier<int>(0);
  final ValueNotifier<int> syncedCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<String?> lastSyncError = ValueNotifier<String?>(null);
  final ValueNotifier<DateTime?> lastSyncTime = ValueNotifier<DateTime?>(null);

  // In-memory cache to reduce SQLite queries
  Map<String, Map<String, dynamic>> _queueCache = {};

  static const int _maxRetries = 3;
  static const Duration _initialBackoff = Duration(seconds: 1);

  /// Initialize the offline order queue service
  /// Creates offline_orders table if it doesn't exist
  /// Sets up connectivity listener and auto-sync timer
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _createOfflineOrdersTable();
      _isInitialized = true;
      await _loadQueueCache();
      await _refreshCounts();

      // Bootstrap with current connectivity
      final currentResults = await _connectivity.checkConnectivity();
      _checkConnectivity(currentResults);

      // Listen for connectivity changes
      _connectivitySubscription =
          _connectivity.onConnectivityChanged.listen(_checkConnectivity);

      // Set up periodic sync every 5 minutes
      _autoSyncTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _autoSyncIfOnline(),
      );

      debugPrint('[OfflineOrderQueueService] Initialized successfully');
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Init failed: $e');
      lastSyncError.value = 'Initialization failed: $e';
    }
  }

  /// Create offline_orders table schema
  Future<void> _createOfflineOrdersTable() async {
    try {
      final db = await _sqlite.database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS offline_orders (
          id TEXT PRIMARY KEY,
          order_json TEXT NOT NULL,
          status TEXT DEFAULT 'queued',
          retry_count INTEGER DEFAULT 0,
          last_retry_at INTEGER,
          firestore_id TEXT,
          conflict_resolution_data TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          synced_at INTEGER
        )
      ''');

      // Create index on status for faster queries
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_offline_orders_status
        ON offline_orders(status)
      ''');

      debugPrint('[OfflineOrderQueueService] Table created/verified');
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Failed to create table: $e');
      rethrow;
    }
  }

  /// Load queue cache from SQLite to reduce future queries
  Future<void> _loadQueueCache() async {
    try {
      final db = await _sqlite.database;
      final results = await db.query('offline_orders');
      _queueCache = {};
      for (var row in results) {
        final id = row['id'] as String;
        _queueCache[id] = Map<String, dynamic>.from(row);
      }
      debugPrint('[OfflineOrderQueueService] Cache loaded: ${_queueCache.length} items');
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Failed to load cache: $e');
    }
  }

  /// Check connectivity and trigger sync if online
  void _checkConnectivity(dynamic results) {
    bool isOnline = false;
    if (results is List) {
      isOnline = results.any((r) => r != ConnectivityResult.none);
    } else {
      isOnline = results != ConnectivityResult.none;
    }

    debugPrint('[OfflineOrderQueueService] Connectivity: ${isOnline ? 'ONLINE' : 'OFFLINE'}');
    if (isOnline) {
      syncQueuedOrders();
    }
  }

  /// Auto-sync if online (called by timer)
  Future<void> _autoSyncIfOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      bool isOnline = results.any((r) => r != ConnectivityResult.none);

      if (isOnline && queuedCount.value > 0) {
        await syncQueuedOrders();
      }
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Auto-sync check failed: $e');
    }
  }

  // ─────────────── QUEUE OPERATIONS ───────────────

  /// Add a new order to the offline queue
  /// Saves order to SQLite and updates cache
  Future<String> addOrderToQueue(OrderModel order) async {
    if (!_isInitialized) await init();

    try {
      final db = await _sqlite.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final rowData = {
        'id': order.id,
        'order_json': jsonEncode(order.toMap(), toEncodable: (val) {
          if (val is DateTime) return val.toIso8601String();
          if (val is Timestamp) return val.toDate().toIso8601String();
          if (val is GeoPoint) return {'latitude': val.latitude, 'longitude': val.longitude};
          return val.toString();
        }),
        'status': 'queued',
        'retry_count': 0,
        'created_at': now,
        'updated_at': now,
      };

      await db.insert('offline_orders', rowData);
      _queueCache[order.id] = rowData;
      await _refreshCounts();

      debugPrint('[OfflineOrderQueueService] Added order ${order.id} to queue');
      return order.id;
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Failed to add order: $e');
      lastSyncError.value = 'Failed to queue order: $e';
      rethrow;
    }
  }

  /// Get all queued orders from local database
  Future<List<OrderModel>> getQueuedOrders() async {
    if (!_isInitialized) await init();

    try {
      final db = await _sqlite.database;
      final results = await db.query(
        'offline_orders',
        where: 'status IN (?, ?)',
        whereArgs: ['queued', 'failed'],
      );

      return results.map((row) {
        final orderJson = jsonDecode(row['order_json'] as String) as Map<String, dynamic>;
        return OrderModel.fromMap(orderJson);
      }).toList();
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Failed to get queued orders: $e');
      return [];
    }
  }

  /// Get all orders in the queue regardless of status
  Future<List<OrderModel>> getAllQueuedOrders({String? status}) async {
    if (!_isInitialized) await init();

    try {
      final db = await _sqlite.database;
      List<Map<String, dynamic>> results;

      if (status != null) {
        results = await db.query(
          'offline_orders',
          where: 'status = ?',
          whereArgs: [status],
        );
      } else {
        results = await db.query('offline_orders');
      }

      return results.map((row) {
        final orderJson = jsonDecode(row['order_json'] as String);
        return OrderModel.fromMap(orderJson as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Failed to get all queued orders: $e');
      return [];
    }
  }

  /// Sync all queued orders to Firestore
  /// Returns number of successfully synced orders
  Future<int> syncQueuedOrders() async {
    if (!_isInitialized) await init();
    if (isSyncing.value) return 0; // Prevent concurrent syncs

    isSyncing.value = true;
    int syncedCount = 0;

    try {
      final orders = await getQueuedOrders();
      debugPrint('[OfflineOrderQueueService] Syncing ${orders.length} orders');

      for (final order in orders) {
        final success = await _syncSingleOrder(order);
        if (success) syncedCount++;
      }

      lastSyncTime.value = DateTime.now();
      lastSyncError.value = null;

      debugPrint(
        '[OfflineOrderQueueService] Sync complete: $syncedCount/${orders.length} successful',
      );
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Sync failed: $e');
      lastSyncError.value = 'Sync failed: $e';
    } finally {
      isSyncing.value = false;
      await _refreshCounts();
    }

    return syncedCount;
  }

  /// Sync a single order to Firestore
  /// Handles conflict resolution and retry logic
  Future<bool> _syncSingleOrder(OrderModel order) async {
    try {
      final db = await _sqlite.database;

      // Update status to syncing
      await _updateOrderStatus(order.id, 'syncing');

      // Check if order exists in Firestore (conflict detection)
      final firestoreDoc = await _firestore
          .collection('orders')
          .doc(order.id)
          .get();

      if (firestoreDoc.exists) {
        // Conflict: order exists on server - apply merge strategy
        await _resolveConflict(order, firestoreDoc.data() ?? {});
      } else {
        // No conflict: upload new order
        await _firestore
            .collection('orders')
            .doc(order.id)
            .set(order.toMap(), SetOptions(merge: true));
      }

      // Mark as synced
      await db.update(
        'offline_orders',
        {
          'status': 'synced',
          'retry_count': 0,
          'synced_at': DateTime.now().millisecondsSinceEpoch,
          'firestore_id': order.id,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [order.id],
      );

      _queueCache[order.id]?['status'] = 'synced';

      debugPrint('[OfflineOrderQueueService] Synced order ${order.id}');
      return true;
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Failed to sync order ${order.id}: $e');
      await _retryFailedOrder(order.id);
      return false;
    }
  }

  /// Resolve conflict when order exists in both local and Firestore
  /// Strategy: Server-wins merge (preserve server updates, add local timestamps)
  Future<void> _resolveConflict(
    OrderModel localOrder,
    Map<String, dynamic> serverData,
  ) async {
    try {
      final db = await _sqlite.database;
      final serverOrder = OrderModel.fromMap(serverData);

      // Merge strategy: server updates take precedence, but preserve local timestamps
      final mergedData = {
        ...localOrder.toMap(),
        'updatedAt': serverOrder.updatedAt,
        'status': serverOrder.status,
        'paymentStatus': serverOrder.paymentStatus,
        // Local metadata
        'syncedLocally': DateTime.now().toIso8601String(),
        'conflictResolvedAt': DateTime.now().toIso8601String(),
      };

      // Upload merged data
      await _firestore
          .collection('orders')
          .doc(localOrder.id)
          .set(mergedData, SetOptions(merge: true));

      // Store conflict resolution metadata
      await db.update(
        'offline_orders',
        {
          'status': 'synced',
          'conflict_resolution_data': jsonEncode({
            'conflictDetectedAt': DateTime.now().toIso8601String(),
            'resolution': 'server_wins_merge',
            'localUpdatedAt': localOrder.updatedAt.toIso8601String(),
            'serverUpdatedAt': serverOrder.updatedAt.toIso8601String(),
          }),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [localOrder.id],
      );

      debugPrint(
        '[OfflineOrderQueueService] Conflict resolved for ${localOrder.id}',
      );
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Conflict resolution failed: $e');
      rethrow;
    }
  }

  /// Retry a failed order with exponential backoff
  /// max 3 retries: 1s, 2s, 4s backoff
  Future<bool> retryFailedOrder(String orderId) async {
    if (!_isInitialized) await init();

    try {
      final order = await _getOrderFromQueue(orderId);
      if (order == null) {
        debugPrint('[OfflineOrderQueueService] Order $orderId not found');
        return false;
      }

      return await _syncSingleOrder(order);
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Retry failed: $e');
      return false;
    }
  }

  /// Retry failed order with exponential backoff logic
  Future<void> _retryFailedOrder(String orderId) async {
    try {
      final db = await _sqlite.database;
      final result = await db.query(
        'offline_orders',
        where: 'id = ?',
        whereArgs: [orderId],
      );

      if (result.isEmpty) return;

      final row = result.first;
      int retryCount = row['retry_count'] as int? ?? 0;
      retryCount++;

      if (retryCount > _maxRetries) {
        // Give up after max retries
        await db.update(
          'offline_orders',
          {
            'status': 'failed',
            'retry_count': retryCount,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [orderId],
        );
        _queueCache[orderId]?['status'] = 'failed';

        debugPrint(
          '[OfflineOrderQueueService] Max retries reached for $orderId',
        );
        return;
      }

      // Calculate backoff: 1s, 2s, 4s...
      final backoffMs = _initialBackoff.inMilliseconds * (1 << (retryCount - 1));

      await db.update(
        'offline_orders',
        {
          'status': 'queued',
          'retry_count': retryCount,
          'last_retry_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      _queueCache[orderId]?['status'] = 'queued';
      _queueCache[orderId]?['retry_count'] = retryCount;

      debugPrint(
        '[OfflineOrderQueueService] Scheduled retry #$retryCount for $orderId in ${backoffMs}ms',
      );

      // Schedule retry after backoff delay
      Future.delayed(Duration(milliseconds: backoffMs), () {
        syncQueuedOrders();
      });
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Retry scheduling failed: $e');
    }
  }

  /// Get a single order from the queue
  Future<OrderModel?> _getOrderFromQueue(String orderId) async {
    try {
      final db = await _sqlite.database;
      final results = await db.query(
        'offline_orders',
        where: 'id = ?',
        whereArgs: [orderId],
      );

      if (results.isEmpty) return null;

      final orderJson = jsonDecode(results.first['order_json'] as String);
      return OrderModel.fromMap(orderJson as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Failed to get order: $e');
      return null;
    }
  }

  /// Remove order from queue (after successful sync)
  Future<bool> removeFromQueue(String orderId) async {
    if (!_isInitialized) await init();

    try {
      final db = await _sqlite.database;
      final result = await db.delete(
        'offline_orders',
        where: 'id = ?',
        whereArgs: [orderId],
      );

      _queueCache.remove(orderId);
      await _refreshCounts();

      debugPrint('[OfflineOrderQueueService] Removed order $orderId from queue');
      return result > 0;
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Failed to remove order: $e');
      return false;
    }
  }

  /// Get queue statistics
  Future<QueueStats> getQueueStats() async {
    if (!_isInitialized) await init();

    try {
      final db = await _sqlite.database;

      final queuedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM offline_orders WHERE status = ?',
        ['queued'],
      );
      final queued = (queuedResult.first['count'] as int?) ?? 0;

      final failedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM offline_orders WHERE status = ?',
        ['failed'],
      );
      final failed = (failedResult.first['count'] as int?) ?? 0;

      final syncedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM offline_orders WHERE status = ?',
        ['synced'],
      );
      final synced = (syncedResult.first['count'] as int?) ?? 0;

      final totalSizeResult = await db.rawQuery(
        'SELECT SUM(LENGTH(order_json)) as total FROM offline_orders',
      );
      final totalSizeBytes = (totalSizeResult.first['total'] as int?) ?? 0;

      return QueueStats(
        queuedCount: queued,
        failedCount: failed,
        syncedCount: synced,
        totalSize: totalSizeBytes,
        lastSyncTime: lastSyncTime.value,
      );
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Failed to get queue stats: $e');
      return QueueStats(
        queuedCount: 0,
        failedCount: 0,
        syncedCount: 0,
        totalSize: 0,
      );
    }
  }

  /// Update order status in queue
  Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      final db = await _sqlite.database;
      await db.update(
        'offline_orders',
        {
          'status': status,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      _queueCache[orderId]?['status'] = status;
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Failed to update status: $e');
    }
  }

  /// Refresh UI-bound counts from database
  Future<void> _refreshCounts() async {
    try {
      final db = await _sqlite.database;

      final qResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM offline_orders WHERE status = ?',
        ['queued'],
      );
      queuedCount.value = (qResult.first['count'] as int?) ?? 0;

      final fResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM offline_orders WHERE status = ?',
        ['failed'],
      );
      failedCount.value = (fResult.first['count'] as int?) ?? 0;

      final sResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM offline_orders WHERE status = ?',
        ['synced'],
      );
      syncedCount.value = (sResult.first['count'] as int?) ?? 0;
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Failed to refresh counts: $e');
    }
  }

  /// Clear all orders from queue (emergency cleanup)
  /// Use with caution!
  Future<int> clearQueue() async {
    if (!_isInitialized) await init();

    try {
      final db = await _sqlite.database;
      final result = await db.delete('offline_orders');
      _queueCache.clear();
      await _refreshCounts();

      debugPrint('[OfflineOrderQueueService] Cleared $result orders from queue');
      return result;
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Failed to clear queue: $e');
      return 0;
    }
  }

  /// Cleanup old synced orders (older than 7 days)
  Future<int> cleanupOldSyncedOrders() async {
    if (!_isInitialized) await init();

    try {
      final db = await _sqlite.database;
      final sevenDaysAgoMs =
          DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;

      final result = await db.delete(
        'offline_orders',
        where: 'status = ? AND synced_at < ?',
        whereArgs: ['synced', sevenDaysAgoMs],
      );

      await _refreshCounts();
      debugPrint('[OfflineOrderQueueService] Cleaned up $result old synced orders');
      return result;
    } catch (e) {
      debugPrint('[OfflineOrderQueueService] Cleanup failed: $e');
      return 0;
    }
  }

  /// Dispose resources and cleanup
  void dispose() {
    _connectivitySubscription?.cancel();
    _autoSyncTimer?.cancel();
    debugPrint('[OfflineOrderQueueService] Disposed');
  }
}

/// Queue statistics data class
class QueueStats {
  final int queuedCount;
  final int failedCount;
  final int syncedCount;
  final int totalSize; // bytes
  final DateTime? lastSyncTime;

  QueueStats({
    required this.queuedCount,
    required this.failedCount,
    required this.syncedCount,
    required this.totalSize,
    this.lastSyncTime,
  });

  int get totalCount => queuedCount + failedCount + syncedCount;
  bool get hasPendingOrders => queuedCount > 0 || failedCount > 0;

  @override
  String toString() {
    return 'QueueStats(queued: $queuedCount, failed: $failedCount, synced: $syncedCount, size: ${(totalSize / 1024).toStringAsFixed(2)}KB)';
  }
}
