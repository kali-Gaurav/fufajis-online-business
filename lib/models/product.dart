/// 📦 Product Model
/// Represents a product in Fufaji Store
/// Supports Hindi/English, pricing with GST, ratings, inventory

class Product {
  /// Unique product identifier
  final String id;

  /// Product name in English
  final String nameEn;

  /// Product name in Hindi
  final String nameHi;

  /// Product description in English
  final String descriptionEn;

  /// Product description in Hindi
  final String descriptionHi;

  /// Base price (before GST and discounts)
  final double basePrice;

  /// Discount percentage (0-100)
  final double discountPercent;

  /// GST rate (18% for most products in India)
  final double gstRate;

  /// Product image URL
  final String imageUrl;

  /// Stock quantity available
  final int stock;

  /// Average rating (1-5 stars)
  final double rating;

  /// Number of reviews/ratings
  final int reviewCount;

  /// Product category (e.g., "electronics", "clothing")
  final String category;

  /// Product weight/size (e.g., "1 kg", "500g")
  final String weight;

  /// Optional dad joke for this product
  final String? dadJoke;

  /// Seller/brand name
  final String? seller;

  /// Product tags for search/filter
  final List<String> tags;

  /// Whether product is active (visible to users)
  final bool isActive;

  /// Whether product is featured/promoted
  final bool isFeatured;

  /// Whether this is a best seller
  final bool isBestseller;

  /// Constructor
  Product({
    required this.id,
    required this.nameEn,
    required this.nameHi,
    required this.descriptionEn,
    required this.descriptionHi,
    required this.basePrice,
    required this.discountPercent,
    required this.gstRate,
    required this.imageUrl,
    required this.stock,
    required this.rating,
    required this.reviewCount,
    required this.category,
    required this.weight,
    this.dadJoke,
    this.seller,
    required this.tags,
    this.isActive = true,
    this.isFeatured = false,
    this.isBestseller = false,
  });

  /// Calculate discounted price
  double get discountedPrice {
    return basePrice * (1 - (discountPercent / 100));
  }

  /// Calculate GST amount
  double get gstAmount {
    return discountedPrice * (gstRate / 100);
  }

  /// Calculate final price (discounted price + GST)
  double get finalPrice {
    return discountedPrice + gstAmount;
  }

  /// Check if product is in stock
  bool get isInStock => stock > 0;

  /// Check if stock is running low (< 5 items)
  bool get isLowStock => stock > 0 && stock < 5;

  /// Get stock status as string
  String get stockStatus {
    if (stock == 0) return 'Out of Stock';
    if (stock < 5) return 'Limited Stock';
    if (stock < 10) return 'Running Low';
    return 'In Stock';
  }

  /// Get discount percentage as integer
  int get discountPercentInt => discountPercent.toInt();

  /// Check if product has discount
  bool get hasDiscount => discountPercent > 0;

  /// Get rating as text
  String get ratingText {
    if (rating >= 4.5) return '⭐⭐⭐⭐⭐ Excellent';
    if (rating >= 4.0) return '⭐⭐⭐⭐ Very Good';
    if (rating >= 3.0) return '⭐⭐⭐ Good';
    if (rating >= 2.0) return '⭐⭐ Fair';
    return '⭐ Poor';
  }

  @override
  String toString() {
    return 'Product(id: $id, nameEn: $nameEn, price: ₹$finalPrice, stock: $stock)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
