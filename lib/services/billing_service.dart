import '../models/delivery_type.dart';
import '../models/order_model.dart';
import '../models/shop_config_model.dart';
import '../models/shop_branch_model.dart';

class BillingDetails {
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryCharge;
  final double tax;
  final double discount;
  final double grandTotal;
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
    double subtotal = items.fold(0, (sum, item) => sum + item.totalPrice);

    // 2. Dynamic Delivery Charge logic
    double deliveryCharge = 0.0;
    
    if (deliveryType == DeliveryType.express) {
      deliveryCharge = config.expressDeliveryFee;
    } else {
      // Free delivery above threshold
      if (subtotal < config.freeDeliveryThreshold) {
        deliveryCharge = config.standardDeliveryFee;
      }
    }
    
    // Distance surcharge for far locations
    if (distanceKm > config.baseDeliveryRadiusKm) {
      deliveryCharge += (distanceKm - config.baseDeliveryRadiusKm) * config.deliveryFeePerKm;
    }

    // 3. Tax calculation (GST 5% for food/essentials)
    double tax = subtotal * 0.05;

    // 4. Discounts
    double totalDiscount = couponDiscount;
    if (isFirstOrder) {
      totalDiscount += 20.0; // ₹20 off for first-time village users
    }

    // 5. Grand Total
    double grandTotal = (subtotal + deliveryCharge + tax - totalDiscount).clamp(0, double.infinity);

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
