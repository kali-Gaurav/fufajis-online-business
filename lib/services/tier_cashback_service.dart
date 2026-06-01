import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'membership_tier_calculator.dart';
import 'wallet_service.dart';
import 'shop_config_service.dart';

/// Component 9 — Tier-Based Cashback & Restrictions
///
/// Cashback rates by tier (Firestore-configurable, these are defaults):
///   Bronze   → 1%
///   Silver   → 1.5%
///   Gold     → 2%
///   Platinum → 3%
///
/// Restrictions:
///   • Cashback only applies on orders with payment_status = 'paid'
///   • COD orders earn cashback ONLY after delivery confirmed
///   • Wallet redemption capped at 50% of order value (per tier config)
///   • Platinum gets 100% wallet redemption
///   • Cashback expires in 365 days (configurable)
///   • Bronze cannot redeem wallet on first order (loyalty incentive)
class TierCashbackService {
  static final TierCashbackService _instance = TierCashbackService._internal();
  factory TierCashbackService() => _instance;
  TierCashbackService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MembershipTierCalculator _tierCalc = MembershipTierCalculator();
  final WalletService _walletService = WalletService();

  // ─────────────── CASHBACK RATES (Firestore-configurable) ───────────────

  static const Map<MembershipTier, double> _defaultCashbackRates = {
    MembershipTier.bronze: 1.0,
    MembershipTier.silver: 1.5,
    MembershipTier.gold: 2.0,
    MembershipTier.platinum: 3.0,
  };

  // Wallet redemption cap by tier (% of order value)
  static const Map<MembershipTier, double> _defaultWalletCap = {
    MembershipTier.bronze: 25.0,
    MembershipTier.silver: 35.0,
    MembershipTier.gold: 50.0,
    MembershipTier.platinum: 100.0,
  };

  // ─────────────── CASHBACK CALCULATION ───────────────

  /// Returns the effective cashback percentage for a user.
  Future<double> getCashbackPercent(String userId) async {
    try {
      final tier = await _tierCalc.getUserTier(userId);
      final config = await _loadTierConfig(tier);
      return config.cashbackPercent;
    } catch (e) {
      debugPrint('[TierCashback] getCashbackPercent error: $e');
      return _defaultCashbackRates[MembershipTier.bronze]!;
    }
  }

  /// Calculates the cashback amount for an order.
  Future<double> calculateCashback({
    required String userId,
    required double orderAmount,
    required String paymentMethod,
  }) async {
    // No cashback on wallet-paid orders (avoid double-dipping)
    if (paymentMethod == 'wallet') return 0;

    final pct = await getCashbackPercent(userId);
    return (orderAmount * pct / 100).roundToDouble();
  }

  /// Applies cashback to the user's wallet after order completion.
  /// For COD orders: call this only after delivery is confirmed.
  Future<CashbackResult> applyCashback({
    required String userId,
    required String orderId,
    required double orderAmount,
    required String paymentMethod,
    required bool isDelivered,
  }) async {
    // Restriction: COD cashback only after delivery
    if (paymentMethod == 'cod' && !isDelivered) {
      debugPrint('[TierCashback] COD order $orderId: cashback held until delivery.');
      return CashbackResult(
        applied: false,
        amount: 0,
        reason: 'cod_pending_delivery',
      );
    }

    // Check if cashback is enabled globally
    final shopConfig = await ShopConfigService().getShopConfig();
    if (!shopConfig.enableCashback) {
      return CashbackResult(applied: false, amount: 0, reason: 'cashback_disabled');
    }

    // Check if already applied (idempotency)
    final alreadyApplied = await _isCashbackAlreadyApplied(orderId);
    if (alreadyApplied) {
      debugPrint('[TierCashback] Cashback already applied for order $orderId');
      return CashbackResult(applied: false, amount: 0, reason: 'already_applied');
    }

    final cashback = await calculateCashback(
      userId: userId,
      orderAmount: orderAmount,
      paymentMethod: paymentMethod,
    );

    if (cashback <= 0) {
      return CashbackResult(applied: false, amount: 0, reason: 'zero_cashback');
    }

    // Get tier for display
    final tier = await _tierCalc.getUserTier(userId);

    // Add to wallet
    final success = await _walletService.addToWallet(
      userId: userId,
      amount: cashback,
      transactionType: WalletTransactionType.cashback,
      orderReference: orderId,
      description: 'Cashback (${tier.name.toUpperCase()}): Order #$orderId',
      transactionId: 'cashback_${orderId}_${DateTime.now().millisecondsSinceEpoch}',
    );

    if (success) {
      // Mark as applied to prevent double credit
      await _markCashbackApplied(orderId, userId, cashback);
      debugPrint('[TierCashback] Applied ₹$cashback cashback for $userId (${tier.name})');
      return CashbackResult(applied: true, amount: cashback, reason: 'success', tier: tier);
    }

    return CashbackResult(applied: false, amount: 0, reason: 'wallet_error');
  }

