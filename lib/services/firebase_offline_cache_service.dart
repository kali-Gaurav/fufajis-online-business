import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

/// Firebase Offline Cache Service
/// Manages local caching with TTL for offline support
class FirebaseOfflineCacheService extends ChangeNotifier {
  static const String _cacheBoxName = 'app_cache';
  static const String _authCacheBoxName = 'auth_cache';
  static const String _userPrefBoxName = 'user_preferences';
  static const String _offlineQueueBoxName = 'offline_queue';

  late Box<dynamic> _cacheBox;
  late Box<dynamic> _authBox;
  late Box<dynamic> _userPrefBox;
  late Box<dynamic> _offlineQueueBox;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize cache boxes
  Future<void> initialize() async {
    try {
      await Hive.initFlutter();

      _cacheBox = await Hive.openBox(_cacheBoxName);
      _authBox = await Hive.openBox(_authCacheBoxName);
      _userPrefBox = await Hive.openBox(_userPrefBoxName);
      _offlineQueueBox = await Hive.openBox(_offlineQueueBoxName);

      _isInitialized = true;
      notifyListeners();

      print('Firebase offline cache initialized');
    } catch (e) {
      print('Failed to initialize offline cache: $e');
      rethrow;
    }
  }

  /// Save data to cache with TTL
  Future<void> save(
    String key,
    dynamic value, {
    Duration ttl = const Duration(hours: 24),
    String? boxName,
  }) async {
    try {
      if (!_isInitialized) {
        throw Exception('Cache service not initialized');
      }

      final box = _getBox(boxName);
      final expiryTime = DateTime.now().add(ttl);

      await box.put(key, {
        'data': value,
        'expiryTime': expiryTime.toIso8601String(),
        'savedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Failed to save cache: $e');
      rethrow;
    }
  }

  /// Get data from cache (checks TTL)
  dynamic get(String key, {String? boxName}) {
    try {
      if (!_isInitialized) {
        throw Exception('Cache service not initialized');
      }

      final box = _getBox(boxName);
      final cached = box.get(key);

      if (cached == null) {
        return null;
      }

      // Check if expired
      final expiryTime = DateTime.parse(cached['expiryTime']);
      if (DateTime.now().isAfter(expiryTime)) {
        box.delete(key);
        return null;
      }

      return cached['data'];
    } catch (e) {
      print('Failed to get cache: $e');
      return null;
    }
  }

  /// Save authentication token
  Future<void> saveAuthToken(String token, {Duration ttl = const Duration(hours: 1)}) async {
    await save('auth_token', token, boxName: _authCacheBoxName, ttl: ttl);
  }

  /// Get cached auth token
  String? getAuthToken() => get('auth_token', boxName: _authCacheBoxName) as String?;

  /// Save user preferences
  Future<void> saveUserPreference(String key, dynamic value) async {
    await save(key, value, boxName: _userPrefBoxName, ttl: const Duration(days: 365));
  }

  /// Get user preference
  dynamic getUserPreference(String key) => get(key, boxName: _userPrefBoxName);

  /// Queue offline action for later sync
  Future<void> queueOfflineAction({
    required String action,
    required Map<String, dynamic> data,
    required DateTime timestamp,
  }) async {
    try {
      if (!_isInitialized) {
        throw Exception('Cache service not initialized');
      }

      final actionId = '${action}_${timestamp.millisecondsSinceEpoch}';

      await _offlineQueueBox.put(actionId, {
        'action': action,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        'synced': false,
      });

      notifyListeners();
    } catch (e) {
      print('Failed to queue offline action: $e');
      rethrow;
    }
  }

  /// Get all pending offline actions
  List<Map<String, dynamic>> getPendingOfflineActions() {
    try {
      if (!_isInitialized) {
        return [];
      }

      final actions = <Map<String, dynamic>>[];
      for (final value in _offlineQueueBox.values) {
        if (value is Map && value['synced'] != true) {
          actions.add(Map<String, dynamic>.from(value));
        }
      }

      return actions;
    } catch (e) {
      print('Failed to get pending offline actions: $e');
      return [];
    }
  }

  /// Mark offline action as synced
  Future<void> markActionSynced(String actionId) async {
    try {
      if (!_isInitialized) {
        return;
      }

      final action = _offlineQueueBox.get(actionId);
      if (action != null) {
        action['synced'] = true;
        await _offlineQueueBox.put(actionId, action);
        notifyListeners();
      }
    } catch (e) {
      print('Failed to mark action as synced: $e');
    }
  }

  /// Clear all offline actions
  Future<void> clearOfflineQueue() async {
    try {
      if (!_isInitialized) {
        return;
      }

      await _offlineQueueBox.clear();
      notifyListeners();
    } catch (e) {
      print('Failed to clear offline queue: $e');
    }
  }

  /// Save document to local cache (for offline viewing)
  Future<void> cacheDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final cacheKey = '${collection}_$documentId';
    await save(cacheKey, data, boxName: _cacheBoxName, ttl: const Duration(days: 7));
  }

