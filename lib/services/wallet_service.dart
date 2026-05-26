import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// Enum for wallet transaction types
enum WalletTransactionType {
  cashback,
  rewardPointsRedeemed,
  walletPayment,
  refund,
  referralBonus,
  reviewBonus,
  firstOrderBonus,
}

/// Extension for transaction type display
extension WalletTransactionTypeExtension on WalletTransactionType {
  String get displayName {
    switch (this) {
      case WalletTransactionType.cashback:
        return 'Cashback';
      case WalletTransactionType.rewardPointsRedeemed:
        return 'Reward Points Redeemed';
      case WalletTransactionType.walletPayment:
        return 'Wallet Payment';
      case WalletTransactionType.refund:
        return 'Refund';
      case WalletTransactionType.referralBonus:
        return 'Referral Bonus';
      case WalletTransactionType.reviewBonus:
        return 'Review Bonus';
      case WalletTransactionType.firstOrderBonus:
        return 'First Order Bonus';
    }
  }

  String get description {
    switch (this) {
      case WalletTransactionType.cashback:
        return 'Cashback earned from order';
      case WalletTransactionType.rewardPointsRedeemed:
        return 'Reward points converted to wallet';
      case WalletTransactionType.walletPayment:
        return 'Payment from wallet';
      case WalletTransactionType.refund:
        return 'Refund to wallet';
      case WalletTransactionType.referralBonus:
        return 'Referral bonus';
      case WalletTransactionType.reviewBonus:
        return 'Review bonus';
      case WalletTransactionType.firstOrderBonus:
        return 'First order bonus';
    }
  }
}

/// Model for wallet transaction history
class WalletTransaction {
  final String id;
  final String userId;
  final WalletTransactionType type;
  final double amount;
  final String? orderReference;
  final DateTime timestamp;
  final String? description;
  final double balanceAfter;

  WalletTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.orderReference,
    required this.timestamp,
    this.description,
    required this.balanceAfter,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: WalletTransactionType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => WalletTransactionType.cashback,
      ),
      amount: (map['amount'] ?? 0.0).toDouble(),
      orderReference: map['orderReference'],
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is DateTime
              ? map['timestamp']
              : map['timestamp'].toDate())
          : DateTime.now(),
      description: map['description'],
      balanceAfter: (map['balanceAfter'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type.toString(),
      'amount': amount,
      'orderReference': orderReference,
      'timestamp': timestamp,
      'description': description,
      'balanceAfter': balanceAfter,
    };
  }

  WalletTransaction copyWith({
    String? id,
    String? userId,
    WalletTransactionType? type,
    double? amount,
    String? orderReference,
    DateTime? timestamp,
    String? description,
    double? balanceAfter,
  }) {
    return WalletTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      orderReference: orderReference ?? this.orderReference,
      timestamp: timestamp ?? this.timestamp,
      description: description ?? this.description,
      balanceAfter: balanceAfter ?? this.balanceAfter,
    );
  }
}

/// WalletService handles all wallet-related operations
/// 
/// Responsibilities:
/// - Update wallet balance with Firestore sync
/// - Track wallet transaction history
/// - Manage wallet transactions with proper auditing
class WalletService {
  static final WalletService _instance = WalletService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  factory WalletService() {
    return _instance;
  }

  WalletService._internal();

