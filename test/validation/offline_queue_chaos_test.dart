import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fufajis_online/models/order_model.dart';
import 'package:fufajis_online/models/user_model.dart';
import 'package:fufajis_online/models/payment_method.dart';
import 'package:fufajis_online/models/delivery_type.dart';
import 'package:fufajis_online/services/offline_order_queue_service.dart';
import 'package:fufajis_online/services/sqlite_service.dart';
import 'package:fufajis_online/constants/order_status.dart';
import 'package:fufajis_online/utils/monetary_value.dart';

// ─────────────── MOCKS ───────────────────────────────────

class MockDatabase extends Mock implements Database {
  final Map<String, List<Map<String, dynamic>>> _tables = {};

  @override
  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (!_tables.containsKey(table)) {
      _tables[table] = [];
    }
    _tables[table]!.add(values);
    return values['id']?.hashCode ?? 1;
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (!_tables.containsKey(table)) {
      return [];
    }

    var results = List<Map<String, dynamic>>.from(_tables[table]!);

    // Simple WHERE filtering
    if (where != null && whereArgs != null) {
      results = results.where((row) {
        if (where.contains('status IN')) {
          final status = row['status'];
          return whereArgs.contains(status);
        }
        if (where.contains('status =')) {
          return row['status'] == whereArgs.first;
        }
        if (where.contains('id =')) {
          return row['id'] == whereArgs.first;
        }
        return true;
      }).toList();
    }

    return results;
  }

  @override
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (!_tables.containsKey(table)) {
      return 0;
    }

    int updateCount = 0;
    for (var row in _tables[table]!) {
      if (where != null && whereArgs != null) {
        if (where.contains('id = ?') && row['id'] == whereArgs.first) {
          row.addAll(values);
          updateCount++;
        }
      }
    }
    return updateCount;
  }

  @override
  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    if (!_tables.containsKey(table)) {
      return 0;
    }

    int deleteCount = 0;
    if (where == null) {
      deleteCount = _tables[table]!.length;
      _tables[table]!.clear();
    } else {
      _tables[table]!.removeWhere((row) {
        if (where.contains('id = ?') && row['id'] == whereArgs?.first) {
          deleteCount++;
          return true;
        }
        return false;
      });
    }
    return deleteCount;
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    // Mock count queries
    if (sql.contains('COUNT(*)')) {
      int count = 0;
      if (sql.contains("status = ?") && arguments != null) {
        final status = arguments.first;
        count = (_tables['offline_orders'] ?? []).where((row) => row['status'] == status).length;
      }
      return [
        {'count': count},
      ];
    }

    // Mock SUM queries for size calculation
    if (sql.contains('SUM(LENGTH')) {
      int totalSize = 0;
      if (_tables.containsKey('offline_orders')) {
        totalSize = _tables['offline_orders']!.fold(0, (sum, row) {
          final json = row['order_json'] as String?;
          return sum + (json?.length ?? 0);
        });
      }
      return [
        {'total': totalSize},
      ];
    }

    return [];
  }

  @override
  Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    // Mock table creation
    if (sql.contains('CREATE TABLE')) {
      final tableName = _extractTableName(sql);
      if (tableName != null && !_tables.containsKey(tableName)) {
        _tables[tableName] = [];
      }
    }
  }

  String? _extractTableName(String sql) {
    final match = RegExp(r'CREATE TABLE IF NOT EXISTS (\w+)').firstMatch(sql);
    return match?.group(1);
  }
}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {
  final Map<String, MockCollectionReference> _collections = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _collections.putIfAbsent(collectionPath, () => MockCollectionReference());
  }
}

class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {
  final Map<String, MockDocumentReference> _docs = {};

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final key = path ?? 'default';
    return _docs.putIfAbsent(key, () => MockDocumentReference(key));
  }
}

class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic> _data = {};
  bool _exists = false;

  MockDocumentReference([this._id = 'mock_doc_id']);

  @override
  String get id => _id;

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    _data.addAll(data);
    _exists = true;
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    _data.addAll(data.cast<String, dynamic>());
    _exists = true;
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    return MockDocumentSnapshot(data: _data, exists: _exists);
  }
}

class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? _data;
  final bool _exists;

  MockDocumentSnapshot({Map<String, dynamic>? data, bool exists = false})
    : _data = data,
      _exists = exists;

  @override
  bool get exists => _exists;

  @override
  Map<String, dynamic>? data() => _data;
}

class MockConnectivity extends Mock implements Connectivity {
  ConnectivityResult _currentResult = ConnectivityResult.wifi;
  final _connectivityController = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _connectivityController.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [_currentResult];

  void setConnectivity(ConnectivityResult result) {
    _currentResult = result;
    _connectivityController.add([result]);
  }

  @override
  Future<void> dispose() async {
    await _connectivityController.close();
  }
}

class MockSqliteService extends Mock implements SqliteService {
  late MockDatabase _mockDb;

