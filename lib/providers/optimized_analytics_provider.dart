import 'package:flutter/material.dart';
import 'package:fufaji/models/analytics_models.dart';
import 'package:fufaji/services/business_analytics_service.dart';
import 'package:fufaji/utils/analytics_performance.dart';

/// Optimized analytics provider with lazy loading and stream management
class OptimizedAnalyticsDashboardProvider extends ChangeNotifier {
  final BusinessAnalyticsService _analyticsService = BusinessAnalyticsService.instance;

  // Metrics state
  DailyAnalytics? _metrics;
  RevenueBreakdown? _revenueBreakdown;
  OrderAnalytics? _orderAnalytics;
  CustomerInsights? _customerInsights;
  DeliveryMetricsData? _deliveryMetrics;
  Map<String, int>? _customerSegmentation;
  List<InventoryMetrics>? _lowStockAlerts;

  // UI state
  bool _isLoading = false;
  String? _error;
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.today;

  // Performance tracking
  int _lastLoadTime = 0;
  bool _isInitialized = false;

  // Stream subscriptions for cleanup
  final List<StreamSubscription> _subscriptions = [];

  DailyAnalytics? get metrics => _metrics;
  RevenueBreakdown? get revenueBreakdown => _revenueBreakdown;
  OrderAnalytics? get orderAnalytics => _orderAnalytics;
  CustomerInsights? get customerInsights => _customerInsights;
  DeliveryMetricsData? get deliveryMetrics => _deliveryMetrics;
  Map<String, int>? get customerSegmentation => _customerSegmentation;
  List<InventoryMetrics>? get lowStockAlerts => _lowStockAlerts;

  bool get isLoading => _isLoading;
  String? get error => _error;
  AnalyticsPeriod get selectedPeriod => _selectedPeriod;
  int get lastLoadTime => _lastLoadTime;

  OptimizedAnalyticsDashboardProvider() {
    _initializeStreams();
  }

  void _initializeStreams() {
    // Subscribe to real-time updates
    try {
      final dailyStream = _analyticsService.streamDailyAnalytics();
      if (dailyStream != null) {
        _subscriptions.add(
          dailyStream.listen(
            (data) {
              _metrics = data;
              notifyListeners();
            },
            onError: (e) {
              debugPrint('Error in daily analytics stream: $e');
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('Error initializing daily analytics stream: $e');
    }
  }

  /// Lazy load metrics on demand
  Future<void> loadDailyMetrics({bool forceRefresh = false}) async {
    // Check cache first
    if (!forceRefresh) {
      final cached = AnalyticsPerformance.getCachedValue<DailyAnalytics>('daily_metrics');
      if (cached != null) {
        _metrics = cached;
        notifyListeners();
        return;
      }
    }

    _setLoading(true);
    PerformanceMonitor.start('loadDailyMetrics');

    try {
      _error = null;

      // Load metrics in parallel
      await Future.wait([
        _loadDailyAnalytics(),
        _loadRevenueBreakdown(),
        _loadOrderAnalytics(),
        _loadDeliveryMetrics(),
        _loadLowStockAlerts(),
      ]);

      _lastLoadTime = PerformanceMonitor.stop('loadDailyMetrics');
      _isInitialized = true;
    } catch (e) {
      _error = 'Failed to load analytics: $e';
      debugPrint('Error loading analytics: $e');
      PerformanceMonitor.stop('loadDailyMetrics');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadDailyAnalytics() async {
    try {
      final data = await _analyticsService.getDailyAnalytics(selectedDate);
      if (data != null) {
        _metrics = data;
        AnalyticsPerformance.setCachedValue('daily_metrics', data);
      }
    } catch (e) {
      debugPrint('Error loading daily analytics: $e');
      rethrow;
    }
  }

  Future<void> _loadRevenueBreakdown() async {
    try {
      final data = await _analyticsService.getRevenueBreakdown(selectedDate);
      if (data != null) {
        _revenueBreakdown = data;
        AnalyticsPerformance.setCachedValue('revenue_breakdown', data);
      }
    } catch (e) {
      debugPrint('Error loading revenue breakdown: $e');
      rethrow;
    }
  }

  Future<void> _loadOrderAnalytics() async {
    try {
      final data = await _analyticsService.getOrderAnalytics(selectedDate);
      if (data != null) {
        _orderAnalytics = data;
        AnalyticsPerformance.setCachedValue('order_analytics', data);
      }
    } catch (e) {
      debugPrint('Error loading order analytics: $e');
      rethrow;
    }
  }

  Future<void> _loadDeliveryMetrics() async {
    try {
      final data = await _analyticsService.getDeliveryMetrics(selectedDate);
      if (data != null) {
        _deliveryMetrics = data;
        AnalyticsPerformance.setCachedValue('delivery_metrics', data);
      }
    } catch (e) {
      debugPrint('Error loading delivery metrics: $e');
      rethrow;
    }
  }

  Future<void> _loadLowStockAlerts() async {
    try {
      final data = await _analyticsService.getLowStockAlerts();
      if (data != null) {
        _lowStockAlerts = data;
        AnalyticsPerformance.setCachedValue('low_stock_alerts', data);
      }
    } catch (e) {
      debugPrint('Error loading low stock alerts: $e');
      rethrow;
    }
  }

  /// Set period and reload metrics
  void setPeriod(AnalyticsPeriod period) {
    if (_selectedPeriod != period) {
      _selectedPeriod = period;
      AnalyticsPerformance.clearCache(); // Clear cache on period change
      notifyListeners();
      // Trigger reload after UI update
      Future.microtask(() => loadDailyMetrics(forceRefresh: true));
    }
  }

  /// Get selected date based on period
  DateTime get selectedDate {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case AnalyticsPeriod.today:
        return DateTime(now.year, now.month, now.day);
      case AnalyticsPeriod.week:
        return now.subtract(Duration(days: now.weekday - 1));
      case AnalyticsPeriod.month:
        return DateTime(now.year, now.month, 1);
      case AnalyticsPeriod.year:
        return DateTime(now.year, 1, 1);
    }
  }

  /// Calculate comparison metrics
  Map<String, double> getComparison() {
    if (_metrics == null) {
      return {'revenue': 0, 'orders': 0, 'customers': 0};
    }

    // Simulate previous period data (in real app, fetch from DB)
    final prevRevenue = _metrics!.totalRevenue * 0.95;
    final prevOrders = _metrics!.totalOrders - 5;
    final prevCustomers = _metrics!.totalCustomers - 2;

    return {
      'revenue': AnalyticsPerformance.calculatePercentageChange(
        _metrics!.totalRevenue.toDouble(),
        prevRevenue,
      ),
      'orders': AnalyticsPerformance.calculatePercentageChange(
        _metrics!.totalOrders.toDouble(),
        prevOrders.toDouble(),
      ),
      'customers': AnalyticsPerformance.calculatePercentageChange(
        _metrics!.totalCustomers.toDouble(),
        prevCustomers.toDouble(),
      ),
    };
  }

  /// Internal method to set loading state
  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  /// Health check for data freshness
  bool isDataFresh() {
    return DateTime.now().difference(selectedDate).inHours < 1;
  }

  /// Memory management - cleanup subscriptions
  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    AnalyticsPerformance.clearCache();
    super.dispose();
  }
}

// For type safety in imports
typedef StreamSubscription<T> = dynamic;
