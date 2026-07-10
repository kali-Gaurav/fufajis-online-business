import 'package:flutter/material.dart';
import '../models/product_review_model.dart';
import '../models/delivery_feedback_model.dart';
import '../services/review_service.dart';

class ReviewProvider extends ChangeNotifier {
  final ReviewService _reviewService = ReviewService();

  List<ProductReviewModel> _productReviews = [];
  List<DeliveryFeedbackModel> _deliveryFeedback = [];
  bool _isLoading = false;
  String? _error;

  List<ProductReviewModel> get productReviews => _productReviews;
  List<DeliveryFeedbackModel> get deliveryFeedback => _deliveryFeedback;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> submitProductReviews(List<ProductReviewModel> reviews) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final submitted = await _reviewService.submitProductReviews(reviews);
      _productReviews.addAll(submitted);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitDeliveryFeedback(DeliveryFeedbackModel feedback) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final submitted = await _reviewService.submitDeliveryFeedback(feedback);
      _deliveryFeedback.add(submitted);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loadReviews({
    String? productId,
    int? rating,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool? onlyFlagged,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _productReviews = await _reviewService.getProductReviews(
        productId: productId,
        rating: rating,
        dateFrom: dateFrom,
        dateTo: dateTo,
        onlyFlagged: onlyFlagged,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loadOrderReviews(String orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _productReviews = await _reviewService.getOrderReviews(orderId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> canReviewOrder(String orderId) async {
    try {
      return await _reviewService.canReviewOrder(orderId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> flagReview(String reviewId, String reason) async {
    try {
      final updated = await _reviewService.flagReview(reviewId, reason);
      final index = _productReviews.indexWhere((r) => r.id == reviewId);
      if (index != -1) {
        _productReviews[index] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resolveReview(String reviewId) async {
    try {
      final updated = await _reviewService.resolveReview(reviewId);
      final index = _productReviews.indexWhere((r) => r.id == reviewId);
      if (index != -1) {
        _productReviews[index] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> getProductStats(String productId) async {
    try {
      return await _reviewService.getProductStats(productId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> loadEmployeeFeedback(String employeeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _deliveryFeedback =
          await _reviewService.getEmployeeFeedback(employeeId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> getEmployeeStats(String employeeId) async {
    try {
      return await _reviewService.getEmployeeStats(employeeId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
