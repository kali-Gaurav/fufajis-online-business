import '../services/admin_api_service.dart';

/// Repository layer for admin operations.
///
/// Single source of truth for admin data.
/// Handles caching, error handling, and state management.
///
/// RULE: Never write directly to Firestore from here.
/// All writes go through AdminApiService → Backend API → PostgreSQL
class AdminRepository {
  final AdminApiService _apiService;

  AdminRepository({required AdminApiService apiService}) : _apiService = apiService;

  /// Fetch dashboard metrics (KPIs).
  ///
  /// Calls: GET /admin/dashboard/metrics
  /// Returns: {totalRevenue, pendingOrders, lowStockItems, activeEmployees, ...}
  Future<Map<String, dynamic>> fetchDashboardMetrics() async {
    try {
      return await _apiService.getDashboardMetrics();
    } catch (e) {
      throw AdminRepositoryException('Failed to fetch dashboard metrics: $e');
    }
  }

  /// Fetch all products with pagination.
  ///
  /// Calls: GET /admin/products?page=X&limit=Y
  Future<Map<String, dynamic>> fetchProducts({
    int page = 1,
    int limit = 20,
    String? searchQuery,
    String? categoryId,
  }) async {
    try {
      return await _apiService.getProducts(
        page: page,
        limit: limit,
        searchQuery: searchQuery,
        categoryId: categoryId,
      );
    } catch (e) {
      throw AdminRepositoryException('Failed to fetch products: $e');
    }
  }

