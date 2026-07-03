import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'audit_service.dart';
import 'wallet_service.dart';

/// Complete loyalty program lifecycle management
/// Handles points awards, redemptions, tier upgrades, and referrals
///
/// Features:
/// - Purchase rewards (1 point per ₹10)
/// - Tier system: bronze → silver → gold
/// - Referral bonuses (₹25 + 250 points)
/// - Point redemption (100 points = ₹100)
/// - Transaction tracking

class LoyaltyWorkflowService {
  static final LoyaltyWorkflowService _instance = LoyaltyWorkflowService._internal();
  factory LoyaltyWorkflowService() => _instance;
  LoyaltyWorkflowService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();
  final AuditService _audit = AuditService();
  final WalletService _wallet = WalletService();

  // Tier definitions (based on lifetime points)
  static const Map<String, int> tierThresholds = {
    'bronze': 0, // 0+ points
    'silver': 2000, // 2000+ points
    'gold': 5000, // 5000+ points
  };

  static const Map<String, double> tierMultipliers = {
    'bronze': 1.0, // 1 point per ₹10
    'silver': 1.25, // 1.25 points per ₹10
    'gold': 1.5, // 1.5 points per ₹10
  };

  /// Initialize loyalty account for new customer
  Future<Map<String, dynamic>> initializeAccount(String userId) async {
    try {
      final now = DateTime.now();
      final docRef = _db.collection('loyalty').doc(userId);

      final loyaltyData = {
        'userId': userId,
        'currentTier': 'bronze',
        'balance': 0,
        'lifetime': 0,
        'totalRedemptions': 0,
        'totalPurchaseAmount': 0,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'lastPointsAwarded': null,
        'tierUpgradeHistory': [
          {'tier': 'bronze', 'timestamp': Timestamp.fromDate(now), 'reason': 'account_created'},
        ],
      };

      await docRef.set(loyaltyData);

      await _audit.log('loyalty_account_created', {'userId': userId});

      debugPrint('[LoyaltyWorkflowService] Initialized loyalty account for $userId');
      return loyaltyData;
    } catch (e) {
      debugPrint('[LoyaltyWorkflowService] Failed to initialize account: $e');
      rethrow;
    }
  }

