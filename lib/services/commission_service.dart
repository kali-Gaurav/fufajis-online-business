import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shop_model.dart';

/// Per-vendor commission summary for a date range (Task #55).
///
/// `grossSales` is the sum of `totalAmount` across the vendor's delivered
/// orders in the range. `commissionAmount` is the platform's cut, computed
/// from each shop's [ShopModel.commissionPercent] (so a shop that changes
/// its commission mid-range is still computed correctly per-order).
/// `vendorPayable` is what's owed to the vendor (`grossSales -
/// commissionAmount`) — this is the same figure Task #53's automated payout
/// job aggregates, so this dashboard is a live preview of that.
class VendorCommissionSummary {
  final String shopId;
  final String shopName;
  final double commissionPercent;
  final int orderCount;
  final double grossSales;
  final double commissionAmount;
  final double vendorPayable;

  VendorCommissionSummary({
    required this.shopId,
    required this.shopName,
    required this.commissionPercent,
    required this.orderCount,
    required this.grossSales,
    required this.commissionAmount,
    required this.vendorPayable,
  });
}

/// Aggregates per-vendor commission dues across all shops for a given
/// date range, for the owner's "Vendor Commission Dashboard" (Task #55).
///
/// This is read-only and does not write anything — it's a live preview of
/// what `generatePayoutRequests` (Task #53) would compute for vendor payout
/// requests, broken down per vendor so the owner can review commission
/// splits before any payout request is generated/approved.
class CommissionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns one [VendorCommissionSummary] per active shop, for delivered
  /// orders with `createdAt` in `[startDate, endDate]`. Shops with zero
  /// delivered orders in the range are included with zero values so the
  /// owner can see the full vendor roster.
  Future<List<VendorCommissionSummary>> getCommissionSummaries({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // 1. Load all shops (for name + commissionPercent lookup).
    final shopsSnap = await _db.collection('shops').get();
    final shops = <String, ShopModel>{};
    for (final doc in shopsSnap.docs) {
      try {
        shops[doc.id] = ShopModel.fromMap({...doc.data(), 'shopId': doc.id});
      } catch (_) {
        // Skip malformed shop docs rather than failing the whole dashboard.
      }
    }

    // 2. Load delivered orders in range.
    final ordersSnap = await _db
        .collection('orders')
        .where('status', isEqualTo: 'OrderStatus.delivered')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    // 3. Aggregate per shopId.
    final orderCounts = <String, int>{};
    final grossSales = <String, double>{};

    for (final doc in ordersSnap.docs) {
      final data = doc.data();
      final shopId = (data['shopId'] as String?) ?? 'unknown';
      final total = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
      orderCounts[shopId] = (orderCounts[shopId] ?? 0) + 1;
      grossSales[shopId] = (grossSales[shopId] ?? 0.0) + total;
    }

    // 4. Build summaries — one per known shop, plus any "unknown" shopId
    // bucket that has orders but no matching shop document.
    final shopIds = {...shops.keys, ...grossSales.keys};
    final summaries = <VendorCommissionSummary>[];

    for (final shopId in shopIds) {
      final shop = shops[shopId];
      final commissionPercent = shop?.commissionPercent ?? 10.0;
      final sales = grossSales[shopId] ?? 0.0;
      final commission = sales * (commissionPercent / 100);

      summaries.add(VendorCommissionSummary(
        shopId: shopId,
        shopName: shop?.shopName ?? 'Unknown shop ($shopId)',
        commissionPercent: commissionPercent,
        orderCount: orderCounts[shopId] ?? 0,
        grossSales: sales,
        commissionAmount: commission,
        vendorPayable: sales - commission,
      ));
    }

    // Highest sales first.
    summaries.sort((a, b) => b.grossSales.compareTo(a.grossSales));
    return summaries;
  }

  /// Convenience totals across all vendors for the same range.
  ({double grossSales, double commissionAmount, double vendorPayable}) totals(
    List<VendorCommissionSummary> summaries,
  ) {
    double gross = 0, commission = 0, payable = 0;
    for (final s in summaries) {
      gross += s.grossSales;
      commission += s.commissionAmount;
      payable += s.vendorPayable;
    }
    return (grossSales: gross, commissionAmount: commission, vendorPayable: payable);
  }
}
