class Coupon {
  final String id;
  final String code;
  final String name;
  final String description;
  final String discountType; // 'percentage' or 'flat'
  final double discountValue;
  final double minimumOrderAmount;
  final double maximumDiscountAmount;
  final DateTime startDate;
  final DateTime endDate;

  Coupon({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.minimumOrderAmount,
    required this.maximumDiscountAmount,
    required this.startDate,
    required this.endDate,
  });

  double calculateDiscount(double subtotal) {
    if (subtotal < minimumOrderAmount) return 0.0;
    
    double discount = 0.0;
    if (discountType == 'percentage') {
      discount = subtotal * (discountValue / 100.0);
      if (discount > maximumDiscountAmount) {
        discount = maximumDiscountAmount;
      }
    } else if (discountType == 'flat') {
      discount = discountValue;
    }
    return discount;
  }
}
