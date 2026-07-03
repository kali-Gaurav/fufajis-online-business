import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to calculate and update product ratings
/// Updates product rating and review count within 1 hour of new review
class ProductRatingCalculator {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Calculate average rating for a product
  /// Returns the average rating from all approved reviews
  Future<double> calculateAverageRating(String productId) async {
    try {
      final snapshot = await _db
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .where('isApproved', isEqualTo: true)
          .where('isFlagged', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) {
        return 0.0;
      }

      double totalRating = 0;
      for (var doc in snapshot.docs) {
        final rating = (doc.data()['rating'] ?? 0.0) as num;
        totalRating += rating.toDouble();
      }

      final averageRating = totalRating / snapshot.docs.length;
      return double.parse(averageRating.toStringAsFixed(1));
    } catch (e) {
      print('Error calculating average rating: $e');
      return 0.0;
    }
  }

  /// Get review count for a product
  Future<int> getReviewCount(String productId) async {
    try {
      final snapshot = await _db
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .where('isApproved', isEqualTo: true)
          .where('isFlagged', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting review count: $e');
      return 0;
    }
  }

  /// Update product rating and review count
  /// This should be called after a new review is added
  Future<void> updateProductRating(String productId) async {
    try {
      final averageRating = await calculateAverageRating(productId);
      final reviewCount = await getReviewCount(productId);

      await _db.collection('products').doc(productId).update({
        'rating': averageRating,
        'reviewCount': reviewCount,
        'lastRatingUpdate': FieldValue.serverTimestamp(),
      });

      print('Updated product $productId: rating=$averageRating, count=$reviewCount');
    } catch (e) {
      print('Error updating product rating: $e');
      rethrow;
    }
  }

  /// Get rating distribution for a product
  /// Returns a map with rating counts: {5: count, 4: count, ...}
  Future<Map<int, int>> getRatingDistribution(String productId) async {
    try {
      final snapshot = await _db
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .where('isApproved', isEqualTo: true)
          .where('isFlagged', isEqualTo: false)
          .get();

      final distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

      for (var doc in snapshot.docs) {
        final rating = (doc.data()['rating'] ?? 0.0) as num;
        final ratingInt = rating.toInt();
        if (distribution.containsKey(ratingInt)) {
          distribution[ratingInt] = distribution[ratingInt]! + 1;
        }
      }

      return distribution;
    } catch (e) {
      print('Error getting rating distribution: $e');
      return {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    }
  }

  /// Get percentage of reviews for each rating
  Future<Map<int, double>> getRatingPercentages(String productId) async {
    try {
      final distribution = await getRatingDistribution(productId);
      final total = distribution.values.fold<int>(0, (acc, val) => acc + val);

      if (total == 0) {
        return {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      }

      return {
        5: (distribution[5]! / total) * 100,
        4: (distribution[4]! / total) * 100,
        3: (distribution[3]! / total) * 100,
        2: (distribution[2]! / total) * 100,
        1: (distribution[1]! / total) * 100,
      };
    } catch (e) {
      print('Error getting rating percentages: $e');
      return {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    }
  }

  /// Get top rated products
  Future<List<String>> getTopRatedProducts({int limit = 10}) async {
    try {
      final snapshot = await _db
          .collection('products')
          .where('rating', isGreaterThanOrEqualTo: 4.0)
          .orderBy('rating', descending: true)
          .orderBy('reviewCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('Error getting top rated products: $e');
      return [];
    }
  }

  /// Get products with most reviews
  Future<List<String>> getMostReviewedProducts({int limit = 10}) async {
    try {
      final snapshot = await _db
          .collection('products')
          .orderBy('reviewCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('Error getting most reviewed products: $e');
      return [];
    }
  }
}
