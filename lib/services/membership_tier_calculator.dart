import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// MembershipTierCalculator manages membership tier upgrades based on lifetime spending
///
/// [Requirements 11.5]: Implements tier calculation based on lifetime spending:
/// - Bronze tier: ₹0-999
/// - Silver tier: ₹1000-4999
/// - Gold tier: ₹5000-19999
/// - Platinum tier: ₹20000+
class MembershipTierCalculator {
  static final MembershipTierCalculator _instance =
      MembershipTierCalculator._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  factory MembershipTierCalculator() {
    return _instance;
  }

  MembershipTierCalculator._internal();

  /// Tier thresholds based on lifetime spending
  static const Map<MembershipTier, double> tierThresholds = {
    MembershipTier.bronze: 0.0,
    MembershipTier.silver: 1000.0,
    MembershipTier.gold: 5000.0,
    MembershipTier.platinum: 20000.0,
  };

  /// Tier benefits (for display purposes)
  static const Map<MembershipTier, Map<String, dynamic>> tierBenefits = {
    MembershipTier.bronze: {
      'name': 'Bronze',
      'cashbackPercentage': 1.0,
      'pointsMultiplier': 1.0,
      'freeDeliveryThreshold': 500.0,
    },
    MembershipTier.silver: {
      'name': 'Silver',
      'cashbackPercentage': 1.5,
      'pointsMultiplier': 1.2,
      'freeDeliveryThreshold': 300.0,
    },
    MembershipTier.gold: {
      'name': 'Gold',
      'cashbackPercentage': 2.0,
      'pointsMultiplier': 1.5,
      'freeDeliveryThreshold': 200.0,
    },
    MembershipTier.platinum: {
      'name': 'Platinum',
      'cashbackPercentage': 3.0,
      'pointsMultiplier': 2.0,
      'freeDeliveryThreshold': 0.0,
    },
  };

  /// Calculates the appropriate membership tier based on lifetime spending
  ///
  /// [Requirements 11.5]: Updates tier on order completion
  MembershipTier calculateTier(double lifetimeSpending) {
    if (lifetimeSpending >= tierThresholds[MembershipTier.platinum]!) {
      return MembershipTier.platinum;
    } else if (lifetimeSpending >= tierThresholds[MembershipTier.gold]!) {
      return MembershipTier.gold;
    } else if (lifetimeSpending >= tierThresholds[MembershipTier.silver]!) {
      return MembershipTier.silver;
    } else {
      return MembershipTier.bronze;
    }
  }

  /// Updates user's membership tier based on their lifetime spending
  ///
  /// [Requirements 11.5]: Updates tier on order completion
  Future<MembershipTier?> updateMembershipTier(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);

      final result = await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final userData = userDoc.data()!;

        // Get lifetime spending from orders
        final lifetimeSpending = await _calculateLifetimeSpending(userId);

        // Calculate new tier
        final newTier = calculateTier(lifetimeSpending);
        final currentTier = MembershipTier.values.firstWhere(
          (e) => e.toString() == userData['membershipTier'],
          orElse: () => MembershipTier.bronze,
        );

        // Only update if tier changed
        if (newTier != currentTier) {
          transaction.update(userRef, {
            'membershipTier': newTier.toString(),
            'updatedAt': DateTime.now(),
          });

          // Record tier upgrade in history
          _recordTierUpgrade(transaction, userId, currentTier, newTier);
        }

        return newTier;
      });

      return result;
    } catch (e) {
      debugPrint('Error updating membership tier: $e');
      return null;
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

  /// Gets the current membership tier for a user
  Future<MembershipTier> getUserTier(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return MembershipTier.bronze;
      }

      return MembershipTier.values.firstWhere(
        (e) => e.toString() == userDoc.data()?['membershipTier'],
        orElse: () => MembershipTier.bronze,
      );
    } catch (e) {
      debugPrint('Error getting user tier: $e');
      return MembershipTier.bronze;
    }
  }

  /// Gets tier benefits for a specific tier
  Map<String, dynamic> getTierBenefits(MembershipTier tier) {
    return tierBenefits[tier] ?? tierBenefits[MembershipTier.bronze]!;
  }

  /// Gets the next tier and spending required to reach it
  Map<String, dynamic> getNextTierInfo(double currentSpending) {
    final currentTier = calculateTier(currentSpending);

    // Find next tier
    MembershipTier? nextTier;
    double spendingRequired = 0.0;

    if (currentTier == MembershipTier.bronze) {
      nextTier = MembershipTier.silver;
      spendingRequired =
          tierThresholds[MembershipTier.silver]! - currentSpending;
    } else if (currentTier == MembershipTier.silver) {
      nextTier = MembershipTier.gold;
      spendingRequired = tierThresholds[MembershipTier.gold]! - currentSpending;
    } else if (currentTier == MembershipTier.gold) {
      nextTier = MembershipTier.platinum;
      spendingRequired =
          tierThresholds[MembershipTier.platinum]! - currentSpending;
    }

    return {
      'currentTier': currentTier,
      'nextTier': nextTier,
      'spendingRequired': spendingRequired,
      'currentSpending': currentSpending,
    };
  }

  /// Gets tier progress percentage
  double getTierProgress(double currentSpending) {
    final currentTier = calculateTier(currentSpending);
    final currentThreshold = tierThresholds[currentTier] ?? 0.0;

    MembershipTier? nextTier;
    double nextThreshold = 0.0;

    if (currentTier == MembershipTier.bronze) {
      nextTier = MembershipTier.silver;
      nextThreshold = tierThresholds[MembershipTier.silver]!;
    } else if (currentTier == MembershipTier.silver) {
      nextTier = MembershipTier.gold;
      nextThreshold = tierThresholds[MembershipTier.gold]!;
    } else if (currentTier == MembershipTier.gold) {
      nextTier = MembershipTier.platinum;
      nextThreshold = tierThresholds[MembershipTier.platinum]!;
    } else {
      // Already at platinum
      return 100.0;
    }

    final progress =
        ((currentSpending - currentThreshold) /
            (nextThreshold - currentThreshold)) *
        100;
    return progress.clamp(0.0, 100.0);
  }

  /// Helper method to record tier upgrade
  void _recordTierUpgrade(
    Transaction transaction,
    String userId,
    MembershipTier oldTier,
    MembershipTier newTier,
  ) {
    final upgradeId = 'tier_${DateTime.now().millisecondsSinceEpoch}';
    final userRef = _firestore.collection('users').doc(userId);

    transaction.set(userRef.collection('tier_history').doc(upgradeId), {
      'id': upgradeId,
      'userId': userId,
      'oldTier': oldTier.toString(),
      'newTier': newTier.toString(),
      'timestamp': DateTime.now(),
    });
  }

  /// Streams membership tier changes in real-time
  Stream<MembershipTier> watchMembershipTier(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      return MembershipTier.values.firstWhere(
        (e) => e.toString() == doc.data()?['membershipTier'],
        orElse: () => MembershipTier.bronze,
      );
    });
  }

  /// Gets tier display name
  String getTierDisplayName(MembershipTier tier) {
    return tierBenefits[tier]?['name'] ?? 'Bronze';
  }

  /// Gets tier color for UI display
  Color getTierColor(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.bronze:
        return const Color(0xFFCD7F32); // Bronze color
      case MembershipTier.silver:
        return const Color(0xFFC0C0C0); // Silver color
      case MembershipTier.gold:
        return const Color(0xFFFFD700); // Gold color
      case MembershipTier.platinum:
        return const Color(0xFFE5E4E2); // Platinum color
    }
  }
}
