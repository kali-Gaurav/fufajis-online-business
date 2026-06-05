import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/wallet_service.dart';
import '../services/reward_system.dart';
import '../services/membership_tier_calculator.dart';
import '../services/cashback_calculator.dart';

class WalletProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WalletService _walletService = WalletService();
  final RewardSystem _rewardSystem = RewardSystem();
  final MembershipTierCalculator _tierCalculator = MembershipTierCalculator();
  final CashbackCalculator _cashbackCalculator = CashbackCalculator();

  // State variables
  double _walletBalance = 0.0;
  int _rewardPoints = 0;
  MembershipTier _membershipTier = MembershipTier.bronze;
  List<WalletTransaction> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  double get walletBalance => _walletBalance;
  int get rewardPoints => _rewardPoints;
  MembershipTier get membershipTier => _membershipTier;
  List<WalletTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Initializes wallet data for a user
  Future<void> initializeWallet(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Fetch wallet balance
      _walletBalance = await _walletService.getWalletBalance(userId);

      // Fetch reward points
      _rewardPoints = await _rewardSystem.getRewardPoints(userId);

      // Fetch membership tier
      _membershipTier = await _tierCalculator.getUserTier(userId);

      // Fetch transaction history
      _transactions = await _walletService.getTransactionHistory(
        userId: userId,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing wallet: $e');
      _errorMessage = 'Failed to initialize wallet: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches wallet transactions with pagination
  ///
  /// [Requirements 11.7]: Displays transaction history with pagination
  Future<void> fetchTransactions(String userId, {int limit = 20}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _transactions = await _walletService.getTransactionHistory(
        userId: userId,
        limit: limit,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      _errorMessage = 'Failed to fetch transactions: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filters transactions by type
  ///
  /// [Requirements 11.7]: Add filter by transaction type
  Future<void> filterTransactionsByType(
    String userId,
    WalletTransactionType type,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _transactions = await _walletService.getTransactionsByType(
        userId: userId,
        type: type,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error filtering transactions: $e');
      _errorMessage = 'Failed to filter transactions: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Applies cashback for an order
  ///
  /// [Requirements 11.1]: Calculates 1% cashback on order completion
  Future<bool> applyCashback({
    required String userId,
    required double orderAmount,
    required String orderId,
  }) async {
    try {
      final success = await _cashbackCalculator.applyCashback(
        userId: userId,
        orderAmount: orderAmount,
        orderId: orderId,
      );

      if (success) {
        // Refresh wallet balance
        _walletBalance = await _walletService.getWalletBalance(userId);
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('Error applying cashback: $e');
      return false;
    }
  }

  /// Alias for applyCashback for backward compatibility
  Future<bool> addCashback(
    String userId,
    double orderAmount,
    String orderId,
  ) async {
    return applyCashback(
      userId: userId,
      orderAmount: orderAmount,
      orderId: orderId,
    );
  }

  /// Processes an auto-refund for a cancelled order (Feature 13)
  ///
  /// Insight: Return money instantly to minimize customer friction.
  Future<bool> refundOrder({
    required String userId,
    required String orderId,
    required double amount,
    String reason = 'Order Cancelled',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _walletService.addToWallet(
        userId: userId,
        amount: amount,
        transactionType: WalletTransactionType.refund,
        orderReference: orderId,
        description: 'Auto-refund: $reason',
        transactionId: 'txn_wallet_refund_$orderId',
      );

      if (success) {
        _walletBalance = await _walletService.getWalletBalance(userId);
        _transactions = await _walletService.getTransactionHistory(
          userId: userId,
        );
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('Error processing auto-refund: $e');
      _errorMessage = 'Refund failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Deducts balance for a wallet payment
  Future<bool> payWithWallet({
    required String userId,
    required double orderAmount,
    required String orderId,
  }) async {
    try {
      final success = await _walletService.deductFromWallet(
        userId: userId,
        amount: orderAmount,
        transactionType: WalletTransactionType.walletPayment,
        orderReference: orderId,
        transactionId: 'txn_wallet_debit_$orderId',
      );

      if (success) {
        _walletBalance = await _walletService.getWalletBalance(userId);
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('Error paying with wallet: $e');
      return false;
    }
  }

  /// Awards reward points for order completion
  ///
  /// [Requirements 11.2]: Awards 1 point per ₹10 spent
  Future<bool> awardOrderPoints({
    required String userId,
    required double orderAmount,
    required String orderId,
  }) async {
    try {
      final success = await _rewardSystem.awardOrderPoints(
        userId: userId,
        orderAmount: orderAmount,
        orderId: orderId,
      );

      if (success) {
        // Refresh reward points
        _rewardPoints = await _rewardSystem.getRewardPoints(userId);
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('Error awarding order points: $e');
      return false;
    }
  }

  /// Awards first order bonus points
  ///
  /// [Requirements 11.2]: Awards 100 points for first order
  Future<bool> awardFirstOrderBonus(String userId) async {
    try {
      final success = await _rewardSystem.awardFirstOrderPoints(userId);

      if (success) {
        _rewardPoints = await _rewardSystem.getRewardPoints(userId);
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('Error awarding first order bonus: $e');
      return false;
    }
  }

  /// Awards review bonus points
  ///
  /// [Requirements 11.2]: Awards 20 points for reviews
  Future<bool> awardReviewBonus(String userId) async {
    try {
      final success = await _rewardSystem.awardReviewPoints(userId);

      if (success) {
        _rewardPoints = await _rewardSystem.getRewardPoints(userId);
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('Error awarding review bonus: $e');
      return false;
    }
  }

  /// Awards referral bonus points
  ///
  /// [Requirements 11.2]: Awards 50 points for referrals
  Future<bool> awardReferralBonus(String userId) async {
    try {
      final success = await _rewardSystem.awardReferralPoints(userId);

      if (success) {
        _rewardPoints = await _rewardSystem.getRewardPoints(userId);
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('Error awarding referral bonus: $e');
      return false;
    }
  }

  /// Redeems reward points for wallet credit
  ///
  /// [Requirements 11.3]: Implements points-to-currency conversion (100 points = ₹1)
  Future<bool> redeemRewardPoints({
    required String userId,
    required int pointsToRedeem,
  }) async {
    try {
      final walletCredit = await _rewardSystem.redeemPoints(
        userId: userId,
        pointsToRedeem: pointsToRedeem,
      );

      if (walletCredit != null) {
        // Refresh both wallet and points
        _walletBalance = await _walletService.getWalletBalance(userId);
        _rewardPoints = await _rewardSystem.getRewardPoints(userId);
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error redeeming points: $e');
      return false;
    }
  }

  /// Updates membership tier based on lifetime spending
  ///
  /// [Requirements 11.5]: Updates tier on order completion
  Future<bool> updateMembershipTier(String userId) async {
    try {
      final newTier = await _tierCalculator.updateMembershipTier(userId);

      if (newTier != null) {
        _membershipTier = newTier;
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error updating membership tier: $e');
      return false;
    }
  }

  /// Gets tier progress information
  Future<Map<String, dynamic>> getTierProgress(String userId) async {
    try {
      final lifetimeSpending = await _calculateLifetimeSpending(userId);
      return _tierCalculator.getNextTierInfo(lifetimeSpending);
    } catch (e) {
      debugPrint('Error getting tier progress: $e');
      return {};
    }
  }

  /// Calculates lifetime spending for a user
  Future<double> _calculateLifetimeSpending(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .where('status', isNotEqualTo: 'OrderStatus.cancelled')
          .get();

      double totalSpending = 0.0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalSpending += (data['totalAmount'] ?? 0.0).toDouble();
      }

      return totalSpending;
    } catch (e) {
      debugPrint('Error calculating lifetime spending: $e');
      return 0.0;
    }
  }

  /// Streams wallet balance changes
  Stream<double> watchWalletBalance(String userId) {
    return _walletService.watchWalletBalance(userId).map((balance) {
      _walletBalance = balance;
      notifyListeners();
      return balance;
    });
  }

  /// Streams reward points changes
  Stream<int> watchRewardPoints(String userId) {
    return _rewardSystem.watchRewardPoints(userId).map((points) {
      _rewardPoints = points;
      notifyListeners();
      return points;
    });
  }

  /// Streams membership tier changes
  Stream<MembershipTier> watchMembershipTier(String userId) {
    return _tierCalculator.watchMembershipTier(userId).map((tier) {
      _membershipTier = tier;
      notifyListeners();
      return tier;
    });
  }
}
