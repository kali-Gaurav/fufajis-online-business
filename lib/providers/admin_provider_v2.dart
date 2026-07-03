import 'package:flutter/foundation.dart';
import '../repositories/admin_repository.dart';
import '../services/admin_api_service.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';

/// Admin Provider (Refactored).
///
/// ARCHITECTURE:
/// Provider → Repository → ApiService → Backend API → PostgreSQL
///
/// RULES ENFORCED:
/// 1. NO direct Firestore writes
/// 2. NO direct Firestore reads for critical data (products, inventory, orders)
/// 3. Single source of truth: PostgreSQL
/// 4. Read layer: Firestore (cached from PostgreSQL via backend sync)
/// 5. All writes validated by backend before persisting
///
/// Benefits:
/// - Prevents data corruption
/// - Prevents overselling
/// - Enables proper transactions
/// - Enforces audit logging
/// - Enables consistent state across apps
class AdminProvider with ChangeNotifier {
  final AdminRepository _repository;

  AdminProvider({required AdminRepository repository}) : _repository = repository;

  // ── State ──────────────────────────────────────────────────
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _error = '';
  String get error => _error;

  // Dashboard metrics
  int _totalRevenue = 0;
  int get totalRevenue => _totalRevenue;

  int _pendingOrders = 0;
  int get pendingOrders => _pendingOrders;

  int _lowStockItems = 0;
  int get lowStockItems => _lowStockItems;

  int _activeEmployees = 0;
  int get activeEmployees => _activeEmployees;

  // Products
  List<ProductModel> _products = [];
  List<ProductModel> get products => _products;

  // Orders
  List<OrderModel> _orders = [];
  List<OrderModel> get orders => _orders;

  // Inventory
  Map<String, dynamic> _inventoryStatus = {};
  Map<String, dynamic> get inventoryStatus => _inventoryStatus;

  // ── Dashboard ──────────────────────────────────────────────
  /// Fetch dashboard KPIs from backend.
  ///
  /// Flow:
  /// 1. Call AdminRepository.fetchDashboardMetrics()
  /// 2. Repository calls AdminApiService.getDashboardMetrics()
  /// 3. ApiService calls GET /admin/dashboard/metrics
  /// 4. Backend queries PostgreSQL
  /// 5. Backend syncs to Firestore (eventually)
  /// 6. Provider stores in memory
  /// 7. UI rebuilds
  Future<void> loadDashboardMetrics() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final metrics = await _repository.fetchDashboardMetrics();

      _totalRevenue = (metrics['totalRevenue'] as num?)?.toInt() ?? 0;
      _pendingOrders = (metrics['pendingOrders'] as num?)?.toInt() ?? 0;
      _lowStockItems = (metrics['lowStockItems'] as num?)?.toInt() ?? 0;
      _activeEmployees = (metrics['activeEmployees'] as num?)?.toInt() ?? 0;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Products ───────────────────────────────────────────────
  /// Fetch products from backend.
  ///
  /// Flow:
  /// 1. Call AdminRepository.fetchProducts()
  /// 2. Repository validates params
  /// 3. Calls AdminApiService.getProducts()
  /// 4. ApiService calls GET /admin/products?page=...
  /// 5. Backend queries PostgreSQL
  /// 6. Returns paginated results
  /// 7. Provider converts to ProductModel list
  Future<void> loadProducts({int page = 1, String? searchQuery}) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final result = await _repository.fetchProducts(
        page: page,
        limit: 20,
        searchQuery: searchQuery,
      );

