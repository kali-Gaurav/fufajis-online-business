import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'order_service.dart';
import 'sqlite_service.dart';
import 'whatsapp_notification_service.dart';

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
  StreamSubscription? _connectivitySubscription;

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
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
        results,
      ) {
        _checkStatus(results);
      });

      debugPrint(
        '[OfflineSyncService] Initialized. Pending: ${pendingSyncCount.value}',
      );
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

  /// Enqueue an order status update for offline sync
  Future<void> enqueueStatusUpdate(
    String orderId,
    String status, {
    String? otp,
    bool otpVerified = false,
  }) async {
    if (!_isInitialized) await init();
    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}_$orderId';
    await _sqlite.enqueuePendingSync(
      id: taskId,
      actionType: 'order_status',
      collection: 'orders',
      documentId: orderId,
      data: {
        'id': taskId,
        'orderId': orderId,
        'status': status,
        'otp': otp,
        'otpVerified': otpVerified,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    await _refreshCounts();
    debugPrint(
      '[OfflineSyncService] Enqueued status "$status" for order $orderId',
    );
    if (isOnline.value) processQueue();
  }

  /// Enqueue an employee inventory/attendance/damage/transfer action
  Future<void> enqueueEmployeeAction({
    required String actionType,
    required String shopId,
    required String branchId,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    if (!_isInitialized) await init();
    final taskId =
        'emp_${DateTime.now().millisecondsSinceEpoch}_${actionType}_$documentId';
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
    debugPrint(
      '[OfflineSyncService] Enqueued employee action "$actionType" for $documentId',
    );
    if (isOnline.value) processQueue();
  }

  // ─────────────── PROCESS ───────────────

  /// Orchestrates processing of all pending queues
  Future<void> processQueue() async {
    await _processOrderQueue();
    await _processEmployeeQueue();
  }

  /// Process pending order status updates
  Future<void> _processOrderQueue() async {
    if (!_isInitialized || !isOnline.value) return;
    final items = await _sqlite.getPendingSyncItems();
    final orderItems = items
        .where((i) => i['actionType'] == 'order_status')
        .toList();
    if (orderItems.isEmpty) return;

    debugPrint(
      '[OfflineSyncService] Processing ${orderItems.length} order tasks...',
    );

    for (final item in orderItems) {
      if (!isOnline.value) break;
      final data = Map<String, dynamic>.from(item['data'] as Map);
      final orderId = data['orderId'] as String? ?? '';
      final status = data['status'] as String? ?? '';

      try {
        await _orderService.updateOrderStatus(orderId, status);
        await _sqlite.markSyncDone(item['id'] as String);
        debugPrint('[OfflineSyncService] Synced order $orderId → $status');
      } catch (e) {
        await _sqlite.markSyncFailed(item['id'] as String);
        debugPrint('[OfflineSyncService] Failed to sync order $orderId: $e');
        break; // stop on connectivity / server error
      }
    }
    await _refreshCounts();
  }

  /// Process pending employee actions with FEFO conflict resolution
  Future<void> _processEmployeeQueue() async {
    if (!_isInitialized || !isOnline.value) return;
    final items = await _sqlite.getPendingSyncItems();
    final empItems = items
        .where((i) => i['actionType'] != 'order_status')
        .toList();
    if (empItems.isEmpty) return;

    debugPrint(
      '[OfflineSyncService] Processing ${empItems.length} employee tasks...',
    );
    final firestore = FirebaseFirestore.instance;

    for (final item in empItems) {
      if (!isOnline.value) break;

      final data = Map<String, dynamic>.from(item['data'] as Map);
      final actionType = data['actionType'] as String? ?? '';
      final shopId = data['shopId'] as String? ?? '';
      final branchId = data['branchId'] as String? ?? '';
      final documentId = data['documentId'] as String? ?? '';
      final rawLocalData = Map<String, dynamic>.from(
        data['data'] as Map? ?? {},
      );
      final localData = _convertDateTimeToTimestamp(rawLocalData);
      final localTimestamp =
          DateTime.tryParse(data['timestamp'] as String? ?? '') ??
          DateTime.now();

      final collectionPath = _collectionForAction(actionType);
      if (collectionPath.isEmpty) {
        debugPrint(
          '[OfflineSyncService] Unknown action type $actionType. Discarding.',
        );
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

        // FEFO conflict check: if server data is newer, skip write and alert manager
        if (snapshot.exists) {
          final serverData = snapshot.data();
          if (serverData != null) {
            final serverModified = serverData['lastModified'] is Timestamp
                ? (serverData['lastModified'] as Timestamp).toDate()
                : DateTime.tryParse(
                    serverData['lastModified']?.toString() ?? '',
                  );

            if (serverModified != null &&
                serverModified.isAfter(localTimestamp)) {
              shouldWrite = false;
              debugPrint(
                '[OfflineSyncService] Conflict: server is newer for $documentId. Writing alert.',
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
                serverModified: serverModified,
              );
            }
          }
        }

        if (shouldWrite) {
          localData['lastModified'] = Timestamp.fromDate(localTimestamp);
          localData['lastSync'] = FieldValue.serverTimestamp();
          await docRef.set(localData, SetOptions(merge: true));

          // Adjust stock for inventory mutations
          if (actionType == 'receive' ||
              actionType == 'damage' ||
              actionType == 'return') {
            await _adjustStock(
              firestore,
              shopId,
              branchId,
              localData,
              actionType,
            );
          }
        }

        await _sqlite.markSyncDone(item['id'] as String);
        debugPrint(
          '[OfflineSyncService] Employee sync complete: $actionType / $documentId',
        );
      } catch (e) {
        await _sqlite.markSyncFailed(item['id'] as String);
        debugPrint(
          '[OfflineSyncService] Failed to sync employee action $actionType / $documentId: $e',
        );
        break;
      }
    }
    await _refreshCounts();
  }

  // ─────────────── HELPERS ───────────────

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
            final Map<dynamic, dynamic> branchStockMap =
                data['branchStock'] as Map? ?? {};
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
              newGlobalStock = updatedBranchStock.values.fold(
                0,
                (total, val) => total + val,
              );
            }

            transaction.update(productRef, {
              'branchStock': updatedBranchStock,
              'stockQuantity': newGlobalStock,
              'isAvailable':
                  newGlobalStock > 0 ||
                  updatedBranchStock.values.any((val) => val > 0),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });
      debugPrint(
        '[OfflineSyncService] Adjusted stock globally for product $productId by $quantity',
      );
    } catch (e) {
      debugPrint(
        '[OfflineSyncService] Error performing transaction-based stock adjustment: $e',
      );
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
    final alertId =
        'conflict_${DateTime.now().millisecondsSinceEpoch}_$documentId';
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
      debugPrint(
        '[OfflineSyncService] WhatsApp conflict alert failed: $waError',
      );
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
      return _ContactInfo(
        phoneNumber: dotenv.get(
          'WHATSAPP_OPERATIONS_PHONE',
          fallback: '919876543210',
        ),
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
          return _ContactInfo(
            phoneNumber: p,
            name: m.data()?['name'] ?? 'Manager',
          );
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
            name: a.data()?['name'] ?? 'Asst. Manager',
          );
        }
      }
    }

    // 3. Branch contact
    final contact = bd['contactPhone'] as String? ?? '';
    if (contact.isNotEmpty) {
      return _ContactInfo(
        phoneNumber: contact,
        name: bd['branchName'] ?? 'Branch Manager',
      );
    }

    // 4. Escalation
    final escalation = bd['escalationPhone'] as String? ?? '';
    if (escalation.isNotEmpty) {
      return _ContactInfo(
        phoneNumber: escalation,
        name: 'Operations Escalation Desk',
      );
    }

    // 5. Global fallback
    return _ContactInfo(
      phoneNumber: dotenv.get(
        'WHATSAPP_OPERATIONS_PHONE',
        fallback: '919876543210',
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
        if (parsed != null &&
            value.length >= 19 &&
            (value.contains('-') || value.contains(':'))) {
          result[key] = Timestamp.fromDate(parsed);
        } else {
          result[key] = value;
        }
      } else if (value is Map) {
        result[key] = _convertDateTimeToTimestamp(
          Map<String, dynamic>.from(value),
        );
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

  Future<void> _refreshCounts() async {
    pendingSyncCount.value = await _sqlite.getPendingSyncCount();
    // Employee tasks are a subset of pending_sync where type != 'order_status'
    final all = await _sqlite.getPendingSyncItems();
    pendingEmployeeSyncCount.value = all
        .where((i) => i['actionType'] != 'order_status')
        .length;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

/// Simple value object for contact resolution
class _ContactInfo {
  final String phoneNumber;
  final String name;
  const _ContactInfo({required this.phoneNumber, required this.name});
  bool get isNotEmpty => phoneNumber.isNotEmpty;
}
