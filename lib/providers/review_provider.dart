import 'package:flutter/material.dart';
import '../models/product_review_model.dart';
import '../models/delivery_feedback_model.dart';

/// ReviewProvider manages both product reviews and delivery feedback
/// for internal quality tracking (NOT shown to customers)
class ReviewProvider extends ChangeNotifier {
  List<ProductReviewModel> _productReviews = [];
  List<DeliveryFeedbackModel> _deliveryFeedback = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<ProductReviewModel> get productReviews => _productReviews;
  List<DeliveryFeedbackModel> get deliveryFeedback => _deliveryFeedback;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Submit product reviews from post-delivery modal
  Future<void> submitProductReviews(List<ProductReviewModel> reviews) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Add reviews to local list
      _productReviews.addAll(reviews);

      // In production, this would call a backend API
      // Example: await _apiService.submitReviews(reviews);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Submit delivery feedback
  Future<void> submitDeliveryFeedback(DeliveryFeedbackModel feedback) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _deliveryFeedback.add(feedback);

      // In production: await _apiService.submitFeedback(feedback);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Load reviews from backend
  Future<void> loadReviews() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // In production, fetch from backend
      // _productReviews = await _apiService.getProductReviews();
      // _deliveryFeedback = await _apiService.getDeliveryFeedback();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load feedback for specific employee
  Future<void> loadEmployeeFeedback(String employeeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Filter feedback for specific employee
      final employeeFeedback = _deliveryFeedback
          .where((f) => f.employeeId == employeeId)
          .toList();

      _deliveryFeedback = employeeFeedback;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load reviews for specific product
  Future<void> loadProductReviews(String productId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Filter reviews for specific product
      final productReviews = _productReviews
          .where((r) => r.productId == productId)
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Flag a review for moderation/issues
  void flagReview(String reviewId, String reason) {
    try {
      final index = _productReviews.indexWhere((r) => r.id == reviewId);
      if (index != -1) {
        _productReviews[index] = _productReviews[index].copyWith(
          isFlagged: true,
          flagReason: reason,
        );
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Resolve a flagged review
  void resolveReview(String reviewId) {
    try {
      final index = _productReviews.indexWhere((r) => r.id == reviewId);
      if (index != -1) {
        _productReviews[index] = _productReviews[index].copyWith(
          resolved: true,
        );
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Get average rating for a product
  double getProductAverageRating(String productId) {
    final productReviews = _productReviews
        .where((r) => r.productId == productId)
        .toList();

    if (productReviews.isEmpty) return 0.0;

    final sum = productReviews
        .map((r) => r.rating)
        .reduce((a, b) => a + b);

    return sum / productReviews.length;
  }

  /// Get average rating for an employee
  double getEmployeeAverageRating(String employeeId) {
    final employeeFeedback = _deliveryFeedback
        .where((f) => f.employeeId == employeeId)
        .toList();

    if (employeeFeedback.isEmpty) return 0.0;

    final sum = employeeFeedback
        .map((f) => f.serviceRating)
        .reduce((a, b) => a + b);

    return sum / employeeFeedback.length;
  }

  /// Get overall average rating across all products
  double getOverallAverageRating() {
    if (_productReviews.isEmpty) return 0.0;

    final sum = _productReviews
        .map((r) => r.rating)
        .reduce((a, b) => a + b);

    return sum / _productReviews.length;
  }

  /// Get count of low-rated reviews (1-2 stars)
  int getLowRatedReviewsCount() {
    return _productReviews.where((r) => r.rating <= 2).length;
  }

  /// Get count of flagged reviews
  int getFlaggedReviewsCount() {
    return _productReviews.where((r) => r.isFlagged).length;
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear all data
  void clearAll() {
    _productReviews = [];
    _deliveryFeedback = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
