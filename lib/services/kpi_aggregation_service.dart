import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// KPI Aggregation Service
///
/// Periodic batch processing engine to compile sales, revenue, inventory,
/// delivery, and payment statistics from transactional logs into physical reporting tables.
class KPIAggregationService {
  static final KPIAggregationService _instance = KPIAggregationService._internal();
  factory KPIAggregationService() => _instance;
  KPIAggregationService._internal();

  SupabaseClient? _customClient;
  SupabaseClient get _client => _customClient ?? Supabase.instance.client;
  set client(SupabaseClient c) => _customClient = c;

  FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  set firestore(FirebaseFirestore f) => _customFirestore = f;

  /// Aggregates sales and revenue P&L records for a specified range
  Future<bool> aggregateSalesAndRevenue(DateTime from, DateTime to) async {
    try {
      debugPrint('[KPIAggregation] Starting Sales and Revenue aggregation...');
      
      // Query raw orders within range from Postgres (workload isolated reads)
      final ordersResponse = await _client
          .from('orders')
          .select('order_id, shop_id, subtotal, discount, delivery_fee, final_amount, order_status, created_at')
          .gte('created_at', from.toIso8601String())
          .lte('created_at', to.toIso8601String());

      final List<dynamic> orders = ordersResponse as List<dynamic>;
      if (orders.isEmpty) {
        debugPrint('[KPIAggregation] No orders found in the range.');
        return true;
      }

      // Group metrics by day, shop, and vendor (if vendor info is present in order_items)
      final Map<String, Map<String, dynamic>> salesRollups = {};
      double totalGrossRevenue = 0.0;
      double totalRefunds = 0.0;
      double totalDeliveryFees = 0.0;

      for (var o in orders) {
        final double finalAmt = (o['final_amount'] as num?)?.toDouble() ?? 0.0;
        final double deliveryFee = (o['delivery_fee'] as num?)?.toDouble() ?? 0.0;
        final String status = o['order_status'] ?? 'pending';
        final String shopId = o['shop_id'] ?? 'global';
        final String dateStr = o['created_at'].toString().split('T').first;
        
        if (status == 'delivered') {
          totalGrossRevenue += finalAmt;
          totalDeliveryFees += deliveryFee;
        } else if (status == 'cancelled' || status == 'returned') {
          totalRefunds += finalAmt;
        }

        final key = '${dateStr}_$shopId';
        salesRollups.putIfAbsent(key, () => {
          'metric_id': key,
          'shop_id': shopId,
          'vendor_id': '00000000-0000-0000-0000-000000000000',
          'order_count': 0,
          'delivered_count': 0,
          'cancelled_count': 0,
          'revenue': 0.0,
          'avg_order_value': 0.0,
          'period': 'daily',
          'created_at': DateTime.now().toIso8601String()
        });

        final rollup = salesRollups[key]!;
        rollup['order_count'] = (rollup['order_count'] as int) + 1;
        if (status == 'delivered') {
          rollup['delivered_count'] = (rollup['delivered_count'] as int) + 1;
          rollup['revenue'] = (rollup['revenue'] as double) + finalAmt;
        } else if (status == 'cancelled') {
          rollup['cancelled_count'] = (rollup['cancelled_count'] as int) + 1;
        }
      }

      // Finalize averages and upsert sales_analytics
      for (var rollup in salesRollups.values) {
        final int delCount = rollup['delivered_count'] as int;
        final double rev = rollup['revenue'] as double;
        rollup['avg_order_value'] = delCount > 0 ? rev / delCount : 0.0;
        await _client.from('sales_analytics').upsert(rollup);
      }

      // Upsert revenue metrics
      final double netRevenue = totalGrossRevenue - totalRefunds;
      final double cogs = netRevenue * 0.68; // fallback COGS estimation
      final double grossProfit = netRevenue - cogs;

      final revenueMetrics = {
        'gross_revenue': totalGrossRevenue,
        'net_revenue': netRevenue,
        'refunds': totalRefunds,
        'delivery_fees': totalDeliveryFees,
        'cogs': cogs,
        'gross_profit': grossProfit
      };

      for (var entry in revenueMetrics.entries) {
        final key = 'daily_${entry.key}_${DateFormat('yyyyMMdd').format(to)}';
        await _client.from('revenue_analytics').upsert({
          'metric_id': key,
          'metric_type': entry.key,
          'metric_value': entry.value,
          'period': 'daily',
          'created_at': DateTime.now().toIso8601String()
        });
      }

      debugPrint('[KPIAggregation] Sales and Revenue aggregation completed successfully.');
      return true;
    } catch (e) {
      debugPrint('[KPIAggregation] Error in Sales and Revenue aggregation: $e');
      return false;
    }
  }

