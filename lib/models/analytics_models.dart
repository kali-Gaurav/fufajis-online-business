import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

// =====================================================================
// DAILY ANALYTICS
// =====================================================================
class DailyAnalytics extends Equatable {
  final String id;
  final DateTime date;
  final double totalRevenue;
  final int totalOrders;
  final int totalCustomers;
  final int newCustomers;
  final int returningCustomers;
  final double avgOrderValue;
  final double deliverySuccessRate;
  final double customerSatisfaction;
  final int? peakHour;
  final int? peakHourOrders;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyAnalytics({
    required this.id,
    required this.date,
    required this.totalRevenue,
    required this.totalOrders,
    required this.totalCustomers,
    required this.newCustomers,
    required this.returningCustomers,
    required this.avgOrderValue,
    required this.deliverySuccessRate,
    required this.customerSatisfaction,
    this.peakHour,
    this.peakHourOrders,
    required this.createdAt,
    required this.updatedAt,
  });

  // Formatted display values
  String get formattedRevenue => '₹${totalRevenue.toStringAsFixed(0)}';
  String get formattedAvgOrderValue => '₹${avgOrderValue.toStringAsFixed(2)}';
  String get formattedSatisfaction => customerSatisfaction.toStringAsFixed(1);
  String get dateString => DateFormat('MMM d, y').format(date);

