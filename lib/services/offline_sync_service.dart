import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firestore_service.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String boxName = 'offline_sync_box';
  late Box<Map> _syncBox;
  bool _isInitialized = false;

  final FirestoreService _firestoreService = FirestoreService();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;

  // Status flags
  final ValueNotifier<int> pendingSyncCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  /// Initializes Hive and the connectivity listener
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();
      _syncBox = await Hive.openBox<Map>(boxName);
      _isInitialized = true;
      _updatePendingCount();

      // Check current connectivity
      final currentResults = await _connectivity.checkConnectivity();
      _checkStatus(currentResults);

      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
        _checkStatus(results);
      });
      
      debugPrint('OfflineSyncService: Initialized successfully with ${_syncBox.length} pending items.');
    } catch (e) {
      debugPrint('OfflineSyncService: Failed to initialize: $e');
    }
  }

  void _checkStatus(dynamic results) {
    bool online = false;
    if (results is List) {
      online = results.any((result) => result != ConnectivityResult.none);
    } else {
      online = results != ConnectivityResult.none;
    }
    
    isOnline.value = online;
    debugPrint('OfflineSyncService: Connection status changed. Online = $online');
    
    if (online) {
      processQueue();
    }
  }

  /// Adds a status change transaction to the offline queue
  Future<void> enqueueStatusUpdate(
    String orderId,
    String status, {
    String? otp,
    bool otpVerified = false,
  }) async {
    if (!_isInitialized) {
      await init();
    }

    final String taskId = 'task_${DateTime.now().millisecondsSinceEpoch}_$orderId';
    final Map taskData = {
      'id': taskId,
      'orderId': orderId,
      'status': status,
      'otp': otp,
      'otpVerified': otpVerified,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _syncBox.put(taskId, taskData);
    _updatePendingCount();
    debugPrint('OfflineSyncService: Enqueued status change to "$status" for Order $orderId');

    // Attempt processing immediately if online
    if (isOnline.value) {
      processQueue();
    }
  }

  /// Processes all pending status updates in the queue
  Future<void> processQueue() async {
    if (!_isInitialized || _syncBox.isEmpty || !isOnline.value) return;

    debugPrint('OfflineSyncService: Starting queue processing...');
    final keys = List.from(_syncBox.keys);

    for (var key in keys) {
      if (!isOnline.value) {
        debugPrint('OfflineSyncService: Connection lost. Pausing queue processing.');
        break;
      }

      final Map? task = _syncBox.get(key);
      if (task == null) continue;

      final String orderId = task['orderId'] ?? '';
      final String status = task['status'] ?? '';
      final bool otpVerified = task['otpVerified'] ?? false;

      try {
        debugPrint('OfflineSyncService: Syncing order $orderId to status $status...');
        
        // 1. Update status
        await _firestoreService.updateOrderStatus(orderId, status);

        // 2. If delivered and OTP verified, sync verification flag
        if (status == 'delivered' && otpVerified) {
          // Additional field updates if necessary can be done here or in updateOrderStatus
        }

        // Remove from queue upon success
        await _syncBox.delete(key);
        _updatePendingCount();
        debugPrint('OfflineSyncService: Sync complete for order $orderId. Removed task.');
      } catch (e) {
        debugPrint('OfflineSyncService: Failed to sync order $orderId. Will retry later. Error: $e');
        // Stop processing rest of queue if it's a connection/server error
        break;
      }
    }
  }

  void _updatePendingCount() {
    pendingSyncCount.value = _syncBox.length;
  }

  /// Clean up subscriptions
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
