import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// RewardSystem handles reward points calculation and management
///
/// [Requirements 11.2, 11.3]: Awards points based on:
/// - 1 point per ₹10 spent
/// - 100 points for first order
/// - 20 points for reviews
/// - 50 points for referrals
/// - Implements points-to-currency conversion (100 points = ₹1)
class RewardSystem {
  static final RewardSystem _instance = RewardSystem._internal();
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  factory RewardSystem() {
    return _instance;
  }

  RewardSystem._internal();

  /// Points per rupee spent
  static const double pointsPerRupee = 0.1; // 1 point per ₹10

  /// Points for first order
  static const int firstOrderPoints = 100;

  /// Points for writing a review
  static const int reviewPoints = 20;

  /// Points for referral
  static const int referralPoints = 50;

  /// Conversion rate: points to currency
  static const double pointsToCurrencyRate = 0.01; // 100 points = ₹1

  /// Calculates reward points earned from order amount
  ///
  /// [Requirements 11.2]: Awards 1 point per ₹10 spent
  int calculateOrderPoints(double orderAmount) {
    return (orderAmount * pointsPerRupee).floor();
  }

  /// Awards points for first order
  ///
  /// [Requirements 11.2]: Awards 100 points for first order
  Future<bool> awardFirstOrderPoints(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final userData = userDoc.data()!;
        final currentPoints = userData['rewardPoints'] ?? 0;
        final newPoints = currentPoints + firstOrderPoints;

        transaction.update(userRef, {
          'rewardPoints': newPoints,
          'updatedAt': DateTime.now(),
        });

        // Record transaction
        _recordPointsTransaction(
          transaction,
          userId,
          firstOrderPoints,
          'First Order Bonus',
        );
      });

      return true;
    } catch (e) {
      debugPrint('Error awarding first order points: $e');
      return false;
    }
  }

  /// Awards points for writing a review
  ///
  /// [Requirements 11.2]: Awards 20 points for reviews
  Future<bool> awardReviewPoints(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final userData = userDoc.data()!;
        final currentPoints = userData['rewardPoints'] ?? 0;
        final newPoints = currentPoints + reviewPoints;

        transaction.update(userRef, {
          'rewardPoints': newPoints,
          'updatedAt': DateTime.now(),
        });

        // Record transaction
        _recordPointsTransaction(
          transaction,
          userId,
          reviewPoints,
          'Review Bonus',
        );
      });

      return true;
    } catch (e) {
      debugPrint('Error awarding review points: $e');
      return false;
    }
  }

  /// Awards points for referral
  ///
  /// [Requirements 11.2]: Awards 50 points for referrals
  Future<bool> awardReferralPoints(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final userData = userDoc.data()!;
        final currentPoints = userData['rewardPoints'] ?? 0;
        final newPoints = currentPoints + referralPoints;

        transaction.update(userRef, {
          'rewardPoints': newPoints,
          'updatedAt': DateTime.now(),
        });

        // Record transaction
        _recordPointsTransaction(
          transaction,
          userId,
          referralPoints,
          'Referral Bonus',
        );
      });

      return true;
    } catch (e) {
      debugPrint('Error awarding referral points: $e');
      return false;
    }
  }

  /// Awards points for order completion
  ///
  /// [Requirements 11.2]: Awards 1 point per ₹10 spent
  Future<bool> awardOrderPoints({
    required String userId,
    required double orderAmount,
    required String orderId,
  }) async {
    try {
      final points = calculateOrderPoints(orderAmount);
      final userRef = _firestore.collection('users').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final userData = userDoc.data()!;
        final currentPoints = userData['rewardPoints'] ?? 0;
        final newPoints = currentPoints + points;

        transaction.update(userRef, {
          'rewardPoints': newPoints,
          'updatedAt': DateTime.now(),
        });

        // Record transaction
        _recordPointsTransaction(
          transaction,
          userId,
          points,
          'Order Points',
          orderId,
        );
      });

      return true;
    } catch (e) {
      debugPrint('Error awarding order points: $e');
      return false;
    }
  }

  /// Redeems reward points for wallet credit
  ///
  /// [Requirements 11.3]: Implements points-to-currency conversion (100 points = ₹1)
  Future<double?> redeemPoints({
    required String userId,
    required int pointsToRedeem,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);

      final result = await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final userData = userDoc.data()!;
        final currentPoints = (userData['rewardPoints'] as num? ?? 0).toInt();

        if (currentPoints < pointsToRedeem) {
          throw Exception('Insufficient reward points');
        }

        final walletCredit = pointsToRedeem * pointsToCurrencyRate;
        final newPoints = currentPoints - pointsToRedeem;
        final currentWallet = (userData['walletBalance'] ?? 0.0).toDouble();
        final newWallet = currentWallet + walletCredit;

        transaction.update(userRef, {
          'rewardPoints': newPoints,
          'walletBalance': newWallet,
          'updatedAt': DateTime.now(),
        });

        // Record points transaction
        _recordPointsTransaction(
          transaction,
          userId,
          -pointsToRedeem,
          'Points Redeemed',
        );

        // Record wallet transaction
        _recordWalletTransaction(
          transaction,
          userId,
          walletCredit,
          'Reward Points Redeemed',
        );

        return walletCredit;
      });

      return result;
    } catch (e) {
      debugPrint('Error redeeming points: $e');
      return null;
    }
  }

  /// Gets current reward points for a user
  Future<int> getRewardPoints(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return 0;
      }
      return (userDoc.data()?['rewardPoints'] as num? ?? 0).toInt();
    } catch (e) {
      debugPrint('Error getting reward points: $e');
      return 0;
    }
  }

  /// Converts reward points to currency amount
  ///
  /// [Requirements 11.3]: 100 points = ₹1
  double convertPointsToCurrency(int points) {
    return points * pointsToCurrencyRate;
  }

  /// Converts currency amount to reward points
  double convertCurrencyToPoints(double amount) {
    return amount / pointsToCurrencyRate;
  }

  /// Helper method to record points transaction
  void _recordPointsTransaction(
    Transaction transaction,
    String userId,
    int points,
    String description, [
    String? orderId,
  ]) {
    final transactionId = 'pts_${DateTime.now().millisecondsSinceEpoch}';
    final userRef = _firestore.collection('users').doc(userId);

    transaction
        .set(userRef.collection('reward_transactions').doc(transactionId), {
          'id': transactionId,
          'userId': userId,
          'points': points,
          'description': description,
          'orderId': orderId,
          'timestamp': DateTime.now(),
        });
  }

  /// Helper method to record wallet transaction
  void _recordWalletTransaction(
    Transaction transaction,
    String userId,
    double amount,
    String description,
  ) {
    final transactionId = 'wlt_${DateTime.now().millisecondsSinceEpoch}';
    final userRef = _firestore.collection('users').doc(userId);

    transaction
        .set(userRef.collection('wallet_transactions').doc(transactionId), {
          'id': transactionId,
          'userId': userId,
          'amount': amount,
          'description': description,
          'timestamp': DateTime.now(),
        });
  }

  /// Streams reward points changes in real-time
  Stream<int> watchRewardPoints(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => (doc.data()?['rewardPoints'] as num? ?? 0).toInt());
  }
}
