import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_review_model.dart';
import '../services/product_service.dart';

class ReviewProvider extends ChangeNotifier {
  final ProductService _productService = ProductService();
  
  List<ProductReviewModel> _reviews = [];
  bool _isLoading = false;
  String? _error;
  
  // Rating distribution
  Map<int, int> _ratingDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
  double _averageRating = 0.0;
  
  // Getters
  List<ProductReviewModel> get reviews => _reviews;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<int, int> get ratingDistribution => _ratingDistribution;
  double get averageRating => _averageRating;

  /// Fetch reviews for a product with pagination
  Future<void> fetchProductReviews(
    String productId, {
    int limit = 10,
    DocumentSnapshot? startAfter,
    String sortBy = 'recent', // recent, highest, lowest, helpful
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Query query = FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .where('isApproved', isEqualTo: true)
          .where('isFlagged', isEqualTo: false);

      // Apply sorting
      switch (sortBy) {
        case 'highest':
          query = query.orderBy('rating', descending: true);
          break;
        case 'lowest':
          query = query.orderBy('rating', descending: false);
          break;
        case 'helpful':
          query = query.orderBy('helpfulCount', descending: true);
          break;
        case 'recent':
        default:
          query = query.orderBy('createdAt', descending: true);
      }

      query = query.limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      _reviews = snapshot.docs
          .map((doc) => ProductReviewModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      _calculateRatingDistribution(productId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calculate rating distribution for a product
  Future<void> _calculateRatingDistribution(String productId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .where('isApproved', isEqualTo: true)
          .where('isFlagged', isEqualTo: false)
          .get();

      _ratingDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      double totalRating = 0;

      for (var doc in snapshot.docs) {
        final review = ProductReviewModel.fromMap(doc.data());
        final rating = review.rating.toInt();
        if (_ratingDistribution.containsKey(rating)) {
          _ratingDistribution[rating] = _ratingDistribution[rating]! + 1;
        }
        totalRating += review.rating;
      }

      _averageRating = snapshot.docs.isEmpty ? 0 : totalRating / snapshot.docs.length;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Submit a new review
  Future<void> submitReview(ProductReviewModel review) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _productService.addProductReview(review);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Add shop owner response to a review
  Future<void> addOwnerResponse(
    String productId,
    String reviewId,
    String response,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .doc(reviewId)
          .update({
            'ownerReply': response,
            'ownerReplyDate': FieldValue.serverTimestamp(),
          });
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Flag a review for moderation
  Future<void> flagReview(
    String productId,
    String reviewId,
    List<String> reasons,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .doc(reviewId)
          .update({
            'isFlagged': true,
            'flagReasons': reasons,
          });
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Mark review as helpful
  Future<void> markAsHelpful(String productId, String reviewId) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .doc(reviewId)
          .update({
            'helpfulCount': FieldValue.increment(1),
          });
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Check if user has already reviewed this product from a specific order
  Future<bool> hasUserReviewedProduct(
    String productId,
    String userId,
    String orderId,
  ) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .where('userId', isEqualTo: userId)
          .where('orderId', isEqualTo: orderId)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Get reviews for moderation (admin)
  Future<List<ProductReviewModel>> getFlaggedReviews() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('reviews')
          .where('isFlagged', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ProductReviewModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Approve a flagged review (admin)
  Future<void> approveReview(String productId, String reviewId) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .doc(reviewId)
          .update({
            'isFlagged': false,
            'isApproved': true,
          });
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Hide a review (admin)
  Future<void> hideReview(String productId, String reviewId) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .doc(reviewId)
          .update({
            'isApproved': false,
          });
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Clear reviews list
  void clearReviews() {
    _reviews = [];
    _ratingDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    _averageRating = 0.0;
    notifyListeners();
  }
}
