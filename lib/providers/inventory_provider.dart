import 'package:flutter/foundation.dart';
import 'package:fufaji/models/inventory_models.dart';
import 'package:fufaji/services/inventory_service.dart';
import 'dart:developer' as developer;

/// Inventory state management provider
class InventoryProvider extends ChangeNotifier {
  final InventoryService _inventoryService = InventoryService();

  // State variables
  InventoryMetrics? _metrics;
  List<StockLevel> _stockLevels = [];
  List<ReorderSuggestion> _reorderSuggestions = [];
  List<ExpiryAlert> _expiryAlerts = [];
  List<Supplier> _suppliers = [];
  List<PurchaseOrder> _purchaseOrders = [];
  List<StockMovement> _movements = [];

  bool _isLoading = false;
  String? _error;
  DateTime _lastUpdated = DateTime.now();

  // Stream subscriptions
  final List<Stream<dynamic>> _activeStreams = [];

  // Getters
  InventoryMetrics? get metrics => _metrics;
  List<StockLevel> get stockLevels => _stockLevels;
  List<ReorderSuggestion> get reorderSuggestions => _reorderSuggestions;
  List<ExpiryAlert> get expiryAlerts => _expiryAlerts;
  List<Supplier> get suppliers => _suppliers;
  List<PurchaseOrder> get purchaseOrders => _purchaseOrders;
  List<StockMovement> get movements => _movements;

  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get lastUpdated => _lastUpdated;

  // Computed properties
  int get lowStockCount => stockLevels.where((s) => s.isLowStock).length;
  int get outOfStockCount => stockLevels.where((s) => s.isOutOfStock).length;
  int get expiringCount => expiryAlerts.where((a) => a.daysUntilExpiry < 7).length;

  // Initialize provider
  Future<void> init() async {
    developer.log('Initializing InventoryProvider');
    await loadDashboardData();
  }

  // Load all dashboard data in parallel
  Future<void> loadDashboardData() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      developer.log('Loading inventory dashboard data');

      await Future.wait([
        _loadMetrics(),
        _loadReorderSuggestions(),
        _loadExpiryAlerts(),
        _loadSuppliers(),
        _loadPurchaseOrders(),
      ]);

