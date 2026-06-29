import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/dashboard_metrics.dart';
import '../models/order_analytics_model.dart';
import '../models/employee_performance_model.dart';

/// Service for fetching and processing business analytics data
/// Provides comprehensive metrics for owner dashboard
class BusinessAnalyticsService {
  static final BusinessAnalyticsService _instance =
      BusinessAnalyticsService._internal();

  factory BusinessAnalyticsService() => _instance;

  BusinessAnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get dashboard metrics for a specified period
  /// Period can be: 'today', 'week', 'month', 'year'
  Future<DashboardMetrics> getDashboardMetrics(String period) async {
    try {
      final dateRange = _getDateRange(period);
      final startDate = dateRange['start'] as DateTime;
      final endDate = dateRange['end'] as DateTime;

      debugPrint('[Analytics] Fetching dashboard metrics for period: $period');

      // Fetch revenue data
      final revenueData =
          await _getRevenueMetrics(startDate, endDate);

      // Fetch order data
      final orderData =
          await _getOrderMetrics(startDate, endDate);

      // Fetch customer data
      final customerData =
          await _getCustomerMetrics(startDate, endDate);

      // Fetch product data
      final productData = await _getProductMetrics();

      // Fetch delivery data
      final deliveryData =
          await _getDeliveryMetrics(startDate, endDate);

      // Fetch employee data
      final employeeData = await _getEmployeeMetrics();

      // Fetch profit data
      final profitData = await _getProfitMetrics(startDate, endDate);

      return DashboardMetrics(
        dateFrom: startDate,
        dateTo: endDate,
        totalRevenue: revenueData['total'] as double,
        revenueGrowth: revenueData['growth'] as double,
        revenueByPaymentMethod:
            revenueData['byPaymentMethod'] as Map<String, double>,
        revenueByCategory: revenueData['byCategory'] as Map<String, double>,
        totalOrders: orderData['total'] as int,
        pendingOrders: orderData['pending'] as int,
        packingOrders: orderData['packing'] as int,
        shippedOrders: orderData['shipped'] as int,
        deliveredOrders: orderData['delivered'] as int,
        cancelledOrders: orderData['cancelled'] as int,
        returnedOrders: orderData['returned'] as int,
        orderGrowth: orderData['growth'] as double,
        avgOrderValue: orderData['avgValue'] as double,
        totalCustomers: customerData['total'] as int,
        newCustomers: customerData['new'] as int,
        repeatCustomers: customerData['repeat'] as int,
        repeatPurchaseRate: customerData['repeatRate'] as double,
        avgCustomerLTV: customerData['ltv'] as double,
        customerChurnRate: customerData['churnRate'] as double,
        topSellers: productData['topSellers'] as List<ProductMetric>,
        lowPerformers: productData['lowPerformers'] as List<ProductMetric>,
        outOfStockCount: productData['outOfStock'] as int,
        avgProductRating: productData['avgRating'] as double,
        onTimeDeliveryRate: deliveryData['onTimeRate'] as double,
        failedDeliveryRate: deliveryData['failedRate'] as double,
        avgDeliveryTime: deliveryData['avgTime'] as double,
        topDeliveryAgents:
            deliveryData['topAgents'] as List<DeliveryAgentMetric>,
        topPerformers: employeeData,
        avgPackingQuality: 0.0, // Will be calculated from employee data
        grossProfit: profitData['gross'] as double,
        profitMargin: profitData['margin'] as double,
        costBreakdown: profitData['breakdown'] as Map<String, double>,
      );
    } catch (e) {
      debugPrint('[Analytics] Error fetching dashboard metrics: $e');
      rethrow;
    }
  }

