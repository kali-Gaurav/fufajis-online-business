import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/payment_method.dart';
import '../models/delivery_type.dart';
import '../models/user_model.dart';
import '../constants/order_status.dart';
import '../utils/monetary_value.dart';

/// Represents profit metrics calculated for a given date range
class ProfitMetrics {
  final double grossRevenue;
  final double cogs; // Cost of Goods Sold
  final double refunds;
  final double commissions; // Platform commission (10%)
  final double netProfit;
  final double profitMarginPercentage;
  final int ordersProcessed;
  final DateTime startDate;
  final DateTime endDate;

  ProfitMetrics({
    required this.grossRevenue,
    required this.cogs,
    required this.refunds,
    required this.commissions,
    required this.netProfit,
    required this.profitMarginPercentage,
    required this.ordersProcessed,
    required this.startDate,
    required this.endDate,
  });

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'grossRevenue': grossRevenue,
      'cogs': cogs,
      'refunds': refunds,
      'commissions': commissions,
      'netProfit': netProfit,
      'profitMarginPercentage': profitMarginPercentage,
      'ordersProcessed': ordersProcessed,
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  @override
  String toString() {
    return 'ProfitMetrics(grossRevenue: $grossRevenue, cogs: $cogs, refunds: $refunds, '
        'commissions: $commissions, netProfit: $netProfit, '
        'profitMarginPercentage: $profitMarginPercentage%, ordersProcessed: $ordersProcessed)';
  }
}

