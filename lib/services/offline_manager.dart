import 'package:hive_flutter/hive_flutter.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';

class OfflineManager {
  static final OfflineManager _instance = OfflineManager._internal();
  factory OfflineManager() => _instance;
  OfflineManager._internal();

  static const String _productsBoxName = 'cached_products';
  static const String _ordersQueueBoxName = 'orders_queue';
  static const String _settingsBoxName = 'offline_settings';

  bool _isInitialized = false;

  /// Initialize Hive boxes for offline use
  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.initFlutter();
    
    // Open necessary boxes
    await Hive.openBox(_productsBoxName);
    await Hive.openBox(_ordersQueueBoxName);
    await Hive.openBox(_settingsBoxName);

    _isInitialized = true;
  }

  /// Cache products list locally
  Future<void> cacheProducts(List<ProductModel> products) async {
    final box = Hive.box(_productsBoxName);
    // Clear old cache to manage size
    await box.clear();

    final productMaps = {
      for (var product in products) product.id: product.toMap()
    };
    await box.putAll(productMaps);
    
    // Save last cached timestamp
    final settingsBox = Hive.box(_settingsBoxName);
    await settingsBox.put('last_cached_time', DateTime.now().toIso8601String());
  }

  /// Retrieve cached products
  List<ProductModel> getCachedProducts() {
    final box = Hive.box(_productsBoxName);
    return box.values
        .map((data) => ProductModel.fromMap(Map<String, dynamic>.from(data)))
        .toList();
  }

  /// Get last cached timestamp
  DateTime? getLastCachedTime() {
    final settingsBox = Hive.box(_settingsBoxName);
    final timeStr = settingsBox.get('last_cached_time');
    return timeStr != null ? DateTime.parse(timeStr) : null;
  }

  /// Queue an order offline when network is down
  Future<void> queueOrder(OrderModel order) async {
    final box = Hive.box(_ordersQueueBoxName);
    await box.put(order.id, order.toMap());
  }

  /// Retrieve all queued offline orders
  List<OrderModel> getQueuedOrders() {
    final box = Hive.box(_ordersQueueBoxName);
    return box.values
        .map((data) => OrderModel.fromMap(Map<String, dynamic>.from(data)))
        .toList();
  }

  /// Clear a specific queued order after sync success
  Future<void> removeQueuedOrder(String orderId) async {
    final box = Hive.box(_ordersQueueBoxName);
    await box.delete(orderId);
  }

  /// Clear the entire queued orders box
  Future<void> clearQueuedOrders() async {
    final box = Hive.box(_ordersQueueBoxName);
    await box.clear();
  }
}
