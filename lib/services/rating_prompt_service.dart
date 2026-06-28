import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../constants/order_status.dart';

/// Service to manage rating prompts after order delivery
class RatingPromptService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Check if an order is eligible for rating prompt
  /// Returns true if:
  /// - Order is delivered
  /// - Delivery was within 7 days
  /// - User hasn't already rated the products
  Future<bool> isEligibleForRating(OrderModel order) async {
    // Check if order is delivered
    if (order.status != OrderStatus.delivered) {
      return false;
    }

    // Check if delivery was within 7 days
    final deliveryDate = order.updatedAt;
    final now = DateTime.now();
    final daysSinceDelivery = now.difference(deliveryDate).inDays;

    if (daysSinceDelivery > 7) {
      return false;
    }

    // Check if user has already rated any product from this order
    for (var item in order.items) {
      final hasReviewed = await _hasUserReviewedProduct(
        item.productId,
        order.customerId,
        order.id,
      );

      if (!hasReviewed) {
        return true; // At least one product hasn't been reviewed
      }
    }

    return false;
  }

  /// Get products from an order that haven't been reviewed yet
  Future<List<OrderItem>> getUnreviewedProducts(OrderModel order) async {
    final unreviewed = <OrderItem>[];

    for (var item in order.items) {
      final hasReviewed = await _hasUserReviewedProduct(
        item.productId,
        order.customerId,
        order.id,
      );

      if (!hasReviewed) {
        unreviewed.add(item);
      }
    }

    return unreviewed;
  }

  /// Check if user has already reviewed a specific product from an order
  Future<bool> _hasUserReviewedProduct(
    String productId,
    String userId,
    String orderId,
  ) async {
    try {
      final snapshot = await _db
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .where('userId', isEqualTo: userId)
          .where('orderId', isEqualTo: orderId)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking review: $e');
      return false;
    }
  }

  /// Get remaining days for rating (max 7 days from delivery)
  int getRemainingDaysForRating(OrderModel order) {
    final deliveryDate = order.updatedAt;
    final now = DateTime.now();
    final daysSinceDelivery = now.difference(deliveryDate).inDays;
    final remainingDays = 7 - daysSinceDelivery;

    return remainingDays > 0 ? remainingDays : 0;
  }

  /// Mark that a rating prompt has been shown for an order
  /// This prevents showing the prompt multiple times
  Future<void> markRatingPromptShown(String orderId) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'ratingPromptShown': true,
        'ratingPromptShownAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking rating prompt: $e');
    }
  }

  /// Check if rating prompt has already been shown for this order
  Future<bool> hasRatingPromptBeenShown(String orderId) async {
    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      return doc.data()?['ratingPromptShown'] ?? false;
    } catch (e) {
      print('Error checking rating prompt: $e');
      return false;
    }
  }
}