  /// Adds amount to wallet balance and records transaction
  /// 
  /// [Requirements 11.1, 11.6, 11.7]: Updates wallet balance with Firestore sync
  /// and tracks transaction history (transaction type, amount, order reference, timestamp)
  Future<bool> addToWallet({
    required String userId,
    required double amount,
    required WalletTransactionType transactionType,
    String? orderReference,
    String? description,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final transactionId = 'txn_${DateTime.now().millisecondsSinceEpoch}';

      // Use transaction to ensure atomicity
      await _firestore.runTransaction((transaction) async {
        // Get current user data
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final userData = userDoc.data()!;
        final currentBalance = (userData['walletBalance'] ?? 0.0).toDouble();
        final newBalance = currentBalance + amount;

        // Update user wallet balance
        transaction.update(userRef, {
          'walletBalance': newBalance,
          'updatedAt': DateTime.now(),
        });

        // Create transaction record
        final transactionData = WalletTransaction(
          id: transactionId,
          userId: userId,
          type: transactionType,
          amount: amount,
          orderReference: orderReference,
          timestamp: DateTime.now(),
          description: description ?? transactionType.description,
          balanceAfter: newBalance,
        );

        transaction.set(
          userRef.collection('wallet_transactions').doc(transactionId),
          transactionData.toMap(),
        );
      });

      return true;
    } catch (e) {
      debugPrint('Error adding to wallet: $e');
      return false;
    }
  }

  /// Deducts amount from wallet balance and records transaction
  Future<bool> deductFromWallet({
    required String userId,
    required double amount,
    required WalletTransactionType transactionType,
    String? orderReference,
    String? description,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final transactionId = 'txn_${DateTime.now().millisecondsSinceEpoch}';

      // Use transaction to ensure atomicity
      await _firestore.runTransaction((transaction) async {
        // Get current user data
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final userData = userDoc.data()!;
        final currentBalance = (userData['walletBalance'] ?? 0.0).toDouble();

        // Check if sufficient balance
        if (currentBalance < amount) {
          throw Exception('Insufficient wallet balance');
        }

        final newBalance = currentBalance - amount;

        // Update user wallet balance
        transaction.update(userRef, {
          'walletBalance': newBalance,
          'updatedAt': DateTime.now(),
        });

        // Create transaction record
        final transactionData = WalletTransaction(
          id: transactionId,
          userId: userId,
          type: transactionType,
          amount: amount,
          orderReference: orderReference,
          timestamp: DateTime.now(),
          description: description ?? transactionType.description,
          balanceAfter: newBalance,
        );

        transaction.set(
          userRef.collection('wallet_transactions').doc(transactionId),
          transactionData.toMap(),
        );
      });

      return true;
    } catch (e) {
      debugPrint('Error deducting from wallet: $e');
      return false;
    }
  }

  /// Gets wallet balance for a user
  Future<double> getWalletBalance(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return 0.0;
      }
      return (userDoc.data()?['walletBalance'] ?? 0.0).toDouble();
    } catch (e) {
      debugPrint('Error getting wallet balance: $e');
      return 0.0;
    }
  }

  /// Fetches wallet transaction history with pagination
  /// 
  /// [Requirements 11.7]: Displays transaction history with pagination,
  /// showing transaction type, amount, order reference, timestamp
  Future<List<WalletTransaction>> getTransactionHistory({
    required String userId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .doc(userId)
          .collection('wallet_transactions')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => WalletTransaction.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching transaction history: $e');
      return [];
    }
  }

  /// Filters transaction history by type
  Future<List<WalletTransaction>> getTransactionsByType({
    required String userId,
    required WalletTransactionType type,
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('wallet_transactions')
          .where('type', isEqualTo: type.toString())
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => WalletTransaction.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching transactions by type: $e');
      return [];
    }
  }

  /// Gets transaction history for a specific order
  Future<List<WalletTransaction>> getTransactionsByOrder({
    required String userId,
    required String orderReference,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('wallet_transactions')
          .where('orderReference', isEqualTo: orderReference)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => WalletTransaction.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching transactions by order: $e');
      return [];
    }
  }

  /// Streams wallet balance changes in real-time
  Stream<double> watchWalletBalance(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => (doc.data()?['walletBalance'] ?? 0.0).toDouble());
  }

  /// Streams transaction history changes in real-time
  Stream<List<WalletTransaction>> watchTransactionHistory(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('wallet_transactions')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WalletTransaction.fromMap(doc.data()))
            .toList());
  }
}
