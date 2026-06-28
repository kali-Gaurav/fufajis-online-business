import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Realtime Database Service for Fufaji Online Business
/// Optimized for Phase 13 Production: Presence, Tracking, and Collision Prevention.
class RealtimeDatabaseService {
  static final RealtimeDatabaseService _instance = RealtimeDatabaseService._internal();
  factory RealtimeDatabaseService() => _instance;
  static RealtimeDatabaseService get instance => _instance;
  
  RealtimeDatabaseService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // RTDB Root Paths
  static const String PATH_LIVE_ORDERS = 'live_orders';
  static const String PATH_ORDER_LOCKS = 'active_order_locks';
  static const String PATH_RIDER_TRACKING = 'rider_tracking';
  static const String PATH_USER_PRESENCE = 'user_presence';
  static const String PATH_SYSTEM_STATUS = 'system_presence';
  static const String PATH_CHAT_PRESENCE = 'chat_presence';

  /// Initialize RTDB settings
  void initialize() {
    _db.setPersistenceEnabled(true);
    _db.setPersistenceCacheSizeBytes(10 * 1024 * 1024); // 10MB
    debugPrint('[RTDB] Initialized with local persistence');
  }

  // --- COLLISION PREVENTION (LOCKS) ---

  /// Attempts to lock an order for packing. 
  /// Returns true if lock acquired, false if already locked by someone else.
  Future<bool> acquireOrderLock(String orderId, String employeeId, String employeeName) async {
    final lockRef = _db.ref('$PATH_ORDER_LOCKS/$orderId');
    
    // Check if lock exists and is still valid (within 2 mins)
    final snapshot = await lockRef.get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final lastHeartbeat = data['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // If lock is fresh (< 2 mins) and not ours, fail.
      if (now - lastHeartbeat < 120000 && data['employee_id'] != employeeId) {
        return false; 
      }
    }

    // Acquire or Refresh lock
    await lockRef.set({
      'employee_id': employeeId,
      'employee_name': employeeName,
      'timestamp': ServerValue.timestamp,
    });
    
    // Auto-remove lock on disconnect
    await lockRef.onDisconnect().remove();
    return true;
  }

  /// Sends a heartbeat to keep an order lock alive
  Future<void> sendOrderHeartbeat(String orderId) async {
    await _db.ref('$PATH_ORDER_LOCKS/$orderId/timestamp').set(ServerValue.timestamp);
  }

  /// Explicitly release a lock (when packing is done or screen closed)
  Future<void> releaseOrderLock(String orderId) async {
    await _db.ref('$PATH_ORDER_LOCKS/$orderId').remove();
  }

  // --- PACKING PROGRESS ---

  Future<void> updatePackingProgress({
    required String orderId,
    required String employeeName,
    required int itemsPacked,
    required int totalItems,
    required String lastItemName,
  }) async {
    await _db.ref('$PATH_LIVE_ORDERS/$orderId/packing').update({
      'packer_name': employeeName,
      'progress': itemsPacked / totalItems,
      'items_packed': itemsPacked,
      'total_items': totalItems,
      'last_item': lastItemName,
      'updated_at': ServerValue.timestamp,
    });
  }

  Stream<DatabaseEvent> getPackingProgressStream(String orderId) {
    return _db.ref('$PATH_LIVE_ORDERS/$orderId/packing').onValue;
  }

  // --- SUPPORT CHAT ---

  Future<void> setUserTyping(String roomId, String userId, bool isTyping) async {
    final ref = _db.ref('$PATH_CHAT_PRESENCE/$roomId/typing/$userId');
    if (isTyping) {
      await ref.set(true);
      await ref.onDisconnect().remove();
    } else {
      await ref.remove();
    }
  }

  Stream<DatabaseEvent> getTypingStream(String roomId) {
    return _db.ref('$PATH_CHAT_PRESENCE/$roomId/typing').onValue;
  }

  // --- USER PRESENCE ---

  Future<void> setUserPresence(String userId, String role, bool isOnline) async {
    final presenceRef = _db.ref('$PATH_USER_PRESENCE/$userId');
    if (isOnline) {
      await presenceRef.set({
        'online': true,
        'role': role,
        'last_seen': ServerValue.timestamp,
      });
      await presenceRef.onDisconnect().update({
        'online': false,
        'last_seen': ServerValue.timestamp,
      });
    } else {
      await presenceRef.update({
        'online': false,
        'last_seen': ServerValue.timestamp,
      });
    }
  }

  // --- RIDER TRACKING ---

  Future<void> updateRiderLocation({
    required String riderId,
    required double lat,
    required double lng,
    double heading = 0,
  }) async {
    await _db.ref('$PATH_RIDER_TRACKING/$riderId').update({
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'last_update': ServerValue.timestamp,
    });
  }

  Stream<DatabaseEvent> getAllRidersStream() {
    return _db.ref(PATH_RIDER_TRACKING).onValue;
  }

  // --- GENERIC OPS ---

  DatabaseReference getRef(String path) => _db.ref(path);
}
