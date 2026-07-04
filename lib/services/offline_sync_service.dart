import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import 'order_service.dart';
import 'sqlite_service.dart';
import 'offline_order_queue_service.dart';
import 'whatsapp_notification_service.dart';
import 'rds_database_service.dart';
import 'notification_retry_service.dart';

enum SyncActionType {
  safeOffline,
  onlineRequired
}

/// Offline Sync Service — Fufaji
/// Processes two queues via SQLite:
///  • orders_queue   — order status updates
///  • employee_queue — inventory / attendance / damage / transfer actions
/// FEFO conflict resolution for employee actions (server wins if newer).
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  final SqliteService _sqlite = SqliteService();
  final OrderService _orderService = OrderService();
  final Connectivity _connectivity = Connectivity();

  bool _isInitialized = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Observable status flags consumed by UI
  final ValueNotifier<int> pendingSyncCount = ValueNotifier<int>(0);
  final ValueNotifier<int> pendingEmployeeSyncCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  /// Initialize SQLite and start connectivity listener
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _sqlite.database; // ensures tables are created
      _isInitialized = true;
      await _refreshCounts();

      // Bootstrap with current connectivity state
      final currentResults = await _connectivity.checkConnectivity();
      _checkStatus(currentResults);

      // React to future connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
        _checkStatus(results);
      });

      debugPrint('[OfflineSyncService] Initialized. Pending: ${pendingSyncCount.value}');
    } catch (e) {
      debugPrint('[OfflineSyncService] Failed to initialize: $e');
    }
  }

  void _checkStatus(dynamic results) {
    bool online = false;
    if (results is List) {
      online = results.any((r) => r != ConnectivityResult.none);
    } else {
      online = results != ConnectivityResult.none;
    }
    isOnline.value = online;
    debugPrint('[OfflineSyncService] Online = $online');
    if (online) processQueue();
  }

  // ─────────────── ENQUEUE ───────────────

  /// Enqueue an order status update for offline sync (DEPRECATED: Order transitions require active connection)
  @deprecated
  Future<void> enqueueStatusUpdate(
    String orderId,
    String status, {
    String? otp,
    bool otpVerified = false,
  }) async {
    throw UnsupportedError('Order status updates require an online connection and cannot be enqueued offline.');
  }

  /// Enqueue a new order placement for offline sync (DEPRECATED: Order placement requires active connection)
  @deprecated
  Future<void> enqueueOrderPlacement({
    required String orderId,
    required Map<String, dynamic> orderData,
  }) async {
    throw UnsupportedError('Order placement requires an online connection and cannot be enqueued offline.');
  }

  /// Enqueue an employee inventory/attendance/damage/transfer action
  Future<void> enqueueEmployeeAction({
    required String actionType,
    required String shopId,
    required String branchId,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      if (!_isInitialized) await init();
      final taskId = 'emp_${DateTime.now().millisecondsSinceEpoch}_${actionType}_$documentId';
      await _sqlite.enqueuePendingSync(
        id: taskId,
        actionType: actionType,
        collection: _collectionForAction(actionType),
        documentId: documentId,
        data: {
          'id': taskId,
          'actionType': actionType,
          'shopId': shopId,
          'branchId': branchId,
          'documentId': documentId,
          'data': data,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      await _refreshCounts();
      debugPrint('[OfflineSyncService] Enqueued employee action "$actionType" for $documentId');
      if (isOnline.value) processQueue();
    } catch (e) {
      debugPrint('[OfflineSyncService] Failed to enqueue employee action: $e');
    }
  }

  // ─────────────── PROCESS ───────────────

  /// Orchestrates processing of all pending queues
  Future<void> processQueue() async {
    await _processOrderQueue();
    await _processEmployeeQueue();
    await _processRiderLocationsQueue();
    await _processRiderShiftsQueue();
    await _processRDSWriteQueue();
  }

  /// Process pending order status updates and placements
  Future<void> _processOrderQueue() async {
    if (!_isInitialized || !isOnline.value) return;
    final items = await _sqlite.getPendingSyncItems();
    final orderItems = items
        .where((i) => i['actionType'] == 'order_status' || i['actionType'] == 'order_placement')
        .toList();
    if (orderItems.isEmpty) return;

    debugPrint('[OfflineSyncService] Processing ${orderItems.length} order tasks...');

    final now = DateTime.now().millisecondsSinceEpoch;

    for (final item in orderItems) {
      if (!isOnline.value) break;

      final retryCount = (item['retryCount'] as int?) ?? 0;
      final lastTried = (item['last_tried_at'] as int?) ?? 0;

      // Exponential backoff: skip if we shouldn't retry yet
      // 2^retryCount * 2 seconds. e.g., 2s, 4s, 8s, 16s...
      if (retryCount > 0) {
        final backoffMs = (1 << retryCount) * 2000;
        if (now < lastTried + backoffMs) {
          continue;
        }
      }

      final data = Map<String, dynamic>.from(item['data'] as Map);
      final actionType = item['actionType'] as String;
      final orderId = data['orderId'] as String? ?? '';

      try {
        if (actionType == 'order_status') {
          final status = data['status'] as String? ?? '';
          await _orderService.updateOrderStatus(orderId, status);
          debugPrint('[OfflineSyncService] Synced order status $orderId → $status');
        } else if (actionType == 'order_placement') {
          final orderData = Map<String, dynamic>.from(data['orderData'] as Map);
          await _orderService.createOrder(
            OrderModel.fromMap(orderData),
          ); // Place order handles idempotency internally
          debugPrint('[OfflineSyncService] Synced new order placement $orderId');
        }

        await _sqlite.markSyncDone(item['id'] as String);
      } catch (e) {
        await _sqlite.markSyncFailed(item['id'] as String);
        debugPrint('[OfflineSyncService] Failed to sync order $orderId: $e');
        continue; // proceed to next task without blocking queue
      }
    }
    await _refreshCounts();
  }

  /// Process pending employee actions with FEFO conflict resolution
  Future<void> _processEmployeeQueue() async {
    if (!_isInitialized || !isOnline.value) return;
    final items = await _sqlite.getPendingSyncItems();
    final empItems = items
        .where((i) => i['actionType'] != 'order_status' && i['actionType'] != 'order_placement')
        .toList();
    if (empItems.isEmpty) return;

    debugPrint('[OfflineSyncService] Processing ${empItems.length} employee tasks...');
    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final item in empItems) {
      if (!isOnline.value) break;

      final retryCount = (item['retryCount'] as int?) ?? 0;
      final lastTried = (item['last_tried_at'] as int?) ?? 0;

      if (retryCount > 0) {
        final backoffMs = (1 << retryCount) * 2000;
        if (now < lastTried + backoffMs) {
          continue;
        }
      }

      final data = Map<String, dynamic>.from(item['data'] as Map);
      final actionType = data['actionType'] as String? ?? '';
      final shopId = data['shopId'] as String? ?? '';
      final branchId = data['branchId'] as String? ?? '';
      final documentId = data['documentId'] as String? ?? '';
      final rawLocalData = Map<String, dynamic>.from(data['data'] as Map? ?? {});
      final localData = _convertDateTimeToTimestamp(rawLocalData);
      final localTimestamp =
          DateTime.tryParse(data['timestamp'] as String? ?? '') ?? DateTime.now();

      final collectionPath = _collectionForAction(actionType);
      if (collectionPath.isEmpty) {
        debugPrint('[OfflineSyncService] Unknown action type $actionType. Discarding.');
        await _sqlite.markSyncDone(item['id'] as String);
        continue;
      }

      try {
        final docRef = firestore
            .collection('shops')
            .doc(shopId)
            .collection('branches')
            .doc(branchId)
            .collection(collectionPath)
            .doc(documentId);

        final snapshot = await docRef.get();
        bool shouldWrite = true;
        bool isMergeDelta = false;

        // Dynamic Conflict Resolution
        if (snapshot.exists) {
          final serverData = snapshot.data();
          if (serverData != null) {
            final serverModified = serverData['lastModified'] is Timestamp
                ? (serverData['lastModified'] as Timestamp).toDate()
                : DateTime.tryParse(serverData['lastModified']?.toString() ?? '');

            final strategy = _getConflictStrategy(collectionPath);

            if (strategy == 'SERVER_AUTHORITY') {
              // If server is modified at all after local, server wins.
              if (serverModified != null && serverModified.isAfter(localTimestamp)) {
                shouldWrite = false;
              }
            } else if (strategy == 'LAST_WRITE_WINS') {
              // We assume local is the last write if localTimestamp > serverModified
              if (serverModified != null && serverModified.isAfter(localTimestamp)) {
                shouldWrite = false;
              }
            } else if (strategy == 'VERSION_BASED') {
              final serverVersion = serverData['documentVersion'] as int? ?? 1;
              final localVersion = localData['documentVersion'] as int? ?? 1;
              if (serverVersion >= localVersion) {
                shouldWrite = false;
              }
            } else if (strategy == 'MERGE_DELTA') {
              // We will merge quantity differences instead of rejecting
              isMergeDelta = true;
              shouldWrite = true;
            }

            if (!shouldWrite && !isMergeDelta) {
              debugPrint(
                '[OfflineSyncService] Conflict: Server won using strategy $strategy for $documentId. Writing alert.',
              );
              await _writeConflictAlert(
                firestore: firestore,
                shopId: shopId,
                branchId: branchId,
                documentId: documentId,
                actionType: actionType,
                localTimestamp: localTimestamp,
                localData: localData,
                serverData: serverData,
                serverModified: serverModified ?? DateTime.now(),
              );
            }
          }
        }

        if (shouldWrite) {
          localData['lastModified'] = Timestamp.fromDate(localTimestamp);
          localData['lastSync'] = FieldValue.serverTimestamp();

          if (isMergeDelta && snapshot.exists) {
            // Example merge delta logic for inventory audits
            final serverData = snapshot.data()!;
            final serverQty = serverData['quantity'] as int? ?? 0;
            final localQty = localData['quantity'] as int? ?? 0;
            final delta = localQty; // Assuming localQty represents the adjustment
            localData['quantity'] = serverQty + delta;
          }

          await docRef.set(localData, SetOptions(merge: true));

          // Adjust stock for inventory mutations
          if (actionType == 'receive' || actionType == 'damage' || actionType == 'return') {
            await _adjustStock(firestore, shopId, branchId, localData, actionType);
          }
        }

        await _sqlite.markSyncDone(item['id'] as String);
        debugPrint('[OfflineSyncService] Employee sync complete: $actionType / $documentId');
      } catch (e) {
        await _sqlite.markSyncFailed(item['id'] as String);
        debugPrint(
          '[OfflineSyncService] Failed to sync employee action $actionType / $documentId: $e',
        );
        continue;
      }
    }
    await _refreshCounts();
  }

  // ─────────────── HELPERS ───────────────

  String _getConflictStrategy(String collection) {
    switch (collection) {
      case 'orders':
        return 'SERVER_AUTHORITY';
      case 'wallet_transactions':
        return 'SERVER_AUTHORITY';
      case 'users':
        return 'LAST_WRITE_WINS';
      case 'delivery_tasks':
        return 'LAST_WRITE_WINS';
      case 'products':
        return 'VERSION_BASED';
      case 'inventory_batches':
        return 'MERGE_DELTA';
      case 'inventory_audits':
        return 'MERGE_DELTA';
      case 'damage_reports':
        return 'MERGE_DELTA';
      default:
        return 'SERVER_AUTHORITY';
    }
  }

  String _collectionForAction(String actionType) {
    switch (actionType) {
      case 'receive':
        return 'inventory_batches';
      case 'audit':
        return 'inventory_audits';
      case 'damage':
        return 'damage_reports';
      case 'attendance':
        return 'attendance';
      case 'return':
        return 'returns';
      case 'transfer':
        return 'transfers';
      default:
        return '';
    }
  }

  Future<void> _adjustStock(
    FirebaseFirestore firestore,
    String shopId,
    String branchId,
    Map<String, dynamic> localData,
    String actionType,
  ) async {
    final productId = localData['productId'] as String? ?? '';
    int quantity = (localData['quantity'] as int?) ?? 0;
    if (actionType == 'damage') quantity = -quantity;
    if (productId.isEmpty || quantity == 0) return;

    final productRef = firestore.collection('products').doc(productId);

    try {
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(productRef);
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data != null) {
            final Map<dynamic, dynamic> branchStockMap = data['branchStock'] as Map? ?? {};
            final targetBranchId = (branchId.isEmpty || branchId == 'primary')
                ? 'primary'
                : branchId;

            int currentBranchStock = 0;
            if (branchStockMap.containsKey(targetBranchId)) {
              currentBranchStock = (branchStockMap[targetBranchId] ?? 0) as int;
            } else if (targetBranchId == 'primary' || branchStockMap.isEmpty) {
              currentBranchStock = (data['stockQuantity'] ?? 0) as int;
            }

            final newBranchStock = currentBranchStock + quantity;
            final Map<String, int> updatedBranchStock = Map<String, int>.from(
              branchStockMap.map((k, v) => MapEntry(k.toString(), v as int)),
            );
            updatedBranchStock[targetBranchId] = newBranchStock;

            // Calculate new global stock for backward compatibility
            int newGlobalStock = 0;
            if (updatedBranchStock.containsKey('primary')) {
              newGlobalStock = updatedBranchStock['primary']!;
            } else {
              newGlobalStock = updatedBranchStock.values.fold(0, (total, val) => total + val);
            }

            transaction.update(productRef, {
              'branchStock': updatedBranchStock,
              'stockQuantity': newGlobalStock,
              'isAvailable': newGlobalStock > 0 || updatedBranchStock.values.any((val) => val > 0),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });
      debugPrint(
        '[OfflineSyncService] Adjusted stock globally for product $productId by $quantity',
      );
    } catch (e) {
      debugPrint('[OfflineSyncService] Error performing transaction-based stock adjustment: $e');
      rethrow;
    }
  }

  Future<void> _writeConflictAlert({
    required FirebaseFirestore firestore,
    required String shopId,
    required String branchId,
    required String documentId,
    required String actionType,
    required DateTime localTimestamp,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> serverData,
    required DateTime serverModified,
  }) async {
    final alertId = 'conflict_${DateTime.now().millisecondsSinceEpoch}_$documentId';
    final alertRef = firestore
        .collection('shops')
        .doc(shopId)
        .collection('branches')
        .doc(branchId)
        .collection('inventory_alerts')
        .doc(alertId);

    final details =
        'Conflict: Offline $actionType update ($documentId) at ${localTimestamp.toIso8601String()} '
        'was superseded by newer server data at ${serverModified.toIso8601String()}.';

    await alertRef.set({
      'id': alertId,
      'type': 'sync_conflict',
      'actionType': actionType,
      'documentId': documentId,
      'message': details,
      'localData': localData,
      'serverData': serverData,
      'resolved': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Notify manager via WhatsApp (with escalation chain)
    try {
      final phone = await _resolveManagerPhone(firestore, shopId, branchId);
      if (phone.isNotEmpty) {
        await WhatsAppNotificationService.sendConflictAlert(
          phoneNumber: phone.phoneNumber,
          managerName: phone.name,
          actionType: actionType,
          documentId: documentId,
          details: details,
        );
      }
    } catch (waError) {
      debugPrint('[OfflineSyncService] WhatsApp conflict alert failed: $waError');
    }
  }

  Future<_ContactInfo> _resolveManagerPhone(
    FirebaseFirestore firestore,
    String shopId,
    String branchId,
  ) async {
    final branchSnap = await firestore
        .collection('shops')
        .doc(shopId)
        .collection('branches')
        .doc(branchId)
        .get();

    if (!branchSnap.exists || branchSnap.data() == null) {
      return const _ContactInfo(
        phoneNumber: String.fromEnvironment('WHATSAPP_OPERATIONS_PHONE', defaultValue: ''),
        name: 'Global Operations Support',
      );
    }

    final bd = branchSnap.data()!;

    // 1. Manager
    final managerId = bd['managerId'] as String? ?? '';
    if (managerId.isNotEmpty) {
      final m = await firestore.collection('users').doc(managerId).get();
      if (m.exists) {
        final p = m.data()?['phoneNumber'] as String? ?? '';
        if (p.isNotEmpty) {
          return _ContactInfo(phoneNumber: p, name: (m.data()?['name'] as String?) ?? 'Manager');
        }
      }
    }

    // 2. Assistant Manager
    final assistId = bd['assistantManagerId'] as String? ?? '';
    if (assistId.isNotEmpty) {
      final a = await firestore.collection('users').doc(assistId).get();
      if (a.exists) {
        final p = a.data()?['phoneNumber'] as String? ?? '';
        if (p.isNotEmpty) {
          return _ContactInfo(
            phoneNumber: p,
            name: a.data()?['name'] as String? ?? 'Asst. Manager',
          );
        }
      }
    }

    // 3. Branch contact
    final contact = bd['contactPhone'] as String? ?? '';
    if (contact.isNotEmpty) {
      return _ContactInfo(
        phoneNumber: contact,
        name: bd['branchName'] as String? ?? 'Branch Manager',
      );
    }

    // 4. Escalation
    final escalation = bd['escalationPhone'] as String? ?? '';
    if (escalation.isNotEmpty) {
      return _ContactInfo(phoneNumber: escalation, name: 'Operations Escalation Desk');
    }

    // 5. Global fallback
    return const _ContactInfo(
      phoneNumber: String.fromEnvironment(
        'WHATSAPP_OPERATIONS_PHONE',
        defaultValue: '919876543210',
      ),
      name: 'Global Operations Support',
    );
  }

  /// Converts DateTime values and ISO-8601 strings to Firestore Timestamps recursively
  Map<String, dynamic> _convertDateTimeToTimestamp(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value is DateTime) {
        result[key] = Timestamp.fromDate(value);
      } else if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null && value.length >= 19 && (value.contains('-') || value.contains(':'))) {
          result[key] = Timestamp.fromDate(parsed);
        } else {
          result[key] = value;
        }
      } else if (value is Map) {
        result[key] = _convertDateTimeToTimestamp(Map<String, dynamic>.from(value));
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is DateTime) return Timestamp.fromDate(item);
          if (item is String) {
            final p = DateTime.tryParse(item);
            if (p != null && item.length >= 19) return Timestamp.fromDate(p);
          }
          if (item is Map) {
            return _convertDateTimeToTimestamp(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  Future<void> _processRiderLocationsQueue() async {
    if (!_isInitialized || !isOnline.value) return;
    try {
      final unsynced = await _sqlite.getUnsyncedLocations();
      if (unsynced.isEmpty) return;

      debugPrint('[OfflineSyncService] Syncing ${unsynced.length} offline rider locations...');
      final firestore = FirebaseFirestore.instance;
      final rds = RDSDatabaseService();

      final List<String> syncedIds = [];

      for (final loc in unsynced) {
        if (!isOnline.value) break;

        final deliveryId = loc['delivery_id'] as String;
        final latitude = (loc['latitude'] as num).toDouble();
        final longitude = (loc['longitude'] as num).toDouble();
        final timestampMs = loc['timestamp'] as int;
        final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);

        try {
          // 1. Sync to Firestore delivery_locations
          await firestore.collection('delivery_locations').add({
            'deliveryId': deliveryId,
            'latitude': latitude,
            'longitude': longitude,
            'timestamp': Timestamp.fromDate(timestamp),
          });

          // 2. Sync to SQL delivery_status_logs
          await rds.query(
            '''
            INSERT INTO delivery_status_logs (delivery_id, order_id, to_status, latitude, longitude, created_at)
            VALUES (\$1, \$2, \$3, \$4, \$5, \$6)
            ''',
            params: [
              deliveryId,
              deliveryId, // using deliveryId as orderId fallback if not resolved
              'LOCATION_PING',
              latitude,
              longitude,
              timestamp.toIso8601String(),
            ],
            allowWrite: true,
          );

          syncedIds.add(loc['id'] as String);
        } catch (e) {
          debugPrint('[OfflineSyncService] Error syncing location record ${loc['id']}: $e');
        }
      }

      if (syncedIds.isNotEmpty) {
        await _sqlite.markLocationsSynced(syncedIds);
        await _sqlite.clearSyncedLocations();
      }
    } catch (e) {
      debugPrint('[OfflineSyncService] Error in _processRiderLocationsQueue: $e');
    }
  }

  Future<void> _processRiderShiftsQueue() async {
    if (!_isInitialized || !isOnline.value) return;
    try {
      final unsynced = await _sqlite.getUnsyncedRiderShifts();
      if (unsynced.isEmpty) return;

      debugPrint('[OfflineSyncService] Syncing ${unsynced.length} offline rider shifts...');
      final firestore = FirebaseFirestore.instance;
      final rds = RDSDatabaseService();

      for (final shift in unsynced) {
        if (!isOnline.value) break;

        final id = shift['id'] as String;
        final riderId = shift['rider_id'] as String;
        final branchId = shift['branch_id'] as String;
        final currentState = shift['current_state'] as String;
        final startedAtMs = shift['started_at'] as int;
        final endedAtMs = shift['ended_at'] as int?;

        final startedAt = DateTime.fromMillisecondsSinceEpoch(startedAtMs);
        final endedAt = endedAtMs != null ? DateTime.fromMillisecondsSinceEpoch(endedAtMs) : null;

        try {
          // 1. Sync to Firestore
          await firestore.collection('rider_shifts').doc(id).set({
            'id': id,
            'riderId': riderId,
            'branchId': branchId,
            'currentState': currentState,
            'startedAt': Timestamp.fromDate(startedAt),
            'endedAt': endedAt != null ? Timestamp.fromDate(endedAt) : null,
            'totalDeliveries': shift['total_deliveries'] ?? 0,
            'totalEarnings': shift['total_earnings'] ?? 0.0,
            'totalDistance': shift['total_distance'] ?? 0.0,
            'totalIncidents': shift['total_incidents'] ?? 0,
          });

          // 2. Sync to SQL rider_shifts table
          await rds.query(
            '''
            INSERT INTO rider_shifts (shift_id, rider_id, branch_id, status, started_at, ended_at, total_deliveries, total_earnings, total_distance_km, total_incidents)
            VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10)
            ON CONFLICT (shift_id) DO UPDATE SET
              status = EXCLUDED.status,
              ended_at = EXCLUDED.ended_at,
              total_deliveries = EXCLUDED.total_deliveries,
              total_earnings = EXCLUDED.total_earnings,
              total_distance_km = EXCLUDED.total_distance_km,
              total_incidents = EXCLUDED.total_incidents,
              updated_at = now()
            ''',
            params: [
              id,
              riderId,
              branchId,
              currentState == 'offline'
                  ? 'offline'
                  : (currentState == 'on_break' ? 'on_break' : 'online'),
              startedAt.toIso8601String(),
              endedAt?.toIso8601String(),
              shift['total_deliveries'] ?? 0,
              shift['total_earnings'] ?? 0.0,
              shift['total_distance'] ?? 0.0,
              shift['total_incidents'] ?? 0,
            ],
            allowWrite: true,
          );

          await _sqlite.markRiderShiftSynced(id);
        } catch (e) {
          debugPrint('[OfflineSyncService] Error syncing shift $id: $e');
        }
      }
    } catch (e) {
      debugPrint('[OfflineSyncService] Error in _processRiderShiftsQueue: $e');
    }
  }

  Future<void> _processRDSWriteQueue() async {
    if (!_isInitialized || !isOnline.value) return;
    try {
      final pending = await _sqlite.getPendingRDSWrites();
      if (pending.isEmpty) return;

      debugPrint('[OfflineSyncService] Syncing ${pending.length} offline RDS writes...');
      final rds = RDSDatabaseService();

      for (final item in pending) {
        if (!isOnline.value) break;

        final id = item['id'] as String;
        final sql = item['sql'] as String;
        final params = item['params'] as List<dynamic>;

        try {
          await rds.query(sql, params: params, allowWrite: true);

          await _sqlite.markRDSWriteSynced(id);
          debugPrint('[OfflineSyncService] Replayed RDS write success: $id');
        } catch (e) {
          final errorMsg = e.toString();
          debugPrint('[OfflineSyncService] Failed to replay RDS write $id: $errorMsg');
          await _sqlite.markRDSWriteFailed(id, maxRetries: 5);

          final retryCount = (item['retryCount'] as int) + 1;
          if (retryCount >= 5) {
            await NotificationRetryService().triggerAdminAlert(
              type: 'SQL_SYNC_DEAD_LETTER',
              severity: 'critical',
              title: 'Postgres Write Permanently Failed',
              description:
                  'SQL query in rds_write_queue exceeded max retries. Query: $sql. Error: $errorMsg',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[OfflineSyncService] Error in _processRDSWriteQueue: $e');
    }
  }

  Future<void> _refreshCounts() async {
    pendingSyncCount.value = await _sqlite.getPendingSyncCount();
    // Employee tasks are a subset of pending_sync where type != 'order_status'
    final all = await _sqlite.getPendingSyncItems();
    pendingEmployeeSyncCount.value = all.where((i) => i['actionType'] != 'order_status').length;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    pendingSyncCount.dispose();
    pendingEmployeeSyncCount.dispose();
    isOnline.dispose();
  }
}

/// Simple value object for contact resolution
class _ContactInfo {
  final String phoneNumber;
  final String name;
  const _ContactInfo({required this.phoneNumber, required this.name});
  bool get isNotEmpty => phoneNumber.isNotEmpty;
}
