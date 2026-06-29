import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../models/order_model.dart';
import '../models/payment_method.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../utils/pdf_theme.dart';
import '../constants/order_status.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Business Intelligence Service
///
/// The analytics brain of the Fufaji Commerce OS. Turns raw orders + product
/// cost data into three executive-grade reports:
///   • [FinancialReport]  — gross/net revenue, refunds, fees, real COGS margin
///   • [BusinessReport]   — orders funnel, retention, AOV, growth, CLV, churn
///   • [FranchiseReport]  — branch-by-branch comparison & ranking
///
/// All heavy logic is pure (operates on in-memory lists) so it is unit-testable
/// and reusable from screens, scheduled jobs, or Cloud Functions mirrors.
/// Firestore access is isolated to [loadDashboard] / [_fetchOrders].
/// ─────────────────────────────────────────────────────────────────────────────
class BusinessIntelligenceService {
  static final BusinessIntelligenceService _instance =
      BusinessIntelligenceService._internal();
  factory BusinessIntelligenceService() => _instance;
  BusinessIntelligenceService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ProductService _productService = ProductService();

  /// Realized revenue statuses — money the business has actually earned.
  static const Set<OrderStatus> realizedStatuses = {OrderStatus.delivered};

  /// Statuses that represent money flowing back out.
  static const Set<OrderStatus> refundStatuses = {
    OrderStatus.returned,
    OrderStatus.refunded,
  };

  /// Fallback cost ratio when a product has no [ProductModel.costPrice] set.
  static const double _fallbackCostRatio = 0.68;

  // ───────────────────────────────────────────────────────────────────────────
  // Public entry point
  // ───────────────────────────────────────────────────────────────────────────