  /// Get cached document
  Map<String, dynamic>? getCachedDocument(String collection, String documentId) {
    final cacheKey = '${collection}_$documentId';
    return get(cacheKey, boxName: _cacheBoxName) as Map<String, dynamic>?;
  }

  /// Save collection snapshot to cache
  Future<void> cacheCollection(String collection, List<Map<String, dynamic>> documents) async {
    final cacheKey = '${collection}_list';
    await save(cacheKey, documents, boxName: _cacheBoxName, ttl: const Duration(hours: 6));
  }

  /// Get cached collection
  List<Map<String, dynamic>>? getCachedCollection(String collection) {
    final cacheKey = '${collection}_list';
    final cached = get(cacheKey, boxName: _cacheBoxName);
    if (cached is List) {
      return List<Map<String, dynamic>>.from(cached);
    }
    return null;
  }

  /// Clear specific collection cache
  Future<void> clearCollectionCache(String collection) async {
    try {
      if (!_isInitialized) {
        return;
      }

      final cacheKey = '${collection}_list';
      await _cacheBox.delete(cacheKey);
      notifyListeners();
    } catch (e) {
      print('Failed to clear collection cache: $e');
    }
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    try {
      if (!_isInitialized) {
        return;
      }

      await _cacheBox.clear();
      await _authBox.clear();
      await _userPrefBox.clear();
      // Keep offline queue

      notifyListeners();
    } catch (e) {
      print('Failed to clear all caches: $e');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheBoxSize': _cacheBox.length,
      'authBoxSize': _authBox.length,
      'userPrefBoxSize': _userPrefBox.length,
      'offlineQueueSize': _offlineQueueBox.length,
      'pendingActions': getPendingOfflineActions().length,
    };
  }

  /// Cleanup expired entries
  Future<void> cleanupExpiredEntries() async {
    try {
      if (!_isInitialized) {
        return;
      }

      final now = DateTime.now();
      final keysToDelete = <String>[];

      for (final entry in _cacheBox.toMap().entries) {
        if (entry.value is Map) {
          final expiryTime = DateTime.parse(entry.value['expiryTime']);
          if (now.isAfter(expiryTime)) {
            keysToDelete.add(entry.key);
          }
        }
      }

      for (final key in keysToDelete) {
        await _cacheBox.delete(key);
      }

      print('Cleaned up ${keysToDelete.length} expired cache entries');
      notifyListeners();
    } catch (e) {
      print('Failed to cleanup expired entries: $e');
    }
  }

  /// Get box by name
  Box<dynamic> _getBox(String? boxName) {
    return switch (boxName) {
      _authCacheBoxName => _authBox,
      _userPrefBoxName => _userPrefBox,
      _offlineQueueBoxName => _offlineQueueBox,
      _ => _cacheBox,
    };
  }

  /// Close all boxes
  Future<void> close() async {
    try {
      if (_isInitialized) {
        await _cacheBox.close();
        await _authBox.close();
        await _userPrefBox.close();
        await _offlineQueueBox.close();
        _isInitialized = false;
        notifyListeners();
      }
    } catch (e) {
      print('Failed to close cache: $e');
    }
  }
}
