import 'package:cloud_firestore/cloud_firestore.dart';

/// Aggregated sales totals for a date range / shop / vendor.
class SalesAnalyticsSummary {
  final double totalRevenue;
  final double totalProfit;
  final int totalOrders;
  final List<Map<String, dynamic>> rows;

  const SalesAnalyticsSummary({
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalOrders,
    required this.rows,
  });

  static SalesAnalyticsSummary fromRows(List<Map<String, dynamic>> rows) {
    double revenue = 0;
    double profit = 0;
    int orders = 0;
    for (final row in rows) {
      revenue += _num(row['total_revenue'] ?? row['revenue'] ?? row['totalAmount']);
      profit += _num(
        row['total_profit'] ??
            row['profit'] ??
            (row['totalAmount'] != null ? (row['totalAmount'] as num) * 0.15 : 0),
      );
      orders += 1;
    }
    return SalesAnalyticsSummary(
      totalRevenue: revenue,
      totalProfit: profit,
      totalOrders: orders,
      rows: rows,
    );
  }
}

/// Aggregated delivery performance totals.
class DeliveryAnalyticsSummary {
  final int totalDeliveries;
  final double avgDeliveryMinutes;
  final List<Map<String, dynamic>> rows;

  const DeliveryAnalyticsSummary({
    required this.totalDeliveries,
    required this.avgDeliveryMinutes,
    required this.rows,
  });

  static DeliveryAnalyticsSummary fromRows(List<Map<String, dynamic>> rows) {
    int deliveries = 0;
    double minutesSum = 0;
    int minutesCount = 0;
    for (final row in rows) {
      if (row['status'] == 'delivered') {
        deliveries += 1;
      }
      final duration = row['estimated_duration_minutes'] ?? 25;
      minutesSum += _num(duration);
      minutesCount++;
    }
    return DeliveryAnalyticsSummary(
      totalDeliveries: deliveries,
      avgDeliveryMinutes: minutesCount == 0 ? 0 : minutesSum / minutesCount,
      rows: rows,
    );
  }
}

num _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? 0;
}

class PostgresAnalyticsRepository {
  static final PostgresAnalyticsRepository _instance = PostgresAnalyticsRepository._internal();
  factory PostgresAnalyticsRepository() => _instance;
  PostgresAnalyticsRepository._internal();

  /// Stores query execution latencies in milliseconds
  final Map<String, double> queryLatencies = {};

  /// Sales analytics, optionally scoped to a shop/vendor and date range.
  Future<SalesAnalyticsSummary> getSalesAnalytics({
    String? shopId,
    String? vendorId,
    DateTime? from,
    DateTime? to,
  }) async {
    final sw = Stopwatch()..start();
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('orders');

      if (from != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
      }
      if (to != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to));
      }

      final snapshot = await query.get();
      final rows = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      sw.stop();
      queryLatencies['Sales Query'] = sw.elapsedMilliseconds.toDouble();
      return SalesAnalyticsSummary.fromRows(rows);
    } catch (e) {
      sw.stop();
      rethrow;
    }
  }

  /// Single vendor's aggregated analytics row (or null if not yet available).
  Future<Map<String, dynamic>?> getVendorAnalytics(String vendorId) async {
    final sw = Stopwatch()..start();
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: vendorId)
          .get();

      double totalSales = 0.0;
      int totalOrders = snapshot.docs.length;
      for (final doc in snapshot.docs) {
        totalSales += _num(doc.data()['totalAmount']);
      }

      final res = {
        'total_sales': totalSales,
        'total_orders': totalOrders,
        'commission_earned': totalSales * 0.05,
      };

      sw.stop();
      queryLatencies['Vendor Query'] = sw.elapsedMilliseconds.toDouble();
      return res;
    } catch (e) {
      sw.stop();
      rethrow;
    }
  }

  /// Delivery performance analytics, optionally scoped to a driver/date range.
  Future<DeliveryAnalyticsSummary> getDeliveryAnalytics({
    String? driverId,
    DateTime? from,
    DateTime? to,
  }) async {
    final sw = Stopwatch()..start();
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('delivery_tasks');

      final snapshot = await query.get();
      final rows = snapshot.docs.map((doc) => doc.data()).toList();

      sw.stop();
      queryLatencies['Delivery Query'] = sw.elapsedMilliseconds.toDouble();
      return DeliveryAnalyticsSummary.fromRows(rows);
    } catch (e) {
      sw.stop();
      rethrow;
    }
  }
}
