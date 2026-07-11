import 'package:flutter_test/flutter_test.dart';
import 'package:fufaji/models/analytics_models.dart';

void main() {
  group('Analytics Models Tests', () {
    group('ChartDataPoint', () {
      test('should create ChartDataPoint with coordinates', () {
        final point = ChartDataPoint(x: 0, y: 100, label: 'Day 1');

        expect(point.x, 0);
        expect(point.y, 100);
        expect(point.label, 'Day 1');
      });

      test('should support equality comparison', () {
        final point1 = ChartDataPoint(x: 0, y: 100);
        final point2 = ChartDataPoint(x: 0, y: 100);

        expect(point1, equals(point2));
      });

      test('should handle optional label', () {
        final point1 = ChartDataPoint(x: 0, y: 100);
        final point2 = ChartDataPoint(x: 0, y: 100, label: 'Label');

        expect(point1.label, isNull);
        expect(point2.label, isNotNull);
      });
    });

    group('AnalyticsPeriod Enum', () {
      test('should have correct label values', () {
        expect(AnalyticsPeriod.today.label, 'Today');
        expect(AnalyticsPeriod.week.label, 'This Week');
        expect(AnalyticsPeriod.month.label, 'This Month');
        expect(AnalyticsPeriod.year.label, 'This Year');
      });

      test('should have correct API values', () {
        expect(AnalyticsPeriod.today.apiValue, 'today');
        expect(AnalyticsPeriod.week.apiValue, 'week');
        expect(AnalyticsPeriod.month.apiValue, 'month');
        expect(AnalyticsPeriod.year.apiValue, 'year');
      });
    });

    group('DailyAnalytics', () {
      test('should create DailyAnalytics with all fields', () {
        final now = DateTime.now();
        final analytics = DailyAnalytics(
          date: now,
          totalRevenue: 50000,
          totalOrders: 100,
          totalCustomers: 50,
          newCustomers: 10,
          returningCustomers: 40,
          avgOrderValue: 500,
          deliverySuccessRate: 95.5,
          customerSatisfaction: 4.5,
          peakHour: 2,
          peakHourOrders: 25,
        );

        expect(analytics.totalRevenue, 50000);
        expect(analytics.totalOrders, 100);
        expect(analytics.totalCustomers, 50);
        expect(analytics.newCustomers, 10);
        expect(analytics.avgOrderValue, 500);
        expect(analytics.deliverySuccessRate, 95.5);
      });

      test('should format revenue with currency', () {
        final analytics = DailyAnalytics(
          date: DateTime.now(),
          totalRevenue: 50000,
          totalOrders: 0,
          totalCustomers: 0,
          newCustomers: 0,
          returningCustomers: 0,
          avgOrderValue: 0,
          deliverySuccessRate: 0,
          customerSatisfaction: 0,
          peakHour: null,
          peakHourOrders: 0,
        );

        expect(analytics.totalRevenueFormatted, contains('₹'));
      });

      test('should calculate repeat rate', () {
        final analytics = DailyAnalytics(
          date: DateTime.now(),
          totalRevenue: 0,
          totalOrders: 100,
          totalCustomers: 50,
          newCustomers: 10,
          returningCustomers: 40,
          avgOrderValue: 0,
          deliverySuccessRate: 0,
          customerSatisfaction: 0,
          peakHour: null,
          peakHourOrders: 0,
        );

        expect(analytics.repeatRate, 80.0);
      });

      test('should support JSON serialization', () {
        final analytics = DailyAnalytics(
          date: DateTime(2026, 7, 12),
          totalRevenue: 50000,
          totalOrders: 100,
          totalCustomers: 50,
          newCustomers: 10,
          returningCustomers: 40,
          avgOrderValue: 500,
          deliverySuccessRate: 95.5,
          customerSatisfaction: 4.5,
          peakHour: 2,
          peakHourOrders: 25,
        );

        final json = analytics.toJson();
        expect(json['totalRevenue'], 50000);
        expect(json['totalOrders'], 100);
        expect(json['totalCustomers'], 50);

        final fromJson = DailyAnalytics.fromJson(json);
        expect(fromJson.totalRevenue, analytics.totalRevenue);
        expect(fromJson.totalOrders, analytics.totalOrders);
      });

      test('should support equality comparison', () {
        final now = DateTime(2026, 7, 12);
        final a1 = DailyAnalytics(
          date: now,
          totalRevenue: 50000,
          totalOrders: 100,
          totalCustomers: 50,
          newCustomers: 10,
          returningCustomers: 40,
          avgOrderValue: 500,
          deliverySuccessRate: 95.5,
          customerSatisfaction: 4.5,
          peakHour: 2,
          peakHourOrders: 25,
        );

        final a2 = DailyAnalytics(
          date: now,
          totalRevenue: 50000,
          totalOrders: 100,
          totalCustomers: 50,
          newCustomers: 10,
          returningCustomers: 40,
          avgOrderValue: 500,
          deliverySuccessRate: 95.5,
          customerSatisfaction: 4.5,
          peakHour: 2,
          peakHourOrders: 25,
        );

        expect(a1, equals(a2));
      });
    });

    group('RevenueBreakdown', () {
      test('should create RevenueBreakdown with categories', () {
        final breakdown = RevenueBreakdown(
          byCategory: {
            'Fruits': 20000,
            'Vegetables': 15000,
            'Dairy': 10000,
          },
          byPaymentMethod: {
            'Card': 30000,
            'UPI': 15000,
          },
        );

        expect(breakdown.byCategory.length, 3);
        expect(breakdown.byPaymentMethod.length, 2);
      });

      test('should calculate total revenue correctly', () {
        final breakdown = RevenueBreakdown(
          byCategory: {
            'Fruits': 20000,
            'Vegetables': 15000,
            'Dairy': 10000,
          },
          byPaymentMethod: {
            'Card': 30000,
            'UPI': 15000,
          },
        );

        expect(breakdown.totalRevenue, 45000);
      });

      test('should support JSON serialization', () {
        final breakdown = RevenueBreakdown(
          byCategory: {
            'Fruits': 20000,
            'Vegetables': 15000,
          },
          byPaymentMethod: {
            'Card': 30000,
            'UPI': 5000,
          },
        );

        final json = breakdown.toJson();
        expect(json['byCategory']['Fruits'], 20000);
        expect(json['byPaymentMethod']['Card'], 30000);

        final fromJson = RevenueBreakdown.fromJson(json);
        expect(fromJson.totalRevenue, breakdown.totalRevenue);
      });
    });

    group('OrderAnalytics', () {
      test('should create OrderAnalytics with all fields', () {
        final analytics = OrderAnalytics(
          totalOrders: 100,
          deliveredOrders: 95,
          pendingOrders: 5,
          cancelledOrders: 0,
          avgOrderValue: 500,
          topProducts: {
            'Apple': 50,
            'Banana': 40,
          },
        );

        expect(analytics.totalOrders, 100);
        expect(analytics.deliveredOrders, 95);
        expect(analytics.successRate, 95.0);
      });

      test('should calculate success rate correctly', () {
        final analytics = OrderAnalytics(
          totalOrders: 100,
          deliveredOrders: 90,
          pendingOrders: 10,
          cancelledOrders: 0,
          avgOrderValue: 500,
          topProducts: {},
        );

        expect(analytics.successRate, 90.0);
      });

      test('should format average order value', () {
        final analytics = OrderAnalytics(
          totalOrders: 100,
          deliveredOrders: 90,
          pendingOrders: 10,
          cancelledOrders: 0,
          avgOrderValue: 500,
          topProducts: {},
        );

        expect(analytics.avgOrderValueFormatted, contains('₹'));
      });
    });

    group('CustomerInsights', () {
      test('should create CustomerInsights with segmentation', () {
        final insights = CustomerInsights(
          customerId: 'cust_123',
          lifetimeValue: 50000,
          totalOrders: 20,
          avgOrderValue: 2500,
          segment: 'VIP',
          churnRisk: 0.1,
          repeatPurchaseRate: 85.0,
        );

        expect(insights.customerId, 'cust_123');
        expect(insights.segment, 'VIP');
        expect(insights.lifetimeValue, 50000);
      });

      test('should format lifetime value with currency', () {
        final insights = CustomerInsights(
          customerId: 'cust_123',
          lifetimeValue: 50000,
          totalOrders: 20,
          avgOrderValue: 2500,
          segment: 'VIP',
          churnRisk: 0.1,
          repeatPurchaseRate: 85.0,
        );

        expect(insights.lifetimeValueFormatted, contains('₹'));
      });

      test('should support JSON serialization', () {
        final insights = CustomerInsights(
          customerId: 'cust_123',
          lifetimeValue: 50000,
          totalOrders: 20,
          avgOrderValue: 2500,
          segment: 'VIP',
          churnRisk: 0.1,
          repeatPurchaseRate: 85.0,
        );

        final json = insights.toJson();
        expect(json['customerId'], 'cust_123');
        expect(json['lifetimeValue'], 50000);

        final fromJson = CustomerInsights.fromJson(json);
        expect(fromJson.customerId, insights.customerId);
      });
    });

    group('Alert', () {
      test('should create Alert with severity levels', () {
        final alert = Alert(
          id: 'alert_123',
          type: 'low_stock',
          severity: 'high',
          message: 'Stock running low',
          createdAt: DateTime.now(),
          dismissed: false,
        );

        expect(alert.id, 'alert_123');
        expect(alert.severity, 'high');
        expect(alert.type, 'low_stock');
      });

      test('should provide icon based on type', () {
        final alert1 = Alert(
          id: 'alert_1',
          type: 'low_stock',
          severity: 'medium',
          message: 'Low stock',
          createdAt: DateTime.now(),
          dismissed: false,
        );

        final alert2 = Alert(
          id: 'alert_2',
          type: 'delivery_failure',
          severity: 'high',
          message: 'Delivery failed',
          createdAt: DateTime.now(),
          dismissed: false,
        );

        expect(alert1.icon, isNotNull);
        expect(alert2.icon, isNotNull);
      });

      test('should support JSON serialization', () {
        final now = DateTime.now();
        final alert = Alert(
          id: 'alert_123',
          type: 'low_stock',
          severity: 'high',
          message: 'Stock running low',
          createdAt: now,
          dismissed: false,
        );

        final json = alert.toJson();
        expect(json['id'], 'alert_123');
        expect(json['type'], 'low_stock');

        final fromJson = Alert.fromJson(json);
        expect(fromJson.id, alert.id);
        expect(fromJson.type, alert.type);
      });
    });

    group('Report', () {
      test('should create Report with metadata', () {
        final now = DateTime.now();
        final report = Report(
          id: 'report_123',
          title: 'Daily Report',
          type: 'daily',
          generatedAt: now,
          data: {},
        );

        expect(report.id, 'report_123');
        expect(report.type, 'daily');
        expect(report.generatedAt, now);
      });

      test('should format generated date', () {
        final report = Report(
          id: 'report_123',
          title: 'Daily Report',
          type: 'daily',
          generatedAt: DateTime(2026, 7, 12, 10, 30),
          data: {},
        );

        expect(report.generatedAtFormatted, isNotNull);
      });

      test('should support JSON serialization', () {
        final now = DateTime(2026, 7, 12);
        final report = Report(
          id: 'report_123',
          title: 'Daily Report',
          type: 'daily',
          generatedAt: now,
          data: {'key': 'value'},
        );

        final json = report.toJson();
        expect(json['id'], 'report_123');
        expect(json['type'], 'daily');

        final fromJson = Report.fromJson(json);
        expect(fromJson.id, report.id);
        expect(fromJson.title, report.title);
      });
    });

    group('DeliveryMetricsData', () {
      test('should create DeliveryMetricsData with agent metrics', () {
        final agentMetrics = [
          AgentMetrics(
            agentId: 'agent_1',
            agentName: 'Agent 1',
            deliveriesCompleted: 50,
            onTimePercentage: 95,
            avgRating: 4.8,
            issuesCount: 2,
          ),
        ];

        final metrics = DeliveryMetricsData(
          totalDeliveries: 100,
          onTimeDeliveries: 95,
          avgDeliveryTime: 30,
          etaAccuracy: 92.5,
          agentMetrics: agentMetrics,
        );

        expect(metrics.totalDeliveries, 100);
        expect(metrics.onTimePercentage, 95.0);
        expect(metrics.agentMetrics.length, 1);
      });

      test('should calculate on-time percentage', () {
        final metrics = DeliveryMetricsData(
          totalDeliveries: 100,
          onTimeDeliveries: 85,
          avgDeliveryTime: 30,
          etaAccuracy: 92.5,
          agentMetrics: [],
        );

        expect(metrics.onTimePercentage, 85.0);
      });

      test('should support JSON serialization', () {
        final metrics = DeliveryMetricsData(
          totalDeliveries: 100,
          onTimeDeliveries: 95,
          avgDeliveryTime: 30,
          etaAccuracy: 92.5,
          agentMetrics: [],
        );

        final json = metrics.toJson();
        expect(json['totalDeliveries'], 100);
        expect(json['onTimeDeliveries'], 95);

        final fromJson = DeliveryMetricsData.fromJson(json);
        expect(fromJson.totalDeliveries, metrics.totalDeliveries);
      });
    });

    group('InventoryMetrics', () {
      test('should create InventoryMetrics with stock info', () {
        final metrics = InventoryMetrics(
          productId: 'prod_123',
          productName: 'Apple',
          stockLevel: 100,
          dailySales: 50,
          turnoverRate: 0.5,
          daysToStockout: 2,
          alertStatus: 'low_stock',
        );

        expect(metrics.productId, 'prod_123');
        expect(metrics.stockLevel, 100);
        expect(metrics.alertStatus, 'low_stock');
      });

      test('should support equality comparison', () {
        final m1 = InventoryMetrics(
          productId: 'prod_123',
          productName: 'Apple',
          stockLevel: 100,
          dailySales: 50,
          turnoverRate: 0.5,
          daysToStockout: 2,
          alertStatus: 'in_stock',
        );

        final m2 = InventoryMetrics(
          productId: 'prod_123',
          productName: 'Apple',
          stockLevel: 100,
          dailySales: 50,
          turnoverRate: 0.5,
          daysToStockout: 2,
          alertStatus: 'in_stock',
        );

        expect(m1, equals(m2));
      });
    });

    group('AgentMetrics', () {
      test('should create AgentMetrics with performance data', () {
        final metrics = AgentMetrics(
          agentId: 'agent_1',
          agentName: 'John Doe',
          deliveriesCompleted: 50,
          onTimePercentage: 95,
          avgRating: 4.8,
          issuesCount: 2,
        );

        expect(metrics.agentName, 'John Doe');
        expect(metrics.avgRating, 4.8);
        expect(metrics.onTimePercentage, 95);
      });

      test('should support JSON serialization', () {
        final metrics = AgentMetrics(
          agentId: 'agent_1',
          agentName: 'John Doe',
          deliveriesCompleted: 50,
          onTimePercentage: 95,
          avgRating: 4.8,
          issuesCount: 2,
        );

        final json = metrics.toJson();
        expect(json['agentName'], 'John Doe');
        expect(json['avgRating'], 4.8);

        final fromJson = AgentMetrics.fromJson(json);
        expect(fromJson.agentName, metrics.agentName);
      });
    });
  });
}