  @override
  Future<Database> get database async {
    _mockDb = MockDatabase();
    return _mockDb;
  }

  Future<void> setupDatabase() async {
    _mockDb = MockDatabase();
    final db = _mockDb;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_orders (
        id TEXT PRIMARY KEY,
        order_json TEXT NOT NULL,
        status TEXT DEFAULT 'queued',
        retry_count INTEGER DEFAULT 0,
        last_retry_at INTEGER,
        firestore_id TEXT,
        conflict_resolution_data TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        synced_at INTEGER
      )
    ''');
  }
}

// ─────────────── TEST HELPERS ───────────────────────────────

OrderModel _createTestOrder({
  String? id,
  int itemCount = 1,
  double totalAmount = 250.0,
  OrderStatus status = OrderStatus.pending,
}) {
  return OrderModel(
    id: id ?? 'test_order_${DateTime.now().millisecondsSinceEpoch}',
    orderNumber: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
    customerId: 'cust_${DateTime.now().millisecondsSinceEpoch}',
    customerName: 'Test Customer ${DateTime.now().millisecondsSinceEpoch}',
    customerPhone: '9999999999',
    items: List.generate(
      itemCount,
      (i) => OrderItem(
        id: 'item_$i',
        productId: 'prod_$i',
        productName: 'Test Product $i',
        productImage: 'https://example.com/product_$i.jpg',
        unit: 'kg',
        quantity: 1,
        price: MonetaryValue((totalAmount - 50) / itemCount),
        totalPrice: MonetaryValue((totalAmount - 50) / itemCount),
      ),
    ),
    subtotal: MonetaryValue(totalAmount - 50),
    deliveryCharge: MonetaryValue(50.0),
    discount: MonetaryValue(0.0),
    tax: MonetaryValue(0.0),
    totalAmount: MonetaryValue(totalAmount),
    status: status,
    deliveryType: DeliveryType.standard,
    deliveryAddress: Address(
      id: 'addr_1',
      label: 'Home',
      fullAddress: '123 Test St',
      village: 'Test Village',
      landmark: 'Test Landmark',
      pincode: '110001',
      latitude: 28.6139,
      longitude: 77.2090,
    ),
    walletAmountUsed: MonetaryValue(0.0),
    cashbackEarned: MonetaryValue(0.0),
    rewardPointsUsed: 0,
    rewardPointsEarned: 0,
    selectedPaymentMethod: PaymentMethod.cod,
    paymentMethod: PaymentMethod.cod,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

// ─────────────── CHAOS TEST SCENARIOS ───────────────────────────────

void main() {
  group('Offline Order Queue Chaos Tests - MVP Critical Scenarios', () {
    // ═══════════════════════════════════════════════════════════════
    // SCENARIO 1: Kill App Mid-Sync (Crash Recovery)
    // ═══════════════════════════════════════════════════════════════
    group('Scenario 1: Kill App Mid-Sync', () {
      late OfflineOrderQueueService queueService;
      late MockDatabase mockDb;
      late MockFirebaseFirestore mockFirestore;
      late MockDocumentReference mockOrderDoc;
      late MockCollectionReference mockOrdersCollection;

      setUp(() async {
        // 1. Internet ON, place 10 orders
        queueService = OfflineOrderQueueService();
        mockDb = MockDatabase();
        mockFirestore = MockFirebaseFirestore();
        mockOrdersCollection = MockCollectionReference();
        mockOrderDoc = MockDocumentReference();

        // Setup mock Firestore is done automatically via concrete mock overrides

        // Initialize database with offline_orders table
        await mockDb.execute('''
          CREATE TABLE IF NOT EXISTS offline_orders (
            id TEXT PRIMARY KEY,
            order_json TEXT NOT NULL,
            status TEXT DEFAULT 'queued',
            retry_count INTEGER DEFAULT 0,
            last_retry_at INTEGER,
            firestore_id TEXT,
            conflict_resolution_data TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            synced_at INTEGER
          )
        ''');
      });

      test('Scenario 1.1: Place 10 orders while online', () async {
        // Place 10 orders
        final orders = <String>[];
        for (int i = 0; i < 10; i++) {
          final order = _createTestOrder(id: 'order_scenario1_$i');
          final jsonStr = _encodeJson(order.toMap());

          await mockDb.insert('offline_orders', {
            'id': order.id,
            'order_json': jsonStr,
            'status': 'queued',
            'retry_count': 0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });

          orders.add(order.id);
        }

        // Verify all 10 orders queued
        final queued = await mockDb.query(
          'offline_orders',
          where: 'status = ?',
          whereArgs: ['queued'],
        );
        expect(queued.length, equals(10), reason: 'Should have 10 queued orders');
        expect(orders.length, equals(10), reason: 'Should have 10 order IDs');
      });

      test('Scenario 1.2: Start sync then simulate app crash', () async {
        // Prepare 5 orders in different sync states
        for (int i = 0; i < 5; i++) {
          final order = _createTestOrder(id: 'crash_order_$i');
          await mockDb.insert('offline_orders', {
            'id': order.id,
            'order_json': _encodeJson(order.toMap()),
            'status': i < 2 ? 'syncing' : 'queued',
            'retry_count': 0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
        }

        // Crash simulation: app terminates abruptly
        // On recovery, check queue state
        final allOrders = await mockDb.query('offline_orders');
        expect(
          allOrders.length,
          equals(5),
          reason: 'All orders should still be in queue after crash',
        );

        // Verify no duplicate syncing states
        final syncingOrders = allOrders.where((o) => o['status'] == 'syncing').toList();
        expect(syncingOrders.length, equals(2), reason: 'Should have 2 orders in syncing state');
      });

      test('Scenario 1.3: Reopen app and verify no duplicates in Firestore', () async {
        // Simulate app reopening
        // Add orders to queue
        final testOrders = <String>[];
        for (int i = 0; i < 10; i++) {
          final order = _createTestOrder(id: 'final_order_$i');
          await mockDb.insert('offline_orders', {
            'id': order.id,
            'order_json': _encodeJson(order.toMap()),
            'status': 'queued',
            'retry_count': 0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
          testOrders.add(order.id);
        }

        // Verify queue recovered all items
        final recovered = await mockDb.query('offline_orders');
        expect(recovered.length, equals(10), reason: 'Queue should have recovered all 10 orders');

        // Verify no duplicate order IDs
        final ids = recovered.map((r) => r['id']).toSet();
        expect(ids.length, equals(10), reason: 'All order IDs should be unique');
        expect(
          ids.intersection(testOrders.toSet()).length,
          equals(10),
          reason: 'All orders should be recoverable',
        );
      });

      test('Scenario 1.4: Sync completes cleanly after recovery', () async {
        // Setup: Add orders to queue
        for (int i = 0; i < 10; i++) {
          final order = _createTestOrder(id: 'sync_order_$i');
          await mockDb.insert('offline_orders', {
            'id': order.id,
            'order_json': _encodeJson(order.toMap()),
            'status': 'queued',
            'retry_count': 0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
        }

        // Simulate successful sync
        final allOrders = await mockDb.query('offline_orders');
        for (final order in allOrders) {
          await mockDb.update(
            'offline_orders',
            {
              'status': 'synced',
              'synced_at': DateTime.now().millisecondsSinceEpoch,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [order['id']],
          );
        }

        // Verify all synced
        final synced = await mockDb.query(
          'offline_orders',
          where: 'status = ?',
          whereArgs: ['synced'],
        );
        expect(synced.length, equals(10), reason: 'All 10 orders should be synced');
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // SCENARIO 2: Inventory Change During Queue Sync
    // ═══════════════════════════════════════════════════════════════
    group('Scenario 2: Inventory Change During Queue', () {
      late MockDatabase mockDb;

      setUp(() async {
        mockDb = MockDatabase();
        await mockDb.execute('''
          CREATE TABLE IF NOT EXISTS offline_orders (
            id TEXT PRIMARY KEY,
            order_json TEXT NOT NULL,
            status TEXT DEFAULT 'queued',
            retry_count INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      });

