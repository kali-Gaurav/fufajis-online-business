import '../models/delivery_type.dart';
import '../models/order_model.dart';
import '../models/shop_config_model.dart';
import '../models/shop_branch_model.dart';
import '../utils/monetary_value.dart';

class BillingDetails {
  final List<OrderItem> items;
  final MonetaryValue subtotal;
  final MonetaryValue deliveryCharge;
  final MonetaryValue tax;
  final MonetaryValue discount;
  final MonetaryValue grandTotal;
  final String invoiceNumber;

  BillingDetails({
    required this.items,
    required this.subtotal,
    required this.deliveryCharge,
    required this.tax,
    required this.discount,
    required this.grandTotal,
    required this.invoiceNumber,
  });
}

class BillingService {
  /// Consolidates all pricing logic (Replaces old DeliveryChargeCalculator)
  static BillingDetails calculateBill({
    required List<OrderItem> items,
    required DeliveryType deliveryType,
    required ShopConfigModel config,
    ShopBranchModel? branch,
    double distanceKm = 0.0,
    double couponDiscount = 0.0,
    bool isFirstOrder = false,
  }) {
    // 1. Calculate items subtotal
    MonetaryValue subtotal = items.fold(MonetaryValue(0.0), (sum, item) => sum + item.totalPrice);

    // 2. Dynamic Delivery Charge logic
    double deliveryChargeVal = 0.0;
    
    if (deliveryType == DeliveryType.express) {
      deliveryChargeVal = config.expressDeliveryFee;
    } else {
      // Free delivery above threshold
      if (subtotal.toDouble() < config.freeDeliveryThreshold) {
        deliveryChargeVal = config.standardDeliveryFee;
      }
    }
    
    // Distance surcharge for far locations
    if (distanceKm > config.baseDeliveryRadiusKm) {
      deliveryChargeVal += (distanceKm - config.baseDeliveryRadiusKm) * config.deliveryFeePerKm;
    }

    MonetaryValue deliveryCharge = MonetaryValue(deliveryChargeVal);

    // 3. Tax calculation (GST 5% for food/essentials)
    MonetaryValue tax = subtotal * 0.05;

    // 4. Discounts
    double totalDiscountVal = couponDiscount;
    if (isFirstOrder) {
      totalDiscountVal += 20.0; // ₹20 off for first-time village users
    }
    MonetaryValue totalDiscount = MonetaryValue(totalDiscountVal);

    // 5. Grand Total
    MonetaryValue grandTotal = (subtotal + deliveryCharge + tax - totalDiscount).clamp(MonetaryValue(0.0), MonetaryValue(1000000.0));

    // 6. Generate Provisional Invoice ID
    String invoiceId = "INV-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

    return BillingDetails(
      items: items,
      subtotal: subtotal,
      deliveryCharge: deliveryCharge,
      tax: tax,
      discount: totalDiscount,
      grandTotal: grandTotal,
      invoiceNumber: invoiceId,
    );
  }
}
