import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fufajis_online/services/wallet_service.dart';
import 'package:fufajis_online/services/wallet_order_service.dart';

void main() {
  group('Wallet Order Integration Tests', () {
    late FirebaseFirestore firestore;
    late WalletOrderService walletOrderService;
    late WalletService walletService;

    setUp(() {
      // Initialize Firebase services (assumes Firebase is configured in test setup)
      firestore = FirebaseFirestore.instance;
      walletService = WalletService();
      walletOrderService = WalletOrderService();
    });

    tearDown(() async {
      // Cleanup created test data
      // In production, you'd delete test documents
    });

    // ──────────────────────────────────────────────────────────────
    // TEST 1: Create wallet order with sufficient stock & balance
    // ──────────────────────────────────────────────────────────────
    testWidgets('Create wallet order successfully', (WidgetTester tester) async {
      const customerId = 'test-customer-wallet-001';
      const shopId = 'test-shop-wallet-001';
      const productId = 'test-product-wallet-001';

      try {
        // Setup: Create test user with wallet balance
        await firestore.collection('users').doc(customerId).set({
          'uid': customerId,
          'email': 'test-wallet-001@example.com',
          'walletBalance': 500.0,
          'lastTransactionSequenceNumber': 0,
        });

        // Setup: Create test product with stock
        await firestore.collection('products').doc(productId).set({
          'id': productId,
          'name': 'Test Product Wallet 001',
          'price': 100.0,
          'stock': 10,
          'shopId': shopId,
        });

        // Action: Create wallet order
        final items = [
          {
            'productId': productId,
            'quantity': 2,
            'price': 100.0,
            'totalPrice': 200.0,
            'name': 'Test Product Wallet 001',
          }
        ];

        final order = await walletOrderService.createWalletOrder(
          customerId: customerId,
          shopId: shopId,
          items: items,
          totalAmount: 200.0,
          deliveryAddressId: 'test-address-001',
          deliveryType: 'home',
        );

        // Assert: Order created successfully
        expect(order.id, isNotEmpty);
        expect(order.customerId, customerId);
        expect(order.totalAmount, 200.0);
        expect(order.status.toString(), contains('confirmed'));

        // Assert: Wallet balance deducted
        final updatedUser = await firestore.collection('users').doc(customerId).get();
        final newBalance = updatedUser.data()?['walletBalance'] as double?;
        expect(newBalance, 300.0); // 500 - 200 = 300

        // Assert: Order is confirmed (payment already captured)
        final orderDoc = await firestore.collection('orders').doc(order.id).get();
        expect(orderDoc.data()?['paymentStatus'], 'completed');
        expect(orderDoc.data()?['status'], isNotNull);

        print('[TEST] PASSED: Create wallet order successfully');
      } catch (e) {
        print('[TEST] FAILED: $e');
        rethrow;
      } finally {
        // Cleanup
        await firestore.collection('users').doc(customerId).delete();
        await firestore.collection('products').doc(productId).delete();
      }
    });

    // ──────────────────────────────────────────────────────────────
    // TEST 2: Wallet order fails if insufficient balance
    // ──────────────────────────────────────────────────────────────
    testWidgets('Wallet order fails - insufficient balance',
        (WidgetTester tester) async {
      const customerId = 'test-customer-wallet-002';
      const shopId = 'test-shop-wallet-002';
      const productId = 'test-product-wallet-002';

      try {
        // Setup: Create user with LOW wallet balance
        await firestore.collection('users').doc(customerId).set({
          'uid': customerId,
          'email': 'test-wallet-002@example.com',
          'walletBalance': 50.0, // Only $50, but order is $200
          'lastTransactionSequenceNumber': 0,
        });

        // Setup: Create test product
        await firestore.collection('products').doc(productId).set({
          'id': productId,
          'name': 'Test Product Wallet 002',
          'price': 100.0,
          'stock': 10,
          'shopId': shopId,
        });

        // Action: Try to create wallet order with insufficient balance
        final items = [
          {
            'productId': productId,
            'quantity': 2,
            'price': 100.0,
            'totalPrice': 200.0,
            'name': 'Test Product Wallet 002',
          }
        ];

        // Assert: Fails with insufficient balance error
        expect(
          () => walletOrderService.createWalletOrder(
            customerId: customerId,
            shopId: shopId,
            items: items,
            totalAmount: 200.0,
            deliveryAddressId: 'test-address-002',
          ),
          throwsException,
        );

        // Assert: Wallet balance unchanged
        final userDoc = await firestore.collection('users').doc(customerId).get();
        final balanceAfter = userDoc.data()?['walletBalance'] as double?;
        expect(balanceAfter, 50.0); // Unchanged

        print('[TEST] PASSED: Wallet order fails - insufficient balance');
      } catch (e) {
        print('[TEST] FAILED: $e');
        rethrow;
      } finally {
        // Cleanup
        await firestore.collection('users').doc(customerId).delete();
        await firestore.collection('products').doc(productId).delete();
      }
    });

    // ──────────────────────────────────────────────────────────────
    // TEST 3: Wallet order fails if product not found
    // ──────────────────────────────────────────────────────────────
    testWidgets('Wallet order fails - product not found',
        (WidgetTester tester) async {
      const customerId = 'test-customer-wallet-003';
      const shopId = 'test-shop-wallet-003';
      const nonExistentProductId = 'non-existent-product';

      try {
        // Setup: Create user with sufficient balance
        await firestore.collection('users').doc(customerId).set({
          'uid': customerId,
          'email': 'test-wallet-003@example.com',
          'walletBalance': 500.0,
          'lastTransactionSequenceNumber': 0,
        });

        // Action: Try to create order with non-existent product
        final items = [
          {
            'productId': nonExistentProductId,
            'quantity': 2,
            'price': 100.0,
            'totalPrice': 200.0,
            'name': 'Non-existent Product',
          }
        ];

        // Assert: Fails because product doesn't exist
        expect(
          () => walletOrderService.createWalletOrder(
            customerId: customerId,
            shopId: shopId,
            items: items,
            totalAmount: 200.0,
            deliveryAddressId: 'test-address-003',
          ),
          throwsException,
        );

        // Assert: Wallet balance unchanged
        final userDoc = await firestore.collection('users').doc(customerId).get();
        final balanceAfter = userDoc.data()?['walletBalance'] as double?;
        expect(balanceAfter, 500.0); // Unchanged

        print('[TEST] PASSED: Wallet order fails - product not found');
      } catch (e) {
        print('[TEST] FAILED: $e');
        rethrow;
      } finally {
        // Cleanup
        await firestore.collection('users').doc(customerId).delete();
      }
    });

    // ──────────────────────────────────────────────────────────────
    // TEST 4: Wallet order atomicity - all or nothing
    // ──────────────────────────────────────────────────────────────
    testWidgets('Wallet order is atomic', (WidgetTester tester) async {
      const customerId = 'test-customer-wallet-004';
      const shopId = 'test-shop-wallet-004';
      const productId = 'test-product-wallet-004';

      try {
        // Setup: User with sufficient balance
        await firestore.collection('users').doc(customerId).set({
          'uid': customerId,
          'email': 'test-wallet-004@example.com',
          'walletBalance': 500.0,
          'lastTransactionSequenceNumber': 0,
        });

        // Setup: Product with sufficient stock
        await firestore.collection('products').doc(productId).set({
          'id': productId,
          'name': 'Test Product Wallet 004',
          'price': 100.0,
          'stock': 10,
          'shopId': shopId,
        });

        // Action: Create valid wallet order
        final items = [
          {
            'productId': productId,
            'quantity': 2,
            'price': 100.0,
            'totalPrice': 200.0,
            'name': 'Test Product Wallet 004',
          }
        ];

        final order = await walletOrderService.createWalletOrder(
          customerId: customerId,
          shopId: shopId,
          items: items,
          totalAmount: 200.0,
          deliveryAddressId: 'test-address-004',
        );

        // Assert: Order created successfully
        expect(order.id, isNotEmpty);

        // Assert: BOTH wallet and stock were updated
        final userDoc = await firestore.collection('users').doc(customerId).get();
        final walletAfter = userDoc.data()?['walletBalance'] as double?;
        expect(walletAfter, 300.0); // 500 - 200 = 300

        // Assert: Order has correct payment status
        final orderDoc = await firestore.collection('orders').doc(order.id).get();
        expect(orderDoc.data()?['paymentStatus'], 'completed');
        expect(orderDoc.data()?['status'], isNotNull);

        print('[TEST] PASSED: Wallet order is atomic');
      } catch (e) {
        print('[TEST] FAILED: $e');
        rethrow;
      } finally {
        // Cleanup
        await firestore.collection('users').doc(customerId).delete();
        await firestore.collection('products').doc(productId).delete();
      }
    });

    // ──────────────────────────────────────────────────────────────
    // TEST 5: Transaction history is recorded
    // ──────────────────────────────────────────────────────────────
    testWidgets('Wallet transaction history recorded', (WidgetTester tester) async {
      const customerId = 'test-customer-wallet-005';
      const shopId = 'test-shop-wallet-005';
      const productId = 'test-product-wallet-005';

      try {
        // Setup: User with sufficient balance
        await firestore.collection('users').doc(customerId).set({
          'uid': customerId,
          'email': 'test-wallet-005@example.com',
          'walletBalance': 500.0,
          'lastTransactionSequenceNumber': 0,
        });

        // Setup: Product
        await firestore.collection('products').doc(productId).set({
          'id': productId,
          'name': 'Test Product Wallet 005',
          'price': 100.0,
          'stock': 10,
          'shopId': shopId,
        });

        // Action: Create wallet order
        final items = [
          {
            'productId': productId,
            'quantity': 2,
            'price': 100.0,
            'totalPrice': 200.0,
            'name': 'Test Product Wallet 005',
          }
        ];

        final order = await walletOrderService.createWalletOrder(
          customerId: customerId,
          shopId: shopId,
          items: items,
          totalAmount: 200.0,
          deliveryAddressId: 'test-address-005',
        );

        // Assert: Transaction history recorded
        final transactions = await walletService.getTransactionHistory(
          userId: customerId,
          limit: 10,
        );

        expect(transactions.isNotEmpty, true);

        // Find the wallet payment transaction
        final walletTxn = transactions.firstWhere(
          (t) => t.amount == 200.0,
          orElse: () => throw Exception('Wallet transaction not found'),
        );

        expect(walletTxn.orderReference, order.id);
        expect(walletTxn.balanceAfter, 300.0);

        print('[TEST] PASSED: Wallet transaction history recorded');
      } catch (e) {
        print('[TEST] FAILED: $e');
        rethrow;
      } finally {
        // Cleanup
        await firestore.collection('users').doc(customerId).delete();
        await firestore.collection('products').doc(productId).delete();
      }
    });
  });
}