  /// Award points for purchase
  /// Points = (amount / 10) * tier_multiplier
  Future<int> awardPointsForPurchase({
    required String userId,
    required double purchaseAmount,
    required String orderId,
  }) async {
    try {
      // Get loyalty account (create if doesn't exist)
      var loyaltySnap = await _db.collection('loyalty').doc(userId).get();
      if (!loyaltySnap.exists) {
        await initializeAccount(userId);
        loyaltySnap = await _db.collection('loyalty').doc(userId).get();
      }

      final loyaltyData = loyaltySnap.data();
      final currentTier = (loyaltyData?['currentTier'] as String?) ?? 'bronze';
      final multiplier = tierMultipliers[currentTier] ?? 1.0;

      // Calculate points
      final basePoints = (purchaseAmount / 10).floor();
      final tierBonus = ((basePoints * (multiplier - 1.0)).toInt());
      final totalPoints = basePoints + tierBonus;

      final now = DateTime.now();

      // Update loyalty account
      await _db.collection('loyalty').doc(userId).update({
        'balance': FieldValue.increment(totalPoints),
        'lifetime': FieldValue.increment(totalPoints),
        'totalPurchaseAmount': FieldValue.increment(purchaseAmount),
        'lastPointsAwarded': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Log transaction
      await _db.collection('loyalty_transactions').add({
        'userId': userId,
        'type': 'purchase',
        'points': totalPoints,
        'basePoints': basePoints,
        'tierBonus': tierBonus,
        'tier': currentTier,
        'purchaseAmount': purchaseAmount,
        'orderId': orderId,
        'timestamp': Timestamp.fromDate(now),
      });

      // Check for tier upgrade
      await _checkTierUpgrade(userId);

      await _audit.log('loyalty_points_awarded', {
        'userId': userId,
        'orderId': orderId,
        'points': totalPoints,
        'purchaseAmount': purchaseAmount,
        'tier': currentTier,
      });

      debugPrint(
        '[LoyaltyWorkflowService] Awarded $totalPoints points to $userId for order $orderId',
      );
      return totalPoints;
    } catch (e) {
      debugPrint('[LoyaltyWorkflowService] Failed to award points: $e');
      rethrow;
    }
  }

  /// Redeem loyalty points for wallet credit
  /// 100 points = ₹100
  Future<double> redeemPoints({required String userId, required int points, String? reason}) async {
    try {
      final loyaltySnap = await _db.collection('loyalty').doc(userId).get();
      final loyaltyData = loyaltySnap.data();

      if (loyaltyData == null) {
        throw Exception('Loyalty account not found for user: $userId');
      }

      final currentBalance = (loyaltyData['balance'] as num?)?.toInt() ?? 0;
      if (currentBalance < points) {
        throw Exception(
          'Insufficient loyalty points. Balance: $currentBalance, Requested: $points',
        );
      }

      // 100 points = ₹100
      final redeemAmount = points / 100.0;
      final now = DateTime.now();

      // Deduct points
      await _db.collection('loyalty').doc(userId).update({
        'balance': FieldValue.increment(-points),
        'totalRedemptions': FieldValue.increment(1),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Credit wallet
      await _wallet.creditBalance(userId, redeemAmount, 'loyalty_redemption', {
        'points': points,
        'reason': reason,
      });

      // Log transaction
      await _db.collection('loyalty_transactions').add({
        'userId': userId,
        'type': 'redemption',
        'points': points,
        'amount': redeemAmount,
        'reason': reason,
        'timestamp': Timestamp.fromDate(now),
      });

      // Notify user
      await _notifications.notifyCustomer(
        userId,
        'Redeemed $points loyalty points! ₹$redeemAmount added to wallet.',
        {'points': points, 'amount': redeemAmount},
      );

      await _audit.log('loyalty_points_redeemed', {
        'userId': userId,
        'points': points,
        'amount': redeemAmount,
      });

      debugPrint(
        '[LoyaltyWorkflowService] Redeemed $points points for ₹$redeemAmount for user $userId',
      );
      return redeemAmount;
    } catch (e) {
      debugPrint('[LoyaltyWorkflowService] Failed to redeem points: $e');
      rethrow;
    }
  }

  /// Process referral bonus
  /// Referrer gets: ₹25 + 250 points
  /// Referred gets: ₹25 + 250 points
  Future<void> processReferralBonus({
    required String referrerId,
    required String referredUserId,
  }) async {
    try {
      final now = DateTime.now();

      // Validate both users exist
      final referrerSnap = await _db.collection('users').doc(referrerId).get();
      final referredSnap = await _db.collection('users').doc(referredUserId).get();

      if (!referrerSnap.exists || !referredSnap.exists) {
        throw Exception('Invalid referrer or referred user');
      }

      const bonusAmount = 25.0;
      const bonusPoints = 250;

      // Award to referrer
      await _wallet.creditBalance(referrerId, bonusAmount, 'referral_bonus', {
        'referredUserId': referredUserId,
      });

      await awardPoints(referrerId, bonusPoints, 'referral_bonus', {
        'referredUserId': referredUserId,
      });

      // Award to referred
      await _wallet.creditBalance(referredUserId, bonusAmount, 'referral_signup', {
        'referrerId': referrerId,
      });

      await awardPoints(referredUserId, bonusPoints, 'referral_signup', {'referrerId': referrerId});

      // Log referral
      await _db.collection('referrals').add({
        'referrerId': referrerId,
        'referredUserId': referredUserId,
        'bonusAwarded': true,
        'timestamp': Timestamp.fromDate(now),
      });

      // Notify both
      await _notifications.notifyCustomer(
        referrerId,
        'Referral bonus: ₹$bonusAmount + $bonusPoints points!',
        {'referredUserId': referredUserId, 'bonusAmount': bonusAmount, 'bonusPoints': bonusPoints},
      );

      await _notifications.notifyCustomer(
        referredUserId,
        'Welcome! Referral bonus: ₹$bonusAmount + $bonusPoints points!',
        {'referrerId': referrerId, 'bonusAmount': bonusAmount, 'bonusPoints': bonusPoints},
      );

      await _audit.log('referral_bonus_processed', {
        'referrerId': referrerId,
        'referredUserId': referredUserId,
        'bonusAmount': bonusAmount,
        'bonusPoints': bonusPoints,
      });

      debugPrint(
        '[LoyaltyWorkflowService] Processed referral bonus for $referrerId → $referredUserId',
      );
    } catch (e) {
      debugPrint('[LoyaltyWorkflowService] Failed to process referral: $e');
      rethrow;
    }
  }

  /// Award arbitrary points (promotions, contests, etc.)
  Future<void> awardPoints(
    String userId,
    int points,
    String reason,
    Map<String, dynamic>? metadata,
  ) async {
    try {
      final now = DateTime.now();

      // Create account if doesn't exist
      var loyaltySnap = await _db.collection('loyalty').doc(userId).get();
      if (!loyaltySnap.exists) {
        await initializeAccount(userId);
        loyaltySnap = await _db.collection('loyalty').doc(userId).get();
      }

      await _db.collection('loyalty').doc(userId).update({
        'balance': FieldValue.increment(points),
        'lifetime': FieldValue.increment(points),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Log transaction
      await _db.collection('loyalty_transactions').add({
        'userId': userId,
        'type': 'award',
        'points': points,
        'reason': reason,
        'metadata': metadata,
        'timestamp': Timestamp.fromDate(now),
      });

      // Check tier upgrade
      await _checkTierUpgrade(userId);

      debugPrint('[LoyaltyWorkflowService] Awarded $points points to $userId for $reason');
    } catch (e) {
      debugPrint('[LoyaltyWorkflowService] Failed to award points: $e');
      rethrow;
    }
  }

  /// Check and process tier upgrades
  /// bronze (0) → silver (2000) → gold (5000)
  Future<void> _checkTierUpgrade(String userId) async {
    try {
      final loyaltySnap = await _db.collection('loyalty').doc(userId).get();
      final loyaltyData = loyaltySnap.data();

      if (loyaltyData == null) return;

      final lifetime = (loyaltyData['lifetime'] as num?)?.toInt() ?? 0;
      final currentTier = (loyaltyData['currentTier'] as String?) ?? 'bronze';

      // Determine new tier
      String newTier = 'bronze';
      if (lifetime >= 5000) {
        newTier = 'gold';
      } else if (lifetime >= 2000)
        newTier = 'silver';

      // If tier changed, update and notify
      if (newTier != currentTier) {
        final now = DateTime.now();

        await _db.collection('loyalty').doc(userId).update({
          'currentTier': newTier,
          'tierUpgradeHistory': FieldValue.arrayUnion([
            {
              'tier': newTier,
              'timestamp': Timestamp.fromDate(now),
              'reason': 'lifetime_threshold_reached',
              'lifetimePoints': lifetime,
            },
          ]),
          'updatedAt': Timestamp.fromDate(now),
        });

        // Notify user
        final multiplier = tierMultipliers[newTier] ?? 1.0;
        final multiplierPercent = ((multiplier - 1.0) * 100).toInt();
        await _notifications.notifyCustomer(
          userId,
          'Congratulations! You\'ve reached $newTier tier! Earn $multiplierPercent% bonus points now.',
          {'tier': newTier, 'lifetimePoints': lifetime, 'multiplier': multiplier},
        );

        await _audit.log('loyalty_tier_upgraded', {
          'userId': userId,
          'fromTier': currentTier,
          'toTier': newTier,
          'lifetimePoints': lifetime,
        });

        debugPrint(
          '[LoyaltyWorkflowService] Upgraded $userId to $newTier tier (lifetime: $lifetime points)',
        );
      }
    } catch (e) {
      debugPrint('[LoyaltyWorkflowService] Failed to check tier upgrade: $e');
      // Don't rethrow - tier check shouldn't fail transactions
    }
  }

  /// Get loyalty account
  Future<Map<String, dynamic>?> getAccount(String userId) async {
    final snap = await _db.collection('loyalty').doc(userId).get();
    return snap.data();
  }

  /// Get loyalty transaction history
  Future<List<Map<String, dynamic>>> getTransactionHistory(String userId, {int limit = 50}) async {
    final snap = await _db
        .collection('loyalty_transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((doc) => doc.data()).toList();
  }

  /// Get tier upgrade history
  Future<List<Map<String, dynamic>>> getTierHistory(String userId) async {
    final snap = await _db.collection('loyalty').doc(userId).get();
    final data = snap.data();
    final history = (data?['tierUpgradeHistory'] as List?) ?? [];
    return history.cast<Map<String, dynamic>>();
  }

  /// Get referral status
  Future<Map<String, dynamic>?> getReferralStatus(String userId) async {
    final snap = await _db
        .collection('referrals')
        .where('referrerId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    return snap.docs.isEmpty ? null : snap.docs.first.data();
  }

  /// Get leaderboard (top users by lifetime points)
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 20}) async {
    final snap = await _db
        .collection('loyalty')
        .orderBy('lifetime', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((doc) => doc.data()).toList();
  }

  /// Stream loyalty account changes
  Stream<Map<String, dynamic>?> watchAccount(String userId) {
    return _db.collection('loyalty').doc(userId).snapshots().map((snap) => snap.data());
  }
}