      _lastUpdated = DateTime.now();
      developer.log('Successfully loaded all inventory data');
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      developer.log('Error loading inventory data: $e', error: e);
      notifyListeners();
      rethrow;
    }
  }

  // Load metrics
  Future<void> _loadMetrics() async {
    try {
      developer.log('Loading inventory metrics');
      final metrics = await _inventoryService.getInventoryMetrics();
      _metrics = metrics;
    } catch (e) {
      developer.log('Error loading metrics: $e', error: e);
    }
  }

  // Load reorder suggestions
  Future<void> _loadReorderSuggestions() async {
    try {
      developer.log('Loading reorder suggestions');
      _reorderSuggestions = await _inventoryService.getReorderSuggestions();
    } catch (e) {
      developer.log('Error loading reorder suggestions: $e', error: e);
    }
  }

  // Load expiry alerts
  Future<void> _loadExpiryAlerts() async {
    try {
      developer.log('Loading expiry alerts');
      _expiryAlerts = await _inventoryService.getExpiryAlerts();
    } catch (e) {
      developer.log('Error loading expiry alerts: $e', error: e);
    }
  }

  // Load suppliers
  Future<void> _loadSuppliers() async {
    try {
      developer.log('Loading suppliers');
      _suppliers = await _inventoryService.getSuppliers();
    } catch (e) {
      developer.log('Error loading suppliers: $e', error: e);
    }
  }

  // Load purchase orders
  Future<void> _loadPurchaseOrders() async {
    try {
      developer.log('Loading purchase orders');
      _purchaseOrders = await _inventoryService.getPurchaseOrders();
    } catch (e) {
      developer.log('Error loading purchase orders: $e', error: e);
    }
  }

  // Get stock level for a product
  Future<StockLevel?> getStockLevel(String productId) async {
    try {
      developer.log('Fetching stock level for product: $productId');
      return await _inventoryService.getStockLevel(productId);
    } catch (e) {
      developer.log('Error fetching stock level: $e', error: e);
      rethrow;
    }
  }

  // Get low stock items
  Future<List<StockLevel>> getLowStockItems() async {
    try {
      developer.log('Fetching low stock items');
      return await _inventoryService.getLowStockItems();
    } catch (e) {
      developer.log('Error fetching low stock items: $e', error: e);
      rethrow;
    }
  }

  // Get movement history for a product
  Future<List<StockMovement>> getMovementHistory(String productId) async {
    try {
      developer.log('Fetching movement history for product: $productId');
      _movements = await _inventoryService.getMovementHistory(productId);
      notifyListeners();
      return _movements;
    } catch (e) {
      developer.log('Error fetching movement history: $e', error: e);
      rethrow;
    }
  }

  // Reserve stock for an order
  Future<bool> reserveStock(String productId, int quantity) async {
    try {
      developer.log('Reserving $quantity units of product $productId');
      final success = await _inventoryService.reserveStock(productId, quantity);

      if (success) {
        await _loadMetrics(); // Refresh metrics
        notifyListeners();
      }

      return success;
    } catch (e) {
      developer.log('Error reserving stock: $e', error: e);
      rethrow;
    }
  }

  // Release stock reservation
  Future<void> releaseReservation(String productId, int quantity) async {
    try {
      developer.log('Releasing $quantity units of product $productId');
      await _inventoryService.releaseReservation(productId, quantity);

      await _loadMetrics(); // Refresh metrics
      notifyListeners();
    } catch (e) {
      developer.log('Error releasing reservation: $e', error: e);
      rethrow;
    }
  }

  // Confirm stock sale
  Future<void> confirmStockSale(String productId, int quantity) async {
    try {
      developer.log('Confirming sale of $quantity units of product $productId');
      await _inventoryService.confirmStockSale(productId, quantity);

      await _loadMetrics(); // Refresh metrics
      notifyListeners();
    } catch (e) {
      developer.log('Error confirming stock sale: $e', error: e);
      rethrow;
    }
  }

  // Stream real-time metrics
  Stream<InventoryMetrics?> watchMetrics() {
    developer.log('Starting metrics stream');
    return _inventoryService.streamInventoryMetrics().handleError((e) {
      developer.log('Error in metrics stream: $e', error: e);
    });
  }

  // Stream real-time reorder suggestions
  Stream<List<ReorderSuggestion>> watchReorderSuggestions() {
    developer.log('Starting reorder suggestions stream');
    return _inventoryService.streamReorderSuggestions().handleError((e) {
      developer.log('Error in reorder suggestions stream: $e', error: e);
    });
  }

  // Stream real-time expiry alerts
  Stream<List<ExpiryAlert>> watchExpiryAlerts() {
    developer.log('Starting expiry alerts stream');
    return _inventoryService.streamExpiryAlerts().handleError((e) {
      developer.log('Error in expiry alerts stream: $e', error: e);
    });
  }

  // Stream real-time stock levels for a product
  Stream<StockLevel?> watchStockLevel(String productId) {
    developer.log('Starting stock level stream for product: $productId');
    return _inventoryService.streamStockLevel(productId).handleError((e) {
      developer.log('Error in stock level stream: $e', error: e);
    });
  }

  // Filter reorder suggestions by status
  List<ReorderSuggestion> getFilteredReorders({required bool needsReorder}) {
    return _reorderSuggestions.where((r) => r.needsReorder == needsReorder).toList();
  }

  // Filter expiry alerts by urgency
  List<ExpiryAlert> getFilteredExpiry({required String urgency}) {
    return _expiryAlerts.where((a) => a.urgencyLabel == urgency).toList();
  }

  // Filter purchase orders by status
  List<PurchaseOrder> getFilteredPOs({required String status}) {
    return _purchaseOrders.where((po) => po.status == status).toList();
  }

  // Refresh all data
  Future<void> refresh() async {
    developer.log('Refreshing inventory data');
    _inventoryService.clearAllCaches();
    await loadDashboardData();
  }

  // Refresh specific data section
  Future<void> refreshMetrics() async {
    developer.log('Refreshing metrics');
    await _loadMetrics();
    notifyListeners();
  }

  Future<void> refreshReorders() async {
    developer.log('Refreshing reorder suggestions');
    await _loadReorderSuggestions();
    notifyListeners();
  }

  Future<void> refreshExpiry() async {
    developer.log('Refreshing expiry alerts');
    await _loadExpiryAlerts();
    notifyListeners();
  }

  Future<void> refreshPOs() async {
    developer.log('Refreshing purchase orders');
    await _loadPurchaseOrders();
    notifyListeners();
  }

  // Cleanup
  @override
  void dispose() {
    developer.log('Disposing InventoryProvider');
    _inventoryService.clearAllCaches();
    _activeStreams.clear();
    super.dispose();
  }
}