  factory DailyAnalytics.fromJson(Map<String, dynamic> json) {
    return DailyAnalytics(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      totalRevenue: (json['total_revenue'] as num).toDouble(),
      totalOrders: json['total_orders'] as int,
      totalCustomers: json['total_customers'] as int,
      newCustomers: json['new_customers'] as int? ?? 0,
      returningCustomers: json['returning_customers'] as int? ?? 0,
      avgOrderValue: (json['avg_order_value'] as num).toDouble(),
      deliverySuccessRate: (json['delivery_success_rate'] as num).toDouble(),
      customerSatisfaction: (json['customer_satisfaction'] as num).toDouble(),
      peakHour: json['peak_hour'] as int?,
      peakHourOrders: json['peak_hour_orders'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'total_revenue': totalRevenue,
    'total_orders': totalOrders,
    'total_customers': totalCustomers,
    'new_customers': newCustomers,
    'returning_customers': returningCustomers,
    'avg_order_value': avgOrderValue,
    'delivery_success_rate': deliverySuccessRate,
    'customer_satisfaction': customerSatisfaction,
    'peak_hour': peakHour,
    'peak_hour_orders': peakHourOrders,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    id, date, totalRevenue, totalOrders, totalCustomers, newCustomers,
    returningCustomers, avgOrderValue, deliverySuccessRate,
    customerSatisfaction, peakHour, peakHourOrders, createdAt, updatedAt
  ];
}

// =====================================================================
// REVENUE BREAKDOWN
// =====================================================================
class RevenueBreakdown extends Equatable {
  final String id;
  final DateTime date;
  final Map<String, double> byCategory;
  final Map<String, double> byPaymentMethod;
  final DateTime timestamp;

  const RevenueBreakdown({
    required this.id,
    required this.date,
    required this.byCategory,
    required this.byPaymentMethod,
    required this.timestamp,
  });

  double get totalRevenue {
    return byCategory.values.fold(0.0, (sum, val) => sum + val);
  }

  factory RevenueBreakdown.fromJson(Map<String, dynamic> json) {
    return RevenueBreakdown(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      byCategory: Map<String, double>.from(
        (json['by_category'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ) ?? {},
      ),
      byPaymentMethod: Map<String, double>.from(
        (json['by_payment_method'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ) ?? {},
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  List<Object> get props => [id, date, byCategory, byPaymentMethod, timestamp];
}

// =====================================================================
// ORDER ANALYTICS
// =====================================================================
class OrderAnalytics extends Equatable {
  final int totalOrders;
  final int delivered;
  final int pending;
  final int cancelled;
  final double deliverySuccessRate;
  final double avgOrderValue;
  final Map<String, int> topProducts;
  final DateTime timestamp;

  const OrderAnalytics({
    required this.totalOrders,
    required this.delivered,
    required this.pending,
    required this.cancelled,
    required this.deliverySuccessRate,
    required this.avgOrderValue,
    required this.topProducts,
    required this.timestamp,
  });

  double get cancelledPercentage => (cancelled / totalOrders) * 100;
  double get pendingPercentage => (pending / totalOrders) * 100;

  factory OrderAnalytics.fromJson(Map<String, dynamic> json) {
    return OrderAnalytics(
      totalOrders: json['total_orders'] as int,
      delivered: json['delivered'] as int? ?? 0,
      pending: json['pending'] as int? ?? 0,
      cancelled: json['cancelled'] as int? ?? 0,
      deliverySuccessRate: (json['delivery_success_rate'] as num).toDouble(),
      avgOrderValue: (json['avg_order_value'] as num).toDouble(),
      topProducts: Map<String, int>.from(
        (json['top_products'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v as int),
        ) ?? {},
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  List<Object> get props => [
    totalOrders, delivered, pending, cancelled,
    deliverySuccessRate, avgOrderValue, topProducts, timestamp
  ];
}

// =====================================================================
// CUSTOMER INSIGHTS
// =====================================================================
class CustomerInsights extends Equatable {
  final String id;
  final String customerId;
  final double lifetimeValue;
  final int totalOrders;
  final double avgOrderValue;
  final String segment; // VIP, Regular, Occasional, Inactive
  final DateTime? lastOrderDate;
  final double churnRisk; // 0-1
  final double repeatPurchaseRate;
  final int? avgDaysBetweenOrders;

  const CustomerInsights({
    required this.id,
    required this.customerId,
    required this.lifetimeValue,
    required this.totalOrders,
    required this.avgOrderValue,
    required this.segment,
    this.lastOrderDate,
    required this.churnRisk,
    required this.repeatPurchaseRate,
    this.avgDaysBetweenOrders,
  });

  String get segmentLabel {
    switch (segment.toLowerCase()) {
      case 'vip':
        return '⭐ VIP';
      case 'regular':
        return '💎 Regular';
      case 'occasional':
        return '👤 Occasional';
      case 'inactive':
        return '⏸️ Inactive';
      default:
        return segment;
    }
  }

  String get churnRiskLabel {
    if (churnRisk > 0.7) return 'High Risk';
    if (churnRisk > 0.4) return 'Medium Risk';
    return 'Low Risk';
  }

  factory CustomerInsights.fromJson(Map<String, dynamic> json) {
    return CustomerInsights(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      lifetimeValue: (json['lifetime_value'] as num).toDouble(),
      totalOrders: json['total_orders'] as int,
      avgOrderValue: (json['avg_order_value'] as num).toDouble(),
      segment: json['customer_segment'] as String,
      lastOrderDate: json['last_order_date'] != null
          ? DateTime.parse(json['last_order_date'] as String)
          : null,
      churnRisk: (json['churn_risk'] as num).toDouble(),
      repeatPurchaseRate: (json['repeat_purchase_rate'] as num?)?.toDouble() ?? 0,
      avgDaysBetweenOrders: json['avg_days_between_orders'] as int?,
    );
  }

  @override
  List<Object?> get props => [
    id, customerId, lifetimeValue, totalOrders, avgOrderValue,
    segment, lastOrderDate, churnRisk, repeatPurchaseRate,
    avgDaysBetweenOrders
  ];
}

// =====================================================================
// DELIVERY METRICS
// =====================================================================
class DeliveryMetricsData extends Equatable {
  final int totalDeliveries;
  final int onTimeDeliveries;
  final double onTimePercentage;
  final double avgDeliveryTime;
  final double etaAccuracy;
  final List<AgentMetrics> agentMetrics;
  final Map<String, int> issueDistribution;

  const DeliveryMetricsData({
    required this.totalDeliveries,
    required this.onTimeDeliveries,
    required this.onTimePercentage,
    required this.avgDeliveryTime,
    required this.etaAccuracy,
    required this.agentMetrics,
    required this.issueDistribution,
  });

  int get failedDeliveries => totalDeliveries - onTimeDeliveries;

  factory DeliveryMetricsData.fromJson(Map<String, dynamic> json) {
    return DeliveryMetricsData(
      totalDeliveries: json['total_deliveries'] as int,
      onTimeDeliveries: json['on_time_deliveries'] as int? ?? 0,
      onTimePercentage: (json['on_time_percentage'] as num).toDouble(),
      avgDeliveryTime: (json['avg_delivery_time'] as num).toDouble(),
      etaAccuracy: (json['eta_accuracy'] as num).toDouble(),
      agentMetrics: (json['agent_metrics'] as List?)
          ?.map((e) => AgentMetrics.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      issueDistribution: Map<String, int>.from(
        (json['issue_distribution'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v as int),
        ) ?? {},
      ),
    );
  }

  @override
  List<Object> get props => [
    totalDeliveries, onTimeDeliveries, onTimePercentage,
    avgDeliveryTime, etaAccuracy, agentMetrics, issueDistribution
  ];
}

class AgentMetrics extends Equatable {
  final String agentId;
  final String agentName;
  final int deliveriesCompleted;
  final double onTimePercentage;
  final double avgRating;
  final int issuesCount;

  const AgentMetrics({
    required this.agentId,
    required this.agentName,
    required this.deliveriesCompleted,
    required this.onTimePercentage,
    required this.avgRating,
    required this.issuesCount,
  });

  factory AgentMetrics.fromJson(Map<String, dynamic> json) {
    return AgentMetrics(
      agentId: json['agent_id'] as String,
      agentName: json['agent_name'] as String,
      deliveriesCompleted: json['deliveries_completed'] as int,
      onTimePercentage: (json['on_time_percentage'] as num).toDouble(),
      avgRating: (json['avg_rating'] as num).toDouble(),
      issuesCount: json['issues_count'] as int? ?? 0,
    );
  }

  @override
  List<Object> get props => [
    agentId, agentName, deliveriesCompleted,
    onTimePercentage, avgRating, issuesCount
  ];
}

// =====================================================================
// INVENTORY METRICS
// =====================================================================
class InventoryMetrics extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final int stockLevel;
  final int dailySales;
  final int weeklySales;
  final double turnoverRate;
  final int? daysToStockout;
  final double stockValue;
  final DateTime? expiryDate;
  final String alertStatus; // in_stock, low_stock, out_of_stock, expired
  final int reorderQuantity;

  const InventoryMetrics({
    required this.id,
    required this.productId,
    required this.productName,
    required this.stockLevel,
    required this.dailySales,
    required this.weeklySales,
    required this.turnoverRate,
    this.daysToStockout,
    required this.stockValue,
    this.expiryDate,
    required this.alertStatus,
    required this.reorderQuantity,
  });

  bool get isLowStock => alertStatus == 'low_stock';
  bool get isOutOfStock => alertStatus == 'out_of_stock';
  bool get isExpired => alertStatus == 'expired';
  bool get isNearExpiry => expiryDate != null &&
      expiryDate!.difference(DateTime.now()).inDays <= 7;

  factory InventoryMetrics.fromJson(Map<String, dynamic> json) {
    return InventoryMetrics(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      stockLevel: json['stock_level'] as int,
      dailySales: json['daily_sales'] as int? ?? 0,
      weeklySales: json['weekly_sales'] as int? ?? 0,
      turnoverRate: (json['turnover_rate'] as num).toDouble(),
      daysToStockout: json['days_to_stockout'] as int?,
      stockValue: (json['stock_value'] as num).toDouble(),
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      alertStatus: json['alert_status'] as String? ?? 'in_stock',
      reorderQuantity: json['reorder_quantity'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    id, productId, productName, stockLevel, dailySales, weeklySales,
    turnoverRate, daysToStockout, stockValue, expiryDate, alertStatus,
    reorderQuantity
  ];
}

// =====================================================================
// ALERT
// =====================================================================
class Alert extends Equatable {
  final String id;
  final String type; // low_stock, delivery_issue, customer_churn, quality_issue, revenue_drop
  final String severity; // low, medium, high, critical
  final String message;
  final String? affectedEntity; // product name, agent name, etc
  final String? actionUrl;
  final DateTime createdAt;
  final bool dismissed;

  const Alert({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    this.affectedEntity,
    this.actionUrl,
    required this.createdAt,
    required this.dismissed,
  });

  String get icon {
    switch (type) {
      case 'low_stock':
        return '📦';
      case 'delivery_issue':
        return '🚚';
      case 'customer_churn':
        return '👥';
      case 'quality_issue':
        return '⚠️';
      case 'revenue_drop':
        return '📉';
      default:
        return '🔔';
    }
  }

  Color get severityColor {
    switch (severity) {
      case 'critical':
        return const Color(0xFFD32F2F);
      case 'high':
        return const Color(0xFFF57C00);
      case 'medium':
        return const Color(0xFFFBC02D);
      case 'low':
        return const Color(0xFF388E3C);
      default:
        return const Color(0xFF1976D2);
    }
  }

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as String,
      type: json['type'] as String,
      severity: json['severity'] as String,
      message: json['message'] as String,
      affectedEntity: json['affected_entity'] as String?,
      actionUrl: json['action_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      dismissed: json['dismissed'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    id, type, severity, message, affectedEntity, actionUrl, createdAt, dismissed
  ];
}

// =====================================================================
// REPORT
// =====================================================================
class Report extends Equatable {
  final String id;
  final String title;
  final String type; // daily, weekly, monthly, custom
  final DateTime generatedAt;
  final Map<String, dynamic> data;
  final String? pdfUrl;
  final String? csvUrl;

  const Report({
    required this.id,
    required this.title,
    required this.type,
    required this.generatedAt,
    required this.data,
    this.pdfUrl,
    this.csvUrl,
  });

  bool get hasPdf => pdfUrl != null && pdfUrl!.isNotEmpty;
  bool get hasCsv => csvUrl != null && csvUrl!.isNotEmpty;

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      data: json['data'] as Map<String, dynamic>? ?? {},
      pdfUrl: json['pdf_url'] as String?,
      csvUrl: json['csv_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id, title, type, generatedAt, data, pdfUrl, csvUrl
  ];
}

// =====================================================================
// CHART DATA
// =====================================================================
class ChartDataPoint extends Equatable {
  final double x;
  final double y;
  final String? label;

  const ChartDataPoint({
    required this.x,
    required this.y,
    this.label,
  });

  @override
  List<Object?> get props => [x, y, label];
}

// =====================================================================
// ANALYTICS PERIOD
// =====================================================================
enum AnalyticsPeriod { today, week, month, year }

extension AnalyticsPeriodExtension on AnalyticsPeriod {
  String get label {
    switch (this) {
      case AnalyticsPeriod.today:
        return 'Today';
      case AnalyticsPeriod.week:
        return 'This Week';
      case AnalyticsPeriod.month:
        return 'This Month';
      case AnalyticsPeriod.year:
        return 'This Year';
    }
  }

  String get apiValue {
    switch (this) {
      case AnalyticsPeriod.today:
        return 'today';
      case AnalyticsPeriod.week:
        return 'week';
      case AnalyticsPeriod.month:
        return 'month';
      case AnalyticsPeriod.year:
        return 'year';
    }
  }
}

// Import Color for Alert class
import 'package:flutter/material.dart';
