class ProductReviewModel {
  final String id;
  final String orderId;
  final String productId;
  final String customerId;
  final String orderItemId;

  final int rating; // 1-5
  final String? reviewText;
  final List<String> tags; // ['quality', 'freshness', 'packaging', 'damage', 'wrong_item']

  final bool isFlagged;
  final String? flagReason;
  final bool resolved;
  final DateTime? resolvedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  ProductReviewModel({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.customerId,
    required this.orderItemId,
    required this.rating,
    this.reviewText,
    this.tags = const [],
    this.isFlagged = false,
    this.flagReason,
    this.resolved = false,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductReviewModel.fromJson(Map<String, dynamic> json) {
    return ProductReviewModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String,
      customerId: json['customer_id'] as String,
      orderItemId: json['order_item_id'] as String,
      rating: json['rating'] as int,
      reviewText: json['review_text'] as String?,
      tags: List<String>.from(json['tags'] as List? ?? []),
      isFlagged: json['is_flagged'] as bool? ?? false,
      flagReason: json['flag_reason'] as String?,
      resolved: json['resolved'] as bool? ?? false,
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'customer_id': customerId,
      'order_item_id': orderItemId,
      'rating': rating,
      'review_text': reviewText,
      'tags': tags,
      'is_flagged': isFlagged,
      'flag_reason': flagReason,
      'resolved': resolved,
      'resolved_at': resolvedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProductReviewModel copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? customerId,
    String? orderItemId,
    int? rating,
    String? reviewText,
    List<String>? tags,
    bool? isFlagged,
    String? flagReason,
    bool? resolved,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductReviewModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      customerId: customerId ?? this.customerId,
      orderItemId: orderItemId ?? this.orderItemId,
      rating: rating ?? this.rating,
      reviewText: reviewText ?? this.reviewText,
      tags: tags ?? this.tags,
      isFlagged: isFlagged ?? this.isFlagged,
      flagReason: flagReason ?? this.flagReason,
      resolved: resolved ?? this.resolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