  /// Aggregates inventory health stats: stock levels, low stocks, out of stocks
  Future<bool> aggregateInventoryHealth() async {
    try {
      debugPrint('[KPIAggregation] Starting Inventory Health aggregation...');

      // Fetch all products from Postgres
      final productsResponse = await _client
          .from('products')
          .select('id, stock, price');
      
      final List<dynamic> products = productsResponse as List<dynamic>;
      int outOfStock = 0;
      int lowStock = 0;
      double deadStockValue = 0.0;

      for (var p in products) {
        final int stock = (p['stock'] as num?)?.toInt() ?? 0;
        final double price = (p['price'] as num?)?.toDouble() ?? 0.0;

        if (stock == 0) {
          outOfStock++;
        } else if (stock < 5) {
          lowStock++;
        }
        
        // Assume items unsold and in stock represent holding value
        if (stock > 50) {
          deadStockValue += stock * price * 0.4; // 40% value tied in dead stock
        }
      }

      final metrics = {
        'out_of_stock_count': outOfStock.toDouble(),
        'low_stock_count': lowStock.toDouble(),
        'dead_stock_value': deadStockValue,
        'stock_turnover': 8.5 // Simulated turnover multiplier
      };

      for (var entry in metrics.entries) {
        final key = 'daily_inv_${entry.key}_${DateFormat('yyyyMMdd').format(DateTime.now())}';
        await _client.from('inventory_analytics').upsert({
          'metric_id': key,
          'metric_type': entry.key,
          'metric_value': entry.value,
          'period': 'daily',
          'created_at': DateTime.now().toIso8601String()
        });
      }

      debugPrint('[KPIAggregation] Inventory Health aggregation completed successfully.');
      return true;
    } catch (e) {
      debugPrint('[KPIAggregation] Error in Inventory Health aggregation: $e');
      return false;
    }
  }

  /// Aggregates delivery performance (rider efficiencies and route status)
  Future<bool> aggregateDeliveryPerformance(DateTime from, DateTime to) async {
    try {
      debugPrint('[KPIAggregation] Starting Delivery Performance aggregation...');

      // Query employee tasks (delivery types) from Postgres
      final tasksResponse = await _client
          .from('employee_tasks')
          .select('assigned_rider_id, status, created_at, completed_at, payout_amount')
          .eq('type', 'delivery')
          .gte('created_at', from.toIso8601String())
          .lte('created_at', to.toIso8601String());

      final List<dynamic> tasks = tasksResponse as List<dynamic>;
      final Map<String, Map<String, dynamic>> riderStats = {};

      for (var t in tasks) {
        final String riderId = t['assigned_rider_id']?.toString() ?? 'unknown_rider';
        final String status = t['status'] ?? 'failed';
        final DateTime created = DateTime.parse(t['created_at'].toString());
        final DateTime? completed = t['completed_at'] != null ? DateTime.parse(t['completed_at'].toString()) : null;

        riderStats.putIfAbsent(riderId, () => {
          'assigned': 0,
          'delivered': 0,
          'cancelled': 0,
          'duration_sum_mins': 0.0,
          'completed_count': 0
        });

        final stats = riderStats[riderId]!;
        stats['assigned'] = (stats['assigned'] as int) + 1;
        if (status == 'completed') {
          stats['delivered'] = (stats['delivered'] as int) + 1;
          if (completed != null) {
            final diff = completed.difference(created).inMinutes;
            stats['duration_sum_mins'] = (stats['duration_sum_mins'] as double) + diff;
            stats['completed_count'] = (stats['completed_count'] as int) + 1;
          }
        } else if (status == 'failed') {
          stats['cancelled'] = (stats['cancelled'] as int) + 1;
        }
      }

      for (var entry in riderStats.entries) {
        final stats = entry.value;
        final String riderId = entry.key;
        final int compCount = stats['completed_count'] as int;
        final double avgMins = compCount > 0 ? (stats['duration_sum_mins'] as double) / compCount : 0.0;

        final key = 'daily_del_${riderId}_${DateFormat('yyyyMMdd').format(to)}';
        await _client.from('delivery_analytics').upsert({
          'metric_id': key,
          'driver_id': riderId,
          'assigned_count': stats['assigned'],
          'delivered_count': stats['delivered'],
          'cancelled_count': stats['cancelled'],
          'avg_delivery_minutes': avgMins,
          'period': 'daily',
          'created_at': DateTime.now().toIso8601String()
        });
      }

      debugPrint('[KPIAggregation] Delivery Performance aggregation completed successfully.');
      return true;
    } catch (e) {
      debugPrint('[KPIAggregation] Error in Delivery Performance aggregation: $e');
      return false;
    }
  }