  /// Create a new product.
  ///
  /// Calls: POST /admin/products
  /// Backend will:
  ///   1. Validate product data
  ///   2. Insert into PostgreSQL
  ///   3. Sync to Firestore
  ///   4. Return created product
  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> productData) async {
    try {
      // Validation
      if (!productData.containsKey('name') || productData['name'].toString().isEmpty) {
        throw AdminRepositoryException('Product name is required');
      }
      if (!productData.containsKey('price') || productData['price'] <= 0) {
        throw AdminRepositoryException('Product price must be > 0');
      }

      return await _apiService.createProduct(productData);
    } catch (e) {
      throw AdminRepositoryException('Failed to create product: $e');
    }
  }

  /// Update an existing product.
  ///
  /// Calls: PUT /admin/products/:id
  /// Backend will:
  ///   1. Validate product data
  ///   2. Update PostgreSQL
  ///   3. Sync to Firestore
  ///   4. Audit log the change
  ///   5. Return updated product
  Future<Map<String, dynamic>> updateProduct(
    String productId,
    Map<String, dynamic> updates,
  ) async {
    try {
      if (productId.isEmpty) {
        throw AdminRepositoryException('Product ID is required');
      }
      if (updates.isEmpty) {
        throw AdminRepositoryException('No updates provided');
      }

      return await _apiService.updateProduct(productId, updates);
    } catch (e) {
      throw AdminRepositoryException('Failed to update product: $e');
    }
  }

  /// Delete a product.
  ///
  /// Calls: DELETE /admin/products/:id
  /// Backend will:
  ///   1. Check if product can be deleted
  ///   2. Delete from PostgreSQL
  ///   3. Delete from Firestore
  ///   4. Audit log the deletion
  Future<void> deleteProduct(String productId) async {
    try {
      if (productId.isEmpty) {
        throw AdminRepositoryException('Product ID is required');
      }

      await _apiService.deleteProduct(productId);
    } catch (e) {
      throw AdminRepositoryException('Failed to delete product: $e');
    }
  }

  /// Fetch inventory status.
  ///
  /// Calls: GET /admin/inventory
  /// Returns: {products with stock levels, low stock alerts, reorder suggestions}
  Future<Map<String, dynamic>> fetchInventory({
    int page = 1,
    int limit = 20,
    String? status, // 'all', 'low', 'out'
  }) async {
    try {
      return await _apiService.getInventory(page: page, limit: limit, status: status);
    } catch (e) {
      throw AdminRepositoryException('Failed to fetch inventory: $e');
    }
  }

  /// Adjust inventory stock.
  ///
  /// Calls: POST /admin/inventory/adjust
  /// Backend will:
  ///   1. Acquire PostgreSQL write lock
  ///   2. Validate available stock
  ///   3. Update inventory
  ///   4. Create transaction record
  ///   5. Sync to Firestore
  ///   6. Release lock
  Future<Map<String, dynamic>> adjustInventory({
    required String productId,
    required int quantity, // positive = add, negative = reduce
    required String reason, // 'sale', 'damage', 'restock', 'adjustment'
    String? employeeId,
    String? orderId,
  }) async {
    try {
      if (productId.isEmpty) {
        throw AdminRepositoryException('Product ID is required');
      }
      if (reason.isEmpty) {
        throw AdminRepositoryException('Adjustment reason is required');
      }

      return await _apiService.adjustInventory(
        productId: productId,
        quantity: quantity,
        reason: reason,
        employeeId: employeeId,
        orderId: orderId,
      );
    } catch (e) {
      throw AdminRepositoryException('Failed to adjust inventory: $e');
    }
  }

  /// Fetch active orders.
  ///
  /// Calls: GET /admin/orders
  /// Returns: {orders, paging, filters}
  Future<Map<String, dynamic>> fetchOrders({
    int page = 1,
    int limit = 20,
    String? status, // 'pending', 'confirmed', 'packed', 'out_for_delivery', 'delivered'
  }) async {
    try {
      return await _apiService.getOrders(page: page, limit: limit, status: status);
    } catch (e) {
      throw AdminRepositoryException('Failed to fetch orders: $e');
    }
  }

  /// Pack an order (reduce inventory atomically).
  ///
  /// Calls: POST /admin/orders/:id/pack
  /// Backend will:
  ///   1. Begin PostgreSQL transaction
  ///   2. Check stock availability with locks
  ///   3. Reduce inventory for each item
  ///   4. Create inventory_transactions
  ///   5. Update order status
  ///   6. Create audit log
  ///   7. Sync order + inventory to Firestore
  ///   8. Commit transaction
  ///   9. Return updated order
  ///
  /// CRITICAL: This must be atomic to prevent overselling.
  Future<Map<String, dynamic>> packOrder(
    String orderId, {
    required List<Map<String, dynamic>> items, // [{productId, qty}, ...]
    String? employeeId,
  }) async {
    try {
      if (orderId.isEmpty) {
        throw AdminRepositoryException('Order ID is required');
      }
      if (items.isEmpty) {
        throw AdminRepositoryException('No items to pack');
      }

      return await _apiService.packOrder(orderId, items, employeeId);
    } catch (e) {
      throw AdminRepositoryException('Failed to pack order: $e');
    }
  }

  /// Fetch analytics/reports.
  ///
  /// Calls: GET /admin/reports/analytics
  /// Returns: {sales trends, top products, customer segments, revenue}
  Future<Map<String, dynamic>> fetchAnalytics({
    required String timeRange, // 'day', 'week', 'month', 'year'
    String? metric, // 'revenue', 'orders', 'customers'
  }) async {
    try {
      return await _apiService.getAnalytics(timeRange: timeRange, metric: metric);
    } catch (e) {
      throw AdminRepositoryException('Failed to fetch analytics: $e');
    }
  }

  /// Fetch audit logs (who changed what, when).
  ///
  /// Calls: GET /admin/audit-logs
  /// Returns: {logs paginated}
  Future<Map<String, dynamic>> fetchAuditLogs({
    int page = 1,
    int limit = 50,
    String? entityType, // 'product', 'order', 'inventory'
    String? action, // 'create', 'update', 'delete'
  }) async {
    try {
      return await _apiService.getAuditLogs(
        page: page,
        limit: limit,
        entityType: entityType,
        action: action,
      );
    } catch (e) {
      throw AdminRepositoryException('Failed to fetch audit logs: $e');
    }
  }
}

/// Exception thrown by AdminRepository.
class AdminRepositoryException implements Exception {
  final String message;
  AdminRepositoryException(this.message);

  @override
  String toString() => 'AdminRepositoryException: $message';
}
