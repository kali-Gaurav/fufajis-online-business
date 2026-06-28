import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import 'sqlite_service.dart';
import 'offline_order_queue_service.dart';

/// Offline Manager — Fufaji Relational Offline Storage (SQLite)
/// Replaces all Hive key-value operations with structured SQLite queries.
class OfflineManager {
  static final OfflineManager _instance = OfflineManager._internal();
  factory OfflineManager() => _instance;
  OfflineManager._internal();

  final SqliteService _sqlite = SqliteService();
  bool _isInitialized = false;

  /// Initialize the SQLite database (idempotent)
  Future<void> initialize() async {
    if (_isInitialized) return;
    // Accessing the database getter triggers _initDatabase()
    await _sqlite.database;
    _isInitialized = true;
    debugPrint('[OfflineManager] SQLite initialized.');
  }

  // ─────────────── PRODUCTS ───────────────

  /// Cache a list of products from Firestore
  Future<void> cacheProducts(List<ProductModel> products) async {
    final maps = products.map((p) => p.toMap()).toList();
    await _sqlite.cacheProducts(maps);
    debugPrint('[OfflineManager] Cached ${products.length} products.');
  }

  /// Retrieve all cached products from SQLite
  Future<List<ProductModel>> getCachedProducts() async {
    final maps = await _sqlite.getCachedProducts();
    return maps.map((m) => ProductModel.fromMap(m)).toList();
  }

  /// Clear cached product data (e.g. on logout)
  Future<void> clearProductCache() async {
    await _sqlite.clearProductCache();
  }

  // ─────────────── ORDERS (Offline Queue) ───────────────

  /// Queue an order for sync when network becomes available
  Future<void> queueOrder(OrderModel order) async {
    await OfflineOrderQueueService().addOrderToQueue(order);
    debugPrint('[OfflineManager] Queued order: ${order.id} via OfflineOrderQueueService');
  }

  /// Retrieve all orders that have not yet been synced
  Future<List<OrderModel>> getQueuedOrders() async {
    return await OfflineOrderQueueService().getQueuedOrders();
  }

  /// Mark a specific order as synced
  Future<void> removeQueuedOrder(String orderId) async {
    await OfflineOrderQueueService().removeFromQueue(orderId);
  }

  /// Remove all unsynced orders from the queue
  Future<void> clearQueuedOrders() async {
    await OfflineOrderQueueService().clearQueue();
  }

  // ─────────────── CART ───────────────

  Future<void> saveCartItem(Map<String, dynamic> item) =>
      _sqlite.saveCartItem(item);
  Future<List<Map<String, dynamic>>> getCartItems() => _sqlite.getCartItems();
  Future<void> updateCartItemQuantity(String itemId, int qty) =>
      _sqlite.updateCartItemQuantity(itemId, qty);
  Future<void> removeCartItem(String itemId) => _sqlite.removeCartItem(itemId);
  Future<void> clearCart() => _sqlite.clearCart();

  // ─────────────── INVENTORY ───────────────

  Future<void> saveInventoryAction(Map<String, dynamic> action) =>
      _sqlite.saveInventoryAction(action);

  Future<List<Map<String, dynamic>>> getUnsyncedInventoryActions() =>
      _sqlite.getUnsyncedInventoryActions();

  Future<void> markInventoryActionSynced(String actionId) =>
      _sqlite.markInventoryActionSynced(actionId);

  // ─────────────── PENDING SYNC QUEUE ───────────────

  Future<void> enqueuePendingSync({
    required String id,
    required String actionType,
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) => _sqlite.enqueuePendingSync(
    id: id,
    actionType: actionType,
    collection: collection,
    documentId: documentId,
    data: data,
  );

  Future<List<Map<String, dynamic>>> getPendingSyncItems() =>
      _sqlite.getPendingSyncItems();

  Future<void> markSyncDone(String syncId) => _sqlite.markSyncDone(syncId);
  Future<void> markSyncFailed(String syncId) => _sqlite.markSyncFailed(syncId);
  Future<int> getPendingSyncCount() => _sqlite.getPendingSyncCount();

  // ─────────────── AUDIT LOGS ───────────────

  Future<void> writeAuditLog({
    required String id,
    required String action,
    required String entityType,
    String? entityId,
    String? userId,
    String? details,
  }) => _sqlite.writeAuditLog(
    id: id,
    action: action,
    entityType: entityType,
    entityId: entityId,
    userId: userId,
    details: details,
  );

  // ─────────────── UTILITY ───────────────

  Future<void> clearAllData() => _sqlite.clearAllData();
}