      // Convert API response to ProductModel list
      final List<dynamic> productsList = result['products'] ?? [];
      _products = productsList
          .map((p) => ProductModel.fromMap(p as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new product.
  ///
  /// Flow:
  /// 1. Validate input
  /// 2. Call AdminRepository.createProduct()
  /// 3. Repository validates again
  /// 4. Calls AdminApiService.createProduct()
  /// 5. Backend validates, inserts to PostgreSQL, syncs to Firestore
  /// 6. Returns created product
  /// 7. Provider adds to local list
  /// 8. UI updates
  Future<ProductModel?> createProduct({
    required String name,
    required String nameHi,
    required double price,
    required String unit,
    String? categoryId,
    String? description,
    List<String>? imageUrls,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final productData = {
        'name': name,
        'nameHi': nameHi,
        'price': price,
        'unit': unit,
        'categoryId': categoryId,
        'description': description,
        'imageUrls': imageUrls ?? [],
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
      };

      final result = await _repository.createProduct(productData);
      final createdProduct = ProductModel.fromMap(result);

      // Add to local list
      _products.add(createdProduct);

      return createdProduct;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update an existing product.
  ///
  /// Flow: Create → Backend validation → PostgreSQL update → Firestore sync
  Future<ProductModel?> updateProduct(
    String productId, {
    String? name,
    String? nameHi,
    double? price,
    String? unit,
    String? categoryId,
    String? description,
    List<String>? imageUrls,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final updates = <String, dynamic>{
        if (name != null) 'name': name,
        if (nameHi != null) 'nameHi': nameHi,
        if (price != null) 'price': price,
        if (unit != null) 'unit': unit,
        if (categoryId != null) 'categoryId': categoryId,
        if (description != null) 'description': description,
        if (imageUrls != null) 'imageUrls': imageUrls,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final result = await _repository.updateProduct(productId, updates);
      final updatedProduct = ProductModel.fromMap(result);

      // Update local list
      final index = _products.indexWhere((p) => p.id == productId);
      if (index >= 0) {
        _products[index] = updatedProduct;
      }

      return updatedProduct;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a product.
  Future<bool> deleteProduct(String productId) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      await _repository.deleteProduct(productId);

      // Remove from local list
      _products.removeWhere((p) => p.id == productId);

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Inventory ──────────────────────────────────────────────
  /// Load inventory status.
  Future<void> loadInventory() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      _inventoryStatus = await _repository.fetchInventory();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adjust inventory stock.
  ///
  /// CRITICAL: This must be atomic to prevent overselling.
  /// Backend handles PostgreSQL transaction locking.
  Future<bool> adjustInventory({
    required String productId,
    required int quantity,
    required String reason,
    String? employeeId,
    String? orderId,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      await _repository.adjustInventory(
        productId: productId,
        quantity: quantity,
        reason: reason,
        employeeId: employeeId,
        orderId: orderId,
      );

      // Refresh inventory after adjustment
      await loadInventory();

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Orders ─────────────────────────────────────────────────
  /// Load active orders.
  Future<void> loadOrders({String? status}) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final result = await _repository.fetchOrders(status: status);

      final List<dynamic> ordersList = result['orders'] ?? [];
      _orders = ordersList
          .map((o) => OrderModel.fromMap(o as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pack an order.
  ///
  /// CRITICAL: Backend must handle this atomically:
  /// 1. BEGIN TRANSACTION
  /// 2. Lock product rows in inventory table
  /// 3. Validate stock for all items
  /// 4. Reduce inventory
  /// 5. Create inventory_transactions
  /// 6. Update order status
  /// 7. Create audit log
  /// 8. Sync to Firestore
  /// 9. COMMIT
  /// 10. UNLOCK
  ///
  /// If ANY step fails, entire transaction rolls back.
  /// This prevents overselling.
  Future<bool> packOrder(
    String orderId, {
    required List<Map<String, dynamic>> items,
    String? employeeId,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      await _repository.packOrder(
        orderId,
        items: items,
        employeeId: employeeId,
      );

      // Refresh orders after pack
      await loadOrders(status: 'pending');

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Error handling ─────────────────────────────────────────
  /// Clear error message.
  void clearError() {
    _error = '';
    notifyListeners();
  }
}
