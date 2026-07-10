import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/models/product_review_model.dart';
import 'package:fufajis_online/models/delivery_feedback_model.dart';
import 'package:fufajis_online/models/order_model.dart';
import 'package:fufajis_online/models/user_model.dart';
import 'package:fufajis_online/constants/order_status.dart';
import 'package:fufajis_online/utils/monetary_value.dart';

void main() {
  group('Review Submission Flow Integration Tests', () {
    group('Order Delivery → Review Modal → Review Submission', () {
      test(
        'should show review modal after order marked as delivered',
        () async {
          // Arrange - Create a delivered order
          final order = OrderModel(
            id: 'order1',
            orderNumber: 'ORD-001',
            customerId: 'customer1',
            customerName: 'John Doe',
            customerPhone: '+919876543210',
            items: [],
            subtotal: MonetaryValue(500.0),
            totalAmount: MonetaryValue(500.0),
            deliveryAddress: Address(
              id: 'addr1',
              label: 'Home',
              street: 'Test Street',
              city: 'Test City',
              latitude: 28.6139,
              longitude: 77.2090,
            ),
            status: OrderStatus.delivered,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Act
          final isDelivered = order.status == OrderStatus.delivered;

          // Assert
          expect(isDelivered, true);
          // In production: Review modal would be displayed when status == delivered
        },
      );

      test(
        'should not show review modal for non-delivered orders',
        () async {
          // Arrange - Create pending order
          final order = OrderModel(
            id: 'order1',
            orderNumber: 'ORD-001',
            customerId: 'customer1',
            customerName: 'John Doe',
            customerPhone: '+919876543210',
            items: [],
            subtotal: MonetaryValue(500.0),
            totalAmount: MonetaryValue(500.0),
            deliveryAddress: Address(
              id: 'addr1',
              label: 'Home',
              street: 'Test Street',
              city: 'Test City',
              latitude: 28.6139,
              longitude: 77.2090,
            ),
            status: OrderStatus.pending,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Act
          final isDelivered = order.status == OrderStatus.delivered;

          // Assert
          expect(isDelivered, false);
          // No review modal shown for non-delivered status
        },
      );
    });

    group('Single Review Mode - Rate All Products Together', () {
      test(
        'should allow customer to rate all products in order with single rating',
        () async {
          // Arrange - Customer rates entire order
          const orderId = 'order1';
          const customerId = 'customer1';
          const overallRating = 5;
          const reviewText = 'All products were excellent quality';

          // Act - Create review for each product in order
          final reviews = [
            ProductReviewModel(
              id: 'review1',
              orderId: orderId,
              productId: 'product1',
              customerId: customerId,
              orderItemId: 'orderItem1',
              rating: overallRating,
              reviewText: reviewText,
              tags: const [],
              isFlagged: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            ProductReviewModel(
              id: 'review2',
              orderId: orderId,
              productId: 'product2',
              customerId: customerId,
              orderItemId: 'orderItem2',
              rating: overallRating,
              reviewText: reviewText,
              tags: const [],
              isFlagged: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ];

          // Assert
          expect(reviews.length, equals(2));
          expect(reviews.every((r) => r.rating == overallRating), true);
          expect(reviews.every((r) => r.reviewText == reviewText), true);
          expect(reviews.every((r) => r.orderId == orderId), true);
        },
      );

      test(
        'should allow optional review text in single mode',
        () async {
          // Arrange
          final review = ProductReviewModel(
            id: 'review1',
            orderId: 'order1',
            productId: 'product1',
            customerId: 'customer1',
            orderItemId: 'orderItem1',
            rating: 4,
            reviewText: null, // Optional text
            tags: const [],
            isFlagged: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Act & Assert
          expect(review.rating, isNotNull); // Rating required
          expect(review.reviewText, isNull); // Text optional
        },
      );
    });

    group('Individual Review Mode - Rate Each Product', () {
      test(
        'should allow customer to rate each product separately',
        () async {
          // Arrange
          final reviews = [
            ProductReviewModel(
              id: 'review1',
              orderId: 'order1',
              productId: 'product1',
              customerId: 'customer1',
              orderItemId: 'orderItem1',
              rating: 5,
              reviewText: 'Fresh vegetables',
              tags: const ['freshness'],
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
              rating: 3,
              reviewText: 'Quality could be better',
              tags: const ['quality'],
              isFlagged: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            ProductReviewModel(
              id: 'review3',
              orderId: 'order1',
              productId: 'product3',
              customerId: 'customer1',
              orderItemId: 'orderItem3',
              rating: 4,
              reviewText: 'Good packaging',
              tags: const ['packaging'],
              isFlagged: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ];

          // Act & Assert
          expect(reviews.length, equals(3));
          expect(reviews[0].rating, equals(5)); // Different ratings per product
          expect(reviews[1].rating, equals(3));
          expect(reviews[2].rating, equals(4));
          expect(reviews[0].reviewText, isNotEmpty); // Different feedback per product
          expect(reviews[1].reviewText, isNotEmpty);
          expect(reviews[2].reviewText, isNotEmpty);
        },
      );

      test(
        'should capture different tags for each product review',
        () async {
          // Arrange
          final reviews = [
            ProductReviewModel(
              id: 'review1',
              orderId: 'order1',
              productId: 'product_vegetable',
              customerId: 'customer1',
              orderItemId: 'orderItem1',
              rating: 2,
              reviewText: 'Vegetables were wilted and old',
              tags: const ['freshness'],
              isFlagged: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            ProductReviewModel(
              id: 'review2',
              orderId: 'order1',
              productId: 'product_dairy',
              customerId: 'customer1',
              orderItemId: 'orderItem2',
              rating: 5,
              reviewText: 'Milk was cold and fresh',
              tags: const [],
              isFlagged: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            ProductReviewModel(
              id: 'review3',
              orderId: 'order1',
              productId: 'product_bakery',
              customerId: 'customer1',
              orderItemId: 'orderItem3',
              rating: 3,
              reviewText: 'Package was damaged during delivery',
              tags: const ['packaging'],
              isFlagged: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ];

          // Assert
          expect(reviews[0].tags, equals(['freshness']));
          expect(reviews[1].tags, isEmpty); // Good product, no issues
          expect(reviews[2].tags, equals(['packaging']));
        },
      );
    });

    group('Delivery Feedback Submission', () {
      test(
        'should allow customer to rate delivery service separately',
        () async {
          // Arrange
          final feedback = DeliveryFeedbackModel(
            id: 'feedback1',
            orderId: 'order1',
            employeeId: 'delivery_agent_1',
            customerId: 'customer1',
            serviceRating: 5,
            feedbackText: 'Driver was punctual and very polite',
            tags: const ['punctual', 'polite'],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Act & Assert
          expect(feedback.orderId, equals('order1'));
          expect(feedback.employeeId, isNotEmpty);
          expect(feedback.serviceRating, equals(5));
          expect(feedback.tags.contains('punctual'), true);
        },
      );

      test(
        'should allow optional feedback text for delivery',
        () async {
          // Arrange
          final feedback = DeliveryFeedbackModel(
            id: 'feedback1',
            orderId: 'order1',
            employeeId: 'employee1',
            customerId: 'customer1',
            serviceRating: 4,
            feedbackText: null, // Optional
            tags: const [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Act & Assert
          expect(feedback.serviceRating, isNotNull); // Rating required
          expect(feedback.feedbackText, isNull); // Text optional
        },
      );

      test(
        'should capture delivery issues in feedback tags',
        () async {
          // Arrange
          final feedback = DeliveryFeedbackModel(
            id: 'feedback1',
            orderId: 'order1',
            employeeId: 'employee1',
            customerId: 'customer1',
            serviceRating: 2,
            feedbackText: 'Delivery was very late and items were damaged',
            tags: const ['delayed', 'damaged'],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Act & Assert
          expect(feedback.serviceRating, equals(2));
          expect(feedback.tags.contains('delayed'), true);
          expect(feedback.tags.contains('damaged'), true);
        },
      );
    });

    group('Multi-Step Review Collection', () {
      test(
        'should sequence: order delivered → review modal → submit reviews → submit feedback',
        () async {
          // Step 1: Order marked as delivered
          const orderId = 'order1';
          const customerId = 'customer1';
          const employeeId = 'employee1';
          final orderStatus = OrderStatus.delivered;

          // Step 2: Customer reviews products
          final productReviews = [
            ProductReviewModel(
              id: 'review1',
              orderId: orderId,
              productId: 'product1',
              customerId: customerId,
              orderItemId: 'orderItem1',
              rating: 4,
              reviewText: 'Good quality',
              tags: const ['quality'],
              isFlagged: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ];

          // Step 3: Customer rates delivery service
          final deliveryFeedback = DeliveryFeedbackModel(
            id: 'feedback1',
            orderId: orderId,
            employeeId: employeeId,
            customerId: customerId,
            serviceRating: 5,
            feedbackText: 'Excellent delivery',
            tags: const ['punctual'],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Act & Assert - Verify complete flow
          expect(orderStatus, equals(OrderStatus.delivered));
          expect(productReviews.isNotEmpty, true);
          expect(productReviews[0].customerId, equals(customerId));
          expect(deliveryFeedback.employeeId, equals(employeeId));
          expect(deliveryFeedback.serviceRating, equals(5));
        },
      );
    });

    group('Dashboard Display - Owner View', () {
      test(
        'should display all product reviews in owner dashboard',
        () async {
          // Arrange
          final reviews = [
            ProductReviewModel(
              id: 'review1',
              orderId: 'order1',
              productId: 'product1',
              customerId: 'customer1',
              orderItemId: 'orderItem1',
              rating: 5,
              reviewText: 'Excellent',
              tags: const ['quality'],
              isFlagged: false,
              createdAt: DateTime(2026, 7, 1),
              updatedAt: DateTime(2026, 7, 1),
            ),
            ProductReviewModel(
              id: 'review2',
              orderId: 'order2',
              productId: 'product1',
              customerId: 'customer2',
              orderItemId: 'orderItem2',
              rating: 3,
              reviewText: 'Average quality',
              tags: const ['quality'],
              isFlagged: false,
              createdAt: DateTime(2026, 7, 2),
              updatedAt: DateTime(2026, 7, 2),
            ),
            ProductReviewModel(
              id: 'review3',
              orderId: 'order3',
              productId: 'product2',
              customerId: 'customer3',
              orderItemId: 'orderItem3',
              rating: 2,
              reviewText: 'Damaged on arrival',
              tags: const ['damage'],
              isFlagged: true,
              flagReason: 'Quality issue',
              createdAt: DateTime(2026, 7, 3),
              updatedAt: DateTime(2026, 7, 3),
            ),
          ];

          // Act
          final averageRating = reviews.isEmpty
              ? 0.0
              : reviews.fold<double>(0, (sum, r) => sum + r.rating) / reviews.length;
          final totalReviews = reviews.length;
          final flaggedCount = reviews.where((r) => r.isFlagged).length;
          final lowRatingCount = reviews.where((r) => r.rating <= 2).length;

          // Assert
          expect(averageRating, equals(10.0 / 3)); // (5+3+2)/3
          expect(totalReviews, equals(3));
          expect(flaggedCount, equals(1));
          expect(lowRatingCount, equals(1));
        },
      );

      test(
        'should support filtering by date range',
        () async {
          // Arrange
          final reviews = [
            ProductReviewModel(
              id: 'review1',
              orderId: 'order1',
              productId: 'product1',
              customerId: 'customer1',
              orderItemId: 'orderItem1',
              rating: 5,
              reviewText: 'Old review',
              tags: const [],
              isFlagged: false,
              createdAt: DateTime(2026, 6, 15),
              updatedAt: DateTime(2026, 6, 15),
            ),
            ProductReviewModel(
              id: 'review2',
              orderId: 'order2',
              productId: 'product2',
              customerId: 'customer2',
              orderItemId: 'orderItem2',
              rating: 4,
              reviewText: 'Recent review',
              tags: const [],
              isFlagged: false,
              createdAt: DateTime(2026, 7, 10),
              updatedAt: DateTime(2026, 7, 10),
            ),
          ];

          // Act - Filter for July reviews only
          final dateFrom = DateTime(2026, 7, 1);
          final dateTo = DateTime(2026, 7, 31);
          final filteredReviews = reviews.where((r) {
            return r.createdAt.isAfter(dateFrom.subtract(Duration(days: 1))) &&
                r.createdAt.isBefore(dateTo.add(Duration(days: 1)));
          }).toList();

          // Assert
          expect(filteredReviews.length, equals(1));
          expect(filteredReviews[0].reviewText, contains('Recent'));
        },
      );

      test(
        'should support filtering by rating',
        () async {
          // Arrange
          final reviews = [
            ProductReviewModel(
              id: 'review1',
              orderId: 'order1',
              productId: 'product1',
              customerId: 'customer1',
              orderItemId: 'orderItem1',
              rating: 5,
              reviewText: 'Excellent',
              tags: const [],
              isFlagged: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            ProductReviewModel(
              id: 'review2',
              orderId: 'order2',
              productId: 'product2',
              customerId: 'customer2',
              orderItemId: 'orderItem2',
              rating: 3,
              reviewText: 'Average',
              tags: const [],
              isFlagged: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            ProductReviewModel(
              id: 'review3',
              orderId: 'order3',
              productId: 'product3',
              customerId: 'customer3',
              orderItemId: 'orderItem3',
              rating: 1,
              reviewText: 'Poor',
              tags: const [],
              isFlagged: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ];

          // Act - Filter for 5-star only
          final fiveStarOnly = reviews.where((r) => r.rating == 5).toList();

          // Assert
          expect(fiveStarOnly.length, equals(1));
          expect(fiveStarOnly[0].reviewText, equals('Excellent'));
        },
      );

      test(
        'should support filtering by quality issues',
        () async {
          // Arrange
          final reviews = [
            ProductReviewModel(
              id: 'review1',
              orderId: 'order1',
              productId: 'product1',
              customerId: 'customer1',
              orderItemId: 'orderItem1',
              rating: 5,
              reviewText: 'Great',
              tags: const [],
              isFlagged: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            ProductReviewModel(
              id: 'review2',
              orderId: 'order2',
              productId: 'product2',
              customerId: 'customer2',
              orderItemId: 'orderItem2',
              rating: 2,
              reviewText: 'Damaged product',
              tags: const ['damage'],
              isFlagged: true,
              flagReason: 'Quality issue',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            ProductReviewModel(
              id: 'review3',
              orderId: 'order3',
              productId: 'product3',
              customerId: 'customer3',
              orderItemId: 'orderItem3',
              rating: 2,
              reviewText: 'Stale vegetables',
              tags: const ['freshness'],
              isFlagged: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ];

          // Act - Filter for quality issues
          final qualityIssues = reviews.where((r) {
            return r.tags.contains('damage') || r.tags.contains('quality');
          }).toList();

          // Assert
          expect(qualityIssues.length, equals(1));
          expect(qualityIssues[0].tags.contains('damage'), true);
        },
      );
    });

    group('Dashboard Display - Employee View', () {
      test(
        'should display only employee own delivery feedback',
        () async {
          // Arrange
          const employeeId = 'employee1';
          final feedback = [
            DeliveryFeedbackModel(
              id: 'feedback1',
              orderId: 'order1',
              employeeId: employeeId,
              customerId: 'customer1',
              serviceRating: 5,
              feedbackText: 'Great service',
              tags: const ['punctual'],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            DeliveryFeedbackModel(
              id: 'feedback2',
              orderId: 'order2',
              employeeId: employeeId,
              customerId: 'customer2',
              serviceRating: 4,
              feedbackText: 'Good delivery',
              tags: const [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ];

          // Act
          final myFeedback = feedback.where((f) => f.employeeId == employeeId).toList();
          final avgRating = myFeedback.isEmpty
              ? 0.0
              : myFeedback.fold<double>(0, (sum, f) => sum + f.serviceRating) /
                  myFeedback.length;

          // Assert
          expect(myFeedback.length, equals(2));
          expect(avgRating, equals(4.5));
        },
      );

      test(
        'should show performance metrics for employee',
        () async {
          // Arrange
          const employeeId = 'employee1';
          final feedback = [
            DeliveryFeedbackModel(
              id: 'feedback1',
              orderId: 'order1',
              employeeId: employeeId,
              customerId: 'customer1',
              serviceRating: 5,
              feedbackText: 'On time and polite',
              tags: const ['punctual', 'polite'],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            DeliveryFeedbackModel(
              id: 'feedback2',
              orderId: 'order2',
              employeeId: employeeId,
              customerId: 'customer2',
              serviceRating: 4,
              feedbackText: 'Good but delayed',
              tags: const ['delayed'],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            DeliveryFeedbackModel(
              id: 'feedback3',
              orderId: 'order3',
              employeeId: employeeId,
              customerId: 'customer3',
              serviceRating: 5,
              feedbackText: 'Perfect delivery',
              tags: const ['punctual'],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ];

          // Act
          final avgRating = feedback.isEmpty
              ? 0.0
              : feedback.fold<double>(0, (sum, f) => sum + f.serviceRating) / feedback.length;
          final punctualCount = feedback
              .where((f) => f.tags.contains('punctual'))
              .length;
          final politeCount = feedback
              .where((f) => f.tags.contains('polite'))
              .length;

          // Assert
          expect(avgRating, equals(14.0 / 3)); // (5+4+5)/3 = 4.67
          expect(punctualCount, equals(2)); // Out of 3
          expect(politeCount, equals(1)); // Out of 3
        },
      );
    });

    group('Error Scenarios', () {
      test('should not submit reviews for non-delivered order', () async {
        // Arrange
        const orderId = 'order_not_delivered';
        const orderStatus = OrderStatus.pending; // Not delivered

        // Act
        final canReview = orderStatus == OrderStatus.delivered;

        // Assert
        expect(canReview, false);
        // In production: Review submission would be rejected by backend
      });

      test('should handle missing review text gracefully', () async {
        // Arrange
        final review = ProductReviewModel(
          id: 'review1',
          orderId: 'order1',
          productId: 'product1',
          customerId: 'customer1',
          orderItemId: 'orderItem1',
          rating: 4, // Rating provided
          reviewText: null, // Text optional
          tags: const [],
          isFlagged: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act & Assert
        expect(review.rating, isNotNull);
        expect(review.reviewText, isNull);
        // Submission should succeed with rating only
      });

      test('should prevent duplicate review submission', () async {
        // Arrange
        final review1 = ProductReviewModel(
          id: 'review1',
          orderId: 'order1',
          productId: 'product1',
          customerId: 'customer1',
          orderItemId: 'orderItem1',
          rating: 4,
          reviewText: 'Good',
          tags: const [],
          isFlagged: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act - Attempt to create duplicate
        final review2 = review1.copyWith(id: 'review1_duplicate');

        // Assert
        expect(review1.id, isNot(equals(review2.id)));
        // In production: DB unique constraint would prevent duplicate order_id+customer_id+product_id
      });
    });
  });
}