  /// Get revenue analytics for a specified period
  Future<Map<String, dynamic>> getRevenueAnalytics(String period) async {
    try {
      final dateRange = _getDateRange(period);
      final startDate = dateRange['start'] as DateTime;
      final endDate = dateRange['end'] as DateTime;

      final data = await _getRevenueMetrics(startDate, endDate);

      // Calculate trend from previous period
      final prevDateRange = _getPreviousPeriodDateRange(period);
      final prevStartDate = prevDateRange['start'] as DateTime;
      final prevEndDate = prevDateRange['end'] as DateTime;
      final prevData = await _getRevenueMetrics(prevStartDate, prevEndDate);

      final prevRevenue = prevData['total'] as double;
      final currentRevenue = data['total'] as double;
      final trend = prevRevenue > 0
          ? ((currentRevenue - prevRevenue) / prevRevenue) * 100
          : 0.0;

      return {
        'today': data['today'] ?? 0.0,
        'week': data['week'] ?? 0.0,
        'month': data['month'] ?? 0.0,
        'year': data['year'] ?? 0.0,
        'current': currentRevenue,
        'previous': prevRevenue,
        'trend': trend,
        'byPaymentMethod': data['byPaymentMethod'],
        'byCategory': data['byCategory'],
      };
    } catch (e) {
      debugPrint('[Analytics] Error fetching revenue analytics: $e');
      rethrow;
    }
  }