class ProfitService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Calculate comprehensive profit metrics for a shop within a date range
  ///
  /// Parameters:
  /// - shopId: The ID of the shop to calculate profit for
  /// - startDate: Start of the date range (inclusive)
  /// - endDate: End of the date range (inclusive)
  /// - platformCommissionPercent: Platform commission percentage (default: 10%)
  ///
  /// Returns: ProfitMetrics containing all profit calculations
  Future<ProfitMetrics> calculateProfitMetrics(
    String shopId, {
    required DateTime startDate,
    required DateTime endDate,
    double platformCommissionPercent = 10.0,
  }) async {
    try {
      // Validate dates
      if (startDate.isAfter(endDate)) {
        throw ArgumentError('startDate must be before or equal to endDate');
      }

      // 1. Fetch all orders for the shop in the date range
      final ordersSnapshot = await _db
          .collection('orders')
          .where('shopId', isEqualTo: shopId)
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          // Only count completed/delivered orders for profit calculation
          .where('status', isEqualTo: 'OrderStatus.delivered')
          .get();

      if (ordersSnapshot.docs.isEmpty) {
        return ProfitMetrics(
          grossRevenue: 0.0,
          cogs: 0.0,
          refunds: 0.0,
          commissions: 0.0,
          netProfit: 0.0,
          profitMarginPercentage: 0.0,
          ordersProcessed: 0,
          startDate: startDate,
          endDate: endDate,
        );
      }

      // 2. Parse orders and calculate gross revenue and refunds
      double grossRevenue = 0.0;
      double totalRefunds = 0.0;
      List<OrderModel> orders = [];

      for (final doc in ordersSnapshot.docs) {
        try {
          final orderData = doc.data();
          final order = _parseOrder(orderData);
          orders.add(order);

          // Add to gross revenue
          grossRevenue += order.totalAmount.toDouble();

          // Add refunds if order was refunded
          if (order.status == OrderStatus.refunded) {
            totalRefunds += order.totalAmount.toDouble();
          }
        } catch (e) {
          print('Error parsing order ${doc.id}: $e');
          continue;
        }
      }

      // 3. Calculate COGS (Cost of Goods Sold)
      double totalCogs = await _calculateTotalCogs(orders);

      // 4. Calculate commissions (10% of gross revenue)
      double commissions = grossRevenue * (platformCommissionPercent / 100);

      // 5. Calculate net profit
      // Net Profit = Gross Revenue - COGS - Platform Commission - Refunds
      double netProfit = grossRevenue - totalCogs - commissions - totalRefunds;

      // 6. Calculate profit margin percentage
      // Profit Margin % = (Net Profit / Gross Revenue) * 100
      double profitMarginPercentage = grossRevenue > 0
          ? (netProfit / grossRevenue) * 100
          : 0.0;

      return ProfitMetrics(
        grossRevenue: grossRevenue,
        cogs: totalCogs,
        refunds: totalRefunds,
        commissions: commissions,
        netProfit: netProfit,
        profitMarginPercentage: profitMarginPercentage,
        ordersProcessed: orders.length,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      print('Error calculating profit metrics: $e');
      rethrow;
    }
  }

  /// Calculate total COGS for all items in the given orders
  ///
  /// This method fetches the costPrice from product documents for each item
  /// and calculates: COGS = sum(quantity * costPrice) for all items
  Future<double> _calculateTotalCogs(List<OrderModel> orders) async {
    double totalCogs = 0.0;

    // Collect all unique product IDs
    Set<String> productIds = {};
    for (final order in orders) {
      for (final item in order.items) {
        productIds.add(item.productId);
      }
    }

    if (productIds.isEmpty) {
      return 0.0;
    }

    // Fetch product documents in batches to avoid query limitations
    Map<String, double> productCostPrices = {};

    for (final productId in productIds) {
      try {
        final productDoc =
            await _db.collection('products').doc(productId).get();

        if (productDoc.exists) {
          final costPrice =
              ((productDoc.data()?['costPrice'] as num?) ?? 0.0).toDouble();
          productCostPrices[productId] = costPrice;
        } else {
          // If product not found, assume cost price is 0
          productCostPrices[productId] = 0.0;
        }
      } catch (e) {
        print('Error fetching product $productId: $e');
        productCostPrices[productId] = 0.0;
      }
    }

    // Calculate COGS for all items
    for (final order in orders) {
      for (final item in order.items) {
        final costPrice = productCostPrices[item.productId] ?? 0.0;
        totalCogs += (costPrice * item.quantity);
      }
    }

    return totalCogs;
  }

  /// Parse Firestore document data into OrderModel
  ///
  /// Handles the conversion of Firestore maps to OrderModel objects
  OrderModel _parseOrder(Map<String, dynamic> data) {
    // Parse status string to OrderStatus enum
    String statusStr = data['status'] as String? ?? 'OrderStatus.pending';
    OrderStatus status = OrderStatus.pending;

    try {
      // Handle both 'OrderStatus.pending' and 'pending' formats
      String enumStr = statusStr.contains('.')
          ? statusStr.split('.').last
          : statusStr.toLowerCase();

      status = OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == enumStr,
        orElse: () => OrderStatus.pending,
      );
    } catch (e) {
      print('Error parsing status: $statusStr - $e');
      status = OrderStatus.pending;
    }

    // Parse items
    List<OrderItem> items = [];
    if (data['items'] is List) {
      items = (data['items'] as List)
          .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    // Parse delivery address
    Address address = Address.fromMap(data['deliveryAddress'] as Map<String, dynamic>? ?? {});

    return OrderModel(
      id: data['id'] as String? ?? '',
      orderNumber: data['orderNumber'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      customerPhone: data['customerPhone'] as String? ?? '',
      customerEmail: data['customerEmail'] as String?,
      items: items,
      subtotal: MonetaryValue(((data['subtotal'] as num?) ?? 0.0).toDouble()),
      deliveryCharge: MonetaryValue(((data['deliveryCharge'] as num?) ?? 0.0).toDouble()),
      discount: MonetaryValue(((data['discount'] as num?) ?? 0.0).toDouble()),
      tax: MonetaryValue(((data['tax'] as num?) ?? 0.0).toDouble()),
      totalAmount: MonetaryValue(((data['totalAmount'] as num?) ?? 0.0).toDouble()),
      walletAmountUsed: MonetaryValue(((data['walletAmountUsed'] as num?) ?? 0.0).toDouble()),
      cashbackEarned: MonetaryValue(((data['cashbackEarned'] as num?) ?? 0.0).toDouble()),
      rewardPointsUsed: (data['rewardPointsUsed'] as num? ?? 0).toInt(),
      rewardPointsEarned: (data['rewardPointsEarned'] as num? ?? 0).toInt(),
      paymentMethod: PaymentMethod.cod, // Default
      selectedPaymentMethod: PaymentMethod.cod, // Default
      status: status,
      deliveryType: DeliveryType.standard, // Default
      deliveryAddress: address,
      shopId: data['shopId'] as String?,
      shopName: data['shopName'] as String?,
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(data['updatedAt']) ?? DateTime.now(),
      tipAmount: MonetaryValue(((data['tipAmount'] as num?) ?? 0.0).toDouble()),
      packagingFee: MonetaryValue(((data['packagingFee'] as num?) ?? 0.0).toDouble()),
      isGift: data['isGift'] as bool? ?? false,
    );
  }

  /// Helper to parse date from Firestore Timestamp or String
  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  /// Get profit metrics for different date ranges
  ///
  /// Convenience method to get metrics for common date ranges
  Future<ProfitMetrics> getProfitMetricsForRange(
    String shopId,
    String range, // 'today', 'week', 'month', 'year', 'all'
  ) async {
    final now = DateTime.now();
    late DateTime startDate;
    late DateTime endDate;

    switch (range.toLowerCase()) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = now;
        break;
      case 'week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = now;
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        endDate = now;
        break;
      case 'year':
        startDate = DateTime(now.year, 1, 1);
        endDate = now;
        break;
      case 'all':
        startDate = DateTime(2020, 1, 1); // Arbitrary start
        endDate = now;
        break;
      default:
        throw ArgumentError('Invalid range: $range');
    }

    return calculateProfitMetrics(
      shopId,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
