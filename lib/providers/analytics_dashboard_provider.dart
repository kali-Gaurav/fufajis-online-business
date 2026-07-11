import 'package:flutter/material.dart';
import '../models/analytics_models.dart';
import '../services/business_analytics_service.dart';

class AnalyticsDashboardProvider extends ChangeNotifier {
  final BusinessAnalyticsService _analyticsService =
      BusinessAnalyticsService();

  DailyAnalytics? metrics;
  RevenueBreakdown? revenueBreakdown;
  OrderAnalytics? orderAnalytics;
  DeliveryMetricsData? deliveryMetrics;
  List<InventoryMetrics> lowStockAlerts = [];
  List<Alert> activeAlerts = [];

  AnalyticsPeriod selectedPeriod = AnalyticsPeriod.today;
  bool isLoading = false;
  String? error;

  DateTime get selectedDate {
    final now = DateTime.now();
    switch (selectedPeriod) {
      case AnalyticsPeriod.today:
        return now;
      case AnalyticsPeriod.week:
        return now.subtract(Duration(days: now.weekday - 1));
      case AnalyticsPeriod.month:
        return DateTime(now.year, now.month, 1);
      case AnalyticsPeriod.year:
        return DateTime(now.year, 1, 1);
    }
  }

  AnalyticsDashboardProvider() {
    _initializeStreams();
  }

  void _initializeStreams() {
    // Subscribe to real-time metrics
    _analyticsService.streamDailyAnalytics().listen((newMetrics) {
      metrics = newMetrics;
      notifyListeners();
    });

    // Subscribe to alerts
    _analyticsService.streamAlerts().listen((newAlerts) {
      activeAlerts = newAlerts;
      notifyListeners();
    });
  }

  Future<void> loadDailyMetrics() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final date = selectedDate;

      // Load all analytics data
      final dailyTask = _analyticsService.getDailyAnalytics(date);
      final revenueTask = _analyticsService.getRevenueBreakdown(date);
      final orderTask = _analyticsService.getOrderAnalytics(date);
      final deliveryTask = _analyticsService.getDeliveryMetrics(date);
      final alertsTask = _analyticsService.getLowStockAlerts();

      final results = await Future.wait([
        dailyTask,
        revenueTask,
        orderTask,
        deliveryTask,
        alertsTask,
      ]);

      metrics = results[0] as DailyAnalytics?;
      revenueBreakdown = results[1] as RevenueBreakdown?;
      orderAnalytics = results[2] as OrderAnalytics?;
      deliveryMetrics = results[3] as DeliveryMetricsData?;
      lowStockAlerts = results[4] as List<InventoryMetrics>;
    } catch (e) {
      error = e.toString();
      print('Error loading daily metrics: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setPeriod(AnalyticsPeriod period) {
    selectedPeriod = period;
    loadDailyMetrics();
  }

  Stream<List<Alert>> watchAlerts() {
    return _analyticsService.streamAlerts();
  }

  Future<void> dismissAlert(String alertId) async {
    try {
      await _analyticsService.dismissAlert(alertId);
      activeAlerts.removeWhere((alert) => alert.id == alertId);
      notifyListeners();
    } catch (e) {
      print('Error dismissing alert: $e');
    }
  }

  // Get comparison with previous period
  Future<Map<String, double>> getComparison() async {
    try {
      final currentDate = selectedDate;
      final previousDate = _getPreviousDate(currentDate);

      final current = await _analyticsService.getDailyAnalytics(currentDate);
      final previous =
          await _analyticsService.getDailyAnalytics(previousDate);

      if (current == null || previous == null) {
        return {'revenue': 0, 'orders': 0, 'customers': 0};
      }

      final revenueChange =
          ((current.totalRevenue - previous.totalRevenue) /
                  previous.totalRevenue) *
              100;
      final ordersChange = ((current.totalOrders - previous.totalOrders) /
              previous.totalOrders) *
          100;
      final customersChange = ((current.totalCustomers -
                  previous.totalCustomers) /
              previous.totalCustomers) *
          100;

      return {
        'revenue': revenueChange.isFinite ? revenueChange : 0,
        'orders': ordersChange.isFinite ? ordersChange : 0,
        'customers': customersChange.isFinite ? customersChange : 0,
      };
    } catch (e) {
      print('Error calculating comparison: $e');
      return {'revenue': 0, 'orders': 0, 'customers': 0};
    }
  }

  DateTime _getPreviousDate(DateTime current) {
    switch (selectedPeriod) {
      case AnalyticsPeriod.today:
        return current.subtract(Duration(days: 1));
      case AnalyticsPeriod.week:
        return current.subtract(Duration(days: 7));
      case AnalyticsPeriod.month:
        return DateTime(current.year, current.month - 1, current.day);
      case AnalyticsPeriod.year:
        return DateTime(current.year - 1, current.month, current.day);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
