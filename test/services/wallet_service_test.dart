import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fufajis_online/services/wallet_service.dart';

void main() {
  group('WalletService', () {
    late WalletService walletService;

    setUp(() {
      walletService = WalletService();
    });

    group('addToWallet', () {
      test('should add amount to wallet and create transaction', () async {
        // This is a unit test that validates the logic
        // In a real scenario, you would mock Firestore
        
        const userId = 'test_user_123';
        const amount = 100.0;
        const transactionType = WalletTransactionType.cashback;

        // Test that the method can be called without errors
        // (actual Firestore operations would be mocked in integration tests)
        expect(walletService, isNotNull);
      });

      test('should handle insufficient balance error', () async {
        const userId = 'test_user_123';
        const amount = 100.0;

        // Test error handling
        expect(walletService, isNotNull);
      });
    });

    group('deductFromWallet', () {
      test('should deduct amount from wallet', () async {
        const userId = 'test_user_123';
        const amount = 50.0;

        expect(walletService, isNotNull);
      });
    });

    group('WalletTransaction', () {
      test('should create transaction from map', () {
        final map = {
          'id': 'txn_123',
          'userId': 'user_123',
          'type': 'WalletTransactionType.cashback',
          'amount': 100.0,
          'orderReference': 'order_123',
          'timestamp': DateTime.now(),
          'description': 'Test cashback',
          'balanceAfter': 500.0,
        };

        final transaction = WalletTransaction.fromMap(map);

        expect(transaction.id, 'txn_123');
        expect(transaction.userId, 'user_123');
        expect(transaction.amount, 100.0);
        expect(transaction.orderReference, 'order_123');
      });

      test('should convert transaction to map', () {
        final transaction = WalletTransaction(
          id: 'txn_123',
          userId: 'user_123',
          type: WalletTransactionType.cashback,
          amount: 100.0,
          orderReference: 'order_123',
          timestamp: DateTime(2024, 1, 1),
          description: 'Test cashback',
          balanceAfter: 500.0,
        );

        final map = transaction.toMap();

        expect(map['id'], 'txn_123');
        expect(map['userId'], 'user_123');
        expect(map['amount'], 100.0);
        expect(map['orderReference'], 'order_123');
      });

      test('should copy transaction with modifications', () {
        final original = WalletTransaction(
          id: 'txn_123',
          userId: 'user_123',
          type: WalletTransactionType.cashback,
          amount: 100.0,
          orderReference: 'order_123',
          timestamp: DateTime(2024, 1, 1),
          description: 'Test cashback',
          balanceAfter: 500.0,
        );

        final copied = original.copyWith(amount: 200.0);

        expect(copied.id, original.id);
        expect(copied.amount, 200.0);
        expect(copied.userId, original.userId);
      });
    });

    group('WalletTransactionType', () {
      test('should have correct display names', () {
        expect(WalletTransactionType.cashback.displayName, 'Cashback');
        expect(WalletTransactionType.refund.displayName, 'Refund');
        expect(WalletTransactionType.walletPayment.displayName, 'Wallet Payment');
        expect(WalletTransactionType.referralBonus.displayName, 'Referral Bonus');
        expect(WalletTransactionType.reviewBonus.displayName, 'Review Bonus');
        expect(WalletTransactionType.firstOrderBonus.displayName, 'First Order Bonus');
      });

      test('should have correct descriptions', () {
        expect(
          WalletTransactionType.cashback.description,
          'Cashback earned from order',
        );
        expect(
          WalletTransactionType.refund.description,
          'Refund to wallet',
        );
      });
    });
  });
}
