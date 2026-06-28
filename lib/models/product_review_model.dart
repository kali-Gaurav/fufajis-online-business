import 'package:cloud_firestore/cloud_firestore.dart';

class ProductReviewModel {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final String? userImage;
  final double rating; // 1-5 stars
  final String comment;
  final List<String> mediaUrls; // Up to 3 images
  final String? videoUrl; // Step 14.1
  final DateTime createdAt;
  final String? orderId; // Reference to order
  final bool isVerifiedPurchase;
  final String? ownerReply; // Shop owner response
  final DateTime? ownerReplyDate;
  final bool isFlagged; // For moderation
  final bool isApproved; // Admin approval status
  final bool isFeatured; // Highlighted review
  final int helpfulCount; // Number of users who found this helpful
  final List<String> flagReasons;

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
    this.isFeatured = false,
    this.helpfulCount = 0,
    this.flagReasons = const [],
    this.videoUrl,
  });

  factory ProductReviewModel.fromMap(Map<String, dynamic> map) {
    return ProductReviewModel(
      id: map['id'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? 'Customer',
      userImage: map['userImage'] as String?,
      rating: (map['rating'] as num? ?? 0.0).toDouble(),
      comment: map['comment'] as String? ?? '',
      mediaUrls: List<String>.from(map['mediaUrls'] as Iterable? ?? []),
      videoUrl: map['videoUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      orderId: map['orderId'] as String?,
      isVerifiedPurchase: map['isVerifiedPurchase'] as bool? ?? false,
      ownerReply: map['ownerReply'] as String?,
      ownerReplyDate: (map['ownerReplyDate'] as Timestamp?)?.toDate(),
      isFlagged: map['isFlagged'] as bool? ?? false,
      isApproved: map['isApproved'] as bool? ?? true,
      isFeatured: map['isFeatured'] as bool? ?? false,
      helpfulCount: map['helpfulCount'] as int? ?? 0,
      flagReasons: List<String>.from(map['flagReasons'] as Iterable? ?? []),
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
      'videoUrl': videoUrl,
      'createdAt': createdAt,
      'orderId': orderId,
      'isVerifiedPurchase': isVerifiedPurchase,
      'ownerReply': ownerReply,
      'ownerReplyDate': ownerReplyDate,
      'isFlagged': isFlagged,
      'isApproved': isApproved,
      'isFeatured': isFeatured,
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
    String? videoUrl,
    DateTime? createdAt,
    String? orderId,
    bool? isVerifiedPurchase,
    String? ownerReply,
    DateTime? ownerReplyDate,
    bool? isFlagged,
    bool? isApproved,
    bool? isFeatured,
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
      videoUrl: videoUrl ?? this.videoUrl,
      createdAt: createdAt ?? this.createdAt,
      orderId: orderId ?? this.orderId,
      isVerifiedPurchase: isVerifiedPurchase ?? this.isVerifiedPurchase,
      ownerReply: ownerReply ?? this.ownerReply,
      ownerReplyDate: ownerReplyDate ?? this.ownerReplyDate,
      isFlagged: isFlagged ?? this.isFlagged,
      isApproved: isApproved ?? this.isApproved,
      isFeatured: isFeatured ?? this.isFeatured,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      flagReasons: flagReasons ?? this.flagReasons,
    );
  }
}
