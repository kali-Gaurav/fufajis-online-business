import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/dashboard_metrics.dart';
import '../models/alert_model.dart';
import '../models/employee_performance_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../services/alert_service.dart';
import '../services/product_service.dart';
import '../constants/order_status.dart';

/// Provider for owner analytics and dashboard state management
/// Extends ChangeNotifier to notify listeners of state changes
class OwnerAnalyticsProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProductService _productService = ProductService();
  final AlertService _alertService = AlertService();

  // Dashboard state
  DashboardMetrics? _metrics;
  final List<OrderModel> _orders = [];
  List<AlertModel> _alerts = [];
  List<EmployeePerformanceModel> _employees = [];
  List<RevenueDataPoint> _revenueTrend = [];
  List<OrderDataPoint> _ordersTrend = [];

  // UI state
  final String _selectedPeriod = 'today';
  final Map<String, dynamic> _filters = {
    'status': 'all',
    'dateRangeStart': null,
    'dateRangeEnd': null,
  };
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedBranchId; // Added for Multi-Branch Analytics
  String? _selectedCity;
  String? _selectedState;
  String? _selectedFranchiseId;
  String _currentView = 'Global View'; // 'Global View', 'Regional View', 'Branch View'

  // Real-time listeners
  StreamSubscription<List<AlertModel>>? _alertListener;

  DashboardMetrics? get metrics => _metrics;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<AlertModel> get alerts => _alerts;
  List<OrderModel> get orders => _orders;
  List<EmployeePerformanceModel> get employees => _employees;
  List<RevenueDataPoint> get revenueTrend => _revenueTrend;
  List<OrderDataPoint> get ordersTrend => _ordersTrend;
  String get selectedPeriod => _selectedPeriod;
  Map<String, dynamic> get filters => _filters;
  String? get selectedBranchId => _selectedBranchId;
  String? get selectedCity => _selectedCity;
  String? get selectedState => _selectedState;
  String? get selectedFranchiseId => _selectedFranchiseId;
  String get currentView => _currentView;

  // Set selected branch and reload
  void setSelectedBranch(String? branchId) {
    _selectedBranchId = branchId;
    _currentView = branchId != null ? 'Branch View' : 'Global View';
    _selectedCity = null;
    _selectedState = null;
    loadMetrics(
      DateTime.now().subtract(const Duration(days: 30)),
      DateTime.now(),
    );
  }

  void setRegionalFilters(String? state, String? city) {
    _selectedState = state;
    _selectedCity = city;
    _selectedBranchId = null;
    _currentView = 'Regional View';
    loadMetrics(
      DateTime.now().subtract(const Duration(days: 30)),
      DateTime.now(),
    );
  }

  void setGlobalView() {
    _selectedBranchId = null;
    _selectedState = null;
    _selectedCity = null;
    _selectedFranchiseId = null;
    _currentView = 'Global View';
    loadMetrics(
      DateTime.now().subtract(const Duration(days: 30)),
      DateTime.now(),
    );
  }

  // Getters for filtered data
  List<AlertModel> get criticalAlerts =>
      _alerts.where((a) => a.severity == AlertSeverity.critical).toList();

  List<AlertModel> get warningAlerts =>
      _alerts.where((a) => a.severity == AlertSeverity.warning).toList();

  int get pendingOrdersCount =>
      _orders.where((o) => o.status == OrderStatus.pending).length;

  int get activeDeliveriesCount =>
      _orders.where((o) => o.status == OrderStatus.outForDelivery).length;

  /// Initialize the provider
  Future<void> initialize() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Load initial data
      await loadMetrics(DateTime.now().subtract(const Duration(days: 1)), DateTime.now());
      await loadAlerts();
      await loadEmployees();

      // Start listening to alerts in real-time
      _startAlertListener();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to initialize: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load employees performance data
  Future<void> loadEmployees() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final snapshot = await _firestore
          .collection('shops')
          .doc(userId)
          .collection('employee_performance')
          .get();

      _employees = snapshot.docs
          .map((doc) => EmployeePerformanceModel.fromJson(doc.data()))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading employees: $e');
    }
  }

  /// Start listening to alerts in real-time
  void _startAlertListener() {
    _alertListener?.cancel();
    _alertListener = _alertService.listenToActiveAlerts().listen((newAlerts) {
      _alerts = newAlerts;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _alertListener?.cancel();
    super.dispose();
  }

  /// Load metrics for specified date range
  Future<void> loadMetrics(DateTime from, DateTime to) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Fetch orders for the date range
      final orders = await _fetchOrders(userId, from, to);

      // Fetch products
      final products = await _productService.getProductsByShopId(userId);

      // Calculate metrics
      _metrics = _calculateMetrics(orders, products, from, to);
      await loadAlerts();

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch orders from Firestore for given date range
  Future<List<OrderModel>> _fetchOrders(
    String shopId,
    DateTime from,
    DateTime to,
  ) async {
    try {
      var query = _firestore
          .collection('orders')
          .where('shopId', isEqualTo: shopId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to));

      if (_currentView == 'Branch View' && _selectedBranchId != null) {
        query = query.where('branchId', isEqualTo: _selectedBranchId);
      }

      final snapshot = await query.get();
      var mappedOrders = snapshot.docs.map((doc) {
        final data = doc.data();
        if (!data.containsKey('id')) data['id'] = doc.id;
        return OrderModel.fromMap(data);
      }).toList();

      // For Regional View, since OrderModel lacks city/state directly,
      // in a full implementation we'd first fetch branches in that city/state 
      // and filter orders by those branchIds.
      // (This assumes we fetch branch list and then `whereIn` or post-filter).
      if (_currentView == 'Regional View') {
        // Mock filtering logic - to be replaced with actual branch metadata joining
        // For now, if Regional View is enabled, we just return the global orders or
        // we could implement a memory filter if we load all branches.
      }

      return mappedOrders;
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      return [];
    }
  }

  /// Calculate comprehensive metrics from orders and products
  DashboardMetrics _calculateMetrics(
    List<OrderModel> orders,
    List<ProductModel> products,
    DateTime from,
    DateTime to,
  ) {
    final productMap = {for (var p in products) p.id: p};

    // Revenue calculations
    double totalRevenue = 0;
    Map<String, double> revenueByPaymentMethod = {};
    Map<String, double> revenueByCategory = {};

    // Order status counts
    int pending = 0, packing = 0, shipped = 0, delivered = 0, cancelled = 0, returned = 0;
    double totalOrderValue = 0;

    // Customer tracking
    Set<String> uniqueCustomers = {};
    Set<String> newCustomers = {};
    Map<String, int> customerOrderCount = {};

    // Process each order
    for (final order in orders) {
      totalRevenue += order.totalAmount.toDouble();
      totalOrderValue += order.totalAmount.toDouble();

      // Count by status
      switch (order.status) {
        case OrderStatus.pending:
          pending++;
          break;
        case OrderStatus.processing:
          packing++;
          break;
        case OrderStatus.packed:
          packing++;
          break;
        case OrderStatus.outForDelivery:
          shipped++;
          break;
        case OrderStatus.delivered:
          delivered++;
          break;
        case OrderStatus.cancelled:
          cancelled++;
          break;
        case OrderStatus.returned:
          returned++;
          break;
        default:
          break;
      }

      // Revenue by payment method
      final paymentMethodStr = order.paymentMethod.name;
      revenueByPaymentMethod[paymentMethodStr] =
          (revenueByPaymentMethod[paymentMethodStr] ?? 0.0) + order.totalAmount.toDouble();

      // Customer metrics
      uniqueCustomers.add(order.customerId);
      customerOrderCount[order.customerId] =
          (customerOrderCount[order.customerId] ?? 0) + 1;

      // Revenue by category (from items)
      for (final item in order.items) {
        final product = productMap[item.productId];
        final category = product?.categoryId ?? 'Uncategorized';
        final itemTotal = (item.price * item.quantity).toDouble();
        revenueByCategory[category] =
            (revenueByCategory[category] ?? 0.0) + itemTotal;
      }
    }

    // Customer metrics calculation
    int repeatCustomers = customerOrderCount.values.where((count) => count > 1).length;
    double repeatPurchaseRate =
        uniqueCustomers.isEmpty ? 0 : (repeatCustomers / uniqueCustomers.length) * 100;

    // Top sellers and low performers
    final topSellers = _getTopSellers(orders, 5);
    final lowPerformers = _getLowPerformers(orders, 5);

    // Out of stock count
    int outOfStock = products.where((p) => p.stockQuantity <= 0).length;

    // Delivery metrics (simplified - would need delivery data)
    double onTimeRate = delivered > 0 ? (delivered / (delivered + shipped) * 100) : 0;

    // Profit calculations
    double totalCost = totalRevenue * 0.68; // Assuming 32% margin (adjustable)
    double grossProfit = totalRevenue - totalCost;
    double profitMargin = totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0;

    return DashboardMetrics(
      dateFrom: from,
      dateTo: to,
      totalRevenue: totalRevenue,
      revenueGrowth: 12.0, // Calculate from previous period
      revenueByPaymentMethod: revenueByPaymentMethod,
      revenueByCategory: revenueByCategory,
      totalOrders: orders.length,
      pendingOrders: pending,
      packingOrders: packing,
      shippedOrders: shipped,
      deliveredOrders: delivered,
      cancelledOrders: cancelled,
      returnedOrders: returned,
      orderGrowth: 5.0, // Calculate from previous period
      avgOrderValue: orders.isEmpty ? 0 : totalOrderValue / orders.length,
      totalCustomers: uniqueCustomers.length,
      newCustomers: newCustomers.length,
      repeatCustomers: repeatCustomers,
      repeatPurchaseRate: repeatPurchaseRate,
      avgCustomerLTV: uniqueCustomers.isEmpty ? 0 : totalRevenue / uniqueCustomers.length,
      topSellers: topSellers,
      lowPerformers: lowPerformers,
      outOfStockCount: outOfStock,
      avgProductRating: _calculateAvgRating(orders, productMap),
      onTimeDeliveryRate: onTimeRate,
      failedDeliveryRate: 0.0, // Would need delivery data
      avgDeliveryTime: 0.0, // Would need delivery data
      topDeliveryAgents: [],
      topPerformers: [],
      avgPackingQuality: 95.0, // Would need quality data
      grossProfit: grossProfit,
      profitMargin: profitMargin,
      costBreakdown: {
        'COGS': totalCost * 0.6,
        'Delivery': totalCost * 0.2,
        'Operations': totalCost * 0.2,
      },
    );
  }

  /// Get top selling products from orders
  List<ProductMetric> _getTopSellers(List<OrderModel> orders, int limit) {
    Map<String, ProductMetric> productMetrics = {};

    for (final order in orders) {
      for (final item in order.items) {
        final key = item.productId;
        if (productMetrics.containsKey(key)) {
          final existing = productMetrics[key]!;
          productMetrics[key] = ProductMetric(
            productId: existing.productId,
            productName: existing.productName,
            unitsSold: existing.unitsSold + item.quantity,
            revenue: existing.revenue + (item.price * item.quantity).toDouble(),
            rating: existing.rating,
          );
        } else {
          productMetrics[key] = ProductMetric(
            productId: item.productId,
            productName: item.productName,
            unitsSold: item.quantity,
            revenue: (item.price * item.quantity).toDouble(),
            rating: 4.5, // Default rating
          );
        }
      }
    }

    final sorted = productMetrics.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    return sorted.take(limit).toList();
  }

  /// Get low performing products
  List<ProductMetric> _getLowPerformers(List<OrderModel> orders, int limit) {
    final allProducts = _getTopSellers(orders, 999);
    return allProducts.reversed.take(limit).toList();
  }

  /// Calculate average product rating
  double _calculateAvgRating(List<OrderModel> orders, Map<String, ProductModel> productMap) {
    if (orders.isEmpty) return 0;
    double totalRating = 0;
    int count = 0;

    for (final order in orders) {
      for (final item in order.items) {
        final product = productMap[item.productId];
        totalRating += product?.rating ?? 4.0;
        count++;
      }
    }

    return count > 0 ? totalRating / count : 0;
  }

  /// Get revenue trend data
  Future<List<RevenueDataPoint>> getRevenueTrend(String period) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      DateTime from;
      DateTime to = DateTime.now();

      switch (period) {
        case 'today':
          from = DateTime(to.year, to.month, to.day);
          break;
        case 'week':
          from = to.subtract(const Duration(days: 7));
          break;
        case 'month':
          from = DateTime(to.year, to.month - 1, to.day);
          break;
        case 'year':
          from = DateTime(to.year - 1, to.month, to.day);
          break;
        default:
          from = to.subtract(const Duration(days: 30));
      }

      final orders = await _fetchOrders(userId, from, to);
      _revenueTrend = _calculateRevenueTrend(orders, from, to, period);
      notifyListeners();
      return _revenueTrend;
    } catch (e) {
      debugPrint('Error fetching revenue trend: $e');
      return [];
    }
  }

  /// Calculate revenue trend data points
  List<RevenueDataPoint> _calculateRevenueTrend(
    List<OrderModel> orders,
    DateTime from,
    DateTime to,
    String period,
  ) {
    Map<String, double> dailyRevenue = {};

    for (final order in orders) {
      final dateKey = order.createdAt.toString().split(' ')[0];
      dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0.0) + order.totalAmount.toDouble();
    }

    return dailyRevenue.entries
        .map((e) => RevenueDataPoint(date: e.key, revenue: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Get orders trend data
  Future<List<OrderDataPoint>> getOrdersTrend(String period) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      DateTime from;
      DateTime to = DateTime.now();

      switch (period) {
        case 'today':
          from = DateTime(to.year, to.month, to.day);
          break;
        case 'week':
          from = to.subtract(const Duration(days: 7));
          break;
        case 'month':
          from = DateTime(to.year, to.month - 1, to.day);
          break;
        case 'year':
          from = DateTime(to.year - 1, to.month, to.day);
          break;
        default:
          from = to.subtract(const Duration(days: 30));
      }

      final orders = await _fetchOrders(userId, from, to);
      _ordersTrend = _calculateOrdersTrend(orders, from, to, period);
      notifyListeners();
      return _ordersTrend;
    } catch (e) {
      debugPrint('Error fetching orders trend: $e');
      return [];
    }
  }

  /// Calculate orders trend data points
  List<OrderDataPoint> _calculateOrdersTrend(
    List<OrderModel> orders,
    DateTime from,
    DateTime to,
    String period,
  ) {
    Map<String, int> dailyOrders = {};

    for (final order in orders) {
      final dateKey = order.createdAt.toString().split(' ')[0];
      dailyOrders[dateKey] = (dailyOrders[dateKey] ?? 0) + 1;
    }

    return dailyOrders.entries
        .map((e) => OrderDataPoint(date: e.key, count: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Get top products
  Future<List<ProductMetric>> getTopProducts(int limit) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final now = DateTime.now();
      final from = DateTime(now.year, now.month - 1, now.day);
      final orders = await _fetchOrders(userId, from, now);

      return _getTopSellers(orders, limit);
    } catch (e) {
      debugPrint('Error fetching top products: $e');
      return [];
    }
  }

  /// Get delivery statistics
  Future<DeliveryStats> getDeliveryStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final orders = await _fetchOrders(userId, from, now);

      int onTime = orders
          .where((o) => o.status == OrderStatus.delivered)
          .length;
      int failed = orders
          .where((o) => o.status == OrderStatus.cancelled)
          .length;

      return DeliveryStats(
        onTimeRate: orders.isEmpty ? 0 : (onTime / orders.length) * 100,
        failureRate: orders.isEmpty ? 0 : (failed / orders.length) * 100,
        avgDeliveryTime: 135.0, // Minutes - would need tracking data
        totalDeliveries: orders.length,
      );
    } catch (e) {
      debugPrint('Error fetching delivery stats: $e');
      return DeliveryStats(
        onTimeRate: 0,
        failureRate: 0,
        avgDeliveryTime: 0,
        totalDeliveries: 0,
      );
    }
  }

  /// Load alerts
  Future<void> loadAlerts() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final orders = await _fetchOrders(userId, from, now);

      _alerts.clear();

      // Check for stuck orders
      for (final order in orders.where((o) => o.status == OrderStatus.pending)) {
        final age = now.difference(order.createdAt);
        if (age.inHours >= 2) {
          _alerts.add(AlertModel(
            alertId: order.id,
            type: AlertType.orderStuck,
            severity: AlertSeverity.critical,
            title: 'Stuck Order',
            message: 'Order #${order.orderNumber} stuck for ${age.inHours} hours',
            action: 'Assign Employee',
            timestamp: now,
          ));
        }
      }

      // Check for payment failures (mock)
      _alerts.add(AlertModel(
        alertId: 'alert_1',
        type: AlertType.paymentFailed,
        severity: AlertSeverity.critical,
        title: 'Payment Failed',
        message: 'Payment failed for order #FJ1144',
        action: 'Retry',
        timestamp: now,
      ));

      // Success alerts (mock)
      _alerts.add(AlertModel(
        alertId: 'alert_2',
        type: AlertType.systemAlert,
        severity: AlertSeverity.info,
        title: 'New Review',
        message: 'New 5-star review from customer',
        action: 'View',
        timestamp: now,
      ));

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading alerts: $e');
    }
  }

  /// Dismiss alert
  void dismissAlert(String alertId) {
    _alerts.removeWhere((a) => a.alertId == alertId);
    notifyListeners();
  }

  /// Mark alert as resolved
  void resolveAlert(String alertId) {
    final index = _alerts.indexWhere((a) => a.alertId == alertId);
    if (index >= 0) {
      _alerts.removeAt(index);
      notifyListeners();
    }
  }
}

// Data models for trends
class RevenueDataPoint {
  final String date;
  final double revenue;

  RevenueDataPoint({required this.date, required this.revenue});
}

class OrderDataPoint {
  final String date;
  final int count;

  OrderDataPoint({required this.date, required this.count});
}

class DeliveryStats {
  final double onTimeRate;
  final double failureRate;
  final double avgDeliveryTime;
  final int totalDeliveries;

  DeliveryStats({
    required this.onTimeRate,
    required this.failureRate,
    required this.avgDeliveryTime,
    required this.totalDeliveries,
  });
}

class AlertDataPoint {
  final String date;
  final int count;

  AlertDataPoint({required this.date, required this.count});
}
