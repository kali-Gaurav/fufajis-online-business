import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path_helper;
import 'package:crypto/crypto.dart';

/// 4-Tier Local Storage Service for Fufaji
///
/// Tier 1: Secure Storage (flutter_secure_storage) — PINs, sensitive tokens
/// Tier 2: SharedPreferences — theme, language, app-level settings
/// Tier 3: Hive — cart, profile cache, fast access data
/// Tier 4: SQLite — order history, analytics, relational data
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  late SharedPreferences _prefs;
  late FlutterSecureStorage _secureStorage;
  late Database _db;
  bool _initialized = false;

  // Hive boxes
  late Box<dynamic> _profileBox;
  late Box<dynamic> _cartBox;
  late Box<dynamic> _cacheBox;

  // ═══════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();
      debugPrint('[LocalStorageService] SharedPreferences initialized');

      // Initialize Secure Storage
      _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
          storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
      );
      debugPrint('[LocalStorageService] Secure Storage initialized');

      // Initialize Hive
      await Hive.initFlutter();
      _profileBox = await Hive.openBox('profile');
      _cartBox = await Hive.openBox('cart');
      _cacheBox = await Hive.openBox('cache');
      debugPrint('[LocalStorageService] Hive boxes initialized');

      // Initialize SQLite
      await _initDatabase();
      debugPrint('[LocalStorageService] SQLite database initialized');

      _initialized = true;
    } catch (e) {
      debugPrint('[LocalStorageService] Initialization error: $e');
      rethrow;
    }
  }

  Future<void> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = path_helper.join(dbPath, 'fufaji_user_data.db');

      _db = await openDatabase(
        path,
        version: 1,
        onCreate: _createTables,
      );
    } catch (e) {
      debugPrint('[LocalStorageService] Database initialization error: $e');
      rethrow;
    }
  }

  Future<void> _createTables(Database db, int version) async {
    // Order history table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_history (
        id TEXT PRIMARY KEY,
        order_number TEXT,
        user_id TEXT NOT NULL,
        total_amount REAL,
        status TEXT,
        items_json TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        synced_at INTEGER
      )
    ''');

    // User activity log
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        action TEXT NOT NULL,
        details_json TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Device info
    await db.execute('''
      CREATE TABLE IF NOT EXISTS device_info (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        device_name TEXT,
        device_id TEXT UNIQUE,
        approved INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    debugPrint('[LocalStorageService] Database tables created');
  }

  // ═══════════════════════════════════════════════════════════════
  // TIER 1: SECURE STORAGE (flutter_secure_storage)
  // ═══════════════════════════════════════════════════════════════

  /// Save sensitive data (PINs, auth tokens) to secure storage
  Future<void> saveToSecureStorage(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
      debugPrint('[LocalStorageService] Secure storage saved: $key');
    } catch (e) {
      debugPrint('[LocalStorageService] Secure storage write error for $key: $e');
      rethrow;
    }
  }

  /// Retrieve sensitive data from secure storage
  Future<String?> getFromSecureStorage(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      debugPrint('[LocalStorageService] Secure storage read error for $key: $e');
      return null;
    }
  }

  /// Delete from secure storage
  Future<void> deleteFromSecureStorage(String key) async {
    try {
      await _secureStorage.delete(key: key);
      debugPrint('[LocalStorageService] Secure storage deleted: $key');
    } catch (e) {
      debugPrint('[LocalStorageService] Secure storage delete error for $key: $e');
    }
  }

  /// Hash and save PIN to secure storage
  Future<void> savePINHash(String pin) async {
    try {
      final pinHash = sha256.convert(utf8.encode(pin)).toString();
      await saveToSecureStorage('pin_hash', pinHash);
      debugPrint('[LocalStorageService] PIN hash saved');
    } catch (e) {
      debugPrint('[LocalStorageService] PIN hash save error: $e');
      rethrow;
    }
  }

  /// Verify PIN against stored hash
  Future<bool> verifyPIN(String pin) async {
    try {
      final storedHash = await getFromSecureStorage('pin_hash');
      if (storedHash == null) return false;

      final pinHash = sha256.convert(utf8.encode(pin)).toString();
      return pinHash == storedHash;
    } catch (e) {
      debugPrint('[LocalStorageService] PIN verification error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TIER 2: SHARED PREFERENCES (theme, language, settings)
  // ═══════════════════════════════════════════════════════════════

  /// Save preference value
  Future<void> saveToPreferences(String key, dynamic value) async {
    try {
      if (value is String) {
        await _prefs.setString(key, value);
      } else if (value is int) {
        await _prefs.setInt(key, value);
      } else if (value is double) {
        await _prefs.setDouble(key, value);
      } else if (value is bool) {
        await _prefs.setBool(key, value);
      } else if (value is List<String>) {
        await _prefs.setStringList(key, value);
      } else {
        await _prefs.setString(key, jsonEncode(value));
      }
      debugPrint('[LocalStorageService] Preference saved: $key');
    } catch (e) {
      debugPrint('[LocalStorageService] Preference save error for $key: $e');
      rethrow;
    }
  }

  /// Get preference value
  T? getFromPreferences<T>(String key) {
    try {
      final value = _prefs.get(key);
      if (value is T) return value;
      if (value is String && T == Map) {
        try {
          return jsonDecode(value) as T;
        } catch (_) {
          return null;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[LocalStorageService] Preference read error for $key: $e');
      return null;
    }
  }

  /// Get string preference
  String? getStringPreference(String key) => _prefs.getString(key);

  /// Get bool preference
  bool? getBoolPreference(String key) => _prefs.getBool(key);

  /// Get int preference
  int? getIntPreference(String key) => _prefs.getInt(key);

  /// Get double preference
  double? getDoublePreference(String key) => _prefs.getDouble(key);

  /// Remove preference
  Future<void> removePreference(String key) async {
    try {
      await _prefs.remove(key);
      debugPrint('[LocalStorageService] Preference removed: $key');
    } catch (e) {
      debugPrint('[LocalStorageService] Preference remove error for $key: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TIER 3: HIVE (cart, profile cache, fast access)
  // ═══════════════════════════════════════════════════════════════

  /// Save to Hive cache
  Future<void> saveToHive(String boxName, String key, dynamic value) async {
    try {
      Box<dynamic> box;
      if (boxName == 'profile') {
        box = _profileBox;
      } else if (boxName == 'cart') {
        box = _cartBox;
      } else if (boxName == 'cache') {
        box = _cacheBox;
      } else {
        box = await Hive.openBox(boxName);
      }

      await box.put(key, value);
      debugPrint('[LocalStorageService] Hive saved: $boxName/$key');
    } catch (e) {
      debugPrint('[LocalStorageService] Hive save error: $e');
      rethrow;
    }
  }

  /// Get from Hive cache
  dynamic getFromHive(String boxName, String key) {
    try {
      Box<dynamic> box;
      if (boxName == 'profile') {
        box = _profileBox;
      } else if (boxName == 'cart') {
        box = _cartBox;
      } else if (boxName == 'cache') {
        box = _cacheBox;
      } else {
        return null;
      }

      return box.get(key);
    } catch (e) {
      debugPrint('[LocalStorageService] Hive read error: $e');
      return null;
    }
  }

  /// Get all from Hive box
  Map<dynamic, dynamic> getAllFromHive(String boxName) {
    try {
      Box<dynamic> box;
      if (boxName == 'profile') {
        box = _profileBox;
      } else if (boxName == 'cart') {
        box = _cartBox;
      } else if (boxName == 'cache') {
        box = _cacheBox;
      } else {
        return {};
      }

      return box.toMap();
    } catch (e) {
      debugPrint('[LocalStorageService] Hive getAll error: $e');
      return {};
    }
  }

  /// Delete from Hive
  Future<void> deleteFromHive(String boxName, String key) async {
    try {
      Box<dynamic> box;
      if (boxName == 'profile') {
        box = _profileBox;
      } else if (boxName == 'cart') {
        box = _cartBox;
      } else if (boxName == 'cache') {
        box = _cacheBox;
      } else {
        return;
      }

      await box.delete(key);
      debugPrint('[LocalStorageService] Hive deleted: $boxName/$key');
    } catch (e) {
      debugPrint('[LocalStorageService] Hive delete error: $e');
    }
  }

  /// Clear entire Hive box
  Future<void> clearHiveBox(String boxName) async {
    try {
      Box<dynamic> box;
      if (boxName == 'profile') {
        box = _profileBox;
      } else if (boxName == 'cart') {
        box = _cartBox;
      } else if (boxName == 'cache') {
        box = _cacheBox;
      } else {
        return;
      }

      await box.clear();
      debugPrint('[LocalStorageService] Hive box cleared: $boxName');
    } catch (e) {
      debugPrint('[LocalStorageService] Hive clear error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TIER 4: SQLITE (order history, analytics, relational data)
  // ═══════════════════════════════════════════════════════════════

  /// Insert order history record
  Future<int> insertOrderHistory(Map<String, dynamic> data) async {
    try {
      return await _db.insert('order_history', data);
    } catch (e) {
      debugPrint('[LocalStorageService] Insert order error: $e');
      rethrow;
    }
  }

  /// Query order history
  Future<List<Map<String, dynamic>>> queryOrderHistory(
    String userId, {
    int? limit,
    int? offset,
  }) async {
    try {
      String query = 'SELECT * FROM order_history WHERE user_id = ?';
      final args = [userId];

      if (limit != null) query += ' LIMIT ?';
      if (offset != null) query += ' OFFSET ?';

      if (limit != null) args.add(limit as String);
      if (offset != null) args.add(offset as String);

      return await _db.rawQuery(query, args);
    } catch (e) {
      debugPrint('[LocalStorageService] Query order history error: $e');
      return [];
    }
  }

  /// Log user activity
  Future<int> logActivity(String userId, String action, Map<String, dynamic>? details) async {
    try {
      return await _db.insert('activity_log', {
        'user_id': userId,
        'action': action,
        'details_json': details != null ? jsonEncode(details) : null,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('[LocalStorageService] Log activity error: $e');
      return -1;
    }
  }

  /// Save device info
  Future<int> saveDeviceInfo(String userId, Map<String, dynamic> deviceInfo) async {
    try {
      final existing = await _db.query(
        'device_info',
        where: 'device_id = ?',
        whereArgs: [deviceInfo['device_id']],
      );

      if (existing.isNotEmpty) {
        return await _db.update(
          'device_info',
          {...deviceInfo, 'user_id': userId},
          where: 'device_id = ?',
          whereArgs: [deviceInfo['device_id']],
        );
      } else {
        return await _db.insert('device_info', {
          ...deviceInfo,
          'user_id': userId,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      debugPrint('[LocalStorageService] Save device info error: $e');
      return -1;
    }
  }

  /// Execute raw query
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? args,
  ]) async {
    try {
      return await _db.rawQuery(sql, args);
    } catch (e) {
      debugPrint('[LocalStorageService] Raw query error: $e');
      return [];
    }
  }

  /// Execute raw update
  Future<int> rawUpdate(String sql, [List<dynamic>? args]) async {
    try {
      return await _db.rawUpdate(sql, args);
    } catch (e) {
      debugPrint('[LocalStorageService] Raw update error: $e');
      return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CLEANUP & LOGOUT
  // ═══════════════════════════════════════════════════════════════

  /// Clear user-specific data on logout
  Future<void> clearUserData() async {
    try {
      // Clear Hive boxes
      await clearHiveBox('profile');
      await clearHiveBox('cart');
      await clearHiveBox('cache');

      // Clear sensitive preferences
      await removePreference('authToken');
      await removePreference('refreshToken');
      await removePreference('userId');

      // Clear secure storage
      await deleteFromSecureStorage('pin_hash');
      await deleteFromSecureStorage('biometric_enabled');

      debugPrint('[LocalStorageService] User data cleared');
    } catch (e) {
      debugPrint('[LocalStorageService] Clear user data error: $e');
    }
  }

  /// Clear all local data (for app reset/debugging)
  Future<void> clearAllData() async {
    try {
      await clearUserData();
      await clearHiveBox('profile');
      await clearHiveBox('cart');
      await clearHiveBox('cache');

      // Clear all preferences
      await _prefs.clear();

      debugPrint('[LocalStorageService] All data cleared');
    } catch (e) {
      debugPrint('[LocalStorageService] Clear all data error: $e');
    }
  }

  /// Compact database
  Future<void> compactDatabase() async {
    try {
      await _db.execute('VACUUM');
      debugPrint('[LocalStorageService] Database compacted');
    } catch (e) {
      debugPrint('[LocalStorageService] Database compact error: $e');
    }
  }

  /// Close database connection
  Future<void> closeDatabase() async {
    try {
      await _db.close();
      debugPrint('[LocalStorageService] Database closed');
    } catch (e) {
      debugPrint('[LocalStorageService] Database close error: $e');
    }
  }
}