  /// Loads everything the BI dashboards need for [from]..[to].
  ///
  /// Also fetches the immediately-preceding equal-length window so we can show
  /// period-over-period growth, and the product catalog for true COGS margins
  /// and category attribution.
  Future<BusinessIntelligenceData> loadDashboard({
    required String shopId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final client = Supabase.instance.client;
      // Fetch pre-aggregated revenue analytics from physical Postgres reporting tables
      final revRes = await client
          .from('revenue_analytics')
          .select('metric_type, metric_value')
          .gte('created_at', from.toIso8601String())
          .lte('created_at', to.toIso8601String());

      final List<dynamic> revRows = revRes as List<dynamic>;
      if (revRows.isNotEmpty) {
        debugPrint('[BI] Postgres Analytics reporting data found. Loading from reporting tables.');

        double grossRev = 0;
        double netRev = 0;
        double refundsVal = 0;
        double delFees = 0;
        double tipsVal = 0;
        double cogsVal = 0;
        double profit = 0;

        for (var r in revRows) {
          final type = r['metric_type'] as String?;
          final val = (r['metric_value'] as num?)?.toDouble() ?? 0.0;
          if (type == 'gross_revenue') grossRev = val;
          if (type == 'net_revenue') netRev = val;
          if (type == 'refunds') refundsVal = val;
          if (type == 'delivery_fees') delFees = val;
          if (type == 'tips') tipsVal = val;
          if (type == 'cogs') cogsVal = val;
          if (type == 'gross_profit') profit = val;
        }

        // Construct reports using pre-aggregated data
        final financial = FinancialReport(
          grossRevenue: grossRev,
          netRevenue: netRev,
          refunds: refundsVal,
          refundRate: grossRev > 0 ? (refundsVal / grossRev) * 100 : 0.0,
          deliveryFeeRevenue: delFees,
          tips: tipsVal,
          walletUsage: 0.0,
          discountsGiven: 0.0,
          taxCollected: 0.0,
          packagingFees: 0.0,
          cogs: cogsVal,
          grossProfit: profit,
          profitMargin: netRev > 0 ? (profit / netRev) * 100 : 0.0,
          revenueGrowth: 0.0,
          revenueByPaymentMethod: {},
          revenueByCategory: {},
          dailyRevenue: [],
        );

        // Fetch sales analytics for business summary
        final salesRes = await client
            .from('sales_analytics')
            .select('order_count, delivered_count, cancelled_count')
            .gte('created_at', from.toIso8601String())
            .lte('created_at', to.toIso8601String());

        final List<dynamic> salesRows = salesRes as List<dynamic>;
        int totalOrders = 0;
        int deliveredOrders = 0;
        int cancelledOrders = 0;
        for (var s in salesRows) {
          totalOrders += (s['order_count'] as num?)?.toInt() ?? 0;
          deliveredOrders += (s['delivered_count'] as num?)?.toInt() ?? 0;
          cancelledOrders += (s['cancelled_count'] as num?)?.toInt() ?? 0;
        }

        final business = BusinessReport(
          ordersPlaced: totalOrders - deliveredOrders - cancelledOrders,
          ordersPacked: 0,
          ordersShipped: 0,
          ordersDelivered: deliveredOrders,
          ordersCancelled: cancelledOrders,
          ordersReturned: 0,
          totalOrders: totalOrders,
          newCustomers: 0,
          returningCustomers: 0,
          totalCustomers: 0,
          retentionRate: 0.0,
          churnRate: 0.0,
          avgOrderValue: deliveredOrders > 0 ? netRev / deliveredOrders : 0.0,
          avgCustomerLtv: 0.0,
          orderGrowth: 0.0,
          clvDistribution: {},
          aovTrend: [],
        );

        return BusinessIntelligenceData(
          from: from,
          to: to,
          financial: financial,
          business: business,
          franchise: FranchiseReport.empty(),
          generatedAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('[BI] Postgres Analytics load error, falling back to Firestore: $e');
    }

    final span = to.difference(from);
    final prevFrom = from.subtract(span);
    final prevTo = from;

    // Kick off all three reads concurrently, then await individually so the
    // static types stay precise (no heterogeneous Future.wait casts).
    final currentFuture = _fetchOrders(shopId: shopId, from: from, to: to);
    final previousFuture =
        _fetchOrders(shopId: shopId, from: prevFrom, to: prevTo);
    final productsFuture = _fetchProducts(shopId);

    final current = await currentFuture;
    final previous = await previousFuture;
    final products = await productsFuture;

    final costByProduct = <String, double?>{};
    final categoryByProduct = <String, String>{};
    for (final p in products) {
      costByProduct[p.id] = p.costPrice;
      categoryByProduct[p.id] =
          p.category.isNotEmpty ? p.category : p.categoryId;
    }

    return BusinessIntelligenceData(
      from: from,
      to: to,
      financial: computeFinancial(
        current,
        previous,
        costByProduct: costByProduct,
        categoryByProduct: categoryByProduct,
      ),
      business: computeBusiness(current, previous),
      franchise: computeFranchise(current),
      generatedAt: DateTime.now(),
    );
  }


  // ───────────────────────────────────────────────────────────────────────────
  // FINANCIAL
  // ───────────────────────────────────────────────────────────────────────────

  FinancialReport computeFinancial(
    List<OrderModel> current,
    List<OrderModel> previous, {
    Map<String, double?> costByProduct = const {},
    Map<String, String> categoryByProduct = const {},
  }) {
    double grossRevenue = 0; // realized (delivered)
    double refunds = 0;
    double deliveryFeeRevenue = 0;
    double tips = 0;
    double walletUsage = 0;
    double discountsGiven = 0;
    double taxCollected = 0;
    double packagingFees = 0;
    double cogs = 0;

    final byPaymentMethod = <String, double>{};
    final byCategory = <String, double>{};
    final dailyRevenue = <String, double>{};

    for (final o in current) {
      if (refundStatuses.contains(o.status)) {
        refunds += o.totalAmount.toDouble();
        continue;
      }
      if (!realizedStatuses.contains(o.status)) continue;

      grossRevenue += o.totalAmount.toDouble();
      deliveryFeeRevenue += o.deliveryCharge.toDouble() + (o.deliveryFee?.toDouble() ?? 0.0);
      tips += o.tipAmount.toDouble();
      walletUsage += o.walletAmountUsed.toDouble();
      discountsGiven += o.discount.toDouble();
      taxCollected += o.tax.toDouble();
      packagingFees += o.packagingFee.toDouble();

      final pm = o.paymentMethod.displayName;
      byPaymentMethod[pm] = (byPaymentMethod[pm] ?? 0) + o.totalAmount.toDouble();

      final dayKey = DateFormat('yyyy-MM-dd').format(o.createdAt);
      dailyRevenue[dayKey] = (dailyRevenue[dayKey] ?? 0) + o.totalAmount.toDouble();

      for (final item in o.items) {
        final lineRevenue = item.price * item.quantity;
        // Category attribution from catalog (OrderItem carries no category).
        final cat = categoryByProduct[item.productId] ?? 'Other';
        byCategory[cat] = (byCategory[cat] ?? 0) + lineRevenue.toDouble();

        // True COGS when costPrice known, else conservative fallback.
        final unitCost = costByProduct[item.productId];
        cogs += unitCost != null
            ? unitCost * item.quantity
            : lineRevenue.toDouble() * _fallbackCostRatio;
      }
    }

    final netRevenue = grossRevenue - refunds;
    final grossProfit = netRevenue - cogs;
    final profitMargin = netRevenue > 0 ? (grossProfit / netRevenue) * 100 : 0.0;
    final refundRate =
        grossRevenue > 0 ? (refunds / grossRevenue) * 100 : 0.0;

    // Previous-period net revenue for growth.
    double prevNet = 0;
    for (final o in previous) {
      if (refundStatuses.contains(o.status)) {
        prevNet -= o.totalAmount.toDouble();
      } else if (realizedStatuses.contains(o.status)) {
        prevNet += o.totalAmount.toDouble();
      }
    }
    final revenueGrowth = _growthPct(netRevenue, prevNet);

    return FinancialReport(
      grossRevenue: grossRevenue,
      netRevenue: netRevenue,
      refunds: refunds,
      refundRate: refundRate,
      deliveryFeeRevenue: deliveryFeeRevenue,
      tips: tips,
      walletUsage: walletUsage,
      discountsGiven: discountsGiven,
      taxCollected: taxCollected,
      packagingFees: packagingFees,
      cogs: cogs,
      grossProfit: grossProfit,
      profitMargin: profitMargin.toDouble(),
      revenueGrowth: revenueGrowth,
      revenueByPaymentMethod: byPaymentMethod,
      revenueByCategory: byCategory,
      dailyRevenue: _sortedDailySeries(dailyRevenue),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BUSINESS (KPIs)
  // ───────────────────────────────────────────────────────────────────────────

  BusinessReport computeBusiness(
    List<OrderModel> current,
    List<OrderModel> previous,
  ) {
    int placed = 0,
        packed = 0,
        shipped = 0,
        delivered = 0,
        cancelled = 0,
        returned = 0;

    final spendByCustomer = <String, double>{};
    final ordersByCustomer = <String, int>{};
    final firstSeen = <String, DateTime>{};
    final lastSeen = <String, DateTime>{};
    final dailyAov = <String, List<double>>{};

    double realizedRevenue = 0;

    for (final o in current) {
      switch (o.status) {
        case OrderStatus.pending:
        case OrderStatus.confirmed:
        case OrderStatus.processing:
          placed++;
          break;
        case OrderStatus.packed:
          packed++;
          break;
        case OrderStatus.shipped:
        case OrderStatus.outForDelivery:
          shipped++;
          break;
        case OrderStatus.delivered:
        case OrderStatus.completed:
          delivered++;
          break;
        case OrderStatus.cancelled:
          cancelled++;
          break;
        case OrderStatus.returned:
        case OrderStatus.refunded:
          returned++;
          break;
      }

      ordersByCustomer[o.customerId] =
          (ordersByCustomer[o.customerId] ?? 0) + 1;

      final seen = firstSeen[o.customerId];
      if (seen == null || o.createdAt.isBefore(seen)) {
        firstSeen[o.customerId] = o.createdAt;
      }
      final last = lastSeen[o.customerId];
      if (last == null || o.createdAt.isAfter(last)) {
        lastSeen[o.customerId] = o.createdAt;
      }

      if (o.status == OrderStatus.delivered) {
        spendByCustomer[o.customerId] =
            (spendByCustomer[o.customerId] ?? 0) + o.totalAmount.toDouble();
        realizedRevenue += o.totalAmount.toDouble();
        final dayKey = DateFormat('yyyy-MM-dd').format(o.createdAt);
        dailyAov.putIfAbsent(dayKey, () => []).add(o.totalAmount.toDouble());
      }
    }

    final totalCustomers = ordersByCustomer.length;
    final returningCustomers =
        ordersByCustomer.values.where((c) => c > 1).length;
    final newCustomers = totalCustomers - returningCustomers;
    final retentionRate =
        totalCustomers > 0 ? (returningCustomers / totalCustomers) * 100 : 0.0;

    final aov = delivered > 0 ? realizedRevenue / delivered : 0.0;
    final avgClv = totalCustomers > 0
        ? spendByCustomer.values.fold(0.0, (a, b) => a + b) / totalCustomers
        : 0.0;

    // Churn: share of customers whose latest order is > 30 days old.
    final now = DateTime.now();
    final churned = lastSeen.values
        .where((d) => now.difference(d).inDays > 30)
        .length;
    final churnRate =
        totalCustomers > 0 ? (churned / totalCustomers) * 100 : 0.0;

    // Growth in order count vs previous period.
    final prevOrders = previous.length;
    final orderGrowth = _growthPct(current.length.toDouble(), prevOrders.toDouble());

    // CLV distribution buckets.
    final clvBuckets = <String, int>{
      '₹0–500': 0,
      '₹500–2k': 0,
      '₹2k–5k': 0,
      '₹5k–10k': 0,
      '₹10k+': 0,
    };
    for (final v in spendByCustomer.values) {
      if (v < 500) {
        clvBuckets['₹0–500'] = clvBuckets['₹0–500']! + 1;
      } else if (v < 2000) {
        clvBuckets['₹500–2k'] = clvBuckets['₹500–2k']! + 1;
      } else if (v < 5000) {
        clvBuckets['₹2k–5k'] = clvBuckets['₹2k–5k']! + 1;
      } else if (v < 10000) {
        clvBuckets['₹5k–10k'] = clvBuckets['₹5k–10k']! + 1;
      } else {
        clvBuckets['₹10k+'] = clvBuckets['₹10k+']! + 1;
      }
    }

    final aovTrend = <DailyPoint>[];
    final sortedDays = dailyAov.keys.toList()..sort();
    for (final k in sortedDays) {
      final list = dailyAov[k]!;
      final avg = list.fold(0.0, (a, b) => a + b) / list.length;
      aovTrend.add(DailyPoint(k, avg));
    }

    return BusinessReport(
      ordersPlaced: placed,
      ordersPacked: packed,
      ordersShipped: shipped,
      ordersDelivered: delivered,
      ordersCancelled: cancelled,
      ordersReturned: returned,
      totalOrders: current.length,
      newCustomers: newCustomers,
      returningCustomers: returningCustomers,
      totalCustomers: totalCustomers,
      retentionRate: retentionRate,
      churnRate: churnRate,
      avgOrderValue: aov,
      avgCustomerLtv: avgClv,
      orderGrowth: orderGrowth,
      clvDistribution: clvBuckets,
      aovTrend: aovTrend,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // FRANCHISE (multi-branch)
  // ───────────────────────────────────────────────────────────────────────────

  FranchiseReport computeFranchise(List<OrderModel> current) {
    final byBranch = <String, _BranchAccumulator>{};

    for (final o in current) {
      final id = (o.shopId == null || o.shopId!.isEmpty) ? 'unassigned' : o.shopId!;
      final acc = byBranch.putIfAbsent(
        id,
        () => _BranchAccumulator(id, o.shopName ?? id),
      );
      acc.orders++;
      if (o.status == OrderStatus.delivered) {
        acc.revenue += o.totalAmount.toDouble();
        acc.deliveredOrders++;
      }
      if (refundStatuses.contains(o.status)) acc.refunds++;
      if (o.rating != null) {
        acc.ratingSum += o.rating!;
        acc.ratingCount++;
      }
    }

    final branches = byBranch.values.map((a) {
      final aov = a.deliveredOrders > 0 ? a.revenue / a.deliveredOrders : 0.0;
      final rating = a.ratingCount > 0 ? a.ratingSum / a.ratingCount : 0.0;
      // Estimated profit at 32% blended margin (branch P&L proxy).
      final estProfit = a.revenue * 0.32;
      return BranchPerformance(
        branchId: a.id,
        branchName: a.name,
        orders: a.orders,
        deliveredOrders: a.deliveredOrders,
        revenue: a.revenue,
        avgOrderValue: aov,
        avgRating: rating,
        refundCount: a.refunds,
        estimatedProfit: estProfit,
      );
    }).toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    return FranchiseReport(branches: branches);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PDF EXPORT
  // ───────────────────────────────────────────────────────────────────────────

  Future<Uint8List> buildPdfReport(BusinessIntelligenceData data) async {
    final doc = pw.Document();
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dfmt = DateFormat('dd MMM yyyy');
    final f = data.financial;
    final b = data.business;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Fufaji — Business Intelligence Report',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(
                    '${dfmt.format(data.from)}  →  ${dfmt.format(data.to)}',
                    style: const pw.TextStyle(
                        fontSize: 11, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Financial Summary',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _pdfKvTable(money, {
            'Gross Revenue': f.grossRevenue,
            'Refunds': -f.refunds,
            'Net Revenue': f.netRevenue,
            'COGS': -f.cogs,
            'Gross Profit': f.grossProfit,
            'Delivery Fees': f.deliveryFeeRevenue,
            'Tips Collected': f.tips,
            'Wallet Usage': f.walletUsage,
            'Discounts Given': -f.discountsGiven,
            'Tax Collected': f.taxCollected,
          }),
          pw.SizedBox(height: 6),
          pw.Text(
              'Profit Margin: ${f.profitMargin.toStringAsFixed(1)}%   •   '
              'Revenue Growth: ${f.revenueGrowth.toStringAsFixed(1)}%   •   '
              'Refund Rate: ${f.refundRate.toStringAsFixed(1)}%',
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 18),
          pw.Text('Business KPIs',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['Metric', 'Value'],
            data: [
              ['Total Orders', '${b.totalOrders}'],
              ['Delivered', '${b.ordersDelivered}'],
              ['Cancelled', '${b.ordersCancelled}'],
              ['Returned / Refunded', '${b.ordersReturned}'],
              ['Total Customers', '${b.totalCustomers}'],
              ['New Customers', '${b.newCustomers}'],
              ['Returning Customers', '${b.returningCustomers}'],
              ['Retention Rate', '${b.retentionRate.toStringAsFixed(1)}%'],
              ['Churn Rate', '${b.churnRate.toStringAsFixed(1)}%'],
              ['Avg Order Value', money.format(b.avgOrderValue)],
              ['Avg Customer LTV', money.format(b.avgCustomerLtv)],
              ['Order Growth', '${b.orderGrowth.toStringAsFixed(1)}%'],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration:
                const pw.BoxDecoration(color: PdfAppTheme.warning100),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
          if (data.franchise.branches.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text('Branch Performance',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Branch', 'Orders', 'Revenue', 'AOV', 'Rating'],
              data: data.franchise.branches
                  .map((br) => [
                        br.branchName,
                        '${br.orders}',
                        money.format(br.revenue),
                        money.format(br.avgOrderValue),
                        br.avgRating.toStringAsFixed(1),
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfAppTheme.warning100),
              cellStyle: const pw.TextStyle(fontSize: 10),
            ),
          ],
          pw.SizedBox(height: 24),
          pw.Text(
              'Generated ${DateFormat('dd MMM yyyy, HH:mm').format(data.generatedAt)} by Fufaji Commerce OS',
              style:
                  const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );

    return doc.save();
  }

  /// Opens the OS share / print sheet with the generated PDF.
  Future<void> exportAndShare(BusinessIntelligenceData data) async {
    final bytes = await buildPdfReport(data);
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'fufaji_bi_${DateFormat('yyyyMMdd').format(data.from)}_${DateFormat('yyyyMMdd').format(data.to)}.pdf',
    );
  }

  static pw.Widget _pdfKvTable(NumberFormat money, Map<String, double> rows) {
    return pw.Table.fromTextArray(
      border: null,
      headers: ['Line Item', 'Amount'],
      data: rows.entries
          .map((e) => [e.key, money.format(e.value)])
          .toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignments: {1: pw.Alignment.centerRight},
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Firestore + helpers
  // ───────────────────────────────────────────────────────────────────────────

  Future<List<OrderModel>> _fetchOrders({
    required String shopId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to));
      // Scope to a shop only when provided; admins pass '' for all branches.
      if (shopId.isNotEmpty) {
        query = query.where('shopId', isEqualTo: shopId);
      }
      final snap = await query.get();
      return snap.docs
          .map((d) => OrderModel.fromMap({'id': d.id, ...d.data()}))
          .toList();
    } catch (e) {
      debugPrint('[BI] _fetchOrders error: $e');
      return [];
    }
  }

  Future<List<ProductModel>> _fetchProducts(String shopId) async {
    try {
      if (shopId.isEmpty) return await _productService.getProducts();
      return await _productService.getProductsByShopId(shopId);
    } catch (e) {
      debugPrint('[BI] _fetchProducts error: $e');
      return [];
    }
  }

  static double _growthPct(double current, double previous) {
    if (previous <= 0) return current > 0 ? 100.0 : 0.0;
    return ((current - previous) / previous) * 100;
  }

  static List<DailyPoint> _sortedDailySeries(Map<String, double> daily) {
    final keys = daily.keys.toList()..sort();
    return keys.map((k) => DailyPoint(k, daily[k]!)).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class BusinessIntelligenceData {
  final DateTime from;
  final DateTime to;
  final FinancialReport financial;
  final BusinessReport business;
  final FranchiseReport franchise;
  final DateTime generatedAt;

  const BusinessIntelligenceData({
    required this.from,
    required this.to,
    required this.financial,
    required this.business,
    required this.franchise,
    required this.generatedAt,
  });
}

class DailyPoint {
  final String day; // yyyy-MM-dd
  final double value;
  const DailyPoint(this.day, this.value);
}

class FinancialReport {
  final double grossRevenue;
  final double netRevenue;
  final double refunds;
  final double refundRate;
  final double deliveryFeeRevenue;
  final double tips;
  final double walletUsage;
  final double discountsGiven;
  final double taxCollected;
  final double packagingFees;
  final double cogs;
  final double grossProfit;
  final double profitMargin;
  final double revenueGrowth;
  final Map<String, double> revenueByPaymentMethod;
  final Map<String, double> revenueByCategory;
  final List<DailyPoint> dailyRevenue;

  const FinancialReport({
    required this.grossRevenue,
    required this.netRevenue,
    required this.refunds,
    required this.refundRate,
    required this.deliveryFeeRevenue,
    required this.tips,
    required this.walletUsage,
    required this.discountsGiven,
    required this.taxCollected,
    required this.packagingFees,
    required this.cogs,
    required this.grossProfit,
    required this.profitMargin,
    required this.revenueGrowth,
    required this.revenueByPaymentMethod,
    required this.revenueByCategory,
    required this.dailyRevenue,
  });

  factory FinancialReport.empty() => const FinancialReport(
        grossRevenue: 0,
        netRevenue: 0,
        refunds: 0,
        refundRate: 0,
        deliveryFeeRevenue: 0,
        tips: 0,
        walletUsage: 0,
        discountsGiven: 0,
        taxCollected: 0,
        packagingFees: 0,
        cogs: 0,
        grossProfit: 0,
        profitMargin: 0,
        revenueGrowth: 0,
        revenueByPaymentMethod: {},
        revenueByCategory: {},
        dailyRevenue: [],
      );
}

class BusinessReport {
  final int ordersPlaced;
  final int ordersPacked;
  final int ordersShipped;
  final int ordersDelivered;
  final int ordersCancelled;
  final int ordersReturned;
  final int totalOrders;
  final int newCustomers;
  final int returningCustomers;
  final int totalCustomers;
  final double retentionRate;
  final double churnRate;
  final double avgOrderValue;
  final double avgCustomerLtv;
  final double orderGrowth;
  final Map<String, int> clvDistribution;
  final List<DailyPoint> aovTrend;

  const BusinessReport({
    required this.ordersPlaced,
    required this.ordersPacked,
    required this.ordersShipped,
    required this.ordersDelivered,
    required this.ordersCancelled,
    required this.ordersReturned,
    required this.totalOrders,
    required this.newCustomers,
    required this.returningCustomers,
    required this.totalCustomers,
    required this.retentionRate,
    required this.churnRate,
    required this.avgOrderValue,
    required this.avgCustomerLtv,
    required this.orderGrowth,
    required this.clvDistribution,
    required this.aovTrend,
  });

  factory BusinessReport.empty() => const BusinessReport(
        ordersPlaced: 0,
        ordersPacked: 0,
        ordersShipped: 0,
        ordersDelivered: 0,
        ordersCancelled: 0,
        ordersReturned: 0,
        totalOrders: 0,
        newCustomers: 0,
        returningCustomers: 0,
        totalCustomers: 0,
        retentionRate: 0,
        churnRate: 0,
        avgOrderValue: 0,
        avgCustomerLtv: 0,
        orderGrowth: 0,
        clvDistribution: {},
        aovTrend: [],
      );
}

class FranchiseReport {
  final List<BranchPerformance> branches;
  const FranchiseReport({required this.branches});
  factory FranchiseReport.empty() => const FranchiseReport(branches: []);

  double get totalRevenue =>
      branches.fold(0.0, (total, b) => total + b.revenue);
}

class BranchPerformance {
  final String branchId;
  final String branchName;
  final int orders;
  final int deliveredOrders;
  final double revenue;
  final double avgOrderValue;
  final double avgRating;
  final int refundCount;
  final double estimatedProfit;

  const BranchPerformance({
    required this.branchId,
    required this.branchName,
    required this.orders,
    required this.deliveredOrders,
    required this.revenue,
    required this.avgOrderValue,
    required this.avgRating,
    required this.refundCount,
    required this.estimatedProfit,
  });
}

class _BranchAccumulator {
  final String id;
  final String name;
  int orders = 0;
  int deliveredOrders = 0;
  double revenue = 0;
  int refunds = 0;
  double ratingSum = 0;
  int ratingCount = 0;
  _BranchAccumulator(this.id, this.name);
}
