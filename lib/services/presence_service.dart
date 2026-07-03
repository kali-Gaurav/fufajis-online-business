import 'dart:async';
import 'realtime_database_service.dart';

/// Global Presence & Heartbeat Manager
/// Prevents "ghost locks" and tracks real-time availability of staff.
class PresenceService {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  Timer? _heartbeatTimer;
  String? _activeOrderId;
  String? _currentUserId;
  String? _currentUserRole;

  /// Start tracking user presence
  void startUserPresence(String userId, String role) {
    _currentUserId = userId;
    _currentUserRole = role;

    // Initial update
    RealtimeDatabaseService.instance.setUserPresence(userId, role, true);

    // Start 30-second heartbeat
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _performHeartbeat();
    });
  }

  /// Track a specific task lock (e.g. Packing an order)
  Future<bool> startTaskLock(String orderId, String employeeId, String employeeName) async {
    final success = await RealtimeDatabaseService.instance.acquireOrderLock(
      orderId,
      employeeId,
      employeeName,
    );
    if (success) {
      _activeOrderId = orderId;
    }
    return success;
  }

  /// Stop tracking task lock
  void endTaskLock() {
    if (_activeOrderId != null) {
      RealtimeDatabaseService.instance.releaseOrderLock(_activeOrderId!);
      _activeOrderId = null;
    }
  }

  void _performHeartbeat() {
    if (_currentUserId != null && _currentUserRole != null) {
      RealtimeDatabaseService.instance.setUserPresence(_currentUserId!, _currentUserRole!, true);
    }
    if (_activeOrderId != null) {
      RealtimeDatabaseService.instance.sendOrderHeartbeat(_activeOrderId!);
    }
  }

  /// Stop all tracking (on logout)
  void stopAll() {
    if (_currentUserId != null) {
      RealtimeDatabaseService.instance.setUserPresence(
        _currentUserId!,
        _currentUserRole ?? 'user',
        false,
      );
    }
    _heartbeatTimer?.cancel();
    _activeOrderId = null;
    _currentUserId = null;
  }
}
