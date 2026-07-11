import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_review_model.dart';
import '../models/delivery_feedback_model.dart';

class ReviewService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Product Reviews Methods

  /// Submit product reviews after delivery
  Future<List<ProductReviewModel>> submitProductReviews(
    List<ProductReviewModel> reviews,
  ) async {
    try {
      final reviewsData = reviews.map((r) => r.toJson()).toList();
      
      final response = await _supabase
          .from('product_reviews')
          .insert(reviewsData)
          .select();

      return (response as List)
          .map((item) => ProductReviewModel.fromJson(item))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to submit reviews: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error submitting reviews: $e');
    }
  }

  /// Get product reviews with filters
  Future<List<ProductReviewModel>> getProductReviews({
    String? productId,
    int? rating,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool? onlyFlagged,
    int limit = 100,
  }) async {
    try {
      var query = _supabase
          .from('product_reviews')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      if (productId != null) {
        query = query.eq('product_id', productId);
      }

      if (rating != null) {
        query = query.eq('rating', rating);
      }

      if (dateFrom != null) {
        query = query.gte('created_at', dateFrom.toIso8601String());
      }

      if (dateTo != null) {
        query = query.lte('created_at', dateTo.toIso8601String());
      }

      if (onlyFlagged == true) {
        query = query.eq('is_flagged', true);
      }

      final response = await query;
      
      return (response as List)
          .map((item) => ProductReviewModel.fromJson(item))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch reviews: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching reviews: $e');
    }
  }

  /// Get reviews for a specific order
  Future<List<ProductReviewModel>> getOrderReviews(String orderId) async {
    try {
      final response = await _supabase
          .from('product_reviews')
          .select()
          .eq('order_id', orderId);

      return (response as List)
          .map((item) => ProductReviewModel.fromJson(item))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch order reviews: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Check if order can be reviewed (is delivered)
  Future<bool> canReviewOrder(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('status')
          .eq('id', orderId)
          .single();

      final status = response['status'] as String;
      return status == 'delivered';
    } on PostgrestException catch (e) {
      throw Exception('Failed to check order status: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Flag a review as quality issue
  Future<ProductReviewModel> flagReview(
    String reviewId,
    String reason,
  ) async {
    try {
      final response = await _supabase
          .from('product_reviews')
          .update({
            'is_flagged': true,
            'flag_reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reviewId)
          .select()
          .single();

      return ProductReviewModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to flag review: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Resolve a flagged review
  Future<ProductReviewModel> resolveReview(String reviewId) async {
    try {
      final response = await _supabase
          .from('product_reviews')
          .update({
            'resolved': true,
            'resolved_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reviewId)
          .select()
          .single();

      return ProductReviewModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to resolve review: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Get product review statistics
  Future<Map<String, dynamic>> getProductStats(String productId) async {
    try {
      final reviews = await getProductReviews(productId: productId);
      
      if (reviews.isEmpty) {
        return {
          'avgRating': 0.0,
          'count': 0,
          'totalRatings': 0,
          'distribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        };
      }

      final avgRating =
          reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
      
      final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (var review in reviews) {
        distribution[review.rating] = (distribution[review.rating] ?? 0) + 1;
      }

      return {
        'avgRating': avgRating,
        'count': reviews.length,
        'totalRatings': reviews.map((r) => r.rating).reduce((a, b) => a + b),
        'distribution': distribution,
      };
    } catch (e) {
      throw Exception('Failed to get product stats: $e');
    }
  }

  // Delivery Feedback Methods

  /// Submit delivery service feedback
  Future<DeliveryFeedbackModel> submitDeliveryFeedback(
    DeliveryFeedbackModel feedback,
  ) async {
    try {
      final response = await _supabase
          .from('delivery_feedback')
          .insert(feedback.toJson())
          .select()
          .single();

      return DeliveryFeedbackModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to submit feedback: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Get delivery feedback for employee
  Future<List<DeliveryFeedbackModel>> getEmployeeFeedback(
    String employeeId, {
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 50,
  }) async {
    try {
      var query = _supabase
          .from('delivery_feedback')
          .select()
          .eq('employee_id', employeeId)
          .order('created_at', ascending: false)
          .limit(limit);

      if (dateFrom != null) {
        query = query.gte('created_at', dateFrom.toIso8601String());
      }

      if (dateTo != null) {
        query = query.lte('created_at', dateTo.toIso8601String());
      }

      final response = await query;

      return (response as List)
          .map((item) => DeliveryFeedbackModel.fromJson(item))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch feedback: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Get employee performance statistics
  Future<Map<String, dynamic>> getEmployeeStats(String employeeId) async {
    try {
      final feedback = await getEmployeeFeedback(employeeId);

      if (feedback.isEmpty) {
        return {
          'avgRating': 0.0,
          'totalFeedback': 0,
          'distribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        };
      }

      final avgRating = feedback.map((f) => f.serviceRating).reduce((a, b) => a + b) /
          feedback.length;

      final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (var fb in feedback) {
        distribution[fb.serviceRating] =
            (distribution[fb.serviceRating] ?? 0) + 1;
      }

      // Calculate tag-based metrics
      final tagCounts = <String, int>{};
      for (var fb in feedback) {
        for (var tag in fb.tags) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }

      final tagPercentages = <String, double>{};
      for (var tag in tagCounts.keys) {
        tagPercentages[tag] = (tagCounts[tag]! / feedback.length) * 100;
      }

      return {
        'avgRating': avgRating,
        'totalFeedback': feedback.length,
        'distribution': distribution,
        'tagPercentages': tagPercentages,
      };
    } catch (e) {
      throw Exception('Failed to get employee stats: $e');
    }
  }

  /// Delete a review (soft delete by marking resolved)
  Future<void> deleteReview(String reviewId) async {
    try {
      await _supabase
          .from('product_reviews')
          .delete()
          .eq('id', reviewId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete review: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Search reviews by text
  Future<List<ProductReviewModel>> searchReviews(String query) async {
    try {
      final response = await _supabase
          .from('product_reviews')
          .select()
          .ilike('review_text', '%$query%')
          .limit(50);

      return (response as List)
          .map((item) => ProductReviewModel.fromJson(item))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to search reviews: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }
}
