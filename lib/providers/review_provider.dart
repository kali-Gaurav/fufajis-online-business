import 'package:flutter/material.dart';
import '../models/product_review_model.dart';
import '../models/delivery_feedback_model.dart';

class ReviewProvider extends ChangeNotifier {
  List<ProductReviewModel> _productReviews = [];
  List<DeliveryFeedbackModel> _deliveryFeedback = [];
  bool _isLoading = false;
  String? _error;

  List<ProductReviewModel> get productReviews => _productReviews;
  List<DeliveryFeedbackModel> get deliveryFeedback => _deliveryFeedback;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> submitProductReviews(List<ProductReviewModel> reviews) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // In production, this would call a backend API
      // For now, store locally
      _productReviews.addAll(reviews);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitDeliveryFeedback(DeliveryFeedbackModel feedback) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _deliveryFeedback.add(feedback);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadReviews() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // In production, fetch from backend
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void flagReview(String reviewId, String reason) {
    try {
      final index =
          _productReviews.indexWhere((r) => r.id == reviewId);
      if (index != -1) {
        _productReviews[index] =
            _productReviews[index].copyWith(
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

  void resolveReview(String reviewId) {
    try {
      final index =
          _productReviews.indexWhere((r) => r.id == reviewId);
      if (index != -1) {
        _productReviews[index] =
            _productReviews[index].copyWith(resolved: true);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
