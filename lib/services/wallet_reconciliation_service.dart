import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class WalletReconciliationService {
  static final WalletReconciliationService _instance = WalletReconciliationService._internal();
  factory WalletReconciliationService() => _instance;
  WalletReconciliationService._internal();

  @visibleForTesting
  WalletReconciliationService.forTesting();

  FirebaseFirestore? _customDb;
  FirebaseFirestore get _db => _customDb ??= FirebaseFirestore.instance;
  set db(FirebaseFirestore database) => _customDb = database;

  /// LEVEL 1: Per-Wallet Reconciliation
  /// Verifies that a specific user's wallet balance equals Sum(Credits) - Sum(Debits)
  Future<bool> reconcileUserWallet(String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final double balance = ((userDoc.data()?['walletBalance'] as num?) ?? 0).toDouble();

      final txnsSnap = await _db
          .collection('users')
          .doc(userId)
          .collection('wallet_transactions')
          .get();

      double calculatedBalance = 0.0;
      for (final doc in txnsSnap.docs) {
        final data = doc.data();
        final amount = ((data['amount'] as num?) ?? 0).toDouble();
        calculatedBalance += amount;
      }

      // Allow for minor floating point discrepancies
      if ((balance - calculatedBalance).abs() > 0.01) {
        debugPrint(
          '[WalletReconciliation] Mismatch for user $userId. Stored: $balance, Calc: $calculatedBalance',
        );
        await _logAnomaly(userId: userId, level: 1, stored: balance, calculated: calculatedBalance);
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[WalletReconciliation] Error Level 1: $e');
      return false;
    }
  }

  /// LEVEL 2: System-Wide Reconciliation
  /// Verifies Sum(All Balances) == Sum(All Credits) - Sum(All Debits)
  Future<bool> reconcileSystemWide() async {
    try {
      final usersAgg = await _db.collection('users').aggregate(sum('walletBalance')).get();
      final totalStoredBalance = (usersAgg.getSum('walletBalance') as num? ?? 0.0).toDouble();

      final txnsSnap = await _db.collectionGroup('wallet_transactions').get();
      double calculatedSystemBalance = 0.0;
      for (final doc in txnsSnap.docs) {
        final amount = ((doc.data()['amount'] as num?) ?? 0.0).toDouble();
        calculatedSystemBalance += amount;
      }

      if ((totalStoredBalance - calculatedSystemBalance).abs() > 0.1) {
        debugPrint(
          '[WalletReconciliation] SYSTEM Mismatch. Stored: $totalStoredBalance, Calc: $calculatedSystemBalance',
        );
        await _logAnomaly(
          level: 2,
          stored: totalStoredBalance,
          calculated: calculatedSystemBalance,
        );
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[WalletReconciliation] Error Level 2: $e');
      return false;
    }
  }

  /// LEVEL 3: Payment Gateway Reconciliation
  /// Razorpay Captures = Orders Paid + Wallet Topups
  Future<bool> reconcilePaymentGateway() async {
    try {
      final paymentsSnap = await _db
          .collection('payments')
          .where('status', whereIn: ['success', 'captured'])
          .get();
      double totalCaptured = 0.0;
      for (final doc in paymentsSnap.docs) {
        totalCaptured += ((doc.data()['amount'] as num?) ?? 0.0).toDouble();
      }

      final ordersPaidSnap = await _db
          .collection('orders')
          .where('paymentStatus', isEqualTo: 'paid')
          .get();
      double totalOrdersPaid = 0.0;
      for (final doc in ordersPaidSnap.docs) {
        totalOrdersPaid += ((doc.data()['totalAmount'] as num?) ?? 0.0).toDouble();
      }

      final txnsSnap = await _db.collectionGroup('wallet_transactions').get();
      double totalTopups = 0.0;
      for (final doc in txnsSnap.docs) {
        final data = doc.data();
        final desc = data['description']?.toString() ?? '';
        final amount = ((data['amount'] as num?) ?? 0.0).toDouble();
        if (desc.contains('Top-up') && amount > 0) {
          totalTopups += amount;
        }
      }

      final expectedGateway = totalOrdersPaid + totalTopups;

      if ((totalCaptured - expectedGateway).abs() > 1.0) {
        debugPrint(
          '[WalletReconciliation] GATEWAY Mismatch. Captured: $totalCaptured, Expected: $expectedGateway',
        );
        await _logAnomaly(level: 3, stored: totalCaptured, calculated: expectedGateway);
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[WalletReconciliation] Error Level 3: $e');
      return false;
    }
  }

  Future<void> _logAnomaly({
    required int level,
    required double stored,
    required double calculated,
    String? userId,
  }) async {
    await _db.collection('transaction_integrity_events').add({
      'type': 'WALLET_MISMATCH',
      'level': level,
      'userId': userId,
      'storedAmount': stored,
      'calculatedAmount': calculated,
      'difference': stored - calculated,
      'status': 'UNRESOLVED',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
