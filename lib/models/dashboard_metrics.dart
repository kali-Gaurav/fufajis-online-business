import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents comprehensive dashboard metrics for owner analytics
class DashboardMetrics {
  final DateTime dateFrom;
  final DateTime dateTo;

  // Revenue metrics
  final double totalRevenue;
  final double revenueGrowth; // percentage
  final Map<String, double> revenueByPaymentMethod;
  final Map<String, double> revenueByCategory;

  // Order metrics
  final int totalOrders;
  final int pendingOrders;
  final int packingOrders;
  final int shippedOrders;
  final int deliveredOrders;
  final int cancelledOrders;
  final int returnedOrders;
  final double orderGrowth; // percentage
  final double avgOrderValue;

  // Customer metrics
  final int totalCustomers;
  final int newCustomers;
  final int repeatCustomers;
  final double repeatPurchaseRate; // percentage
  final double avgCustomerLTV; // Lifetime Value
  final double customerChurnRate; // percentage

  // Product metrics
  final List<ProductMetric> topSellers;
  final List<ProductMetric> lowPerformers;
  final int outOfStockCount;
  final double avgProductRating;

  // Delivery metrics
  final double onTimeDeliveryRate; // percentage
  final double failedDeliveryRate; // percentage
  final double avgDeliveryTime; // minutes
  final List<DeliveryAgentMetric> topDeliveryAgents;

  // Employee metrics
  final List<EmployeeMetric> topPerformers;
  final double avgPackingQuality; // percentage

  // Profit metrics
  final double grossProfit;
  final double profitMargin; // percentage
  final Map<String, double> costBreakdown; // {category: cost}

  const DashboardMetrics({
    required this.dateFrom,
    required this.dateTo,
    required this.totalRevenue,
    this.revenueGrowth = 0.0,
    this.revenueByPaymentMethod = const {},
    this.revenueByCategory = const {},
    required this.totalOrders,
    this.pendingOrders = 0,
    this.packingOrders = 0,
    this.shippedOrders = 0,
    this.deliveredOrders = 0,
    this.cancelledOrders = 0,
    this.returnedOrders = 0,
    this.orderGrowth = 0.0,
    this.avgOrderValue = 0.0,
    required this.totalCustomers,
    this.newCustomers = 0,
    this.repeatCustomers = 0,
    this.repeatPurchaseRate = 0.0,
    this.avgCustomerLTV = 0.0,
    this.customerChurnRate = 0.0,
    this.topSellers = const [],
    this.lowPerformers = const [],
    this.outOfStockCount = 0,
    this.avgProductRating = 0.0,
    this.onTimeDeliveryRate = 0.0,
    this.failedDeliveryRate = 0.0,
    this.avgDeliveryTime = 0.0,
    this.topDeliveryAgents = const [],
    this.topPerformers = const [],
    this.avgPackingQuality = 0.0,
    required this.grossProfit,
    this.profitMargin = 0.0,
    this.costBreakdown = const {},
  });