  /// Get order analytics for a specified period
  Future<OrderAnalyticsModel> getOrderAnalytics(String period) async {
    try {
      final dateRange = _getDateRange(period);
      final startDate = dateRange['start'] as DateTime;
      final endDate = dateRange['end'] as DateTime;

      final orderData = await _getOrderMetrics(startDate, endDate);

      final completed = orderData['delivered'] as int;
      final cancelled = orderData['cancelled'] as int;
      final returned = orderData['returned'] as int;
      final refunded = orderData['refunded'] as int? ?? 0;

      return OrderAnalyticsModel(
        period: period,
        completedOrders: completed,
        cancelledOrders: cancelled,
        returnedOrders: returned,
        refundedOrders: refunded,
        avgTimeToDeliver: orderData['avgDeliveryTime'] as double? ?? 0.0,
        onTimeDeliveryRate: orderData['onTimeRate'] as double? ?? 0.0,
        customerSatisfactionRating:
            orderData['avgRating'] as double? ?? 0.0,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[Analytics] Error fetching order analytics: $e');
      rethrow;
    }
  }

  /// Get product analytics
  Future<Map<String, dynamic>> getProductAnalytics() async {
    try {
      return await _getProductMetrics();
    } catch (e) {
      debugPrint('[Analytics] Error fetching product analytics: $e');
      rethrow;
    }
  }

  /// Get customer analytics for a specified period
  Future<Map<String, dynamic>> getCustomerAnalytics(String period) async {
    try {
      final dateRange = _getDateRange(period);
      final startDate = dateRange['start'] as DateTime;
      final endDate = dateRange['end'] as DateTime;

      return await _getCustomerMetrics(startDate, endDate);
    } catch (e) {
      debugPrint('[Analytics] Error fetching customer analytics: $e');
      rethrow;
    }
  }

  /// Get delivery analytics for a specified period
  Future<Map<String, dynamic>> getDeliveryAnalytics(String period) async {
    try {
      final dateRange = _getDateRange(period);
      final startDate = dateRange['start'] as DateTime;
      final endDate = dateRange['end'] as DateTime;

      return await _getDeliveryMetrics(startDate, endDate);
    } catch (e) {
      debugPrint('[Analytics] Error fetching delivery analytics: $e');
      rethrow;
    }
  }

  /// Get payment analytics for a specified period
  Future<Map<String, dynamic>> getPaymentAnalytics(String period) async {
    try {
      final dateRange = _getDateRange(period);
      final startDate = dateRange['start'] as DateTime;
      final endDate = dateRange['end'] as DateTime;

      final orders = await _firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .get();

      int totalPayments = 0;
      int successfulPayments = 0;
      int failedPayments = 0;
      double revenue = 0.0;
      final Map<String, int> failureReasons = {};

      for (var doc in orders.docs) {
        final data = doc.data();
        totalPayments++;

        final paymentStatus = data['paymentStatus'] as String? ?? 'pending';
        if (paymentStatus == 'completed' || paymentStatus == 'success') {
          successfulPayments++;
          revenue += (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        } else if (paymentStatus == 'failed') {
          failedPayments++;
          final reason = data['paymentFailureReason'] as String? ??
              'unknown';
          failureReasons[reason] = (failureReasons[reason] ?? 0) + 1;
        }
      }

      final successRate = totalPayments > 0
          ? (successfulPayments / totalPayments) * 100
          : 0.0;

      return {
        'totalPayments': totalPayments,
        'successfulPayments': successfulPayments,
        'failedPayments': failedPayments,
        'successRate': successRate,
        'revenue': revenue,
        'failureReasons': failureReasons,
      };
    } catch (e) {
      debugPrint('[Analytics] Error fetching payment analytics: $e');
      rethrow;
    }
  }

  Future<List<EmployeeMetric>> _getEmployeeMetrics() async {
    final employees = await getEmployeeAnalytics();
    return employees.map((e) => EmployeeMetric(
      employeeId: e.employeeId,
      employeeName: e.name,
      role: e.role,
      ordersCompleted: e.ordersPacked,
      qualityScore: e.qualityScore,
    )).toList();
  }

  /// Get employee performance analytics
  Future<List<EmployeePerformanceModel>> getEmployeeAnalytics() async {
    try {
      final employees = await _firestore.collection('employees').get();

      final List<EmployeePerformanceModel> performanceList = [];

      for (var doc in employees.docs) {
        final data = doc.data();

        performanceList.add(
          EmployeePerformanceModel(
            employeeId: doc.id,
            name: data['name'] as String? ?? 'Unknown',
            role: data['role'] as String? ?? 'Employee',
            ordersPacked: data['ordersPacked'] as int? ?? 0,
            qualityScore: (data['qualityScore'] as num?)?.toDouble() ?? 0.0,
            avgTimePerOrder:
                (data['avgTimePerOrder'] as num?)?.toDouble() ?? 0.0,
            rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
            efficiency: (data['efficiency'] as num?)?.toDouble() ?? 0.0,
            lastUpdated: data['lastUpdated'] != null
                ? (data['lastUpdated'] as Timestamp).toDate()
                : DateTime.now(),
          ),
        );
      }

      return performanceList;
    } catch (e) {
      debugPrint('[Analytics] Error fetching employee analytics: $e');
      rethrow;
    }
  }

  /// Get profit analytics for a specified period
  Future<Map<String, dynamic>> getProfitAnalytics(String period) async {
    try {
      final dateRange = _getDateRange(period);
      final startDate = dateRange['start'] as DateTime;
      final endDate = dateRange['end'] as DateTime;

      return await _getProfitMetrics(startDate, endDate);
    } catch (e) {
      debugPrint('[Analytics] Error fetching profit analytics: $e');
      rethrow;
    }
  }

  // ==================== PRIVATE HELPER METHODS ====================

  /// Get date range based on period string
  Map<String, DateTime> _getDateRange(String period) {
    final now = DateTime.now();
    late DateTime startDate;

    switch (period) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'year':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    return {
      'start': startDate,
      'end': now,
    };
  }

  /// Get previous period date range
  Map<String, DateTime> _getPreviousPeriodDateRange(String period) {
    final now = DateTime.now();
    late DateTime startDate;
    late DateTime endDate;

    switch (period) {
      case 'today':
        endDate = now.subtract(const Duration(days: 1));
        startDate = endDate;
        break;
      case 'week':
        endDate = now.subtract(const Duration(days: 1));
        startDate = endDate.subtract(const Duration(days: 6));
        break;
      case 'month':
        endDate = DateTime(now.year, now.month, 0); // Last day of prev month
        startDate = DateTime(now.year, now.month - 1, 1);
        break;
      case 'year':
        endDate = DateTime(now.year - 1, 12, 31);
        startDate = DateTime(now.year - 1, 1, 1);
        break;
      default:
        endDate = now.subtract(const Duration(days: 1));
        startDate = endDate;
    }

    return {'start': startDate, 'end': endDate};
  }

  /// Fetch revenue metrics
  Future<Map<String, dynamic>> _getRevenueMetrics(
      DateTime startDate, DateTime endDate) async {
    final orders = await _firestore
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: startDate)
        .where('createdAt', isLessThanOrEqualTo: endDate)
        .where('status', isEqualTo: 'delivered')
        .get();

    double totalRevenue = 0.0;
    final Map<String, double> byPaymentMethod = {};
    final Map<String, double> byCategory = {};

    for (var doc in orders.docs) {
      final data = doc.data();
      final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
      totalRevenue += amount;

      // Group by payment method
      final paymentMethod = data['paymentMethod'] as String? ?? 'unknown';
      byPaymentMethod[paymentMethod] =
          (byPaymentMethod[paymentMethod] ?? 0.0) + amount;

      // Group by category (from order items)
      final items = data['items'] as List? ?? [];
      for (var item in items) {
        final category =
            (item as Map<String, dynamic>)['category'] as String? ?? 'other';
        final itemAmount =
            ((item['quantity'] as num? ?? 0) * (item['price'] as num? ?? 0))
                .toDouble();
        byCategory[category] = (byCategory[category] ?? 0.0) + itemAmount;
      }
    }

    return {
      'total': totalRevenue,
      'growth': 0.0, // Will be calculated by caller
      'byPaymentMethod': byPaymentMethod,
      'byCategory': byCategory,
    };
  }

  /// Fetch order metrics
  Future<Map<String, dynamic>> _getOrderMetrics(
      DateTime startDate, DateTime endDate) async {
    final orders = await _firestore
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: startDate)
        .where('createdAt', isLessThanOrEqualTo: endDate)
        .get();

    int total = 0;
    int pending = 0;
    int packing = 0;
    int shipped = 0;
    int delivered = 0;
    int cancelled = 0;
    int returned = 0;
    int refunded = 0;
    double totalRevenue = 0.0;
    int deliveredCount = 0;
    double totalDeliveryTime = 0.0;
    int onTimeCount = 0;
    double totalRating = 0.0;
    int ratedCount = 0;

    for (var doc in orders.docs) {
      final data = doc.data();
      total++;

      final status = data['status'] as String? ?? 'pending';
      switch (status) {
        case 'pending':
          pending++;
          break;
        case 'confirmed':
          pending++;
          break;
        case 'processing':
          packing++;
          break;
        case 'packed':
          packing++;
          break;
        case 'outForDelivery':
          shipped++;
          break;
        case 'delivered':
          delivered++;
          deliveredCount++;
          totalRevenue += (data['totalAmount'] as num?)?.toDouble() ?? 0.0;

          // Calculate delivery time
          final createdAt = data['createdAt'] as Timestamp?;
          final deliveredAt = data['deliveredAt'] as Timestamp?;
          if (createdAt != null && deliveredAt != null) {
            totalDeliveryTime +=
                deliveredAt.toDate().difference(createdAt.toDate()).inMinutes;

            // Check if on-time
            const expectedDeliveryTime = 24 * 60; // 24 hours in minutes
            if (totalDeliveryTime <= expectedDeliveryTime) {
              onTimeCount++;
            }
          }

          // Get rating if available
          final rating = data['rating'] as num?;
          if (rating != null) {
            totalRating += rating.toDouble();
            ratedCount++;
          }
          break;
        case 'cancelled':
          cancelled++;
          break;
        case 'returned':
          returned++;
          break;
        case 'refunded':
          refunded++;
          break;
      }
    }

    final avgOrderValue =
        total > 0 ? totalRevenue / deliveredCount : 0.0;
    final avgDeliveryTime =
        deliveredCount > 0 ? totalDeliveryTime / deliveredCount : 0.0;
    final onTimeRate =
        deliveredCount > 0 ? (onTimeCount / deliveredCount) * 100 : 0.0;
    final avgRating = ratedCount > 0 ? totalRating / ratedCount : 0.0;

    return {
      'total': total,
      'pending': pending,
      'packing': packing,
      'shipped': shipped,
      'delivered': delivered,
      'cancelled': cancelled,
      'returned': returned,
      'refunded': refunded,
      'growth': 0.0,
      'avgValue': avgOrderValue,
      'avgDeliveryTime': avgDeliveryTime,
      'onTimeRate': onTimeRate,
      'avgRating': avgRating,
    };
  }

