class ProductReviewModel {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final String? userImage;
  final double rating; // 1-5 stars
  final String comment;
  final List<String> mediaUrls; // Up to 3 images
  final DateTime createdAt;
  final String? orderId; // Reference to order for one-review-per-order validation
  final bool isVerifiedPurchase;
  final String? ownerReply; // Shop owner response
  final DateTime? ownerReplyDate;
  final bool isFlagged; // For moderation
  final bool isApproved; // Admin approval status
  final int helpfulCount; // Number of users who found this helpful
  final List<String> flagReasons; // Reasons for flagging

  ProductReviewModel({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    this.userImage,
    required this.rating,
    required this.comment,
    this.mediaUrls = const [],
    required this.createdAt,
    this.orderId,
    this.isVerifiedPurchase = false,
    this.ownerReply,
    this.ownerReplyDate,
    this.isFlagged = false,
    this.isApproved = true,
    this.helpfulCount = 0,
    this.flagReasons = const [],
  });

  factory ProductReviewModel.fromMap(Map<String, dynamic> map) {
    return ProductReviewModel(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Customer',
      userImage: map['userImage'],
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: map['comment'] ?? '',
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      orderId: map['orderId'],
      isVerifiedPurchase: map['isVerifiedPurchase'] ?? false,
      ownerReply: map['ownerReply'],
      ownerReplyDate: map['ownerReplyDate']?.toDate(),
      isFlagged: map['isFlagged'] ?? false,
      isApproved: map['isApproved'] ?? true,
      helpfulCount: map['helpfulCount'] ?? 0,
      flagReasons: List<String>.from(map['flagReasons'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'userId': userId,
      'userName': userName,
      'userImage': userImage,
      'rating': rating,
      'comment': comment,
      'mediaUrls': mediaUrls,
      'createdAt': createdAt,
      'orderId': orderId,
      'isVerifiedPurchase': isVerifiedPurchase,
      'ownerReply': ownerReply,
      'ownerReplyDate': ownerReplyDate,
      'isFlagged': isFlagged,
      'isApproved': isApproved,
      'helpfulCount': helpfulCount,
      'flagReasons': flagReasons,
    };
  }

  ProductReviewModel copyWith({
    String? id,
    String? productId,
    String? userId,
    String? userName,
    String? userImage,
    double? rating,
    String? comment,
    List<String>? mediaUrls,
    DateTime? createdAt,
    String? orderId,
    bool? isVerifiedPurchase,
    String? ownerReply,
    DateTime? ownerReplyDate,
    bool? isFlagged,
    bool? isApproved,
    int? helpfulCount,
    List<String>? flagReasons,
  }) {
    return ProductReviewModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userImage: userImage ?? this.userImage,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      createdAt: createdAt ?? this.createdAt,
      orderId: orderId ?? this.orderId,
      isVerifiedPurchase: isVerifiedPurchase ?? this.isVerifiedPurchase,
      ownerReply: ownerReply ?? this.ownerReply,
      ownerReplyDate: ownerReplyDate ?? this.ownerReplyDate,
      isFlagged: isFlagged ?? this.isFlagged,
      isApproved: isApproved ?? this.isApproved,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      flagReasons: flagReasons ?? this.flagReasons,
    );
  }
}
