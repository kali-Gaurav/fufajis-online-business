import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path_helper;

/// SQLite Relational Storage Service for Fufaji Offline Operations
/// Manages: products, orders, cart, inventory, pending_sync, audit_logs
class SqliteService {
  static final SqliteService _instance = SqliteService._internal();
  factory SqliteService() => _instance;
  SqliteService._internal();

  Database? _database;
  static const int _schemaVersion = 3;
  static const String _dbName = 'fufaji_offline.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final dbFilePath = path_helper.join(dbPath, _dbName);

    return await openDatabase(
      dbFilePath,
      version: _schemaVersion,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    debugPrint('[SqliteService] Creating schema v$version...');

    // Products cache table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT,
        price REAL,
        stock_quantity INTEGER,
        is_available INTEGER DEFAULT 1,
        image_url TEXT,
        unit TEXT,
        barcode TEXT,
        data_json TEXT NOT NULL,
        synced_at INTEGER NOT NULL
      )
    ''');

    // Orders table (includes offline-created orders pending sync)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id TEXT PRIMARY KEY,
        order_number TEXT,
        customer_id TEXT,
        customer_name TEXT,
        status TEXT DEFAULT 'pending',
        payment_method TEXT,
        payment_status TEXT DEFAULT 'pending',
        total_amount REAL,
        is_synced INTEGER DEFAULT 0,
        data_json TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Cart table (persists cart across app restarts)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit TEXT,
        data_json TEXT NOT NULL,
        added_at INTEGER NOT NULL
      )
    ''');

    // Inventory adjustments table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        action_type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        batch_number TEXT,
        notes TEXT,
        shop_id TEXT,
        branch_id TEXT,
        is_synced INTEGER DEFAULT 0,
        data_json TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // Pending sync queue (unified for all offline operations)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_sync (
        id TEXT PRIMARY KEY,
        action_type TEXT NOT NULL,
        collection TEXT NOT NULL,
        document_id TEXT NOT NULL,
        data_json TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        status TEXT DEFAULT 'queued',
        created_at INTEGER NOT NULL,
        last_tried_at INTEGER
      )
    ''');

    // Audit logs table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT,
        user_id TEXT,
        details TEXT,
        timestamp INTEGER NOT NULL
      )
    ''');

    // Rider shifts table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rider_shifts (
        id TEXT PRIMARY KEY,
        rider_id TEXT NOT NULL,
        branch_id TEXT NOT NULL,
        current_state TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        total_deliveries INTEGER DEFAULT 0,
        total_earnings REAL DEFAULT 0.0,
        total_distance REAL DEFAULT 0.0,
        total_incidents INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // Rider location logs table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rider_location_logs (
        id TEXT PRIMARY KEY,
        delivery_id TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        speed REAL NOT NULL,
        accuracy REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // RDS write queue table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rds_write_queue (
        id TEXT PRIMARY KEY,
        sql_query TEXT NOT NULL,
        params_json TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        status TEXT DEFAULT 'queued',
        created_at INTEGER NOT NULL,
        last_tried_at INTEGER
      )
    ''');

    debugPrint('[SqliteService] All tables created successfully.');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[SqliteService] Upgrading from v$oldVersion to v$newVersion');
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rider_shifts (
          id TEXT PRIMARY KEY,
          rider_id TEXT NOT NULL,
          branch_id TEXT NOT NULL,
          current_state TEXT NOT NULL,
          started_at INTEGER NOT NULL,
          ended_at INTEGER,
          total_deliveries INTEGER DEFAULT 0,
          total_earnings REAL DEFAULT 0.0,
          total_distance REAL DEFAULT 0.0,
          total_incidents INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rider_location_logs (
          id TEXT PRIMARY KEY,
          delivery_id TEXT,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          speed REAL NOT NULL,
          accuracy REAL NOT NULL,
          timestamp INTEGER NOT NULL,
          is_synced INTEGER DEFAULT 0
        )
      ''');
      debugPrint('[SqliteService] Upgrade to v2 (shifts/locations) applied.');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rds_write_queue (
          id TEXT PRIMARY KEY,
          sql_query TEXT NOT NULL,
          params_json TEXT NOT NULL,
          retry_count INTEGER DEFAULT 0,
          status TEXT DEFAULT 'queued',
          created_at INTEGER NOT NULL,
          last_tried_at INTEGER
        )
      ''');
      debugPrint('[SqliteService] Upgrade to v3 (rds_write_queue) applied.');
    }
  }

  // ─────────────── PRODUCTS ───────────────

  Future<void> upsertProduct(Map<String, dynamic> product) async {
    final db = await database;
    await db.insert('products', {
      'id': product['id'],
      'name': product['name'] ?? '',
      'category': product['category'] ?? '',
      'price': (product['price'] ?? 0).toDouble(),
      'stock_quantity': product['stockQuantity'] ?? 0,
      'is_available': (product['isAvailable'] == true) ? 1 : 0,
      'image_url': product['imageUrl'] ?? '',
      'unit': product['unit'] ?? '',
      'barcode': product['barcode'] ?? '',
      'data_json': jsonEncode(product),
      'synced_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {
    final db = await database;
    final batch = db.batch();
    for (final product in products) {
      batch.insert('products', {
        'id': product['id'],
        'name': product['name'] ?? '',
        'category': product['category'] ?? '',
        'price': (product['price'] ?? 0).toDouble(),
        'stock_quantity': product['stockQuantity'] ?? 0,
        'is_available': (product['isAvailable'] == true) ? 1 : 0,
        'image_url': product['imageUrl'] ?? '',
        'unit': product['unit'] ?? '',
        'barcode': product['barcode'] ?? '',
        'data_json': jsonEncode(product),
        'synced_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    debugPrint('[SqliteService] Cached ${products.length} products.');
  }

  Future<List<Map<String, dynamic>>> getCachedProducts() async {
    final db = await database;
    final rows = await db.query('products');
    return rows.map((r) => jsonDecode(r['data_json'] as String) as Map<String, dynamic>).toList();
  }

  Future<void> clearProductCache() async {
    final db = await database;
    await db.delete('products');
  }

  // ─────────────── ORDERS ───────────────

  Future<void> saveOrder(Map<String, dynamic> order) async {
    final db = await database;
    await db.insert('orders', {
      'id': order['id'],
      'order_number': order['orderNumber'] ?? '',
      'customer_id': order['customerId'] ?? '',
      'customer_name': order['customerName'] ?? '',
      'status': order['status'] ?? 'pending',
      'payment_method': order['paymentMethod']?.toString() ?? '',
      'payment_status': order['paymentStatus'] ?? 'pending',
      'total_amount': (order['totalAmount'] ?? 0).toDouble(),
      'is_synced': 0,
      'data_json': jsonEncode(order),
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedOrders() async {
    final db = await database;
    final rows = await db.query('orders', where: 'is_synced = ?', whereArgs: [0]);
    return rows.map((r) => jsonDecode(r['data_json'] as String) as Map<String, dynamic>).toList();
  }

  Future<void> markOrderSynced(String orderId) async {
    final db = await database;
    await db.update(
      'orders',
      {'is_synced': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> deleteOrder(String orderId) async {
    final db = await database;
    await db.delete('orders', where: 'id = ?', whereArgs: [orderId]);
  }

  // ─────────────── CART ───────────────

  Future<void> saveCartItem(Map<String, dynamic> item) async {
    final db = await database;
    await db.insert('cart', {
      'id': item['id'],
      'product_id': item['productId'],
      'product_name': item['productName'] ?? '',
      'price': (item['price'] ?? 0).toDouble(),
      'quantity': item['quantity'] ?? 1,
      'unit': item['unit'] ?? '',
      'data_json': jsonEncode(item),
      'added_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getCartItems() async {
    final db = await database;
    final rows = await db.query('cart');
    return rows.map((r) => jsonDecode(r['data_json'] as String) as Map<String, dynamic>).toList();
  }

  Future<void> updateCartItemQuantity(String itemId, int quantity) async {
    final db = await database;
    if (quantity <= 0) {
      await db.delete('cart', where: 'id = ?', whereArgs: [itemId]);
    } else {
      final rows = await db.query('cart', where: 'id = ?', whereArgs: [itemId]);
      if (rows.isNotEmpty) {
        final item = jsonDecode(rows.first['data_json'] as String) as Map<String, dynamic>;
        item['quantity'] = quantity;
        await db.update(
          'cart',
          {'quantity': quantity, 'data_json': jsonEncode(item)},
          where: 'id = ?',
          whereArgs: [itemId],
        );
      }
    }
  }

  Future<void> removeCartItem(String itemId) async {
    final db = await database;
    await db.delete('cart', where: 'id = ?', whereArgs: [itemId]);
  }

  Future<void> clearCart() async {
    final db = await database;
    await db.delete('cart');
  }

  // ─────────────── INVENTORY ───────────────

  Future<void> saveInventoryAction(Map<String, dynamic> action) async {
    final db = await database;
    await db.insert('inventory', {
      'id': action['id'],
      'product_id': action['productId'],
      'action_type': action['actionType'] ?? 'receive',
      'quantity': action['quantity'] ?? 0,
      'batch_number': action['batchNumber'] ?? '',
      'notes': action['notes'] ?? '',
      'shop_id': action['shopId'] ?? '',
      'branch_id': action['branchId'] ?? '',
      'is_synced': 0,
      'data_json': jsonEncode(action),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedInventoryActions() async {
    final db = await database;
    final rows = await db.query('inventory', where: 'is_synced = ?', whereArgs: [0]);
    return rows.map((r) => jsonDecode(r['data_json'] as String) as Map<String, dynamic>).toList();
  }

  Future<void> markInventoryActionSynced(String actionId) async {
    final db = await database;
    await db.update('inventory', {'is_synced': 1}, where: 'id = ?', whereArgs: [actionId]);
  }

  // ─────────────── PENDING SYNC QUEUE ───────────────

  Future<void> enqueuePendingSync({
    required String id,
    required String actionType,
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    final db = await database;
    await db.insert('pending_sync', {
      'id': id,
      'action_type': actionType,
      'collection': collection,
      'document_id': documentId,
      'data_json': jsonEncode(data),
      'retry_count': 0,
      'status': 'queued',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'last_tried_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    debugPrint('[SqliteService] Enqueued sync: $actionType/$collection/$documentId');
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await database;
    final rows = await db.query(
      'pending_sync',
      where: 'status = ?',
      whereArgs: ['queued'],
      orderBy: 'created_at ASC',
    );
    return rows
        .map(
          (r) => {
            'id': r['id'],
            'actionType': r['action_type'],
            'collection': r['collection'],
            'documentId': r['document_id'],
            'data': jsonDecode(r['data_json'] as String),
            'retryCount': r['retry_count'],
          },
        )
        .toList();
  }

  Future<void> markSyncDone(String syncId) async {
    final db = await database;
    await db.update('pending_sync', {'status': 'synced'}, where: 'id = ?', whereArgs: [syncId]);
  }

  Future<void> markSyncFailed(String syncId, {int maxRetries = 5}) async {
    final db = await database;
    final rows = await db.query('pending_sync', where: 'id = ?', whereArgs: [syncId]);
    if (rows.isEmpty) return;
    final retryCount = (rows.first['retry_count'] as int) + 1;
    final newStatus = retryCount >= maxRetries ? 'dead_letter' : 'queued';
    await db.update(
      'pending_sync',
      {
        'retry_count': retryCount,
        'status': newStatus,
        'last_tried_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [syncId],
    );
  }

  Future<void> clearCompletedSyncItems() async {
    final db = await database;
    await db.delete('pending_sync', where: 'status = ?', whereArgs: ['synced']);
  }

  Future<int> getPendingSyncCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM pending_sync WHERE status = 'queued' OR status = 'processing'",
    );
    return (result.first['count'] as int?) ?? 0;
  }

  // ─────────────── AUDIT LOGS ───────────────

  Future<void> writeAuditLog({
    required String id,
    required String action,
    required String entityType,
    String? entityId,
    String? userId,
    String? details,
  }) async {
    final db = await database;
    await db.insert('audit_logs', {
      'id': id,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId ?? '',
      'user_id': userId ?? '',
      'details': details ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 100}) async {
    final db = await database;
    return await db.query('audit_logs', orderBy: 'timestamp DESC', limit: limit);
  }

  Future<void> clearOldAuditLogs({int keepDays = 30}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: keepDays)).millisecondsSinceEpoch;
    await db.delete('audit_logs', where: 'timestamp < ?', whereArgs: [cutoff]);
  }

  // ─────────────── UTILITY ───────────────

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('products');
    await db.delete('orders');
    await db.delete('cart');
    await db.delete('inventory');
    await db.delete('pending_sync');
    await db.delete('audit_logs');
    await db.delete('rider_shifts');
    await db.delete('rider_location_logs');
    await db.delete('rds_write_queue');
    debugPrint('[SqliteService] All local data cleared.');
  }

  // ─────────────── RDS WRITE QUEUE ───────────────

  Future<void> enqueueRDSWrite({
    required String id,
    required String sql,
    required List<dynamic> params,
  }) async {
    final db = await database;
    await db.insert('rds_write_queue', {
      'id': id,
      'sql_query': sql,
      'params_json': jsonEncode(params),
      'retry_count': 0,
      'status': 'queued',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'last_tried_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    debugPrint('[SqliteService] Enqueued RDS write task $id');
  }

  Future<List<Map<String, dynamic>>> getPendingRDSWrites() async {
    final db = await database;
    final rows = await db.query(
      'rds_write_queue',
      where: "status = 'queued' OR status = 'processing'",
      orderBy: 'created_at ASC',
    );
    return rows
        .map(
          (r) => {
            'id': r['id'],
            'sql': r['sql_query'],
            'params': jsonDecode(r['params_json'] as String) as List<dynamic>,
            'retryCount': r['retry_count'],
          },
        )
        .toList();
  }

  Future<void> markRDSWriteSynced(String id) async {
    final db = await database;
    await db.update('rds_write_queue', {'status': 'synced'}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markRDSWriteFailed(String id, {int maxRetries = 5}) async {
    final db = await database;
    final rows = await db.query('rds_write_queue', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final retryCount = (rows.first['retry_count'] as int) + 1;
    final newStatus = retryCount >= maxRetries ? 'dead_letter' : 'queued';
    await db.update(
      'rds_write_queue',
      {
        'retry_count': retryCount,
        'status': newStatus,
        'last_tried_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getPendingRDSWriteCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM rds_write_queue WHERE status = 'queued' OR status = 'processing'",
    );
    return (result.first['count'] as int?) ?? 0;
  }

  // ─────────────── RIDER SHIFTS ───────────────

  Future<void> saveRiderShift(Map<String, dynamic> shift) async {
    final db = await database;
    await db.insert('rider_shifts', {
      'id': shift['id'],
      'rider_id': shift['riderId'],
      'branch_id': shift['branchId'],
      'current_state': shift['currentState'] ?? 'offline',
      'started_at': shift['startedAt'] is int
          ? shift['startedAt']
          : (shift['startedAt'] as DateTime).millisecondsSinceEpoch,
      'ended_at': shift['endedAt'] == null
          ? null
          : (shift['endedAt'] is int
                ? shift['endedAt']
                : (shift['endedAt'] as DateTime).millisecondsSinceEpoch),
      'total_deliveries': shift['totalDeliveries'] ?? 0,
      'total_earnings': (shift['totalEarnings'] ?? 0.0).toDouble(),
      'total_distance': (shift['totalDistance'] ?? 0.0).toDouble(),
      'total_incidents': shift['totalIncidents'] ?? 0,
      'is_synced': shift['isSynced'] ?? 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRiderShifts() async {
    final db = await database;
    return await db.query('rider_shifts', where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<void> markRiderShiftSynced(String id) async {
    final db = await database;
    await db.update('rider_shifts', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────── RIDER LOCATION LOGS ───────────────

  Future<void> saveRiderLocation(Map<String, dynamic> loc) async {
    final db = await database;
    await db.insert('rider_location_logs', {
      'id': loc['id'] ?? '${loc['deliveryId']}_${DateTime.now().millisecondsSinceEpoch}',
      'delivery_id': loc['deliveryId'],
      'latitude': loc['latitude'],
      'longitude': loc['longitude'],
      'speed': loc['speed'] ?? 0.0,
      'accuracy': loc['accuracy'] ?? 0.0,
      'timestamp': loc['timestamp'] is int
          ? loc['timestamp']
          : (loc['timestamp'] as DateTime).millisecondsSinceEpoch,
      'is_synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedLocations() async {
    final db = await database;
    return await db.query('rider_location_logs', where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<void> markLocationsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update('rider_location_logs', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearSyncedLocations() async {
    final db = await database;
    await db.delete('rider_location_logs', where: 'is_synced = ?', whereArgs: [1]);
  }
}
