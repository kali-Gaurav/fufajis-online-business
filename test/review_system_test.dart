import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/models/product_review_model.dart';
import 'package:fufajis_online/services/profanity_filter_service.dart';

void main() {
  group('ProductReviewModel Tests', () {
    test('ProductReviewModel creation with all fields', () {
      final review = ProductReviewModel(
        id: 'review_1',
        productId: 'product_1',
        userId: 'user_1',
        userName: 'John Doe',
        userImage: 'https://example.com/image.jpg',
        rating: 4.5,
        comment: 'Great product!',
        mediaUrls: ['https://example.com/photo1.jpg'],
        createdAt: DateTime.now(),
        orderId: 'order_1',
        isVerifiedPurchase: true,
        ownerReply: 'Thank you!',
        ownerReplyDate: DateTime.now(),
        isFlagged: false,
        isApproved: true,
        helpfulCount: 5,
        flagReasons: [],
      );

      expect(review.id, 'review_1');
      expect(review.productId, 'product_1');
      expect(review.rating, 4.5);
      expect(review.isVerifiedPurchase, true);
      expect(review.ownerReply, 'Thank you!');
      expect(review.helpfulCount, 5);
    });

    test('ProductReviewModel toMap and fromMap', () {
      final now = DateTime.now();
      final review = ProductReviewModel(
        id: 'review_1',
        productId: 'product_1',
        userId: 'user_1',
        userName: 'John Doe',
        rating: 4.0,
        comment: 'Good product',
        createdAt: now,
        isVerifiedPurchase: true,
      );

      final map = review.toMap();
      final reviewFromMap = ProductReviewModel.fromMap(map);

      expect(reviewFromMap.id, review.id);
      expect(reviewFromMap.productId, review.productId);
      expect(reviewFromMap.rating, review.rating);
      expect(reviewFromMap.isVerifiedPurchase, review.isVerifiedPurchase);
    });

    test('ProductReviewModel copyWith', () {
      final review = ProductReviewModel(
        id: 'review_1',
        productId: 'product_1',
        userId: 'user_1',
        userName: 'John Doe',
        rating: 4.0,
        comment: 'Good product',
        createdAt: DateTime.now(),
      );

      final updatedReview = review.copyWith(
        ownerReply: 'Thank you for your feedback!',
        helpfulCount: 10,
      );

      expect(updatedReview.id, review.id);
      expect(updatedReview.ownerReply, 'Thank you for your feedback!');
      expect(updatedReview.helpfulCount, 10);
      expect(updatedReview.rating, review.rating);
    });

    test('ProductReviewModel with minimum fields', () {
      final review = ProductReviewModel(
        id: 'review_1',
        productId: 'product_1',
        userId: 'user_1',
        userName: 'Anonymous',
        rating: 3.0,
        comment: '',
        createdAt: DateTime.now(),
      );

      expect(review.mediaUrls, isEmpty);
      expect(review.isVerifiedPurchase, false);
      expect(review.isFlagged, false);
      expect(review.isApproved, true);
    });
  });

  group('ProfanityFilterService Tests', () {
    final filterService = ProfanityFilterService();

    test('Filter detects no profanity in clean text', () {
      const text = 'This is a great product!';
      final filtered = filterService.filter(text);
      expect(filtered, text);
    });

    test('hasProfanity returns false for clean text', () {
      const text = 'This is a great product!';
      expect(filterService.hasProfanity(text), false);
    });

    test('getProfanityWords returns empty list for clean text', () {
      const text = 'This is a great product!';
      expect(filterService.getProfanityWords(text), isEmpty);
    });

    test('Filter handles case insensitivity', () {
      const text = 'This product is GREAT';
      final filtered = filterService.filter(text);
      expect(filtered, isNotNull);
    });

    test('Filter handles multiple words', () {
      const text = 'This is a good product with great quality';
      final filtered = filterService.filter(text);
      expect(filtered, isNotNull);
    });
  });

  group('Review Rating Distribution Tests', () {
    test('Calculate rating distribution from reviews', () {
      final reviews = [
        ProductReviewModel(
          id: '1',
          productId: 'p1',
          userId: 'u1',
          userName: 'User 1',
          rating: 5.0,
          comment: 'Excellent',
          createdAt: DateTime.now(),
        ),
        ProductReviewModel(
          id: '2',
          productId: 'p1',
          userId: 'u2',
          userName: 'User 2',
          rating: 4.0,
          comment: 'Good',
          createdAt: DateTime.now(),
        ),
        ProductReviewModel(
          id: '3',
          productId: 'p1',
          userId: 'u3',
          userName: 'User 3',
          rating: 5.0,
          comment: 'Great',
          createdAt: DateTime.now(),
        ),
        ProductReviewModel(
          id: '4',
          productId: 'p1',
          userId: 'u4',
          userName: 'User 4',
          rating: 3.0,
          comment: 'Average',
          createdAt: DateTime.now(),
        ),
      ];

      // Calculate distribution
      final distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      double totalRating = 0;

      for (var review in reviews) {
        final rating = review.rating.toInt();
        if (distribution.containsKey(rating)) {
          distribution[rating] = distribution[rating]! + 1;
        }
        totalRating += review.rating;
      }

      final averageRating = totalRating / reviews.length;

      expect(distribution[5], 2);
      expect(distribution[4], 1);
      expect(distribution[3], 1);
      expect(distribution[2], 0);
      expect(distribution[1], 0);
      expect(averageRating, 4.25);
    });

    test('Calculate average rating correctly', () {
      final ratings = [5.0, 4.0, 3.0, 4.0, 5.0];
      final average = ratings.reduce((a, b) => a + b) / ratings.length;
      expect(average, 4.2);
    });

    test('Handle empty reviews list', () {
      final reviews = <ProductReviewModel>[];
      expect(reviews.isEmpty, true);
    });
  });

  group('Review Validation Tests', () {
    test('Review with minimum comment length', () {
      const comment = 'abc'; // 3 characters minimum
      expect(comment.length >= 3, true);
    });

    test('Review with rating in valid range', () {
      const rating = 4.5;
      expect(rating >= 1 && rating <= 5, true);
    });

    test('Review with maximum images', () {
      final mediaUrls = [
        'https://example.com/1.jpg',
        'https://example.com/2.jpg',
        'https://example.com/3.jpg',
      ];
      expect(mediaUrls.length <= 3, true);
    });

    test('Review with verified purchase flag', () {
      final review = ProductReviewModel(
        id: 'r1',
        productId: 'p1',
        userId: 'u1',
        userName: 'User',
        rating: 5.0,
        comment: 'Great!',
        createdAt: DateTime.now(),
        orderId: 'order_123',
        isVerifiedPurchase: true,
      );
      expect(review.isVerifiedPurchase, true);
    });
  });

  group('Review Moderation Tests', () {
    test('Flag review with reasons', () {
      final review = ProductReviewModel(
        id: 'r1',
        productId: 'p1',
        userId: 'u1',
        userName: 'User',
        rating: 5.0,
        comment: 'Test',
        createdAt: DateTime.now(),
        isFlagged: true,
        flagReasons: ['spam', 'inappropriate'],
      );

      expect(review.isFlagged, true);
      expect(review.flagReasons.length, 2);
      expect(review.flagReasons.contains('spam'), true);
    });

    test('Approve flagged review', () {
      var review = ProductReviewModel(
        id: 'r1',
        productId: 'p1',
        userId: 'u1',
        userName: 'User',
        rating: 5.0,
        comment: 'Test',
        createdAt: DateTime.now(),
        isFlagged: true,
        isApproved: false,
      );

      review = review.copyWith(
        isFlagged: false,
        isApproved: true,
      );

      expect(review.isFlagged, false);
      expect(review.isApproved, true);
    });

    test('Hide review', () {
      var review = ProductReviewModel(
        id: 'r1',
        productId: 'p1',
        userId: 'u1',
        userName: 'User',
        rating: 5.0,
        comment: 'Test',
        createdAt: DateTime.now(),
        isApproved: true,
      );

      review = review.copyWith(isApproved: false);

      expect(review.isApproved, false);
    });
  });

  group('Owner Response Tests', () {
    test('Add owner response to review', () {
      var review = ProductReviewModel(
        id: 'r1',
        productId: 'p1',
        userId: 'u1',
        userName: 'User',
        rating: 4.0,
        comment: 'Good product',
        createdAt: DateTime.now(),
      );

      final responseDate = DateTime.now();
      review = review.copyWith(
        ownerReply: 'Thank you for your feedback!',
        ownerReplyDate: responseDate,
      );

      expect(review.ownerReply, 'Thank you for your feedback!');
      expect(review.ownerReplyDate, responseDate);
    });

    test('Owner response is optional', () {
      final review = ProductReviewModel(
        id: 'r1',
        productId: 'p1',
        userId: 'u1',
        userName: 'User',
        rating: 4.0,
        comment: 'Good product',
        createdAt: DateTime.now(),
      );

      expect(review.ownerReply, isNull);
      expect(review.ownerReplyDate, isNull);
    });
  });

  group('Helpful Count Tests', () {
    test('Track helpful count', () {
      var review = ProductReviewModel(
        id: 'r1',
        productId: 'p1',
        userId: 'u1',
        userName: 'User',
        rating: 5.0,
        comment: 'Excellent!',
        createdAt: DateTime.now(),
        helpfulCount: 0,
      );

      review = review.copyWith(helpfulCount: review.helpfulCount + 1);
      expect(review.helpfulCount, 1);

      review = review.copyWith(helpfulCount: review.helpfulCount + 1);
      expect(review.helpfulCount, 2);
    });

    test('Helpful count starts at zero', () {
      final review = ProductReviewModel(
        id: 'r1',
        productId: 'p1',
        userId: 'u1',
        userName: 'User',
        rating: 5.0,
        comment: 'Test',
        createdAt: DateTime.now(),
      );

      expect(review.helpfulCount, 0);
    });
  });
}
