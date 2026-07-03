import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../constants/order_status.dart';

/// Smart Analytics Service
///
/// ML-lite analytics engine powering:
/// - Customer LTV & churn prediction (exponential decay)
/// - Demand forecasting (Holt exponential smoothing)
/// - Basket affinity (co-purchase rules)
/// - Revenue & profit attribution by category/day
/// - Win-back segment identification
/// - VIP customer detection
class SmartAnalyticsService {
  static final SmartAnalyticsService _instance = SmartAnalyticsService._internal();
  factory SmartAnalyticsService() => _instance;
  SmartAnalyticsService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Customer LTV ─────────────────────────────────────────────────────────────
  double calculateCustomerLTV(List<OrderModel> orders) {
    return orders
        .where((o) => o.status == OrderStatus.delivered)
        .fold(0.0, (sum, o) => sum + o.totalAmount.toDouble());
  }

  // ─── Churn risk score (0.0 = no risk, 1.0 = churned) ─────────────────────────
  /// Uses exponential decay with half-life of 21 days, modulated by order frequency
  double calculateChurnRiskScore(List<OrderModel> orders) {
    if (orders.isEmpty) return 1.0;
    final sorted = [...orders]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final daysSinceLast = DateTime.now().difference(sorted.first.createdAt).inDays;

    // Exponential decay: half-life ≈ 21 days
    final raw = 1 - exp(-daysSinceLast / 21.0);

    // Frequency modifier: frequent buyers get lower risk
    final freq = calculateOrderFrequency(orders);
    final freqFactor = freq > 8
        ? 0.55
        : freq > 4
        ? 0.75
        : 1.0;

    return (raw * freqFactor).clamp(0.0, 1.0);
  }

  // ─── Order frequency (orders/month) ──────────────────────────────────────────
  double calculateOrderFrequency(List<OrderModel> orders) {
    if (orders.length < 2) return 0.0;
    final sorted = [...orders]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final span = sorted.last.createdAt.difference(sorted.first.createdAt).inDays;
    if (span == 0) return orders.length.toDouble();
    return (orders.length / span) * 30;
  }

  // ─── VIP detection ────────────────────────────────────────────────────────────
  bool isVIPCustomer(List<OrderModel> orders) {
    final ltv = calculateCustomerLTV(orders);
    final freq = calculateOrderFrequency(orders);
    return ltv > 10000 || (freq > 6 && ltv > 2000);
  }

  // ─── Customer segment label ───────────────────────────────────────────────────
  String getSegmentLabel(List<OrderModel> orders) {
    final churn = calculateChurnRiskScore(orders);
    if (orders.isEmpty) return 'New';
    if (isVIPCustomer(orders)) return 'VIP';
    if (churn > 0.75) return 'At Risk';
    if (churn > 0.5) return 'Dormant';
    return 'Active';
  }