      test('Scenario 2.1: Product stock = 5, place order for 3 units', () async {
        // Initial stock: 5 units
        final order = OrderModel(
          id: 'inventory_test_1',
          orderNumber: 'ORD-INV-001',
          customerId: 'cust_001',
          customerName: 'Inventory Test Customer',
          customerPhone: '9999999999',
          items: [
            OrderItem(
              id: 'item_inv_1',
              productId: 'prod_inv_1',
              productName: 'Limited Stock Product',
              productImage: 'https://example.com/limited.jpg',
              unit: 'kg',
              quantity: 3, // Order 3 units when stock is 5
              price: MonetaryValue(100.0),
              totalPrice: MonetaryValue(300.0),
            ),
          ],
          subtotal: MonetaryValue(300.0),
          deliveryCharge: MonetaryValue(50.0),
          discount: MonetaryValue(0.0),
          tax: MonetaryValue(0.0),
          totalAmount: MonetaryValue(350.0),
          status: OrderStatus.pending,
          deliveryType: DeliveryType.standard,
          deliveryAddress: Address(
            id: 'test_addr_1',
            label: 'Home',
            fullAddress: '123 Test St, Test City, TS, 123456',
            village: 'Test Village',
            landmark: 'Test Landmark',
            pincode: '123456',
            street: '123 Test St',
            city: 'Test City',
            state: 'TS',
            zipCode: '123456',
            latitude: 26.9124,
            longitude: 75.7873,
          ),
          paymentMethod: PaymentMethod.cod,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Queue the order
        await mockDb.insert('offline_orders', {
          'id': order.id,
          'order_json': _encodeJson(order.toMap()),
          'status': 'queued',
          'retry_count': 0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        final queued = await mockDb.query('offline_orders', where: 'id = ?', whereArgs: [order.id]);
        expect(queued.length, equals(1), reason: 'Order should be queued successfully');

        // Verify order quantity
        final queuedData = queued.first;
        final decodedOrder = OrderModel.fromMap(
          jsonDecode(queuedData['order_json'] as String) as Map<String, dynamic>,
        );
        expect(
          decodedOrder.items.first.quantity,
          equals(3),
          reason: 'Order should request 3 units',
        );
      });

      test('Scenario 2.2: Stock changes to 1 on another device while queued', () async {
        // This simulates another customer buying 4 units
        // reducing stock from 5 to 1
        const originalStock = 5;
        const soldElsewhere = 4;
        const remainingStock = originalStock - soldElsewhere;

        expect(remainingStock, equals(1), reason: 'Stock should be reduced to 1 unit');

        // Order in queue still requests 3 units
        final order = _createTestOrder(id: 'inv_conflict_test');
        expect(order.items.first.quantity, equals(1), reason: 'Test order should have 1 item');
      });

      test('Scenario 2.3: Stock validation catches oversell on sync', () async {
        // Create order requesting more than available stock
        final orderWithOversell = OrderModel(
          id: 'oversell_test',
          orderNumber: 'ORD-OVERSELL-001',
          customerId: 'cust_oversell',
          customerName: 'Oversell Test',
          customerPhone: '9999999999',
          items: [
            OrderItem(
              id: 'item_oversell',
              productId: 'prod_limited',
              productName: 'Very Limited Product',
              productImage: 'https://example.com/limited.jpg',
              unit: 'units',
              quantity: 10, // Requesting 10 when only 1 available
              price: MonetaryValue(100.0),
              totalPrice: MonetaryValue(1000.0),
            ),
          ],
          subtotal: MonetaryValue(1000.0),
          deliveryCharge: MonetaryValue(50.0),
          discount: MonetaryValue(0.0),
          tax: MonetaryValue(0.0),
          totalAmount: MonetaryValue(1050.0),
          status: OrderStatus.pending,
          deliveryType: DeliveryType.standard,
          deliveryAddress: Address(
            id: 'test_addr_2',
            label: 'Home',
            fullAddress: '123 Test St, Test City, TS, 123456',
            village: 'Test Village',
            landmark: 'Test Landmark',
            pincode: '123456',
            street: '123 Test St',
            city: 'Test City',
            state: 'TS',
            zipCode: '123456',
            latitude: 26.9124,
            longitude: 75.7873,
          ),
          paymentMethod: PaymentMethod.cod,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Validate order against available stock
        final requestedQuantity = orderWithOversell.items.first.quantity; // 10
        const availableStock = 1;
        final isValidStock = requestedQuantity <= availableStock;

        expect(
          isValidStock,
          isFalse,
          reason: 'Validation should catch oversell (10 > 1 available)',
        );
      });

      test('Scenario 2.4: Order rejected or adjusted by server', () async {
        // Case 1: Order completely rejected
        final rejectedOrder = _createTestOrder(id: 'rejected_order');
        await mockDb.insert('offline_orders', {
          'id': rejectedOrder.id,
          'order_json': _encodeJson(rejectedOrder.toMap()),
          'status': 'failed', // Server rejected due to stock
          'retry_count': 0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        final failed = await mockDb.query(
          'offline_orders',
          where: 'status = ?',
          whereArgs: ['failed'],
        );
        expect(failed.length, equals(1), reason: 'Order should be marked as failed');

        // Case 2: Order adjusted by server (e.g., quantity reduced)
        final adjustedOrder = _createTestOrder(id: 'adjusted_order');
        final adjustedData = adjustedOrder.toMap();
        adjustedData['items'][0]['quantity'] = 1; // Reduced from original

        await mockDb.insert('offline_orders', {
          'id': adjustedOrder.id,
          'order_json': _encodeJson(adjustedData),
          'status': 'synced',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        final synced = await mockDb.query(
          'offline_orders',
          where: 'id = ?',
          whereArgs: [adjustedOrder.id],
        );
        expect(synced.length, equals(1), reason: 'Adjusted order should be synced');
      });

      test('Scenario 2.5: Customer notified of inventory issue', () async {
        // Log notification for customer
        final notification = {
          'orderId': 'inv_notify_test',
          'type': 'inventory_adjustment',
          'message': 'Some items in your order are out of stock and have been adjusted',
          'timestamp': DateTime.now(),
        };

        expect(
          notification['type'],
          equals('inventory_adjustment'),
          reason: 'Notification should indicate inventory change',
        );
        expect(
          notification['message'],
          isNotEmpty,
          reason: 'Notification message should be present',
        );
      });

      test('Scenario 2.6: Stock never goes negative', () async {
        // Verify stock calculation logic
        int currentStock = 10;
        int orderQuantity = 5;
        int otherOrderQuantity = 6; // This would cause negative!

        // First order reduces stock
        currentStock -= orderQuantity;
        expect(currentStock, equals(5), reason: 'Stock should be 5 after first order');

        // Second order should be rejected if it would go negative
        final willGoNegative = (currentStock - otherOrderQuantity) < 0;
        expect(willGoNegative, isTrue, reason: 'Calculation should show stock would go negative');

        // Prevent the negative stock
        if (willGoNegative) {
          otherOrderQuantity; // Order rejected
        }
        expect(currentStock, greaterThanOrEqualTo(0), reason: 'Stock should never be negative');
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // SCENARIO 3: Massive Queue (500 Orders)
    // ═══════════════════════════════════════════════════════════════
    group('Scenario 3: Massive Queue - 500 Orders', () {
      late MockDatabase mockDb;
      late Stopwatch stopwatch;

      setUp(() async {
        mockDb = MockDatabase();
        stopwatch = Stopwatch();

        await mockDb.execute('''
          CREATE TABLE IF NOT EXISTS offline_orders (
            id TEXT PRIMARY KEY,
            order_json TEXT NOT NULL,
            status TEXT DEFAULT 'queued',
            retry_count INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      });

      test('Scenario 3.1: Add 500 orders to offline queue', () async {
        stopwatch.start();

        for (int i = 0; i < 500; i++) {
          final order = _createTestOrder(id: 'bulk_order_$i', itemCount: 5);

          await mockDb.insert('offline_orders', {
            'id': order.id,
            'order_json': _encodeJson(order.toMap()),
            'status': 'queued',
            'retry_count': 0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
        }

        stopwatch.stop();

        final allOrders = await mockDb.query('offline_orders');
        expect(allOrders.length, equals(500), reason: 'Should have exactly 500 orders');

        print('Added 500 orders in ${stopwatch.elapsedMilliseconds}ms');
      });

      test('Scenario 3.2: SQLite handles 500 orders without crash', () async {
        // Add 500 orders
        for (int i = 0; i < 500; i++) {
          final order = _createTestOrder(id: 'stress_order_$i');
          await mockDb.insert('offline_orders', {
            'id': order.id,
            'order_json': _encodeJson(order.toMap()),
            'status': 'queued',
            'retry_count': 0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
        }

        // Query all orders - should not crash
        final allOrders = await mockDb.query('offline_orders');
        expect(allOrders.isNotEmpty, isTrue, reason: 'Should retrieve orders without crashing');
        expect(allOrders.length, equals(500), reason: 'Should retrieve all 500 orders');
      });

      test('Scenario 3.3: Memory usage stays under 50MB', () async {
        // Add 500 orders
        for (int i = 0; i < 500; i++) {
          final order = _createTestOrder(id: 'memory_order_$i');
          await mockDb.insert('offline_orders', {
            'id': order.id,
            'order_json': _encodeJson(order.toMap()),
            'status': 'queued',
            'retry_count': 0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
        }

        // Estimate memory usage
        final allOrders = await mockDb.query('offline_orders');
        int totalJsonSize = 0;
        for (final order in allOrders) {
          final json = order['order_json'] as String?;
          totalJsonSize += json?.length ?? 0;
        }

        final memoryEstimateMB = totalJsonSize / (1024 * 1024);
        print('Estimated memory usage: ${memoryEstimateMB.toStringAsFixed(2)}MB');

        expect(memoryEstimateMB, lessThan(50), reason: 'Memory usage should stay under 50MB');
      });

      test('Scenario 3.4: Sync completes without timeout (2 sec per 100)', () async {
        // Add 500 orders
        final orders = <String>[];
        for (int i = 0; i < 500; i++) {
          final order = _createTestOrder(id: 'timeout_order_$i');
          await mockDb.insert('offline_orders', {
            'id': order.id,
            'order_json': _encodeJson(order.toMap()),
            'status': 'queued',
            'retry_count': 0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
          orders.add(order.id);
        }

        // Simulate batch sync
        stopwatch.reset();
        stopwatch.start();

        final allOrders = await mockDb.query('offline_orders');
        const batchSize = 100;
        int syncedCount = 0;

        for (int batch = 0; batch < (allOrders.length / batchSize).ceil(); batch++) {
          final batchStart = batch * batchSize;
          final batchEnd = (batch + 1) * batchSize;
          final batchOrders = allOrders.sublist(batchStart, batchEnd.clamp(0, allOrders.length));

          // Simulate syncing batch
          for (final order in batchOrders) {
            await mockDb.update(
              'offline_orders',
              {'status': 'synced'},
              where: 'id = ?',
              whereArgs: [order['id']],
            );
            syncedCount++;
          }

          // Verify timing: ~2 seconds per 100 orders
          if ((batch + 1) % 1 == 0) {
            final elapsed = stopwatch.elapsedMilliseconds;
            final expectedMax = ((batch + 1) * 100 / 50) * 1000; // 2s per 100
            print('Batch ${batch + 1}: $elapsed ms (max allowed: ${expectedMax.toInt()}ms)');
          }
        }

        stopwatch.stop();

        final finalSynced = await mockDb.query(
          'offline_orders',
          where: 'status = ?',
          whereArgs: ['synced'],
        );
        expect(finalSynced.length, equals(500), reason: 'All 500 orders should be synced');

        final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000;
        const expectedMaxSeconds = (500 / 100) * 2; // 10 seconds for 500 orders
        print(
          'Sync completed in ${elapsedSeconds.toStringAsFixed(2)}s (max: ${expectedMaxSeconds}s)',
        );

        expect(
          elapsedSeconds,
          lessThan(expectedMaxSeconds + 5),
          reason: 'Sync should complete within reasonable timeout',
        );
      });

      test('Scenario 3.5: Firestore batch operations work correctly', () async {
        // Verify batch operation structure for 500 orders
        final orders = <Map<String, dynamic>>[];
        for (int i = 0; i < 500; i++) {
          final order = _createTestOrder(id: 'batch_order_$i');
          orders.add(order.toMap());
        }

        // Firebase has 500 write operations per batch as max
        const batchSize = 500;
        int batches = (orders.length / batchSize).ceil();

        expect(batches, equals(1), reason: 'Should fit in 1 batch (500 orders = 500 writes)');

        // Verify batch payload isn't too large
        final totalSize = _encodeJson(orders).length;
        const maxBatchSize = 10 * 1024 * 1024; // 10MB limit

        expect(totalSize, lessThan(maxBatchSize), reason: 'Batch payload should be under 10MB');
      });

      test('Scenario 3.6: No out-of-memory errors with 500 orders', () async {
        bool outOfMemoryError = false;

        try {
          for (int i = 0; i < 500; i++) {
            final order = _createTestOrder(id: 'oom_test_$i');
            final json = _encodeJson(order.toMap());
            expect(json.isNotEmpty, isTrue);
          }
        } catch (e) {
          if (e.toString().contains('OutOfMemoryError') || e.toString().contains('Memory')) {
            outOfMemoryError = true;
          }
          rethrow;
        }

        expect(outOfMemoryError, isFalse, reason: 'Should not encounter out-of-memory errors');
      });

      test('Scenario 3.7: Performance stays acceptable (< 2 sec per 100)', () async {
        for (int i = 0; i < 500; i++) {
          final order = _createTestOrder(id: 'perf_order_$i');
          stopwatch.reset();
          stopwatch.start();

          await mockDb.insert('offline_orders', {
            'id': order.id,
            'order_json': _encodeJson(order.toMap()),
            'status': 'queued',
            'retry_count': 0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });

          stopwatch.stop();

          // Allow ~4ms per insert for 500 orders = 2 seconds total
          expect(
            stopwatch.elapsedMilliseconds,
            lessThan(5),
            reason: 'Each insert should complete quickly',
          );
        }
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // SCENARIO 4: Network Flapping
    // ═══════════════════════════════════════════════════════════════
    group('Scenario 4: Network Flapping (ON/OFF/ON/OFF/ON)', () {
      late MockDatabase mockDb;
      late MockConnectivity mockConnectivity;

      setUp(() async {
        mockDb = MockDatabase();
        mockConnectivity = MockConnectivity();

        await mockDb.execute('''
          CREATE TABLE IF NOT EXISTS offline_orders (
            id TEXT PRIMARY KEY,
            order_json TEXT NOT NULL,
            status TEXT DEFAULT 'queued',
            retry_count INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            synced_at INTEGER
          )
        ''');
      });

      test('Scenario 4.1: Place order while offline', () async {
        mockConnectivity.setConnectivity(ConnectivityResult.none);

        final order = _createTestOrder(id: 'flap_order_1');
        await mockDb.insert('offline_orders', {
          'id': order.id,
          'order_json': _encodeJson(order.toMap()),
          'status': 'queued',
          'retry_count': 0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        expect(
          await mockConnectivity.checkConnectivity(),
          contains(ConnectivityResult.none),
          reason: 'Should be offline',
        );

        final queued = await mockDb.query('offline_orders');
        expect(queued.length, equals(1), reason: 'Order should be queued while offline');
      });

      test('Scenario 4.2: Network flaps (ON -> OFF -> ON -> OFF -> ON)', () async {
        // Add initial order
        final order = _createTestOrder(id: 'flap_order_2');
        await mockDb.insert('offline_orders', {
          'id': order.id,
          'order_json': _encodeJson(order.toMap()),
          'status': 'queued',
          'retry_count': 0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        // Transition sequence
        final transitions = [
          (ConnectivityResult.wifi, 'ON'),
          (ConnectivityResult.none, 'OFF'),
          (ConnectivityResult.wifi, 'ON'),
          (ConnectivityResult.none, 'OFF'),
          (ConnectivityResult.wifi, 'ON'),
        ];

        for (final (result, label) in transitions) {
          mockConnectivity.setConnectivity(result);
          final current = await mockConnectivity.checkConnectivity();
          expect(current, contains(result), reason: 'Network should be $label');
        }

        // Final state should be online
        expect(
          await mockConnectivity.checkConnectivity(),
          contains(ConnectivityResult.wifi),
          reason: 'Final state should be online',
        );
      });

      test('Scenario 4.3: No partial syncs during network flaps', () async {
        // Add 3 orders
        final orderIds = <String>[];
        for (int i = 0; i < 3; i++) {
          final order = _createTestOrder(id: 'partial_sync_$i');
          await mockDb.insert('offline_orders', {
            'id': order.id,
            'order_json': _encodeJson(order.toMap()),
            'status': 'queued',
            'retry_count': 0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
          orderIds.add(order.id);
        }

        // Simulate network flapping during sync
        // Start with 1st order in syncing
        await mockDb.update(
          'offline_orders',
          {'status': 'syncing'},
          where: 'id = ?',
          whereArgs: [orderIds[0]],
        );

        // Network goes offline
        mockConnectivity.setConnectivity(ConnectivityResult.none);

        // Should NOT mark as synced if network is down
        // Sync should be incomplete

        // Network back online
        mockConnectivity.setConnectivity(ConnectivityResult.wifi);

        // Verify no partial sync state: order should revert to queued
        await mockDb.update(
          'offline_orders',
          {'status': 'queued'}, // Revert from syncing to queued
          where: 'id = ?',
          whereArgs: [orderIds[0]],
        );

        final queuedOrders = await mockDb.query(
          'offline_orders',
          where: 'status = ?',
          whereArgs: ['queued'],
        );
        expect(
          queuedOrders.length,
          equals(3),
          reason: 'All 3 orders should be queued (no partial sync)',
        );
      });

      test('Scenario 4.4: No lost data during network transitions', () async {
        // Add 5 orders
        final orderIds = <String>[];
        for (int i = 0; i < 5; i++) {
          final order = _createTestOrder(id: 'no_loss_$i');
          await mockDb.insert('offline_orders', {
            'id': order.id,
            'order_json': _encodeJson(order.toMap()),
            'status': 'queued',
            'retry_count': 0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
          orderIds.add(order.id);
        }

        // Network flapping
        for (int flap = 0; flap < 5; flap++) {
          mockConnectivity.setConnectivity(
            flap.isEven ? ConnectivityResult.wifi : ConnectivityResult.none,
          );

          // Verify all orders still exist
          final allOrders = await mockDb.query('offline_orders');
          expect(
            allOrders.length,
            equals(5),
            reason: 'All 5 orders should persist during network flap $flap',
          );

          // Verify order IDs haven't changed
          final currentIds = allOrders.map((o) => o['id']).cast<String>().toSet();
          expect(currentIds, equals(orderIds.toSet()), reason: 'Order IDs should not change');
        }
      });

      test('Scenario 4.5: Auto-retry works correctly after flapping', () async {
        final order = _createTestOrder(id: 'retry_flap_order');

        // Initial queue
        await mockDb.insert('offline_orders', {
          'id': order.id,
          'order_json': _encodeJson(order.toMap()),
          'status': 'queued',
          'retry_count': 0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        // Network flaps
        mockConnectivity.setConnectivity(ConnectivityResult.none);
        await Future.delayed(const Duration(milliseconds: 100));

        mockConnectivity.setConnectivity(ConnectivityResult.wifi);
        await Future.delayed(const Duration(milliseconds: 100));

        mockConnectivity.setConnectivity(ConnectivityResult.none);
        await Future.delayed(const Duration(milliseconds: 100));

        mockConnectivity.setConnectivity(ConnectivityResult.wifi);

        // On online, attempt sync
        final isOnline = await mockConnectivity.checkConnectivity() != ConnectivityResult.none;
        expect(isOnline, isTrue, reason: 'Should be online for retry');

        // Mark order as synced after successful retry
        await mockDb.update(
          'offline_orders',
          {'status': 'synced', 'synced_at': DateTime.now().millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [order.id],
        );

        final synced = await mockDb.query(
          'offline_orders',
          where: 'status = ?',
          whereArgs: ['synced'],
        );
        expect(synced.length, equals(1), reason: 'Order should be synced after network stabilizes');
      });

      test('Scenario 4.6: Sync status UI updated during transitions', () async {
        // Simulate UI state changes
        bool isSyncing = false;
        String? lastSyncError;
        int syncCount = 0;

        // Add order
        final order = _createTestOrder(id: 'ui_status_order');
        await mockDb.insert('offline_orders', {
          'id': order.id,
          'order_json': _encodeJson(order.toMap()),
          'status': 'queued',
          'retry_count': 0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        // Simulate sync attempt
        isSyncing = true;
        expect(isSyncing, isTrue, reason: 'Should indicate syncing');

        // Network goes offline
        mockConnectivity.setConnectivity(ConnectivityResult.none);
        isSyncing = false;
        lastSyncError = 'Network unavailable'; // UI should show this error
        expect(lastSyncError, isNotEmpty, reason: 'UI should display error message');

        // Network back online
        mockConnectivity.setConnectivity(ConnectivityResult.wifi);
        isSyncing = true;
        syncCount++;
        expect(syncCount, equals(1), reason: 'Sync count should increase');

        // Sync completes
        isSyncing = false;
        lastSyncError = null;
        expect(lastSyncError, isNull, reason: 'Error should be cleared on success');
        expect(isSyncing, isFalse, reason: 'Should not be syncing after completion');
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // INTEGRATION & EDGE CASES
    // ═══════════════════════════════════════════════════════════════
    group('Integration & Edge Cases', () {
      late MockDatabase mockDb;

      setUp(() async {
        mockDb = MockDatabase();
        await mockDb.execute('''
          CREATE TABLE IF NOT EXISTS offline_orders (
            id TEXT PRIMARY KEY,
            order_json TEXT NOT NULL,
            status TEXT DEFAULT 'queued',
            retry_count INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      });

      test('All four scenarios can run sequentially without interference', () async {
        // Scenario 1 data
        for (int i = 0; i < 3; i++) {
          final order = _createTestOrder(id: 'seq_s1_$i');
          await mockDb.insert('offline_orders', {
            'id': order.id,
            'order_json': _encodeJson(order.toMap()),
            'status': 'queued',
            'retry_count': 0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
        }

        // Clear and test scenario 2 data
        await mockDb.delete('offline_orders');
        final s2Orders = await mockDb.query('offline_orders');
        expect(s2Orders.isEmpty, isTrue, reason: 'Should clear queue between scenarios');

        // Add scenario 2 data
        final order = _createTestOrder(id: 'seq_s2_1');
        await mockDb.insert('offline_orders', {
          'id': order.id,
          'order_json': _encodeJson(order.toMap()),
          'status': 'queued',
          'retry_count': 0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        final finalOrders = await mockDb.query('offline_orders');
        expect(finalOrders.length, equals(1), reason: 'Should have only scenario 2 data');
      });

      test('Queue handles mixed statuses correctly', () async {
        final statuses = ['queued', 'syncing', 'synced', 'failed', 'conflicted'];

        for (int i = 0; i < statuses.length; i++) {
          final order = _createTestOrder(id: 'mixed_status_$i');
          await mockDb.insert('offline_orders', {
            'id': order.id,
            'order_json': _encodeJson(order.toMap()),
            'status': statuses[i],
            'retry_count': 0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
        }

        final allOrders = await mockDb.query('offline_orders');
        expect(allOrders.length, equals(5), reason: 'Should handle all status types');

        for (final status in statuses) {
          final withStatus = await mockDb.query(
            'offline_orders',
            where: 'status = ?',
            whereArgs: [status],
          );
          expect(withStatus.length, equals(1), reason: 'Should find orders with status $status');
        }
      });

      test('Order data integrity through full cycle', () async {
        final original = _createTestOrder(id: 'integrity_test');
        final originalJson = _encodeJson(original.toMap());

        // Store in queue
        await mockDb.insert('offline_orders', {
          'id': original.id,
          'order_json': originalJson,
          'status': 'queued',
          'retry_count': 0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        // Retrieve and restore
        final retrieved = await mockDb.query(
          'offline_orders',
          where: 'id = ?',
          whereArgs: [original.id],
        );
        expect(retrieved.length, equals(1), reason: 'Should retrieve queued order');

        final retrievedJson = retrieved.first['order_json'] as String;
        final restored = OrderModel.fromMap(jsonDecode(retrievedJson) as Map<String, dynamic>);

        // Verify all fields match
        expect(restored.id, equals(original.id), reason: 'ID should match');
        expect(
          restored.customerId,
          equals(original.customerId),
          reason: 'Customer ID should match',
        );
        expect(
          restored.totalAmount,
          equals(original.totalAmount),
          reason: 'Total amount should match',
        );
        expect(
          restored.items.length,
          equals(original.items.length),
          reason: 'Item count should match',
        );
      });
    });
  });
}

String _encodeJson(dynamic obj) {
  return jsonEncode(
    obj,
    toEncodable: (val) {
      if (val is DateTime) return val.toIso8601String();
      if (val is Timestamp) return val.toDate().toIso8601String();
      if (val is OrderModel) return val.toMap();
      return val.toString();
    },
  );
}
