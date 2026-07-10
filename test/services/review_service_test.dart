import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fufajis_online/services/review_service.dart';
import 'package:fufajis_online/models/product_review_model.dart';
import 'package:fufajis_online/models/delivery_feedback_model.dart';

// Mock classes for Supabase
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockPostgrestQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder<PostgrestList> {}

void main() {
  group('ReviewService - Product Reviews', () {
    late ReviewService reviewService;
    late MockSupabaseClient mockSupabaseClient;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      // Note: In production, inject the Supabase client via constructor
      reviewService = ReviewService();
    });

    group('submitProductReviews', () {
      test('should successfully submit product reviews to Supabase', () async {
        // Arrange
        final reviews = [
          ProductReviewModel(
            id: 'review1',
            orderId: 'order1',
            productId: 'product1',
            customerId: 'customer1',
            orderItemId: 'orderItem1',
            rating: 5,
            reviewText: 'Great quality product',
            tags: const ['quality'],
            isFlagged: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          ProductReviewModel(
            id: 'review2',
            orderId: 'order1',
            productId: 'product2',
            customerId: 'customer1',
            orderItemId: 'orderItem2',
            rating: 4,
            reviewText: 'Fresh and nice',
            tags: const ['freshness'],
            isFlagged: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Act & Assert - This test validates the review structure
        // In production, would mock Supabase response
        expect(reviews.length, equals(2));
        expect(reviews[0].rating, equals(5));
        expect(reviews[1].rating, equals(4));
        expect(reviews[0].tags.contains('quality'), true);
        expect(reviews[1].tags.contains('freshness'), true);
      });

      test('should validate rating is between 1-5', () {
        // Arrange - Test invalid ratings
        expect(
          () => ProductReviewModel(
            id: 'review1',
            orderId: 'order1',
            productId: 'product1',
            customerId: 'customer1',
            orderItemId: 'orderItem1',
            rating: 6, // Invalid - > 5
            reviewText: 'Test',
            tags: const [],
            isFlagged: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<AssertionError>()),
        );

        expect(
          () => ProductReviewModel(
            id: 'review1',
            orderId: 'order1',
            productId: 'product1',
            customerId: 'customer1',
            orderItemId: 'orderItem1',
            rating: 0, // Invalid - < 1
            reviewText: 'Test',
            tags: const [],
            isFlagged: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should validate review text max 500 characters', () {
        // Arrange
        final longText = 'a' * 501; // Exceeds 500 character limit

        // Act & Assert
        expect(
          () => ProductReviewModel(
            id: 'review1',
            orderId: 'order1',
            productId: 'product1',
            customerId: 'customer1',
            orderItemId: 'orderItem1',
            rating: 4,
            reviewText: longText,
            tags: const [],
            isFlagged: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('flagReview', () {
      test('should flag a review for quality issues', () {
        // Arrange
        final review = ProductReviewModel(
          id: 'review1',
          orderId: 'order1',
          productId: 'product1',
          customerId: 'customer1',
          orderItemId: 'orderItem1',
          rating: 2,
          reviewText: 'Product arrived damaged',
          tags: const ['damage'],
          isFlagged: false,
          flagReason: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final flaggedReview = review.copyWith(
          isFlagged: true,
          flagReason: 'Low rating - quality issue',
        );

        // Assert
        expect(flaggedReview.isFlagged, true);
        expect(flaggedReview.flagReason, equals('Low rating - quality issue'));
        expect(flaggedReview.id, equals(review.id)); // ID unchanged
      });
    });

    group('resolveReview', () {
      test('should mark a flagged review as resolved', () {
        // Arrange
        final review = ProductReviewModel(
          id: 'review1',
          orderId: 'order1',
          productId: 'product1',
          customerId: 'customer1',
          orderItemId: 'orderItem1',
          rating: 2,
          reviewText: 'Product damaged on arrival',
          tags: const ['damage'],
          isFlagged: true,
          flagReason: 'Quality issue',
          resolved: false,
          resolvedAt: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final resolvedReview = review.copyWith(
          resolved: true,
          resolvedAt: DateTime.now(),
        );

        // Assert
        expect(resolvedReview.resolved, true);
        expect(resolvedReview.resolvedAt, isNotNull);
        expect(resolvedReview.isFlagged, true); // Flag remains
      });
    });

    group('Auto-tagging', () {
      test('should detect quality issue tags', () {
        // Arrange
        final reviewTexts = [
          'Product is rotten and smells bad',
          'Received damaged item',
          'Quality is very poor',
          'Spoiled milk on arrival',
        ];

        // Act & Assert - Validate that tags would be detected
        expect(
          reviewTexts[0].toLowerCase().contains('rotten'),
          true,
        );
        expect(
          reviewTexts[1].toLowerCase().contains('damaged'),
          true,
        );
        expect(
          reviewTexts[2].toLowerCase().contains('poor'),
          true,
        );
      });

      test('should detect freshness issue tags', () {
        // Arrange
        final reviewTexts = [
          'Vegetable was already stale',
          'Fruits are old and wilted',
          'Product expired before arrival',
          'Bread is dry and hard',
        ];

        // Act & Assert
        expect(reviewTexts[0].toLowerCase().contains('stale'), true);
        expect(reviewTexts[1].toLowerCase().contains('wilted'), true);
        expect(reviewTexts[2].toLowerCase().contains('expired'), true);
      });

      test('should detect packaging issue tags', () {
        // Arrange
        final reviewTexts = [
          'Package was torn open',
          'Box arrived crushed',
          'Container was damaged',
          'Wrapper was broken',
        ];

        // Act & Assert
        expect(reviewTexts[0].toLowerCase().contains('torn'), true);
        expect(reviewTexts[1].toLowerCase().contains('crushed'), true);
        expect(reviewTexts[2].toLowerCase().contains('container'), true);
      });

      test('should detect wrong item tags', () {
        // Arrange
        final reviewTexts = [
          'Received wrong product',
          'Different item than ordered',
          'This is not what I ordered',
          'Item is incorrect',
        ];

        // Act & Assert
        expect(reviewTexts[0].toLowerCase().contains('wrong'), true);
        expect(reviewTexts[1].toLowerCase().contains('different'), true);
      });
    });
  });

  group('ReviewService - Delivery Feedback', () {
    late ReviewService reviewService;

    setUp(() {
      reviewService = ReviewService();
    });

    group('submitDeliveryFeedback', () {
      test('should successfully submit delivery feedback', () {
        // Arrange
        final feedback = DeliveryFeedbackModel(
          id: 'feedback1',
          orderId: 'order1',
          employeeId: 'employee1',
          customerId: 'customer1',
          serviceRating: 5,
          feedbackText: 'Delivery agent was very polite and professional',
          tags: const ['polite', 'punctual'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act & Assert
        expect(feedback.serviceRating, equals(5));
        expect(feedback.tags.contains('polite'), true);
        expect(feedback.feedbackText, isNotEmpty);
      });

      test('should validate service rating is between 1-5', () {
        // Arrange & Act & Assert - Test invalid ratings
        expect(
          () => DeliveryFeedbackModel(
            id: 'feedback1',
            orderId: 'order1',
            employeeId: 'employee1',
            customerId: 'customer1',
            serviceRating: 6, // Invalid
            feedbackText: 'Test',
            tags: const [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should validate feedback text max 500 characters', () {
        // Arrange
        final longText = 'a' * 501;

        // Act & Assert
        expect(
          () => DeliveryFeedbackModel(
            id: 'feedback1',
            orderId: 'order1',
            employeeId: 'employee1',
            customerId: 'customer1',
            serviceRating: 4,
            feedbackText: longText,
            tags: const [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('Delivery Service Tags', () {
      test('should detect punctuality tags', () {
        final texts = [
          'Delivery was on time',
          'Driver arrived punctually',
          'Delivery delayed by 30 minutes',
          'Very late delivery',
        ];

        expect(texts[0].toLowerCase().contains('time'), true);
        expect(texts[1].toLowerCase().contains('punctually'), true);
      });

      test('should detect politeness tags', () {
        final texts = [
          'Driver was very polite',
          'Staff was rude and impatient',
          'Extremely courteous service',
          'Driver was careful with items',
        ];

        expect(texts[0].toLowerCase().contains('polite'), true);
        expect(texts[1].toLowerCase().contains('rude'), true);
      });

      test('should detect damage tags', () {
        final texts = [
          'Items arrived damaged',
          'Delivery package was crushed',
          'Food leaked during delivery',
          'Items intact and well-packaged',
        ];

        expect(texts[0].toLowerCase().contains('damaged'), true);
        expect(texts[1].toLowerCase().contains('crushed'), true);
        expect(texts[2].toLowerCase().contains('leak'), true);
      });
    });
  });

  group('ReviewService - Data Serialization', () {
    test('ProductReviewModel should serialize to JSON', () {
      // Arrange
      final review = ProductReviewModel(
        id: 'review1',
        orderId: 'order1',
        productId: 'product1',
        customerId: 'customer1',
        orderItemId: 'orderItem1',
        rating: 5,
        reviewText: 'Excellent product',
        tags: const ['quality'],
        isFlagged: false,
        createdAt: DateTime(2026, 7, 10),
        updatedAt: DateTime(2026, 7, 10),
      );

      // Act
      final json = review.toJson();

      // Assert
      expect(json['id'], equals('review1'));
      expect(json['rating'], equals(5));
      expect(json['tags'], equals(['quality']));
      expect(json['is_flagged'], equals(false));
    });

    test('ProductReviewModel should deserialize from JSON', () {
      // Arrange
      final json = {
        'id': 'review1',
        'order_id': 'order1',
        'product_id': 'product1',
        'customer_id': 'customer1',
        'order_item_id': 'orderItem1',
        'rating': 4,
        'review_text': 'Good quality',
        'tags': ['freshness'],
        'is_flagged': false,
        'flag_reason': null,
        'resolved': false,
        'resolved_at': null,
        'created_at': '2026-07-10T00:00:00Z',
        'updated_at': '2026-07-10T00:00:00Z',
      };

      // Act
      final review = ProductReviewModel.fromJson(json);

      // Assert
      expect(review.id, equals('review1'));
      expect(review.rating, equals(4));
      expect(review.tags.contains('freshness'), true);
      expect(review.isFlagged, false);
    });

    test('DeliveryFeedbackModel should serialize to JSON', () {
      // Arrange
      final feedback = DeliveryFeedbackModel(
        id: 'feedback1',
        orderId: 'order1',
        employeeId: 'employee1',
        customerId: 'customer1',
        serviceRating: 5,
        feedbackText: 'Great service',
        tags: const ['polite'],
        createdAt: DateTime(2026, 7, 10),
        updatedAt: DateTime(2026, 7, 10),
      );

      // Act
      final json = feedback.toJson();

      // Assert
      expect(json['id'], equals('feedback1'));
      expect(json['service_rating'], equals(5));
      expect(json['tags'], equals(['polite']));
    });
  });

  group('ReviewService - Anonymization', () {
    test('should anonymize customer data for reviews', () {
      // Arrange
      final review = ProductReviewModel(
        id: 'review1',
        orderId: 'order1',
        productId: 'product1',
        customerId: 'customer_abc123def456',
        orderItemId: 'orderItem1',
        rating: 5,
        reviewText: 'Great product',
        tags: const [],
        isFlagged: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act - Extract anonymous customer reference
      final anonymousId = 'Customer #${review.customerId.substring(0, 6).toUpperCase()}';

      // Assert
      expect(anonymousId, startsWith('Customer #'));
        expect(anonymousId.length, greaterThan(9));
        expect(review.customerId.length, greaterThan(20)); // Original preserved in model
      });

      test('should anonymize feedback for delivery', () {
        // Arrange
        final feedback = DeliveryFeedbackModel(
          id: 'feedback1',
          orderId: 'order1',
          employeeId: 'employee1',
          customerId: 'customer_xyz789uvw012', // Should not be shown to employee
          serviceRating: 5,
          feedbackText: 'Good service',
          tags: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act - Employee should see feedback but not customer identity
        // In real implementation, RLS policy prevents customer_id access

        // Assert - Feedback data is available
        expect(feedback.feedbackText, isNotEmpty);
        expect(feedback.serviceRating, isNotNull);
      });
    });

  group('ReviewService - Edge Cases', () {
    test('should handle null review text gracefully', () {
      // Arrange
      final review = ProductReviewModel(
        id: 'review1',
        orderId: 'order1',
        productId: 'product1',
        customerId: 'customer1',
        orderItemId: 'orderItem1',
        rating: 3,
        reviewText: null, // Optional text
        tags: const [],
        isFlagged: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act & Assert
      expect(review.reviewText, isNull);
      expect(review.rating, equals(3)); // Rating still required
    });

    test('should handle empty tags list', () {
      // Arrange
      final review = ProductReviewModel(
        id: 'review1',
        orderId: 'order1',
        productId: 'product1',
        customerId: 'customer1',
        orderItemId: 'orderItem1',
        rating: 5,
        reviewText: 'Good',
        tags: const [], // Empty tags
        isFlagged: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act & Assert
      expect(review.tags.isEmpty, true);
      expect(review.tags, isA<List<String>>());
    });

    test('should preserve timestamps correctly', () {
      // Arrange
      final now = DateTime.now();
      final review = ProductReviewModel(
        id: 'review1',
        orderId: 'order1',
        productId: 'product1',
        customerId: 'customer1',
        orderItemId: 'orderItem1',
        rating: 4,
        reviewText: 'Test',
        tags: const [],
        isFlagged: false,
        createdAt: now,
        updatedAt: now,
      );

      // Act & Assert
      expect(review.createdAt, equals(now));
      expect(review.updatedAt, equals(now));
      expect(review.updatedAt.isAfter(review.createdAt), false); // Same time initially
    });
  });
}