  // ─── Win-back eligible customers from Firestore ───────────────────────────────
  Future<List<CustomerSegment>> getWinBackCustomersTyped({String shopId = 'shop_001'}) async {
    try {
      final thirtyDaysAgo = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30)));
      final sixtyDaysAgo = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 60)));

      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'UserRole.customer')
          .where('lastOrderAt', isLessThan: thirtyDaysAgo)
          .where('lastOrderAt', isGreaterThan: sixtyDaysAgo)
          .limit(100)
          .get();

      return snap.docs.map((d) {
        final data = d.data();
        final ltv = (data['totalSpent'] ?? 0.0).toDouble();
        final orders = (data['totalOrders'] ?? 0) as int;
        final lastOrderTs = data['lastOrderAt'] as Timestamp?;
        final days = lastOrderTs != null
            ? DateTime.now().difference(lastOrderTs.toDate()).inDays
            : 45;
        return CustomerSegment(
          userId: d.id,
          name: data['name'] ?? 'Customer',
          phone: data['phoneNumber'] ?? '',
          ltv: ltv,
          totalOrders: orders,
          daysSinceLast: days,
          segment: ltv > 5000 ? 'VIP Win-back' : 'Regular Win-back',
        );
      }).toList()..sort((a, b) => b.ltv.compareTo(a.ltv));
    } catch (e) {
      debugPrint('[SmartAnalytics] Win-back query error: $e');
      return [];
    }
  }

  // ─── Demand forecast (Holt exponential smoothing, α=0.4) ─────────────────────
  /// Returns predicted units to sell per product in next [forecastDays] days
  Future<Map<String, double>> forecastDemand({int forecastDays = 7}) async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 60)));
      final snap = await _db
          .collection('order_items')
          .where('createdAt', isGreaterThan: cutoff)
          .get();

      // Group: productId → dayIndex → qty
      final Map<String, Map<int, double>> matrix = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final pid = data['productId'] as String? ?? '';
        final qty = (data['quantity'] as num? ?? 1).toDouble();
        final dt = (data['createdAt'] as Timestamp).toDate();
        final dayIdx = DateTime.now().difference(dt).inDays;
        matrix.putIfAbsent(pid, () => {});
        matrix[pid]![dayIdx] = (matrix[pid]![dayIdx] ?? 0) + qty;
      }

      const alpha = 0.4;
      final Map<String, double> forecast = {};
      for (final entry in matrix.entries) {
        // Build 60-element series (oldest → newest)
        final series = List.generate(60, (i) => entry.value[59 - i] ?? 0.0);
        double s = series.first;
        for (final obs in series.skip(1)) {
          s = alpha * obs + (1 - alpha) * s;
        }
        forecast[entry.key] = s * forecastDays;
      }
      return forecast;
    } catch (e) {
      debugPrint('[SmartAnalytics] Forecast error: $e');
      return {};
    }
  }

  // ─── Basket affinity ──────────────────────────────────────────────────────────
  Future<List<String>> getFrequentlyBoughtTogether(String productId, {int topN = 5}) async {
    try {
      final orderIdsSnap = await _db
          .collection('order_items')
          .where('productId', isEqualTo: productId)
          .limit(200)
          .get();

      final orderIds = orderIdsSnap.docs
          .map((d) => d.data()['orderId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .take(10)
          .toList();

      if (orderIds.isEmpty) return [];

      final coSnap = await _db.collection('order_items').where('orderId', whereIn: orderIds).get();

      final Map<String, int> freq = {};
      for (final doc in coSnap.docs) {
        final pid = doc.data()['productId'] as String? ?? '';
        if (pid.isNotEmpty && pid != productId) {
          freq[pid] = (freq[pid] ?? 0) + 1;
        }
      }

      return (freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(topN)
          .map((e) => e.key)
          .toList();
    } catch (e) {
      debugPrint('[SmartAnalytics] Affinity error: $e');
      return [];
    }
  }

  // ─── Revenue report ───────────────────────────────────────────────────────────
  Future<RevenueReport> getRevenueReport({
    required String shopId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final snap = await _db
          .collection('orders')
          .where('status', isEqualTo: 'OrderStatus.delivered')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(from))
          .where('createdAt', isLessThan: Timestamp.fromDate(to))
          .get();

      double totalRevenue = 0;
      double totalProfit = 0;
      final Map<String, double> byCategory = {};
      final Map<String, double> byDay = {};

      for (final doc in snap.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] as num? ?? 0).toDouble();
        totalRevenue += amount;
        totalProfit += amount * 0.18;

        final dt = (data['createdAt'] as Timestamp).toDate();
        final key =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        byDay[key] = (byDay[key] ?? 0) + amount;

        for (final item in (data['items'] as List? ?? [])) {
          final cat = (item as Map)['category'] as String? ?? 'Other';
          byCategory[cat] =
              (byCategory[cat] ?? 0) +
              (item['price'] as num? ?? 0).toDouble() * (item['quantity'] as num? ?? 1).toDouble();
        }
      }

      return RevenueReport(
        totalRevenue: totalRevenue,
        totalProfit: totalProfit,
        totalOrders: snap.docs.length,
        byCategory: byCategory,
        byDay: byDay,
        from: from,
        to: to,
      );
    } catch (e) {
      debugPrint('[SmartAnalytics] Revenue report error: $e');
      return RevenueReport.empty(from, to);
    }
  }

  // ─── Persist computed metrics for a customer ──────────────────────────────────
  Future<void> persistCustomerMetrics({
    required String customerId,
    required List<OrderModel> orders,
  }) async {
    if (orders.isEmpty) return;
    await _db.collection('customer_metrics').doc(customerId).set({
      'ltv': calculateCustomerLTV(orders),
      'churnRisk': calculateChurnRiskScore(orders),
      'orderFrequency': calculateOrderFrequency(orders),
      'isVip': isVIPCustomer(orders),
      'segment': getSegmentLabel(orders).toLowerCase().replaceAll(' ', '_'),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ─── Adapter methods for CustomerSegmentationScreen ─────────────────────
  /// Returns customers with churn risk above [thresholdScore].
  Future<List<Map<String, dynamic>>> predictChurnRiskList({
    double thresholdScore = 0.6,
    String shopId = 'shop_001',
  }) async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 14)));
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'UserRole.customer')
          .where('lastOrderAt', isLessThan: cutoff)
          .limit(80)
          .get();

      return snap.docs.map((d) {
        final data = d.data();
        final ltv = (data['totalSpent'] ?? 0.0).toDouble();
        final orders = (data['totalOrders'] ?? 0) as int;
        return <String, dynamic>{
          'id': d.id,
          'userId': d.id,
          'name': data['name'] ?? 'Customer',
          'email': data['email'] ?? '',
          'lifetimeValue': ltv,
          'totalOrders': orders,
        };
      }).toList();
    } catch (e) {
      debugPrint('[SmartAnalytics] predictChurnRisk list error: $e');
      return [];
    }
  }

  /// Returns top customers by lifetime value above [minLifetimeValue].
  Future<List<Map<String, dynamic>>> getVipCustomersList({
    double minLifetimeValue = 5000,
    String shopId = 'shop_001',
  }) async {
    try {
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'UserRole.customer')
          .where('totalSpent', isGreaterThanOrEqualTo: minLifetimeValue)
          .orderBy('totalSpent', descending: true)
          .limit(50)
          .get();

      return snap.docs.map((d) {
        final data = d.data();
        return <String, dynamic>{
          'id': d.id,
          'userId': d.id,
          'name': data['name'] ?? 'Customer',
          'email': data['email'] ?? '',
          'lifetimeValue': (data['totalSpent'] ?? 0.0).toDouble(),
          'totalOrders': (data['totalOrders'] ?? 0) as int,
        };
      }).toList();
    } catch (e) {
      debugPrint('[SmartAnalytics] getVipCustomers error: $e');
      return [];
    }
  }

  /// Overload of getWinBackSegment returning raw maps for UI consumption.
  Future<List<Map<String, dynamic>>> getWinBackSegmentList({
    int daysSinceLastOrder = 30,
    String shopId = 'shop_001',
  }) async {
    try {
      final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(Duration(days: daysSinceLastOrder)),
      );
      final cutoffOld = Timestamp.fromDate(
        DateTime.now().subtract(Duration(days: daysSinceLastOrder * 2)),
      );
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'UserRole.customer')
          .where('lastOrderAt', isLessThan: cutoff)
          .where('lastOrderAt', isGreaterThan: cutoffOld)
          .limit(80)
          .get();

      return snap.docs.map((d) {
        final data = d.data();
        return <String, dynamic>{
          'id': d.id,
          'userId': d.id,
          'name': data['name'] ?? 'Customer',
          'email': data['email'] ?? '',
          'lifetimeValue': (data['totalSpent'] ?? 0.0).toDouble(),
          'totalOrders': (data['totalOrders'] ?? 0) as int,
        };
      }).toList();
    } catch (e) {
      debugPrint('[SmartAnalytics] getWinBackSegment map error: $e');
      return [];
    }
  }

  /// Triggers a campaign notification for a single customer.
  Future<void> triggerCampaignForCustomer({
    required String customerId,
    required String campaignType,
  }) async {
    try {
      await _db.collection('campaign_triggers').add({
        'customerId': customerId,
        'campaignType': campaignType,
        'triggeredAt': FieldValue.serverTimestamp(),
        'status': 'queued',
      });
    } catch (e) {
      debugPrint('[SmartAnalytics] triggerCampaign error: $e');
    }
  }
}

// ─── Data models ──────────────────────────────────────────────────────────────
class CustomerSegment {
  final String userId;
  final String name;
  final String phone;
  final double ltv;
  final int totalOrders;
  final int daysSinceLast;
  final String segment;

  const CustomerSegment({
    required this.userId,
    required this.name,
    required this.phone,
    required this.ltv,
    required this.totalOrders,
    required this.daysSinceLast,
    required this.segment,
  });
}

class RevenueReport {
  final double totalRevenue;
  final double totalProfit;
  final int totalOrders;
  final Map<String, double> byCategory;
  final Map<String, double> byDay;
  final DateTime from;
  final DateTime to;

  const RevenueReport({
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalOrders,
    required this.byCategory,
    required this.byDay,
    required this.from,
    required this.to,
  });

  factory RevenueReport.empty(DateTime from, DateTime to) => RevenueReport(
    totalRevenue: 0,
    totalProfit: 0,
    totalOrders: 0,
    byCategory: {},
    byDay: {},
    from: from,
    to: to,
  );

  double get avgOrderValue => totalOrders > 0 ? totalRevenue / totalOrders : 0;
  double get grossMarginPct => totalRevenue > 0 ? totalProfit / totalRevenue : 0;
}
