import 'package:flutter_test/flutter_test.dart';
import 'package:fufaji/providers/analytics_dashboard_provider.dart';
import 'package:fufaji/models/analytics_models.dart';

void main() {
  group('AnalyticsDashboardProvider Tests', () {
    late AnalyticsDashboardProvider provider;

    setUp(() {
      provider = AnalyticsDashboardProvider();
    });

    test('should initialize with default values', () {
      expect(provider.metrics, isNull);
      expect(provider.isLoading, false);
      expect(provider.error, isNull);
      expect(provider.selectedPeriod, AnalyticsPeriod.today);
    });

    test('should set period and notify listeners', () async {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.setPeriod(AnalyticsPeriod.week);

      expect(provider.selectedPeriod, AnalyticsPeriod.week);
      expect(notified, true);
    });

    test('should calculate selected date based on period', () {
      final now = DateTime.now();

      provider.setPeriod(AnalyticsPeriod.today);
      final todayDate = provider.selectedDate;
      expect(todayDate.year, now.year);
      expect(todayDate.month, now.month);
      expect(todayDate.day, now.day);

      provider.setPeriod(AnalyticsPeriod.week);
      final weekDate = provider.selectedDate;
      expect(weekDate.isBefore(now) || weekDate.isAtSameMomentAs(now), true);

      provider.setPeriod(AnalyticsPeriod.month);
      final monthDate = provider.selectedDate;
      expect(monthDate.day, 1);
      expect(monthDate.month, now.month);
    });

    test('should handle period label correctly', () {
      provider.setPeriod(AnalyticsPeriod.today);
      expect(provider.selectedPeriod.label, 'Today');

      provider.setPeriod(AnalyticsPeriod.week);
      expect(provider.selectedPeriod.label, 'This Week');

      provider.setPeriod(AnalyticsPeriod.month);
      expect(provider.selectedPeriod.label, 'This Month');

      provider.setPeriod(AnalyticsPeriod.year);
      expect(provider.selectedPeriod.label, 'This Year');
    });

    test('should calculate comparison with previous period', () {
      provider.metrics = DailyAnalytics(
        date: DateTime.now(),
        totalRevenue: 10000,
        totalOrders: 100,
        totalCustomers: 50,
        newCustomers: 10,
        returningCustomers: 40,
        avgOrderValue: 100,
        deliverySuccessRate: 90,
        customerSatisfaction: 4.5,
        peakHour: 2,
        peakHourOrders: 25,
      );

      final comparison = provider.getComparison();

      expect(comparison.containsKey('revenue'), true);
      expect(comparison.containsKey('orders'), true);
      expect(comparison.containsKey('customers'), true);
    });

    test('should handle null metrics in comparison', () {
      provider.metrics = null;
      final comparison = provider.getComparison();

      expect(comparison['revenue'], 0);
      expect(comparison['orders'], 0);
      expect(comparison['customers'], 0);
    });

    test('should support period-based filtering', () {
      // Test with different periods
      provider.setPeriod(AnalyticsPeriod.today);
      expect(provider.selectedPeriod, AnalyticsPeriod.today);

      provider.setPeriod(AnalyticsPeriod.week);
      expect(provider.selectedPeriod, AnalyticsPeriod.week);

      provider.setPeriod(AnalyticsPeriod.month);
      expect(provider.selectedPeriod, AnalyticsPeriod.month);

      provider.setPeriod(AnalyticsPeriod.year);
      expect(provider.selectedPeriod, AnalyticsPeriod.year);
    });

    test('should handle revenue breakdown', () {
      provider.revenueBreakdown = RevenueBreakdown(
        byCategory: {
          'Fruits': 5000,
          'Vegetables': 3000,
        },
        byPaymentMethod: {
          'Card': 6000,
          'UPI': 2000,
        },
      );

      expect(provider.revenueBreakdown, isNotNull);
      expect(provider.revenueBreakdown!.totalRevenue, 8000);
    });

    test('should handle order analytics', () {
      provider.orderAnalytics = OrderAnalytics(
        totalOrders: 100,
        deliveredOrders: 90,
        pendingOrders: 10,
        cancelledOrders: 0,
        avgOrderValue: 500,
        topProducts: {
          'Apple': 50,
        },
      );

      expect(provider.orderAnalytics, isNotNull);
      expect(provider.orderAnalytics!.totalOrders, 100);
      expect(provider.orderAnalytics!.successRate, 90.0);
    });

    test('should handle customer segmentation', () {
      provider.customerSegmentation = {
        'VIP': 5,
        'Regular': 20,
        'Occasional': 25,
      };

      expect(provider.customerSegmentation, isNotNull);
      expect(provider.customerSegmentation!['VIP'], 5);
    });

    test('should handle delivery metrics', () {
      provider.deliveryMetrics = DeliveryMetricsData(
        totalDeliveries: 100,
        onTimeDeliveries: 90,
        avgDeliveryTime: 30,
        etaAccuracy: 92.5,
        agentMetrics: [],
      );

      expect(provider.deliveryMetrics, isNotNull);
      expect(provider.deliveryMetrics!.onTimePercentage, 90.0);
    });

    test('should handle low stock alerts', () {
      provider.lowStockAlerts = [
        InventoryMetrics(
          productId: 'prod_1',
          productName: 'Apple',
          stockLevel: 5,
          dailySales: 10,
          turnoverRate: 2,
          daysToStockout: 1,
          alertStatus: 'low_stock',
        ),
      ];

      expect(provider.lowStockAlerts, isNotNull);
      expect(provider.lowStockAlerts!.length, 1);
      expect(provider.lowStockAlerts![0].alertStatus, 'low_stock');
    });

    test('should support loading state transitions', () {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      // Simulate loading
      provider.isLoading = true;
      expect(notified, true);

      notified = false;
      provider.isLoading = false;
      expect(notified, true);
    });

    test('should handle error state', () {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.error = 'Test error';
      expect(notified, true);
      expect(provider.error, 'Test error');

      notified = false;
      provider.error = null;
      expect(notified, true);
      expect(provider.error, isNull);
    });

    test('should dispose properly', () {
      provider.dispose();
      // If dispose completes without error, test passes
      expect(true, true);
    });
  });
}