  factory DashboardMetrics.fromMap(Map<String, dynamic> map) {
    return DashboardMetrics(
      dateFrom: (map['dateFrom'] as Timestamp).toDate(),
      dateTo: (map['dateTo'] as Timestamp).toDate(),
      totalRevenue: (map['totalRevenue'] as num).toDouble(),
      revenueGrowth: (map['revenueGrowth'] as num?)?.toDouble() ?? 0.0,
      revenueByPaymentMethod: Map<String, double>.from(
        (map['revenueByPaymentMethod'] as Map?)?.map(
              (key, value) => MapEntry(key as String, (value as num).toDouble()),
            ) ??
            {},
      ),
      revenueByCategory: Map<String, double>.from(
        (map['revenueByCategory'] as Map?)?.map(
              (key, value) => MapEntry(key as String, (value as num).toDouble()),
            ) ??
            {},
      ),
      totalOrders: (map['totalOrders'] as num?)?.toInt() ?? 0,
      pendingOrders: (map['pendingOrders'] as num?)?.toInt() ?? 0,
      packingOrders: (map['packingOrders'] as num?)?.toInt() ?? 0,
      shippedOrders: (map['shippedOrders'] as num?)?.toInt() ?? 0,
      deliveredOrders: (map['deliveredOrders'] as num?)?.toInt() ?? 0,
      cancelledOrders: (map['cancelledOrders'] as num?)?.toInt() ?? 0,
      returnedOrders: (map['returnedOrders'] as num?)?.toInt() ?? 0,
      orderGrowth: (map['orderGrowth'] as num?)?.toDouble() ?? 0.0,
      avgOrderValue: (map['avgOrderValue'] as num?)?.toDouble() ?? 0.0,
      totalCustomers: (map['totalCustomers'] as num?)?.toInt() ?? 0,
      newCustomers: (map['newCustomers'] as num?)?.toInt() ?? 0,
      repeatCustomers: (map['repeatCustomers'] as num?)?.toInt() ?? 0,
      repeatPurchaseRate: (map['repeatPurchaseRate'] as num?)?.toDouble() ?? 0.0,
      avgCustomerLTV: (map['avgCustomerLTV'] as num?)?.toDouble() ?? 0.0,
      customerChurnRate: (map['customerChurnRate'] as num?)?.toDouble() ?? 0.0,
      topSellers:
          (map['topSellers'] as List?)
              ?.map((item) => ProductMetric.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      lowPerformers:
          (map['lowPerformers'] as List?)
              ?.map((item) => ProductMetric.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      outOfStockCount: (map['outOfStockCount'] as num?)?.toInt() ?? 0,
      avgProductRating: (map['avgProductRating'] as num?)?.toDouble() ?? 0.0,
      onTimeDeliveryRate: (map['onTimeDeliveryRate'] as num?)?.toDouble() ?? 0.0,
      failedDeliveryRate: (map['failedDeliveryRate'] as num?)?.toDouble() ?? 0.0,
      avgDeliveryTime: (map['avgDeliveryTime'] as num?)?.toDouble() ?? 0.0,
      topDeliveryAgents:
          (map['topDeliveryAgents'] as List?)
              ?.map((item) => DeliveryAgentMetric.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      topPerformers:
          (map['topPerformers'] as List?)
              ?.map((item) => EmployeeMetric.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      avgPackingQuality: (map['avgPackingQuality'] as num?)?.toDouble() ?? 0.0,
      grossProfit: (map['grossProfit'] as num).toDouble(),
      profitMargin: (map['profitMargin'] as num?)?.toDouble() ?? 0.0,
      costBreakdown: Map<String, double>.from(
        (map['costBreakdown'] as Map?)?.map(
              (key, value) => MapEntry(key as String, (value as num).toDouble()),
            ) ??
            {},
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dateFrom': Timestamp.fromDate(dateFrom),
      'dateTo': Timestamp.fromDate(dateTo),
      'totalRevenue': totalRevenue,
      'revenueGrowth': revenueGrowth,
      'revenueByPaymentMethod': revenueByPaymentMethod,
      'revenueByCategory': revenueByCategory,
      'totalOrders': totalOrders,
      'pendingOrders': pendingOrders,
      'packingOrders': packingOrders,
      'shippedOrders': shippedOrders,
      'deliveredOrders': deliveredOrders,
      'cancelledOrders': cancelledOrders,
      'returnedOrders': returnedOrders,
      'orderGrowth': orderGrowth,
      'avgOrderValue': avgOrderValue,
      'totalCustomers': totalCustomers,
      'newCustomers': newCustomers,
      'repeatCustomers': repeatCustomers,
      'repeatPurchaseRate': repeatPurchaseRate,
      'avgCustomerLTV': avgCustomerLTV,
      'customerChurnRate': customerChurnRate,
      'topSellers': topSellers.map((e) => e.toMap()).toList(),
      'lowPerformers': lowPerformers.map((e) => e.toMap()).toList(),
      'outOfStockCount': outOfStockCount,
      'avgProductRating': avgProductRating,
      'onTimeDeliveryRate': onTimeDeliveryRate,
      'failedDeliveryRate': failedDeliveryRate,
      'avgDeliveryTime': avgDeliveryTime,
      'topDeliveryAgents': topDeliveryAgents.map((e) => e.toMap()).toList(),
      'topPerformers': topPerformers.map((e) => e.toMap()).toList(),
      'avgPackingQuality': avgPackingQuality,
      'grossProfit': grossProfit,
      'profitMargin': profitMargin,
      'costBreakdown': costBreakdown,
    };
  }
}

class ProductMetric {
  final String productId;
  final String productName;
  final int unitsSold;
  final double revenue;
  final double rating;

  const ProductMetric({
    required this.productId,
    required this.productName,
    required this.unitsSold,
    required this.revenue,
    required this.rating,
  });

  factory ProductMetric.fromMap(Map<String, dynamic> map) {
    return ProductMetric(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      unitsSold: (map['unitsSold'] as num?)?.toInt() ?? 0,
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0.0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'unitsSold': unitsSold,
      'revenue': revenue,
      'rating': rating,
    };
  }
}

class DeliveryAgentMetric {
  final String agentId;
  final String agentName;
  final int deliveriesCompleted;
  final double avgRating;
  final double onTimeRate;

  const DeliveryAgentMetric({
    required this.agentId,
    required this.agentName,
    required this.deliveriesCompleted,
    required this.avgRating,
    required this.onTimeRate,
  });

  factory DeliveryAgentMetric.fromMap(Map<String, dynamic> map) {
    return DeliveryAgentMetric(
      agentId: map['agentId'] as String? ?? '',
      agentName: map['agentName'] as String? ?? '',
      deliveriesCompleted: (map['deliveriesCompleted'] as num?)?.toInt() ?? 0,
      avgRating: (map['avgRating'] as num?)?.toDouble() ?? 0.0,
      onTimeRate: (map['onTimeRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'agentId': agentId,
      'agentName': agentName,
      'deliveriesCompleted': deliveriesCompleted,
      'avgRating': avgRating,
      'onTimeRate': onTimeRate,
    };
  }
}

class EmployeeMetric {
  final String employeeId;
  final String employeeName;
  final String role;
  final int ordersCompleted;
  final double qualityScore; // percentage
  final double avgRating; // for delivery agents

  const EmployeeMetric({
    required this.employeeId,
    required this.employeeName,
    required this.role,
    required this.ordersCompleted,
    required this.qualityScore,
    this.avgRating = 0.0,
  });

  factory EmployeeMetric.fromMap(Map<String, dynamic> map) {
    return EmployeeMetric(
      employeeId: map['employeeId'] as String? ?? '',
      employeeName: map['employeeName'] as String? ?? '',
      role: map['role'] as String? ?? '',
      ordersCompleted: (map['ordersCompleted'] as num?)?.toInt() ?? 0,
      qualityScore: (map['qualityScore'] as num?)?.toDouble() ?? 0.0,
      avgRating: (map['avgRating'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'role': role,
      'ordersCompleted': ordersCompleted,
      'qualityScore': qualityScore,
      'avgRating': avgRating,
    };
  }
}
