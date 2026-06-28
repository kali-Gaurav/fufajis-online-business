import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_config.dart';
import '../utils/lru_memory_cache.dart';
import '../core/resilience/circuit_breaker.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  SharedPreferences? _prefs;
  bool _useLocalFailover = false;
  bool _useFirebaseCache = false;
  final LruMemoryCache<String, String> _memoryCache = LruMemoryCache(capacity: 500);
  String? _redisUrl;
  String? _redisToken;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CircuitBreaker _redisCircuitBreaker;

  // Initialize service settings
  Future<void> init() async {
    try {
      _redisCircuitBreaker = CircuitBreakerRegistry.get('UpstashRedis', config: const CircuitBreakerConfig(failureThreshold: 3, resetTimeout: Duration(minutes: 1)));
      _prefs = await SharedPreferences.getInstance();
      
      try {
        _redisUrl = AppConfig.upstashRedisRestUrl.trim();
        
        // Clean trailing slash for absolute URL mapping
        if (_redisUrl != null && _redisUrl!.endsWith('/')) {
          _redisUrl = _redisUrl!.substring(0, _redisUrl!.length - 1);
        }

        _redisToken = AppConfig.upstashRedisRestToken.trim();
      } catch (e, stack) {
        debugPrint('CacheService error loading env variables: $e\\n$stack');
      }
      
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

      // Step 3: Test Ping Endpoint using Circuit Breaker
      await _redisCircuitBreaker.execute<void>(() async {
        debugPrint('[CacheService] Step 3: Pinging Upstash Redis REST endpoint: $_redisUrl/ping');
        final response = await http.get(
          Uri.parse('$_redisUrl/ping'),
          headers: {
            'Authorization': 'Bearer $_redisToken',
          },
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if ((decoded is Map && decoded.containsKey('result') && decoded['result'] == 'PONG') ||
              response.body.toUpperCase().contains('PONG')) {
            debugPrint('[CacheService] ✅ Upstash Redis REST authenticated successfully (PONG received).');
            _useLocalFailover = false;
            _useFirebaseCache = false;
          } else {
            throw Exception('Unexpected ping result: ${response.body}');
          }
        } else if (response.statusCode == 401) {
          throw Exception('Upstash authentication failed — check UPSTASH_REDIS_REST_TOKEN');
        } else {
          throw Exception('HTTP Status ${response.statusCode} - ${response.body}');
        }
      }, fallback: (e) async {
        throw e as Object;
      });
    } catch (e) {
      debugPrint('⚠️ [CacheService] Upstash Redis authentication failed or Circuit Open: $e');
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
    _memoryCache.set(key, value);

    // 1. If Local Failover is active
    if (_useLocalFailover || _prefs == null) {
      return await _saveToLocal(key, value);
    }

    // 2. If Firebase Cache is active
    if (_useFirebaseCache) {
      return await _saveToFirebaseCache(key, value);
    }

    // 3. Try Redis — Upstash REST API using CircuitBreaker
    return await _redisCircuitBreaker.execute<bool>(() async {
      debugPrint('[CacheService] Redis Write -> $key');
      final response = await http.post(
        Uri.parse('$_redisUrl/set/$key'),
        headers: {
          'Authorization': 'Bearer $_redisToken',
          'Content-Type': 'text/plain',
        },
        body: value,
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    }, fallback: (error) async {
      debugPrint('[CacheService] Redis Write Error, falling back to Firebase Cache: $error');
      _useFirebaseCache = true;
      return await _saveToFirebaseCache(key, value);
    });
  }

  // Get cached value by key
  Future<String?> get(String key) async {
    // Check memory cache first (p99 latency optimization)
    final cachedVal = _memoryCache.get(key);
    if (cachedVal != null) {
      debugPrint('[CacheService] [MEMORY] Read -> $key');
      return cachedVal;
    }

    if (_useLocalFailover || _prefs == null) {
      return await _readFromLocal(key);
    }

    if (_useFirebaseCache) {
      return await _readFromFirebaseCache(key);
    }

    return await _redisCircuitBreaker.execute<String?>(() async {
      debugPrint('[CacheService] Redis Read -> $key');
      final response = await http.get(
        Uri.parse('$_redisUrl/get/$key'),
        headers: {
          'Authorization': 'Bearer $_redisToken',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        String? value;
        if (decoded is Map && decoded.containsKey('result') && decoded['result'] != null) {
          value = decoded['result'].toString();
        }
        if (value != null) {
          _memoryCache.set(key, value);
          return value;
        }
        return await _readFromLocal(key);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    }, fallback: (error) async {
      debugPrint('[CacheService] Redis Read Error, falling back to Firebase Cache: $error');
      _useFirebaseCache = true;
      return await _readFromFirebaseCache(key);
    });
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
        // Upstash REST format: GET /del/{key}
        await http.get(
          Uri.parse('$_redisUrl/del/$key'),
          headers: {
            'Authorization': 'Bearer $_redisToken',
          },
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
    _prefs ??= await SharedPreferences.getInstance();
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
    if (value != null) _memoryCache.set(key, value);
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
          _memoryCache.set(key, value);
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

  // ============================================================
  // TTL-aware set/get (Redis EX). Falls back to plain set/get +
  // a stored expiry timestamp when Redis is unavailable, so the
  // same API works against the Firestore/local failover tiers.
  // ============================================================

  /// Sets [key] to [value] with a time-to-live of [ttlSeconds].
  /// On Upstash Redis this uses the `EX` option on SET. On the
  /// Firestore/local fallback tiers, an `_exp` sibling key stores
  /// the expiry epoch (ms) and is checked by [_getWithTtl].
  Future<bool> _setWithTtl(String key, String value, int ttlSeconds) async {
    _memoryCache.set(key, value);

    if (!_useLocalFailover && !_useFirebaseCache && _redisUrl != null && _redisToken != null) {
      try {
        return await _redisCircuitBreaker.execute<bool>(() async {
          final response = await http.post(
            Uri.parse('$_redisUrl/set/${Uri.encodeComponent(key)}/${Uri.encodeComponent(value)}?EX=$ttlSeconds'),
            headers: {'Authorization': 'Bearer $_redisToken'},
          ).timeout(const Duration(seconds: 4));

          if (response.statusCode == 200) return true;
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }, fallback: (error) async {
          debugPrint('[CacheService] Redis TTL set error, falling back: $error');
          _useFirebaseCache = true;
          return await _setWithTtlFallback(key, value, ttlSeconds);
        });
      } catch (e) {
        debugPrint('[CacheService] _setWithTtl error: $e');
        return await _setWithTtlFallback(key, value, ttlSeconds);
      }
    }

    return await _setWithTtlFallback(key, value, ttlSeconds);
  }

  Future<bool> _setWithTtlFallback(String key, String value, int ttlSeconds) async {
    final expiresAt = DateTime.now().add(Duration(seconds: ttlSeconds)).millisecondsSinceEpoch;
    final ok1 = _useLocalFailover || _prefs == null
        ? await _saveToLocal(key, value)
        : (_useFirebaseCache ? await _saveToFirebaseCache(key, value) : await _saveToLocal(key, value));
    final ok2 = _useLocalFailover || _prefs == null
        ? await _saveToLocal('${key}_exp', expiresAt.toString())
        : (_useFirebaseCache
            ? await _saveToFirebaseCache('${key}_exp', expiresAt.toString())
            : await _saveToLocal('${key}_exp', expiresAt.toString()));
    return ok1 && ok2;
  }

  /// Gets [key], honoring TTL on the fallback tiers (Redis handles
  /// expiry natively, so a plain [get] is used there).
  Future<String?> _getWithTtl(String key) async {
    if (!_useLocalFailover && !_useFirebaseCache && _redisUrl != null && _redisToken != null) {
      return await get(key);
    }

    final expStr = await _readFromLocal('${key}_exp') ?? await _readFromFirebaseCache('${key}_exp');
    if (expStr != null) {
      final expiresAt = int.tryParse(expStr);
      if (expiresAt != null && DateTime.now().millisecondsSinceEpoch > expiresAt) {
        await remove(key);
        await remove('${key}_exp');
        return null;
      }
    }
    return await get(key);
  }

  // ============================================================
  // SESSIONS
  // ============================================================

  /// Stores a serialized user session, keyed by [userId], with a
  /// default TTL of 7 days (matches typical "remember me" duration).
  Future<bool> setUserSession(String userId, Map<String, dynamic> sessionData,
      {int ttlSeconds = 7 * 24 * 60 * 60}) {
    return _setWithTtl('session:$userId', jsonEncode(sessionData), ttlSeconds);
  }

  Future<Map<String, dynamic>?> getUserSession(String userId) async {
    final raw = await _getWithTtl('session:$userId');
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e) {
      debugPrint('[CacheService] getUserSession decode error: $e');
      return null;
    }
  }

  Future<void> invalidateSession(String userId) async {
    await remove('session:$userId');
    await remove('session:${userId}_exp');
  }

  // ============================================================
  // PRODUCT CACHE
  // ============================================================

  /// Caches a product's serialized data for [ttlSeconds] (default 10
  /// minutes) to reduce repeated Supabase/Firestore reads on hot items.
  Future<bool> cacheProduct(String productId, Map<String, dynamic> productData,
      {int ttlSeconds = 10 * 60}) {
    return _setWithTtl('product:$productId', jsonEncode(productData), ttlSeconds);
  }

  Future<Map<String, dynamic>?> getCachedProduct(String productId) async {
    final raw = await _getWithTtl('product:$productId');
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e) {
      debugPrint('[CacheService] getCachedProduct decode error: $e');
      return null;
    }
  }

  Future<void> invalidateProductCache(String productId) async {
    await remove('product:$productId');
    await remove('product:${productId}_exp');
  }

  // ============================================================
  // CART
  // ============================================================

  /// Persists the in-progress cart for [userId] so it survives app
  /// restarts and is shared across devices. Carts use a long TTL
  /// (default 30 days) purely as a storage-eviction safeguard for
  /// abandoned carts — they are refreshed on every save, so an
  /// actively-used cart never expires.
  Future<bool> saveCart(String userId, List<Map<String, dynamic>> cartItems,
      {int ttlSeconds = 30 * 24 * 60 * 60}) {
    return _setWithTtl('cart:$userId', jsonEncode(cartItems), ttlSeconds);
  }

  Future<List<Map<String, dynamic>>> getCart(String userId) async {
    final raw = await _getWithTtl('cart:$userId');
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(raw) as Iterable);
    } catch (e) {
      debugPrint('[CacheService] getCart decode error: $e');
      return [];
    }
  }

  Future<void> invalidateCart(String userId) async {
    await remove('cart:$userId');
    await remove('cart:${userId}_exp');
  }

  // ============================================================
  // OTP
  // ============================================================

  /// Stores an OTP code for [identifier] (phone/email) with a short
  /// TTL (default 5 minutes).
  Future<bool> storeOTP(String identifier, String code, {int ttlSeconds = 5 * 60}) {
    return _setWithTtl('otp:$identifier', code, ttlSeconds);
  }

  /// Returns the stored OTP for [identifier], or null if missing/expired.
  Future<String?> getOTP(String identifier) {
    return _getWithTtl('otp:$identifier');
  }

  // ============================================================
  // RATE LIMITING
  // ============================================================

  /// Increments a counter for [key] within a [windowSeconds] window
  /// and returns whether the request is still within [maxRequests].
  /// Returns a map: `{allowed: bool, count: int, remaining: int}`.
  Future<Map<String, dynamic>> checkRateLimit(
    String key, {
    int maxRequests = 10,
    int windowSeconds = 60,
  }) async {
    final count = await incrementRateLimit(key, windowSeconds: windowSeconds);
    final allowed = count <= maxRequests;
    final remaining = (maxRequests - count).clamp(0, maxRequests);
    return {'allowed': allowed, 'count': count, 'remaining': remaining};
  }

  /// Increments the rate-limit counter for [key], setting its
  /// expiry to [windowSeconds] on first increment. Returns the new
  /// count.
  Future<int> incrementRateLimit(String key, {int windowSeconds = 60}) async {
    final rlKey = 'ratelimit:$key';

    if (!_useLocalFailover && !_useFirebaseCache && _redisUrl != null && _redisToken != null) {
      try {
        return await _redisCircuitBreaker.execute<int>(() async {
          final incrResp = await http.get(
            Uri.parse('$_redisUrl/incr/${Uri.encodeComponent(rlKey)}'),
            headers: {'Authorization': 'Bearer $_redisToken'},
          ).timeout(const Duration(seconds: 4));

          if (incrResp.statusCode != 200) {
            throw Exception('HTTP ${incrResp.statusCode}: ${incrResp.body}');
          }
          final decoded = jsonDecode(incrResp.body);
          final count = decoded is Map ? (decoded['result'] as num?)?.toInt() ?? 1 : 1;

          if (count == 1) {
            // First hit in this window — set expiry.
            await http.get(
              Uri.parse('$_redisUrl/expire/${Uri.encodeComponent(rlKey)}/$windowSeconds'),
              headers: {'Authorization': 'Bearer $_redisToken'},
            ).timeout(const Duration(seconds: 4));
          }
          return count;
        }, fallback: (error) async {
          debugPrint('[CacheService] Redis rate limit error, falling back: $error');
          return await _incrementRateLimitFallback(rlKey, windowSeconds);
        });
      } catch (e) {
        debugPrint('[CacheService] incrementRateLimit error: $e');
        return await _incrementRateLimitFallback(rlKey, windowSeconds);
      }
    }

    return await _incrementRateLimitFallback(rlKey, windowSeconds);
  }

  /// Non-atomic fallback counter using the local/Firestore tiers with
  /// TTL bookkeeping via [_setWithTtl]/[_getWithTtl].
  Future<int> _incrementRateLimitFallback(String rlKey, int windowSeconds) async {
    final current = await _getWithTtl(rlKey);
    final count = (int.tryParse(current ?? '0') ?? 0) + 1;
    await _setWithTtl(rlKey, count.toString(), windowSeconds);
    return count;
  }
}
