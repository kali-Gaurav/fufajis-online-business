import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_review_model.dart';

/// Service for managing review moderation
/// Allows admins to approve/hide inappropriate reviews
class ReviewModerationSystem {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Get all flagged reviews for moderation
  Future<List<Map<String, dynamic>>> getFlaggedReviews({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _db
          .collectionGroup('reviews')
          .where('isFlagged', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final results = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Extract product ID from the path
        final pathSegments = doc.reference.path.split('/');
        final productId = pathSegments[1];

        results.add({
          'productId': productId,
          'reviewId': doc.id,
          'review': ProductReviewModel.fromMap(data),
          'docSnapshot': doc,
        });
      }

      return results;
    } catch (e) {
      print('Error getting flagged reviews: $e');
      return [];
    }
  }

  /// Get reviews pending approval
  Future<List<Map<String, dynamic>>> getPendingReviews({
    int limit = 20,
  }) async {
    try {
      final snapshot = await _db
          .collectionGroup('reviews')
          .where('isApproved', isEqualTo: false)
          .where('isFlagged', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final results = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final pathSegments = doc.reference.path.split('/');
        final productId = pathSegments[1];

        results.add({
          'productId': productId,
          'reviewId': doc.id,
          'review': ProductReviewModel.fromMap(data),
        });
      }

      return results;
    } catch (e) {
      print('Error getting pending reviews: $e');
      return [];
    }
  }

  /// Approve a flagged review
  Future<void> approveReview(String productId, String reviewId) async {
    try {
      await _db
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .doc(reviewId)
          .update({
            'isFlagged': false,
            'isApproved': true,
            'approvedAt': FieldValue.serverTimestamp(),
          });

      print('Review $reviewId approved');
    } catch (e) {
      print('Error approving review: $e');
      rethrow;
    }
  }

  /// Hide/reject a review
  Future<void> hideReview(
    String productId,
    String reviewId, {
    String? reason,
  }) async {
    try {
      await _db
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .doc(reviewId)
          .update({
            'isApproved': false,
            'isFlagged': false,
            'hiddenAt': FieldValue.serverTimestamp(),
            'hiddenReason': reason,
          });

      print('Review $reviewId hidden');
    } catch (e) {
      print('Error hiding review: $e');
      rethrow;
    }
  }

  /// Delete a review completely
  Future<void> deleteReview(String productId, String reviewId) async {
    try {
      await _db
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .doc(reviewId)
          .delete();

      print('Review $reviewId deleted');
    } catch (e) {
      print('Error deleting review: $e');
      rethrow;
    }
  }

  /// Get moderation statistics
  Future<Map<String, int>> getModerationStats() async {
    try {
      final flaggedSnapshot = await _db
          .collectionGroup('reviews')
          .where('isFlagged', isEqualTo: true)
          .get();

      final pendingSnapshot = await _db
          .collectionGroup('reviews')
          .where('isApproved', isEqualTo: false)
          .where('isFlagged', isEqualTo: false)
          .get();

      final approvedSnapshot = await _db
          .collectionGroup('reviews')
          .where('isApproved', isEqualTo: true)
          .where('isFlagged', isEqualTo: false)
          .get();

      return {
        'flagged': flaggedSnapshot.docs.length,
        'pending': pendingSnapshot.docs.length,
        'approved': approvedSnapshot.docs.length,
      };
    } catch (e) {
      print('Error getting moderation stats: $e');
      return {'flagged': 0, 'pending': 0, 'approved': 0};
    }
  }

  /// Get reviews by flag reason
  Future<Map<String, int>> getReviewsByFlagReason() async {
    try {
      final snapshot = await _db
          .collectionGroup('reviews')
          .where('isFlagged', isEqualTo: true)
          .get();

      final reasonCounts = <String, int>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final reasons = List<String>.from(data['flagReasons'] ?? []);

        for (var reason in reasons) {
          reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
        }
      }

      return reasonCounts;
    } catch (e) {
      print('Error getting flag reasons: $e');
      return {};
    }
  }

  /// Get reviews by a specific user (for checking spam)
  Future<List<ProductReviewModel>> getReviewsByUser(String userId) async {
    try {
      final snapshot = await _db
          .collectionGroup('reviews')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ProductReviewModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting user reviews: $e');
      return [];
    }
  }

  /// Check if a user is posting too many reviews (spam detection)
  Future<bool> isUserSpamming(String userId, {int reviewsInHours = 24}) async {
    try {
      final cutoffTime = DateTime.now().subtract(Duration(hours: reviewsInHours));

      final snapshot = await _db
          .collectionGroup('reviews')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThan: cutoffTime)
          .get();

      // Flag as spam if more than 5 reviews in 24 hours
      return snapshot.docs.length > 5;
    } catch (e) {
      print('Error checking spam: $e');
      return false;
    }
  }

  /// Get reviews with suspicious patterns
  Future<List<Map<String, dynamic>>> getSuspiciousReviews() async {
    try {
      final snapshot = await _db
          .collectionGroup('reviews')
          .where('isFlagged', isEqualTo: false)
          .get();

      final suspicious = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final review = ProductReviewModel.fromMap(data);

        // Check for suspicious patterns
        bool isSuspicious = false;

        // Pattern 1: Very short review with high rating
        if (review.comment.length < 5 && review.rating >= 4) {
          isSuspicious = true;
        }

        // Pattern 2: All 5-star reviews from same user
        if (review.rating == 5.0) {
          final userReviews = await getReviewsByUser(review.userId);
          if (userReviews.every((r) => r.rating == 5.0) && userReviews.length > 3) {
            isSuspicious = true;
          }
        }

        // Pattern 3: Repeated text
        if (review.comment.length > 10) {
          final wordCount = review.comment.split(' ').length;
          final uniqueWords = review.comment.split(' ').toSet().length;
          if (uniqueWords < wordCount * 0.5) {
            isSuspicious = true;
          }
        }

        if (isSuspicious) {
          final pathSegments = doc.reference.path.split('/');
          final productId = pathSegments[1];

          suspicious.add({
            'productId': productId,
            'reviewId': doc.id,
            'review': review,
            'suspiciousReasons': _getSuspiciousReasons(review),
          });
        }
      }

      return suspicious;
    } catch (e) {
      print('Error getting suspicious reviews: $e');
      return [];
    }
  }

  List<String> _getSuspiciousReasons(ProductReviewModel review) {
    final reasons = <String>[];

    if (review.comment.length < 5 && review.rating >= 4) {
      reasons.add('Very short review with high rating');
    }

    if (review.rating == 5.0) {
      reasons.add('Perfect 5-star rating');
    }

    if (review.comment.length > 10) {
      final wordCount = review.comment.split(' ').length;
      final uniqueWords = review.comment.split(' ').toSet().length;
      if (uniqueWords < wordCount * 0.5) {
        reasons.add('Repetitive text');
      }
    }

    return reasons;
  }
}
