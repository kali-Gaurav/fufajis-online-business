import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  SharedPreferences? _prefs;
  bool _useLocalFailover = false;
  bool _useFirebaseCache = false;
  final Map<String, String> _memoryCache = {};
  String? _redisUrl;
  String? _redisToken;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize service settings
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      
      try {
        _redisUrl = dotenv.get('UPSTASH_REDIS_REST_URL', fallback: '').trim();
        if (_redisUrl == null || _redisUrl!.isEmpty) {
          _redisUrl = dotenv.get('REDIS_REST_URL', fallback: '').trim();
        }
        if (_redisUrl != null && _redisUrl!.isNotEmpty && !_redisUrl!.endsWith('/')) {
          _redisUrl = '$_redisUrl/';
        }
        _redisToken = dotenv.get('UPSTASH_REDIS_REST_TOKEN', fallback: '').trim();
        if (_redisToken == null || _redisToken!.isEmpty) {
          _redisToken = dotenv.get('REDIS_REST_TOKEN', fallback: '').trim();
        }
      } catch (_) {}
      
      // Step 1: URL Validation
      if (!_isValidUrl(_redisUrl)) {
        debugPrint('[CacheService] Step 1: URL validation failed or empty. Falling back to Firebase Cache.');
        await _activateFirebaseCache();
        return;
      }

      // Step 2: Token Validation
      if (!_isValidToken(_redisToken)) {
        debugPrint('[CacheService] Step 2: REST Token validation failed. Falling back to Firebase Cache.');
        await _activateFirebaseCache();
        return;
      }

      // Step 3: Test Ping Endpoint
      debugPrint('[CacheService] Step 3: Pinging Upstash Redis REST endpoint: $_redisUrl');
      final response = await http.post(
        Uri.parse(_redisUrl!),
        headers: {
          'Authorization': 'Bearer $_redisToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(['PING']),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('result') && decoded['result'] == 'PONG') {
          debugPrint('[CacheService] Upstash Redis REST authenticated successfully (PONG received).');
          _useLocalFailover = false;
          _useFirebaseCache = false;
        } else if (response.body.contains('PONG')) {
          debugPrint('[CacheService] Upstash Redis REST authenticated successfully.');
          _useLocalFailover = false;
          _useFirebaseCache = false;
        } else {
          throw Exception('Unexpected ping result: ${response.body}');
        }
      } else {
        throw Exception('HTTP Status ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('⚠️ [CacheService] Upstash Redis authentication failed: $e');
      await _activateFirebaseCache();
    }
  }

  bool _isValidUrl(String? urlStr) {
    if (urlStr == null || urlStr.isEmpty) return false;
    final uri = Uri.tryParse(urlStr);
    return uri != null && uri.hasAbsolutePath && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  bool _isValidToken(String? token) {
    return token != null && token.isNotEmpty && token.length > 5;
  }

  Future<void> _activateFirebaseCache() async {
    try {
      debugPrint('[CacheService] Step 4: Activating Firebase Cache (Firestore fallback)...');
      // Verify firestore connectivity
      await _firestore.collection('cache').doc('ping_test').set({
        'pingedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 3));
      
      _useFirebaseCache = true;
      _useLocalFailover = false;
      debugPrint('👉 [CacheService] Firebase Cache fallback activated successfully.');
    } catch (e) {
      _useLocalFailover = true;
      _useFirebaseCache = false;
      debugPrint('⚠️ [CacheService] Firebase Cache (Firestore) is unavailable ($e).');
      debugPrint('👉 [CacheService] Activated Local SharedPreferences Failover.');
    }
  }

  // Set cached key-value entry
  Future<bool> set(String key, String value) async {
    // Always update memory cache for instant access
    _memoryCache[key] = value;

    // 1. If Local Failover is active
    if (_useLocalFailover || _prefs == null) {
      return await _saveToLocal(key, value);
    }

    // 2. If Firebase Cache is active
    if (_useFirebaseCache) {
      return await _saveToFirebaseCache(key, value);
    }

    // 3. Try Redis
    try {
      debugPrint('[CacheService] Redis Write -> $key');
      final response = await http.post(
        Uri.parse(_redisUrl!),
        headers: {
          'Authorization': 'Bearer $_redisToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(['SET', key, value]),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[CacheService] Redis Write Error, falling back to Firebase Cache: $e');
      _useFirebaseCache = true;
      return await _saveToFirebaseCache(key, value);
    }
  }

  // Get cached value by key
  Future<String?> get(String key) async {
    // Check memory cache first (p99 latency optimization)
    if (_memoryCache.containsKey(key)) {
      debugPrint('[CacheService] [MEMORY] Read -> $key');
      return _memoryCache[key];
    }

    if (_useLocalFailover || _prefs == null) {
      return await _readFromLocal(key);
    }

    if (_useFirebaseCache) {
      return await _readFromFirebaseCache(key);
    }

    try {
      debugPrint('[CacheService] Redis Read -> $key');
      final response = await http.post(
        Uri.parse(_redisUrl!),
        headers: {
          'Authorization': 'Bearer $_redisToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(['GET', key]),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        String? value;
        if (decoded is Map && decoded.containsKey('result')) {
          value = decoded['result']?.toString();
        }
        if (value != null) {
          _memoryCache[key] = value;
          return value;
        }
        // Key not found in Redis, check local preferences as secondary lookup
        return await _readFromLocal(key);
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[CacheService] Redis Read Error, falling back to Firebase Cache: $e');
      _useFirebaseCache = true;
      return await _readFromFirebaseCache(key);
    }
  }

  // Remove key from cache
  Future<bool> remove(String key) async {
    _memoryCache.remove(key);
    bool localRemoved = false;
    if (_prefs != null) {
      localRemoved = await _prefs!.remove('cache_$key');
    }

    if (_useFirebaseCache) {
      try {
        await _firestore.collection('cache').doc(key).delete();
      } catch (e) {
        debugPrint('[CacheService] Firebase Cache Delete Error: $e');
      }
    } else if (!_useLocalFailover && _redisUrl != null && _redisToken != null) {
      try {
        await http.post(
          Uri.parse(_redisUrl!),
          headers: {
            'Authorization': 'Bearer $_redisToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(['DEL', key]),
        ).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('[CacheService] Redis Delete Error: $e');
      }
    }
    return localRemoved;
  }

  // Clear entire cache entries
  Future<void> clearAll() async {
    _memoryCache.clear();
    if (_prefs == null) _prefs = await SharedPreferences.getInstance();
    final keys = _prefs!.getKeys();
    for (String key in keys) {
      if (key.startsWith('cache_')) {
        await _prefs!.remove(key);
      }
    }

    if (_useFirebaseCache) {
      try {
        final snapshot = await _firestore.collection('cache').get();
        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('[CacheService] Firebase Cache Clear Error: $e');
      }
    }
    debugPrint('[CacheService] Cache database cleared successfully.');
  }

  // --- Helper Methods ---

  Future<bool> _saveToLocal(String key, String value) async {
    debugPrint('[CacheService] [FAILOVER] Local Write -> $key');
    if (_prefs == null) {
      try {
        _prefs = await SharedPreferences.getInstance();
      } catch (e) {
        debugPrint('[CacheService] SharedPreferences critical error: $e');
        return true;
      }
    }
    return await _prefs!.setString('cache_$key', value);
  }

  Future<String?> _readFromLocal(String key) async {
    debugPrint('[CacheService] [FAILOVER] Local Read -> $key');
    if (_prefs == null) {
      try {
        _prefs = await SharedPreferences.getInstance();
      } catch (e) {
        debugPrint('[CacheService] SharedPreferences critical error: $e');
        return null;
      }
    }
    final value = _prefs!.getString('cache_$key');
    if (value != null) _memoryCache[key] = value;
    return value;
  }

  Future<bool> _saveToFirebaseCache(String key, String value) async {
    try {
      debugPrint('[CacheService] [FIREBASE CACHE] Write -> $key');
      await _firestore.collection('cache').doc(key).set({
        'value': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[CacheService] Firebase Cache Write Error, falling back to local: $e');
      _useLocalFailover = true;
      return await _saveToLocal(key, value);
    }
  }

  Future<String?> _readFromFirebaseCache(String key) async {
    try {
      debugPrint('[CacheService] [FIREBASE CACHE] Read -> $key');
      final doc = await _firestore.collection('cache').doc(key).get();
      if (doc.exists && doc.data() != null) {
        final value = doc.data()?['value']?.toString();
        if (value != null) {
          _memoryCache[key] = value;
          return value;
        }
      }
      return await _readFromLocal(key);
    } catch (e) {
      debugPrint('[CacheService] Firebase Cache Read Error, falling back to local: $e');
      _useLocalFailover = true;
      return await _readFromLocal(key);
    }
  }
}
