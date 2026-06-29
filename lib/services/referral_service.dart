import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import 'wallet_service.dart';

/// ReferralService — the end-to-end "Refer & Earn" loop for Fufaji's Online.
///
/// Responsibilities:
///  1. Generate a stable, human-friendly referral code for each user.
///  2. Record [referredBy] when a new user signs up with a friend's code.
///  3. Pay BOTH the referrer and the new user a ₹ wallet bonus when the new
///     user places their first order (idempotent via [referralRedeemed]).
///  4. List the friends a user has successfully referred (for the UI).
///
/// All Firestore writes are guarded so a referral failure can never break the
/// surrounding flow (signup / order placement).
class ReferralService {
  ReferralService({FirebaseFirestore? firestore, WalletService? walletService})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _wallet = walletService ?? WalletService();

  final FirebaseFirestore _firestore;
  final WalletService _wallet;

  /// ₹ credited to the friend who joins (the referee).
  static const double refereeReward = 50.0;

  /// ₹ credited to the existing user who referred them (the referrer).
  static const double referrerReward = 50.0;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  // ── Code generation ────────────────────────────────────────────────────────

  /// Builds a deterministic, readable code from a name + uid, e.g. "RAVI4F9A".
  /// Derived from the (unique) uid, so practical collisions are negligible.
  static String buildCode({String? name, required String uid}) {
    final alpha = (name ?? '')
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '');
    final prefix = alpha.isNotEmpty
        ? alpha.substring(0, alpha.length >= 4 ? 4 : alpha.length)
        : 'FUFA';
    final clean = uid.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final suffix = clean.length >= 4
        ? clean.substring(clean.length - 4)
        : clean.padLeft(4, '0');
    return '$prefix$suffix';
  }

  /// Returns the user's referral code, generating + persisting one if missing.
  Future<String> ensureReferralCode(UserModel user) async {
    if (user.referralCode != null && user.referralCode!.isNotEmpty) {
      return user.referralCode!;
    }
    final code = buildCode(name: user.name, uid: user.id);
    try {
      await _users.doc(user.id).set(
        {'referralCode': code, 'updatedAt': DateTime.now()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[ReferralService] ensureReferralCode failed: $e');
    }
    return code;
  }

  // ── Applying a code at signup ───────────────────────────────────────────────

  /// Result of attempting to apply a referral code.
  /// Look up the user who owns [code]. Returns null if none / invalid.
  Future<UserModel?> _findUserByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final snap = await _users
        .where('referralCode', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return UserModel.fromMap({...snap.docs.first.data(), 'id': snap.docs.first.id});
  }

  /// Records that [newUserId] was referred by the owner of [code].
  /// Returns a short status string for UI feedback.
  Future<ReferralApplyResult> applyReferralCode({
    required String newUserId,
    required String code,
  }) async {
    try {
      final referrer = await _findUserByCode(code);
      if (referrer == null) {
        return ReferralApplyResult(false, 'Invalid referral code.');
      }
      if (referrer.id == newUserId) {
        return ReferralApplyResult(false, 'You cannot use your own code.');
      }

      final meRef = _users.doc(newUserId);
      final meSnap = await meRef.get();
      if (meSnap.exists && (meSnap.data()?['referredBy'] != null)) {
        return ReferralApplyResult(false, 'A referral code was already applied.');
      }

      await meRef.set(
        {'referredBy': referrer.id, 'updatedAt': DateTime.now()},
        SetOptions(merge: true),
      );
      return ReferralApplyResult(
        true,
        'Code applied! You\'ll both get ₹${refereeReward.toStringAsFixed(0)} after your first order.',
        referrerName: referrer.name,
      );
    } catch (e) {
      debugPrint('[ReferralService] applyReferralCode failed: $e');
      return ReferralApplyResult(false, 'Could not apply code. Try again.');
    }
  }

  // ── Payout on first order ───────────────────────────────────────────────────

  /// Pays the referral bonus to both parties the first time the referred user
  /// places an order. Safe to call after every order — the [referralRedeemed]
  /// flag makes it idempotent. Never throws.
  Future<bool> redeemReferralOnFirstOrder(String userId, {String? orderId}) async {
    try {
      final meSnap = await _users.doc(userId).get();
      if (!meSnap.exists) return false;
      final data = meSnap.data()!;

      final referredBy = data['referredBy'] as String?;
      final alreadyRedeemed = data['referralRedeemed'] == true;
      if (referredBy == null || referredBy.isEmpty || alreadyRedeemed) {
        return false;
      }

      // Mark redeemed FIRST (atomic guard) so concurrent orders can't double-pay.
      final claimed = await _firestore.runTransaction<bool>((txn) async {
        final fresh = await txn.get(_users.doc(userId));
        if (fresh.data()?['referralRedeemed'] == true) return false;
        txn.update(_users.doc(userId), {
          'referralRedeemed': true,
          'updatedAt': DateTime.now(),
        });
        return true;
      });
      if (!claimed) return false;

      final txnTag = orderId ?? DateTime.now().millisecondsSinceEpoch.toString();

      // 1) Credit the new user (referee).
      await _wallet.addToWallet(
        userId: userId,
        amount: refereeReward,
        transactionType: WalletTransactionType.referralBonus,
        description: 'Welcome bonus for joining via referral',
        transactionId: 'ref_referee_$txnTag',
      );

      // 2) Credit the referrer + bump their counters.
      await _wallet.addToWallet(
        userId: referredBy,
        amount: referrerReward,
        transactionType: WalletTransactionType.referralBonus,
        description: 'Your friend completed their first order',
        transactionId: 'ref_referrer_$txnTag',
      );
      await _users.doc(referredBy).set({
        'referralCount': FieldValue.increment(1),
        'referralEarnings': FieldValue.increment(referrerReward),
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint('[ReferralService] redeemReferralOnFirstOrder failed: $e');
      return false;
    }
  }

  // ── Reading referred friends (for the screen) ───────────────────────────────

  /// Friends this user has referred, newest first.
  Future<List<ReferredFriend>> getReferredFriends(String userId) async {
    try {
      final snap = await _users
          .where('referredBy', isEqualTo: userId)
          .get();
      final list = snap.docs.map((d) {
        final m = d.data();
        return ReferredFriend(
          name: (m['name'] as String?)?.trim().isNotEmpty == true
              ? m['name'] as String
              : 'New friend',
          joinedAt: (m['createdAt'] is Timestamp)
              ? (m['createdAt'] as Timestamp).toDate()
              : null,
          completed: m['referralRedeemed'] == true,
        );
      }).toList();
      list.sort((a, b) =>
          (b.joinedAt ?? DateTime(2000)).compareTo(a.joinedAt ?? DateTime(2000)));
      return list;
    } catch (e) {
      debugPrint('[ReferralService] getReferredFriends failed: $e');
      return [];
    }
  }
}

class ReferralApplyResult {
  final bool success;
  final String message;
  final String? referrerName;
  ReferralApplyResult(this.success, this.message, {this.referrerName});
}

class ReferredFriend {
  final String name;
  final DateTime? joinedAt;
  final bool completed; // true once their first order paid out
  ReferredFriend({required this.name, this.joinedAt, required this.completed});
}
