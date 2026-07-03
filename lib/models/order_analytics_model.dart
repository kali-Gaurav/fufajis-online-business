/// Model for order analytics across different time periods
class OrderAnalyticsModel {
  final String period;
  final int completedOrders;
  final int cancelledOrders;
  final int returnedOrders;
  final int refundedOrders;
  final double avgTimeToDeliver; // in minutes
  final double onTimeDeliveryRate; // percentage 0-100
  final double customerSatisfactionRating; // 1-5 scale
  final DateTime timestamp;

  const OrderAnalyticsModel({
    required this.period,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.returnedOrders,
    required this.refundedOrders,
    required this.avgTimeToDeliver,
    required this.onTimeDeliveryRate,
    required this.customerSatisfactionRating,
    required this.timestamp,
  });

  /// Factory constructor to create OrderAnalyticsModel from JSON/Map
  factory OrderAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return OrderAnalyticsModel(
      period: json['period'] as String? ?? 'unknown',
      completedOrders: json['completedOrders'] as int? ?? 0,
      cancelledOrders: json['cancelledOrders'] as int? ?? 0,
      returnedOrders: json['returnedOrders'] as int? ?? 0,
      refundedOrders: json['refundedOrders'] as int? ?? 0,
      avgTimeToDeliver: (json['avgTimeToDeliver'] as num?)?.toDouble() ?? 0.0,
      onTimeDeliveryRate: (json['onTimeDeliveryRate'] as num?)?.toDouble() ?? 0.0,
      customerSatisfactionRating: (json['customerSatisfactionRating'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  /// Convert OrderAnalyticsModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'completedOrders': completedOrders,
      'cancelledOrders': cancelledOrders,
      'returnedOrders': returnedOrders,
      'refundedOrders': refundedOrders,
      'avgTimeToDeliver': avgTimeToDeliver,
      'onTimeDeliveryRate': onTimeDeliveryRate,
      'customerSatisfactionRating': customerSatisfactionRating,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Calculate total non-completed orders
  int get totalFailedOrders => cancelledOrders + returnedOrders + refundedOrders;

  /// Calculate success rate percentage
  double get successRate {
    if (completedOrders == 0) return 0.0;
    final total = completedOrders + totalFailedOrders;
    if (total == 0) return 0.0;
    return (completedOrders / total) * 100;
  }

  /// Copy with method for creating modified instances
  OrderAnalyticsModel copyWith({
    String? period,
    int? completedOrders,
    int? cancelledOrders,
    int? returnedOrders,
    int? refundedOrders,
    double? avgTimeToDeliver,
    double? onTimeDeliveryRate,
    double? customerSatisfactionRating,
    DateTime? timestamp,
  }) {
    return OrderAnalyticsModel(
      period: period ?? this.period,
      completedOrders: completedOrders ?? this.completedOrders,
      cancelledOrders: cancelledOrders ?? this.cancelledOrders,
      returnedOrders: returnedOrders ?? this.returnedOrders,
      refundedOrders: refundedOrders ?? this.refundedOrders,
      avgTimeToDeliver: avgTimeToDeliver ?? this.avgTimeToDeliver,
      onTimeDeliveryRate: onTimeDeliveryRate ?? this.onTimeDeliveryRate,
      customerSatisfactionRating: customerSatisfactionRating ?? this.customerSatisfactionRating,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'OrderAnalyticsModel(period: $period, completed: $completedOrders, cancelled: $cancelledOrders, '
        'returned: $returnedOrders, refunded: $refundedOrders, avgDeliveryTime: ${avgTimeToDeliver}min, '
        'onTimeRate: $onTimeDeliveryRate%, satisfaction: $customerSatisfactionRating/5)';
  }
}
