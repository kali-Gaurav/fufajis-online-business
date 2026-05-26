import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'wallet_service.dart';
import 'membership_tier_calculator.dart';

/// CashbackCalculator handles cashback calculation and application
/// 
/// [Requirements 11.1]: Calculates 1% cashback on order completion
/// and adds cashback to wallet balance
class CashbackCalculator {
  static final CashbackCalculator _instance = CashbackCalculator._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WalletService _walletService = WalletService();
  final MembershipTierCalculator _tierCalculator = MembershipTierCalculator();

  factory CashbackCalculator() {
    return _instance;
  }

  CashbackCalculator._internal();

  /// Base cashback percentage (1%)
  static const double baseCashbackPercentage = 0.01;

  /// Calculates cashback amount for an order
  /// 
  /// [Requirements 11.1]: Calculates 1% cashback on order completion
  double calculateCashback(double orderAmount, {double multiplier = 1.0}) {
    return orderAmount * baseCashbackPercentage * multiplier;
  }

  /// Applies cashback to user's wallet on order completion
  /// 
  /// [Requirements 11.1]: Adds cashback to wallet balance
  Future<bool> applyCashback({
    required String userId,
    required double orderAmount,
    required String orderId,
  }) async {
    try {
      // Get user's membership tier to determine cashback multiplier
      final tier = await _tierCalculator.getUserTier(userId);
      final tierBenefits = _tierCalculator.getTierBenefits(tier);
      final cashbackMultiplier =
          (tierBenefits['cashbackPercentage'] ?? 1.0) / 1.0;

      // Calculate cashback amount
      final cashbackAmount = calculateCashback(orderAmount, multiplier: cashbackMultiplier);

      // Add to wallet
      final success = await _walletService.addToWallet(
        userId: userId,
        amount: cashbackAmount,
        transactionType: WalletTransactionType.cashback,
        orderReference: orderId,
        description: 'Cashback for Order #$orderId',
      );

      if (success) {
        debugPrint('Cashback of ₹$cashbackAmount applied for order $orderId');
      }

      return success;
    } catch (e) {
      debugPrint('Error applying cashback: $e');
      return false;
    }
  }

  /// Gets cashback amount for an order based on user's tier
  Future<double> getCashbackAmount({
    required String userId,
    required double orderAmount,
  }) async {
    try {
      final tier = await _tierCalculator.getUserTier(userId);
      final tierBenefits = _tierCalculator.getTierBenefits(tier);
      final cashbackPercentage = (tierBenefits['cashbackPercentage'] ?? 1.0) / 100.0;

      return orderAmount * cashbackPercentage;
    } catch (e) {
      debugPrint('Error getting cashback amount: $e');
      return orderAmount * baseCashbackPercentage;
    }
  }

  /// Gets cashback percentage for a user's tier
  Future<double> getCashbackPercentage(String userId) async {
    try {
      final tier = await _tierCalculator.getUserTier(userId);
      final tierBenefits = _tierCalculator.getTierBenefits(tier);
      return (tierBenefits['cashbackPercentage'] ?? 1.0);
    } catch (e) {
      debugPrint('Error getting cashback percentage: $e');
      return 1.0;
    }
  }

  /// Gets cashback history for a user
  Future<List<Map<String, dynamic>>> getCashbackHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('wallet_transactions')
          .where('type', isEqualTo: 'WalletTransactionType.cashback')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error getting cashback history: $e');
      return [];
    }
  }

  /// Gets total cashback earned by a user
  Future<double> getTotalCashbackEarned(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('wallet_transactions')
          .where('type', isEqualTo: 'WalletTransactionType.cashback')
          .get();

      double totalCashback = 0.0;
      for (final doc in snapshot.docs) {
        totalCashback += (doc.data()['amount'] ?? 0.0).toDouble();
      }

      return totalCashback;
    } catch (e) {
      debugPrint('Error getting total cashback: $e');
      return 0.0;
    }
  }

  /// Streams cashback history changes in real-time
  Stream<List<Map<String, dynamic>>> watchCashbackHistory(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('wallet_transactions')
        .where('type', isEqualTo: 'WalletTransactionType.cashback')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