  /// Aggregates payment processing parameters (success rates, wallet ratios)
  Future<bool> aggregatePaymentStats(DateTime from, DateTime to) async {
    try {
      debugPrint('[KPIAggregation] Starting Payment stats aggregation...');

      // Query order payments from Postgres
      final paymentsResponse = await _client
          .from('order_payments')
          .select('payment_method, payment_status, amount')
          .gte('created_at', from.toIso8601String())
          .lte('created_at', to.toIso8601String());

      final List<dynamic> payments = paymentsResponse as List<dynamic>;
      if (payments.isEmpty) return true;

      int total = 0;
      int success = 0;
      int refunds = 0;
      int codCount = 0;
      int walletCount = 0;

      for (var p in payments) {
        total++;
        final String status = p['payment_status'] ?? 'FAILED';
        final String method = p['payment_method'] ?? 'COD';

        if (status == 'SUCCESS') {
          success++;
        } else if (status == 'REFUNDED') {
          refunds++;
        }

        if (method == 'COD') codCount++;
        if (method == 'WALLET') walletCount++;
      }

      final double successRate = total > 0 ? (success / total) * 100 : 100.0;
      final double codRatio = total > 0 ? (codCount / total) * 100 : 0.0;
      final double refundRate = total > 0 ? (refunds / total) * 100 : 0.0;
      final double walletUsageRate = total > 0 ? (walletCount / total) * 100 : 0.0;

      final metrics = {
        'success_rate': successRate,
        'cod_ratio': codRatio,
        'refund_rate': refundRate,
        'wallet_usage_rate': walletUsageRate
      };

      for (var entry in metrics.entries) {
        final key = 'daily_pay_${entry.key}_${DateFormat('yyyyMMdd').format(to)}';
        await _client.from('payment_analytics').upsert({
          'metric_id': key,
          'metric_type': entry.key,
          'metric_value': entry.value,
          'period': 'daily',
          'created_at': DateTime.now().toIso8601String()
        });
      }

      debugPrint('[KPIAggregation] Payment stats aggregation completed successfully.');
      return true;
    } catch (e) {
      debugPrint('[KPIAggregation] Error in Payment stats aggregation: $e');
      return false;
    }
  }

  /// Runs the full aggregation pipeline and persists a Firestore snapshot
  Future<void> runFullAggregation() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final s1 = await aggregateSalesAndRevenue(from, to);
    final s2 = await aggregateInventoryHealth();
    final s3 = await aggregateDeliveryPerformance(from, to);
    final s4 = await aggregatePaymentStats(from, to);

    if (s1 && s2 && s3 && s4) {
      // Create a consolidated snapshot for Firestore
      await _firestore.collection('analytics_snapshots').doc('latest').set({
        'aggregatedAt': FieldValue.serverTimestamp(),
        'dateRangeFrom': Timestamp.fromDate(from),
        'dateRangeTo': Timestamp.fromDate(to),
        'status': 'success',
      }, SetOptions(merge: true));
      debugPrint('[KPIAggregation] Full batch aggregation ran successfully.');
    } else {
      debugPrint('[KPIAggregation] Full batch aggregation encountered some errors.');
    }
  }
}