  /// Fetch customer metrics
  Future<Map<String, dynamic>> _getCustomerMetrics(
      DateTime startDate, DateTime endDate) async {
    final orders = await _firestore
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: startDate)
        .where('createdAt', isLessThanOrEqualTo: endDate)
        .get();

    final Set<String> totalCustomers = {};
    final Set<String> newCustomers = {};
    final Set<String> repeatingCustomers = {};

    for (var doc in orders.docs) {
      final data = doc.data();
      final customerId = data['customerId'] as String? ?? '';

      if (customerId.isNotEmpty) {
        totalCustomers.add(customerId);

        // Check if new customer (first order in period)
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null && createdAt.toDate().isAfter(startDate)) {
          newCustomers.add(customerId);
        }

        // Check if repeat customer (more than 1 order in period)
        final orderCount = orders.docs
            .where((o) =>
                (o.data()['customerId'] as String? ?? '') == customerId)
            .length;
        if (orderCount > 1) {
          repeatingCustomers.add(customerId);
        }
      }
    }

    final repeatRate = totalCustomers.isNotEmpty
        ? (repeatingCustomers.length / totalCustomers.length) * 100
        : 0.0;

    return {
      'total': totalCustomers.length,
      'new': newCustomers.length,
      'repeat': repeatingCustomers.length,
      'repeatRate': repeatRate,
      'ltv': 0.0, // Would require historical data
      'churnRate': 0.0, // Would require historical data
    };
  }

  /// Fetch product metrics
  Future<Map<String, dynamic>> _getProductMetrics() async {
    final products = await _firestore.collection('products').get();

    final List<ProductMetric> topSellers = [];
    final List<ProductMetric> lowPerformers = [];
    int outOfStock = 0;
    double totalRating = 0.0;
    int ratedCount = 0;

    for (var doc in products.docs) {
      final data = doc.data();

      final unitsSold = data['unitsSold'] as int? ?? 0;
      final revenue = (data['revenue'] as num?)?.toDouble() ?? 0.0;
      final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
      final stock = data['stock'] as int? ?? 0;

      if (rating > 0) {
        totalRating += rating;
        ratedCount++;
      }

      if (stock < 1) {
        outOfStock++;
      }

      if (unitsSold > 0 || revenue > 0) {
        final metric = ProductMetric(
          productId: doc.id,
          productName: data['name'] as String? ?? 'Unknown',
          unitsSold: unitsSold,
          revenue: revenue,
          rating: rating,
        );

        if (unitsSold > 50) {
          topSellers.add(metric);
        } else if (unitsSold < 5 && unitsSold > 0) {
          lowPerformers.add(metric);
        }
      }
    }

    // Sort and limit
    topSellers.sort((a, b) => b.unitsSold.compareTo(a.unitsSold));
    lowPerformers.sort((a, b) => a.unitsSold.compareTo(b.unitsSold));

    final avgRating = ratedCount > 0 ? totalRating / ratedCount : 0.0;

    return {
      'topSellers': topSellers.take(10).toList(),
      'lowPerformers': lowPerformers.take(10).toList(),
      'outOfStock': outOfStock,
      'avgRating': avgRating,
    };
  }

  /// Fetch delivery metrics
  Future<Map<String, dynamic>> _getDeliveryMetrics(
      DateTime startDate, DateTime endDate) async {
    final deliveries = await _firestore
        .collection('deliveries')
        .where('createdAt', isGreaterThanOrEqualTo: startDate)
        .where('createdAt', isLessThanOrEqualTo: endDate)
        .get();

    int totalDeliveries = 0;
    int successfulDeliveries = 0;
    int failedDeliveries = 0;
    double totalDeliveryTime = 0.0;
    final Map<String, int> agentDeliveries = {};
    final Map<String, double> agentRatings = {};

    for (var doc in deliveries.docs) {
      final data = doc.data();
      totalDeliveries++;

      final status = data['status'] as String? ?? 'pending';
      if (status == 'delivered') {
        successfulDeliveries++;

        // Calculate delivery time
        final createdAt = data['createdAt'] as Timestamp?;
        final deliveredAt = data['deliveredAt'] as Timestamp?;
        if (createdAt != null && deliveredAt != null) {
          totalDeliveryTime +=
              deliveredAt.toDate().difference(createdAt.toDate()).inMinutes;
        }
      } else if (status == 'failed') {
        failedDeliveries++;
      }

      // Track agent metrics
      final agentId = data['deliveryAgentId'] as String? ?? '';
      if (agentId.isNotEmpty) {
        agentDeliveries[agentId] = (agentDeliveries[agentId] ?? 0) + 1;

        final rating = data['rating'] as num?;
        if (rating != null) {
          final current = agentRatings[agentId] ?? 0.0;
          agentRatings[agentId] =
              (current + rating.toDouble()) / 2;
        }
      }
    }

    final onTimeRate = totalDeliveries > 0
        ? (successfulDeliveries / totalDeliveries) * 100
        : 0.0;
    final failedRate =
        totalDeliveries > 0 ? (failedDeliveries / totalDeliveries) * 100 : 0.0;
    final avgDeliveryTime =
        successfulDeliveries > 0 ? totalDeliveryTime / successfulDeliveries : 0.0;

    // Get top agents
    final topAgents = agentDeliveries.entries
        .map((e) => DeliveryAgentMetric(
              agentId: e.key,
              agentName: e.key, // Would need to fetch actual name
              deliveriesCompleted: e.value,
              avgRating: agentRatings[e.key] ?? 0.0,
              onTimeRate: onTimeRate,
            ))
        .toList();
    topAgents.sort((a, b) => b.deliveriesCompleted.compareTo(a.deliveriesCompleted));

    return {
      'totalDeliveries': totalDeliveries,
      'onTimeRate': onTimeRate,
      'failedRate': failedRate,
      'avgTime': avgDeliveryTime,
      'topAgents': topAgents.take(5).toList(),
    };
  }

  /// Fetch profit metrics
  Future<Map<String, dynamic>> _getProfitMetrics(
      DateTime startDate, DateTime endDate) async {
    // This is simplified; actual implementation would need cost data
    final revenueData = await _getRevenueMetrics(startDate, endDate);
    final revenue = revenueData['total'] as double;

    // Assume 60% gross margin (simplified)
    final grossProfit = revenue * 0.6;

    // Assume 30% net margin (simplified)
    final netProfit = revenue * 0.3;

    final margin = revenue > 0 ? (netProfit / revenue) * 100 : 0.0;

    return {
      'gross': grossProfit,
      'net': netProfit,
      'margin': margin,
      'breakdown': {
        'cogs': revenue * 0.4,
        'operations': revenue * 0.2,
        'delivery': revenue * 0.1,
      },
    };
  }
}