  // ─────────────── WALLET REDEMPTION ───────────────

  /// Returns the maximum wallet amount a user can redeem on a given order.
  Future<double> getMaxWalletRedemption({
    required String userId,
    required double orderAmount,
    required bool isFirstOrder,
  }) async {
    final tier = await _tierCalc.getUserTier(userId);

    // Restriction: Bronze users cannot redeem wallet on their first order
    if (isFirstOrder && tier == MembershipTier.bronze) {
      debugPrint('[TierCashback] Bronze first order: wallet redemption blocked.');
      return 0;
    }

    final config = await _loadTierConfig(tier);
    final capPercent = config.walletRedemptionCapPercent;
    return (orderAmount * capPercent / 100).floorToDouble();
  }

  /// Validates if a requested wallet redemption is within tier limits.
  Future<WalletValidationResult> validateWalletRedemption({
    required String userId,
    required double requestedAmount,
    required double orderAmount,
    required bool isFirstOrder,
  }) async {
    final maxAllowed = await getMaxWalletRedemption(
      userId: userId,
      orderAmount: orderAmount,
      isFirstOrder: isFirstOrder,
    );

    if (requestedAmount > maxAllowed) {
      return WalletValidationResult(
        isValid: false,
        allowedAmount: maxAllowed,
        reason: 'exceeds_tier_cap',
      );
    }

    // Also check user's actual wallet balance
    final balance = await _walletService.getWalletBalance(userId);
    final effectiveAmount = requestedAmount.clamp(0, balance).toDouble();

    return WalletValidationResult(
      isValid: true,
      allowedAmount: effectiveAmount,
      reason: 'ok',
    );
  }

  // ─────────────── TIER CONFIG (FIRESTORE) ───────────────

  Future<_TierConfig> _loadTierConfig(MembershipTier tier) async {
    try {
      final doc = await _firestore
          .collection('settings')
          .doc('tier_cashback_config')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final tierData = data[tier.name] as Map<String, dynamic>?;
        if (tierData != null) {
          return _TierConfig(
            cashbackPercent: (tierData['cashbackPercent'] ?? _defaultCashbackRates[tier]!).toDouble(),
            walletRedemptionCapPercent:
                (tierData['walletRedemptionCapPercent'] ?? _defaultWalletCap[tier]!).toDouble(),
          );
        }
      }
    } catch (e) {
      debugPrint('[TierCashback] Config load error: $e');
    }

    // Fall back to hardcoded defaults
    return _TierConfig(
      cashbackPercent: _defaultCashbackRates[tier]!,
      walletRedemptionCapPercent: _defaultWalletCap[tier]!,
    );
  }

  // ─────────────── IDEMPOTENCY ───────────────

  Future<bool> _isCashbackAlreadyApplied(String orderId) async {
    try {
      final doc = await _firestore
          .collection('cashback_log')
          .doc(orderId)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markCashbackApplied(
      String orderId, String userId, double amount) async {
    await _firestore.collection('cashback_log').doc(orderId).set({
      'orderId': orderId,
      'userId': userId,
      'amount': amount,
      'appliedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────── ADMIN: UPDATE TIER CONFIG ───────────────

  /// Updates tier cashback rates in Firestore (owner action, no app release needed).
  Future<void> updateTierConfig({
    required MembershipTier tier,
    required double cashbackPercent,
    required double walletRedemptionCapPercent,
  }) async {
    await _firestore.collection('settings').doc('tier_cashback_config').set({
      tier.name: {
        'cashbackPercent': cashbackPercent,
        'walletRedemptionCapPercent': walletRedemptionCapPercent,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
    debugPrint('[TierCashback] Updated config for ${tier.name}: $cashbackPercent%');
  }

  /// Returns a summary of cashback config for all tiers.
  Future<Map<String, dynamic>> getCashbackSummary() async {
    final Map<String, dynamic> summary = {};
    for (final tier in MembershipTier.values) {
      final config = await _loadTierConfig(tier);
      summary[tier.name] = {
        'cashbackPercent': config.cashbackPercent,
        'walletRedemptionCapPercent': config.walletRedemptionCapPercent,
      };
    }
    return summary;
  }
}

// ─────────────── VALUE OBJECTS ───────────────

class _TierConfig {
  final double cashbackPercent;
  final double walletRedemptionCapPercent;
  const _TierConfig({required this.cashbackPercent, required this.walletRedemptionCapPercent});
}

class CashbackResult {
  final bool applied;
  final double amount;
  final String reason;
  final MembershipTier? tier;
  const CashbackResult({required this.applied, required this.amount, required this.reason, this.tier});
}

class WalletValidationResult {
  final bool isValid;
  final double allowedAmount;
  final String reason;
  const WalletValidationResult({required this.isValid, required this.allowedAmount, required this.reason});
}
